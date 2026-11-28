extends SceneTree
## Run in a disposable profile with the real 523 definitions and bank.
## Pass --current523-source-bank-config=... to select the private bank.
## --verify-render additionally compares the OpenGL gameplay viewport.

const BANK = preload("res://scripts/resources/current523_source_bank.gd")
const EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const VIEW = preload("res://scripts/monsters/current523_source_bank_view.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const ITEMS = preload("res://scripts/loot/patch523_item_inventory.gd")
const AMMO = preload("res://scripts/loot/patch523_ammo.gd")
const NPC_BODY: int = 2389

var checks: int = 0
var failures: Array[String] = []

class ExistingCombatReceiver extends Node:
	var patch523_npc_spells: RefCounted
	var field_population: Node
	var numbers: Array[String] = []
	var effects: Array[String] = []

	func show_combat_number(_point: Vector2, value: String, _color: Color, _critical: bool = false) -> void:
		numbers.append(value)

	func monster_combat_feedback(_target: TwilightMonster, _critical: bool, kind: String) -> void:
		effects.append(kind)

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, detail: String) -> bool:
	checks += 1
	if not ok:
		failures.append(detail)
		printerr("COMBAT_FEEDBACK_FAIL ",detail)
	return ok

func original_overlays(preview: Node, consumer: String, sprite: int) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node: Variant in preview._overlay_nodes:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		if node._reference_overlay_parent.get("consumer") == consumer and node.reference_bank_status.get("source_actor_id") == sprite:
			found.append(node)
	return found

func has_source_pixels(node: Node2D) -> bool:
	for layer: Sprite2D in node._layers:
		if layer.visible and layer.texture != null:
			var pixels: Image = layer.texture.get_image()
			if pixels != null and pixels.get_used_rect().has_area(): return true
	return false

func check_frames(overlay: Node2D, label: String) -> void:
	var visible_source: bool = has_source_pixels(overlay)
	# Some original effects start with a client-null frame.
	for step: int in 8:
		if visible_source: break
		overlay.advance_reference_source(1.0 / 24.0,"idle",overlay._overlay_facing)
		visible_source = has_source_pixels(overlay)
	check(visible_source,label+" has nonempty original sprite pixels")
	if visible_source and "--verify-render" in OS.get_cmdline_user_args():
		paused = true
		overlay.hide()
		await RenderingServer.frame_post_draw
		var before: PackedByteArray = root.get_texture().get_image().get_data()
		overlay.show()
		await RenderingServer.frame_post_draw
		var after: PackedByteArray = root.get_texture().get_image().get_data()
		paused = false
		check(before != after,label+" changes the rendered gameplay viewport")

func launch_normal(world: TwilightWorld, target: TwilightMonster, sample_seed: int) -> bool:
	world.auto_attack_timer = 0.0
	world.rng.seed = sample_seed
	world.selected_monster = target
	var count: int = target.damage_hit_count
	world.player.attack_requested.emit()
	if not check(not world.pending_attack.is_empty(),"game attack input queues the normal marker: "+world.hud.message_label.text): return false
	var attack_id: int = int(world.pending_attack.id)
	check(target.damage_hit_count == count,"damage waits for the attack marker")
	world.player.attack_strike.emit(attack_id)
	world.player.cancel_attack()
	return target.damage_hit_count > count

func equip_existing_sword_family(world: TwilightWorld) -> bool:
	# The original bank is also used with older saves carrying a local weapon
	# record. Exercise that same explicit motion-family route in Main.
	world.equipped_items.weapon = {"name":"Combat feedback test sword","slot":"weapon","type":"한손검","atk":1}
	world._invalidate_equipment_static()
	return AMMO.weapon_type(world._equipped_weapon_record()).is_empty() and world._mastery_actual_weapon_type() == 1

