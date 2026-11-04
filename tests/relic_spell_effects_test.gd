extends SceneTree
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const EFFECTS = preload("res://scripts/cards/relic_spell_effects.gd")
const STATUS = preload("res://scripts/skills/status_service.gd")
var checks: int = 0
var failures: Array[String] = []
var records: Dictionary = {}
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RELIC_EFFECT_FAIL ", message)
func projected(id: String, character_level: int = 90, enabled: bool = true, bonus: int = 1) -> Dictionary:
	return EFFECTS.project(records[id].duplicate(true), RULES._rules.spell_profiles[id], {"effective_level":bonus, "bonus":bonus, "code":"ready"}, character_level, enabled)
func delta(id: String, field: String, character_level: int = 90) -> float:
	for entry: Dictionary in projected(id, character_level).relic_spell_effect.applied:
		if entry.field == field: return float(entry.delta)
	return 0.0
func _initialize() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="): path = arg.trim_prefix("--source-zip=")
	if not RULES.load_source(path).get("ok", false): printerr("Verified source required"); quit(2); return
	var master: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/master.json"))
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/balance.json"))
	for row: Dictionary in master.records:
		var record: Dictionary = row.duplicate(true)
		for key: String in balance.skills.get(str(row.id), {}): record[key] = balance.skills[row.id][key].value
		records[str(row.id)] = record
	var connected: int = 0
	var pending: int = 0
	for id: String in RULES._rules.spell_profiles:
		var profile: Dictionary = RULES._rules.spell_profiles[id]
		check(EFFECTS.identity_matches(records[id], profile), "exact host identity " + id)
		var original: Dictionary = records[id].duplicate(true)
		var inert: Dictionary = projected(id, 90, true, 0)
		inert.erase("relic_spell_effect")
		check(inert == original, "no relic preserves all host fields " + id)
		var disabled: Dictionary = projected(id, 90, false)
		disabled.erase("relic_spell_effect")
		check(disabled == original, "disabled skill cannot gain effects " + id)
		var active: Dictionary = projected(id)
		check(EFFECTS.needs_buff_refresh(records[id]) == bool(active.relic_spell_effect.buff_level_changes), "pack-independent buff recovery flag matches native curves " + id)
		for field: String in ["mp", "hp", "items", "cooldown", "cast_time", "trigger", "weapons", "id", "name"]:
			check(active.get(field) == original.get(field), "source delta preserves " + field + " " + id)
		if not active.relic_spell_effect.applied.is_empty(): connected += 1
		if not active.relic_spell_effect.pending.is_empty(): pending += 1
	check(delta("lm_e8236ca60328dd0a", "power") == 5, "Ice Spike native40 to45 adds exactly5")
	check(delta("lm_a67dae07b4f0608a", "power") == 6, "Hell Scythe70 to76 adds6")
	check(delta("lm_0fa8b37f33c7f9d6", "mana") == 1 and delta("lm_9f4be293cf774c31", "mana") == 1, "two MP conversions add1")
	for character_level: int in [1, 59, 60, 69, 70, 79, 80, 89, 90, 99]:
		check(delta("lm_cd78ab3abe724dd9", "hp", character_level) == 50, "HP tier replacement, not sum " + str(character_level))
	check(delta("lm_d23194d0b63ee4e1", "hp") == 30 and delta("lm_d23194d0b63ee4e1", "mp") == 20, "Advance Spirit explicit new flat bonuses")
	check(delta("lm_027e64c9f1bac62b", "attackSpeed") == 1, "Percentage uses native10000 denominator")
	check(is_equal_approx(delta("lm_01141f56509e111e", "speed"), .05) and delta("lm_01141f56509e111e", "duration") == 2, "Barrier direct movement and duration deltas")
	check(delta("lm_8009dbbae892b539", "weight") == 35, "Weight uses native100 denominator")
	check(delta("lm_888a50500b32fd03", "meleeHit", 74) == 0 and delta("lm_888a50500b32fd03", "meleeHit", 75) == 1, "Shadow Fang character gate respected")
	check(delta("lm_bb653bb8ca9e587d", "def") == 1 and delta("lm_cb0375ba9c238726", "def") == 1, "native AC improvement maps to host positive defense")
	check(delta("lm_a3f1da232ab333b5", "pveDamageReduction") == 1, "PvE reduction remains separate")
	for id: String in ["lm_b9e5decfe11eb2aa", "lm_236e004c8ab51043"]:
		check(delta(id,"pvpDamageReduction") == 1 and projected(id).relic_spell_effect.training_available, "PvP source increment isolated for explicit local training " + id)
	for id: String in ["lm_a67097404fc5663e", "lm_1fb2fb45ca7bb6e5"]:
		var result: Dictionary = projected(id)
		check(is_equal_approx(float(result.get("heal_percent",0)), .05) and bool(result.relic_spell_effect.native_definition_pending), "missing Restoration uses explicit five-percent estimate " + id)
		check(EFFECTS.detail_text(result).contains("TWILIGHT 추정") and result.relic_spell_effect.applied[0].projection == "ESTIMATE", "estimated recovery never labeled native " + id)
	check(is_equal_approx(delta("lm_517ca31126a31b45", "heal_percent"), .2), "Dragon Force exact self-child percentage50 to70 adds maxHP20 percent")
	for pair: Array in [["lm_a0a768c51a6b7838", .005],["lm_2bdb65edfba2772d", .01],["lm_3728e0e8b8a822aa", .01]]:
		var skill: Dictionary = projected(str(pair[0]))
		check(is_equal_approx(delta(str(pair[0]), "invoke_probability"), float(pair[1])), "native invoke level difference " + str(pair[0]))
		var rule: Dictionary = skill.relic_invoke_probability
		# The upgrade card describes the existing base consumer, not a new action.
		skill.id = rule.consumer; skill.mode = rule.mode
		var attack: Dictionary = {"confirmed":true,"attack_type":"melee","by_spell":false,"hit":true,"source_weapon_type":2,"main_target":true}
		check(is_equal_approx(EFFECTS.INVOKE.delta_for(skill, attack), float(pair[1])), "native invoke eligible normal hit " + str(pair[0]))
		attack.by_spell = true
		check(EFFECTS.INVOKE.delta_for(skill, attack) == 0, "native invoke never leaks to skill attacks " + str(pair[0]))
		attack.by_spell = false; attack.hit = false
		check(is_equal_approx(EFFECTS.INVOKE.delta_for(skill, attack), float(pair[1]) if bool(rule.allow_miss) else 0.0), "native miss flag controls increment " + str(pair[0]))
		check(EFFECTS.INVOKE.delta_for(skill, {}) == 0, "unknown attack context cannot grant native probability " + str(pair[0]))
	var crash: Dictionary = projected("lm_a0a768c51a6b7838")
	var weapon_attack: Dictionary = {"confirmed":true,"attack_type":"melee","by_spell":false,"hit":true,"source_weapon_type":1}
	check(EFFECTS.INVOKE.delta_for(crash, weapon_attack) == 0, "Crash group241 rejects swords")
	weapon_attack.source_weapon_type = 4
	check(is_equal_approx(EFFECTS.INVOKE.delta_for(crash, weapon_attack), .005), "Crash group241 source membership includes spear")
	for id: String in ["lm_4f90e0d7ce272c1f", "lm_4577052891abbbc4", "lm_f3e3300d0862d21a", "lm_8187ff2de29d3853"]:
		check(is_equal_approx(delta(id, "status_chance"), .03), "native probability +3 percentage points " + id)
	check(is_equal_approx(delta("lm_44e63d3719e2f526", "status_chance"), .01), "Power Grip native probability +1 point")
	var with_probability: Dictionary = projected("lm_4f90e0d7ce272c1f")
	check(with_probability.relic_spell_effect.applied[0].projection == "CUSTOM_BALANCE" and EFFECTS.detail_text(with_probability).contains("게임 적용 설정"), "host probability formula distinguished from native increment")
	var saved_policy: Dictionary = EFFECTS._policy_document.duplicate(true)
	EFFECTS._policy_document.restoration_level_estimates["69601"].enabled = false
	check(float(projected("lm_a67097404fc5663e").get("heal_percent",0)) == 0, "missing-definition estimate can be disabled")
	EFFECTS._policy_document.restoration_level_estimates["69601"].enabled = true
	EFFECTS._policy_document.restoration_level_estimates["69601"].bonus_fraction = .1
	check(is_equal_approx(float(projected("lm_a67097404fc5663e").heal_percent), .1), "recovery estimate uses configured fraction")
	check(is_equal_approx(delta("lm_517ca31126a31b45","heal_percent"), .2), "verified native Dragon Force curve takes priority over estimate settings")
	EFFECTS._policy_document = saved_policy.duplicate(true)
	EFFECTS._policy_document.status_probability_projection.enabled = false
	check(delta("lm_4f90e0d7ce272c1f", "status_chance") == 0, "custom probability projection can be disabled")
	EFFECTS._policy_document = saved_policy
	var immune_target: TwilightMonster = preload("res://scenes/Monster.tscn").instantiate()
	var unused_world := Node.new()
	immune_target.stun_resistance = 100
	check(not STATUS.new().apply(with_probability, immune_target, unused_world), "native probability increment preserves resistance100 failure")
	immune_target.stun_resistance = 0; immune_target.status_immunities = ["stun"]
	check(not STATUS.new().apply(with_probability, immune_target, unused_world), "native probability increment preserves immunity failure")
	immune_target.free(); unused_world.free()
	var tampered: Dictionary = records["lm_e8236ca60328dd0a"].duplicate(true)
	tampered.name = "same ID, altered record"
	check(not EFFECTS.identity_matches(tampered, RULES._rules.spell_profiles[tampered.id]), "ID alone cannot authorize altered host")
	check(records["lm_e8236ca60328dd0a"].get("relic_spell_effect") == null, "projections leave original records immutable")
	print("RELIC_SPELL_EFFECT_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "bindings":RULES._rules.spell_profiles.size(), "connected_skills":connected, "pending_skills":pending}))
	quit(0 if failures.is_empty() else 1)
