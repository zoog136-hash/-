extends SceneTree

const SKILL_OPTIONS = preload("res://scripts/transform_skill_options.gd")
const VISIBILITY = preload("res://scripts/card_option_visibility.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("CARD_SPECIAL_POLICY_FAIL: " + label)

func _find(data: Dictionary, category: String, name_value: String) -> Dictionary:
	for value: Variant in (data.get(category, []) as Array):
		if value is Dictionary and str((value as Dictionary).get("name", "")) == name_value:
			return value as Dictionary
	return {}

func _run() -> void:
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	if not (content is Dictionary):
		_check(false, "catalog cannot parse")
		_finish()
		return
	var data: Dictionary = content as Dictionary
	var counts: Dictionary = {"변신":413, "마법인형":166, "성물":144}
	for cat: String in counts:
		var cards: Array = data.get(cat, []) as Array
		_check(cards.size() == int(counts[cat]), "category count " + cat)
		for entry: Variant in cards:
			if not (entry is Dictionary):
				_check(false, "invalid card in " + cat)
				continue
			var record: Dictionary = entry as Dictionary
			var options: Array = record.get("sourceOptions", []) as Array
			_check(str(record.get("desc", "")) == " · ".join(PackedStringArray(options)), "description diverged: " + str(record.get("name", "")))
			for value: Variant in options:
				var option: String = str(value)
				_check(not option.begins_with("발동:"), "retired proc still visible: " + option)
				_check(not option.begins_with("발동 :"), "retired alternate proc: " + option)
				_check(not option.begins_with("전용 스킬:"), "retired exclusive spell: " + option)
				_check(not option.begins_with("액티브 스킬:"), "retired active spell: " + option)
				if cat == "변신":
					_check(not option.begins_with("시전 속도"), "old cast-speed label remains")
					_check(not option.begins_with("차징 시간 감소"), "removed charging option remains")
					_check(not option in ["어비스 쉐도우", "콜 오브 데스", "암흑 면역", "생명 +1", "죽음 +1"], "removed named option: " + option)
					_check(not option.begins_with("드래곤 추가 대미지"), "removed dragon damage remains")
					_check(not option.begins_with("MP 절대 회복"), "removed absolute recovery remains")
					_check(not option.begins_with("출혈 적중"), "removed bleed accuracy remains")
				elif cat == "성물":
					_check(option != "얼티밋 그로우스", "removed unique relic spell remains")
	var transform: Array = data["변신"] as Array
	var changed: int = 0
	for value: Variant in transform:
		var record: Dictionary = value as Dictionary
		if float(record.get("skillCooldownPct", 0.0)) > 0.0:
			changed += 1
			_check((record.get("sourceOptions",[]) as Array).has("스킬 쿨타임 감소 +%d%%" % int(record["skillCooldownPct"])), "missing converted cooldown description")
	_check(changed == 375, "375 transformation cooldown conversions preserved")
	var halphas: Dictionary = _find(data, "변신", "해방된 할파스")
	var wizard: Dictionary = _find(data, "변신", "신화-마법사(남)")
	var knight: Dictionary = _find(data, "변신", "신화-기사(남)")
	var elf: Dictionary = _find(data, "변신", "신화-요정(여)")
	var sentinel: Dictionary = _find(data, "변신", "파아그리오의 수호자")
	var linds: Dictionary = _find(data, "마법인형", "린드비오르")
	var demon: Dictionary = _find(data, "마법인형", "할파스")
	var lineage: Dictionary = _find(data, "성물", "지배자 기르타스의 뿔")
	var spell: Dictionary = _find(data, "성물", "진명황의 보주")
	_check(SKILL_OPTIONS.amount(halphas,"요정","트리플 애로우","damage_flat") == 15.0, "halphas elf skill +15")
	_check(SKILL_OPTIONS.amount(halphas,"총사","트리플 애로우","damage_flat") == 0.0, "class gate prevents wrong elf skill bonus")
	_check(SKILL_OPTIONS.amount(elf,"요정","트리플 애로우(스피릿)","damage_flat") == 10.0, "spirit triple arrow +10")
	_check(SKILL_OPTIONS.amount(wizard,"마법사","디스인티그레이트","damage_flat") == 300.0, "wizard base damage +300")
	_check(SKILL_OPTIONS.amount(wizard,"마법사","디스인티그레이트(에이션트)","damage_flat") == 300.0, "ancient upgrade bonus is not doubled")
	_check(SKILL_OPTIONS.amount(knight,"기사","쇼크 스턴","accuracy_pct") == 15.0, "knight stun bonus +15")
	_check(SKILL_OPTIONS.amount(knight,"마법사","쇼크 스턴","damage_flat") == 0.0, "status accuracy never gives damage")
	_check(absf(float(halphas.get("skillCooldownPct",0.0)) - 25.0) < 0.01, "halphas cast-speed => -25 cooldown")
	_check(VISIBILITY.unresolved("변신","속성 치명타 +2%",sentinel), "elemental crit must display unimplemented")
	_check(VISIBILITY.unresolved("변신","불 속성 대미지 +2",sentinel), "element-specific damage must display unimplemented")
	_check(not VISIBILITY.unresolved("마법인형","축복 소모량 감소 +25%",linds), "doll blessing consumption reduction is now applied")
	_check(VISIBILITY.unresolved("마법인형","디스펠 면역",demon), "doll dispel immunity remains pending")
	_check(VISIBILITY.unresolved("성물","일반 ~ 신화 스킬 레벨+1",lineage), "relic skill-level pending")
	_check(VISIBILITY.unresolved("성물","스킬 쿨타임 감소10%",spell), "relic unverified cooldown remains pending in raw card")
	var runtime: PackedScene = load("res://Main.tscn") as PackedScene
	if runtime != null:
		var world: Node = runtime.instantiate()
		root.add_child(world)
		await process_frame
		await process_frame
		world.set("equipped_catalog", {"변신":halphas,"마법인형":{},"성물":{}})
		_check(absf(float(world.call("_skill_cooldown_factor")) - 0.75) < 0.001, "transformation cooldown active in real world")
		world.set("job_class", "요정")
		_check(float(world.call("_transformation_skill_bonus","트리플 애로우","damage_flat")) == 15.0, "real world skill modifier connected")
		world.set("job_class", "마법사")
		_check(float(world.call("_transformation_skill_bonus","트리플 애로우","damage_flat")) == 0.0, "real world class gate connected")
		world.queue_free()
		await process_frame
	else:
		_check(false, "cannot load Main.tscn")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CARD_SPECIAL_POLICY_OK: source, C skill bonuses, cooldown, pending visibility and runtime")
		quit(0)
	else:
		print("CARD_SPECIAL_POLICY_FAILED: %d failed" % failures.size())
		quit(1)
