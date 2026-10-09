extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failed: bool = false
var world: TwilightWorld
var hits: Array[int] = [0]

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failed = true; print("ATTACK PROFILES FAIL: "+message)

func _initialize() -> void: call_deferred("_run")

func make_actor(name_value: String, distance: float) -> TwilightMonster:
	var record: Dictionary = {}
	for entry: Dictionary in world.monster_db:
		if str(entry.name)==name_value: record = entry.duplicate(true); break
	record["hp"] = 999999
	var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(actor)
	actor.global_position = world.player.global_position-Vector2(distance,0)
	actor.setup(record,world.player,world,world._monster_texture(record))
	actor.home_position = actor.global_position
	actor.collision_mask = 4
	actor.set_physics_process(false)
	actor.player_hit.connect(func(_a: TwilightMonster, _d: int, _k: String) -> void: hits[0] += 1)
	return actor

func remove_actor(actor: TwilightMonster) -> void:
	world.combat_flights.clear()
	actor.queue_free()
	hits[0] = 0

func _run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world),"gameplay entry")
	world._set_map("aden_world",false)
	world.save_timer = -10000
	world.field_population.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for other: TwilightMonster in world.monsters_root.get_children(): other.set_physics_process(false)
	world.hp = 999999
	world.player.global_position = Vector2(3550,4300)
	var melee: TwilightMonster = make_actor("해골 근위병",40.)
	melee._tick_ai(.01)
	check(melee.motion.active,"melee begins windup")
	melee.motion.advance(.12,Vector2.ZERO)
	check(hits[0]==0,"no damage before strike")
	melee.motion.advance(.28,Vector2.ZERO)
	check(hits[0]==1,"one damage event at strike marker")
	melee.motion.advance(.5,Vector2.ZERO)
	check(hits[0]==1,"recovery cannot double-hit")
	melee.attack_cooldown = 0.
	melee._tick_ai(.01)
	world.player.global_position += Vector2(200,0)
	melee._tick_ai(.01)
	check(not melee.motion.active,"out-of-range melee windup cancels and pursues")
	remove_actor(melee)
	await process_frame
	world.player.global_position = Vector2(3550,4300)
	var archer: TwilightMonster = make_actor("해골 궁수",230.)
	archer._tick_ai(.01)
	archer.motion.advance(.45,Vector2.ZERO)
	check(world.combat_flights.flights.size()==1 and hits[0]==0,"arrow is released without instantaneous damage")
	if not world.combat_flights.flights.is_empty():
		var flight: Dictionary = world.combat_flights.flights[0]
		check(archer.motion.direction.dot((flight.aim-flight.position).normalized())>.98,"arrow aim matches attack direction")
	for i: int in range(5): world.combat_flights._physics_process(.1)
	check(hits[0]==1,"arrow collision resolves damage")
	hits[0] = 0
	archer.attack_cooldown = 0.; archer.motion.cancel_attack()
	archer._tick_ai(.01); archer.motion.advance(.45,Vector2.ZERO)
	world.player.global_position += Vector2(80,80)
	for i: int in range(5): world.combat_flights._physics_process(.1)
	check(hits[0]==0,"fixed aimed arrow misses a dodging player")
	world.player.global_position = Vector2(6700,4300)
	archer.global_position = Vector2(5500,4300)
	archer._launch_projectile(archer.motion.sequence,"ranged")
	for i: int in range(20): world.combat_flights._physics_process(.1)
	check(hits[0]==0 and world.combat_flights.flights.is_empty(),"river blocks actual projectile")
	remove_actor(archer)
	await process_frame
	world.player.global_position = Vector2(3550,4300)
	var caster: TwilightMonster = make_actor("서큐버스",230.)
	caster._tick_ai(.01); caster.motion.advance(.45,Vector2.ZERO)
	check(caster.motion.attack_style=="magic" and world.combat_flights.flights.size()==1,"cast motion releases elemental projectile")
	for i: int in range(7): world.combat_flights._physics_process(.1)
	check(hits[0]==1 and caster.attack_element=="dark","magic impact uses species element")
	var old_life: int = caster.life_id
	var source: Dictionary = world.monster_db[0]
	caster.setup(source,world.player,world,world._monster_texture(source))
	caster._resolve_attack(1,"magic",old_life)
	check(hits[0]==1,"stale missile cannot damage through reused actor")
	remove_actor(caster)
	await process_frame
	var passive: TwilightMonster = make_actor("왜곡의 라미아",40.)
	passive._tick_ai(.01)
	check(not passive.motion.active,"passive species does not attack nearby player")
	passive.take_damage(1)
	passive._tick_ai(.01)
	check(passive.motion.active,"passive species retaliates when attacked")
	passive.global_position = passive.home_position+Vector2(1300,0)
	passive._tick_ai(.01)
	check(passive.returning_home and not passive.motion.active,"leash cancels combat and returns home")
	remove_actor(passive)
	await process_frame
	var patterns: Dictionary = {}
	for entry: Dictionary in world.monster_db:
		if not entry.get("ai",{}).has("special"): continue
		var kind: String = str(entry.ai.special.kind)
		if patterns.has(kind): continue
		patterns[kind] = true
		world.player.global_position = Vector2(3550,4300)
		var boss: TwilightMonster = make_actor(str(entry.name),100.)
		boss._begin_special()
		check(boss.species_visual.warning_active,"boss warning "+kind)
		boss.motion.advance(.5,Vector2.ZERO)
		check(hits[0]==0,"boss windup safe before marker "+kind)
		boss.motion.advance(.6,Vector2.ZERO)
		check(not boss.species_visual.warning_active,"warning ends at skill marker "+kind)
		if kind=="volley":
			check(world.combat_flights.flights.size()==3,"boss volley produces three missiles")
			for i: int in range(15): world.combat_flights._physics_process(.1)
			check(hits[0]>0,"boss volley impacts")
		elif kind=="summon":
			check(world.field_population.summons.size()>0 and world.field_population.summons.size()<=4,"boss helpers are bounded")
			world.field_population.summon_for(boss); world.field_population.summon_for(boss)
			check(world.field_population.summons.size()<=4,"repeat summon respects cap")
			world.field_population._clear_summons(boss.get_instance_id())
		else: check(hits[0]==1,"boss skill damage occurs once "+kind)
		remove_actor(boss)
		await process_frame
	check(patterns.size()==7,"seven distinct implemented boss patterns")
	world.queue_free()
	await process_frame
	print("MONSTER_ATTACK_PROFILES_OK checks="+str(checks) if not failed else "MONSTER_ATTACK_PROFILES_FAILED")
	quit(1 if failed else 0)
