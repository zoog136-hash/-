extends SceneTree
const Adapter=preload("res://scripts/cards/skill_awakening_source_vfx.gd")
const CATALOG=preload("res://data/cards/base508_skill_awakening.json")
var errors: Array[String]=[]
var checks: int=0
class Motion extends RefCounted:
	var facing8: int=5 # Existing host +3 mapping selects stored source direction0.
class Caster extends Node2D:
	var original_source_preview: Node
	var original_source_manifest: String=""
	var motion=Motion.new()
class Host extends Node2D:
	var player: Node2D
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(path: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path)==OK,"capture exact original effect pixels")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: String="";var folder: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--effect-manifest="):manifest=arg.trim_prefix("--effect-manifest=")
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
	if manifest.is_empty() or folder.is_empty() or not ResourceLoader.exists("res://scripts/animation/original_source_preview.gd"):
		push_error("Explicit private priority source pack and PR217 compositor required");quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(640,360);DisplayServer.window_set_size(root.size)
	var host:=Host.new();root.add_child(host)
	var player:=Caster.new();host.add_child(player);host.player=player
	var preview: Node=load("res://scripts/animation/original_source_preview.gd").new();player.add_child(preview)
	player.original_source_preview=preview;player.original_source_manifest=manifest
	var target:=Node2D.new();host.add_child(target);target.global_position=Vector2(320,180)
	var adapter=Adapter.new();var spell: Dictionary=CATALOG.data.spells["64224"].source_spell
	var result: Dictionary=adapter.emit_spell(host,spell,target)
	print("SOURCE_PIXEL_DISPATCH ",JSON.stringify(result))
	check(result.status=="played" and result.played==["effect","impact"],"both exact1583/218 stages render with available source direction")
	var partial: Node2D=adapter.partial_effects
	check(partial.active.size()==1 and partial.active[0].source_frame==3,"1583 starts at SPR token frame3 rather than numeric frame0")
	if partial.active.is_empty():host.queue_free();quit(1);return
	partial.set_process(false)
	var sprite: Sprite2D=partial.active[0].sprite;var pool_id: int=sprite.get_instance_id()
	var expected: Image=Image.load_from_file(manifest.get_base_dir()+"/pixels/1583-0-0-3.png")
	check(sprite.texture.get_image().get_data()==expected.get_data(),"render texture preserves exact decoded original1583 pixels")
	check(preview._overlay_nodes.size()==1,"complete218 uses existing compositor; partial1583 adds no duplicate overlay")
	var explosion: Node2D=preview._overlay_nodes[0];explosion.set_process(false)
	check(explosion.last_source_frame==9,"218 starts at original SPR frame9")
	check(explosion._layers[0].texture.get_image().get_data()==Image.load_from_file(manifest.get_base_dir()+"/pixels/218-0-0-9.png").get_data(),"existing compositor texture matches original218 pixels")
	await capture(folder+"/source-1583-218-initial.png")
	partial._process(.13);explosion.advance_source(.05,"idle",5,0,false)
	check(partial.active[0].source_frame==0 and explosion.last_source_frame==0,"original token ticks advance both effects in declared order")
	target.position=Vector2(500,300)
	check(sprite.global_position==Vector2(320,180) and explosion.global_position==Vector2(320,180),"effect points remain independent of target reuse/movement")
	await capture(folder+"/source-1583-218-next.png")
	partial._process(2);explosion.advance_source(2,"idle",5,0,false);await process_frame
	check(partial.active.is_empty() and partial.pool.size()==1 and not sprite.visible and sprite.texture==null,"partial effect retires and releases texture/material to bounded pool")
	check(not is_instance_valid(explosion),"existing one-shot compositor retires218")
	result=adapter.emit_spell(host,spell,target);partial.set_process(false)
	check(result.status=="played" and partial.active[0].sprite.get_instance_id()==pool_id,"new effect reuses released sprite rather than allocating another")
	check(partial.active[0].sprite.global_position==target.global_position and partial.active[0].source_frame==3,"pooled sprite resets position and source frame for new invocation")
	partial.clear();player.motion.facing8=1 # Source4 is absent from SP2 mask15.
	result=adapter.emit_spell(host,spell,target)
	check(result.status=="partial" and result.unavailable==["effect"] and result.played==["impact"] and partial.active.is_empty(),"unavailable1583 source direction4 is not mirrored/invented;218 remains valid")
	check(partial.textures.size()<=96 and partial.pool.size()<=32,"source caches and sprite pool remain bounded")
	var report: Dictionary={"checks":checks,"errors":errors,"timing":"Source FPS absent: existing compatible PC24 policy, not verified M FPS","source1583_direction_scope":[0,1,2,3],"source218_direction_scope":"fixed source0 all host facings"}
	var file:=FileAccess.open(folder+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	print("CARD_SKILL_SOURCE_PIXELS ",JSON.stringify(report))
	host.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
