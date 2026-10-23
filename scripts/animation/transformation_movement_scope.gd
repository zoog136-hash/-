extends RefCounted
class_name TwilightTransformationMovementScope

const POLICY_PATH = "res://data/pr122_transform_motion_scope.json"
const CATALOG_PATH = "res://data/catalog_v19.json"
const MONSTER_POLICY_PATH = "res://data/pr122_monster_production_scope.json"
const EXCLUDED_GRADES = ["신화", "전설", "영웅", "희귀", "고급", "일반"]
static var _loaded: bool = false
static var _run_only: Dictionary = {}
static var _monster_loaded: bool = false
static var _monster_run_only: Dictionary = {}

static func _load_monster_scope() -> void:
	_monster_loaded = true
	if not FileAccess.file_exists(MONSTER_POLICY_PATH):
		return
	var policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONSTER_POLICY_PATH))
	if not policy is Dictionary or policy.get("schema") != "pr122-monster-motion-scope-v1":
		return
	if policy.get("actor_kind") != "monster" or policy.get("new_walk_required") != false:
		return
	if policy.get("preserve_existing_walk") != true or policy.get("preserve_existing_directional_death") != true or policy.get("omission_grants_approval") != false:
		return
	var rows: Variant = policy.get("monsters")
	if not rows is Array:
		return
	var selected: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary:
			return
		var key: String = str(row.get("id", ""))
		if not key.begins_with("monster:") or key == "monster:" or selected.has(key):
			return
		if str(row.get("kind", "")) not in ["normal", "boss"]:
			return
		selected[key] = true
	_monster_run_only = selected

static func requires_walk(profile_id: String) -> bool:
	if profile_id.begins_with("monster:"):
		if not _monster_loaded:
			_load_monster_scope()
		# Existing WALK clips remain usable through ActorMotion's existing
		# run-to-walk fallback. New RUN-only sources also play at normal NPC speed.
		return not _monster_run_only.has(profile_id)
	if not profile_id.begins_with("transform:"):
		return true
	if not _loaded:
		_loaded = true
		var policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
		if not policy is Dictionary or policy.get("schema") != "pr122-transform-motion-scope-v1":
			return true
		if policy.get("actor_kind") != "transform" or policy.get("unique_transform_walk_required") != true or policy.get("boss_walk_required") != true:
			return true
		var grades: Variant = policy.get("walk_excluded_grades", [])
		if not grades is Array or grades.size() != EXCLUDED_GRADES.size():
			return true
		for grade: String in EXCLUDED_GRADES:
			if not grades.has(grade):
				return true
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if not catalog is Dictionary:
			return true
		for row: Dictionary in catalog.get("변신", []):
			if grades.has(str(row.get("grade", ""))):
				_run_only["transform:" + str(row.get("sourceId", ""))] = true
	return not _run_only.has(profile_id)
