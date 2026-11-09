extends RefCounted
## UNVERIFIED: current523 definitions are the final input, never an old pack.
## Only the existing public build_collections numeric adapters are reproduced.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CATEGORIES = {1:"변신",2:"마법인형",98:"성물"}
const TABLES = ["BuffCardCollection","BuffCardForCollection","BuffCardCollectionBonus","BuffCard","BuffCardDeck","Bonus","BonusType","BonusApplicationType","Unit","UIUnit","Grade","ServerLimit","IntervalBonusCategory","IntervalBonus","SpecialResistanceType","SpellClass","SpellTag","DescData_Korean"]
const TARGET_TABLES = ["SpecialResistanceType","SpellClass","SpellTag","IntervalBonusCategory","IntervalBonus"]
const FLAT = {
	"HPPlus":"max_hp","MPPlus":"max_mp","MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MagicDamage":"magic_damage",
	"MeleeHit":"melee_hit","RangeHit":"ranged_hit","MagicHit":"magic_hit","ArmorClass":"ac","MagicResist":"mr","RangeEvasion":"er",
	"DamageReduction":"damage_reduction","SpellPower":"sp","Strength":"str","Dexterity":"dex","Constitution":"con","Intelligence":"int","Wisdom":"wis","Charisma":"cha",
	"RegenHP":"hp_regeneration","RegenMP":"mp_regeneration","HPPotionIncreaseStatic":"potion_heal",
	"PVEDamageReduction":"pve_damage_reduction","PVEMeleeAdditionDamage":"pve_melee_damage","PVERangeAdditionDamage":"pve_ranged_damage","PVEMagicAdditionDamage":"pve_magic_damage",
	"PVEMeleeHit":"pve_melee_hit","PVERangeHit":"pve_ranged_hit","PVEMagicHit":"pve_magic_hit","CriticalMeleeDamage":"melee_critical_damage","CriticalRangeDamage":"ranged_critical_damage","CriticalMagicDamage":"magic_critical_damage","MeleeEvasion":"melee_evasion",
	"MeleeDamageReduction":"melee_damage_reduction","RangeDamageReduction":"ranged_damage_reduction","MagicDamageReduction":"magic_damage_reduction","CriticalDamageReduction":"critical_damage_reduction","PoisonDamageReduction":"poison_damage_reduction",
	"PVPDamageReduction":"pve_damage_reduction","PVPMeleeAdditionDamage":"pve_melee_damage","PVPRangeAdditionDamage":"pve_ranged_damage","PVPMagicAdditionDamage":"pve_magic_damage","PiercePVPDamageReduction":"damage_reduction_ignore","PVPPierceMeleeEvasion":"melee_evasion_ignore","PVPPierceRangeEvasion":"ranged_evasion_ignore","PVPMeleeEvasion":"melee_evasion","PVPRangeEvasion":"er",
	"PierceDamageReduction":"damage_reduction_ignore","PierceMeleeDamageReduction":"melee_reduction_ignore","PierceRangeDamageReduction":"ranged_reduction_ignore","PierceMagicDamageReduction":"magic_reduction_ignore","PierceMeleeEvasion":"melee_evasion_ignore","PierceRangeEvasion":"ranged_evasion_ignore","AbsoluteRegenMP":"absolute_mp_regeneration","FinalBlowAdditionalDmg":"final_blow_damage","KarmaLife":"life","KarmaDeath":"death"}
const PERCENT = {
	"MagicCritical":"magic_critical_rate","PVEDamageReductionPercent":"pve_damage_reduction","ExperienceAdditionPercent":"experience_bonus","AttackSpeedBonus":"attack_speed","MoveSpeedBonus":"movement_speed","HPPotionIncreasePercent":"potion_heal","MeleeCritical":"melee_critical_rate","RangeCritical":"ranged_critical_rate",
	"MeleeDamageReductionPercent":"melee_damage_reduction","RangeDamageReductionPercent":"ranged_damage_reduction","MagicDamageReductionPercent":"magic_damage_reduction","PoisonDamageReductionPercent":"poison_damage_reduction",
	"PVPDamageReductionPercent":"pve_damage_reduction","IgnorePVPDamageReductionPercent":"damage_reduction_ignore","PVPPierceDamageReductionPercent":"pve_damage_amplification",
	"IgnoreDamageReductionPercent":"damage_reduction_ignore","IgnoreMeleeDamageReductionPercent":"melee_reduction_ignore","IgnoreRangeDamageReductionPercent":"ranged_reduction_ignore","IgnoreMagicDamageReductionPercent":"magic_reduction_ignore","PVEPierceDamageReductionPercent":"pve_damage_amplification",
	"MeleeCriticalResist":"melee_critical_resistance","RangeCriticalResist":"ranged_critical_resistance","MagicCriticalResist":"magic_critical_resistance","ElementalCriticalResistance":"elemental_critical_resistance","HPHealIncreasePercent":"magic_heal","WeaponBlock":"weapon_block","EinasadBlessAbsolutePercent":"blessing_charge","FinalBlowProbability":"final_blow_probability","FinalBlowAdditionalScale":"final_blow_amplification",
	"PierceMagicShieldPercent":"magic_penetration","ResistIgnoreDamageReductionPercent":"reduction_efficiency","MeleeDmgSpellDefensivePowerPercent":"physical_magic_defense","FinalBlowResistance":"final_blow_resistance"}
