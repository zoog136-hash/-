extends SceneTree
const Native = preload("res://scripts/cards/native_collection_rules.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func _run() -> void:
	var path: String = "res://data/lineagem_base508/cards.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--native-cards="): path = argument.trim_prefix("--native-cards=")
	if not FileAccess.file_exists(path): push_error("Required canonical native card catalog missing: " + path); quit(2); return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).catalog
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/base508_collections.json"))
	var core = Native.new()
	check(core.configure(data, catalog), "all native rows configure: " + core.error)
	check(core.definitions.size() == 1736, "1736 source sets retained")
	var counts: Dictionary = {}; var member_count: int = 0; var effect_count: int = 0
	var all_owned: Dictionary = {}; var old_numeric: Dictionary = {}
	for category: String in Cards.CATEGORIES:
		all_owned[category] = {}; old_numeric[category] = {}
		for record: Dictionary in catalog[category]:
			all_owned[category][Cards.card_id(record)] = true
			old_numeric[category]["source:"+str(record.source_card_id)] = true
	for row: Dictionary in core.definitions:
		counts[row.category] = int(counts.get(row.category, 0)) + 1
		member_count += row.requirements.size(); effect_count += row.effects.size()
	check(counts == {"변신":814,"마법인형":484,"성물":438}, "source category counts")
	check(member_count == 4906 and effect_count == 1982, "exact member/reward rows")
	var checked_percent: bool = false; var checked_ac: bool = false
	for definition: Dictionary in core.definitions:
		for effect: Dictionary in definition.effects:
			var native: Dictionary = effect.source_original
			if effect.unit=="percent" and effect.native_supported and native.unit.Name=="Percentage":
				check(is_equal_approx(float(effect.value),float(native.bonus.Value)/float(native.ui_unit.Denominator)), "UIUnit denominator produces percentage points"); checked_percent = true
			if effect.key=="ac":
				check(float(effect.value)==-float(native.bonus.Value), "source defensive power maps to signed local AC"); checked_ac = true
	check(checked_percent and checked_ac, "real source percentage and AC cases verified")
	var empty: Dictionary = core.derive({"owned":{}})
	check(empty.completed.is_empty() and empty.totals.is_empty(), "no owned cards grants no bonus")
	var legacy: Dictionary = core.derive({"owned":old_numeric})
	check(legacy.completed.is_empty() and legacy.rows.all(func(r: Dictionary) -> bool:return r.met_count==0), "old numeric IDs never alias native IDs")
	var owned_before: int = hash(all_owned)
	var full: Dictionary = core.derive({"owned":all_owned,"spare":{},"option_awakening":{"all":true}})
	var again: Dictionary = core.derive({"owned":all_owned,"spare":{"변신":{"irrelevant":999999}}})
	check(hash(all_owned) == owned_before, "derivation does not alter owned ledger")
	check(full.totals == again.totals and full.completed == again.completed, "idempotent rewards; duplicates/option awakening do not alter native completion")
	var blocked: int = 0; var available: int = 0; var chosen: Dictionary = {}
	for row: Dictionary in full.rows:
		if not row.available:
			blocked += 1; check(not row.completed, "blocked source context never rewards " + str(row.id))
		else:
			available += 1
			if chosen.is_empty(): chosen = row
		if row.problems.has("native_awakening_required"):
			check(not row.conditions_met, "native awakening not implied by ownership " + str(row.id))
	check(available > 0 and not chosen.is_empty(), "verified unconditional supported sets available")
	var one_data: Dictionary = data.duplicate(true); one_data.collections = [chosen]
	var one = Native.new(); check(one.configure(one_data,catalog), "isolated genuine source set configures")
	var owned: Dictionary = {}; owned[chosen.category] = {}
	for requirement: Dictionary in chosen.requirements: owned[chosen.category][requirement.id] = true
	var completed: Dictionary = one.derive({"owned":owned})
	check(completed.completed.size() == 1 and not completed.totals.is_empty(), "exact native members apply genuine source reward once")
	owned[chosen.category].erase(chosen.requirements[0].id)
	var removed: Dictionary = one.derive({"owned":owned})
	check(removed.completed.is_empty() and removed.totals.is_empty(), "missing required member removes derived reward")
	one_data.collections[0].requirements[0].source_original.BuffCardID = -77
	check(not Native.new().configure(one_data,catalog), "corrupt BuffCardID join fails closed")
	print(JSON.stringify({"checks":checks,"failures":failures,"native_sets":1736,"available_supported_sets":available,"blocked_sets":blocked,"all_owned_derived_totals":full.totals}))
	quit(0 if failures.is_empty() else 1)
