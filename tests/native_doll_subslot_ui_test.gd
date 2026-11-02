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
	var folder: String="";var private_root: String="";var manifest: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--private-ui-root="):private_root=arg.trim_prefix("--private-ui-root=")
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--effect-manifest="):manifest=arg.trim_prefix("--effect-manifest=")
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
		if Cards.card_id(record)=="source:m508:2:40":chosen=record
		elif int(record.source_grade_id)==3 and main.is_empty():main=record
	check(not chosen.is_empty() and not main.is_empty(),"exact source doll fixtures")
	if chosen.is_empty() or main.is_empty():world.queue_free();quit(1);return
	world.card_draw_fusion.owned["마법인형"][Cards.card_id(chosen)]=true;world.card_draw_fusion.owned["마법인형"][Cards.card_id(main)]=true
	world.equipped_catalog["마법인형"]=main;world.level=95;world.player.original_source_manifest=manifest
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
	check(is_instance_valid(world.secondary_doll_visual) and world.secondary_doll_visual.status=="source_asset_pending" and not world.secondary_doll_visual.visible,"overlay-only fixture pack never generates a replacement actor")
	check(hash(world.card_draw_fusion.export_state())==owned_before and world.gold==money,"UI and visual state consume no card or currency")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/source-doll-subslot-854x480.png")==OK,"capture source controls")
	world.equipped_catalog["마법인형"]=chosen;world._update_companion(0)
	check(not world.option_awakening.subslot_view().active and world.secondary_doll_visual.status=="inactive","conflicting main card hides secondary actor")
	world.queue_free();await settle()
	print("NATIVE_DOLL_SUBSLOT_UI ",JSON.stringify({"checks":checks,"errors":errors,"fixture":"isolated XDG, ownership in memory only; no save"}));quit(0 if errors.is_empty() else 1)
