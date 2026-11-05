extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("TOTEM_CUSTOM_FAIL: ",label)

func _initialize() -> void:call_deferred("run")

func proc_seed() -> int:
	var probe := RandomNumberGenerator.new()
	for number in range(1,10000):
		probe.seed = number
		if probe.randi_range(0,999999) < 5000:return number
	return -1

func hit_seed(chance: float) -> int:
	var probe := RandomNumberGenerator.new()
	for number in range(1,10000):
		probe.seed = number
		if probe.randf() < chance:return number
	return -1

func select_totem(world: TwilightWorld,id: int) -> void:
	var candidate: Dictionary = world.totems.level_preview(id,10).option_pools["1"][0]
	world.totems.state = {str(id):{"active":true,"kills":3000,"level":10,"selected":{"10":{"1":int(candidate.source.BonusID)}}}}
	world.totem_combat.clear()
	world._invalidate_equipment_static()

func arm_venom(world: TwilightWorld,target: TwilightMonster,duration: float = 2.5) -> bool:
	var potion: Array = []
	for bonus: Dictionary in world.totem_combat.buff_effects(81014):
		if bonus.type.Name == "HPPotionDecreasePercent":potion.append(bonus)
	var applied := target.apply_source_option_debuff("totem:17524",duration,potion) and target.configure_totem_venom("totem:17524",float(world.totem_combat.settings().venom_interval),30000,750,950,world.totem_combat.POLICY.ID)
	if applied:world.totem_combat.targets.append(weakref(target))
	return applied

func capture(world: TwilightWorld,name: String,control: Control) -> void:
	if DisplayServer.get_name() == "headless":return
	await process_frame
	var scroll := world.hud.totem_view.content.get_parent() as ScrollContainer
	scroll.ensure_control_visible(control)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("user://"+name+".png") == OK,"actual custom combat/settings capture "+name)

