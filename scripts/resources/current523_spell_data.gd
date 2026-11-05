extends RefCounted
## Original spell facts for existing item/book suppliers. No learning or effects.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const REFERENCES: Dictionary = {
	"TargettingTypeID":"TargettingType",
	"TargetKindID":"TargetKind",
	"SpellCategoryID":"SpellCategory",
	"SpellMaterialTypeID":"SpellMaterialType"}

static func _reference(blockers: Array[String], table: String, value: Variant) -> Dictionary:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or absf(float(value))>9007199254740991.0:
		blockers.append("invalid_source_reference:"+table)
		return {}
	var row: Dictionary = SOURCE.row(table,int(value))
	if row.is_empty(): blockers.append("missing_source_reference:"+table+":"+str(int(value)))
	return row

static func _fields(row: Dictionary, names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for field: String in names:
		if row.has(field): result[field] = row[field]
	return result

static func describe(spell_id: int) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	var spell: Dictionary = SOURCE.row("SpellClass",spell_id) if spell_id>=0 and not identity.is_empty() else {}
	var blockers: Array[String] = []
	var result: Dictionary = {
		"kind":"twilight.current523.spell-data.v1","ok":false,
		"reference_only":true,"can_execute":false,"learning_authorized":false,"ownership_authorized":false,
		"spell_class_id":spell_id,"source":identity,"spell_class":spell,
		"bonuses":[],"learn_limits":[],"references":{},"costs":{},"range":{},"conditions":{},"blockers":blockers}
	if spell.is_empty():
		blockers.append("source_spell_unavailable")
		result["problem"] = SOURCE.problem()
		return result
	# This is the explicit original test declaration, not an inferred dummy name.
	var test: Variant = spell.get("TestSpell")
	if typeof(test)!=TYPE_BOOL:
		blockers.append("source_test_declaration_missing")
	elif test:
		blockers.append("source_TestSpell_true")
		result["excluded"] = true
	for link: Dictionary in SOURCE.related("SpellBonus","SpellClassID",spell_id):
		var bonus: Dictionary = _reference(blockers,"Bonus",link.get("BonusID"))
		var type: Dictionary = _reference(blockers,"BonusType",bonus.get("BonusTypeID")) if not bonus.is_empty() else {}
		var unit: Dictionary = _reference(blockers,"Unit",type.get("UnitID")) if not type.is_empty() else {}
		result.bonuses.append({"link":link,"min_spell_level":link.get("MinSpellLevel"),"bonus":bonus,"type":type,"unit":unit})
	for link: Dictionary in SOURCE.related("SpellLearnLimit","SpellClassID",spell_id):
		var class_row: Dictionary = _reference(blockers,"Class",link.get("ClassID"))
		var limit_card: Dictionary = {}
		# The existing source book compiler treats zero as no required card.
		if link.get("LimitBuffCardID",0)!=0:
			limit_card = _reference(blockers,"BuffCard",link.get("LimitBuffCardID"))
		result.learn_limits.append({"link":link,"class":class_row,"limit_buff_card":limit_card})
	for field: String in REFERENCES:
		var table: String = REFERENCES[field]
		result.references[field] = {"table":table,"id":spell.get(field),"row":_reference(blockers,table,spell.get(field))}
	# Preserve native values and field names. These groups do not assign units,
	# calculate costs/ranges, satisfy conditions, or select a spell level.
	result.costs = _fields(spell,["HPCost","MPCost","MPCostUnit","VPCost","SpellMaterialTypeID","SpellMaterialItemAmount"])
	result.range = _fields(spell,["CastRange","MinCastRange","TargetAreaRadius","TargetLimitCount","IsAttackRange"])
	result.conditions = _fields(spell,["SpellGroupID","SpellGroupLevel","IsRequireSpellGroupMastery","IsChargeSpell","CanCastOnInvisible","CastingWeaponType","CastingMotionType","CopySpellClassID","SpellCompositionNode","SiegeTargetKindID"])
	# DescData/DescID text reads are deferred; all raw IDs remain in spell_class.
	result.ok = blockers.is_empty()
	return result
