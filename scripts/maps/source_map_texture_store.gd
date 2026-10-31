extends Node
## Full-resolution source84 images. Workers only verify/decode CPU Images;
## texture creation and ownership changes run on the scene thread.
const IDLE_BYTES: int=64*1024*1024
const MAX_DECODERS: int=2
const MAX_UPLOADS: int=1
# Admission budget between uploads; a single driver call is not preemptible.
const UPLOAD_USEC: int=2000
static var shared_ref: WeakRef
var entries: Dictionary={}
var clock: int=0
var idle_budget: int=IDLE_BYTES
var decodes: int=0
var uploads: int=0
# Includes file reading and SHA verification before the CPU decoder.
var decode_usec: int=0
var upload_usec: int=0
var max_frame_uploads: int=0
var evictions: int=0
var initial_uploads: int=0
var largest_upload_usec: int=0
var max_decode_jobs: int=0
# path -> [sha256, byte length, mtime] of the last successful SHA-256 check.
var verified_files: Dictionary={}

func _init() -> void:
	process_priority=-100

class DecodeJob extends RefCounted:
	var path: String
	var row: Dictionary
	var image: Image
	var problem: String=""
	var elapsed: int=0
	var decoded: bool=false
	var task: int=-1
	var stamp: Array=[]
	func _stamp() -> Array:
		var file: FileAccess=FileAccess.open(path,FileAccess.READ)
		return [] if file==null else [file.get_length(),FileAccess.get_modified_time(path)]
	func run() -> void:
		var begun: int=Time.get_ticks_usec()
		var before: Array=_stamp()
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
		# Remember the size/mtime only if the file was stable around the read.
		if not before.is_empty() and before==_stamp():stamp=before
		var digest:=HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		if not bytes.is_empty():digest.update(bytes)
		if bytes.is_empty() or digest.finish().hex_encode()!=str(row.sha256):problem="Source chunk missing or changed: "+path
		else:
			image=Image.new()
			decoded=true
			var error: Error=image.load_png_from_buffer(bytes) if bool(row.get("local_patch",false)) else image.load_webp_from_buffer(bytes)
			if error!=OK:problem="Source chunk decode failed: "+path
			elif image.get_width()!=int(row.size[0]) or image.get_height()!=int(row.size[1]):problem="Source chunk dimensions changed: "+path
		if not problem.is_empty():image=null
		elapsed=Time.get_ticks_usec()-begun

static func shared(host: Node) -> Node:
	var retained: Node=shared_ref.get_ref() as Node if shared_ref!=null else null
	if is_instance_valid(retained):return retained
	var store: Node=load("res://scripts/maps/source_map_texture_store.gd").new()
	store.name="Source84TextureStore"
	shared_ref=weakref(store)
	host.get_tree().root.add_child.call_deferred(store)
	return store

static func resource_key(_root_path: String,row: Dictionary) -> String:
	var relative: String=str(row.get("file",""))
	if relative.contains("..") or relative.is_absolute_path() or not row.get("size") is Array or row.size.size()!=2:return ""
	if bool(row.get("local_patch",false)):
		if not relative.begins_with("local-interpretation-v1/patches/") or not relative.ends_with(".png"):return ""
	elif not relative.begins_with("chunks/") or relative.get_file()!=relative.trim_prefix("chunks/") or not relative.ends_with(".webp"):return ""
	if str(row.get("sha256","")).length()!=64 or int(row.size[0])<=0 or int(row.size[1])<=0:return ""
	# Equal verified content and decode policy share one texture across maps,
	# while position, foot frame and painter order remain placement data.
	return "%s:%dx%d:%s:fullres-v1" % [row.sha256,int(row.size[0]),int(row.size[1]),relative.get_extension()]

func request(root_path: String,row: Dictionary,owner: Object,blocking: bool=false) -> String:
	var key: String=resource_key(root_path,row)
	if key.is_empty():return ""
	var path: String=(root_path.trim_suffix("/")+"/"+str(row.file)).simplify_path()
	var lease: String=str(owner.get_instance_id())+":"+path
	if entries.has(key):
		var current: Dictionary=entries[key]
		# A new placement/map lease revalidates the requested file even if the
		# texture is already resident. Live leases match the old one-load policy.
		# While walking, a chunk re-entering view hashed its whole multi-MB WebP
		# on the scene thread. A streaming (non-blocking) lease reuses the last
		# SHA-256 verification while the file's size and mtime are unchanged;
		# blocking/map-entry requests still hash the bytes.
		if not current.validated.has(lease):
			if blocking or not _verified_unchanged(path,str(row.sha256)):
				if FileAccess.get_sha256(path)!=str(row.sha256):return ""
				_remember_verified(path,str(row.sha256))
	else:
		entries[key]={"path":path,"row":row.duplicate(true),"owners":{},"validated":{},"texture":null,"job":null,"bytes":0,"idle":0,"problem":""}
	var entry: Dictionary=entries[key]
	entry.owners[owner.get_instance_id()]=weakref(owner)
	entry.validated[lease]=true
	if blocking and entry.texture==null and str(entry.problem).is_empty():
		if entry.job==null:
			var running: Array[String]=[]
			for pending: String in entries:
				if entries[pending].job!=null:running.append(pending)
			if running.size()>=MAX_DECODERS:
				var prior: String=running[0]
				if _finish(prior,entries[prior]):initial_uploads+=1
			_start(entry)
		if _finish(key,entry):initial_uploads+=1
	return key

