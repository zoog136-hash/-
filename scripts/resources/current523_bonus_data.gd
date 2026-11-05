extends RefCounted
## Shared original Bonus references. Values and target IDs are never executed.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

static func _id(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _reference(blockers: Array[String], table: String, value: Variant) -> Dictionary:
	if not _id(value):
		blockers.append("invalid_source_reference:"+table)
		return {}
	var matches: Array[Dictionary] = SOURCE.related(table,"ID",int(value))
	if matches.size()!=1:
		blockers.append(("missing_source_reference:" if matches.is_empty() else "ambiguous_source_reference:")+table+":"+str(int(value)))
		return {}
	return matches[0]

static func describe(bonus_id: int) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	var blockers: Array[String] = []
	var bonus: Dictionary = _reference(blockers,"Bonus",bonus_id) if not identity.is_empty() else {}
	var result: Dictionary = {
		"kind":"twilight.current523.bonus-data.v1","ok":false,
		"reference_only":true,"can_execute":false,"bonus_id":bonus_id,"source":identity,
		"bonus":bonus,"type":{},"unit":{},"application_type":{},"ui_units":[],
		"rawValue":bonus.get("Value"),"rawApplicationTargetID":bonus.get("BonusApplicationTargetID"),
		"blockers":blockers}
	if bonus.is_empty():
		if identity.is_empty(): blockers.append("source_bonus_unavailable")
		result["problem"] = SOURCE.problem()
		return result
	var type: Dictionary = _reference(blockers,"BonusType",bonus.get("BonusTypeID"))
	result.type = type
	if not type.is_empty():
		var unit_id: Variant = type.get("UnitID")
		result.unit = _reference(blockers,"Unit",unit_id)
		if _id(unit_id):
			# Keep every matching display-unit row. No denominator, percentage,
			# rounding or alternate display selection is applied by this contract.
			var ui_units: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(unit_id))
			result.ui_units = ui_units
			if ui_units.is_empty(): blockers.append("missing_source_reference:UIUnit.UnitID:"+str(int(unit_id)))
			elif ui_units.size()>1: blockers.append("ambiguous_source_reference:UIUnit.UnitID:"+str(int(unit_id)))
	result.application_type = _reference(blockers,"BonusApplicationType",bonus.get("BonusApplicationTypeID"))
	# The target namespace is not inferred from an application-type name.
	# Its exact ID and all original condition/value fields remain in bonus.
	# DescData/DescID text tables are not read here.
	result.ok = blockers.is_empty()
	return result
