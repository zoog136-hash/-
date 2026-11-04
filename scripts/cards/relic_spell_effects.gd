extends RefCounted
## Exact native level deltas projected onto existing host parameters.
## This is not a replacement for the unavailable full native combat formula.
const BINDINGS = "res://data/skills/relic_spell_bindings523.json"
const POLICY_PATH = "res://data/skills/relic_spell_effect_policy.json"
const STAT_FIELDS = {"HPPlus":"hp", "MPPlus":"mp", "MeleeDamage":"meleeDamage", "MeleeHit":"meleeHit", "MeleeCritical":"meleeCrit", "RangeEvasion":"er", "Constitution":"con", "ArmorClass":"def", "ArmorClassBonus":"def", "MagicResist":"mr", "AttackSpeedBonus":"attackSpeed", "MoveSpeedBonus":"speed", "CarryPlus":"weight", "PVEDamageReduction":"pveDamageReduction"}
const STAT_UNITS = {"HPPlus":"Value", "MPPlus":"Value", "MeleeDamage":"Value", "MeleeHit":"Value", "MeleeCritical":"ValuePercent", "RangeEvasion":"Value", "Constitution":"Value", "ArmorClass":"Value", "ArmorClassBonus":"Value", "MagicResist":"Value", "AttackSpeedBonus":"Percentage", "MoveSpeedBonus":"Percentage", "CarryPlus":"Weight", "PVEDamageReduction":"Value"}
const ACTION_FIELDS = {"SpellDamageBase":"power", "MPRestoration":"mana", "HPRestoration":"heal", "SpellBuffDuration":"duration"}
const ACTION_MODES = {"SpellDamageBase":["attack"], "MPRestoration":["convert"], "HPRestoration":["heal"], "SpellBuffDuration":["buff", "counter", "stealth", "heal"]}
const LABELS = {"hp":"최대 HP", "mp":"최대 MP", "meleeDamage":"근거리 피해", "meleeHit":"근거리 명중", "meleeCrit":"근거리 치명타(%)", "er":"원거리 회피", "con":"CON", "def":"방어(AC 감소)", "mr":"MR", "attackSpeed":"공격 속도(%)", "speed":"이동 속도 배율", "weight":"소지 무게", "pveDamageReduction":"몬스터 피해 감소", "power":"스킬 기본 피해", "mana":"MP 회복", "heal":"HP 회복", "duration":"지속시간(초)"}
static var _binding_document: Dictionary = {}
static var _policy_document: Dictionary = {}

static func policy() -> Dictionary:
	if _policy_document.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
		if value is Dictionary: _policy_document = value
	return _policy_document.get("status_probability_projection", {})

static func bindings() -> Dictionary:
	if _binding_document.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS))
		if value is Dictionary: _binding_document = value
	return _binding_document

static func needs_buff_refresh(record: Dictionary) -> bool:
	# This ID/hash flag is available even without the optional native ZIP, so
	# loaded buffs cannot retain a saved native increment after pack loss.
	var document: Dictionary = bindings()
	var entry: Dictionary = document.get("skills", {}).get(str(record.get("id", "")), {})
	return bool(entry.get("has_level_buff", false)) and identity_matches(record, {"binding":entry, "identity_fields":document.identity_fields})

static func _hash(value: Dictionary) -> String:
	return _canonical(value).sha256_text()

static func _canonical(value: Variant) -> String:
	# Godot parses JSON numbers as floats and its built-in sorted dictionary
	# order differs from Python's case-sensitive canonical binding format.
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return a.casecmp_to(b) < 0)
		var pairs: Array[String] = []
		for key: String in keys: pairs.append(JSON.stringify(key) + ":" + _canonical(value[key]))
		return "{" + ",".join(pairs) + "}"
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value: items.append(_canonical(item))
		return "[" + ",".join(items) + "]"
	if value is float and value == floor(value): return str(int(value))
	return JSON.stringify(value)

