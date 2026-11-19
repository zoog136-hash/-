extends SceneTree
## A tapped original 523 town NPC opens its function window directly, with no
## NpcDialogue talk (user request 2026-11-19 "Npc는 누르면 대화 안나오고 바로
## 상점 매뉴로 들어가게해"): shop first, then storage, teleport, craft,
## buyback, death recovery, quest; an NPC that only talks shows its name.
## The tap reads no DialogData_Korean (talk text is not loaded).
## Without the original 523 map only the rules run; with it the actual Main
## Giran NPCs are tapped through the world tap path.
const TOWN = preload("res://scripts/npc/source523_town_npcs.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const GIRAN := Vector2i(33441, 32813)
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakeField extends RefCounted:
	var data: Dictionary = {"npc_spawn": []}

class FakeWorld extends Node:
	var field_map: FakeField = FakeField.new()
	var player: Node2D = Node2D.new()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); printerr("NPC_DIRECT_OPEN_FAIL: " + label)
	return ok

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var world := FakeWorld.new()
	root.add_child(world); world.add_child(world.player)
	world.field_map.data.npc_spawn = [
		{"id":"m523npc:1","name":"[잡화상인] 세린","position":[100.0,100.0],"source523_earth_object_class_id":1,"source523_actions":["teleport","shop"]},
		{"id":"m523npc:2","name":"[창고지기] 하딘","position":[100.0,100.0],"source523_earth_object_class_id":2,"source523_actions":["warehouse"]},
		{"id":"m523npc:3","name":"[퀘스트] 안내원","position":[100.0,100.0],"source523_earth_object_class_id":3,"source523_actions":["quest"]},
		{"id":"m523npc:4","name":"[주민] 말만 함","position":[100.0,100.0],"source523_earth_object_class_id":4,"source523_actions":[]}]
	world.player.global_position = Vector2(120, 100)
	check(TOWN.primary_action(world, "m523npc:1") == "shop", "an NPC with several functions opens the shop first")
	check(TOWN.primary_action(world, "m523npc:2") == "warehouse" and TOWN.primary_action(world, "m523npc:3") == "quest", "storage and quest NPCs open their own window")
	check(TOWN.primary_action(world, "m523npc:4") == "" and TOWN.primary_action(world, "other") == "", "a talk-only or unknown NPC opens nothing")
	world.player.global_position = Vector2(1000, 100)
	check(TOWN.primary_action(world, "m523npc:1") == "", "distance is still checked")
	check(DEF.PREPARE_ON_DEMAND_ONLY.has("DialogData_Korean"), "NPC talk text is not converted on the loading screen")
	check(TOWN.ACTIONS.get("QuestAccept") == "quest" and TOWN.ACTIONS.get("RestoreItemsAndExps") == "restore" and TOWN.ACTIONS.get("SellList") == "shop", "original DialogActionType rows map to the windows")
	world.queue_free()

func tap(world: Node, npc: Dictionary) -> void:
	var at := Vector2(float(npc.position[0]), float(npc.position[1]))
	world.player.global_position = at + Vector2(20, 0)
	await process_frame
	world.hud.message_label.text = ""
	world._set_click_destination(at)
	for frame: int in 4: await process_frame

func main_part() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual Main class confirmation")
	var save_path: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.save_timer = -100000
	for frame: int in 900:
		await process_frame
		if world.current523_aden_source_active(): break
	if not world.current523_aden_source_active():
		evidence["main"] = "original 523 map not installed: Main part skipped"
		world.queue_free(); await process_frame
		if not had_save and FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)
		return
	var here: Dictionary = world.orim_current_land()
	if int(here.get("land_id", -1)) != 4 or absi(int(here.cell[0]) - GIRAN.x) > 30 or absi(int(here.cell[1]) - GIRAN.y) > 30:
		world.call("_aden_play_controller").enter_source_land(4, [GIRAN.x - 5, GIRAN.y - 5, GIRAN.x + 5, GIRAN.y + 5], world.ITEM523_TELEPORT_WAIVE.duplicate())
		for frame: int in 60: await process_frame
	var picked: Dictionary = {}
	for npc: Dictionary in world.field_map.data.get("npc_spawn", []):
		var at: Array = npc.get("source_position", [])
		if not TOWN.is_town_npc_id(str(npc.get("id",""))) or at.size() != 2 or absi(int(at[0]) - GIRAN.x) > 80 or absi(int(at[1]) - GIRAN.y) > 80: continue
		var actions: Array = npc.get("source523_actions", [])
		var kind: String = "shop" if actions.has("shop") else ("warehouse" if actions.has("warehouse") else ("teleport" if actions.has("teleport") else ("none" if actions.is_empty() else "")))
		if not kind.is_empty() and not picked.has(kind): picked[kind] = npc
	evidence["giran_npcs"] = picked.keys()
	check(picked.has("shop"), "Giran has an original merchant")
	var expected: Dictionary = {"shop":["npc_shop","store_window"],"warehouse":["warehouse","storage_window"],"teleport":["teleport","teleport_window"]}
	var results: Dictionary = {}
	for kind: String in picked:
		var npc: Dictionary = picked[kind]
		world.hud.call("_close_workspace"); world.hud.original_main_ui_status.erase("npc_dialogue")
		for frame: int in 2: await process_frame
		await tap(world, npc)
		var status: Dictionary = world.hud.original_main_ui_status
		results[kind] = {"npc":npc.name,"section":world.hud.active_section,"message":world.hud.message_label.text,"native":status.get(expected.get(kind,["",""])[1],{}).get("handled",false)}
		check(not status.has("npc_dialogue") and str(world.hud.active_section) != "dialogue", "no talk window for " + kind)
		if expected.has(kind): check(str(world.hud.active_section) == expected[kind][0], "tap opens the %s window directly (%s)" % [kind, str(results[kind])])
		else: check(str(world.hud.message_label.text) == str(npc.name), "a talk-only NPC shows only its name")
		var store: Object = world.hud.original_main_ui_controller.get("_store_window") if is_instance_valid(world.hud.original_main_ui_controller) else null
		if store != null and store.has_method("is_open") and store.is_open(): store.close()
	evidence["taps"] = results
	check(not DEF._tables.has("DialogData_Korean"), "tapping NPCs loads no DialogData_Korean")
	world.hud.call("_close_workspace")
	world.queue_free(); await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if "--main" in OS.get_cmdline_user_args(): await main_part()
	print("NPC_DIRECT_OPEN_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
