extends Node
class_name FieldPopulation

const COORD = preload("res://scripts/maps/world_coordinates.gd")
var world: Node
var field: PlayableField
var slots: Array[Dictionary] = []
var wake_clock: float = 0.0

func configure(controller: Node, value: PlayableField) -> void:
	world = controller
	field = value
	slots.clear()
	set_process(field != null)
	if field == null:
		return
	for region: Dictionary in field.data["monster_spawn"]:
		for index: int in range(int(region["max_count"])):
			var slot: Dictionary = {"region":region,"index":index,"monster":null,"remaining":0.0}
			slots.append(slot)
			_spawn_slot(slot)

func _spawn_slot(slot: Dictionary) -> void:
	var region: Dictionary = slot["region"]
	var p: Vector2 = field.sample_spawn(str(region["id"]),world.rng)
	if not p.is_finite():
		return
	var names: Array = region["monster_types"]
	var name_value: String = str(names[int(slot["index"]) % names.size()])
	var record: Dictionary = {}
	for candidate: Dictionary in world.monster_db:
		if str(candidate.get("name","")) == name_value:
			record = candidate
			break
	if record.is_empty():
		push_error("Unknown field monster: " + name_value)
		return
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.global_position = p
	monster.setup(record,world.player,world,world._monster_texture(record))
	# Keep names readable at the field's wider camera zoom.
	monster.name_label.add_theme_font_size_override("font_size",17)
	monster.name_label.add_theme_color_override("font_color",Color("fff0cc"))
	monster.home_position = p
	monster.spawn_region_id = str(region["id"])
	monster.roaming_radius = float(region["roaming_radius"])
	monster.collision_mask = 4
	monster.died.connect(world._on_monster_died)
	monster.player_hit.connect(world._on_player_hit)
	monster.selected.connect(world._select_monster)
	monster.set_meta("field_slot",slots.find(slot))
	slot["monster"] = monster
	slot["remaining"] = 0.0

func release(monster: TwilightMonster) -> void:
	for slot: Dictionary in slots:
		if slot["monster"] == monster:
			slot["monster"] = null
			slot["remaining"] = float(slot["region"]["respawn_time"])
			return

func _process(delta: float) -> void:
	if field == null:
		return
	wake_clock -= delta
	var refresh: bool = wake_clock <= 0.0
	if refresh:
		wake_clock = .4
	for slot: Dictionary in slots:
		var monster: TwilightMonster = slot["monster"] as TwilightMonster
		if not is_instance_valid(monster):
			slot["remaining"] = maxf(0.0,float(slot["remaining"])-delta)
			if float(slot["remaining"]) <= 0.0:
				_spawn_slot(slot)
		elif refresh:
			var distance: float = monster.global_position.distance_to(world.player.global_position)
			monster.set_physics_process(distance < float(field.data["streaming"]["monster_sleep_distance"]))
			if not monster.is_physics_processing():
				monster.velocity = Vector2.ZERO
