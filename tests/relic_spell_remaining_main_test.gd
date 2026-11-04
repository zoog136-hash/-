extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const TRAINING = preload("res://scripts/cards/relic_pvp_training.gd")
var world: TwilightWorld
var service: TwilightOriginalSkillService
var catalog: TwilightOriginalSkillCatalog
var dummy: TwilightMonster
var checks: int = 0
var failures: Array[String] = []
var captures: String = ""
var source: String = ""
func _initialize() -> void: call_deferred("run")
func frames(count: int = 3) -> void:
	for _index: int in range(count): await process_frame
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RELIC_REMAINING_FAIL ", message)
func freeze() -> void:
	world.set_process(false); world.save_timer = -100000
	world.player.set_physics_process(false); world.player.set_auto_enabled(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
func relic(id: int) -> void:
	if id == 0:
		world.equipped_catalog["성물"] = {}; world._invalidate_equipment_static(); world._refresh_speed_modifiers(); return
	for record: Dictionary in world.catalog_db["성물"]:
		if int(record.get("source_card_id", 0)) == id:
			world.card_draw_fusion.owned["성물"][CARDS.card_id(record)] = true
			world._equip_catalog("성물", record); return
	check(false, "required canonical relic " + str(id))
func change_job(job: String) -> void:
	check(QA.enter_game(world, job), "ordinary class selector " + job)
	catalog.learned.clear(); world.active_skill_buffs.clear()
	world.equipped_items.clear(); world._invalidate_equipment_static()
	service.clear(); world.skill_cooldowns.clear(); world.skill_global_cooldown = 0
	world.hp = world._effective_max_hp(); world.mp = world._effective_max_mp()
func weapon(kind: String) -> void:
	# Controlled combat input, never a source-art or item delivery claim.
	world.equipped_items["weapon"] = {"name":"검증 무기", "slot":"weapon", "type":kind}
	world._invalidate_equipment_static()
func boundary_seed(lower: float, upper: float) -> int:
	var random := RandomNumberGenerator.new()
	for value: int in range(100000):
		random.seed = value
		var roll: float = random.randf()
		if roll >= lower and roll < upper: return value
	return -1
func misses_with_proc_seed() -> int:
	var random := RandomNumberGenerator.new()
	for value: int in range(100000):
		random.seed = value
		if random.randf() >= .99 and random.randf() < .01: return value
	return -1
func event_count(id: String) -> int: return int(service.event_counts.get(id, 0))
func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size*.5)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = down
		root.push_input(event,true)
