extends SceneTree
## Original 523 town NPC talk: the link file holds row identities only (never
## text), pages advance one by one and the last page carries the NPC's original
## function, distance is checked, and TWILIGHT's own dialogue data is gone.
const TOWN = preload("res://scripts/npc/source523_town_npcs.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

class FakeField extends RefCounted:
	var data: Dictionary = {"npc_spawn": []}

class FakeWorld extends Node:
	var field_map: FakeField = FakeField.new()
	var player: Node2D = Node2D.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

func _initialize() -> void:
	var links: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOWN.LINKS_PATH))
	check(links is Dictionary and links.get("schema") == "twilight.source523.npc-dialog-links.v1" and links.get("source_zip_sha256") == DEF.SOURCE_SHA and links.get("text_in_file") == false, "link file identity")
	var only_ids: bool = links is Dictionary and links.get("links") is Array and not links.links.is_empty()
	if only_ids:
		for link: Variant in links.links:
			if not link is Dictionary or typeof(link.get("earth_object_class_id")) != TYPE_FLOAT or not link.get("pages") is Array or link.pages.is_empty(): only_ids = false; break
			for page: Variant in link.pages:
				if not page is Dictionary or page.keys().size() != 2 or typeof(page.get("id")) != TYPE_FLOAT or not page.get("name") is String: only_ids = false
	check(only_ids, "links carry only class id -> DialogData id + Name (no text)")
	check(TOWN.display_name("꽃다발 상인^샤론").display == "[꽃다발 상인] 샤론" and TOWN.display_name("게시판").display == "게시판", "original title^name display")
	check(TOWN.clean_text("가\r\n나<br></br><font color =\"#cccccc\" size=\"30\">은</font>") == "가\n나\n은", "original markup becomes plain text")
	for path: String in ["res://scripts/npc/dialogue_service.gd", "res://scripts/npc/source_npc_catalog.gd", "res://data/npc/twilight_dialogues.json", "res://data/npc/source_six_dialogues.json", "res://data/npc/source_six.json"]:
		check(not FileAccess.file_exists(path), "own dialogue data removed: " + path)
	var world := FakeWorld.new()
	root.add_child(world)
	world.add_child(world.player)
	world.field_map.data.npc_spawn = [{"id": "m523npc:1", "name": "[잡화상인] 세린", "position": [100.0, 100.0], "source523_earth_object_class_id": 2147480000, "source523_actions": ["shop"]}]
	world.player.global_position = Vector2(120, 100)
	var page: Dictionary = TOWN.resolve(world, "m523npc:1", "")
	check(page.get("ok") == true and page.node_id == "p1" and page.npc_name == "[잡화상인] 세린" and page.text == "" and page.text_basis == "none", "an unlinked NPC shows its original name and no invented text")
	check(page.get("choices") == [{"label": "", "next": "", "action": "shop"}], "the last page carries the original function")
	check(TOWN.allowed_action(world, "m523npc:1", "p1", "shop") and not TOWN.allowed_action(world, "m523npc:1", "p1", "warehouse"), "only the NPC's own function is allowed")
	check(not TOWN.resolve(world, "m523npc:1", "p2").get("ok", false) and not TOWN.resolve(world, "other", "").get("ok", false), "unknown page or NPC is refused")
	world.player.global_position = Vector2(1000, 100)
	check(not TOWN.resolve(world, "m523npc:1", "").get("ok", false) and not TOWN.allowed_action(world, "m523npc:1", "p1", "shop"), "distance is checked again")
	if DEF.row_count("DialogData_Korean") > 0:
		var pages: Array[Dictionary] = TOWN.pages_for_class(186)
		check(pages.size() == 3 and pages[0].name == "NPC_CL_POU_DIALOG_PA1" and not str(pages[0].text).is_empty(), "installed archive: multi-page original talk")
		world.field_map.data.npc_spawn[0].source523_earth_object_class_id = 186
		world.player.global_position = Vector2(120, 100)
		var first: Dictionary = TOWN.resolve(world, "m523npc:1", "")
		var last: Dictionary = TOWN.resolve(world, "m523npc:1", "p3")
		check(first.choices == [{"label": "", "next": "p2", "action": ""}] and last.choices == [{"label": "", "next": "", "action": "shop"}] and last.text == pages[2].text, "installed archive: pages then function")
	world.queue_free()
	print("SOURCE523_TOWN_NPCS: %d checks, %d failures %s" % [checks, failures.size(), JSON.stringify(failures)])
	if not failures.is_empty(): print("SOURCE523_TOWN_NPCS_FAIL")
	quit(0 if failures.is_empty() else 1)
