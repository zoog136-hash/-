extends Control
## Read-only staging viewer. No approval, source rewrite, or game integration.
## Raw ImageTexture.take_over_path + AnimatedSprite2D playback is adapted from
## PR122 mythic draft-first-pass-20261023/generated_motion_draft_test_v02.gd.

const STAGING: String = "res://data/pr122_legendary_parallel_staging.json"
const ALLOWED_ASSETS: String = "res://assets/actors/eight_direction/legendary_parallel/"
const DIRECTIONS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const ROLES: Array[String] = ["idle", "run", "attack", "hit", "death"]

var _actors: Array[Dictionary] = []
var _textures: Array[ImageTexture] = []
var _queue: Array[Dictionary] = []
var _queue_index: int = -1
var _next_after: float = -1.0
var _paused: bool = false
var _animation: StringName = &""
var _role: String = "idle"
var _duration: float = 0.0
var _fit_scale: float = 1.0
var _maximum_texture_size: Vector2 = Vector2.ONE

var _actor_choice: OptionButton
var _direction_choice: OptionButton
var _role_choice: OptionButton
var _speed: SpinBox
var _zoom: SpinBox
var _status: Label
var _frame_line: Label
var _progress: Label
var _path_line: Label
var _stage: PanelContainer
var _portrait: TextureRect
var _sprite: AnimatedSprite2D

func _ready() -> void:
	_build_ui()
	_load_staging()

func _button(parent: Container, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "TWILIGHT legendary drafts | source quality HOLD | no approval or game integration"
	column.add_child(title)
	var selections := HBoxContainer.new()
	column.add_child(selections)
	_actor_choice = OptionButton.new()
	_actor_choice.custom_minimum_size.x = 320
	_actor_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selections.add_child(_actor_choice)
	_direction_choice = OptionButton.new()
	for direction: String in DIRECTIONS:
		_direction_choice.add_item(direction)
	_direction_choice.select(2)
	selections.add_child(_direction_choice)
	_role_choice = OptionButton.new()
	for role: String in ROLES:
		_role_choice.add_item(role.to_upper())
	selections.add_child(_role_choice)
	_actor_choice.item_selected.connect(_manual_selection)
	_direction_choice.item_selected.connect(_manual_selection)
	_role_choice.item_selected.connect(_manual_selection)
	_button(selections, "Reload staging", _load_staging)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	_button(controls, "Replay [R]", _replay)
	_button(controls, "Pause [Space]", _toggle_pause)
	_button(controls, "This actor x33", func() -> void: _start_sweep(false))
	_button(controls, "All actors x33", func() -> void: _start_sweep(true))
	_button(controls, "Cancel sweep", _cancel_sweep)
	var speed_label := Label.new()
	speed_label.text = "Speed"
	controls.add_child(speed_label)
	_speed = SpinBox.new()
	_speed.min_value = 0.25
	_speed.max_value = 2.0
	_speed.step = 0.25
	_speed.value = 1.0
	controls.add_child(_speed)
	_speed.value_changed.connect(_change_speed)
	var zoom_label := Label.new()
	zoom_label.text = "Zoom"
	controls.add_child(zoom_label)
	_zoom = SpinBox.new()
	_zoom.min_value = 0.25
	_zoom.max_value = 4.0
	_zoom.step = 0.25
	_zoom.value = 1.0
	controls.add_child(_zoom)
	_zoom.value_changed.connect(func(_value: float) -> void: _fit())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_progress = Label.new()
	column.add_child(_progress)
	_stage = PanelContainer.new()
	_stage.custom_minimum_size = Vector2(640, 400)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.15, 0.18)
	_stage.add_theme_stylebox_override("panel", background)
	column.add_child(_stage)
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.add_child(_sprite)
	_sprite.animation_finished.connect(_finished)
	_stage.resized.connect(_fit)
	# PanelContainer sizes its Control children. A plain overlay keeps the
	# portrait's own anchors independent from the panel's container layout.
	var reference_layer := Control.new()
	reference_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(reference_layer)
	_portrait = TextureRect.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_portrait.position = Vector2(-180, 12)
	_portrait.size = Vector2(160, 190)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference_layer.add_child(_portrait)
	_frame_line = Label.new()
	column.add_child(_frame_line)
	_path_line = Label.new()
	_path_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_path_line)

func _resource_path(value: String) -> String:
	return value if value.begins_with("res://") else "res://" + value

func _message(value: String, problem: bool = false) -> void:
	_status.text = value
	_status.modulate = Color(1.0, 0.65, 0.45) if problem else Color.WHITE

