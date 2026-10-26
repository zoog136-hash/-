extends SceneTree

const REVEAL = preload("res://scripts/ui/option_awakening_reveal.gd")
const BORDER = preload("res://scripts/ui/option_awakening_border.gd")
const AURA = preload("res://scripts/animation/option_awakening_aura.gd")
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--option-vfx-capture="):
			capture_dir = argument.trim_prefix("--option-vfx-capture=")
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("OPTION_VFX_FAIL: " + label)

func _capture(filename: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.get_size() == root.size, "capture uses real window extent " + filename)
	var error: Error = image.save_png(capture_dir.path_join(filename))
	check(error == OK, "capture " + filename)

func _touch(control: Control, down: bool, finger: int = 91, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)

func _card() -> Dictionary:
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for value: Dictionary in database.get("마법인형", []):
		if str(value.get("grade", "")) == "영웅" and ResourceLoader.exists(str(value.get("image_path", ""))):
			return value.duplicate(true)
	return {"name":"검수용 카드", "grade":"영웅"}

func _bonus_lines(card: Dictionary) -> Array:
	var database: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/option_awakening_cards.json"))
	for row: Dictionary in database.get("cards", []):
		if row.get("category") == "마법인형" and row.get("expected_name") == card.get("name") and row.get("grade") == card.get("grade"):
			return row.get("applied_options", []).duplicate()
	check(false, "capture card has actual applied awakening options")
	return []

