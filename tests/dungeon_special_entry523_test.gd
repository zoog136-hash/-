extends SceneTree
## 특수 던전 (시간 던전) entry regression (user report 2026-11-22 "던전 입장 안
## 됨, 시간만 지나감"): entering moves into the dungeon's original Land, the
## cost and the time pool are charged only with a completed move, time drains
## only inside the Land (not across a pause or a closed game), 나가기 and an
## empty pool return to the village, leaving the Land ends the session, a
## dungeon whose map bundle is not installed is refused with its reason and
## nothing charged, and old saves get back the base time of fake sessions.
## 1) Fixture: dungeon_play_service over a recording host (always, CI).
## 2) Actual Main (when the original 523 ZIP is installed): every special
##    dungeon is entered; with the 523 map pack each one moves into its Land and
##    returns, without it each one is refused with nothing charged.
const PLAY = preload("res://scripts/dungeons/dungeon_play_service.gd")
const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("DUNGEON_SPECIAL_ENTRY523_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

## Recording host with the members dungeon_play_service reads for special runs.
class Host extends Node:
	const DUNGEON_RUNS = preload("res://scripts/dungeons/dungeon_run_service.gd")
	var gold: int = 1000000
	var level: int = 60
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var active_map_id: String = "aden_world"
	var source_dungeon_runs: RefCounted = RefCounted.new()
	var player: Node = null
	var hud: Node
	var land: int = 4
	var land_ready_map: Dictionary = {}
	var move_ok: bool = true
	var saved: Array = []
	var moves: Array = []
	var returns: int = 0
	var messages: Array = []
	func dungeon523_land_ready(land_id: int) -> String:
		return str(land_ready_map.get(land_id, ""))
	func dungeon523_enter_land(land_id: int, bounds: Array, save: Dictionary) -> Dictionary:
		moves.append([land_id, bounds])
		if not move_ok: return {"ok": false, "reason": "도착 셀 없음"}
		saved.append(save.duplicate(true))
		if save.has("gold"): gold = int(save.gold)
		land = land_id
		return {"ok": true, "saved": true}
	func orim_current_land() -> Dictionary:
		return {"land_id": land, "cell": [10, 10]}
	func dungeon523_return_to_village() -> Dictionary:
		returns += 1; land = 4
		return {"ok": true}
	func commit_dungeon_play(candidate: Dictionary, changes: Dictionary) -> Error:
		saved.append({"source_dungeon_play": candidate.duplicate(true)})
		if changes.has("gold"): gold = int(changes.gold)
		return OK
	func _update_hud() -> void: pass
	func _invalidate_equipment_static() -> void: pass

class Hud extends Node:
	var messages: Array = []
	func show_message(text: String) -> void: messages.append(text)

class Runs extends RefCounted:
	var state: Dictionary = {"active": {}}

## The projection shape of source_dungeon_projection._special for the rows used here.
class Rules extends RefCounted:
	var special_by_id: Dictionary = {}
	var time_by_id: Dictionary = {}
	func stage(_kind: String, _id: int) -> Dictionary: return {}

static func entry(id: int, land: int, group: int, cost: int, min_level: int, max_level: int = 0, boxes: int = 1) -> Dictionary:
	var destinations: Array = []
	for b: int in boxes:
		destinations.append({"link": {}, "place": {"territory": {"LandID": land, "StartX": 32600 + b * 10, "StartY": 32800, "EndX": 32605 + b * 10, "EndY": 32805}, "land": {"ID": land}, "time_groups": [{"row": {"ID": group}}]}})
	var pre: Array = [{"type": "MinLevel", "row": {"Value": min_level}}]
	if max_level > 0: pre.append({"type": "MaxLevel", "row": {"Value": max_level}})
	return {"row": {"ID": id}, "teleport": {"CurrencyID": 1, "TeleportCost": cost}, "currency": {"name": "아데나"}, "destinations": destinations, "prerequisites": pre}

func fixture() -> void:
	check(PAYMENT._OVERRIDE_KEYS.has("source_dungeon_play"), "the dungeon session may be saved with the arrival")
	var host := Host.new()
	host.hud = Hud.new(); host.add_child(host.hud)
	host.source_dungeon_runs = Runs.new()
	root.add_child(host)
	var rules := Rules.new()
	# Original rows: 41 버림받은 자들의 땅 (Land 22701, group 61, 10000, Lv55),
	# 51 몽환의 섬 (22801, group 81, five boxes, Lv60), 324 엘모어 (MaxLevel 84),
	# 999 a dungeon whose map bundle is not installed.
	var rows: Array = [entry(41, 22701, 61, 10000, 55), entry(51, 22801, 81, 10000, 60, 0, 5), entry(324, 51094, 32544, 10000, 45, 84), entry(999, 77777, 999, 10000, 1)]
	for e: Dictionary in rows:
		rules.special_by_id[int(e.row.ID)] = e
		var g: int = int(e.destinations[0].place.time_groups[0].row.ID)
		rules.time_by_id[g] = {"row": {"ID": g, "TimeLimit": 3600, "MaxRechargeTime": 7200}, "reset": {"Name": "Daily"}}
	host.land_ready_map[77777] = "설치된 리소스 팩에 이 던전 지도가 없어 입장할 수 없습니다."
	var play = PLAY.new()
	play.configure(host, rules)
	var now: int = 1800000000
	# Every entrable dungeon: move -> charged with the move -> drains inside -> back.
	for id: int in [41, 51]:
		var gold: int = host.gold
		var e: Dictionary = rules.special_by_id[id]
		var g: String = str(int(e.destinations[0].place.time_groups[0].row.ID))
		var before: int = int(play.pool(int(g), now).base)
		var r: Dictionary = play.begin("special", id, now)
		check(r.get("ok", false) and r.get("travel", false), "%d enters (moves into its Land) %s" % [id, str(r)])
		check(host.land == int(e.destinations[0].place.land.ID) and play.state.active.get("land", -1) == host.land, "%d is inside its original Land" % id)
		check(host.gold == gold - 10000, "%d entry cost charged once with the move" % id)
		check(host.saved[-1].has("source_dungeon_play") and host.saved[-1].has("gold"), "%d cost and session saved together with the arrival" % id)
		check(int(play.state.pools[g].base) == before, "%d nothing drained at the moment of entry" % id)
		for s: int in range(1, 13): play.tick(1.0, now + s)
		check(int(play.state.pools[g].base) == before - 10, "%d inside: drained 10 s and saved at the 10-second step (base %d)" % [id, int(play.state.pools[g].base)])
		check(play.special_left(now + 12) == before - 12, "%d remaining time counts the unsaved seconds" % id)
		# A pause / closed game: the gap is not dungeon time.
		play.tick(1.0, now + 500)
		for s: int in range(501, 513): play.tick(1.0, now + s)
		check(int(play.state.pools[g].base) >= before - 24 and int(play.state.pools[g].base) <= before - 20, "%d a 488-second gap is not charged (base %d)" % [id, int(play.state.pools[g].base)])
		var returns: int = host.returns
		check(play.stop(now + 513).get("ok", false) and play.state.active.is_empty(), "%d 나가기 closes the session" % id)
		check(host.returns == returns + 1 and host.land == 4, "%d 나가기 returns to the village" % id)
		now += 1000
	check(host.moves[1][1][0] >= 32600 and host.moves[1][1][2] - host.moves[1][1][0] == 5, "the landing box is the LandTeleportTerritories box")
	# Time over: back to the village.
	var gold2: int = host.gold
	check(play.begin("special", 41, now).get("ok", false), "re-entry")
	var p61: Dictionary = play.state.pools["61"]
	var next: Dictionary = play.state.duplicate(true); next.pools["61"].base = 3; next.pools["61"].bonus = 0
	play.commit(next)
	for s: int in range(1, 6): play.tick(1.0, now + s)
	check(play.state.active.is_empty() and int(play.state.pools["61"].base) == 0 and host.land == 4 and host.returns >= 3, "an empty pool returns to the village")
	check(str(play.special_note).contains("소진"), "time-over message")
	check(not play.begin("special", 41, now + 10).get("ok", false) and host.gold == gold2 - 10000, "an empty pool refuses entry before any charge")
	now += 1000
	# Leaving the Land (귀환 주문서, death) ends the session without a return.
	check(play.begin("special", 51, now).get("ok", false), "entry before leaving")
	var base81: int = int(play.state.pools["81"].base)
	host.land = 4
	var returns2: int = host.returns
	for s: int in range(1, 4): play.tick(1.0, now + s)
	check(play.state.active.is_empty() and host.returns == returns2, "leaving the Land ends the session (no forced return)")
	check(int(play.state.pools["81"].base) >= base81 - 3, "nothing charged after leaving")
	now += 1000
	# Refusals: nothing charged, no move.
	var gold3: int = host.gold
	var moves: int = host.moves.size()
	var r999: Dictionary = play.begin("special", 999, now)
	check(not r999.ok and str(r999.reason).contains("지도가 없어") and host.gold == gold3 and host.moves.size() == moves and play.state.active.is_empty() and not play.state.pools.has("999"), "a dungeon without its map is refused with the reason, nothing charged")
	check(not play.special_block(rules.special_by_id[999]).is_empty() and play.special_block(rules.special_by_id[41]).is_empty(), "the window lock reads the same reason")
	host.level = 85
	var r324: Dictionary = play.begin("special", 324, now)
	check(not r324.ok and host.gold == gold3 and host.moves.size() == moves, "MaxLevel 84 refuses Lv85, nothing charged")
	host.move_ok = false
	var base41: int = int(play.pool(61, now).base)
	var rfail: Dictionary = play.begin("special", 41, now)
	check(not rfail.ok and host.gold == gold3 and play.state.active.is_empty() and int(play.pool(61, now).base) == base41, "a failed move charges neither the cost nor the time")
	host.move_ok = true
	# Old saves: a fake session (no Land) is closed and the base time returned.
	var old: Dictionary = PLAY.empty_state()
	old.erase("special_travel_v1")
	old.day = play.day(now)
	old.pools = {"61": {"period": play.period(rules.time_by_id[61], now), "base": 100, "bonus": 50}, "81": {"period": 1, "base": 0, "bonus": 0}}
	old.active = {"kind": "special", "id": "special:9", "stage_id": 41, "map_id": "aden_world", "status": "active", "started": now - 3500, "last": now - 3500, "duration": 0, "seed": 1, "cursor": 0, "remaining_count": 0, "groups": [61], "buffs": {}, "events": {}, "rewards": [], "issued": {}, "rerolls": 0, "reroll_stat": ""}
	check(play.restore(old), "old save restores")
	check(play.state.active.is_empty() and int(play.state.pools["61"].base) == 3600 and int(play.state.pools["61"].bonus) == 50, "fake session closed, today's base time given back, bonus kept")
	check(int(play.state.pools["81"].base) == 0, "an old period is left to the daily reset")
	check(bool(play.state.special_travel_v1) and not play.migrate_special_sessions(now), "migration runs once")
	evidence["fixture"] = {"moves": host.moves.size(), "returns": host.returns}
	host.queue_free()
	await process_frame

## Actual Main: every special row of world.source_dungeon_entries("special").
func actual() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for i: int in 20: await process_frame
	var play = world.dungeon_play
	var saved_state: Dictionary = play.state.duplicate(true)
	var saved_gold: int = world.gold
	var saved_level: int = world.level
	var rows: Array = world.source_dungeon_entries("special")
	var source_field: bool = bool(world.current523_aden_play_active)
	var home: int = int(world.orim_current_land().get("land_id", -1)) if source_field else -1
	var table: Array = []
	for e: Dictionary in rows:
		var id: int = int(e.row.ID)
		var min_level: int = 1; var max_level: int = 0
		for req: Dictionary in e.prerequisites:
			if req.type == "MinLevel": min_level = maxi(min_level, int(req.row.Value))
			if req.type == "MaxLevel": max_level = int(req.row.Value)
		world.level = max_level if max_level > 0 else maxi(min_level, 85)
		world.gold = 10000000
		var gold: int = world.gold
		var groups: Array = []
		for g: Dictionary in e.destinations[0].place.time_groups: groups.append(str(int(g.row.ID)))
		var r: Dictionary = play.begin("special", id, -1)
		var row: Dictionary = {"id": id, "ok": r.get("ok", false), "reason": str(r.get("reason", ""))}
		if r.get("ok", false):
			var here: int = int(world.orim_current_land().get("land_id", -1))
			row["land"] = here
			check(here == int(play.state.active.land) and here in PLAY.special_lands(e), "%d moved into its Land %d" % [id, here])
			check(world.gold == gold - int(e.teleport.TeleportCost) or int(e.teleport.CurrencyID) != 1, "%d entry cost charged" % id)
			var left0: int = play.special_left()
			var t0: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 2200: await process_frame
			check(play.special_left() < left0 or left0 == 0, "%d time runs inside (%d -> %d)" % [id, left0, play.special_left()])
			check(play.stop().get("ok", false) and play.state.active.is_empty(), "%d 나가기" % id)
			for f: int in 10: await process_frame
			row["back"] = int(world.orim_current_land().get("land_id", -1))
			check(int(row.back) == 4, "%d returned to the village (Land %d)" % [id, int(row.back)])
		else:
			check(world.gold == gold and play.state.active.is_empty(), "%d refused without any charge: %s" % [id, row.reason])
			if source_field: check(not row.reason.is_empty(), "%d refusal names its reason" % id)
		table.append(row)
	evidence["actual"] = {"source_field": source_field, "home": home, "rows": table}
	# Restore what this test changed (CI shares user://).
	play.state = saved_state
	world.gold = saved_gold; world.level = saved_level
	check(world._save_game(true) == OK, "state restored and saved")
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	await fixture()
	if not SOURCE.not_installed(): await actual()
	print("DUNGEON_SPECIAL_ENTRY523_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)
