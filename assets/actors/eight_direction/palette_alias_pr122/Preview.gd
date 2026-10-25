extends Node2D
## Space: pause/resume. Arrows: previous/next source track. No source edits.

const PreviewActor = preload("res://assets/actors/eight_direction/palette_alias_pr122/VariantPlayer.gd")
var players: Array[PreviewActor] = []
var tracks: Array[StringName] = []
var track_index: int = 0
var elapsed: float = 0.0
var interval: float = 1.0
var paused: bool = false
var status: Label

func _ready() -> void:
	players = [$Red as PreviewActor, $Blue as PreviewActor]
	status = $Status
	for player in players:
		if player.source_frames == null:
			status.text = "HOLD: source/index changed or missing. " + player.last_error
			set_process(false)
			return
	for action in ["idle", "walk", "attack", "hit", "death"]:
		for direction in range(8):
			var track := StringName("%s_%d" % [action, direction])
			if not players[0].source_frames.has_animation(track):
				status.text = "HOLD: missing source track " + str(track)
				set_process(false)
				return
			tracks.append(track)
	_start_track()

func _start_track() -> void:
	if tracks.is_empty():
		return
	var track: StringName = tracks[track_index]
	var frames: SpriteFrames = players[0].source_frames
	var duration: float = 0.0
	for frame in range(frames.get_frame_count(track)):
		duration += frames.get_frame_duration(track, frame)
	interval = duration / maxf(frames.get_animation_speed(track), 0.001) + 0.2
	elapsed = 0.0
	for player in players:
		player.play_track(track)
		if paused:
			player.sprite.pause()
	status.text = "LEGACY TINT PREVIEW / NOT NEW ART\n%s (%d/%d) | Space: pause | arrows: track\nSource walk: 3 frames; run: absent. Identity, masks and game integration: HOLD." % [str(track), track_index + 1, tracks.size()]

func _process(delta: float) -> void:
	if paused or tracks.is_empty():
		return
	elapsed += delta
	if elapsed >= interval:
		track_index = (track_index + 1) % tracks.size()
		_start_track()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or tracks.is_empty():
		return
	if event.keycode == KEY_SPACE:
		paused = not paused
		for player in players:
			if paused:
				player.sprite.pause()
			else:
				player.sprite.play()
	elif event.keycode == KEY_RIGHT or event.keycode == KEY_LEFT:
		var step: int = 1 if event.keycode == KEY_RIGHT else -1
		track_index = posmod(track_index + step, tracks.size())
		_start_track()
