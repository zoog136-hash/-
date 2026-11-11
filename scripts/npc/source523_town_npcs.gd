extends RefCounted
## Original 523 town NPCs on a current523 source field and their original talk.
## Placement: EarthObjectSpawn -> its one-cell Territories row on the field's
## Land; identity: EarthObjectClass + DescData_Korean name ("title^name");
## functions: EarthObjectDialogActions -> DialogActionType.
## Talk text: DialogData_Korean rows named by data/npc/source523_npc_dialog_links.json
## (row identities only; the client tables have no NPC->dialog column, see
## tools/npc/build_source523_npc_dialog_links.py). Text is read from the
## installed original archive; nothing is invented when a link is missing.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const SPAWNS = preload("res://scripts/maps/current523_source_spawns.gd")
const LINKS_PATH: String = "res://data/npc/source523_npc_dialog_links.json"
const ID_PREFIX: String = "m523npc:"
const PLACEMENT: String = "EARTH_OBJECT_SPAWN_TERRITORY_CELL_V1"
## Online-only, event, rotating and cut content (clan, hideout, fishing, events).
const EXCLUDED_NAME_TAGS: Array[String] = ["[이벤트]", "[랜덤]", "[낚시]", "혈맹", "아지트", "[테스트]", "[미사용]", "할로윈"]
const EXCLUDED_CATEGORIES: Array[String] = ["AgitMerchant", "AgitTeleporter"]
## DialogActionType -> existing TWILIGHT service. Other action types (quest,
## buff, restore, agit, landmark) have no local owner and stay unconnected.
const ACTIONS: Dictionary = {"SellList": "shop", "BuyList": "buyback", "CraftList": "craft",
	"TeleportList": "teleport", "RequestTeleport": "teleport",
	"ShowCanStorageItems": "warehouse", "ShowCanPickupItems": "warehouse", "StorageItems": "warehouse",
	"PickupItems": "warehouse", "UseAccountStorage": "warehouse"}
const INTERACT_DISTANCE: float = 190.0
static var _links: Dictionary = {}
static var _links_loaded: bool = false

static func is_town_npc_id(id: String) -> bool:
	return id.begins_with(ID_PREFIX)

static func _first(table: String, id: int) -> Dictionary:
	# related() does not record a missing-ID problem in the shared reader.
	var found: Array[Dictionary] = DEF.related(table, "ID", id)
	return found[0] if found.size() == 1 else {}

static func _tagged(text: String) -> bool:
	for tag: String in EXCLUDED_NAME_TAGS:
		if text.contains(tag): return true
	return false

## "title^name" -> {name, title, display}; DialogData NPC name rows use "[title] name".
static func display_name(full: String) -> Dictionary:
	var parts: PackedStringArray = full.split("^")
	var name: String = parts[parts.size() - 1].strip_edges()
	var title: String = parts[0].strip_edges() if parts.size() > 1 else ""
	return {"name": name, "title": title, "display": ("[%s] %s" % [title, name]) if not title.is_empty() else name}

static func actions_for_class(class_id: int) -> Array[String]:
	var result: Array[String] = []
	var names: Dictionary = {}
	for row: Dictionary in DEF.rows("DialogActionType"): names[int(row.ID)] = str(row.Name)
	for link: Dictionary in DEF.related("EarthObjectDialogActions", "EarthObjectClassID", class_id):
		var action: String = str(ACTIONS.get(names.get(int(link.EarthActionTypeID), ""), ""))
		if not action.is_empty() and not result.has(action): result.append(action)
	return result

