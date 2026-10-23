extends SceneTree

const Reveal = preload("res://scripts/ui/enhancement_reveal.gd")
var errors: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		errors.append(detail)
		print("ENHANCEMENT_REVEAL_FAIL: "+detail)

func _run() -> void:
	for outcome: String in ["success","maintain","decrease","destroy"]:
		var stage: Control = Reveal.new()
		stage.silent = true
		root.add_child(stage)
		stage.set_process(false)
		stage.present(outcome,"검증 장검",7,9 if outcome == "success" else 6,null)
		var completed := {"count":0}
		stage.finished.connect(func() -> void: completed.count += 1)
		check(stage.result_label.text.is_empty(),outcome+" result hidden during charge")
		check(stage.confirm_button.disabled,outcome+" cannot close during charge")
		stage.close_reveal()
		check(not stage.closed,outcome+" premature confirmation does nothing")
		stage._process(Reveal.REVEAL_AT-0.01)
		check(not stage.revealed,outcome+" charge boundary")
		stage._process(0.02)
		check(stage.revealed and not stage.confirm_button.disabled,outcome+" reveal occurs once")
		check(stage.result_label.text.contains({"success":"성공","maintain":"유지","decrease":"하락","destroy":"소실"}[outcome]),outcome+" correct result copy")
		check(stage.level_label.text == ("" if outcome == "destroy" else "+9" if outcome == "success" else "+6" if outcome == "decrease" else "+7"),outcome+" level display")
		stage._process(10.0)
		check(not stage.playing and stage.clock == Reveal.SETTLE_AT,outcome+" stops redrawing when settled")
		stage.close_reveal()
		stage.close_reveal()
		check(int(completed.count) == 1,outcome+" close emits once")
		await process_frame
	var skipped: Control = Reveal.new()
	skipped.silent = true
	root.add_child(skipped)
	skipped.present("destroy","소실 장비",9,0,null)
	skipped.skip_to_result()
	skipped.skip_to_result()
	check(skipped.revealed and not skipped.playing and skipped.result == "destroy","skip preserves committed outcome")
	for viewport: Vector2 in [Vector2(1280,720),Vector2(1920,1080),Vector2(900,1480)]:
		skipped.size = viewport
		skipped._fit()
		var board_rect := Rect2(skipped.design_offset,Reveal.DESIGN*skipped.design_scale)
		check(Rect2(Vector2(-1,-1),viewport+Vector2(2,2)).encloses(board_rect),"composition fits "+str(viewport))
	skipped.close_reveal()
	await process_frame
	if errors.is_empty(): print("ENHANCEMENT_REVEAL_OK checks=%d" % checks)
	quit(0 if errors.is_empty() else 1)
