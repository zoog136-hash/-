extends Node2D
const FloatSkin = preload("res://scripts/animation/thunder_float/myth_thunder_float.gd")
var actor: Node2D
var detail: Node2D
var time := 0.0
var frame := 0
var status: Label
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("202a30"))
	actor = FloatSkin.new()
	detail = FloatSkin.new()
	add_child(actor)
	add_child(detail)
	actor.scale = Vector2.ONE * 0.70
	detail.scale = Vector2.ONE * 3.0
	var title := Label.new()
	title.text = "TRANSFORM 413 / MYTH THUNDER (FEMALE) / LEFT-FACING FLOAT / EXISTING 413 FEMALE SHEET"
	title.position = Vector2(32, 18)
	add_child(title)
	status = Label.new()
	status.position = Vector2(32, 48)
	add_child(status)
	var notes := Label.new()
	notes.text = "Top: ~84 px visible height (current game footprint), 210 px/s. Bottom: 3x inspection. 30 FPS, normal time.\nExisting 413 FEMALE LEFT sheet cell; newly authored float motion. Not verified original animation.\nExisting source pose -> float -> source pose. Attack, idle animations and common RUN unchanged."
	notes.position = Vector2(32, 615)
	add_child(notes)
	_update()
func _process(delta: float) -> void:
	time = fmod(time + delta, 6.0)
	frame += 1
	_update()
	if frame == 180 and "--float-capture" in OS.get_cmdline_user_args():
		get_tree().quit()
func _update() -> void:
	var w := smoothstep(0.7, 1.0, time) * (1.0 - smoothstep(3.8, 4.1, time))
	var travel := _travel(time) * 210.0
	actor.position = Vector2(1060 - travel, 240)
	detail.position = Vector2(650, 590)
	actor.apply_movement(w, time)
	detail.apply_movement(w, time)
	status.text = "%.2f s    %s" % [time, "FLOAT" if w > 0.99 else ("SOURCE POSE HELD" if w < 0.01 else "MOVE TRANSITION")]
	queue_redraw()
func _draw() -> void:
	for x in range(0, 1280, 40):
		draw_line(Vector2(x, 110), Vector2(x, 265), Color("304049"))
	for y in range(110, 266, 40):
		draw_line(Vector2(0, y), Vector2(1280, y), Color("304049"))
	draw_line(Vector2(0, 280), Vector2(1280, 280), Color("65767d"), 1)

func _travel(t: float) -> float:
	# Integral of the same smoothstep envelope: no instant full-speed start/stop.
	if t <= 0.7: return 0.0
	if t < 1.0:
		var u := (t - 0.7) / 0.3
		return 0.3 * (u * u * u - 0.5 * u * u * u * u)
	if t <= 3.8: return 0.15 + t - 1.0
	if t < 4.1:
		var u := (t - 3.8) / 0.3
		return 2.95 + 0.3 * (u - u * u * u + 0.5 * u * u * u * u)
	return 3.1
