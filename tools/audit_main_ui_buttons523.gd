extends SceneTree
## Open original feature windows and actual HUD menu routes on a disposable
## character. Records mounted callbacks and fallback reasons. No purchase,
## reward claim, card choice or enhancement is performed by this audit.
const QA = preload("res://tests/qa_class_selection.gd")
var output: FileAccess
var buttons := {}
var pack: RefCounted

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].ends_with(".jsonl") or FileAccess.file_exists("user://twilight_v20_save.json") or OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty():
		printerr("Provide a fresh user directory, selected original UI and private JSONL output path")
		quit(1)
		return
	output = FileAccess.open(args[0],FileAccess.WRITE)
	if output==null:
		quit(2)
		return
	root.size=Vector2i(2048,919)
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	world.save_timer=-100000
	if not QA.enter_game(world):
		quit(3)
		return
	await process_frame
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	var hud: Node=world.hud
	var controller: Node=hud.original_main_ui_controller
	pack=controller._pack
	if pack==null or pack.manifest_sha256!=OS.get_environment("TWILIGHT_SOURCE_UI_SHA256"):
		quit(4)
		return
	record_buttons(controller._coordinates,"field")
	hud.toggle_inventory()
	await process_frame
	record_buttons(controller._coordinates,"inventory")
	hud.toggle_inventory()
	var optional := {"card_collection":["변신"],"card_fusion":["변신"]}
	var results := {}
	for key: String in controller.FEATURE_WINDOWS:
		var script: Script=controller.FEATURE_WINDOWS[key]
		var arguments: Array=optional.get(key,[])
		var required := 0
		for method: Dictionary in script.get_script_method_list():
			if method.name=="open":required=method.args.size()-method.default_args.size()-1
		if required>arguments.size():
			results[key]="needs contextual entry"
			continue
		var result: Dictionary=controller.try_open_feature_window(key,arguments)
		results[key]="opened" if result.get("handled",false) else str(result.get("code",result.get("error","unavailable")))
		if result.get("handled",false):
			await process_frame
			record_buttons(controller.feature_window(key)._scene,key)
			controller.feature_window(key).close()
			await process_frame
	# These screens are entered through dedicated HUD methods instead of
	# FEATURE_WINDOWS. The next open follows the same close path as play.
	var hud_entries := {
		"quest_window":"open_quests", "shop_window":"open_shop",
		"storage_window":"open_warehouse", "teleport_window":"open_npc_teleport",
		"production_window":"open_crafting", "stat_detail_window":"open_detailed_status",
		"clan_window":"open_clan523", "emblem_window":"open_clan_emblem523",
		"domination_window":"open_domination_stone", "skill_window":"open_skills",
		"dungeon_window":"open_source_dungeons", "refine_window":"open_refine523"
	}
	for key: String in hud_entries:
		hud.call(hud_entries[key])
		await process_frame
		var view: RefCounted=controller.get("_"+key)
		if view!=null and view.is_open():
			results[key]="opened"
			record_buttons(view._scene,key)
		else:
			results[key]="original window did not open"
		hud._close_workspace()
		await process_frame
	var navigation: Dictionary=await audit_navigation(hud,controller,world)
	for values: Dictionary in buttons.values(): output.store_line(JSON.stringify(values))
	output.close()
	print("UI_BUTTON_RESULT ",JSON.stringify({"distinct_button_nodes":buttons.size(),"first_screen":results,"hud_navigation":navigation}))
	world.queue_free()
	await process_frame
	quit()

