extends SceneTree
## Server-limited item paths (card items, skill books, draw tickets and shop
## offers through the shop server check, monster book card awards) are checked
## against one server profile: the declared card-collection context, otherwise
## the offline Korean world 1 profile. A set opens only when its original
## ServerLimit rows name that region and world; a set without rows stays
## closed. Without the pinned 523 tables only the profile rules run; with
## TWILIGHT_PATCH523_CONTENT the real sets and the projection are checked.
const SERVER = preload("res://scripts/loot/current523_server_profile.gd")
const MAP_CONTEXT = preload("res://scripts/maps/current523_map_runtime_context.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class Collections extends RefCounted:
	var context: Dictionary = {}
	func source_server_context() -> Dictionary: return context

class Host extends Node:
	var card_collections: Collections = Collections.new()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void: call_deferred("run")

func rules(host: Host) -> void:
	check(SERVER.profile(null) == MAP_CONTEXT.OFFLINE_PROFILE and SERVER.profile(host) == MAP_CONTEXT.OFFLINE_PROFILE, "no declared context: offline Korean world 1")
	host.card_collections.context = {"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":7}
	check(SERVER.profile(host).WorldNo == 7, "a declared card-collection context wins")
	host.card_collections.context = {"source_snapshot":"base508","ServiceRegionCode":"","WorldNo":7}
	check(SERVER.profile(host) == MAP_CONTEXT.OFFLINE_PROFILE, "an invalid declared context falls back to the offline profile")
	host.card_collections.context = {}
	var rows: Array = [{"ServiceRegionCode":"KR","WorldNo":2.0},{"ServiceRegionCode":"KR","WorldNo":1.0}]
	check(SERVER.rows_allow(rows, "KR", 1) and not SERVER.rows_allow(rows, "KR", 3) and not SERVER.rows_allow(rows, "TW", 1), "a set allows exactly the region and world its rows name")
	check(not SERVER.rows_allow([], "KR", 1), "a set without rows allows nothing")
	check(SERVER.allows(host, 0).ok and not SERVER.allows(host, -1).ok and not SERVER.allows(host, 1.5).ok, "set 0 is unrestricted; malformed sets are refused")

func table(host: Host) -> void:
	var by_set: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ServerLimit"):
		var key: int = int(row.ServerLimitSetID)
		if not by_set.has(key): by_set[key] = []
		by_set[key].append(row)
	var kr1: int = -1; var other: int = -1
	for key: int in by_set:
		var named: bool = SERVER.rows_allow(by_set[key], "KR", 1)
		if named and kr1 < 0: kr1 = key
		if not named and other < 0: other = key
	check(kr1 > 0 and SERVER.allows(host, kr1).ok, "an original set naming KR world 1 opens for the offline profile")
	check(other > 0 and not SERVER.allows(host, other).ok, "an original set for other servers stays closed")
	var missing: int = 1
	while by_set.has(missing): missing += 1
	check(not SERVER.allows(host, missing).ok, "a set without original rows stays closed")
	# Card items that were blocked only for server context now project usable.
	var opened: int = 0; var listed: int = 0
	for line: String in FileAccess.get_file_as_string(argument("--server-cards=")).split("\n", false):
		if not line.strip_edges().is_valid_int(): continue
		listed += 1
		var spec: Dictionary = FIELDS.full(D.definition_id(line.strip_edges()).get("native_record", {})).get("source_use_spec", {})
		if spec.get("kind") == "fixed_card" and spec.get("activation_status") == "unrestricted" and int(spec.get("server_limit_set_id", 0)) != 0 and SERVER.allows(host, spec.server_limit_set_id).ok: opened += 1
	evidence["server_cards"] = {"listed":listed,"opened":opened}
	if listed > 0: check(opened == listed, "every server-limited card item naming KR world 1 projects usable and passes the profile")

func run() -> void:
	var host := Host.new()
	root.add_child(host)
	rules(host)
	if not SOURCE.not_installed(): table(host)
	host.queue_free()
	print("CURRENT523_SERVER_PROFILE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
