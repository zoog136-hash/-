extends SceneTree
const Cards=preload("res://scripts/card_draw_fusion.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var errors: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func settle() -> void:
	for i: int in range(3):await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder: String="";var private_root: String="";var manifest: String="";var actor_manifest: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--private-ui-root="):private_root=arg.trim_prefix("--private-ui-root=")
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--effect-manifest="):manifest=arg.trim_prefix("--effect-manifest=")
		if arg.begins_with("--actor-manifest="):actor_manifest=arg.trim_prefix("--actor-manifest=")
	if folder.is_empty() or private_root.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	load("res://scripts/lineagem_pack_install.gd")._session_root=private_root
	root.size=Vector2i(854,480);DisplayServer.window_set_size(root.size)
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);await settle()
	check(QA.enter_game(world),"enter game")
	world.save_timer=-10000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	world.hud.process_mode=Node.PROCESS_MODE_ALWAYS
	var chosen: Dictionary={};var main: Dictionary={}
	for record: Dictionary in world.catalog_db["마법인형"]:
		if Cards.card_id(record)==("source:m508:2:28" if not actor_manifest.is_empty() else "source:m508:2:40"):chosen=record
		elif int(record.source_grade_id)==3 and main.is_empty():main=record
	check(not chosen.is_empty() and not main.is_empty(),"exact source doll fixtures")
	if chosen.is_empty() or main.is_empty():world.queue_free();quit(1);return
	world.card_draw_fusion.owned["마법인형"][Cards.card_id(chosen)]=true;world.card_draw_fusion.owned["마법인형"][Cards.card_id(main)]=true
	world.equipped_catalog["마법인형"]=main;world.level=95;world.player.original_source_manifest=actor_manifest if not actor_manifest.is_empty() else manifest
	world._update_hud();world.hud.open_catalog("마법인형");await settle()
	world.hud.catalog_search.text=str(chosen.sourceId);world.hud._refresh_catalog_list(str(chosen.sourceId));await settle();world.hud._select_catalog_index(0);world.hud._set_catalog_detail_view(true);await settle()
	var button: Button=world.hud.companion_detail_view.secondary_button
	check(button.is_visible_in_tree() and button.disabled and button.tooltip_text.contains("에바"),"source extra summon visibly locked without actual unlock")
	world.active_skill_buffs={"QA in-memory only":{"source_snapshot":"base508","source_buff_class_id":91531,"remaining":30}}
	world.hud.companion_detail_view.refresh()
	check(not button.disabled and button.text=="추가 소환" and button.size.y>=44,"eligible source action has touch height44")
	var owned_before: int=hash(world.card_draw_fusion.export_state());var money: int=world.gold
	# Isolated in-memory selected state, never write granted fixture ownership.
	world.option_awakening.progress["native_subslot_identity"]=Cards.card_id(chosen);world._update_companion(0);world._update_hud();await settle()
	check(world.option_awakening.subslot_view().active and button.text=="추가 소환 해제","selected source state and release UI agree")
	if actor_manifest.is_empty():
		check(is_instance_valid(world.secondary_doll_visual) and world.secondary_doll_visual.status=="source_asset_pending" and not world.secondary_doll_visual.visible,"overlay-only fixture pack never generates a replacement actor")
	else:
		var visual: Node2D=world.secondary_doll_visual
		check(visual.status=="source_native" and visual.visible and visual.actor.installed(),"exact source secondary actor installed")
		var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(actor_manifest.get_base_dir()+"/actors/12539.json"))
		var direction: int=posmod(int(world.player.motion.facing8)+3,8)
		var frame: Dictionary={}
		for source_frame: Dictionary in record.tracks.idle.directions[direction]:
			if int(source_frame.source_frame)==visual.actor.last_source_frame:frame=source_frame;break
		check(not frame.is_empty(),"displayed token comes from exact stored source direction")
		for i: int in range(frame.layers.size()):
			var image: Image=Image.load_from_file(actor_manifest.get_base_dir().path_join(str(frame.layers[i].path)))
			check(visual.actor._layers[i].texture.get_image().get_data()==image.get_data(),"source wood body/shadow exact pixels "+str(i))
		var node_id: int=visual.actor.get_instance_id()
		world._update_companion(.1);check(visual.actor.get_instance_id()==node_id,"frame update reuses existing actor and textures")
		check(visual.actor._playback_tracks.idle.timing_origin=="compat_user_approved_doll_shared_24_not_verified_M_default","reuses existing user-approved common doll clock")
		var cached: int=visual.actor._textures.size();var seen: Dictionary={}
		for step: int in range(4):world._update_companion(.2);seen[visual.actor.last_source_frame]=true
		check(seen.size()>1,"actual source actor advances multiple original poses")
		check(visual.actor._textures.size()==cached and visual.actor.get_instance_id()==node_id,"animation clock creates no new bulk textures or actor nodes")

		var stage:=CanvasLayer.new();stage.layer=1000;root.add_child(stage)
		visual.reparent(stage,false);visual.position=Vector2(427,270)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/source-wood-body-shadow.png")==OK,"capture real original secondary actor pixels")
		visual.reparent(world,false);stage.queue_free();world._update_companion(0)


	check(hash(world.card_draw_fusion.export_state())==owned_before and world.gold==money,"UI and visual state consume no card or currency")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/source-doll-subslot-854x480.png")==OK,"capture source controls")
	world.equipped_catalog["마법인형"]=chosen;world._update_companion(0)
	check(not world.option_awakening.subslot_view().active and world.secondary_doll_visual.status=="inactive","conflicting main card hides secondary actor")
	world.queue_free();await settle()
	print("NATIVE_DOLL_SUBSLOT_UI ",JSON.stringify({"checks":checks,"errors":errors,"fixture":"isolated XDG, ownership in memory only; no save"}));quit(0 if errors.is_empty() else 1)
