extends SceneTree
const VIEW=preload("res://scripts/animation/original_source_preview.gd")
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
const SOURCE=preload("res://scripts/lineagem_base508.gd")
const BANK=preload("res://scripts/animation/source_weapon_banks.gd")
var failures:int=0
var checks:int=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var manifest:String=INSTALL.active_root().path_join("manifest.json")
	var expected:Dictionary={1:{"idle":7,"walk":4,"attack":5},2:{"idle":14,"walk":11,"attack":12},7:{"idle":53,"walk":50,"attack":51},84:{"idle":151,"walk":147,"attack":148}}
	for sid:int in [28439,28514,28519,28524]:
		var option:int={28439:0,28514:24,28519:4,28524:14}[sid]
		for weapon:int in expected:
			var view:=VIEW.new();root.add_child(view);view.playback_mode_override="compatible"
			var context:Dictionary={"source_weapon_type":weapon,"active_card_options":{"m508:1:24504":option}}
			check(view.configure("transform:m508:1:24504",manifest,context),"exact Halpas option loads")
			check(int(view._record.source_sprite_id)==sid and view.source_weapon_status.state=="selected_source_weapon_actions","native body/weapon selection")
			for role:String in ["idle","walk","attack"]:
				check(int(view._playback_tracks[role].source_action_id)==int(expected[weapon][role]),"source primary action matches M table")
				for facing:int in range(8):
					view.advance_source(0.25,role,facing,facing+1,role=="attack");check(view.last_source_frame>=0,"source weapon frame direction loads")
			if sid==28439:check(view._playback_tracks.run.source_action.begins_with("Run"),"native run alias retained")
			else:check(not view._playback_tracks.has("run"),"no fabricated color-option run")
			view.free()
	var view:=VIEW.new();root.add_child(view);view.playback_mode_override="compatible"
	check(view.configure("transform:m508:1:24504",manifest,{"source_weapon_type":0}),"unarmed remains explicit source generic")
	check(int(view._playback_tracks.idle.source_action_id)==3,"generic control unchanged")
	check(view.configure("transform:m508:1:24504",manifest,{"source_weapon_type":-1}),"unknown type preserves source fallback")
	check(view.source_weapon_status.state.begins_with("unsupported"),"fallback status explicit")
	# An unrelated single-bank actor keeps its original source weapon/frames.
	check(view.configure("transform:267",manifest,{"source_weapon_type":1}),"existing Girtas regression loads")
	check(int(view._record.body_id)==22258 and view.source_weapon_status.state.contains("fallback"),"unprepared actor not forced into another weapon bank")
	view.free()
	var player=preload("res://scenes/Player.tscn").instantiate();root.add_child(player);player.set_physics_process(false)
	player.original_source_manifest=manifest
	var card:Dictionary={}
	for row:Dictionary in SOURCE.cards().catalog["변신"]:
		if int(row.source_card_id)==24504:card=row;break
	player.source_visual_context={"source_weapon_type":0,"active_card_options":{"m508:1:24504":24}}
	player.set_transform_visual("",1.0,preload("res://scripts/animation/animation_catalog.gd").for_record("transform",card,""))
	player.attack_clock=0.17
	player.motion.attack_elapsed=0.23
	var sequence:int=player.motion.sequence
	var strikes:Array=[];player.attack_strike.connect(func(value:int):strikes.append(value))
	player.set_source_weapon_visual("한손검")
	check(int(player.original_source_preview._record.source_sprite_id)==28514 and int(player.original_source_preview._playback_tracks.idle.source_action_id)==7,"real Player weapon equip changes same color-option source action bank")
	check(player.motion.sequence==sequence and strikes.is_empty() and is_equal_approx(player.attack_clock,0.17) and is_equal_approx(player.motion.attack_elapsed,0.23),"weapon visual change preserves hit sequence and emits no combat strike")
	player.free()
	print("SOURCE_WEAPON_BANKS ",JSON.stringify({"checks":checks,"failures":failures,"actors":4,"families":4,"attack_hit_clock_changed":false}))
	quit(0 if failures==0 else 1)
