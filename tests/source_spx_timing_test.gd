extends SceneTree

const PLAYER = preload("res://scripts/animation/source_spx_player.gd")
var failures := 0
var marks := 0
var sounds: Array[String] = []

func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := PLAYER.new()
	player.free_on_finish = false
	player.set_process(false)
	root.add_child(player)
	player._group = "fixture"
	player._rate = 10.0
	player._action = {"total_ticks":6, "frames":[
		{"frame":3,"ticks":2,"hit_marker":false},
		{"frame":0,"ticks":0,"hit_marker":true,"sound_ids":["10827"]},
		{"frame":2,"ticks":1,"hit_marker":true},
		{"frame":1,"ticks":3,"hit_marker":false,"sound_ids":["10831"]}]}
	player.source_marker.connect(func(_id: String, _frame: int): marks += 1)
	player.sound_requested.connect(func(id: String): sounds.append(id))
	var frames := SpriteFrames.new()
	frames.add_animation("fixture")
	for i in range(3):
		var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
		image.fill(Color(float(i)/3,0,0))
		frames.add_frame("fixture",ImageTexture.create_from_image(image))
	var sprite := Sprite2D.new()
	sprite.set_meta("frames",frames)
	player.add_child(sprite)
	player._layers.append(sprite)
	player._track_name = "fixture"
	player.play()
	player.advance(.19)
	check(sprite.texture == frames.get_frame_texture("fixture",0),"first frame keeps its two ticks")
	player.advance(.02)
	check(sprite.texture == frames.get_frame_texture("fixture",1),"zero record consumes no duration")
	check(marks == 1 and sounds == ["10827"],"zero-duration source marker and sound fire once")
	player.advance(.2)
	check(sprite.texture == frames.get_frame_texture("fixture",2),"last frame retains three ticks")
	player.advance(2.)
	check(not player._running and marks == 1,"long delta ends without extra marker or damage path")
	check(sounds == ["10827","10831"],"missing audio is only an optional event")
	player.speed_scale = 2.0
	player.play()
	player.advance(.11)
	check(sprite.texture == frames.get_frame_texture("fixture",1),"speed multiplier scales the entire original timeline")
	check(marks == 2,"replay resets marker state")
	player.stop()
	player.advance(9.)
	check(marks == 2,"stopped effect has no stale events")
	player.free()
	print("SOURCE_SPX_TIMING checks=9 failures=",failures)
	if failures == 0: print("SOURCE_SPX_TIMING_OK")
	quit(1 if failures else 0)
