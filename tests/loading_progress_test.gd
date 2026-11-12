extends SceneTree
## Counts actual successful work. No assets, scenes, saves or original packs
## are needed for this state-machine test.
const PROGRESS = preload("res://scripts/boot/loading_progress.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var model = PROGRESS.new()
	check(model.snapshot().percent == 0 and not model.snapshot().ready, "unconfigured is never ready")
	var steps: Array[Dictionary] = [{"id":"images", "label":"그림 목록"}, {"id":"ui", "label":"원작 UI"}]
	model.configure(steps)
	check(model.snapshot().total == 5 and model.snapshot().completed == 0, "verification plus three actual handoff milestones")
	check(not model.begin_task("scene_ready") and not model.complete_task("scene_ready"), "cannot announce readiness before verification or scene initialization")
	check(not model.complete_task("images"), "unbegun work is not counted")
	check(model.begin_task("images", "그림 목록 검증 중"), "actual work begins")
	var before: Dictionary = model.snapshot()
	for index: int in 120: model.snapshot()
	check(model.snapshot() == before, "render polling does not create progress")
	check(model.snapshot().status == "그림 목록 검증 중" and model.snapshot().percent == 0, "long indivisible task shows status without invented percent")
	check(not model.begin_task("ui") and not model.complete_task("ui"), "another task cannot displace unfinished work")
	check(model.complete_task("images") and model.snapshot().percent == 20, "only actual completion advances the fraction")
	check(not model.complete_task("images") and model.snapshot().completed == 1, "duplicate completion never double counts")
	check(not model.begin_task("scene_load"), "scene cannot skip unfinished selected pack validation")
	check(model.begin_task("ui") and model.snapshot().status == "원작 UI", "default status is the selected work label")
	model.fail_task("원작 UI 검증 실패 · 다시 시도")
	check(model.snapshot().failed and model.snapshot().percent == 20 and not model.snapshot().ready, "failure preserves completed count and never claims ready")
	check(not model.complete_task("ui") and not model.begin_task("scene_load"), "failed work cannot count as complete")
	model.configure(steps)
	check(not model.snapshot().failed and model.snapshot().completed == 0 and model.snapshot().total == 5, "retry explicitly resets failed attempt")
	for step: Dictionary in steps:
		check(model.begin_task(str(step.id)) and model.complete_task(str(step.id)), "successful verification " + str(step.id))
	check(not model.begin_task("scene_change"), "scene handoff cannot precede scene loading")
	check(model.begin_task("scene_load") and model.complete_task("scene_load") and model.snapshot().percent == 60, "resource load is an actual completed item")
	check(not model.begin_task("scene_ready"), "loaded resource alone is not game readiness")
	check(model.begin_task("scene_change") and model.complete_task("scene_change") and model.snapshot().percent == 80, "scene change remains incomplete readiness")
	check(model.begin_task("scene_ready", "선택 캐릭터와 월드 준비 중"), "readiness can start after handoff")
	check(model.snapshot().percent < 100 and not model.snapshot().ready, "waiting for deferred world setup cannot display 100")
	check(model.complete_task("scene_ready") and model.snapshot().percent == 100 and model.snapshot().ready, "100 only after explicit successful readiness")
	var no_steps: Array[Dictionary] = []
	model.configure(no_steps)
	check(model.snapshot().total == 3 and model.snapshot().percent == 0, "warm boot uses only remaining real milestones")
	for id: String in ["scene_load", "scene_change", "scene_ready"]:
		check(model.begin_task(id) and model.complete_task(id), "warm boot actual work " + id)
	check(model.snapshot().ready and model.snapshot().percent == 100, "warm boot completes without fake verification")
	var duplicates: Array[Dictionary] = [{"id":"images"},{"id":"images"},{"id":""},{"id":"scene_ready"}]
	model.configure(duplicates)
	check(model.snapshot().total == 4, "duplicate and reserved IDs cannot corrupt the denominator")
	print("LOADING_PROGRESS_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
