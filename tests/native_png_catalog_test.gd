extends SceneTree
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_PNG_CATALOG_FAIL: "+label)
func _initialize() -> void:
	var plan: Dictionary=REGISTRY.plan()
	check(not plan.is_empty(),"review is bound to the exact immutable pack plan")
	var base: Dictionary=REGISTRY.base_plan()
	var review: Dictionary=REGISTRY.read_json(REGISTRY.REVIEW_PATH)
	var base_hash: String=FileAccess.get_sha256(REGISTRY.PLAN_PATH)
	var invalid: Dictionary=review.duplicate(true);invalid.base_plan_sha256="other-pack"
	check(REGISTRY.merge_review(base,invalid,base_hash).is_empty(),"review for a different art plan is rejected")
	invalid=review.duplicate(true);invalid.maps.balrog_temple.source_sha256="other-source"
	check(REGISTRY.merge_review(base,invalid,base_hash).is_empty(),"review cannot reuse geometry on a different original PNG")
	invalid=review.duplicate(true);invalid.maps.balrog_temple.foreground[0].polygon_image=[[1,1],[5000,1],[5000,5000],[1,5000]]
	check(REGISTRY.merge_review(base,invalid,base_hash).is_empty(),"unbounded foreground cut is rejected")
	invalid=review.duplicate(true);invalid.maps.balrog_temple.foreground[0].foot_image=[-1,0]
	check(REGISTRY.merge_review(base,invalid,base_hash).is_empty(),"out-of-source foreground anchor is rejected")
	check(base.revision<plan.revision and not base.maps.balrog_temple.has("runtime_foreground"),"review does not mutate the immutable archive plan")
	check(base.maps.size()==6,"immutable v5 retains three Albino, continuous Escaros and two temples")
	check(plan.maps.size()==11,"five independently sourced Aden/Faith replacements join the six existing native fields")
	var extra: Dictionary=REGISTRY.read_json(REGISTRY.EXTRA_PLAN_PATH)
	for mid: String in ["aden_world","faith_01","faith_02","faith_03","faith_04"]:
		check(plan.maps.has(mid) and extra.maps.has(mid),"existing persistent ID receives its own PNG: "+mid)
		check(REGISTRY.plan_hash(mid)==FileAccess.get_sha256(REGISTRY.EXTRA_PLAN_PATH),"per-map save marker selects new pack: "+mid)
	check(plan.maps.balrog_temple.name=="발록의 시전","user supplied 99111 name retained exactly")
	check(plan.maps.yahee_temple.name=="야히의신전","user supplied 99112 name retained exactly")
	for source: Dictionary in plan.sources.values():
		check(source.get("server_map_id")==null and source.get("collision_data_id")==null,"PNG number never becomes server/collision ID")
		check(str(source.sha256).length()==64 and source.decoded,"original byte provenance recorded")
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json"))
	var ids: Array=baseline.map(func(row: Dictionary) -> String: return str(row.id))
	check(ids.size()==25 and ids.has("albino_04"),"all 25 original persistent IDs retained")
	for prefix: String in ["albino_","escaros_"]:
		for floor: int in range(1,5 if prefix=="albino_" else 6):
			check(ids.has(prefix+"%02d"%floor),"legacy ID remains loadable: "+prefix+str(floor))
	check(REGISTRY.catalog_entries().size()==(3 if REGISTRY.enabled() else (2 if REGISTRY.installed() else 0)),"new temples register with installed art; legacy replacements require explicit mode")
	print("NATIVE_PNG_CATALOG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"CODE_REGRESSION_NOT_PNG_RUNTIME"}))
	quit(0 if failures.is_empty() else 1)
