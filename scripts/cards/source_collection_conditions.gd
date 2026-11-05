extends RefCounted
## Exact original ServerLimit matching. This evaluator never chooses a server,
## infers it from a map/language/account, reads a user save, or grants ownership.
var profiles: Dictionary={}
func configure(rows: Array) -> void:
	profiles.clear()
	for row: Dictionary in rows:
		var identity: int=int(row.get("ServerLimitSetID",-1))
		if identity<1:continue
		if not profiles.has(identity):profiles[identity]=[]
		profiles[identity].append(row.duplicate(true))
static func valid_context(context: Dictionary) -> bool:
	if context.get("source_snapshot","") not in ["base508","patch523"] or not context.get("ServiceRegionCode") is String:return false
	var number: Variant=context.get("WorldNo")
	return not str(context.ServiceRegionCode).is_empty() and (number is int or number is float) and is_finite(float(number)) and float(number)==floorf(float(number)) and int(number)>0
func evaluate(limit_id: int,context: Dictionary) -> Dictionary:
	if limit_id==0:return {"status":"unrestricted","limit_id":0}
	if not profiles.has(limit_id):return {"status":"definition_missing","limit_id":limit_id}
	if not valid_context(context):return {"status":"context_missing","limit_id":limit_id}
	for row: Dictionary in profiles[limit_id]:
		if str(row.ServiceRegionCode)==str(context.ServiceRegionCode) and int(row.WorldNo)==int(context.WorldNo):
			return {"status":"eligible","limit_id":limit_id,"matched_source_row_id":int(row.ID)}
	return {"status":"ineligible","limit_id":limit_id}
