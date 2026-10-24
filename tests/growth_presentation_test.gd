extends SceneTree
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var seal=preload("res://scripts/growth/growth_diagram.gd").new()
	seal.stage=18
	root.add_child(seal)
	seal.reveal(15)
	check(seal.animating and seal.displayed_stage==15,"enhancement begins at previous stage")
	var face=preload("res://scripts/growth/growth_card_face.gd").new()
	root.add_child(face)
	face.reveal(true)
	check(face.playing and face.progress==0 and face.front,"success begins with card back")
	await create_timer(.28).timeout
	check(seal.displayed_stage>15 and seal.displayed_stage<18,"slots reveal over time")
	check(face.progress>0 and face.progress<.5,"back half of flip")
	await create_timer(.22).timeout
	check(face.progress>.5 and face.progress<1,"front half of flip")
	await create_timer(.95).timeout
	check(not seal.animating and is_equal_approx(seal.displayed_stage,18),"seal settles at actual stage")
	check(not face.playing and face.progress==1 and face.shine==0,"success settles and releases presentation")
	face.reveal(false)
	check(face.failed and not face.front,"failure does not show success art")
	await create_timer(1.4).timeout
	check(not face.playing and face.failed,"failure settles")
	face.queue_free(); seal.queue_free()
	await process_frame
	print("GROWTH_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
