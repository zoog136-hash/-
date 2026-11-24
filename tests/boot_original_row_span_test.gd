extends SceneTree
const R=preload("res://scripts/resources/current523_definition_rows.gd")
const SPANS=preload("res://scripts/resources/current523_boot_row_spans.gd")
const B=preload("res://scripts/resources/current523_bake_cache.gd")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,why:String)->void:
	checks+=1
	if not ok:failures.append(why);printerr("BOOT_ROW_SPAN_FAIL ",why)
## Linux per-thread running time (not scheduler wait); optional on other hosts.
func cpu_usec()->int:
	var f:=FileAccess.open("/proc/thread-self/schedstat",FileAccess.READ)
	if f==null:return -1
	var fields:=f.get_buffer(192).get_string_from_ascii().strip_edges().split(" ",false)
	return int(fields[0])/1000 if fields.size()>0 and fields[0].is_valid_int() else -1
func _initialize()->void:
	var sizes:Dictionary={}
	for table:String in SPANS.TABLES:
		var spec:Dictionary=SPANS.TABLES[table]
		var total:int=0;var previous:int=0
		for i:int in range(0,spec.spans.size(),3):
			var a:int=spec.spans[i];var b:int=spec.spans[i+1];var n:int=spec.spans[i+2]
			ck(a>previous and b>a and b-a<=R.CONVERT_BATCH_BYTES and n>0 and n<=R.CONVERT_BATCH_ROWS,"bounded disjoint span "+table)
			previous=b;total+=n
		ck(total==int(spec.rows),"complete rows "+table)
	var negative:PackedByteArray='{"rows":[{"id":1},{"other":"text"}]}'.to_utf8_buffer()
	ck(R._convert_pinned_member("ItemClass",negative)==R._convert(negative),"unknown bytes retain legacy fallback")
	var path:String=OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	if not path.is_empty():
		if FileAccess.get_sha256(path)!=R.SOURCE_SHA:ck(false,"wrong original archive")
		else:
			var zip:=ZIPReader.new();ck(zip.open(path)==OK,"pinned archive opened")
			var order:int=1 if OS.get_environment("TWILIGHT_SPAN_REVERSE")=="1" else 0
			for table:String in SPANS.TABLES:
				var bytes:=zip.read_file("content/"+table+".json")
				var readings:Dictionary={}
				for route:String in (["old","new"] if order%2==0 else ["new","old"]):
					var cpu_start:=cpu_usec();var t:=Time.get_ticks_usec()
					var out:Dictionary=R._convert(bytes) if route=="old" else R._convert_pinned_member(table,bytes)
					var elapsed:int=Time.get_ticks_usec()-t;var cpu_end:=cpu_usec()
					ck(out.get("ok",false) and out.store.count==int(SPANS.TABLES[table].rows),"complete conversion "+table)
					# One digest over the exact Godot-serialized full store incl types/field order.
					var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(var_to_bytes(out.store))
					readings[route]={"us":elapsed,"cpu_us":cpu_end-cpu_start if cpu_start>=0 and cpu_end>=cpu_start else -1,"sha":h.finish().hex_encode()}
					out={}
				ck(readings.old.sha==readings.new.sha,"exact whole stored bytes "+table)
				sizes[table]=readings
				print("BOOT_ROW_SPAN_TABLE ",table," ",JSON.stringify(readings))
				order+=1
			zip.close()
			if OS.get_environment("TWILIGHT_SPAN_DISK_TEST")=="1":
				ck(R._open(),"production source opened")
				var name:String="NpcClass";var current:String=R._bake_key(name);var old:String=R._bake_key(name,R.COMPATIBLE_V1)
				# The caller must supply a new private directory. Never rewrite another profile.
				var live_path:String=B.ROOT+"/disk_"+name+".json"
				if not FileAccess.file_exists(live_path):
					var t:=Time.get_ticks_usec()
					ck(R.prepare_table(name),"cold production prepare_table -> real disk publication")
					sizes["production_cold_us"]=Time.get_ticks_usec()-t
					var m:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(live_path))
					ck(m.key==current,"new production bake v2")
					var first:Dictionary=R.row_at(name,0)
					R.reset()
					# Same disk encoding and digest; recreate the old released metadata key.
					m.key=old;var f:=FileAccess.open(live_path,FileAccess.WRITE);f.store_string(JSON.stringify(m));f.close()
					t=Time.get_ticks_usec()
					ck(R.stored_current(name) and R.prepare_table(name) and R.row_at(name,0)==first and JSON.parse_string(FileAccess.get_file_as_string(live_path)).key==old,"real v1 cache reused without rewrite")
					sizes["production_v1_warm_us"]=Time.get_ticks_usec()-t
					R.reset()
					m.sha256="0".repeat(64);f=FileAccess.open(live_path,FileAccess.WRITE);f.store_string(JSON.stringify(m));f.close()
					ck(R.prepare_table(name) and R.row_at(name,0)==first and JSON.parse_string(FileAccess.get_file_as_string(live_path)).key==current,"invalid old digest is rejected and rebuilt v2")
				else:ck(false,"isolated new CPU test profile required")
	print("BOOT_ROW_SPAN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"times":sizes}))
	quit(0 if failures.is_empty() else 1)