## Rebuilds field.data.npc_spawn from the original town NPC rows of its Land.
static func apply(field: Object) -> Dictionary:
	var summary: Dictionary = {"ok": false, "placed": 0, "skipped": {}, "placement_policy": PLACEMENT}
	if field == null or not field.get("data") is Dictionary: summary.reason = "no_field"; return summary
	field.data.npc_spawn = []
	var identity: Dictionary = SPAWNS.land_identity(field)
	if identity.is_empty() or DEF.row_count("EarthObjectSpawn") <= 0:
		summary.reason = "definition_unavailable"
		field.set_meta("current523_town_npc_summary", summary)
		return summary
	var land_id: int = int(identity.land_id)
	var bounds: Rect2i = field.get("source_bounds") if field.get("source_bounds") is Rect2i else Rect2i()
	var categories: Dictionary = {}
	for row: Dictionary in DEF.rows("EarthObjectCategory"): categories[int(row.ID)] = str(row.Name)
	var skipped: Dictionary = {}
	var cells: Dictionary = {}
	var placed: Array = []
	for index: int in DEF.row_count("EarthObjectSpawn"):
		var spawn: Dictionary = DEF.row_at("EarthObjectSpawn", index)
		var territory: Dictionary = _first("Territories", int(spawn.get("TerritoriesID", -1)))
		if territory.is_empty() or int(territory.get("LandID", -1)) != land_id: continue
		var reason: String = ""
		var object_class: Dictionary = _first("EarthObjectClass", int(spawn.get("EarthObjectClassID", -1)))
		var description: Dictionary = _first("DescData_Korean", int(object_class.get("DescID", -1))) if not object_class.is_empty() else {}
		var full_name: String = str(description.get("Description", ""))
		if object_class.is_empty() or full_name.is_empty(): reason = "class_or_name_missing"
		elif int(spawn.get("ServerLimitSetID", 0)) != 0: reason = "server_limited"
		elif spawn.get("SpawnManually") == true: reason = "spawn_manually"
		elif _tagged(str(spawn.get("Name", ""))) or _tagged(str(object_class.get("Name", ""))) or _tagged(full_name): reason = "excluded_content"
		elif EXCLUDED_CATEGORIES.has(str(categories.get(int(object_class.get("EarthObjectCategoryID", -1)), ""))): reason = "excluded_content"
		var cell := Vector2i((int(territory.StartX) + int(territory.EndX)) / 2, (int(territory.StartY) + int(territory.EndY)) / 2)
		if reason.is_empty() and bounds.has_area() and not bounds.has_point(cell): reason = "outside_field"
		if reason.is_empty() and cells.has(cell): reason = "same_cell"
		if not reason.is_empty():
			skipped[reason] = int(skipped.get(reason, 0)) + 1
			continue
		var point: Vector2 = field.coordinates.to_world(Vector2(cell.x, cell.y))
		if not point.is_finite(): skipped["invalid_point"] = int(skipped.get("invalid_point", 0)) + 1; continue
		cells[cell] = true
		var named: Dictionary = display_name(full_name)
		var actions: Array[String] = actions_for_class(int(object_class.ID))
		placed.append({"id": ID_PREFIX + str(int(spawn.ID)), "name": named.display, "role": actions[0] if not actions.is_empty() else "dialogue",
			"source523_earth_object_spawn_id": int(spawn.ID), "source523_earth_object_class_id": int(object_class.ID),
			"source523_category": str(categories.get(int(object_class.get("EarthObjectCategoryID", -1)), "")),
			"source523_sprite_id": int(object_class.get("SpriteID", 0)), "source523_actions": actions,
			"source_land_id": land_id, "source_position": [cell.x, cell.y], "position": [point.x, point.y],
			"placement_policy": PLACEMENT})
	field.data.npc_spawn = placed
	summary.placed = placed.size()
	summary.skipped = skipped
	summary.ok = true
	field.set_meta("current523_town_npc_summary", summary)
	return summary

static func _load_links() -> Dictionary:
	if _links_loaded: return _links
	_links_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINKS_PATH)) if FileAccess.file_exists(LINKS_PATH) else null
	if not parsed is Dictionary or parsed.get("schema") != "twilight.source523.npc-dialog-links.v1" or parsed.get("source_zip_sha256") != DEF.SOURCE_SHA: return _links
	for link: Variant in parsed.get("links", []):
		if link is Dictionary and link.get("pages") is Array: _links[int(link.get("earth_object_class_id", -1))] = link
	return _links