func run() -> void:
	if OS.get_environment("TWILIGHT_TOTEM_PACK").is_empty():
		print("TOTEM_CUSTOM SKIP: private pack required")
		quit(0)
		return
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main enters game")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.original_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var combat = world.totem_combat
	check(combat.policy.error.is_empty() and combat.settings().venom_interval == 1.0 and combat.settings().shield_capacity == 100,"documented custom defaults load from config")
	select_totem(world,14)
	check(world._save_game(true) == OK,"isolated baseline save")
	var inventory := world.inventory.duplicate(true)
	var gold := world.gold
	var target: TwilightMonster = world.monsters_root.get_child(0)
	target.dead = false
	target.max_hp = 30000
	target.hp = 30000
	world.rng.seed = proc_seed()
	combat.on_hit(target,"melee",false)
	check(combat.fired.has(17524) and target.is_poisoned(),"actual Tikal source proc dispatches custom poison")
	var entry: Dictionary = target.source_option_debuffs.get("totem:17524",{})
	check(entry.has("venom") and entry.venom.damage == 900 and entry.venom.policy == combat.POLICY.ID,"source HP proportion and limits enter labelled host snapshot")
	check(target.hp == 30000 and target.source_option_healing(100,true) == 85,"first tick delayed; source potion penalty separate")
	target.advance_source_option_debuffs(0.99)
	check(target.hp == 30000,"no premature tick")
	target.advance_source_option_debuffs(0.01)
	check(target.hp == 29100,"one full interval consumes actual Monster HP once")
	world.hud.open_totems()
	world.hud.totem_view.selected_id = 14
	world.hud.totem_view._refresh()
	var status: Label = world.hud.totem_view.combat_status
	check(status.text.contains("독 900") and status.text.contains("자체"),"live UI distinguishes source potion penalty and custom poison procedure")
	await capture(world,"totem-custom-venom",status)
	target.clear_poison()
	check(not target.is_poisoned() and target.source_option_healing(100,true) == 85,"host cleanse removes poison component while preserving potion penalty")
	for sample in [[20000,750],[30000,900],[100000,950]]:
		target.max_hp = sample[0]
		target.hp = sample[0]
		check(arm_venom(world,target),"native poison tuple with adjustable host clock")
		var before := target.hp
		target.advance_source_option_debuffs(1.0)
		check(before-target.hp == sample[1],"source lower/proportional/upper damage boundary")
	target.max_hp = 100000
	target.hp = 100000
	arm_venom(world,target)
	target.advance_source_option_debuffs(0.9)
	arm_venom(world,target)
	target.advance_source_option_debuffs(0.9)
	check(target.hp == 100000,"refresh replaces old tick clock instead of stacking")
	target.advance_source_option_debuffs(0.1)
	check(target.hp == 99050,"refreshed poison ticks only once")
	arm_venom(world,target)
	var hp_before := target.hp
	target.advance_source_option_debuffs(10)
	check(hp_before-target.hp == 1900 and not target.is_poisoned(),"long frame catches up within duration only, no extra post-expiry ticks")
	target.status_immunities.append("poison")
	check(not arm_venom(world,target) and target.source_option_healing(100,true) == 85,"existing host poison immunity retained without removing source potion effect")
	target.status_immunities.erase("poison")
	target.hp = 100000
	arm_venom(world,target)
	target.apply_poison(5,7,1)
	target.advance_source_option_debuffs(1)
	target._tick_poison(1)
	check(target.hp == 99043,"ordinary poison and Totem poison keep independent damage clocks")
	target.clear_poison()
	check(not target.is_poisoned() and target.source_option_healing(100,true) == 85,"cleanse clears both poison channels but not the separate source potion penalty")
	target.prune_source_option_debuffs({},"totem:")
	var tikal_progress: Dictionary = world.totems.progress(14)
	select_totem(world,24)
	world.totems.state["14"] = tikal_progress
	world.rng.seed = proc_seed()
	var damage: int = combat.incoming(target,"melee",150)
	check(damage == 45 and combat.barrier_capacity == 0 and combat.barrier_remaining == 5,"source DR then custom finite absorption on triggering hit")
	check(combat.incoming(target,"melee",20) == 20 and combat.barrier_flat() == 5,"exhausted absorption cannot spend twice; DR remains until duration")
	combat.tick(5.01)
	check(combat.barrier_capacity == 0 and combat.barrier_flat() == 0,"expiry clears both host components")
	world.skill_cooldowns.erase("totem|17514")
	world.rng.seed = proc_seed()
	check(combat.incoming(target,"melee",20) == 0 and combat.barrier_capacity == 85,"new proc replenishes one capacity budget")
	world.hud.open_totems()
	world.hud.totem_view.selected_id = 24
	world.hud.totem_view._refresh()
	status = world.hud.totem_view.combat_status
	check(status.text.contains("흡수 잔량 85") and status.text.contains("자체"),"actual screen labels custom absorption capacity")
	await capture(world,"totem-custom-shield",status)
	var interval: SpinBox = world.hud.totem_view.find_child("TotemVenomInterval",true,false)
	var capacity: SpinBox = world.hud.totem_view.find_child("TotemShieldCapacity",true,false)
	var apply: Button = world.hud.totem_view.find_child("TotemLocalSettingsSave",true,false)
	check(interval != null and capacity != null and apply != null,"settings controls reachable from existing Totem screen")
	interval.value = 0.5
	capacity.value = 250
	var prior: Dictionary = combat.settings()
	var save_sha := FileAccess.get_sha256(world.save_path())
	world.source_save_blocked = true
	apply.pressed.emit()
	check(combat.settings() == prior and combat.barrier_capacity == 85 and FileAccess.get_sha256(world.save_path()) == save_sha,"failed settings save preserves policy, active shield and bytes")
	check(world.hud.message_label.text.contains("설정 저장 실패"),"settings failure shown in actual UI")
	world.source_save_blocked = false
	var blocked_temp := world.save_path()+".tmp"
	check(DirAccess.make_dir_recursive_absolute(blocked_temp) == OK,"isolated writer failure fixture blocks temporary path")
	apply.pressed.emit()
	check(combat.settings() == prior and combat.barrier_capacity == 85 and FileAccess.get_sha256(world.save_path()) == save_sha,"actual atomic writer failure preserves old save, settings and live effects")
	check(DirAccess.remove_absolute(blocked_temp) == OK,"temporary-path fixture removed before successful write")
	apply.pressed.emit()
	check(combat.settings().shield_capacity == 250 and combat.settings().venom_interval == 0.5 and combat.barrier_capacity == 85,"successful UI save changes next-proc policy, not active snapshot")
	check(world.inventory == inventory and world.gold == gold,"settings never consume, grant or replace items/gold")
	var current_sha := FileAccess.get_sha256(world.save_path())
	apply.pressed.emit()
	check(FileAccess.get_sha256(world.save_path()) == current_sha and combat.settings().shield_capacity == 250,"stale settings callback cannot overwrite latest preference")
	var invalid: Dictionary = combat.settings()
	invalid.venom_interval = 0
	check(not combat.apply_settings(invalid,combat.settings_token()).ok,"unsafe interval rejected")
	invalid = combat.settings()
	invalid.shield_capacity = 1.5
	check(not combat.apply_settings(invalid,combat.settings_token()).ok,"fractional capacity rejected")
	invalid = combat.settings()
	invalid.version = true
	check(not combat.valid_settings(invalid),"boolean version rejected")
	check(FileAccess.get_sha256(world.save_path()) == current_sha,"invalid requests preserve saved bytes")
	var venom_toggle: CheckButton = world.hud.totem_view.find_child("TotemVenomEnabled",true,false)
	var shield_toggle: CheckButton = world.hud.totem_view.find_child("TotemShieldEnabled",true,false)
	apply = world.hud.totem_view.find_child("TotemLocalSettingsSave",true,false)
	venom_toggle.button_pressed = false
	shield_toggle.button_pressed = false
	apply.pressed.emit()
	combat.clear()
	world.skill_cooldowns.erase("totem|17514")
	world.rng.seed = proc_seed()
	check(combat.incoming(target,"melee",150) == 145 and combat.barrier_capacity == 0,"UI can disable custom absorption while retaining confirmed source DR")
	world.skill_cooldowns.erase("totem|17524")
	world.rng.seed = proc_seed()
	combat.on_hit(target,"melee",false)
	check(not target.is_poisoned() and target.source_option_healing(100,true) == 85,"UI can disable custom poison while retaining source potion decrease")
	venom_toggle = world.hud.totem_view.find_child("TotemVenomEnabled",true,false)
	shield_toggle = world.hud.totem_view.find_child("TotemShieldEnabled",true,false)
	apply = world.hud.totem_view.find_child("TotemLocalSettingsSave",true,false)
	venom_toggle.button_pressed = true
	shield_toggle.button_pressed = true
	apply.pressed.emit()
	check(combat.settings().venom_enabled and combat.settings().shield_enabled,"same settings UI can reenable own procedures")
	world.skill_cooldowns.erase("totem|17514")
	combat.clear()
	world.rng.seed = proc_seed()
	check(combat.incoming(target,"melee",20) == 0 and combat.barrier_capacity == 235,"subsequent proc uses saved custom capacity")
	# Actual successful-hit consumer: use an already placed current-map monster,
	# never a guessed native map entry or source coordinate.
	world.player.global_position = target.global_position
	check(not world.field_map.is_safe(world.player.global_position),"existing current-map encounter is outside safe zone")
	world.rng.seed = hit_seed(world._monster_hit_chance(target,"melee"))
	var player_hp := world.hp
	var capacity_before: int = combat.barrier_capacity
	world._on_player_hit(target,100,"melee")
	check(world.hp == player_hp and combat.barrier_capacity < capacity_before,"actual world incoming hit consumes shield budget before HP")
	var normal_settings: Dictionary = combat.settings()
	var large_settings := normal_settings.duplicate(true)
	large_settings.shield_capacity = 100000
	check(combat.apply_settings(large_settings,combat.settings_token()).ok,"explicit large capacity remains a valid adjustable host estimate")
	combat.clear()
	world.skill_cooldowns.erase("totem|17514")
	world.rng.seed = proc_seed()
	combat.incoming(target,"melee",20)
	check(combat.barrier_capacity == world._effective_max_hp()-15,"absorption is capped at actual maximum HP before consumption")
	check(combat.apply_settings(normal_settings,combat.settings_token()).ok,"restore the saved UI preference before load checks")
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(good.ui_preferences.totem_combat_settings.shield_capacity == 250 and not good.has("totem_combat_settings"),"settings saved in own preferences field without leaking transaction staging key")
	var bad := good.duplicate(true)
	bad.ui_preferences.totem_combat_settings.venom_interval = 0
	check(arm_venom(world,target) and target.is_poisoned(),"live poison snapshot before load validation")
	check(WRITER.write(world.save_path(),bad) == OK,"isolated malformed-settings save fixture")
	var bad_sha := FileAccess.get_sha256(world.save_path())
	var live_capacity: int = combat.barrier_capacity
	world._load_game(true)
	check(combat.settings_blocked and combat.settings().shield_capacity == 250 and combat.barrier_capacity == live_capacity and target.is_poisoned(),"bad settings load preserves current policy, poison and live shield")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == bad_sha,"malformed settings cannot be silently overwritten")
	check(WRITER.write(world.save_path(),good) == OK,"restore isolated good save")
	var restored_sha := FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	check(not combat.settings_blocked and combat.settings().shield_capacity == 250 and combat.settings().venom_interval == 0.5,"saved custom values survive normal load")
	check(combat.barrier_capacity == 0 and combat.barrier_remaining == 0 and not target.is_poisoned() and FileAccess.get_sha256(world.save_path()) == restored_sha,"load clears transient absorption and poison without rewriting bytes")
	world.hud.open_totems()
	interval = world.hud.totem_view.find_child("TotemVenomInterval",true,false)
	capacity = world.hud.totem_view.find_child("TotemShieldCapacity",true,false)
	check(interval.value == 0.5 and capacity.value == 250,"reopened screen reflects saved policy")
	await capture(world,"totem-custom-settings",world.hud.totem_view.find_child("TotemLocalSettingsSave",true,false))
	world.queue_free()
	await process_frame
	print("TOTEM_CUSTOM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_CUSTOM_ESTIMATES_SETTINGS_SAVE_UI; NO_NATIVE_SERVER_OR_MAP_EQUIVALENCE"}))
	quit(0 if failures.is_empty() else 1)
