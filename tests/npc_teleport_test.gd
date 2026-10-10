extends SceneTree
const POLICY = preload("res://scripts/npc/teleport_policy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, why: String) -> void:
	if not ok:
		failures.append(why)
		printerr("NPC_TELEPORT_FAIL: " + why)

func _run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json"))
	_check(raw is Array, "source maps parse")
	var by_id: Dictionary = {}
	if raw is Array:
		for value: Variant in raw:
			if value is Dictionary:
				var entry: Dictionary = value as Dictionary
				by_id[str(entry.get("id",""))] = entry
	_check(by_id.size() == 25, "exactly 25 existing map IDs preserved")
	for id: String in by_id.keys():
		var rule: Dictionary = POLICY._rule(id)
		var quote: Dictionary = POLICY.quote(id,by_id,"not_current",100,100000)
		_check(bool(quote.get("ok",false)), "all 25 real destinations selectable: " + id)
		_check(int(rule.get("price",-1)) >= 0 and int(rule.get("min_level",0)) > 0, "valid money/level gate: " + id)
		_check(int(quote.get("price",-1)) == int(rule.get("price",-2)), "same policy for display and execution")
		_check(not bool(POLICY.quote(id,by_id,id,100,100000).get("ok")), "reject same destination")
		if int(rule["price"]) > 0:
			_check(not bool(POLICY.quote(id,by_id,"not_current",100,int(rule["price"])-1).get("ok")), "reject insufficient Adena: " + id)
		if int(rule["min_level"]) > 1:
			_check(not bool(POLICY.quote(id,by_id,"not_current",int(rule["min_level"])-1,100000).get("ok")), "reject lower level: " + id)
	_check(not bool(POLICY.quote("__made_up__",by_id,"aden_world",100,100000).get("ok")), "reject forged destination")
	var original_npc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	_check(original_npc is Dictionary, "original Aden field parses")
	if original_npc is Dictionary:
		var present: bool = false
		var existing: Dictionary = {}
		for row: Variant in (original_npc as Dictionary).get("npc_spawn",[]):
			if row is Dictionary:
				var v: Dictionary = row as Dictionary
				existing[str(v.get("id",""))] = v
				if v.get("id","") == "teleport_guide":
					present = str(v.get("role","")) == "teleport"
		_check(present, "NPC teleport guide connected in actual Aden field")
		_check(existing.has("merchant") and existing.has("warden") and existing.has("warehouse_keeper"), "existing NPCs preserved")
		var position: Variant = existing.get("merchant",{}).get("position",[])
		var unchanged: bool = position is Array and position.size() == 2
		if unchanged:
			unchanged = is_equal_approx(float(position[0]),1980.0) and is_equal_approx(float(position[1]),3840.0)
		_check(unchanged, "merchant original coordinates unchanged")
	if failures.is_empty():
		print("NPC_TELEPORT_OK: 25 maps, costs, level gates, forged IDs and preserved NPC placement")
		quit(0)
	else:
		print("NPC_TELEPORT_FAILED: %d failures" % failures.size())
		quit(1)