const PVP_FLAT = ["PVPDamageReduction","PVPMeleeAdditionDamage","PVPRangeAdditionDamage","PVPMagicAdditionDamage","PiercePVPDamageReduction","PVPPierceMeleeEvasion","PVPPierceRangeEvasion","PVPMeleeEvasion","PVPRangeEvasion"]
const PVP_PERCENT = ["PVPDamageReductionPercent","IgnorePVPDamageReductionPercent","PVPPierceDamageReductionPercent"]
const ESTIMATED = {"KarmaLife":"twilight_life_healing","KarmaDeath":"twilight_death_damage","PierceMagicShieldPercent":"twilight_magic_mr_penetration","ResistIgnoreDamageReductionPercent":"twilight_ignore_counter","MeleeDmgSpellDefensivePowerPercent":"twilight_physical_magic_guard","FinalBlowResistance":"twilight_final_blow_defense","WeaponBlock":"twilight_weapon_block","FinalBlowProbability":"twilight_final_blow","FinalBlowAdditionalDmg":"twilight_final_blow","FinalBlowAdditionalScale":"twilight_final_blow"}
var problem: String = ""
var _tables: Dictionary = {}
var _indexes: Dictionary = {}
var _hashes: Dictionary = {}
var _descriptions: Dictionary = {}
var _records: Dictionary = {}
var _ui: Dictionary = {}
var _exclusions: Array = []

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

func _excluded(table: String, row: Dictionary) -> bool:
	var evidence: Dictionary = SOURCE.declared_exclusion(table,row)
	if evidence.is_empty(): return false
	_exclusions.append({"table":table,"row":row,"evidence":evidence})
	return true

## Large tables read only by ID: kept in the shared reader and looked up per
## ID instead of materialized (Bonus alone is 217,916 rows). The same
## whole-table ID check as the index below runs on the packed ID column.
const BY_ID_TABLES = ["Bonus","SpellClass"]
var _by_id: Dictionary = {}

func _by_id_ready(table: String) -> bool:
	if not _by_id.has(table):
		var ids: Variant = SOURCE.column(table,"ID")
		var ready: bool = ids is PackedFloat64Array and (ids as PackedFloat64Array).size() == SOURCE.row_count(table) and SOURCE.integer_field(table,"ID")
		if ready:
			var sorted := PackedInt64Array()
			for value: float in ids: sorted.append(int(value))
			sorted.sort()
			for index: int in range(1, sorted.size()):
				if sorted[index] == sorted[index - 1]: ready = false; break
		_by_id[table] = ready
	return _by_id[table]

func _row(table: String, id: int, required: bool = true) -> Dictionary:
	if table in BY_ID_TABLES and not _tables.has(table):
		if not _by_id_ready(table):
			if required: problem = "컬렉션 원본 ID가 없거나 중복됩니다: "+table
			return {}
		var matches: Array[Dictionary] = SOURCE.related(table,"ID",id)
		var found: Dictionary = matches[0] if matches.size() == 1 else {}
		if required and found.is_empty(): problem = "컬렉션 원본 참조가 없습니다: "+table+"#"+str(id)
		return found
	if not _indexes.has(table):
		var index: Dictionary = {}
		for row: Dictionary in _tables.get(table,[]):
			if not row.has("ID") or index.has(int(row.ID)):
				if required: problem = "컬렉션 원본 ID가 없거나 중복됩니다: "+table
				return {}
			index[int(row.ID)] = row
		_indexes[table] = index
	var result: Dictionary = _indexes[table].get(id,{})
	if required and result.is_empty(): problem = "컬렉션 원본 참조가 없습니다: "+table+"#"+str(id)
	return result

