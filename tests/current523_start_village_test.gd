extends SceneTree
## 사용자 결정 2026-11-17 "시작지점을 아덴마을이 아닌 기란으로" (docs/START_VILLAGE523.md,
## scripts/maps/current523_start_village.gd). Always: the start village is the
## one point every own village fallback uses (controller return point, host
## spawn, tutorial and old-map relocation). With the original definition ZIP the
## Giran point is re-derived from the original Locations / TerritoriesVillage
## rows. The real-pack Main proof (new character in Giran, blocked/stranded
## spot recovery to Giran, 523 return to Giran) is current523_long_teleport_test.
const START_VILLAGE = preload("res://scripts/maps/current523_start_village.gd")
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const TUTORIAL = preload("res://scripts/content523/tutorial523.gd")
const RELOCATION = preload("res://scripts/maps/old_map_save_relocation523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CURRENT523_START_VILLAGE_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func synthetic() -> void:
	check(START_VILLAGE.LOCATION == {"ID":473,"Name":"[리스타트 좌표] 기란 마을","LandID":4,"X":33441,"Y":32813}, "Giran start = Locations473")
	check(START_VILLAGE.source_position() == [33441.5, 32813.5] and START_VILLAGE.cell() == Vector2i(33441, 32813), "cell-centre source position")
	check(START_VILLAGE.cursor() == {"native_land_id":4, "source_position":[33441.5, 32813.5]}, "character cursor")
	check(START_VILLAGE.in_village(START_VILLAGE.cell()) and START_VILLAGE.in_village(Vector2i(33332, 32630)) and START_VILLAGE.in_village(Vector2i(33548, 32900)), "the point is inside TerritoriesVillage1367")
	check(not START_VILLAGE.in_village(Vector2i(33923, 33350)) and not START_VILLAGE.in_village(Vector2i(33331, 32813)), "Aden town / outside cells are not Giran")
	check(START_VILLAGE.ENTRY_WAIVE == ["ObjectLazyLoad"], "only the village's client lazy-load hint is waived on entry")
	# Every own fallback reads the same point.
	check(CONTROLLER.ADEN_RETURN_LOCATION.ID == 473 and CONTROLLER.ADEN_RETURN_POLICY == START_VILLAGE.POLICY, "controller return point is Giran")
	check(CONTROLLER.village_source_position() == START_VILLAGE.source_position(), "held-spot restart uses Giran")
	var tutorial: Dictionary = TUTORIAL.migrate_save({"character_source_cursor":{"native_land_id":44502,"source_position":[1,2]},"inventory":{}})
	check(tutorial.character_source_cursor == START_VILLAGE.cursor(), "tutorial relocation targets Giran")
	var old: Dictionary = RELOCATION.relocated({"map_id":"faith_01","position":[1.0,2.0]})
	check(old.character_source_cursor == START_VILLAGE.cursor() and old.position == [], "old-map relocation targets Giran")
	# A normal saved spot is not a relocation candidate.
	var normal: Dictionary = {"map_id":"aden_world","position":[10.0,20.0],"character_source_cursor":{"native_land_id":4,"source_position":[33923.5,33350.5]}}
	check(not TUTORIAL.needed(normal) and not RELOCATION.needed(normal, true, false), "an existing normal save position is left alone")

func derived() -> void:
	var location: Array[Dictionary] = SOURCE.rows_matching("Locations", "ID", {473:true})
	check(location.size() == 1, "original Locations473 exists")
	if location.size() == 1:
		var row: Dictionary = location[0]
		evidence["location473"] = row
		check(str(row.get("Name","")) == START_VILLAGE.LOCATION.Name and int(row.LandID) == 4 and int(row.X) == START_VILLAGE.LOCATION.X and int(row.Y) == START_VILLAGE.LOCATION.Y, "constant equals the original row")
	var village: Array[Dictionary] = SOURCE.rows_matching("TerritoriesVillage", "ID", {1367:true})
	check(village.size() == 1, "original TerritoriesVillage1367 exists")
	if village.size() == 1:
		var row: Dictionary = village[0]
		evidence["village1367"] = row
		check(bool(row.get("IsVillage", false)) and int(row.LandID) == 4 and int(row.StartX) == START_VILLAGE.VILLAGE_TERRITORY.StartX and int(row.EndX) == START_VILLAGE.VILLAGE_TERRITORY.EndX \
			and int(row.StartY) == START_VILLAGE.VILLAGE_TERRITORY.StartY and int(row.EndY) == START_VILLAGE.VILLAGE_TERRITORY.EndY, "village bounds equal the original row")
	# Original Giran town NPC Locations sit around the start point.
	var near: int = 0
	for id: int in [265, 268, 306, 338, 703, 814]:
		var rows: Array[Dictionary] = SOURCE.rows_matching("Locations", "ID", {id:true})
		if rows.size() == 1 and str(rows[0].Name).begins_with("[기란]") and maxi(absi(int(rows[0].X) - START_VILLAGE.LOCATION.X), absi(int(rows[0].Y) - START_VILLAGE.LOCATION.Y)) <= 20: near += 1
	evidence["giran_npc_locations_within_20"] = near
	check(near == 6, "six original Giran NPC Locations within 20 cells (%d)" % near)

func run() -> void:
	synthetic()
	if not SOURCE.not_installed(): derived()
	else: evidence["derived"] = "original definition ZIP not installed: table part skipped"
	print("CURRENT523_START_VILLAGE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
