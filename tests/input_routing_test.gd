extends SceneTree

# Send real viewport events through GUI dispatch and _unhandled_input.
# Direct calls to movement setters would miss touch capture/coordinate defects.
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld
var stick: TwilightVirtualJoystick

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("INPUT FAIL: " + message)

func touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)

func stick_point(local_point: Vector2) -> Vector2:
	return stick.get_global_transform_with_canvas() * local_point

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func _run() -> void:
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.save_timer = -10000
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: TwilightMonster in world.monsters_root.get_children():
		monster.set_physics_process(false)
	stick = world.hud.joystick
	var original_scale: Vector2 = stick.scale
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(960,540), Vector2i(1560,720)]:
		root.size = viewport_size
		await process_frame
		for ui_scale: Vector2 in [Vector2.ONE, Vector2(.82,1.08)]:
			stick.scale = ui_scale
			for direction: Vector2 in [Vector2.RIGHT, Vector2(1,1).normalized(), Vector2.DOWN, Vector2(-1,1).normalized(), Vector2.LEFT, Vector2(-1,-1).normalized(), Vector2.UP, Vector2(1,-1).normalized()]:
				world.player.clear_click_path()
				var center: Vector2 = stick.size*.5
				var start: Vector2 = stick_point(center + direction*38)
				touch(0,start,true)
				check(stick.active_touch == 0,"GUI captures primary finger")
				check(stick.value.dot(direction) > .99,"eight directions at viewport %s" % viewport_size)
				var outside: Vector2 = stick_point(center+direction*stick.size.x*1.8)
				drag(0,outside)
				check(stick.value.dot(direction) > .99,"outside drag preserves local direction %s" % direction)
				check(world.player.touch_vector.dot(direction) > .99,"HUD forwards captured drag")
				check(world.player.click_path.is_empty(),"joystick never leaks a world destination")
				touch(0,outside,false)
				check(stick.active_touch == -1 and world.player.touch_vector == Vector2.ZERO,"outside release stops movement")
	stick.scale = original_scale
	root.size = Vector2i(1280,720)
	await process_frame
	var center: Vector2 = stick.size*.5
	var start: Vector2 = stick_point(center+Vector2(40,0))
	touch(2,start,true)
	touch(7,stick_point(center-Vector2(40,0)),true)
	drag(7,stick_point(center-Vector2(300,0)))
	touch(7,stick_point(center),false)
	check(stick.active_touch == 2 and stick.value.x > .99,"secondary finger cannot steal or release joystick")
	var attack_count: Array[int] = [0]
	world.hud.attack_pressed.connect(func() -> void: attack_count[0] += 1)
	var attack: Button = world.hud.get_node("Root/RightControls/AttackButton")
	var attack_point: Vector2 = attack.get_global_transform_with_canvas() * (attack.size*.5)
	touch(3,attack_point,true)
	touch(3,attack_point,false)
	check(attack_count[0] == 1,"second finger activates attack while moving")
	check(stick.active_touch == 2 and world.player.touch_vector.x > .99,"attack finger preserves movement")
	check(world.player.click_path.is_empty(),"HUD touch does not issue a world path")
	mouse(start,true)
	mouse(start,false)
	check(stick.active_touch == 2 and world.player.touch_vector.x > .99,"mouse events cannot cancel a native finger")
	touch(2,start,false)
	# Android can cancel a contact, including with the pressed flag still set.
	touch(4,start,true)
	touch(4,start,true,true)
	check(stick.active_touch == -1 and world.player.touch_vector == Vector2.ZERO,"OS cancellation releases capture")
	touch(4,start,false)
	touch(5,start,true)
	stick.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(stick.active_touch == -1 and world.player.touch_vector == Vector2.ZERO,"application focus loss releases capture")
	touch(5,start,false)
	touch(6,start,true)
	stick.hide()
	check(stick.active_touch == -1 and world.player.touch_vector == Vector2.ZERO,"hidden control releases capture")
	touch(6,start,false)
	stick.show()
	# Native mouse support remains functional alongside touch.
	mouse(start,true)
	check(stick.mouse_active and stick.value.x > .99,"mouse drag starts")
	touch(8,stick_point(center-Vector2(40,0)),true)
	touch(8,stick_point(center-Vector2(40,0)),false)
	check(stick.mouse_active and stick.value.x > .99,"touch events cannot steal a mouse drag")
	var motion := InputEventMouseMotion.new()
	motion.position = stick_point(center+Vector2(300,0))
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	check(stick.value.x > .99,"mouse outside drag preserves direction")
	mouse(motion.position,false)
	check(not stick.mouse_active and world.player.touch_vector == Vector2.ZERO,"mouse release stops movement")
	# Check the actual actor over physics ticks after a real GUI drag.
	world.player.global_position = Vector2(3580,3640)
	world.player.clear_click_path()
	var before_move: Vector2 = world.player.global_position
	touch(9,start,true)
	drag(9,stick_point(center+Vector2(300,0)))
	for i: int in range(25):
		await physics_frame
	check(world.player.global_position.x > before_move.x+40,"captured outside drag moves the actor right")
	check(absf(world.player.global_position.y-before_move.y) < 3,"outside drag does not introduce vertical drift")
	stick.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var stopped_at: Vector2 = world.player.global_position
	for i: int in range(5):
		await physics_frame
	check(world.player.global_position.distance_to(stopped_at) < 2,"suspend cancels physical movement")
	touch(9,start,false)
	world.queue_free()
	await process_frame
	print("INPUT checks=",checks)
	if failures.is_empty():
		print("INPUT_ROUTING_OK")
		quit(0)
	else:
		print("INPUT_ROUTING_FAILED: ",failures.size())
		quit(1)