func _text(id: int, fallback: String = "") -> String:
	if not _descriptions.has(id):
		var rows: Array[Dictionary] = SOURCE.related("DescData_Korean","ID",id)
		_descriptions[id] = "" if rows.is_empty() else str(rows[-1].get("Description",""))
	return fallback if str(_descriptions[id]).is_empty() else str(_descriptions[id])

func _read() -> bool:
	if SOURCE.identity().get("source_sha256") != SOURCE.SOURCE_SHA:
		problem = "current523 원본 정의 ZIP이 없습니다 · 구 컬렉션 팩으로 대체하지 않습니다"
		return false
	for table: String in TABLES:
		var meta: Dictionary = SOURCE.table_metadata(table)
		if meta.is_empty(): problem = "컬렉션 원본 메타데이터가 없습니다: "+table; return false
		_hashes[table] = meta.get("sha256")
		if table in BY_ID_TABLES and _by_id_ready(table):
			if SOURCE.row_count(table) != int(meta.get("row_count",-1)): problem = "컬렉션 원본 표가 없습니다: "+table; return false
			continue
		_tables[table] = [] if table == "DescData_Korean" else SOURCE.rows(table)
		if table != "DescData_Korean" and _tables[table].size() != int(meta.get("row_count",-1)): problem = "컬렉션 원본 표가 없습니다: "+table; return false
	for row: Dictionary in _tables.UIUnit: _ui[int(row.UnitID)] = row
	return true

func _bind_catalog(catalog: Dictionary) -> bool:
	for deck: int in CATEGORIES:
		var category: String = CATEGORIES[deck]
		var rows: Variant = catalog.get(category)
		if not rows is Array or rows.is_empty(): problem = "현재 카탈로그의 원본 카드 분류가 없습니다: "+category; return false
		for record: Variant in rows:
			if not record is Dictionary or not _integer(record.get("source_card_id")) or not _integer(record.get("source_deck_id")) or record.get("source") not in ["lineagem_base508","lineagem_patch523"]:
				problem = "현재 카탈로그에 정확한 원본 카드 ID·덱이 필요합니다: "+category; return false
			var card_id: int = int(record.source_card_id)
			var source_id: Variant = record.get("sourceId")
			if card_id <= 0 or int(record.source_deck_id) != deck or source_id not in ["m508:"+str(deck)+":"+str(card_id),"m523:"+str(deck)+":"+str(card_id)]:
				problem = "현재 카드의 stable 원본 정체가 다릅니다: BuffCard#"+str(card_id); return false
			var raw: Dictionary = _row("BuffCard",card_id)
			if raw.is_empty(): return false
			if raw.get("BuffCardDeckID") != deck:
				problem = "현재 카드와 current523 전체 원문이 다릅니다: BuffCard#"+str(card_id); return false
			if _excluded("BuffCard",raw): continue
			if record.get("source_original_card") != raw:
				problem = "현재 카드와 current523 전체 원문이 다릅니다: BuffCard#"+str(card_id); return false
			if _records.has(card_id): problem = "현재 카탈로그의 원본 카드 ID가 중복됩니다: "+str(card_id); return false
			if not record.get("name") is String or not record.get("grade") is String:
				problem = "현재 원본 카드의 표시 메타데이터가 없습니다: "+str(card_id); return false
			_records[card_id] = {"category":category,"record":record,"raw":raw}
	return true

func _target(bonus: Dictionary, application: Dictionary) -> Dictionary:
	var table: String = str(application.get("Name",""))
	var raw: Variant = null
	if table in TARGET_TABLES and _integer(bonus.get("BonusApplicationTargetID")):
		var original: Dictionary = _row(table,int(bonus.BonusApplicationTargetID),false)
		if not original.is_empty() and not _excluded(table,original): raw = original
	return {"BonusApplicationTypeID":application.ID,"target_id":bonus.BonusApplicationTargetID,"target_table":table,
		"target_row":raw,"resolved":application.ID == 0 or raw != null}

static func _trim_decimal(text: String) -> String:
	if not text.contains("."): return text
	while text.ends_with("0"): text = text.left(-1)
	return text.left(-1) if text.ends_with(".") else text