func show_skill(record: Dictionary, name_value: String, expected: String, extent: Vector2i = Vector2i(1280,720)) -> Node:
	world._update_hud(); world.hud.open_skills(); await frames(4)
	var view: Node = world.hud.skills_view
	view.search.text = str(record.name); view.search.text_changed.emit(view.search.text); await frames(3)
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].get("id", "")) == str(record.id):
			view.cards.select(index); view.cards.item_selected.emit(index); break
	root.size = extent; DisplayServer.window_set_size(extent); await frames(5)
	(view.find_child("BrowserCompactTabs",true,false).get_child(1) as Button).pressed.emit()
	await frames(3)
	check(str(view.selected.get("id", "")) == str(record.id) and view.detail.text.contains(expected), "ordinary exact skill inspector " + name_value)
	if not captures.is_empty() and DisplayServer.get_name() != "headless":
		view.selection_sheet.scroll.scroll_vertical = int(view.selection_sheet.scroll.get_v_scroll_bar().max_value)
		await frames(3); await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(captures)
		check(root.get_texture().get_image().save_png(captures.path_join(name_value + ".png")) == OK, "actual UI capture " + name_value)
	return view
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="): source = arg.trim_prefix("--source-zip=")
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	world = load("res://Main.tscn").instantiate(); root.add_child(world); await frames(6)
	check(QA.enter_game(world, "광전사"), "real Main class confirmation")
	freeze(); world._clear_monsters(); world.level = 90
	service = world.original_skills; catalog = service.catalog
	check(RULES.install_source(source).get("ok", false), "durable verified source installation")
	var arena: Vector2 = POSITIONS.combat(world, [Vector2(30,0)])
	check(arena.is_finite(), "current original-map combat ground")
	if not arena.is_finite(): world.queue_free(); await frames(); quit(1); return
	world.player.global_position = arena
	dummy = load("res://scenes/Monster.tscn").instantiate(); world.monsters_root.add_child(dummy)
	dummy.setup({"name":"성물 발동 검사 NPC","hp":100000,"lv":1,"mr":0,"ac":0,"stun_resistance":0},world.player,world,null)
	dummy.global_position = arena + Vector2(30,0); dummy.set_physics_process(false)
	world.selected_monster = dummy
	change_job("광전사"); weapon("도끼")
	var crash: Dictionary = catalog.record_for("크래쉬"); catalog.learned[str(crash.id)] = 1
	var seed_value: int = boundary_seed(.1,.105)
	check(seed_value >= 0, "Crash probability boundary fixture")
	relic(0); service.event_counts.clear(); world.rng.seed = seed_value
	world._try_trigger_passives("on_hit",dummy,"melee",true,false)
	check(event_count(str(crash.id)) == 0, "Crash base chance retains failure")
	relic(21428); service.event_counts.clear(); world.rng.seed = seed_value
	world._try_trigger_passives("on_hit",dummy,"melee",true,false)
	check(event_count(str(crash.id)) == 1, "Crash native half-point consumed by world successful-hit API")
	weapon("한손검"); service.event_counts.clear(); world.rng.seed = seed_value
	world._try_trigger_passives("on_hit",dummy,"melee",true,false)
	check(event_count(str(crash.id)) == 0, "Crash native weapon241 rejects swords")
	weapon("창"); service.event_counts.clear(); world.rng.seed = seed_value
	world._try_trigger_passives("on_hit",dummy,"melee",true,false)
	check(event_count(str(crash.id)) == 1, "Crash native membership permits spear")
	service.event_counts.clear(); world.rng.seed = seed_value
	world._try_trigger_passives("on_hit",dummy,"melee",true,true)
	check(event_count(str(crash.id)) == 0, "Crash increment excludes spell attacks")
	await show_skill(crash, "crash-scope", "도끼·창")
	change_job("마검사"); weapon("마검")
	var rune: Dictionary = catalog.record_for("룬 블로우"); catalog.learned[str(rune.id)] = 1
	relic(21428); seed_value = boundary_seed(.08,.09)
	var ordinary: Dictionary = service.attack_context("melee",false,true)
	world.rng.seed = seed_value
	check(service.outgoing_damage(10, ordinary) == 30, "Rune Blow resolved source chance reaches existing amplification API")
	world.rng.seed = seed_value
	check(service.outgoing_damage(10, service.attack_context("melee",true,true)) == 10, "Rune native increment excludes skills")
	world.rng.seed = seed_value
	check(service.outgoing_damage(10) == 10, "Rune native increment requires confirmed context")
	var before_hp: int = dummy.hp; world.rng.seed = seed_value
	world._deal_successful_player_hit(dummy,10,false,ordinary)
	var improved_damage: int = before_hp - dummy.hp
	relic(0); before_hp = dummy.hp; world.rng.seed = seed_value
	world._deal_successful_player_hit(dummy,10,false,ordinary)
	check(improved_damage > before_hp - dummy.hp, "actual damage boundary consumes Rune source increment")
	relic(21428); await show_skill(rune, "rune-invoke", "발동률 +1.00%p")
	change_job("뇌신")
	var lightning: Dictionary = catalog.record_for("라이트닝 스트라이크")
	var mystic: Dictionary = catalog.record_for("라이트닝 스트라이크(미스틱)")
	catalog.learned[str(lightning.id)] = 1; catalog.learned[str(mystic.id)] = 1
	relic(21488); seed_value = boundary_seed(.15,.16)
	service.event_counts.clear(); world.rng.seed = seed_value
	world._try_trigger_passives("on_hit",dummy,"melee",true,false)
	check(event_count(str(lightning.id)) == 1, "Mystic ancestry applies native chance to existing base consumer")
	check(catalog.resolve(lightning).relic_invoke_probability.consumer == lightning.id, "upgrade card never becomes a separate proc")
	var miss_seed: int = misses_with_proc_seed(); check(miss_seed >= 0, "normal-miss probability fixture")
	relic(0); service.event_counts.clear(); world.rng.seed = miss_seed
	world._resolve_normal_attack(dummy,"melee")
	check(event_count(str(lightning.id)) == 0, "no relic preserves previously absent miss proc")
	relic(21488); service.event_counts.clear(); world.rng.seed = miss_seed
	var inventory: Dictionary = world.inventory.duplicate(true); var mp_before: int = world.mp
	world._resolve_normal_attack(dummy,"melee")
	check(event_count(str(lightning.id)) == 1, "native Param5 allows only added chance on an actual missed normal attack")
	check(world.inventory == inventory and world.mp == mp_before, "native miss invoke preserves existing no-cost passive behavior")
	await show_skill(lightning, "lightning-miss", "명중·빗나감")
	change_job("투사")
	var dragon: Dictionary = catalog.record_for("드래곤 포스"); catalog.learned[str(dragon.id)] = 1
	relic(21518)
	var heal_skill: Dictionary = catalog.resolve(dragon)
	check(is_equal_approx(float(heal_skill.get("heal_percent",0)), .2) and int(heal_skill.heal) == int(dragon.heal), "Dragon Force consumes exact child recovery difference without replacing host base")
	world.hp = 1; world.mp = world._effective_max_mp(); world.skill_global_cooldown = 0; world.skill_cooldowns.clear()
	var expected_hp: int = mini(world._effective_max_hp(),1+int(dragon.heal)+int(world._effective_max_hp()*.2))
	mp_before = world.mp; inventory = world.inventory.duplicate(true)
	check(world._cast_job_skill(str(dragon.id)) and world.hp == expected_hp, "actual Dragon Force cast heals host amount plus maxHP20 percent")
	check(world.mp == mp_before-int(dragon.mp) and world.inventory == inventory, "Dragon Force retains one existing cost")
	var hp_before: int = world.hp; world.mp = 0; world.skill_global_cooldown = 0; world.skill_cooldowns.clear()
	check(not world._cast_job_skill(str(dragon.id)) and world.hp == hp_before and world.inventory == inventory, "insufficient MP never grants child healing")
	relic(0); check(float(catalog.resolve(dragon).get("heal_percent",0)) == 0, "release removes derived recovery fraction")
	relic(21518); await show_skill(dragon, "dragon-recovery", "최대 HP의 +20.00%p", Vector2i(854,480))
	change_job("뇌신")
	var plasma: Dictionary = catalog.record_for("플라즈마 다이브"); catalog.learned[str(plasma.id)] = 1
	relic(21518)
	world.hp = 1; world.mp = world._effective_max_mp(); world.skill_global_cooldown = 0; world.skill_cooldowns.clear()
	expected_hp = mini(world._effective_max_hp(),1+int(plasma.heal)+int(world._effective_max_hp()*.05))
	check(world._cast_job_skill(str(plasma.id)) and world.hp == expected_hp, "Plasma actual cast consumes configured maxHP5 percent estimate")
	var view: Node = await show_skill(plasma, "plasma-estimate", "TWILIGHT 추정 회복 증가", Vector2i(854,480))
	check(view.selection_sheet.category.text.contains("TWILIGHT 추정"), "recovery estimate visible in inspector header")
	view.selection_sheet._switch_skill_tab(true)
	check(view.detail.text.contains("Restoration 2 → 12") and view.detail.text.contains("자식 69631"), "source tab names exact missing Restoration definitions")
	change_job("마검사")
	var life: Dictionary = catalog.record_for("라이프 스트림"); catalog.learned[str(life.id)] = 1
	relic(21518); world.hp = world._effective_max_hp()-50; world.mp = world._effective_max_mp()
	world.skill_global_cooldown = 0; world.skill_cooldowns.clear()
	var expected_shield: int = mini(world._effective_max_hp(),int(life.heal)+int(world._effective_max_hp()*.05)-50)
	mp_before = world.mp; inventory = world.inventory.duplicate(true)
	check(world._cast_job_skill(str(life.id)) and world.hp == world._effective_max_hp(), "Life Stream estimated increment reaches real heal cap")
	check(int(service.shields.get(str(life.id),{}).get("amount",-1)) == expected_shield, "Life Stream preserves existing overflow shield conversion")
	check(world.mp == mp_before-int(life.mp) and world.inventory == inventory, "Life Stream keeps original host resource debit")
	check(not world._cast_job_skill(str(life.id)) and int(service.shields[str(life.id)].amount) == expected_shield, "cooldown rejects duplicate cast and shield grant")
	await show_skill(life,"life-estimate","TWILIGHT 추정 회복 증가",Vector2i(854,480))
	change_job("뇌신")
	var protection: Dictionary = catalog.record_for("썬더 프로텍션"); catalog.learned[str(protection.id)] = 1
	relic(21518)
	var monster_with: int = service.incoming_damage(dummy,"magic",100)
	check(service.stat("pvpDamageReduction") == 1, "Thunder Protection exact native PvP delta")
	relic(0); var monster_without: int = service.incoming_damage(dummy,"magic",100)
	check(monster_with == monster_without, "PvP increment never leaks into ordinary monster damage")
	relic(21518); world.hp = world._effective_max_hp()
	view = await show_skill(protection, "pvp-training", "자체 로컬 훈련", Vector2i(854,480))
	check(view.selection_sheet.relic_training_button.is_visible_in_tree(), "existing skill inspector exposes explicit own-rule PvP training")
	var button: Control = view.selection_sheet.relic_training_button
	var button_rect: Rect2 = root.get_final_transform() * (button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,button.size))
	check(Rect2(Vector2.ZERO,Vector2(854,480)).grow(1).encloses(button_rect), "training entry fits actual small window")
	check(world._save_game(true) == OK, "training baseline is durable")
	var training_hash: String = FileAccess.get_sha256(world.save_path())
	var training_hp: int = world.hp
	check(world._save_training_hp(training_hp+1) != OK and world._save_training_hp(0) != OK and FileAccess.get_sha256(world.save_path()) == training_hash, "dedicated staged HP endpoint rejects healing and lethal debit")
	tap(view.selection_sheet.relic_training_button); await frames(3)
	var modal: Control = world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(modal != null and int(modal.quantity.value) == 100, "training opens existing once-only quantity confirmation")
	if not captures.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(captures.path_join("pvp-training-confirmation.png")) == OK, "actual own-rule training confirmation capture")
	modal.cancel_button.pressed.emit(); await frames(3)
	check(world.hp == training_hp and FileAccess.get_sha256(world.save_path()) == training_hash, "training cancel preserves HP and durable bytes")
	view.selection_sheet.relic_training_button.pressed.emit(); await frames(3)
	modal = world.hud.get_node("Root").get_node("TwilightConfirmation")
	world.equipment_collections.save_blocked = true
	modal.confirm_button.pressed.emit(); await frames(3)
	check(world.hp == training_hp and FileAccess.get_sha256(world.save_path()) == training_hash, "actual UI training save failure applies no HP debit")
	world.equipment_collections.save_blocked = false
	inventory = world.inventory.duplicate(true); var training_gold: int = world.gold
	view.selection_sheet.relic_training_button.pressed.emit(); await frames(3)
	modal = world.hud.get_node("Root").get_node("TwilightConfirmation")
	var writes: int = world.equipment_collections.save_writes
	modal.confirm_button.pressed.emit(); modal.confirm_button.pressed.emit(); await frames(3)
	check(world.hp == training_hp-99 and world.equipment_collections.save_writes == writes+1, "training source reduction and duplicate-accept protection commit one HP debit")
	var durable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(durable.hp) == world.hp and world.inventory == inventory and world.gold == training_gold, "training persists actual HP without resources or rewards")
	if not captures.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(captures.path_join("pvp-training-result.png")) == OK, "actual committed training HP capture")
	world.hp = 3
	var minimum: Dictionary = TRAINING.apply(world,100)
	check(minimum.ok and world.hp == 1 and not TRAINING.apply(world,100).ok, "own training floor prevents death and repeated depletion")
	change_job("군주")
	var armor: Dictionary = catalog.record_for("브레이브 아머"); catalog.learned[str(armor.id)] = 1
	relic(21488)
	check(service.stat("pvpDamageReduction") == 1 and int(TRAINING.preview(world,100).reduction) == 1, "Brave Armor native delta reaches same explicit player-training consumer")
	await show_skill(armor,"brave-pvp-training","자체 로컬 훈련",Vector2i(854,480))
	change_job("뇌신")
	catalog.learned[str(protection.id)] = 1
	# Persist the new independent behaviors; the passive projections themselves
	# add no progress fields and are always rebuilt from the verified source.
	catalog.learned[str(lightning.id)] = 1; catalog.learned[str(mystic.id)] = 1
	world.equipped_items.clear(); world._invalidate_equipment_static(); relic(21488)
	world.hp = mini(123,world._effective_max_hp()); world.mp = mini(77,world._effective_max_mp())
	check(world._save_game(true) == OK, "durable actual progression after native integration")
	var save_path: String = world.save_path(); var disk_hash: String = FileAccess.get_sha256(save_path)
	var saved_gold: int = world.gold; var saved_inventory: Dictionary = world.inventory.duplicate(true)
	var saved_owned: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	world.equipment_collections.save_blocked = true
	check(world._save_game(true) != OK and FileAccess.get_sha256(save_path) == disk_hash, "real blocked-save failure preserves exact prior bytes")
	check(world.gold == saved_gold and world.inventory == saved_inventory, "save refusal never debits source resources")
	world.equipment_collections.save_blocked = false
	check(world._save_game(true) == OK, "save retry can safely acknowledge durable snapshot")
	disk_hash = FileAccess.get_sha256(save_path)
	world.queue_free(); await frames(5)
	RULES._rules = {}; RULES._default_checked = false; RULES.revision += 1
	world = load("res://Main.tscn").instantiate(); root.add_child(world); await frames(6)
	freeze(); service = world.original_skills; catalog = service.catalog
	check(world.job_class == "뇌신" and not bool(world.hud.class_picker_initial), "fresh Main re-entry restores real saved class")
	check(RULES.ensure_loaded() and FileAccess.get_sha256(RULES.INSTALLED) == RULES.SOURCE_SHA256, "re-entry loads durable authorized source installation")
	check(world.gold == saved_gold and normalized(world.inventory) == normalized(saved_inventory) and normalized(world.card_draw_fusion.export_state()) == normalized(saved_owned), "re-entry preserves inventory gold and card ownership across JSON numeric types")
	lightning = catalog.record_for("라이트닝 스트라이크")
	check(catalog.owned(lightning) and catalog.resolve(lightning).has("relic_invoke_probability"), "re-entry rebuilds exact native base/upgrade invoke contract")
	check(FileAccess.get_sha256(save_path) == disk_hash, "re-entry and derived projections do not rewrite save bytes")
	print("RELIC_SPELL_REMAINING_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"renderer":DisplayServer.get_name()}))
	world.queue_free(); await frames(3); quit(0 if failures.is_empty() else 1)
