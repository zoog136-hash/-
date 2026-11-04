extends SceneTree
const RULES = preload("res://scripts/animation/source_optimization.gd")
const LOCAL = preload("res://scripts/animation/local_presentation_region.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("LOCAL_PRESENTATION_FAIL: ",label)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rules = RULES.new()
	check(bool(rules.load_directory(OS.get_environment("TWILIGHT_PATCH523_CONTENT")).ok),"actual patch523 private source required")
	if rules.territories.is_empty(): quit(1);return
	var original: String = JSON.stringify(rules.territories)
	for row: Dictionary in rules.territories:
		var own: Dictionary = LOCAL.normalized({"enabled":true,"center":Vector2(40,-25),"radius":256.0,"row_id":int(row.ID),"branch":"default"})
		var result: Dictionary = LOCAL.at_point(own,Vector2(40,-25),rules)
		check(result.status=="TWILIGHT_local_estimate" and result.settings.hide_doll==row.DefaultHideMagicDoll and result.settings.limit_effect_count==row.DefaultLowEffectCount,"all 195 original defaults work in independently defined game bounds %d" % int(row.ID))
		check(LOCAL.at_point(own,Vector2(296,-25),rules).status=="TWILIGHT_local_estimate" and LOCAL.at_point(own,Vector2(297,-25),rules).settings.is_empty(),"inclusive edge is an explicit own policy %d" % int(row.ID))
		own.branch = "condition"
		result = LOCAL.at_point(own,Vector2(40,-25),rules)
		if int(row.ConditionTypeId)!=0:
			check(result.settings.hide_doll==row.ConditionHideMagicDoll and result.settings.limit_effect_count==row.ConditionLowEffectCount,"all original conditional values available by explicit own choice %d" % int(row.ID))
		else: check(result.status=="condition_unavailable" and result.settings.is_empty(),"no conditional values invented for unconditional source %d" % int(row.ID))
	var valid: Dictionary = {"enabled":true,"center":Vector2.ZERO,"radius":256.0,"row_id":79013,"branch":"default"}
	for changes: Dictionary in [{"enabled":"true"},{"center":Vector2(NAN,0)},{"radius":INF},{"radius":0},{"radius":4097},{"row_id":1.5},{"branch":"siege_active"}]:
		var broken: Dictionary = valid.duplicate(true)
		broken.merge(changes,true)
		check(LOCAL.normalized(broken).is_empty(),"malformed own rule cannot change quality")
	valid.enabled = false
	check(LOCAL.at_point(LOCAL.normalized(valid),Vector2.ZERO,rules).settings.is_empty(),"own rule can be disabled independently of native M context")
	check(JSON.stringify(rules.territories)==original,"source rows and conditions are immutable")
	print("LOCAL_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":195,"native_M_geometry_or_activation_claim":false}))
	quit(0 if failures.is_empty() else 1)
