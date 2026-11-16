extends SceneTree
## 참고 스킬 근사 (6) — 받는 곳 추가 (data/skills/source_approx523.json receivers,
## player_skills523.APPROX_TARGET_FIELDS), docs/skill523_source_hold_report.md.
## With the original ZIP, in actual Main: skills held only because PierceMelee/RangeEvasion,
## MeleeDamageReductionPercent or a target AttackedMeleeDamageScale had no receiver now
## open, each with the new receiver among its rows; the total held count goes down.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SKILL523_RECEIVERS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func stats_of(record: Dictionary) -> Array:
	var out: Array = []
	var spec: Variant = record.get("source_approx523", {})
	if spec is Dictionary:
		for row: Variant in spec.get("rows", []):
			if row is Dictionary: out.append(str(row.get("stat","")))
	return out

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world, "기사"), "actual Main map entry")
	var catalog = world.original_skills.catalog
	var adapter = catalog.source523
	var opened: Dictionary = {}
	var blocked: int = 0
	for key: String in adapter.profiles:
		if not key.begins_with("lmref_"): continue
		var record: Dictionary = catalog.record_for(key)
		if record.get("runtime_blocked", false): blocked += 1; continue
		var name: String = "%s/%s" % [str(record.get("class","")), str(record.get("name",""))]
		var stats: Array = stats_of(record)
		if record.has("source_approx523_active"):
			var active: Dictionary = record.source_approx523_active
			var text: String = JSON.stringify(active)
			if text.contains("\"taken\""): opened[name] = ["taken"]
			elif text.contains("\"magicCrit\"") or text.contains("\"magicHit\""): opened[name] = ["magic"]
			elif text.contains("\"speed\""): opened[name] = ["speed"]
		elif stats.has("receivedReductionPct") or stats.has("meleeHit") or stats.has("rangedHit") or stats.has("magicCrit") or stats.has("magicHit") or stats.has("moveSpeedPct"):
			opened[name] = stats
	evidence["blocked"] = blocked
	evidence["opened"] = opened
	var reduction: Array = []; var pierce: Array = []; var taken: Array = []; var magic: Array = []
	for name: String in opened:
		if (opened[name] as Array).has("receivedReductionPct"): reduction.append(name)
		if (opened[name] as Array).has("taken"): taken.append(name)
		if (opened[name] as Array).has("magic") or (opened[name] as Array).has("magicCrit") or (opened[name] as Array).has("magicHit"): magic.append(name)
	for name: String in ["피어스 애로우","라이트닝 어택(미스틱)","세인트 블로우(디바인)"]:
		for key: String in opened:
			if key.ends_with("/"+name): pierce.append(key)
	evidence["groups"] = {"reduction":reduction,"pierce":pierce,"taken":taken,"magic":magic}
	check(blocked < 145, "held reference skills below 145 (근사 (8)): %d" % blocked)
	check(magic.size() >= 1, "MagicCritical / MagicHit open magic skills "+str(magic))
	check(reduction.size() >= 2, "MeleeDamageReductionPercent opens 받는 피해 % 감소 skills "+str(reduction))
	check(pierce.size() >= 1, "Pierce*Evasion opens accuracy skills "+str(pierce))
	check(taken.size() >= 1, "AttackedMeleeDamageScale gives a 'taken' target debuff "+str(taken))
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else:
		var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/source_approx523.json"))
		check(policy.receivers.has("PierceMeleeEvasion") and policy.receivers.has("MeleeDamageReductionPercent") and policy.receivers.has("MagicCritical") and policy.receivers.has("FixedMoveSpeedBonus"), "receivers declared")
	print("SKILL523_RECEIVERS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