func check_healing_potion(world: TwilightWorld) -> void:
	var granted: Dictionary = ITEMS.stage(world,[{"item_class_id":233,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"isolated_original_potion_fixture"})
	if not check(granted.get("ok",false),"the exact original healing potion has a normal ownership receipt"): return
	var uid: String = ""
	for id: String in granted.overrides.item_instances:
		if not world.item_instances.has(id):
			uid = id
			break
	if not check(not uid.is_empty(),"the test can select the newly issued potion"): return
	var key: String = str(granted.overrides.item_instances[uid].name)
	world.inventory = granted.overrides.inventory
	world.item_instances = granted.overrides.item_instances
	world.hp = maxi(1,world._effective_max_hp()-200)
	var hp_before: int = world.hp
	var quantity: int = int(world.inventory[key])
	world._on_inventory_item_activated(key+"@@@"+uid)
	check(world.hp>hp_before and int(world.inventory.get(key,0))==quantity-1,"inventory use heals and consumes exactly one potion")
	await process_frame
	await process_frame
	var effect: Array[Node2D] = original_overlays(world.player.original_source_preview,"item_effect",16007)
	var status: String = str(world.option_awakening.combat.visual_results.get("16007","request missing"))
	if check(effect.size()==1,"the consumed ItemClass requests its exact original effect 16007: "+status+" / "+str(world.player.original_source_preview.source_effect_status.get("reason","no reason"))):
		await check_frames(effect[0],"healing potion")

func _run() -> void:
	var options: Dictionary = BANK.options()
	if not options.get("ok",false):
		print("COMBAT_FEEDBACK_PRIVATE_PACK_REQUIRED")
		quit(2)
		return
	var source: Dictionary = options.options
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	await process_frame
	check(QA.enter_game(world),"Main enters through normal class selection")
	await process_frame
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.level = 90
	if world.field_map == null and world.astar == null:
		# This visual test installs only the verified bank members it exercises.
		# Use the game's normal AStar combat visibility check on a clear cell.
		world.astar = AStarGrid2D.new()
		world.astar.region = Rect2i(world._world_to_cell(world.player.global_position) - Vector2i.ONE,Vector2i(3,3))
		world.astar.update()
	check(equip_existing_sword_family(world),"a legacy one-hand sword still resolves original WeaponType 1")
	world._refresh_speed_modifiers()
	check(world.combat_flights.original_visuals_only,"live projectiles use original pixels only")
	check(not world.player.has_node("PlayerActionFX"),"Main never allocates the authored swing and dust renderer")
	var miss: Dictionary = EFFECT.select_combat_result("miss")
	var final: Dictionary = EFFECT.select_combat_result("final_blow")
	check(miss.get("sprite_id") == 16023 and final.get("sprite_id") == 24259,"original result rows distinguish MISS and FinalBlow")
	check(EFFECT.select_weapon_critical(34).get("sprite_id") == 16404,"ranged gun uses its own declared critical effect")
	check(not EFFECT.select_weapon_critical(0).get("ok",false),"unarmed does not invent a weapon effect")
	check(not EFFECT.select_combat_result("unrelated").get("ok",false),"untyped result requests cannot emit")
	var target: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(target)
	target.setup({"name":"Combat feedback target","hp":900000,"ac":0},world.player,world,null)
	target.set_physics_process(false)
	target.global_position = world.player.global_position
	var body := PREVIEW.new()
	var view = VIEW.new()
	target.add_child(view)
	view.add_child(body)
	view._preview = body
	target.source_m_view = view
	check(body._configure_reference_bank(source.manifest_path,source.manifest_sha256,NPC_BODY,{"idle":3},{"idle":true},"idle","npc"),"real original NPC body fixture loads its unchanged idle data")
	body.source_selection_status = {"ok":true,"sprite_id":NPC_BODY}
	var player_preview: Node = world.player.original_source_preview
	target.critical_resistance = 1000
	var normal: bool = false
	for sample_seed: int in range(1,9):
		if launch_normal(world,target,sample_seed):
			normal = true
			break
	check(normal,"normal attack applies damage to the target once")
	var damage: Array[Node2D] = original_overlays(body,"damage_effect",1248)
	if check(damage.size() == 1,"successful hit requests the exact declared original body effect"):
		check(damage[0].global_position.is_equal_approx(target.global_position),"body effect anchors to the target")
		await check_frames(damage[0],"normal hit")
	check(original_overlays(player_preview,"weapon_critical",13411).is_empty(),"normal hit emits no weapon critical effect")
	world.combat_vfx.clear()
	player_preview.clear_current523_combat_feedback()
	target.critical_resistance = -1000
	var crit: Array[Node2D] = []
	for sample_seed: int in range(9,25):
		launch_normal(world,target,sample_seed)
		crit = original_overlays(player_preview,"weapon_critical",13411)
		if not crit.is_empty(): break
	if check(crit.size() == 1,"actual critical uses the worn sword's exact original effect once"):
		await check_frames(crit[0],"weapon critical")
	check(original_overlays(player_preview,"combat_result",16019).is_empty(),"ordinary attack shows no Critical title above the target")
	check(world.combat_vfx.active.any(func(row: Dictionary) -> bool: return row.kind == "number" and row.critical and not row.caption),"critical damage number remains on the target")
	player_preview.clear_current523_combat_feedback()
	var hp: int = target.hp
	target.show_miss()
	check(original_overlays(player_preview,"combat_result",16023).is_empty() and target.hp == hp,"a miss shows no title and applies no damage")
	check(not world.combat_vfx.active.any(func(row: Dictionary) -> bool: return row.kind in ["impact","ring"] or row.get("text") == "MISS"),"custom shapes and duplicate MISS text are absent")
	world.show_combat_number(target.combat_hit_position(),"CRIT 800",Color.WHITE,true,true)
	check(original_overlays(player_preview,"combat_result",24259).is_empty(),"final blow shows no title above the target")
	var emitted_before: int = world.combat_vfx.emitted
	world.player.show_miss()
	world.player.show_received_damage(9,true)
	world.player.show_status_text("GUARD")
	check(world.combat_vfx.emitted == emitted_before,"incoming combat does not draw text over the player")
	world._clear_combat_actions()
	check(original_overlays(player_preview,"weapon_critical",13411).is_empty() and original_overlays(player_preview,"combat_result",16023).is_empty(),"combat generation cleanup clears the original feedback")
	await check_healing_potion(world)
	var receiver := ExistingCombatReceiver.new()
	target.world_controller = receiver
	var hp_before: int = target.hp
	target.take_damage(5, false, "slash")
	target.take_damage(7, true, "magic")
	check(target.hp == hp_before - 12 and receiver.numbers == ["5", "CRIT 7"] and receiver.effects == ["slash", "magic"],"standalone combat receivers keep their existing callback signatures")
	target.world_controller = world
	receiver.free()
	world.queue_free()
	await process_frame
	print("COMBAT_FEEDBACK_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if not failures.is_empty() else 0)