static func _display_amount(value: Variant) -> String:
	# Existing Python +g display convention (six significant digits), only a
	# label formatter. It never rounds the numeric effect value.
	var number: float = float(value)
	var sign: String = "-" if number < 0 else "+"
	var absolute: float = absf(number)
	if absolute == 0: return sign+"0"
	var exponent: int = int(floor(log(absolute)/log(10.0)))
	var places: int = maxi(0,5-exponent)
	var fixed: String = ("%."+str(places)+"f") % absolute
	var rounded: float = float(fixed)
	if rounded > 0: exponent = int(floor(log(rounded)/log(10.0)))
	if exponent < -4 or exponent >= 6:
		var mantissa: String = "%.5f" % (absolute/pow(10.0,exponent))
		if float(mantissa) >= 10: exponent += 1; mantissa = "1"
		return sign+_trim_decimal(mantissa)+"e"+("-" if exponent < 0 else "+")+str(absi(exponent)).pad_zeros(2)
	return sign+_trim_decimal(("%."+str(maxi(0,5-exponent))+"f") % absolute)

func _nested(category_id: int) -> Array:
	var result: Array = []
	for original: Dictionary in _tables.IntervalBonus:
		if original.IntervalBonusCategory != category_id: continue
		var bonus: Dictionary = _row("Bonus",int(original.BonusID))
		if bonus.is_empty(): return []
		var type: Dictionary = _row("BonusType",int(bonus.BonusTypeID))
		var application: Dictionary = _row("BonusApplicationType",int(bonus.BonusApplicationTypeID))
		if type.is_empty() or application.is_empty(): return []
		var unit: Dictionary = _row("Unit",int(type.UnitID))
		if unit.is_empty(): return []
		if _excluded("IntervalBonus",original) or _excluded("Bonus",bonus) or _excluded("BonusType",type) or _excluded("Unit",unit) or _excluded("BonusApplicationType",application): return []
		var target: Dictionary = _target(bonus,application)
		var branch: Dictionary = original.duplicate(true)
		branch.merge({"bonus":bonus,"bonus_type":type,"unit":unit,"ui_unit":_ui.get(int(type.UnitID),{}),
			"application_type":application,"application_target":target.target_row})
		result.append(branch)
	return result

