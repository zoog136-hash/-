extends SceneTree
## Full private source validation is opt-in and never embeds source rows.
const Source = preload("res://scripts/growth/half_elixir_source.gd")
const Runtime = preload("res://scripts/growth/half_elixir_runtime.gd")
var failures: Array = []
func _initialize() -> void:
	var path: String = OS.get_environment("TWILIGHT_HALF_ELIXIR_SOURCE")
	if path.is_empty(): printerr("A user-supplied 523 ZIP is required."); quit(2); return
	var source = Source.new()
	if not source.load_zip(path): printerr(source.problem); quit(1); return
	var visited: Dictionary = {}
	var profiles: Dictionary = {}
	for pair: String in source.pairs:
		var rules: Dictionary = source.profile(pair)
		if rules.size() != 37: failures.append("profile size")
		var ids: Array = rules.keys(); ids.sort(); profiles[JSON.stringify(ids)] = true
		var base: int = 0
		for id: String in rules:
			visited[id] = true
			base += int(rules[id].raw.DefaultMaxPoint)
			for before: int in source.costs:
				var after: int = int(source.costs[before].AfterExtendPoint)
				if not source.extensions.has(id + ":" + str(after)): failures.append("missing source coordinate")
		if base != source.constant("DefaultHalfElixirMaxPoint", pair): failures.append("source capacity mismatch")
	var unreachable: int = 0
	for row: Dictionary in source.extensions.values():
		if int(row.ElixirExtendPoint) > 50: unreachable += 1
	for id: String in source.rules:
		var rule: Dictionary = source.rules[id]
		if source.memberships.get(str(int(rule.raw.ServerLimitSetID)), {}).is_empty() and visited.has(id): failures.append("empty membership became global")
		var effect: Dictionary = source.effect(id, 1)
		if effect.type.is_empty() or effect.value <= 0: failures.append("missing typed effect")
	if profiles.size() != 4 or visited.size() != 138 or unreachable != 10: failures.append("source coverage mismatch")
	# The bundled 523 archive goes through the cold row reader; it must build
	# the same source as parsing every table whole.
	if source.sha == preload("res://scripts/resources/current523_definition_rows.gd").SOURCE_SHA:
		var whole = Source.new()
		if not whole.load_zip_whole(path): failures.append("whole parse failed: " + whole.problem)
		else:
			for field: String in ["sha", "pairs", "costs", "audits"]:
				if JSON.stringify(source.get(field)) != JSON.stringify(whole.get(field)): failures.append("cold " + field + " differs from whole parse")
			for group: String in ["rules", "charges", "resets", "currencies"]:
				var a: Dictionary = source.get(group)
				var b: Dictionary = whole.get(group)
				if JSON.stringify(a.keys()) != JSON.stringify(b.keys()): failures.append("cold " + group + " keys differ")
				for key: Variant in a:
					if JSON.stringify(a[key]) != JSON.stringify(b.get(key)): failures.append("cold " + group + " " + str(key) + " differs")
	print("HALF_ELIXIR_SOURCE_RESULT ", JSON.stringify({"audit":source.audits, "all_rules_checked":source.rules.size(), "reachable_rules":visited.size(), "unreachable_extra_coordinates":unreachable, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
