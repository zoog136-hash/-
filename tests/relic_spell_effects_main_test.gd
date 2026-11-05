extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
var checks: int = 0
var failures: Array[String] = []
var world: TwilightWorld
var dummy: TwilightMonster
var captures: String = ""
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RELIC_EFFECT_MAIN_FAIL ", message)
func frames(count: int = 3) -> void:
	for _index: int in range(count): await process_frame
func prepare_cast() -> void:
	world._clear_combat_actions()
	world.skill_global_cooldown = 0
	world.skill_cooldowns.clear()
	world.mp = world._effective_max_mp()
func hit(skill: Dictionary) -> int:
	world.rng.seed = 313
	var before: int = dummy.hp
	world.original_skills.deal_damage(skill, dummy)
	return before - dummy.hp
func run() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="): path = arg.trim_prefix("--source-zip=")
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	world = load("res://Main.tscn").instantiate()
	root.add_child(world); await frames(6)
	check(QA.enter_game(world, "마법사"), "real Main enters mage class")
	world.set_process(false); world.save_timer = -100000
	world.player.set_physics_process(false); world.player.set_auto_enabled(false)
	world.field_population.set_process(false); world._clear_monsters()
	world.level = 90
	world.equipped_items.clear(); world._invalidate_equipment_static()
	var position: Vector2 = POSITIONS.combat(world, [Vector2(30, 0)])
	check(position.is_finite(), "combat fixture uses actual current source-map ground")
	if not position.is_finite(): world.queue_free(); await frames(); quit(1); return
	world.player.global_position = position
	dummy = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"성물 레벨 검사 NPC", "hp":10000, "lv":1, "mr":0, "ac":0, "stun_resistance":0}, world.player, world, null)
	dummy.global_position = position + Vector2(30,0); dummy.set_physics_process(false)
	world.selected_monster = dummy
	var service: TwilightOriginalSkillService = world.original_skills
	var catalog: TwilightOriginalSkillCatalog = service.catalog
	var ice: Dictionary = catalog.record_for("아이스 스파이크")
	var advance: Dictionary = catalog.record_for("어드밴스 스피릿")
	catalog.learned[str(ice.id)] = 1; catalog.learned[str(advance.id)] = 1
	var initial_power: int = int(catalog.resolve(ice).power)
	check(RULES.load_source(path).get("ok", false), "authorized native source loaded")
	check(int(catalog.resolve(ice).power) == initial_power, "source load without relic preserves attack")
	var native_hash: int = hash(ice)
	prepare_cast()
	check(service.cast(advance), "existing buff cast works before relic")
	var remaining: float = world.active_skill_buffs[str(advance.name)].remaining
	var base_hp_stat: float = service.stat("hp")
	var base_mp_stat: float = service.stat("mp")
	var ordinary_damage: int = hit(catalog.resolve(ice))
	var relic: Dictionary = {}
	for row: Dictionary in world.catalog_db["성물"]:
		if int(row.get("source_card_id", 0)) == 21428: relic = row; break
	world.card_draw_fusion.owned["성물"][CARDS.card_id(relic)] = true
	check(world._save_game(true) == OK, "durable fixture before passive projection")
	var save_hash: String = FileAccess.get_sha256(world.save_path())
	var gold: int = world.gold
	var inventory: Dictionary = world.inventory.duplicate(true)
	var mp_before: int = world.mp
	world._equip_catalog("성물", relic)
	var boosted: Dictionary = catalog.resolve(ice)
	check(int(boosted.power) == initial_power + 5 and int(boosted.relic_spell_effect.effective_level) == 1, "catalog resolves native grade and damage delta")
	check(int(catalog.resolve(ice.duplicate(true)).power) == initial_power + 5, "exact UI and quickslot copies resolve through canonical source")
	var altered: Dictionary = ice.duplicate(true)
	altered["power"] = initial_power + 500
	check(not catalog.resolve(altered).has("relic_spell_effect"), "altered same-ID record cannot gain native projection")
	check(hit(boosted) == ordinary_damage + 5, "real successful damage path consumes increment once")
	for _index: int in range(8): catalog.resolve(ice)
	check(int(catalog.resolve(ice).power) == initial_power + 5 and hash(ice) == native_hash, "cache projections never stack or mutate source records")
	check(service.stat("hp") == base_hp_stat + 30 and service.stat("mp") == base_mp_stat + 20, "already active buff follows relic stat changes")
	check(world.active_skill_buffs[str(advance.name)].remaining == remaining and world.mp == mp_before, "refresh does not recast extend time or charge MP")
	prepare_cast()
	var cast_mp: int = world.mp
	check(world._cast_job_skill(str(ice.id)), "existing quickslot path can actually cast with relic")
	check(int(world.pending_attack.get("original_skill", {}).get("power", 0)) == initial_power + 5, "paid action carries boosted snapshot to motion marker")
	check(world.mp == cast_mp - int(boosted.mp), "existing cast pays exactly one unchanged MP cost")
	world._clear_combat_actions()
	world.equipped_catalog["성물"] = {}; world._invalidate_equipment_static()
	check(int(catalog.resolve(ice).power) == initial_power and hit(catalog.resolve(ice)) == ordinary_damage, "release restores catalog and actual damage")
	check(service.stat("hp") == base_hp_stat and service.stat("mp") == base_mp_stat, "release refreshes active buff without stacking")
	check(world.active_skill_buffs[str(advance.name)].remaining == remaining, "release preserves remaining buff time")
	world._equip_catalog("성물", relic)
	world.card_draw_fusion.owned["성물"].erase(CARDS.card_id(relic))
	check(int(catalog.resolve(ice).power) == initial_power, "loss of permanent ownership invalidates cached effect")
	world.card_draw_fusion.owned["성물"][CARDS.card_id(relic)] = true
	check(int(catalog.resolve(ice).power) == initial_power + 5, "ownership restoration recalculates without extra level")
	var rules_before: Dictionary = RULES._rules
	RULES._rules = {}; RULES._default_checked = true; RULES.revision += 1
	check(service.stat("hp") == base_hp_stat and int(catalog.resolve(ice).power) == initial_power, "absent optional pack removes derived saved buff and damage increments")
	check(world.active_skill_buffs[str(advance.name)].remaining == remaining, "pack loss does not reset buff time")
	RULES._rules = rules_before; RULES.revision += 1
	check(service.stat("hp") == base_hp_stat + 30, "verified source restoration reapplies one increment")
	# Native learned=1 is ownership; a larger legacy value must not invent level5.
	catalog.learned[str(ice.id)] = 5
	check(int(catalog.resolve(ice).power) == initial_power + 5 and int(catalog.resolve(ice).relic_spell_effect.effective_level) == 1, "host learned number is not native spell growth")
	catalog.learned[str(ice.id)] = 1
	world.hud.open_skills(); await frames(5)
	var view: Node = world.hud.skills_view
	view.search.text = "아이스 스파이크"; view.search.text_changed.emit(view.search.text); await frames(3)
	check(view.detail.text.contains("스킬 기본 피해 +5.00") and not view.selection_sheet.source_active, "ordinary skill usage tab displays actual applied increment")
	view.selection_sheet._switch_skill_tab(true)
	check(view.detail.text.contains("성물 · 원본 스킬 레벨 0 → 1"), "source tab retains exact native level evidence")
	view.selection_sheet._switch_skill_tab(false)
	for extent: Vector2i in [Vector2i(1280,720), Vector2i(854,480)]:
		root.size = extent; DisplayServer.window_set_size(extent); await frames(6)
		(view.find_child("BrowserCompactTabs", true, false).get_child(1) as Button).pressed.emit(); await frames(3)
		view.selection_sheet.scroll.scroll_vertical = int(view.selection_sheet.scroll.get_v_scroll_bar().max_value)
		await frames(3)
		check(view.detail.is_visible_in_tree() and view.detail.text.contains("스킬 기본 피해 +5.00"), "applied increment accessible in skill inspector " + str(extent))
		if not captures.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(captures)
			check(root.get_texture().get_image().save_png(captures.path_join("relic-skill-effect-" + str(extent.x) + ".png")) == OK, "actual skill increment capture " + str(extent))
	# Passive cache and MP conversion use the same resolver across jobs.
	world.job_class = "군주"
	var vitality: Dictionary = catalog.record_for("브레이브 바이탈")
	catalog.learned[str(vitality.id)] = 1
	var stat_on: float = catalog.stat("hp")
	world.equipped_catalog["성물"] = {}
	check(stat_on - catalog.stat("hp") == 50, "passive stat cache invalidates on relic release")
	world.job_class = "요정"; world.equipped_catalog["성물"] = relic.duplicate(true)
	var convert: Dictionary = catalog.record_for("블러드 투 소울")
	catalog.learned[str(convert.id)] = 1
	prepare_cast(); world.mp = 0; world.hp = world._effective_max_hp()
	var hp_before: int = world.hp
	check(world._cast_job_skill(str(convert.id)) and world.mp == int(convert.mana) + 1, "actual MP recovery cast consumes native increment")
	check(world.hp == hp_before - int(convert.hp), "conversion preserves user HP cost")
	world.job_class = "투사"
	for row: Dictionary in world.catalog_db["성물"]:
		if int(row.get("source_card_id", 0)) == 21488:
			world.card_draw_fusion.owned["성물"][CARDS.card_id(row)] = true
			world.equipped_catalog["성물"] = row.duplicate(true)
			break
	var shield: Dictionary = catalog.record_for("드래곤 실드")
	catalog.learned[str(shield.id)] = 1
	var reduction_on: int = service.incoming_damage(dummy, "magic", 100)
	world.equipped_catalog["성물"] = {}
	var reduction_off: int = service.incoming_damage(dummy, "magic", 100)
	check(reduction_on == reduction_off - 1, "actual monster damage consumes PvE-only increment")
	world.job_class = "군주"
	var excalibur: Dictionary = catalog.record_for("엑스칼리버")
	catalog.learned[str(excalibur.id)] = 1
	var normal_status: Dictionary = catalog.resolve(excalibur)
	for row: Dictionary in world.catalog_db["성물"]:
		if int(row.get("source_card_id", 0)) == 21488: world.equipped_catalog["성물"] = row.duplicate(true); break
	var improved_status: Dictionary = catalog.resolve(excalibur)
	check(is_equal_approx(float(improved_status.status_chance) - float(normal_status.status_chance), .03), "source probability difference reaches existing status action")
	var status_seed: int = -1
	var random := RandomNumberGenerator.new()
	for candidate: int in range(10000):
		random.seed = candidate
		var roll: float = random.randf()
		if roll >= float(normal_status.status_chance) and roll < float(improved_status.status_chance): status_seed = candidate; break
	check(status_seed >= 0, "deterministic probability boundary fixture")
	world.rng.seed = status_seed
	check(not service.status.apply(normal_status, dummy, world), "unchanged base probability retains actual failure")
	world.rng.seed = status_seed
	check(service.status.apply(improved_status, dummy, world) and dummy.stun_remaining > 0, "native increment changes actual status result at same RNG boundary")
	check(catalog.RELIC_LEVELS.EFFECTS.detail_text(improved_status).contains("게임 적용 설정"), "probability UI identifies configurable host integration")
	world._update_hud()
	view.search.text = "엑스칼리버"; view.search.text_changed.emit(view.search.text); await frames(3)
	# The browser also finds reference skills whose descriptions mention this
	# name. Select the exact existing execution ID through the ordinary row.
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].get("id", "")) == str(excalibur.id):
			view.cards.select(index); view.cards.item_selected.emit(index); break
	await frames(3)
	check(view.detail.text.contains("상태 성공률 +3.00%p") and view.detail.text.contains("게임 적용 설정"), "actual skill inspector distinguishes source increment and host probability policy")
	if not captures.is_empty() and DisplayServer.get_name() != "headless":
		view.selection_sheet.scroll.scroll_vertical = int(view.selection_sheet.scroll.get_v_scroll_bar().max_value)
		await frames(3); await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(captures.path_join("relic-status-policy.png")) == OK, "actual probability policy capture")
	check(world.inventory == inventory and world.gold == gold, "relic projection never spends unrelated inventory or gold")
	check(FileAccess.get_sha256(world.save_path()) == save_hash, "projection casts and UI never rewrite progression save bytes")
	print("RELIC_SPELL_EFFECT_MAIN_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "renderer":DisplayServer.get_name()}))
	world.queue_free(); await frames(2); quit(0 if failures.is_empty() else 1)
