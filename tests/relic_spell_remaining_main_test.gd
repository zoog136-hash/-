extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
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
		world._equip_catalog("성물", {}); return
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
	world.inventory["명예 코인"] = 1000
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
	print("RELIC_MAIN_PHASE instantiate")
	world = load("res://Main.tscn").instantiate(); root.add_child(world); await frames(6)
	check(QA.enter_game(world, "광전사"), "real Main class confirmation")
	print("RELIC_MAIN_PHASE initial_ready")
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
	world._deal_successful_player_hit(dummy,10,false,"melee",true,false,{},true)
	var improved_damage: int = before_hp - dummy.hp
	before_hp = dummy.hp; world.rng.seed = seed_value
	world._deal_successful_player_hit(dummy,10,false,"melee")
	check(improved_damage > before_hp-dummy.hp,"secondary hit keeps main ordinary-attack flag and receives no unconfirmed native increment")
	before_hp = dummy.hp; world.rng.seed = seed_value
	world._deal_successful_player_hit(dummy,10,false,"melee",true,false,{},false,ordinary)
	check(before_hp-dummy.hp == improved_damage,"confirmed weapon-extra context keeps native increment independently of main ordinary-attack classification")
	relic(0); before_hp = dummy.hp; world.rng.seed = seed_value
	world._deal_successful_player_hit(dummy,10,false,"melee",true,false,{},true)
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
	check(catalog.resolve(lightning).get("relic_invoke_probability",{}).get("consumer","") == lightning.id, "upgrade card never becomes a separate proc")
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
	print("RELIC_MAIN_PHASE native_healing")
	change_job("투사")
	var dragon: Dictionary = catalog.record_for("드래곤 포스"); catalog.learned[str(dragon.id)] = 1
	relic(21518)
	var heal_skill: Dictionary = catalog.resolve(dragon)
	check(is_equal_approx(float(heal_skill.get("heal_percent",0)), .7) and int(heal_skill.heal) == 0 and heal_skill.has("recovery523") and not heal_skill.has("source523_block_reason"), "Dragon Force adds native child difference after source523 base50 percent and passes Category184")
	world.hp = 1; world.mp = world._effective_max_mp(); world.skill_global_cooldown = 0; world.skill_cooldowns.clear()
	var expected_hp: int = mini(world._effective_max_hp(),1+int(heal_skill.heal)+int(world._effective_max_hp()*.7))
	mp_before = world.mp; inventory = world.inventory.duplicate(true)
	check(world._cast_job_skill(str(dragon.id)) and world.hp == expected_hp, "actual Dragon Force cast heals host amount plus maxHP20 percent")
	check(world.mp == mp_before-int(heal_skill.mp) and int(world.inventory["명예 코인"]) == int(inventory["명예 코인"])-10, "Dragon Force retains one existing cost")
	var hp_before: int = world.hp; inventory = world.inventory.duplicate(true); world.mp = 0; world.skill_global_cooldown = 0; world.skill_cooldowns.clear()
	check(not world._cast_job_skill(str(dragon.id)) and world.hp == hp_before and world.inventory == inventory, "insufficient MP never grants child healing")
	relic(0); check(is_equal_approx(float(catalog.resolve(dragon).get("heal_percent",0)), .5), "release removes derived recovery fraction")
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
	check(world.mp == mp_before-int(catalog.resolve(life).mp) and int(world.inventory["명예 코인"]) == int(inventory["명예 코인"])-10, "Life Stream keeps original host resource debit")
	check(not world._cast_job_skill(str(life.id)) and int(service.shields[str(life.id)].amount) == expected_shield, "cooldown rejects duplicate cast and shield grant")
	await show_skill(life,"life-estimate","TWILIGHT 추정 회복 증가",Vector2i(854,480))
	change_job("뇌신")
	var protection: Dictionary = catalog.record_for("썬더 프로텍션"); catalog.learned[str(protection.id)] = 1
	relic(21518)
	var monster_with: int = service.incoming_damage(dummy,"magic",100)
	check(service.stat("pvpDamageReduction") == 1, "Thunder Protection exact native PvP delta")
	relic(0); var monster_without: int = service.incoming_damage(dummy,"magic",100)
	check(monster_with == monster_without, "PvP increment never leaks into ordinary monster damage")
	relic(21518); await show_skill(protection,"thunder-pvp-pending","PvP 소비자 연결 대기")
	var vitality: Dictionary=catalog.record_for("썬더 바이탈");catalog.learned[str(vitality.id)]=1
	var enhanced_cap: int=world._effective_max_hp()
	world._equip_catalog("성물",{})
	check(enhanced_cap>world._effective_max_hp(),"source vitality fixture really loses a relic-derived HP cap on release")
	relic(21518);world.hp=world._effective_max_hp();world.mp=world._effective_max_mp()
	check(world._save_game(true)==OK,"source cap release baseline committed")
	var full_hp: int=world.hp;var full_mp: int=world.mp
	var buffs_before: Dictionary=world.active_skill_buffs.duplicate(true)
	var release_hash: String=FileAccess.get_sha256(world.save_path())
	world.equipment_collections.save_blocked=true;world._equip_catalog("성물",{})
	check(world.hp==full_hp and world.mp==full_mp and world.active_skill_buffs==buffs_before,"failed cap-lowering release preserves live HP MP and buff state")
	check(int(world.equipped_catalog["성물"].source_card_id)==21518 and FileAccess.get_sha256(world.save_path())==release_hash,"failed cap-lowering release preserves primary and exact saved bytes")
	world.equipment_collections.save_blocked=false
	change_job("군주")
	var brave: Dictionary = catalog.record_for("브레이브 아머"); catalog.learned[str(brave.id)] = 1
	relic(21518); await show_skill(brave,"brave-pvp-pending","PvP 소비자 연결 대기")
	check(service.stat("pvpDamageReduction") == 1, "Brave Armor retains source-only PvP increment")
	check(not world.hud.skills_view.selection_sheet.has_method("_open_relic_training"), "invented training UI removed")
	# A controlled unlock fixture checks only composition; the existing native
	# item/inventory/UI transaction has its own unchanged Main regression.
	var unlock = preload("res://scripts/cards/native_relic_unlock_item.gd")
	var slot = preload("res://scripts/cards/native_relic_subslot.gd")
	world.card_draw_fusion.owned["성물"]["source:m508:98:20578"] = true
	world.option_awakening.progress[unlock.FIELD] = unlock.marker()
	world.hp = mini(world.hp,world._effective_max_hp()); world.mp = mini(world.mp,world._effective_max_mp())
	var before_level: int = int(RULES.level_for(world,4,0).bonus)
	check(world._save_game(true) == OK,"real integrated baseline save")
	var state_before: Dictionary = world.option_awakening.export_state().duplicate(true)
	var hash_before: String = FileAccess.get_sha256(world.save_path())
	check(world._save_game(true,{"equipped_catalog":world.equipped_catalog.duplicate(true),"hp":world.hp,"mp":world.mp}) == ERR_INVALID_DATA and FileAccess.get_sha256(world.save_path()) == hash_before,"unsealed card snapshot cannot bypass shared owner boundary")
	var primary_before: String = CARDS.card_id(world.equipped_catalog["성물"])
	world.equipment_collections.save_blocked = true
	relic(21428)
	check(CARDS.card_id(world.equipped_catalog["성물"]) == primary_before and FileAccess.get_sha256(world.save_path()) == hash_before,"failed primary save preserves source level and exact save")
	world.option_awakening.select_relic_subslot("source:m508:98:20578")
	check(world.option_awakening.export_state() == state_before and FileAccess.get_sha256(world.save_path()) == hash_before,"failed slot save preserves exact card state and save bytes")
	world.equipment_collections.save_blocked = false
	world.option_awakening.select_relic_subslot("source:m508:98:20578")
	check(world.option_awakening.relic_subslot_view().active,"main primary and existing native secondary coexist")
	check(int(RULES.level_for(world,4,0).bonus) == before_level,"secondary slot never duplicates primary spell-level bonus")
	for _index: int in range(3): catalog.resolve(brave); world._update_hud()
	check(service.stat("pvpDamageReduction") == 1,"HUD and source slot refresh never stack level increment")
	check(world._save_game(true) == OK,"integrated card/skill/HP/MP durable snapshot")
	var durable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var durable_hash: String = FileAccess.get_sha256(world.save_path())
	print("RELIC_MAIN_PHASE reconnect")
	world.queue_free(); await frames(4)
	RULES._rules.clear(); RULES._default_checked = false
	world = load("res://Main.tscn").instantiate(); world.set_process(false); root.add_child(world); freeze(); await frames(6)
	check(QA.enter_game(world,"군주"),"actual Main re-entry class flow")
	freeze(); service=world.original_skills; catalog=service.catalog
	check(RULES.ensure_loaded() and FileAccess.get_sha256(RULES.INSTALLED) == RULES.SOURCE_SHA256,"fresh re-entry reads installed verified source")
	check(normalized(world.option_awakening.export_state()) == durable.card_option_awakening,"re-entry preserves exact slot/awakening state")
	check(normalized(world.equipped_catalog) == durable.equipped_catalog and normalized(world.inventory) == durable.inventory and world.gold == int(durable.gold),"re-entry preserves equipped cards and resources")
	check(world.hp == int(durable.hp) and world.mp == int(durable.mp),"re-entry preserves exact current HP/MP (%d/%d -> %d/%d)" % [int(durable.hp),int(durable.mp),world.hp,world.mp])
	check(world.option_awakening.relic_subslot_view().active and service.stat("pvpDamageReduction") == 1 and int(RULES.level_for(world,4,0).bonus) == before_level,"re-entry recomputes source effects once alongside native slot")
	check(FileAccess.get_sha256(world.save_path()) == durable_hash,"re-entry never rewrites progression save")
	# Existing save vitals use 64-bit integers; a quote must not narrow them
	# to a coordinate vector even when the writer refuses the transaction.
	var normal_vitals: Array=[world.max_hp,world.max_mp,world.hp,world.mp]
	world.max_hp=3000000000;world.max_mp=4000000000;world.hp=2999999999;world.mp=3999999999
	world.equipment_collections.save_blocked=true;world._equip_catalog("성물",{})
	check(world.hp==2999999999 and world.mp==3999999999,"failed preview preserves existing 64-bit resource values")
	world.equipment_collections.save_blocked=false
	world.max_hp=int(normal_vitals[0]);world.max_mp=int(normal_vitals[1]);world.hp=int(normal_vitals[2]);world.mp=int(normal_vitals[3])
	print("RELIC_SPELL_REMAINING_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"renderer":DisplayServer.get_name()}))
	world.queue_free(); await frames(3); quit(0 if failures.is_empty() else 1)
