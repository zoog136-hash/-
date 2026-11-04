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
	check(not face.selected and not face.failed and not face.success,"waiting card has no automatic outcome")
	await create_timer(.28).timeout
	check(seal.displayed_stage>15 and seal.displayed_stage<18,"slots reveal over time")
	check(not face.selected and not face.success,"time passing cannot select a card")
	await create_timer(.95).timeout
	check(not seal.animating and is_equal_approx(seal.displayed_stage,18),"seal settles at actual stage")

	var timeline=preload("res://scripts/growth/guardian_timeline.gd")
	var source: Dictionary=preload("res://data/growth/guardian_presentation.json").data
	check(source.fps==60 and source.clips.open.source_clip.start==40,"source Cocos frame rate and clip boundary")
	var scale_track: Dictionary=source.clips.open.tracks[0]
	check(is_equal_approx(float(timeline.sample(scale_track,42)[0]),.1485),"exact source opening scale")
	check(is_equal_approx(float(timeline.sample(scale_track,75)[0]),1),"exact source opening rest scale")
	timeline.play(face,"success")
	check(face.get_node_or_null("GuardianTimeline")!=null,"source result timeline attached")
	await create_timer(.3).timeout
	check(is_equal_approx(face.scale.x,1) and is_equal_approx(face.modulate.a,1),"source result settles after 15 frames")
	check(not face.selected and not face.success,"presentation cannot change card outcome")
	face.queue_free(); seal.queue_free()
	await process_frame
	print("GROWTH_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
