extends SceneTree
## Synthetic CPU/equivalence fixture. No device FPS claim.
class PlayerStub extends Node2D:
	var camera: Camera2D
class WorldStub extends Node:
	var player: PlayerStub
class PopulationFixture extends FieldPopulation:
	func _ready() -> void: pass

var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := WorldStub.new()
	world.player = PlayerStub.new()
	world.add_child(world.player)
	world.player.camera = Camera2D.new()
	world.player.add_child(world.player.camera)
	root.add_child(world)
	var population := PopulationFixture.new()
	world.add_child(population)
	population.set_process(false)
	population.world = world
	population.field = NativePngField.new()
	population.field.data = {"map_id":"escaros_world", "streaming":{"monster_sleep_distance":1000.0}}
	var scene: PackedScene = load("res://scenes/Monster.tscn")
	var actors: Array[TwilightMonster] = []
	for i: int in range(165):
		var monster: TwilightMonster = scene.instantiate()
		monster.set_physics_process(false)
		world.add_child(monster)
		monster.global_position = Vector2(i * 25.0, (i % 7) * 90.0)
		monster.ai = {"aggro_radius":420.0 + (i % 3) * 300.0}
		actors.append(monster)
		population.slots.append({"slot_id":i,"monster":monster})
	# Each independently sufficient busy condition at three camera zooms.
	var states: Array[String] = ["idle","dead","motion","aggro_remaining","returning_home","poison_remaining","bleed_remaining","slow_remaining","stun_remaining","hold_remaining","fear_remaining","silence_remaining"]
	for map_id: String in ["escaros_world", "aden_world"]:
		population.field.data.map_id = map_id
		for zoom: float in [0.5, 1.0, 2.0]:
			world.player.camera.zoom = Vector2.ONE * zoom
			for state: String in states:
				for monster: TwilightMonster in actors:
					monster.dead = state == "dead"
					monster.motion.active = state == "motion"
					monster.returning_home = state == "returning_home"
					for clock: String in states.slice(3):
						if clock != "returning_home": monster.set(clock,1.0 if clock == state else 0.0)
					monster.is_boss = state == "motion"
					monster.visible = true
					monster.velocity = Vector2(3,4)
				var expected: Array = []
				for monster: TwilightMonster in actors: expected.append(_expected(population,monster))
				population.wake_clock = 0.0
				population._process(0.01)
				for i: int in range(actors.size()):
					var monster: TwilightMonster = actors[i]
					check([monster.is_physics_processing(),monster.visible,monster.velocity] == expected[i],"%s/%s/%s/%d" % [map_id,zoom,state,i])
	# A direct spawn update and later sweeps must observe fresh camera geometry.
	population.field.data.map_id = "escaros_world"
	var probe: TwilightMonster = actors[0]
	probe.silence_remaining = 0.0
	world.player.camera.zoom = Vector2.ONE
	world.player.camera.position = Vector2(900,400)
	world.player.camera.force_update_scroll()
	var extent: Vector2 = population.get_viewport().get_visible_rect().size/world.player.camera.zoom
	var edge: float = maxf(extent.length()*.5+320.0,float(probe.ai.aggro_radius)*1.7+320.0)
	for point: Vector2 in [Vector2(edge-0.01,0),Vector2(edge,0),Vector2(edge+0.01,0),Vector2(1000,0)]:
		probe.global_position = point
		probe.velocity = Vector2(3,4)
		var expected: Array = _expected(population,probe)
		population._update_activity(probe)
		check([probe.is_physics_processing(),probe.visible,probe.velocity] == expected,"direct spawn/radius boundary %s" % point)
	probe.global_position = Vector2(3000,0)
	probe.set_physics_process(true)
	population.wake_clock = 0.4
	population._process(0.01)
	check(probe.is_physics_processing(),"no early refresh between 0.4 second sweeps")
	population.wake_clock = 0.0
	population._process(0.01)
	check(not probe.is_physics_processing(),"next sweep uses current radius")
	population.field = PlayableField.new()
	population.field.data = {"map_id":"legacy", "streaming":{"monster_sleep_distance":1000.0}}
	probe.global_position = Vector2(1000,0)
	probe.visible = true
	population.wake_clock = 0.0
	population._process(0.01)
	check(not probe.is_physics_processing() and probe.visible,"ordinary field strict sleep boundary and visibility preserved")
	population.field = NativePngField.new()
	population.field.data = {"map_id":"escaros_world", "streaming":{"monster_sleep_distance":1000.0}}
	var original_slots: Array[Dictionary] = population.slots
	var original_camera: Camera2D = world.player.camera
	population.slots = []
	world.player.camera = null
	population._process(0.4)
	check(population.slots.is_empty(),"empty sweep needs no camera context")
	population.slots = original_slots
	population.wake_clock = 0.4
	population._process(0.01)
	check(population.wake_clock > 0.0,"non-refresh sweep needs no camera context")
	world.player.camera = original_camera
	# Use the production refresh loop with a fixed idle crowd for CPU timing.
	population.field.data.map_id = "escaros_world"
	world.player.camera.position = Vector2.ZERO
	world.player.camera.zoom = Vector2.ONE * 2.0
	world.player.camera.force_update_scroll()
	actors[0].global_position = Vector2.ZERO
	for monster: TwilightMonster in actors:
		for clock: String in states.slice(3):
			if clock != "returning_home": monster.set(clock,0.0)
		monster.dead = false
		monster.motion.active = false
		monster.returning_home = false
	var samples: Array[int] = []
	for sample: int in range(7 if OS.get_environment("TWILIGHT_ACTIVITY_BENCHMARK") == "1" else 0):
		var started: int = Time.get_ticks_usec()
		for iteration: int in range(500): population._process(0.4)
		samples.append(Time.get_ticks_usec()-started)
	print("POPULATION_ACTIVITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actors":165,"refreshes_per_sample":500,"cpu_usec":samples,"scope":"synthetic_headless_cpu_not_device_fps"}))
	world.free()
	quit(0 if failures.is_empty() else 1)

func _expected(population: FieldPopulation, monster: TwilightMonster) -> Array:
	var distance: float = monster.global_position.distance_to(population.world.player.global_position)
	var awake: bool = distance < float(population.field.data.streaming.monster_sleep_distance)
	var shown: bool = monster.visible
	if str(population.field.data.map_id) == "escaros_world":
		var camera: Camera2D = population.world.player.camera
		var extent: Vector2 = population.get_viewport().get_visible_rect().size/camera.zoom
		var view := Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(240.0)
		var busy: bool = monster.dead or monster.motion.active or monster.aggro_remaining>0 or monster.returning_home or monster.poison_remaining>0 or monster.bleed_remaining>0 or monster.slow_remaining>0 or monster.is_stunned() or monster.is_held() or monster.is_feared() or monster.is_silenced()
		var radius: float = maxf(extent.length()*.5+320.0,float(monster.ai.get("aggro_radius",420.0))*1.7+320.0)
		awake = busy or distance<radius
		shown = view.has_point(monster.global_position) or (monster.is_boss and monster.motion.active)
	return [awake,shown,monster.velocity if awake else Vector2.ZERO]