func audit_navigation(hud: Node, controller: Node, world: Node) -> Dictionary:
	# [original window key, dedicated controller instance if there is one].
	# An empty entry identifies a direct TWILIGHT route.
	var entries: Dictionary={
		"inventory":["inventory","_inventory_view"], "character":["character_equipment","_character_view"],
		"skills":["skill_window","_skill_window"], "quests":["quest_window","_quest_window"],
		"shop":["shop_window","_shop_window"], "warehouse":["storage_window","_storage_window"],
		"teleport":["teleport_window","_teleport_window"], "crafting":["production_window","_production_window"],
		"enhance":["enchant_window","_enchant_window"], "refine523":["refine_window","_refine_window"],
		"domination_stone":["domination_window","_domination_window"], "status_board":["status_board","_status_board"],
		"clan523":["clan_window","_clan_window"], "source_dungeons":["dungeon_window","_dungeon_window"],
		"content523":["dungeon_window","_dungeon_window"],
		"변신":["change_window","_change_window"], "마법인형":["change_window","_change_window"],
		"성물":["change_window","_change_window"], "아이템":[],
		"card_fusion":["card_fusion"], "card_collections":["card_collection"],
		"skill_card523":["skill_cards"], "card_swap523":["card_change"],
		"quick_change523":["quick_change"], "quick_summon523":["quick_summon"],
		"equipment_collections":["item_book"], "weapon_mastery":["weapon_mastery"],
		"guardians":["guardians"], "emblems":["emblems"], "titles":["titles"],
		"half_elixir":["half_elixir"], "totems":["totems"], "monsterbook523":["monsterbook"],
		"auto":["schedule"], "settings":["options"], "promo_code":["options"],
		"tj_coupons":["tj_coupons"], "doll_explore":["doll_explore"], "forge523":["forge"],
		"equipment523":[], "bless_refine523":["refine_window","_refine_window"], "combinations":[], "growth96":[],
		"exchange":["trade"], "sell":[], "field_activities523":[], "log":["combat_log"], "class_select":[]
	}
	var results: Dictionary={}
	for section: String in entries:
		hud._navigate(section)
		await process_frame
		results[section]=route_result(hud,controller,entries[section],section)
		hud._close_workspace()
		await process_frame
	# Re-enter with a pending slot, as when opening the menu after a reload.
	# The fixture creates no success, debit or changed on-disk growth state.
	var growth: Object=world.growth
	var before: Dictionary=growth.state.duplicate(true)
	for group: Dictionary in growth.config.get("guardians",[]):
		var nodes: Array=group.get("nodes",[])
		if nodes.is_empty() or int(nodes[0].get("cards",0))<2:continue
		var slot: String=nodes[0].id
		var count: int=int(nodes[0].cards)
		growth.state.searches[slot]={"cards":count,"winner":0,"failed":[],"attempts":0}
		growth.state.pending={"node":slot,"cards":count}
		var pending: Dictionary=growth.state.duplicate(true)
		hud._navigate("guardians")
		await process_frame
		var result: Dictionary=route_result(hud,controller,["guardian_find"],"guardians_pending")
		result["same_pending_state"]=growth.state==pending
		results["guardians_pending"]=result
		hud._close_workspace()
		growth.state=before
		break
	return results

func route_result(hud: Node, controller: Node, entry: Array, section: String) -> Dictionary:
	if entry.is_empty():return local_presentation(hud,"direct_hud_route")
	var key: String=entry[0]
	var view: Variant=controller.get(entry[1]) if entry.size()>1 else controller.feature_window(key)
	var opened: bool=view is Object and view.has_method("is_open") and view.is_open()
	var status_key: String=key if entry.size()>1 else key+"_window"
	var status: Dictionary=hud.original_main_ui_status.get(status_key,{})
	if key=="inventory":opened=controller.inventory_is_open()
	elif key=="character_equipment":opened=controller.character_is_open()
	if opened:
		var scene: Variant=view.get("_scene") if view is RefCounted else view
		if scene is Node:record_buttons(scene,section)
		return {"presentation":"original","view":key}
	var local: Dictionary = local_presentation(hud,str(status.get("code",status.get("error","not_mounted"))))
	local["view"] = key
	return local

func local_presentation(hud: Node, reason: String) -> Dictionary:
	if not hud.workspace.visible:return {"presentation":"no_window","reason":reason}
	var frame: StyleBox = hud.workspace.get_theme_stylebox("panel")
	var source: Dictionary = frame.get_meta("original_ui_source",{})
	if frame is StyleBoxTexture and frame.texture != null and not source.is_empty():
		return {"presentation":"original_chrome","reason":reason,"frame":source.frame,"source_offset":source.node_offset}
	return {"presentation":"twilight","reason":reason}

func record_buttons(node: Node, screen: String) -> void:
	if node==null or node.is_queued_for_deletion():return
	var identity: Variant=node.get_meta("original_ui_source",{})
	var button: Variant=node.get_meta("source_button") if node.has_meta("source_button") else (node.get_meta("source_checkbox") if node.has_meta("source_checkbox") else null)
	if is_instance_valid(button) and identity is Dictionary and identity.has("node_offset"):
		var member: String=identity.scene
		var key: String=member+"#"+str(identity.node_offset)
		var row: Dictionary=buttons.get(key,{"member":member,"offset":identity.node_offset,"sha256":pack.manifest.files[member].sha256,"actions":{}})
		var callback: Callable=button._activation
		var method: String=str(callback.get_method()) if callback.is_valid() else ""
		var owner: Object=callback.get_object() if callback.is_valid() else null
		var script: Script=owner.get_script() if owner!=null else null
		var route: String=screen+"|"+(script.resource_path.get_file() if script!=null else "")+"|"+method
		row.actions[route]=bool(row.actions.get(route,false)) or button._input_available()
		buttons[key]=row
	for child: Node in node.get_children():record_buttons(child,screen)