func _file_stamp(path: String) -> Array:
	var file: FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null:return []
	return [file.get_length(),FileAccess.get_modified_time(path)]

func _remember_verified(path: String,sha256: String) -> void:
	var stamp: Array=_file_stamp(path)
	if not stamp.is_empty():verified_files[path]=[sha256]+stamp

func _verified_unchanged(path: String,sha256: String) -> bool:
	var known: Array=verified_files.get(path,[])
	if known.is_empty() or str(known[0])!=sha256:return false
	return _file_stamp(path)==known.slice(1)

func texture(key: String) -> Texture2D:
	return entries.get(key,{}).get("texture") as Texture2D

func problem(key: String) -> String:
	return str(entries.get(key,{}).get("problem",""))

func release_owner(owner: Object) -> void:
	var id: int=owner.get_instance_id()
	for entry: Dictionary in entries.values():
		if entry.owners.erase(id):clock+=1;entry.idle=clock
		for lease: String in entry.validated.keys():
			if lease.begins_with(str(id)+":"):entry.validated.erase(lease)
	prune()

func release(key: String,owner: Object) -> void:
	if not entries.has(key):return
	var entry: Dictionary=entries[key]
	entry.owners.erase(owner.get_instance_id())
	for lease: String in entry.validated.keys():
		if lease.begins_with(str(owner.get_instance_id())+":"):entry.validated.erase(lease)
	clock+=1;entry.idle=clock
	prune()

func _start(entry: Dictionary) -> void:
	var job:=DecodeJob.new()
	job.path=entry.path;job.row=entry.row
	entry.job=job
	job.task=WorkerThreadPool.add_task(job.run)
	var running: int=0
	for current: Dictionary in entries.values():
		if current.job!=null:running+=1
	max_decode_jobs=maxi(max_decode_jobs,running)

func _finish(key: String,entry: Dictionary) -> bool:
	assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
	var job: DecodeJob=entry.job
	WorkerThreadPool.wait_for_task_completion(job.task)
	entry.job=null
	decode_usec+=job.elapsed
	if job.decoded:decodes+=1
	if entry.owners.is_empty():entries.erase(key);return false
	entry.problem=job.problem
	if job.image==null:return false
	# The worker hashed exactly these bytes, with a stable size/mtime.
	if not job.stamp.is_empty():verified_files[entry.path]=[str(entry.row.sha256)]+job.stamp
	var begun: int=Time.get_ticks_usec()
	entry.bytes=job.image.get_data_size()
	entry.texture=ImageTexture.create_from_image(job.image)
	var elapsed: int=Time.get_ticks_usec()-begun
	upload_usec+=elapsed;largest_upload_usec=maxi(largest_upload_usec,elapsed)
	uploads+=1
	return true

func _process(_delta: float) -> void:
	pump()

func pump() -> void:
	prune()
	var running: int=0
	for entry: Dictionary in entries.values():
		if entry.job!=null:running+=1
	for entry: Dictionary in entries.values():
		if running>=MAX_DECODERS:break
		if entry.texture==null and entry.job==null and str(entry.problem).is_empty() and not entry.owners.is_empty():_start(entry);running+=1
	var begun: int=Time.get_ticks_usec()
	var completed: int=0
	for key: String in entries.keys():
		var entry: Dictionary=entries[key]
		if entry.job==null or not WorkerThreadPool.is_task_completed(entry.job.task):continue
		if _finish(key,entry):completed+=1
		if completed>=MAX_UPLOADS or Time.get_ticks_usec()-begun>=UPLOAD_USEC:break
	max_frame_uploads=maxi(max_frame_uploads,completed)
	prune()

func prune() -> void:
	var idle: Array[String]=[]
	var bytes: int=0
	for key: String in entries.keys():
		var entry: Dictionary=entries[key]
		for id: int in entry.owners.keys():
			if entry.owners[id].get_ref()==null:
				entry.owners.erase(id);clock+=1;entry.idle=clock
				for lease: String in entry.validated.keys():
					if lease.begins_with(str(id)+":"):entry.validated.erase(lease)
		if not entry.owners.is_empty():continue
		if entry.job!=null:continue
		if entry.texture==null:entries.erase(key);continue
		idle.append(key);bytes+=int(entry.bytes)
	idle.sort_custom(func(a: String,b: String) -> bool:return int(entries[a].idle)<int(entries[b].idle))
	while bytes>idle_budget and not idle.is_empty():
		var key: String=idle.pop_front()
		bytes-=int(entries[key].bytes);entries.erase(key);evictions+=1

func stats() -> Dictionary:
	var result: Dictionary={"unique_textures":0,"active_bytes":0,"idle_bytes":0,"pending":0,"decodes":decodes,"uploads":uploads,"decode_usec":decode_usec,"upload_usec":upload_usec,"largest_upload_usec":largest_upload_usec,"max_frame_uploads":max_frame_uploads,"max_decode_jobs":max_decode_jobs,"evictions":evictions,"initial_uploads":initial_uploads}
	for entry: Dictionary in entries.values():
		if entry.texture!=null:
			result.unique_textures+=1
			if entry.owners.is_empty():result.idle_bytes+=int(entry.bytes)
			else:result.active_bytes+=int(entry.bytes)
		elif not entry.owners.is_empty():result.pending+=1
	return result

func _exit_tree() -> void:
	for entry: Dictionary in entries.values():
		if entry.job!=null:WorkerThreadPool.wait_for_task_completion(entry.job.task)
	entries.clear()
