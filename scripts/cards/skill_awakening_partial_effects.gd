extends Node2D
## Sparse one-shot adapter only. Fully supported clips use the existing compositor.
## Missing source directions remain unavailable; no reflection/rotation is invented.
const POLICY_PATH="res://scripts/animation/source_playback_policy.gd"
const MAX_ACTIVE: int=32
const MAX_TEXTURES: int=96
var active: Array[Dictionary]=[]
var pool: Array[Sprite2D]=[]
var textures: Dictionary={}
var emitted: int=0
var retired: int=0

func _ready() -> void:set_process(false)
func play_source(_manifest: String,_sprite_id: int,_facing: int,_point: Vector2) -> bool:
	# A legacy base508 overlay index is not a current source-bank input.
	return false

func play_current_source(preview: Node,sprite_id: int,facing: int,point: Vector2) -> bool:
	if preview==null or not preview.has_method("spawn_source_overlay"):return false
	var context: Variant=preview.get("_reference_card_context")
	if not context is Dictionary or context.get("source_snapshot")!="patch523" or context.get("source_tables_sha256")!="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832":return false
	# The Sprite owner resolves its own exact current child/action declaration.
	# No old overlay record, fabricated source action or sparse frame is supplied.
	return preview.spawn_source_overlay(sprite_id,facing,point)

func _play_legacy_source_for_reference(manifest: String,sprite_id: int,facing: int,point: Vector2) -> bool:
	if active.size()>=MAX_ACTIVE or not ResourceLoader.exists(POLICY_PATH) or not FileAccess.file_exists(manifest):return false
	var policy: Script=load(POLICY_PATH)
	if policy.mode(manifest.get_base_dir())!="compatible":return false
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if not index is Dictionary or index.get("source_snapshot","")!="base508":return false
	var relative: String=str(index.get("records",{}).get("overlay:"+str(sprite_id),{}).get("manifest",""))
	if not safe(relative):return false
	var record: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest.get_base_dir().path_join(relative)))
	if not record is Dictionary or not bool(record.get("card_skill_partial_overlay",false)) or int(record.get("source_sprite_id",0))!=sprite_id:return false
	var direction: int=posmod(facing+3,8)
	var available: bool=false
	for value: Variant in record.get("source_available_directions",[]):
		if int(value)==direction:available=true;break
	if not available:return false
	var track: Dictionary=record.get("tracks",{}).get("idle",{})
	if track.get("directions",[]).size()!=8:return false
	var source_frames: Array=track.directions[direction]
	if source_frames.is_empty() or not track.get("timing_issues",[]).is_empty():return false
	var fps: float=float(track.fps) if track.get("fps")!=null else float(policy.data().get("pc_default_ticks_per_second",0))
	if fps<=0:return false
	var style: Dictionary=policy.effect(record.get("source_attributes",[]),"compatible")
	if not bool(style.get("enabled",false)):return false
	var frames: Array[Dictionary]=[];var duration: float=0
	for frame: Dictionary in source_frames:
		if frame.get("layers",[]).size()!=1 or float(frame.get("source_ticks",-1))<0:return false
		var layer: Dictionary=frame.layers[0]
		var path: String=str(layer.get("path",""))
		if not safe(path) or str(layer.get("sha256","")).is_empty():return false
		path=manifest.get_base_dir().path_join(path)
		var key: String=path+":"+str(layer.sha256)
		if not textures.has(key):
			if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(layer.sha256):return false
			var image: Image=Image.load_from_file(path)
			if image==null or image.is_empty():return false
			if textures.size()>=MAX_TEXTURES:textures.erase(textures.keys()[0])
			textures[key]=ImageTexture.create_from_image(image)
		duration+=float(frame.source_ticks)/fps
		frames.append({"texture":textures[key],"offset":Vector2(float(layer.offset[0]),float(layer.offset[1])),"end":duration,"source_frame":int(frame.source_frame)})
	if duration<=0:return false
	var sprite: Sprite2D=pool.pop_back() if not pool.is_empty() else Sprite2D.new()
	if sprite.get_parent()==null:add_child(sprite)
	sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=Vector2.ONE;sprite.rotation=0;sprite.modulate=Color(1,1,1,float(style.get("alpha",1)))
	var material:=CanvasItemMaterial.new();material.blend_mode=int(style.blend_mode);sprite.material=material
	sprite.global_position=point;sprite.show()
	var entry: Dictionary={"sprite":sprite,"frames":frames,"clock":0.0,"duration":duration,"sprite_id":sprite_id,"source_direction":direction,"timing_origin":"SPR_explicit" if track.get("fps")!=null else "compat_PC_default_unverified_M","source_frame":-1}
	active.append(entry);_pose(entry);emitted+=1;set_process(true);return true

static func safe(path: String) -> bool:return not path.is_empty() and not path.is_absolute_path() and not ".." in path.split("/") and not ":" in path
func _pose(entry: Dictionary) -> void:
	var chosen: Dictionary=entry.frames[-1]
	for frame: Dictionary in entry.frames:
		if float(entry.clock)<float(frame.end):chosen=frame;break
	entry.sprite.texture=chosen.texture;entry.sprite.offset=chosen.offset;entry.source_frame=chosen.source_frame
func _process(delta: float) -> void:
	for i: int in range(active.size()-1,-1,-1):
		var entry: Dictionary=active[i];entry.clock+=maxf(0,delta)
		if float(entry.clock)>=float(entry.duration):
			_retire(entry.sprite);active.remove_at(i)
		else:_pose(entry)
	if active.is_empty():set_process(false)
func _retire(sprite: Sprite2D) -> void:
	sprite.hide();sprite.texture=null;sprite.material=null;sprite.offset=Vector2.ZERO;sprite.modulate=Color.WHITE
	sprite.position=Vector2.ZERO;pool.append(sprite);retired+=1
func clear() -> void:
	for entry: Dictionary in active:_retire(entry.sprite)
	active.clear();set_process(false)