func _effect(link: Dictionary) -> Dictionary:
	var bonus: Dictionary = _row("Bonus",int(link.BonusID))
	if bonus.is_empty(): return {}
	var type: Dictionary = _row("BonusType",int(bonus.BonusTypeID))
	var application: Dictionary = _row("BonusApplicationType",int(bonus.BonusApplicationTypeID))
	if type.is_empty() or application.is_empty(): return {}
	var unit: Dictionary = _row("Unit",int(type.UnitID))
	if unit.is_empty(): return {}
	if _excluded("BuffCardCollectionBonus",link) or _excluded("Bonus",bonus) or _excluded("BonusType",type) or _excluded("Unit",unit) or _excluded("BonusApplicationType",application): return {}
	if typeof(bonus.get("Value")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(bonus.Value)):
		problem = "컬렉션 원본 Bonus 수치가 유효하지 않습니다: "+str(bonus.ID)
		return {}
	var target: Dictionary = _target(bonus,application)
	var target_raw: Dictionary = target.target_row if target.target_row is Dictionary else {}
	var type_name: String = str(type.Name); var unit_name: String = str(unit.Name)
	var ui: Dictionary = _ui.get(int(unit.ID),{})
	var denominator: float = float(ui.get("Denominator",0))
	var key: String = "native_"+type_name; var local_unit: String = "raw"
	var amount: Variant = bonus.Value; var supported: bool = false; var policy: String = ""
	var target_name: String = str(target_raw.get("Name",""))
	var scoped: String = ""
	if application.ID == 2 and target_name in ["Stun","Hold","Fear"]:
		var suffix: String = {"SpecialResistance":"resistance","HitSpecialResistance":"hit"}.get(type_name,"")
		if not suffix.is_empty(): scoped = target_name.to_lower()+"_"+suffix
	if application.Name == "SpellClass" and not target_raw.is_empty() and type_name == "SpellDamageBase" and unit_name == "Value":
		key = "spell_"+str(int(bonus.BonusApplicationTargetID))+"_damage"; local_unit = "flat"; supported = true; policy = "local_exact_spell_identity"
	elif application.Name == "SpellClass" and not target_raw.is_empty() and type_name == "SpellHitProbabilityBase" and unit_name == "Percentage" and denominator > 0:
		key = "spell_"+str(int(bonus.BonusApplicationTargetID))+"_hit"; local_unit = "percent"; amount = float(amount)/denominator; supported = true; policy = "local_exact_spell_identity"
	elif application.Name == "SpellTag" and bonus.BonusApplicationTargetID == 1 and type_name == "DamageReductionForSpellAttackWeapon" and unit_name == "Value":
		key = "ranged_burst_reduction"; local_unit = "flat"; supported = true; policy = "twilight_ranged_burst_tag1"
	elif application.ID == 2 and target_name in ["Stun","Fear"] and type_name == "DamageReductionForSpecialDebuff" and unit_name == "Value":
		key = "while_"+target_name.to_lower()+"_damage_reduction"; local_unit = "flat"; supported = true; policy = "live_exact_source_status"
	elif type_name == "DamageDampOption" and application.Name == "DamageDampOption" and bonus.BonusApplicationTargetID == 13 and unit_name == "Percentage" and denominator > 0:
		key = "stacked_damage_reduction"; local_unit = "percent"; amount = float(amount)/denominator; supported = true; policy = "twilight_target13_stacked_reduction_v1"
	elif not scoped.is_empty() and unit_name == "Percentage" and denominator > 0:
		key = scoped; local_unit = "percent"; amount = float(amount)/denominator; supported = true
	elif application.ID == 0 and bonus.BonusApplicationTargetID == 0:
		if FLAT.has(type_name) and unit_name == "Value": key = FLAT[type_name]; local_unit = "flat"; supported = true
		elif PERCENT.has(type_name) and unit_name in ["Percentage","ValuePercent"] and denominator > 0:
			key = PERCENT[type_name]; local_unit = "percent"; amount = float(amount)/denominator; supported = true
		elif type_name == "CarryPlus" and unit_name == "Weight" and denominator > 0:
			key = "weight_bonus"; local_unit = "flat"; amount = float(amount)/denominator; supported = true
	if supported and ESTIMATED.has(type_name): policy = ESTIMATED[type_name]
	if supported and (type_name in PVP_FLAT or type_name in PVP_PERCENT): policy = "existing_single_player_pvp_to_pve"
	if key == "ac" and local_unit == "flat": amount = -amount
	if (local_unit == "flat" or (key == "potion_heal" and local_unit == "percent")) and not _integer(amount): supported = false
	if _integer(amount): amount = int(amount)
	# Unknown target semantics never become executable because the numeric
	# adapter alone recognizes a type. Existing NativeRules keeps them pending.
	if not target.resolved: supported = false
	var display_amount: Variant = amount; var display_unit: String = local_unit
	if not supported and unit_name in ["Percentage","ValuePercent","Weight"] and denominator > 0:
		display_amount = float(bonus.Value)/denominator; display_unit = "percent" if unit_name in ["Percentage","ValuePercent"] else "flat"
	var target_label: String = _text(int(target_raw.get("DescID",0)),target_name)
	var label: String = (target_label+" · " if not target_label.is_empty() else "")+_text(int(type.DescID),type_name)+" "+_display_amount(display_amount)+("%" if display_unit == "percent" else "")
	if policy == "existing_single_player_pvp_to_pve": label = label.replace("PVP","PVE").replace("PvP","PvE")
	var nested: Array = []
	if unit_name == "IntervalBonusCategoryID":
		var category: Dictionary = _row("IntervalBonusCategory",int(bonus.Value),false)
		label = _text(int(type.DescID),type_name)+" · 원본 구간 조건: "+str(category.get("Name",str(int(bonus.Value))))
		nested = _nested(int(bonus.Value))
	return {"key":key,"unit":local_unit,"value":amount,"label":label,"native_supported":supported,"runtime_policy":policy,
		"source_original":{"link":link,"bonus":bonus,"bonus_type":type,"application_type":application,"unit":unit,"ui_unit":ui,"application_target":target,"nested_intervals":nested}}