## Original talk pages of one EarthObjectClass: [{id, name, text}] (empty when unlinked).
static func pages_for_class(class_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var link: Dictionary = _load_links().get(class_id, {})
	for page: Variant in link.get("pages", []):
		if not page is Dictionary: continue
		var row: Dictionary = _first("DialogData_Korean", int(page.get("id", -1)))
		# The archive row must still carry the linked name: otherwise nothing is shown.
		if row.is_empty() or str(row.get("Name", "")) != str(page.get("name", "")):
			result.clear()
			return result
		result.append({"id": int(row.ID), "name": str(row.Name), "text": clean_text(str(row.get("Description", "")))})
	return result

## Original text markup (CRLF, <br></br>, <font ...>) as plain wrapped text.
static func clean_text(text: String) -> String:
	var value: String = text.replace("\r\n", "\n").replace("\r", "\n").replace("<br></br>", "\n").replace("<br/>", "\n").replace("<br>", "\n")
	var tags := RegEx.create_from_string("<[^>]*>")
	value = tags.sub(value, "", true)
	return value.strip_edges()

static func record(world: Node, npc_id: String) -> Dictionary:
	if not is_instance_valid(world) or world.get("field_map") == null: return {}
	for npc: Dictionary in world.field_map.data.get("npc_spawn", []):
		if str(npc.get("id", "")) == npc_id and npc.has("source523_earth_object_class_id"): return npc
	return {}

static func nearby(world: Node, npc: Dictionary) -> bool:
	if npc.is_empty() or not is_instance_valid(world.get("player")): return false
	var p: Array = npc.get("position", [])
	return p.size() == 2 and world.player.global_position.distance_to(Vector2(float(p[0]), float(p[1]))) <= INTERACT_DISTANCE

## One talk page: {ok, npc_id, npc_name, node_id, text, choices}. Page i links
## to page i+1; the last page carries the NPC's original function (if any).
static func resolve(world: Node, npc_id: String, node_id: String) -> Dictionary:
	var npc: Dictionary = record(world, npc_id)
	if npc.is_empty(): return {"ok": false, "reason": "원본 NPC가 아닙니다"}
	if not nearby(world, npc): return {"ok": false, "reason": "NPC와의 거리가 멉니다"}
	var pages: Array[Dictionary] = pages_for_class(int(npc.source523_earth_object_class_id))
	var index: int = 0
	if not node_id.is_empty():
		index = int(node_id.trim_prefix("p")) - 1 if node_id.begins_with("p") and node_id.trim_prefix("p").is_valid_int() else -1
		if index < 0 or index >= maxi(1, pages.size()): return {"ok": false, "reason": "등록되지 않은 대화 단계입니다"}
	var choices: Array = []
	var actions: Array = npc.get("source523_actions", [])
	if index + 1 < pages.size(): choices.append({"label": "", "next": "p%d" % (index + 2), "action": ""})
	elif not actions.is_empty(): choices.append({"label": "", "next": "", "action": str(actions[0])})
	var text: String = str(pages[index].text) if index < pages.size() else ""
	var player_name: Variant = world.get("character_name")
	if player_name is String and not str(player_name).is_empty(): text = text.replace("%user%", str(player_name))
	return {"ok": true, "npc_id": npc_id, "npc_name": str(npc.get("name", "")), "node_id": "p%d" % (index + 1),
		"text": text, "choices": choices, "source_dialog_rows": pages.map(func(page: Dictionary) -> int: return int(page.id)),
		"source_earth_object_class_id": int(npc.source523_earth_object_class_id), "text_basis": "DialogData_Korean" if not pages.is_empty() else "none"}

static func allowed_action(world: Node, npc_id: String, node_id: String, action: String) -> bool:
	var resolved: Dictionary = resolve(world, npc_id, node_id)
	for choice: Dictionary in resolved.get("choices", []):
		if str(choice.get("action", "")) == action: return true
	return false