static func build(archive: ZIPReader, cards: Dictionary, bonuses: Dictionary, types: Dictionary, units: Dictionary) -> Dictionary:
	var binding: Dictionary = bindings()
	if binding.get("schema_version") != 1 or binding.get("skills", {}).size() != 119: return {}
	var spells: Dictionary = {}
	for row: Dictionary in _table(archive, "SpellClass"): spells[int(row.ID)] = row
	var decks: Array = _table(archive, "BuffCardDeck")
	if not decks.any(func(row: Dictionary) -> bool: return int(row.ID) == 41 and row.Name == "Spell"): return {}
	var ui_units: Dictionary = {}
	for row: Dictionary in _table(archive, "UIUnit"): ui_units[int(row.UnitID)] = row
	var needed_spells: Dictionary = {}
	for entry: Dictionary in binding.skills.values(): needed_spells[int(entry.spell_id)] = true
	var spell_rows: Array = _table(archive, "SpellBonus")
	var children: Dictionary = {}
	var needed_buffs: Dictionary = {}
	for row: Dictionary in spell_rows:
		if not needed_spells.has(int(row.SpellClassID)): continue
		var bonus: Dictionary = bonuses.get(int(row.BonusID), {})
		var name_value: String = str(types.get(int(bonus.get("BonusTypeID", -1)), {}).get("Name", ""))
		if name_value == "SpellClassID": children[int(bonus.Value)] = true
		if name_value == "BuffClassID": needed_buffs[int(bonus.Value)] = true
	needed_spells.merge(children)
	var spell_links: Dictionary = _links(spell_rows, "SpellClassID", bonuses, types, units, ui_units, needed_spells)
	spell_rows.clear()
	var buff_links: Dictionary = _links(_table(archive, "BuffBonus"), "BuffClassID", bonuses, types, units, ui_units, needed_buffs)
	var profiles: Dictionary = {}
	for id: String in binding.skills:
		var entry: Dictionary = binding.skills[id]
		var spell: Dictionary = spells.get(int(entry.spell_id), {})
		var card: Dictionary = cards.get(int(entry.spell_card_id), {})
		if spell.is_empty() or _hash(spell) != str(entry.row_sha256) or int(card.get("BuffCardDeckID", -1)) != 41 or int(card.get("SpellClassID", -1)) != int(entry.spell_id) or int(card.get("GradeID", -1)) != int(entry.grade_id): return {}
		var direct: Array = spell_links.get(int(entry.spell_id), [])
		var main_buffs: Dictionary = {}
		var child_pending: Array[String] = []
		for effect: Dictionary in direct:
			if effect.name_value == "BuffClassID" and effect.spell_level == 0 and effect.application == 0 and effect.target == 0:
				main_buffs[int(effect.value)] = true
			if effect.name_value == "SpellClassID":
				for child: Dictionary in spell_links.get(int(effect.value), []):
					if child.spell_level > 0 and not child_pending.has(str(child.name_value)): child_pending.append(str(child.name_value))
		var buff: Array = buff_links.get(int(main_buffs.keys()[0]), []) if main_buffs.size() == 1 else []
		profiles[id] = {"binding":entry, "spell":direct, "buff":buff, "child_pending":child_pending, "identity_fields":binding.identity_fields}
	return profiles

static func _table(archive: ZIPReader, table: String) -> Array:
	var document: Variant = JSON.parse_string(archive.read_file("content/" + table + ".json").get_string_from_utf8().trim_prefix("\ufeff"))
	return document.get("rows", []) if document is Dictionary else []