static func _group(rows: Array, field: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var id: int = int(row[field])
		if not result.has(id): result[id] = []
		result[id].append(row)
	return result

func build(catalog: Dictionary) -> Dictionary:
	problem = ""
	_tables.clear(); _indexes.clear(); _by_id.clear(); _hashes.clear(); _descriptions.clear(); _records.clear(); _ui.clear(); _exclusions.clear()
	if not _read() or not _bind_catalog(catalog): return {}
	var members: Dictionary = _group(_tables.BuffCardForCollection,"BuffCardCollectionID")
	var rewards: Dictionary = _group(_tables.BuffCardCollectionBonus,"BuffCardCollectionID")
	var collections: Array = []; var excluded_decks: Array = []; var excluded_collections: Array = []
	for original: Dictionary in _tables.BuffCardCollection:
		var deck_id: int = int(original.BuffCardDeckID)
		if not CATEGORIES.has(deck_id): excluded_decks.append(original); continue
		var grade: Dictionary = _row("Grade",int(original.GradeID))
		var deck: Dictionary = _row("BuffCardDeck",deck_id)
		if grade.is_empty() or deck.is_empty(): return {}
		var exclusion_start: int = _exclusions.size()
		var omitted: bool = _excluded("BuffCardCollection",original) or _excluded("Grade",grade) or _excluded("BuffCardDeck",deck)
		if omitted:
			excluded_collections.append({"source_original":original,"members":members.get(int(original.ID),[]),"reward_links":rewards.get(int(original.ID),[]),"evidence":_exclusions.slice(exclusion_start)})
			continue
		var requirements: Array = []
		for member: Dictionary in members.get(int(original.ID),[]):
			var card: Dictionary = _row("BuffCard",int(member.BuffCardID))
			if card.is_empty(): return {}
			if _excluded("BuffCardForCollection",member) or _excluded("BuffCard",card): omitted = true; break
			var entry: Dictionary = _records.get(int(member.BuffCardID),{})
			if entry.is_empty():
				problem = "필수 컬렉션 카드의 현재 카탈로그 정체가 없습니다: BuffCard#"+str(int(member.BuffCardID))+" / deck#"+str(int(card.BuffCardDeckID))
				return {}
			var record: Dictionary = entry.record
			requirements.append({"category":entry.category,"id":"source:"+str(record.sourceId),"name":record.name,"catalog_name":record.name,"grade":record.grade,
				"awakened":member.IsAwaken,"source_original":member,"source_card_availability":{"ServerLimitSetID":card.ServerLimitSetID,"StartDateTimeID":card.StartDateTimeID,"EndDateTimeID":card.EndDateTimeID}})
		if omitted:
			excluded_collections.append({"source_original":original,"members":members.get(int(original.ID),[]),"reward_links":rewards.get(int(original.ID),[]),"evidence":_exclusions.slice(exclusion_start)})
			continue
		var effects: Array = []
		for link: Dictionary in rewards.get(int(original.ID),[]):
			var before: int = _exclusions.size()
			var effect: Dictionary = _effect(link)
			if not problem.is_empty(): return {}
			if _exclusions.size() > before: omitted = true; break
			if not effect.is_empty(): effects.append(effect)
		if omitted:
			excluded_collections.append({"source_original":original,"members":members.get(int(original.ID),[]),"reward_links":rewards.get(int(original.ID),[]),"evidence":_exclusions.slice(exclusion_start)})
			continue
		var labels: PackedStringArray = []
		for effect: Dictionary in effects: labels.append(effect.label)
		collections.append({"id":"base508:collection:"+str(int(original.ID)),"name":_text(int(original.DescID),str(original.Name)),"category":CATEGORIES[deck_id],
			"grade":_text(int(grade.DescID),str(grade.Name)),"source_grade":grade,"requirements":requirements,"effects":effects,"raw_effects":"\n".join(labels),
			"server_note":"원본 서버 조건 "+str(int(original.ServerLimitSetID)) if original.ServerLimitSetID != 0 else "",
			"source":{"snapshot":"patch523","url":"patch523/BuffCardCollection:"+str(int(original.ID)),"table_sha256":_hashes.BuffCardCollection},"source_original":original,"source_deck":deck})
	var dates: Array = []
	for card: Dictionary in _tables.BuffCard:
		if CATEGORIES.has(int(card.BuffCardDeckID)) and (card.StartDateTimeID != 0 or card.EndDateTimeID != 0): dates.append(card)
	return {"schema_version":1,"source_snapshot":"patch523","identity_namespace":"base508:collection",
		"ownership_policy":"permanent_acquisition_exact_native_ID; no_registration_or_consumption","source_zip_sha256":SOURCE.SOURCE_SHA,"source_table_sha256":_hashes,
		"collections":collections,"excluded_test_deck_collections":excluded_decks,"excluded_source_collections":excluded_collections,"source_exclusion_evidence":_exclusions,
		"source_server_limits":_tables.ServerLimit,"source_card_date_rows":dates}