func _load_staging() -> void:
	_cancel_sweep()
	var selected_key: String = ""
	if not _actors.is_empty() and _actor_choice.selected >= 0:
		selected_key = str(_actors[_actor_choice.selected].get("key", ""))
	_actors.clear()
	_actor_choice.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGING))
	if not parsed is Dictionary:
		_message("Staging JSON unavailable: " + STAGING, true)
		return
	var staging: Dictionary = parsed
	var selection: int = 0
	for actor: Dictionary in staging.get("actors", []):
		if str(actor.get("grade", "")) != "전설":
			continue
		if str(actor.get("key", "")) == selected_key:
			selection = _actors.size()
		_actors.append(actor)
		_actor_choice.add_item(str(actor.get("key", "")) + "  " + str(actor.get("name", "")))
	var counts: Dictionary = staging.get("counts", {})
	_progress.text = "Staged " + str(counts.get("new_draft_configurations", 0)) + "/1320 | characters " + str(_actors.size()) + "/40 | approval remains unchanged"
	if _actors.is_empty():
		_message("No legendary actors in staging", true)
		return
	_actor_choice.select(selection)
	_select_track()

func _manual_selection(_index: int) -> void:
	_cancel_sweep()
	_select_track()

func _select_track() -> void:
	_sprite.pause()
	_sprite.sprite_frames = null
	_textures.clear()
	_paused = false
	_duration = 0.0
	_next_after = 0.5
	if _actors.is_empty() or _actor_choice.selected < 0:
		return
	_role = ROLES[_role_choice.selected]
	_direction_choice.disabled = _role == "death"
	if _role == "death":
		_direction_choice.select(2)
	var direction: String = DIRECTIONS[_direction_choice.selected]
	var actor: Dictionary = _actors[_actor_choice.selected]
	_load_reference(actor)
	var chosen: Dictionary = {}
	for draft: Dictionary in actor.get("drafts", []):
		if str(draft.get("direction", "")) == direction and str(draft.get("role", "")) == _role:
			chosen = draft
			break
	_path_line.text = str(actor.get("key", "")) + " " + direction + " " + _role.to_upper()
	if chosen.is_empty():
		_message("Missing staging draft; no fallback source is substituted", true)
		return
	var record_path: String = _resource_path(str(chosen.get("record", "")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	if not parsed is Dictionary:
		_message("Draft record unavailable: " + record_path, true)
		return
	var record: Dictionary = parsed
	if str(record.get("key", "")) != str(actor.get("key", "")):
		_message("Record actor ID mismatch", true)
		return
	var source_files: Array = record.get("source_files", [])
	if source_files.is_empty():
		source_files = [{"path": _resource_path(str(record.get("source", ""))), "sha256": record.get("source_sha256", "")}]
	# Same raw-source loading as the mythic first-pass validator. Keep only the
	# current resource alive; never rewrite a PNG or rely on a fallback texture.
	for source: Dictionary in source_files:
		var path: String = _resource_path(str(source.get("path", "")))
		if not path.begins_with(ALLOWED_ASSETS) or FileAccess.get_sha256(path) != str(source.get("sha256", "")):
			_message("Source path/SHA mismatch: " + path, true)
			return
		var image: Image = Image.load_from_file(path)
		if image == null or image.is_empty():
			_message("PNG cannot be loaded: " + path, true)
			return
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		_textures.append(texture)
		texture.take_over_path(path)
	var frames_path: String = str(chosen.get("SpriteFrames", ""))
	if not frames_path.begins_with(ALLOWED_ASSETS) or FileAccess.get_sha256(frames_path) != str(chosen.get("SpriteFrames_sha256", "")):
		_message("SpriteFrames path/SHA mismatch", true)
		return
	var frames: SpriteFrames = ResourceLoader.load(frames_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
	_animation = StringName(_role + "_" + str(DIRECTIONS.find(direction)))
	if frames == null or not frames.has_animation(_animation) or frames.get_frame_count(_animation) < 1:
		_message("Requested SpriteFrames animation unavailable", true)
		return
	_sprite.sprite_frames = frames
	_sprite.animation = _animation
	_maximum_texture_size = Vector2.ONE
	var weights: float = 0.0
	for phase: int in range(frames.get_frame_count(_animation)):
		var texture: Texture2D = frames.get_frame_texture(_animation, phase)
		if texture != null:
			_maximum_texture_size = _maximum_texture_size.max(texture.get_size())
		weights += frames.get_frame_duration(_animation, phase)
	var fps: float = frames.get_animation_speed(_animation)
	_duration = weights / fps if fps > 0.0 else 0.0
	_path_line.text += " | " + frames_path
	_fit()
	if _role == "death" and frames.get_animation_loop(_animation):
		_sprite.frame = frames.get_frame_count(_animation) - 1
		_message("HOLD: death resource loops; showing terminal frame without replay", true)
		return
	_sprite.speed_scale = float(_speed.value)
	_sprite.play(_animation)
	_next_after = _duration * (2.0 if _role in ["idle", "run"] else 1.0) / maxf(float(_speed.value), 0.01) + (0.75 if _role == "death" else 0.35)
	_message("HOLD | " + direction + " " + _role.to_upper() + " | new " + str(record.get("newly_authored_poses", record.get("new_poses", 6))) + " / reused " + str(record.get("reused_poses", 0)) + " | same fit scale across every frame")

func _load_reference(actor: Dictionary) -> void:
	_portrait.texture = null
	var path: String = str(actor.get("reference", ""))
	if not FileAccess.file_exists(path):
		return
	var image: Image = Image.load_from_file(path)
	if image != null and not image.is_empty():
		_portrait.texture = ImageTexture.create_from_image(image)

func _fit() -> void:
	if _stage == null or _sprite == null:
		return
	var usable: Vector2 = Vector2(maxf(_stage.size.x - 230.0, 100.0), maxf(_stage.size.y - 60.0, 100.0))
	_fit_scale = minf(usable.x / _maximum_texture_size.x, usable.y / _maximum_texture_size.y)
	_sprite.position = Vector2(maxf((_stage.size.x - 190.0) * 0.5, 50.0), _stage.size.y * 0.5)
	_sprite.scale = Vector2.ONE * _fit_scale * float(_zoom.value)

func _finished() -> void:
	if _role == "death" and _sprite.sprite_frames != null:
		_sprite.pause()
		_sprite.frame = _sprite.sprite_frames.get_frame_count(_animation) - 1

func _replay() -> void:
	_cancel_sweep()
	_select_track()

func _toggle_pause() -> void:
	if not _sprite.is_playing() and not _paused:
		return
	_paused = not _paused
	if _paused:
		_sprite.pause()
	else:
		_sprite.play(_animation)

func _change_speed(value: float) -> void:
	if _sprite != null:
		_sprite.speed_scale = value
	if not _queue.is_empty():
		_next_after = _duration * (2.0 if _role in ["idle", "run"] else 1.0) / maxf(value, 0.01) + 0.75

func _cancel_sweep() -> void:
	if not _queue.is_empty() and _progress != null:
		_progress.text = "Sequential playback cancelled; approval remains unchanged"
	_queue.clear()
	_queue_index = -1
	_next_after = -1.0

func _start_sweep(all_actors: bool) -> void:
	_cancel_sweep()
	if _actors.is_empty():
		return
	for actor_index: int in range(_actors.size()):
		if not all_actors and actor_index != _actor_choice.selected:
			continue
		for direction_index: int in range(DIRECTIONS.size()):
			for role_index: int in range(4):
				_queue.append({"actor": actor_index, "direction": direction_index, "role": role_index})
		_queue.append({"actor": actor_index, "direction": 2, "role": 4})
	_advance_sweep()

func _advance_sweep() -> void:
	_queue_index += 1
	if _queue_index >= _queue.size():
		_cancel_sweep()
		_progress.text = "Sequential playback finished; source quality and approvals remain unchanged"
		return
	var slot: Dictionary = _queue[_queue_index]
	_actor_choice.select(int(slot["actor"]))
	_direction_choice.select(int(slot["direction"]))
	_role_choice.select(int(slot["role"]))
	_select_track()
	_progress.text = "Sequential playback " + str(_queue_index + 1) + "/" + str(_queue.size()) + " | missing drafts are shown, never approved"

func _process(delta: float) -> void:
	if _sprite != null and _sprite.sprite_frames != null:
		_frame_line.text = "Frame " + str(_sprite.frame + 1) + "/" + str(_sprite.sprite_frames.get_frame_count(_animation)) + " | " + ("playing" if _sprite.is_playing() else "held / paused") + " | native duration " + String.num(_duration, 4) + "s | engine " + str(Engine.get_version_info().get("string", ""))
	if not _queue.is_empty() and not _paused:
		_next_after -= delta
		if _next_after <= 0.0:
			_advance_sweep()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: InputEventKey = event
	if key.keycode == KEY_SPACE:
		_toggle_pause()
	elif key.keycode == KEY_R:
		_replay()
	elif key.keycode in [KEY_LEFT, KEY_RIGHT] and _role != "death":
		_direction_choice.select(posmod(_direction_choice.selected + (-1 if key.keycode == KEY_LEFT else 1), 8))
		_manual_selection(0)
