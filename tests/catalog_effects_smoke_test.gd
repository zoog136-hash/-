extends SceneTree

const RULES = preload("res://scripts/catalog_effects.gd")
var failures: Array[String] = []

func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		print("CATALOG_EFFECTS_FAIL: " + detail)

func _record(data: Dictionary, category: String, name_value: String) -> Dictionary:
	for value: Variant in data.get(category, []) as Array:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == name_value:
			return value as Dictionary
	return {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	if not (parsed is Dictionary):
		_check(false, "game database invalid")
		_finish()
		return
	var data: Dictionary = parsed as Dictionary
	var mythic: Dictionary = _record(data, "변신", "신화-기사(여)")
	var unique_transform: Dictionary = _record(data, "변신", "해방된 할파스")
	var dragon: Dictionary = _record(data, "변신", "드래곤 슬레이어")
	var bugbear: Dictionary = _record(data, "변신", "버그베어")
	var lindvior: Dictionary = _record(data, "마법인형", "린드비오르")
	var drake: Dictionary = _record(data, "마법인형", "드레이크")
	var succubus: Dictionary = _record(data, "마법인형", "서큐버스퀸")
	var shield: Dictionary = _record(data, "성물", "군터의 방패")
	var lodemai: Dictionary = _record(data, "성물", "로데마이의 검")
	var wing: Dictionary = _record(data, "성물", "라이아의 구두")
	var relic: Dictionary = _record(data, "성물", "지배자 기르타스의 뿔")
	for item: Dictionary in [mythic, unique_transform, dragon, bugbear, lindvior, drake, succubus, shield, lodemai, wing, relic]:
		_check(not item.is_empty(), "missing reference catalog record")
	_check(absf(RULES.attack_speed_percent(mythic) - 170.0) < 0.001, "mythic attack speed 170%")
	_check(absf(RULES.attack_speed_percent(unique_transform) - 190.0) < 0.001, "unique attack speed 190%")
	_check(absf(RULES.attack_speed_percent(bugbear) - 4.0) < 0.001, "common transform attack speed 4%")
	_check(absf(RULES.attack_speed_percent({"attackSpeed":12.0,"desc":"공격 속도 +170%"}) - 12.0) < 0.001, "typed attack speed takes precedence")
	_check(RULES.attack_speed_percent(lindvior) == 0.0, "vague doll attack speed must not be fabricated")
	_check(RULES.damage_by_style(dragon, "melee") == 3, "dragon melee bonus")
	_check(RULES.damage_by_style(dragon, "ranged") == 3, "dragon ranged bonus")
	_check(RULES.damage_by_style(dragon, "magic") == 0, "dragon description excludes magic")
	_check(RULES.damage_by_style(drake, "melee") == 0, "ranged doll must not grant melee bonus")
	_check(RULES.damage_by_style(drake, "ranged") == 2, "ranged doll grants +2 only once")
	_check(RULES.damage_by_style(drake, "magic") == 0, "ranged doll must not grant magic bonus")
	_check(RULES.damage_by_style(lodemai, "melee") == 2, "melee relic bonus")
	_check(RULES.damage_by_style(lodemai, "ranged") == 0, "melee relic must not boost ranged damage")
	_check(RULES.damage_by_style(wing, "ranged") == 2, "ranged relic bonus")
	_check(RULES.flat_reduction(shield) == 0, "do not invent unquantified relic reduction")
	_check(RULES.unresolved_description(succubus), "unknown MP recovery effect must remain flagged")
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main.tscn unavailable")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})
	var melee_before: int = int(world.call("_melee_damage_stat"))
	var ranged_before: int = int(world.call("_ranged_damage_stat"))
	var magic_before: int = int(world.call("_magic_damage_stat"))
	var speed_before: float = float(world.call("_effective_attack_speed_bonus_percent"))
	world.set("equipped_catalog", {"변신": mythic, "마법인형":{}, "성물":{}})
	_check(absf(float(world.call("_effective_attack_speed_bonus_percent")) - speed_before - 170.0) < 0.001, "transform attack speed must affect runtime")
	_check(int(world.call("_melee_damage_stat")) == melee_before + 5, "melee mythic grants attack +5")
	_check(int(world.call("_ranged_damage_stat")) == ranged_before, "melee transform must not affect ranged damage")
	world.set("equipped_catalog", {"변신":{}, "마법인형":drake, "성물":lodemai})
	_check(int(world.call("_melee_damage_stat")) == melee_before + 2, "melee relic +2 with ranged doll not double counted")
	_check(int(world.call("_ranged_damage_stat")) == ranged_before + 2, "ranged doll +2 with melee relic not double counted")
	_check(int(world.call("_magic_damage_stat")) == magic_before, "specialized records do not give magic bonus")
	world.set("equipped_catalog", {"변신":dragon, "마법인형":{}, "성물":{}})
	_check(int(world.call("_melee_damage_stat")) == melee_before + 3, "dual-style transform melee +3")
	_check(int(world.call("_ranged_damage_stat")) == ranged_before + 3, "dual-style transform ranged +3")
	_check(int(world.call("_magic_damage_stat")) == magic_before, "dual-style transform excludes magic")
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":relic})
	_check(absf(float(world.call("_experience_multiplier")) - 1.3) < 0.001, "relic XP +30% remains applied")
	_check(int(world.call("_effective_max_hp")) > int(world.get("max_hp")), "relic max HP bonus remains applied")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CATALOG_EFFECTS_SMOKE_OK: transformation, doll, relic and unknown-effect boundaries verified")
		quit(0)
	else:
		print("CATALOG_EFFECTS_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
