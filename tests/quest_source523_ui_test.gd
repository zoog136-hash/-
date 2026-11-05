extends SceneTree
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("QUEST523_UI_FAIL: "+label)
func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name_value: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://quest523-ui")
	var image: Image = root.get_texture().get_image()
	check(not image.is_empty() and image.save_png("user://quest523-ui/"+name_value+".png")==OK,"real OpenGL capture "+name_value)
func run() -> void:
	check(DisplayServer.get_name()!="headless","actual OpenGL display")
	var selected_pack: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--quest-pack="): selected_pack=argument.trim_prefix("--quest-pack=")
	check(not selected_pack.is_empty() and SOURCE.install_zip(selected_pack).ok,"local v1 ZIP installs through production installer")
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual class-selected Main")
	world.quest_auto.refresh_context(world)
	if world.quest_item_provider.ready:
		var pending: int=0
		for row: Dictionary in world.quest_service.entries(world.level,world.inventory):
			if row.get("source_id")!=null and row.completed and not row.rewards.get("pending_use",[]).is_empty():pending+=1
		var source_claims: int=0
		for id: String in world.quest_service.claimed:
			if id.begins_with("m523:quest:"):source_claims+=1
		check(source_claims==822 and pending==537 and world.quest_service.item_grants.is_empty(),"historical822 unreceipted save stays537 pending with installed consumer; no silent conversion")
		check(world.quest_item_provider.supported_held(world).is_empty(),"historical held items do not obtain fabricated receipt proof")
	check(world.quest_service.source.quests.size()==3621 and world.quest_service.source.loaded_path==SOURCE.USER_PATH,"Main consumes the installed complete user pack")
	var save_path: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(save_path)
	root.size=Vector2i(1280,720)
	world.hud.open_quests()
	await settle()
	var view: Control = world.hud.quest_view
	check(view!=null and view.listing.get_child_count()==30,"complete catalog is paginated to 30 cards")
	check(str(view.pack_status.text).contains("3621"),"full source input count shown")
	check(view.find_children("","Button",true,false).all(func(button: Button) -> bool: return not button.text.contains("보상 받기")),"no manual completion button remains")
	await capture("quests-1280x720")
	for category: String in ["common","achievement","other","main"]:
		view._select(category)
		check(view.selected==category and view.listing.get_child_count()<=30,"all original category rows reachable: "+category)
	view.search.text="236"
	view.refresh()
	check(view.listing.get_child_count()==1 and view.page_label.text.contains("1개"),"exact original ID search finds one quest")
	root.size=Vector2i(854,480)
	await settle()
	check(view.size.x<=world.hud.workspace.size.x+1,"quest panel width contained on 854px screen")
	check(view.listing.get_parent().size.y>=100,"small screen retains a readable scrolling quest area")
	await capture("quest-search-854x480")
	view.search.text=""
	view.state_filter.select(1)
	view.refresh()
	check(view.summary.text.contains("완료"),"completion filter with persisted native claims")
	view.search.text=""
	view.state_filter.select(4)
	view.refresh()
	check(view.listing.get_child_count()>0 and view.summary.text.contains("기존 완료 이력"),"legacy history is separate from native source counts")
	var bag: Variant = world.hud.lineage_inventory_ui
	bag.set_character_state(world.hud.character_state)
	bag.inventory=world.inventory
	var stack_entries: Array[Dictionary] = bag._inventory_entries()
	var matched: int = 0
	for entry: Dictionary in stack_entries:
		var id: String = bag._ref_instance_id(str(entry.reference))
		var instance: Dictionary = world.item_instances.get(id,{})
		if instance.has("source_reward_quantity"):
			check(int(entry.amount)==int(instance.source_reward_quantity),"physical original reward quantity shown in inventory")
			matched+=1
	check(matched>0,"actual source reward stacks exist in inventory UI")
	check(FileAccess.get_sha256(save_path)==save_sha,"browsing/searching source and inventory UI preserves save bytes")
	print("QUEST523_UI_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_quests":3621,"inventory_source_stacks":matched,"installed_sha256":FileAccess.get_sha256(SOURCE.USER_PATH)}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
