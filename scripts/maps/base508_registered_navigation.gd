extends RefCounted
## Keeps the existing PNG collision evaluator in its original pixel coordinates.
## Projection changes artwork position only; no S32 attributes become passable.
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
const FIELD = preload("res://scripts/maps/native_png_field.gd")
var source_pack: RefCounted
var field: RefCounted
var proof: Dictionary
var scale: Vector2
var translation: Vector2
var error: String = ""

func configure(pack: RefCounted, certificate: String, legacy_root: String, map_id: String) -> bool:
	field=null
	error="Registration or legacy navigation inputs failed validation"
	source_pack=pack
	proof = REGISTRY.read_json(certificate)
	if proof.get("status") != "VERIFIED_VISUAL_REGISTRATION_LEGACY_NAV_ONLY" or proof.get("source_pixel_sha256") != pack.manifest.art.get("pixel_sha256"):
		error="Registration evidence missing or different source raster";return false
	var anchors: Variant=proof.get("anchors")
	if not anchors is Array or anchors.size()!=16:return false
	for anchor: Dictionary in anchors:
		if float(anchor.get("highpass_ncc",0))<0.4 or not anchor.get("residual_pixels") is Array or anchor.residual_pixels.size()!=2:return false
		if absf(float(anchor.residual_pixels[0]))>1 or absf(float(anchor.residual_pixels[1]))>1:return false
	if map_id not in ["albino_01","albino_02"] or map_id not in proof.get("accepted_legacy_maps",[]):
		error="Legacy map has no accepted registration";return false
	if proof.get("plan_sha256") != FileAccess.get_sha256(REGISTRY.PLAN_PATH) or proof.get("review_sha256") != FileAccess.get_sha256(REGISTRY.REVIEW_PATH):
		error="Legacy geometry changed since registration";return false
	var base: Dictionary = REGISTRY.base_plan()
	var plan: Dictionary = REGISTRY.merge_review(base,REGISTRY.read_json(REGISTRY.REVIEW_PATH),proof.plan_sha256)
	if plan.is_empty() or proof.get("reference_sha256") != plan.sources["13474.png"].sha256: return false
	# Do not add optional correction polygons or alter any existing collision rule.
	# This is a conservative subset of the existing reviewed PNG geometry.
	var index: Dictionary = REGISTRY.read_json(legacy_root+"/index.json")
	var receipt: Dictionary = REGISTRY.read_json("res://data/maps/native_png_pack.json")
	if FileAccess.get_sha256(legacy_root+"/index.json") != receipt.get("index_sha256") or index.get("plan_sha256") != proof.plan_sha256: return false
	var path: String = legacy_root+"/"+map_id+"/manifest.json"
	if FileAccess.get_sha256(path) != index.get("maps",{}).get(map_id,{}).get("sha256"): return false
	var manifest: Dictionary = REGISTRY.read_json(path)
	if manifest.get("source_sha256") != proof.reference_sha256 or manifest.get("native_pixel_scale") != 1: return false
	if not proof.get("scale") is Array or not proof.get("translation") is Array: return false
	scale=Vector2(proof.scale[0],proof.scale[1]);translation=Vector2(proof.translation[0],proof.translation[1])
	if scale != Vector2(21504.0/19998.0,6912.0/6428.0) or translation != Vector2(0,-1536): return false
	field=FIELD.new()
	field.configure_png(map_id,plan,manifest,legacy_root+"/"+map_id)
	return safe_point(spawn())

func spawn() -> Vector2:
	return Vector2(field.data.spawn_position[0],field.data.spawn_position[1]) if field!=null else Vector2.INF

func to_render(legacy_point: Vector2) -> Vector2:
	return legacy_point*scale+translation

func safe_point(point: Vector2) -> bool:
	if field==null or not point.is_finite() or not field.walkable(point) or not field.point_clear(point,4.0): return false
	var projected: Vector2=source_pack.COORDINATE_CONTRACT.source_from_grid_anchor(source_pack.manifest,to_render(point)-Vector2(24,12))
	if not projected.is_finite() or not source_pack.COORDINATE_CONTRACT.supplied_cell(source_pack.manifest,Vector2i(projected.floor())): return false
	# Add registration uncertainty as an extra restriction around the original foot.
	var budget: float=1.0/minf(scale.x,scale.y)
	for offset: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		if not field.line_clear(point,point+offset*budget): return false
	return true

func move(from: Vector2, to: Vector2) -> Vector2:
	return to if safe_point(to) and field.line_clear(from,to) else from
