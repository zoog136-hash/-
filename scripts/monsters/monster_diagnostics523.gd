extends RefCounted
## "몬스터 진단" lines for the top of the settings screen: what the running
## game knows about monster spawning, so a player can send one screenshot
## from the device. Read-only; never changes game state.

const HOST = preload("res://scripts/maps/current523_host.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const PREFERENCES = preload("res://scripts/maps/current523_source_definition_preferences.gd")
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const INSTALLER = preload("res://scripts/lineagem_pack_install.gd")
const RELOCATION = preload("res://scripts/maps/old_map_save_relocation523.gd")

static func lines(world: Node) -> PackedStringArray:
	var out := PackedStringArray(["몬스터 진단"])
	if world == null or not is_instance_valid(world):
		out.append("· 월드 없음")
		return out
	var field: Variant = world.get("field_map")
	var field_id: String = str(field.data.get("map_id", "?")) if field != null and field.get("data") is Dictionary else "없음"
	out.append("· 지도 %s · 지형 %s · 빌드 %s/%s" % [str(world.get("active_map_id")), field_id,
		"template" if OS.has_feature("template") else "editor", OS.get_name()])
	var active: bool = bool(world.get("current523_aden_play_active"))
	var play_problem: String = str(world.get("current523_aden_play_problem"))
	out.append("· 523 모드 %s · 523 팩 %s%s%s" % ["켜짐" if active else "꺼짐", "선택됨" if HOST.requested() else "미선택",
		"" if play_problem.is_empty() else " · 사유: " + play_problem,
		"" if HOST.problem.is_empty() else " · 팩: " + HOST.problem])
	var settings: Dictionary = POLICY.settings()
	var selected: Dictionary = PREFERENCES.read()
	var selection: String = "설정 파일 없음"
	if selected.get("configured", false):
		selection = str(selected.get("directory", "")) if selected.get("ok", false) else "오류: " + str(selected.get("problem", ""))
	out.append("· 출현 정의 %s · 경로 %s · 설정 %s" % ["연결" if settings.get("enabled", false) else "없음",
		str(settings.get("root", "-")), selection])
	var summary: Dictionary = {}
	var controller: Variant = world.call("_aden_play_controller") if world.has_method("_aden_play_controller") else null
	if controller != null and controller.get("spawn_summary") is Dictionary: summary = controller.get("spawn_summary")
	if summary.is_empty() and field != null and field.has_meta("current523_spawn_summary"): summary = field.get_meta("current523_spawn_summary")
	if summary.is_empty():
		out.append("· 출현 구역 정보 없음")
	else:
		out.append("· 출현 구역 %d · 슬롯 %d · 보스 %d%s%s" % [int(summary.get("regions", 0)), int(summary.get("slots", 0)), int(summary.get("bosses", 0)),
			"" if bool(summary.get("ok", false)) else " · 실패: " + str(summary.get("reason", "?")),
			"" if LINKS.shared_problem.is_empty() else " · 정의: " + LINKS.shared_problem])
	var population: Variant = world.get("field_population")
	var pop_name: String = "없음"
	var metrics: Dictionary = {}
	if population != null and is_instance_valid(population):
		pop_name = str(population.get_script().resource_path.get_file().get_basename()) if population.get_script() != null else "?"
		if population.has_method("source_metrics"): metrics = population.call("source_metrics")
	var monsters_root: Variant = world.get("monsters_root")
	var alive: int = (monsters_root as Node).get_child_count() if monsters_root is Node and is_instance_valid(monsters_root) else -1
	out.append("· 출현기 %s · 등록 %s/%s · 슬롯 %s · 살아있음 %s · 몬스터 노드 %d" % [pop_name, str(metrics.get("registered", "-")),
		str(metrics.get("regions", "-")), str(metrics.get("slots", "-")), str(metrics.get("alive", "-")), alive])
	out.append("· 가까운 출현 구역 " + _nearest(world, population))
	var relocation: Variant = world.get("old_map_relocation523")
	var moved: String = str(relocation.get("from_map_id", "")) if relocation is Dictionary else ""
	out.append("· 옛 base508 몬스터 팩 %s · 옛 지도 세이브 이전 %s" % [
		"있음" if FileAccess.file_exists(INSTALLER.monster_root().path_join("manifest.json")) else "없음(523에서는 사용 안 함)",
		("%s → 523 아덴" % moved) if not moved.is_empty() else "없음"])
	return out

static func _nearest(world: Node, population: Variant) -> String:
	if population == null or not is_instance_valid(population) or population.get("field") == null: return "확인 불가(출현 지형 없음)"
	var pfield: Object = population.get("field")
	var player: Variant = world.get("player")
	if not player is Node2D or pfield.get("coordinates") == null: return "확인 불가"
	var source: Vector2 = pfield.coordinates.to_source((player as Node2D).global_position)
	var best: float = INF
	var inside: bool = false
	for region: Dictionary in pfield.data.get("monster_spawn", []):
		if not region.get("source_rect") is Rect2i: continue
		var box: Rect2i = region.source_rect
		if Rect2(box).has_point(source): inside = true
		best = minf(best, Vector2(box.get_center()).distance_to(source))
	if best == INF: return "구역 없음"
	return "%d칸%s · 위치 %d,%d" % [roundi(best), " (구역 안)" if inside else "", roundi(source.x), roundi(source.y)]
