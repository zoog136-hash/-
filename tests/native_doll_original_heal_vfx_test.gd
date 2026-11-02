extends SceneTree
const Combat=preload("res://scripts/cards/native_option_combat.gd")
const Source=preload("res://data/cards/base508_option_extensions.json")
class Motion extends RefCounted:
	var facing8: int=5
class Player extends Node2D:
	var original_source_preview: Node
	var original_source_manifest: String=""
	var motion=Motion.new()
class Host extends Node:
	var player: Node2D
class Service extends RefCounted:
	var world: Node
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest: String="";var folder: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--effect-manifest="):manifest=arg.trim_prefix("--effect-manifest=")
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
	if manifest.is_empty() or folder.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(640,360);DisplayServer.window_set_size(root.size)
	var host:=Host.new();root.add_child(host);var player:=Player.new();host.add_child(player);host.player=player;player.global_position=Vector2(320,260)
	var preview: Node=load("res://scripts/animation/original_source_preview.gd").new();player.add_child(preview);player.original_source_preview=preview;player.original_source_manifest=manifest
	var service:=Service.new();service.world=host;var combat=Combat.new();combat.configure(service)
	var spell: Dictionary=Source.data.invoke_spells["55653"].source_spell
	for facing: int in range(8):
		player.motion.facing8=facing;combat.emit_spell(spell,player)
		check(combat.visual_results.get("19580","")=="played_original","real source19580 dispatched "+str(facing))
		check(preview._overlay_nodes.size()==1,"effect/success same ID never duplicate source layers "+str(facing))
		var effect: Node=preview._overlay_nodes[0];effect.set_process(false)
		check(effect._layers.size()==1 and effect._effect_nodes.has(19581),"source19580 includes declared19581 child "+str(facing))
		check(effect.last_source_frame==13,"source token starts at13 "+str(facing))
		check(effect._layers[0].texture.get_image().get_data()==Image.load_from_file(manifest.get_base_dir()+"/pixels/19580-0-0-13.png").get_data(),"body pixels exact "+str(facing))
		check(effect._effect_nodes[19581].texture.get_image().get_data()==Image.load_from_file(manifest.get_base_dir()+"/pixels/19581-0-0-13.png").get_data(),"child pixels exact "+str(facing))
		if facing==5:
			await process_frame;await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/original-19580-19581.png")==OK,"actual OpenGL capture")
			effect.advance_source(.5,"idle",facing,0,false);await process_frame;await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/original-19580-19581-active.png")==OK,"actual original active frame with labelled compatibility clock")
		effect.advance_source(10,"idle",facing,0,false);await process_frame
		check(not is_instance_valid(effect),"one-shot source node retires "+str(facing))
		# Next emit prunes freed compositor handles without a typed cast failure.
	# The other newly supported proc has no local original bytes; stay explicit.
	combat.emit_spell(Source.data.invoke_spells["67401"].source_spell,player)
	check(combat.visual_results.get("23084","")=="original_binding_unavailable","missing23084 is not fabricated")
	preview._overlay_nodes.clear();host.queue_free();await process_frame
	print("NATIVE_DOLL_ORIGINAL_HEAL_VFX ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