func _run() -> void:
	# This isolated component fixture uses actual viewport pixels. The game's
	# default 16:9 keep-aspect policy would otherwise letterbox a tall window.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var card: Dictionary = _card()
	var outcome := {"success":true, "category":"마법인형", "bonus_lines":_bonus_lines(card)}
	var original_card: Dictionary = card.duplicate(true)
	var original_outcome: Dictionary = outcome.duplicate(true)
	var stage: Control = REVEAL.new()
	stage.silent = true
	root.add_child(stage)
	await process_frame
	stage.present(card, outcome)
	stage.set_process(false)
	var completions := [0]
	stage.finished.connect(func() -> void: completions[0] += 1)
	stage.seek(0.65)
	check(not stage.revealed and stage.confirm_button.disabled, "result cannot confirm during charge")
	await _capture("option_awaken_charge.png")
	stage.seek(stage.reveal_time() + 0.16)
	check(stage.revealed and not stage.confirm_button.disabled and stage.border.awakened, "success reveals card status")
	if outcome.bonus_lines.size() > 2:
		check(stage.note.text.contains("외 %d개" % (outcome.bonus_lines.size() - 2)), "summary identifies additional applied options")
	await _capture("option_awaken_success.png")
	stage.present({"name":"unexpected replacement"}, {"success":false})
	check(stage.succeeded and stage.record == original_card, "reentrant present cannot replace committed result")
	check(card == original_card and outcome == original_outcome, "presentation does not mutate caller data")
	var repeated_key := InputEventKey.new()
	repeated_key.keycode = KEY_ESCAPE
	repeated_key.pressed = true
	repeated_key.echo = true
	stage._gui_input(repeated_key)
	check(not stage.closed, "key repeat cannot dismiss result")
	stage.skip_to_result()
	await _capture("option_awaken_settled.png")
	stage.close_reveal()
	stage.close_reveal()
	stage.skip_to_result()
	check(completions[0] == 1 and stage.closed, "duplicate close emits exactly once")
	stage.queue_free()
	await process_frame
	var failed: Control = REVEAL.new()
	failed.silent = true
	root.add_child(failed)
	await process_frame
	failed.present(card, {"success":false, "category":"마법인형"}, {"reduced_motion":true})
	failed.set_process(false)
	var intact_texture: Texture2D = failed.texture
	failed.skip_to_result()
	check(failed.revealed and failed.result_label.text == "각성 실패", "failed result is explicit")
	check(failed.texture == intact_texture and not failed.border.awakened, "failure keeps target card intact and unawakened")
	await _capture("option_awaken_failure.png")
	root.size = Vector2i(412, 915)
	await process_frame
	failed._fit()
	check(failed.confirm_button.get_global_rect().end.y <= root.size.y, "portrait confirmation stays in viewport")
	check(failed.confirm_button.get_global_rect().size.y >= 44.0 and failed.skip_button.get_global_rect().size.y >= 44.0, "412px portrait touch targets do not shrink with composition")
	await _capture("option_awaken_portrait.png")
	failed.queue_free()
	await process_frame
	var touch_stage: Control = REVEAL.new()
	touch_stage.silent = true
	root.add_child(touch_stage)
	await process_frame
	touch_stage.present(card, {"success":true, "category":"마법인형"})
	touch_stage.set_process(false)
	var touch_completions := [0]
	touch_stage.finished.connect(func() -> void: touch_completions[0] += 1)
	_touch(touch_stage.skip_button, true)
	_touch(touch_stage.skip_button, false)
	await process_frame
	check(touch_stage.revealed and not touch_stage.closed, "native screen-touch press/release skips to result")
	_touch(touch_stage.confirm_button, true, 92)
	_touch(touch_stage.confirm_button, false, 92, true)
	await process_frame
	check(not touch_stage.closed, "canceled native touch does not confirm")
	_touch(touch_stage.confirm_button, true, 93)
	_touch(touch_stage.confirm_button, false, 93)
	_touch(touch_stage.confirm_button, false, 93)
	await process_frame
	check(touch_stage.closed and touch_completions[0] == 1, "native screen-touch confirms once without mouse emulation")
	touch_stage.queue_free()
	await process_frame
	var status: Control = BORDER.new()
	root.add_child(status)
	status.configure("전설", true, {"reduced_motion":true, "impact_intensity":0.0})
	check(status.visible and not status.is_processing(), "status mark remains static with reduced motion and zero intensity")
	status.configure("전설", false)
	check(not status.visible, "unawakened card has no completion mark")
	status.queue_free()
	await process_frame
	await _check_field_anchors()
	print("OPTION_AWAKENING_VFX checks=%d failures=%d" % [checks, failures.size()])
	print("OPTION_AWAKENING_VFX_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	if failures.is_empty(): print("OPTION_AWAKENING_VFX_OK")
	quit(0 if failures.is_empty() else 1)

func _check_field_anchors() -> void:
	var image := Image.create(40, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color("cfa25e"))
	var art: Texture2D = ImageTexture.create_from_image(image)
	var foot := Node2D.new()
	root.add_child(foot)
	foot.position = Vector2(220, 280)
	foot.scale = Vector2(1.3, 0.9)
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_frame("default", art)
	sprite.sprite_frames = frames
	sprite.position = Vector2(12, -42)
	sprite.offset = Vector2(4, -7)
	sprite.scale = Vector2(0.8, 1.2)
	sprite.rotation = 0.18
	sprite.flip_h = true
	foot.add_child(sprite)
	var aura: Node2D = AURA.new()
	foot.add_child(aura)
	await process_frame
	var old_transform: Transform2D = sprite.transform
	aura.configure(sprite, "마법인형", "영웅", true)
	aura.sync_visual()
	check(aura.visible, "awakened follower has aura")
	check(aura.to_global(aura.center).is_equal_approx(sprite.to_global(sprite.offset)), "animated offset and ancestor transform place aura at actual visual center")
	check(aura.global_position.is_equal_approx(foot.global_position), "follower aura retains foot Y-sort position")
	check(sprite.transform == old_transform and sprite.flip_h, "aura never alters target scale rotation position or flip")
	foot.position += Vector2(35, 17)
	sprite.offset.y -= 6
	aura.sync_visual()
	check(aura.to_global(aura.center).is_equal_approx(sprite.to_global(sprite.offset)), "movement and elevated offset remain tracked")
	sprite.modulate.a = 0.3
	aura.sync_visual()
	check(is_equal_approx(aura.modulate.a, 0.3), "summon fade is reflected by aura")
	sprite.hide()
	aura.sync_visual()
	check(not aura.visible, "hidden follower never leaves detached aura")
	sprite.show()
	aura.set_awakened(false)
	check(not aura.visible and not aura.is_processing(), "unequipped awakening is disabled immediately")
	var relic := Sprite2D.new()
	relic.texture = art
	relic.position = Vector2(460, 280)
	relic.scale = Vector2(0.5, 0.7)
	relic.offset = Vector2(0, -88)
	relic.rotation = -0.06
	root.add_child(relic)
	aura.reparent(root)
	aura.configure(relic, "성물", "전설", true, {"reduced_motion":true, "effect_detail":"low"})
	aura.sync_visual()
	check(aura.to_global(aura.center).is_equal_approx(relic.to_global(relic.offset)), "relic float offset is reflected rather than drawn at feet")
	check(aura.global_position.is_equal_approx(relic.global_position), "relic aura retains foot sorting")
	var phase: float = aura.clock
	aura._process(0.1)
	check(is_equal_approx(aura.clock, phase), "reduced motion freezes authored orbit clock")
	relic.top_level = true
	relic.global_position += Vector2(21, 13)
	aura.sync_visual()
	check(aura.to_global(aura.center).is_equal_approx(relic.to_global(relic.offset)), "top-level visual global transform is respected")
	relic.queue_free()
	await process_frame
	aura.sync_visual()
	check(not aura.visible, "freed target leaves no orphan aura")
	aura.queue_free()
	foot.queue_free()
	await process_frame
