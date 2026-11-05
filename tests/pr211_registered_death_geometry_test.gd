extends SceneTree
const VFX=preload("res://scripts/animation/combat_vfx.gd")
const REG=preload("res://scripts/animation/reviewed_frame_registration.gd")
const GROUND=preload("res://tests/qa_rendered_prop_clearance.gd")
const RENDERER=preload("res://scripts/maps/source_map_runtime_renderer.gd")
var failures:int=0
var checks:int=0
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var record:Dictionary={}
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for row:Dictionary in catalog["변신"]:
		if str(row.get("sourceId",""))=="176":record=row;break
	var profile=preload("res://scripts/animation/animation_catalog.gd").for_record("transform",record,"")
	var frames:SpriteFrames=load(profile.frames_path)
	var raw:Dictionary=frames.get_meta(REG.META)
	check(frames.get_frame_count("death_2")==6,"current authored source has six death frames")
	var live:=AnimatedSprite2D.new();live.sprite_frames=frames;live.animation="idle_2";live.frame=0
	var base:=Vector2(.75,.75);REG.apply(live,frames,"idle_2",0,base)
	var vfx:=VFX.new();root.add_child(vfx)
	var tex:Texture2D=frames.get_frame_texture("idle_2",0)
	vfx.death_pose(Vector2.ZERO,tex,live.scale,live.position,frames,"death_2",base)
	var entry:Dictionary=vfx.active.back();var old_formula_disagrees:bool=false
	var age:float=0.0
	for i:int in range(6):
		var frame_seconds:float=frames.get_frame_duration("death_2",i)/frames.get_animation_speed("death_2")
		entry.age=age+frame_seconds*.25
		age+=frame_seconds
		check(vfx._death_frame_at_age(entry)==i,"weighted source frame boundary")
		var texture:Texture2D=frames.get_frame_texture("death_2",i)
		var expected:Dictionary=raw.death_2.frames[i]
		var pose:Dictionary=vfx._death_draw_geometry(entry,texture)
		check((pose.scale as Vector2).is_equal_approx(base*(expected.scale as Vector2)),"source registration scale phase%d"%i)
		var anchor:Vector2=pose.offset+(pose.texture_offset-texture.get_size()*.5+(expected.anchor as Vector2))*pose.scale
		check(anchor.is_equal_approx(base*(expected.get("target",Vector2.ZERO) as Vector2)),"source anchor phase%d"%i)
		if not live.scale.is_equal_approx(pose.scale):old_formula_disagrees=true
	check(old_formula_disagrees,"old frozen-live-scale path demonstrably differs from source death registration")
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	var floor:=Sprite2D.new();floor.centered=false;floor.texture=ImageTexture.create_from_image(image);floor.z_index=-4096
	var renderer:=RENDERER.new();renderer.record={"chunks":[{"position":[0,0]}]};renderer.chunks[0]=floor;renderer.add_child(floor);root.add_child(renderer)
	check(GROUND.registered_source_ground(renderer,floor),"owned source ground below actors is not an occluder")
	floor.z_index=0;check(not GROUND.registered_source_ground(renderer,floor),"foreground draw order never exempt")
	floor.z_index=-4096;renderer.chunks.clear();check(not GROUND.registered_source_ground(renderer,floor),"unregistered prop never exempt")
	live.free();vfx.free();renderer.free()
	print("PR211_REGISTERED_DEATH_GEOMETRY ",JSON.stringify({"checks":checks,"failures":failures,"source_frames":6,"old_scale_regression_reproduced":old_formula_disagrees}))
	quit(0 if failures==0 else 1)