static func _links(rows: Array, owner_key: String, bonuses: Dictionary, types: Dictionary, units: Dictionary, ui_units: Dictionary, needed: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for link: Dictionary in rows:
		if not needed.has(int(link[owner_key])): continue
		var bonus: Dictionary = bonuses.get(int(link.BonusID), {})
		var type_row: Dictionary = types.get(int(bonus.get("BonusTypeID", -1)), {})
		var unit_id: int = int(type_row.get("UnitID", -1))
		var id: int = int(link[owner_key])
		if not result.has(id): result[id] = []
		result[id].append({"link_id":int(link.ID), "bonus_id":int(link.BonusID), "name_value":str(type_row.get("Name", "")), "unit":str(units.get(unit_id, {}).get("Name", "")), "denominator":maxf(1, float(ui_units.get(unit_id, {}).get("Denominator", 0))), "value":float(bonus.get("Value", 0)), "application":int(bonus.get("BonusApplicationTypeID", -1)), "target":int(bonus.get("BonusApplicationTargetID", -1)), "spell_level":int(link.MinSpellLevel), "character_level":int(link.get("CharacterLevel", 0)), "character_class":int(link.get("CharacterClass", 0))})
	return result

static func identity_matches(record: Dictionary, profile: Dictionary) -> bool:
	var identity: Dictionary = {}
	for key: String in profile.identity_fields: identity[key] = record.get(key)
	return _hash(identity) == str(profile.binding.host_identity_sha256)

static func _selected(rows: Array, level: int, character_level: int) -> Dictionary:
	# Rows at different character/spell thresholds replace one another. Scoped
	# applications and class-dependent rows are deliberately not generalized.
	var result: Dictionary = {}
	for effect: Dictionary in rows:
		if effect.application != 0 or effect.target != 0 or effect.character_class != 0 or effect.spell_level > level or effect.character_level > character_level: continue
		var key: String = str(effect.name_value)
		var rank: int = int(effect.character_level) * 100 + int(effect.spell_level)
		if not result.has(key) or rank > int(result[key].rank):
			result[key] = {"rank":rank, "effect":effect, "ambiguous":false}
		elif rank == int(result[key].rank) and effect.bonus_id != result[key].effect.bonus_id:
			result[key].ambiguous = true
	return result

static func project(record: Dictionary, profile: Dictionary, level: Dictionary, character_level: int, enabled: bool) -> Dictionary:
	var meta: Dictionary = {"spell_id":profile.binding.spell_id, "grade_id":profile.binding.grade_id, "base_level":0, "effective_level":level.effective_level, "active":enabled and int(level.bonus) > 0, "code":level.code, "applied":[], "pending":profile.child_pending.duplicate(), "buff_level_changes":profile.buff.any(func(row: Dictionary) -> bool: return row.spell_level == 1)}
	if not enabled: meta.code = "skill_not_enabled"
	record["relic_spell_effect"] = meta
	for kind: String in ["spell", "buff"]:
		var rows: Array = profile[kind]
		var base: Dictionary = _selected(rows, 0, character_level)
		var raised: Dictionary = _selected(rows, 1, character_level)
		var changed: Dictionary = {}
		for effect: Dictionary in rows:
			if effect.spell_level != 1: continue
			changed[str(effect.name_value)] = true
			if effect.application != 0 or effect.target != 0 or effect.character_class != 0:
				var scoped: String = str(effect.name_value) + "(조건부)"
				if not meta.pending.has(scoped): meta.pending.append(scoped)
		for name_value: String in changed:
			var field: String = str(STAT_FIELDS.get(name_value, "")) if kind == "buff" else str(ACTION_FIELDS.get(name_value, ""))
			var probability_policy: Dictionary = policy()
			var probability_match: Dictionary = probability_policy.get("skills", {}).get(str(int(profile.binding.spell_id)), {})
			var custom_probability: bool = kind == "spell" and name_value == "SpellHitProbabilityBase" and bool(probability_policy.get("enabled", false)) and not probability_match.is_empty() and record.get("mode") == probability_match.get("mode") and record.get("status") == probability_match.get("status") and record.has("status_chance")
			if custom_probability: field = "status_chance"
			var target: Dictionary = raised.get(name_value, {})
			var previous: Dictionary = base.get(name_value, {})
			var supported: bool = not field.is_empty() and not target.is_empty() and not bool(target.get("ambiguous", false)) and not bool(previous.get("ambiguous", false))
			if supported:
				var expected: String = str(STAT_UNITS.get(name_value, "")) if kind == "buff" else "Seconds" if name_value == "SpellBuffDuration" else "Value"
				if custom_probability: expected = "Percentage"
				supported = str(target.effect.unit) == expected and (previous.is_empty() or str(previous.effect.unit) == expected)
				if kind == "spell": supported = supported and (custom_probability or str(record.get("mode", "")) in ACTION_MODES.get(name_value, []))
				else: supported = supported and str(record.get("mode", "")) in ["stats", "buff", "counter", "stealth", "heal"]
			if not supported:
				if not meta.pending.has(name_value): meta.pending.append(name_value)
				continue
			var baseline: float = float(previous.effect.value) if not previous.is_empty() else 0.0
			var delta: float = (float(target.effect.value) - baseline) / float(target.effect.denominator)
			if field == "speed": delta /= 100.0
			if custom_probability: delta /= 100.0
			if is_zero_approx(delta): continue
			if not meta.active: continue
			if kind == "buff":
				var stats: Dictionary = record.get("stats", {}).duplicate(true)
				stats[field] = float(stats.get(field, 1.0 if field == "speed" else 0.0)) + delta
				record["stats"] = stats
			else:
				var before: float = float(record.get(field, 0.0))
				record[field] = before + delta
				if custom_probability:
					record[field] = clampf(float(record[field]), clampf(float(probability_policy.get("minimum", 0)), 0, 1), clampf(float(probability_policy.get("maximum", 1)), 0, 1))
					delta = float(record[field]) - before
			meta.applied.append({"field":field, "delta":delta, "source_type":name_value, "source_link_id":target.effect.link_id, "source_bonus_id":target.effect.bonus_id, "base_link_id":previous.effect.link_id if not previous.is_empty() else 0, "projection":"CUSTOM_BALANCE" if custom_probability else "SOURCE_LEVEL_DELTA"})
	return record

static func detail_text(skill: Dictionary) -> String:
	var meta: Dictionary = skill.get("relic_spell_effect", {})
	if meta.is_empty(): return ""
	var lines: Array[String] = ["성물 · 원본 스킬 레벨 %d → %d" % [int(meta.base_level), int(meta.effective_level)]]
	for effect: Dictionary in meta.applied:
		if effect.field == "status_chance": lines.append("상태 성공률 %+.2f%%p · 게임 적용 설정(원본 증가분)" % (float(effect.delta) * 100.0))
		else: lines.append("%s %+.2f" % [str(LABELS.get(effect.field, effect.field)), float(effect.delta)])
	if meta.applied.is_empty(): lines.append("현재 적용 증가분 없음" if not meta.active else "이 스킬의 확인된 직접 증가분 없음")
	if not meta.pending.is_empty(): lines.append("조건·공식 연결 대기: " + ", ".join(meta.pending))
	return "\n".join(lines)
