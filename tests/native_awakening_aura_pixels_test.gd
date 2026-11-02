extends SceneTree
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
class Anchor extends Node2D:
	var source_facing: int=5
	var mode: String="compatible"
	var role: String="idle"
	func installed() -> bool:return true
	func source_playback_mode() -> String:return mode
	func source_role() -> String:return role
var checks: int=0
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String="";var stage: String="";var folder: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
		if arg.begins_with("--aura-stage="):stage=arg.trim_prefix("--aura-stage=")
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
	if path.is_empty() or stage.is_empty() or folder.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(640,360);DisplayServer.window_set_size(root.size)
	var host=Fixture.Host.new();root.add_child(host);host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}
	var service=Runtime.new();check(service.configure(host),"source-aware completion service")
	var actor=Anchor.new();root.add_child(actor);actor.position=Vector2(320,245)
	var aura: Node2D=load("res://scripts/animation/source_awakening_aura.gd").new();root.add_child(aura);aura.set_process(false)
	var last: Dictionary={};var rendered: int=0
	for grade: int in [4,5,32,52]:
		var record: Dictionary={}
		for candidate: Dictionary in host.catalog_db["성물"]:
			var id: String=Cards.card_id(candidate)
			if int(candidate.source_grade_id)==grade and service.core.native_eligibility("성물",id).ok:record=candidate;break
		check(not record.is_empty(),"eligible canonical relic grade "+str(grade))
		if record.is_empty():continue
		var identity: String=Cards.card_id(record);host.card_draw_fusion.owned["성물"][identity]=true
		service.progress.cards["성물"][identity]={"experience":0,"awakened":true,"attempts":1,"failures":0}
		actor.role="idle";actor.mode="compatible"
		var before: int=hash([service.export_state(),host.card_draw_fusion.export_state(),host.gold,host.rng.state])
		aura.configure("성물",record,service.source_visual_awakened("성물",record),actor,stage+"/manifest.json",{})
		check(aura.visual.installed() and aura.status=="compatible_native_anchor_unverified_M_placement_and_blend","existing renderer installs original aura grade "+str(grade))
		if not aura.visual.installed():continue
		check(aura.visual._playback_tracks.idle.effective_fps==24 and aura.visual._playback_tracks.walk.effective_fps==36,"preserve explicit source idle24 walk36 rates")
		check(aura.visual._playback_tracks.idle.timing_origin=="SPR_explicit_section","aura timing uses exact directive, not doll compatibility fallback")
		for direction: int in range(8):
			actor.source_facing=posmod(direction+5,8);aura.visual._clock=0;aura._process(0)
			var frame: Dictionary=aura.visual._record.tracks.idle.directions[direction][0]
			var layer: Dictionary=frame.layers[0]
			var original: Image=Image.load_from_file(stage+"/awakening/"+str(layer.path))
			check(aura.visual._layers[0].texture.get_image().get_data()==original.get_data(),"exact decoded source pixels direction "+str(direction))
			check(aura.visual._layers[0].position==Vector2(layer.offset[0],layer.offset[1]),"original pixel offset retained")
		actor.source_facing=5;aura.visual._clock=0;aura._process(0)
		check(aura.visual.last_source_frame==11,"idle starts at declared frame11 rather than numeric0")
		aura._process(.2);check(aura.visual.last_source_frame==0,"24Hz source ticks advance declared next pose")
		var clock: float=aura.visual._clock;var textures: int=aura.visual._textures.size()
		aura.configure("성물",record,true,actor,stage+"/manifest.json",{})
		check(aura.visual._clock==clock and aura.visual._textures.size()==textures,"repeat sync preserves clock and cached textures")
		actor.role="walk";aura._process(0);check(aura.visual.source_role()=="walk" and aura.visual.last_source_frame==0,"owner walk selects source walk track")
		aura._process(.1);check(aura.visual.last_source_frame==1,"36Hz source walk ticks preserved")
		aura.apply_settings({"reduced_motion":true});aura._process(0);check(not aura.visible,"existing settings hide aura without invented pixels")
		aura.apply_settings({});actor.role="idle";aura._process(0)
		await process_frame;await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/source-aura-"+str(aura.sprite_id)+".png")==OK,"capture actual existing aura renderer")
		check(hash([service.export_state(),host.card_draw_fusion.export_state(),host.gold,host.rng.state])==before,"render changes no save ownership currency or RNG")
		last=record;rendered+=1
	actor.mode="strict";aura.configure("성물",last,true,actor,stage+"/manifest.json",{})
	check(aura.status=="strict_unverified_composition" and not aura.visual.installed(),"strict keeps unverified blend inactive")
	aura.configure("성물",last,false,actor,stage+"/manifest.json",{});check(aura.status=="inactive" and aura.sprite_id==0,"unequip/completion removal releases original effect")
	print("NATIVE_AWAKENING_AURA_PIXELS ",JSON.stringify({"checks":checks,"errors":errors,"profiles":rendered,"anchor":"isolated test anchor; M placement/blend remain unverified","source":"8 reused original SP2; no new source download or generated pixels"}))
	aura.queue_free();actor.queue_free();host.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
