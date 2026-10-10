extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("PROVENANCE FAIL: ", message)

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual game")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.level = 90
	world._on_job_class_selected("마법사")
	world.hud.open_skills()
	await process_frame
	var view: Node = world.hud.skills_view
	var catalog := world.original_skills.catalog
	view.selected = catalog.record_for("턴 언데드")
	view.select_original()
	var text: String = view.detail.get_parsed_text()
	check(text.contains("일반 (추정)") and text.contains("액티브 (추정)"), "inferred grade and activation are labeled beside their values")
	check(text.contains("Lv.30 (TWILIGHT 설정)"), "custom learning level is not presented as original")
	check(text.contains("3000 아데나 (TWILIGHT 설정)"), "custom book price is labeled inline")
	check(text.contains("원작 입수처: 원작 미확인"), "missing original acquisition is explicitly unknown")
	check(text.contains("사용 수치: TWILIGHT 설정"), "cost/cooldown values are identified as offline settings")
	check(view.use_button.disabled and view.quick_button.disabled, "provenance text does not unlock an unlearned skill")
	view.selected = catalog.record_for("턴 언데드(에이션트)")
	view.select_original()
	text = view.detail.get_parsed_text()
	check(text.contains("영웅 (원작 확인)") and text.contains("패시브 (원작 확인)"), "verified grade and passive activation remain distinct from inferred values")
	check(text.contains("Lv.70 (TWILIGHT 설정)"), "verified passive does not imply a verified custom learning level")
	check(text.contains("신념의 탑 2층 보스") and text.contains("(원작 확인)"), "verified original acquisition is shown separately from local shop")
	check(view.use_button.disabled and view.quick_button.disabled, "passive remains unavailable for manual use or quickslots")
	view.selected = catalog.record_for("썬더 스턴")
	view.select_original()
	text = view.detail.get_parsed_text()
	check(text.contains("Lv.50 (원작 확인)"), "verified original learning level retains its provenance")
	# Render the existing UNKNOWN policy through the real detail view as well;
	# this copied fixture never changes the catalog or an actual skill record.
	view.selected = catalog.record_for("턴 언데드").duplicate(true)
	view.selected.fields.basic.grade.status = "UNKNOWN"
	view.selected.fields.basic.activation.status = "UNKNOWN"
	view.select_original()
	text = view.detail.get_parsed_text()
	check(text.contains("원작 미확인 (게임 표시: 일반)") and text.contains("원작 미확인 (게임 표시: 액티브)"), "unknown fields show a fallback without asserting original certainty")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_PROVENANCE_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
