extends SceneTree
## Actual Main: transform weapon limit at equip/attack and the original
## SpellMove cast path. The original archive is optional (absent in CI).
const QA = preload("res://tests/qa_class_selection.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const FLASH_ID := "lmref_f7afaf54afcbb439"
var checks: int = 0
var failures: Array[String] = []
var real: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func first_weapon(world: Node, type: String) -> Dictionary:
	for item: Dictionary in world.catalog_db.get("아이템", []):
		if item.get("type") == type and item.get("slot") == "weapon" and not item.get("source_m_native_item", false): return item
	return {}

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world, "요정"), "actual Main class confirmation")
	world.player.set_physics_process(false)
	# Synthetic fixture monster (same pattern as symbol_offline_combat_test).
	var fixture: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(fixture)
	fixture.setup({"name":"이동 검증", "hp":999999, "lv":1, "ac":0, "crit":0}, world.player, world, null)
	fixture.set_physics_process(false)
	fixture.global_position = world.player.global_position + Vector2(20, 0)
	var archive: bool = not DEF.identity().is_empty()
	var sword: Dictionary = first_weapon(world, "한손검")
	var bow: Dictionary = first_weapon(world, "활")
	check(not sword.is_empty() and not bow.is_empty(), "catalog has a one-handed sword and a bow")
	world.source_gender_id = 2
	# Original Orc Archer transform record, as a loaded save would hold it.
	var archer: Dictionary = {}
	for value: Variant in world.catalog_db.get("변신", []):
		if value is Dictionary and int(value.get("source_card_id", -1)) == 66: archer = value; break
	real["archive"] = archive
	real["archer_found"] = not archer.is_empty()
	if archive and not archer.is_empty():
		world.equipped_catalog["변신"] = archer.duplicate(true)
		world._invalidate_equipment_static()
		world._equip_or_acquire_item(sword)
		check(str(world.equipped_items.get("weapon", {}).get("name", "")) != str(sword.name), "sword is rejected while transformed into the ranged form")
		real["sword_message"] = str(world.hud.message_label.text) if world.hud.get("message_label") != null else ""
		world._equip_or_acquire_item(bow)
		check(str(world.equipped_items.get("weapon", {}).get("name", "")) == str(bow.name), "bow is accepted while transformed")
		# A weapon worn before the transform stays worn; attacks are refused.
		world.equipped_catalog["변신"] = {}
		world._invalidate_equipment_static()
		world._equip_or_acquire_item(sword)
		check(str(world.equipped_items.get("weapon", {}).get("name", "")) == str(sword.name), "sword equips without a transform")
		world.equipped_catalog["변신"] = archer.duplicate(true)
		world._invalidate_equipment_static()
		var near: TwilightMonster = fixture
		if near != null:
			near.global_position = world.player.global_position + Vector2(20, 0)
			world.selected_monster = near
		world.auto_attack_timer = 0.0
		world.pending_attack = {}
		world._attack()
		check(world.pending_attack.is_empty(), "attack with a sword is refused in the ranged form")
		real["attack_blocked_timer"] = world.auto_attack_timer
		world.equipped_catalog["변신"] = {}
		world._invalidate_equipment_static()
		world.auto_attack_timer = 0.0
		world._attack()
		real["attack_monster"] = near != null
		check(near != null and not world.pending_attack.is_empty(), "sword attack works again without the transform")
		world.pending_attack = {}
	elif not archive:
		world._equip_or_acquire_item(sword)
		check(str(world.equipped_items.get("weapon", {}).get("name", "")) == str(sword.name), "no archive: equipping is unchanged")
	# Original SpellMove through the existing skill service.
	var skills = world.original_skills
	var flash: Dictionary = skills.catalog.record_for(FLASH_ID)
	check(not flash.is_empty(), "flash reference record exists")
	check(not skills.cast(flash), "reference flash stays blocked in normal play (cooldown/acquisition missing)")
	if archive and not flash.is_empty():
		world.job_class = "뇌신"
		var resolved: Dictionary = skills.catalog.resolve(flash)
		# The existing profile loader attaches the plan when it admits 523
		# profiles; otherwise the same original plan is attached here.
		real["profile_attached"] = resolved.has("spell_move523")
		if not resolved.has("spell_move523"): resolved["spell_move523"] = preload("res://scripts/skills/spell_move523.gd").plan(69381)
		var move: Dictionary = resolved.get("spell_move523", {})
		check(bool(move.get("ok", false)) and str(move.get("kind", "")) == "caster_dash", "flash carries the original dash plan")
		var target: TwilightMonster = fixture
		var cell: float = skills.spell_move.cell_length()
		var placed: bool = false
		if target != null:
			for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				var start: Vector2 = world.player.global_position
				var goal: Vector2 = start + direction * 5 * cell
				var clear: bool = true
				for index: int in range(1, 21):
					if not world._is_walkable_world(start.lerp(goal, index / 20.0)): clear = false; break
				if clear: target.global_position = goal; placed = true; break
		real["dash_target_placed"] = placed
		if placed:
			world.selected_monster = target
			world.mp = world._effective_max_mp()
			# Test-only: emulate the missing cooldown/acquisition data so the
			# real cast path runs. Normal play keeps the record blocked (above).
			resolved["cooldown"] = 0
			resolved["runtime_blocked"] = false
			resolved["hp"] = 0 # reference record has no HP cost value
			var before: Vector2 = world.player.global_position
			var mp_before: int = int(world.mp)
			var started: bool = skills._cast_spell_move(resolved)
			var guard: int = 0
			while skills.spell_move.busy() and guard < 600:
				skills.spell_move.tick(1.0 / 60.0); guard += 1
			var after: Vector2 = world.player.global_position
			check(started and before.distance_to(after) > 3 * cell - 1 and after.distance_to(target.global_position) <= cell + 1.0, "flash dash moves the player next to the monster")
			real["dash_message"] = str(world.hud.message_label.text)
			real["dash_reasons"] = {"cost":skills.cost_reason(resolved), "material":str(skills.material_plan(resolved).get("reason","")), "items":resolved.get("items",{}), "mp":resolved.get("mp")}
			real["flash_dash"] = {"before":str(before), "target":str(target.global_position), "after":str(after), "moved_cells":before.distance_to(after) / cell,
				"mp_before":mp_before, "mp_after":int(world.mp), "state":str(skills.spell_move.last_event.get("state", ""))}
	print("SPELL_MOVE_POLYMORPH523_MAIN_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
	quit(0 if failures.is_empty() else 1)
