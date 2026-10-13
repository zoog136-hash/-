extends SceneTree

const POLICY = preload("res://scripts/consumable_auto_policy.gd")
const RULES = preload("res://scripts/consumable_rules.gd")
const CONTROLS = preload("res://scripts/ui/consumable_auto_settings.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("CONSUMABLE_AUTO_FAIL: " + label)

func _tick(world: Variant) -> void:
	world.auto_item_clock = 0.0
	world._run_auto_item_quickslots(0.2)

func _run() -> void:
	var defaults: Dictionary = POLICY.normalize({})
	_check(int(defaults.hp_percent) == 70, "HP safety default")
	_check(not bool(defaults.long_mp_enabled), "Expensive MP auto defaults off")
	_check(POLICY.normalize(null) == defaults, "Missing legacy preferences")
	var invalid: Dictionary = POLICY.normalize({"hp_percent":"bad", "mp_percent":INF, "long_mp_enabled":"true"})
	_check(invalid == defaults, "Malformed values cannot enable expensive auto")
	var bounded: Dictionary = POLICY.normalize({"hp_percent":200, "mp_percent":-20})
	_check(int(bounded.hp_percent) == 95 and int(bounded.mp_percent) == 5, "Bounded percentages")
	_check(POLICY.below_threshold(70, 100, 70), "Inclusive HP boundary")
	_check(not POLICY.below_threshold(71, 100, 70), "Above HP boundary")
	_check(not POLICY.below_threshold(100, 100, 95), "Full resource never consumed")
	_check(not POLICY.below_threshold(0, 0, 20), "Zero maximum")
	_check(not POLICY.below_threshold(-1, 100, 20), "Negative resource rejected")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	_check(scene != null, "Main scene loads")
	if scene == null:
		_finish()
		return
	var world: Variant = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.clear_status_effects()
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	world.active_item_buffs.clear()
	world.item_use_cooldowns.clear()
	world.ui_preferences["consumable_auto"] = defaults.duplicate(true)
	var inv: Dictionary = world.inventory
	inv["HP 물약"] = 10
	world.quickslots = [{"kind":"item", "id":"HP 물약", "auto":true}]
	var max_hp: int = int(world._effective_max_hp())
	world.hp = max_hp - 1
	_tick(world)
	_check(int(inv.get("HP 물약", 0)) == 10, "One missing HP does not consume")
	world.hp = maxi(1, int(max_hp * 0.5))
	var before_hp: int = int(world.hp)
	_tick(world)
	_check(int(inv.get("HP 물약", 0)) == 9, "Low HP consumes exactly one")
	_check(int(world.hp) > before_hp, "Real HP is restored")
	world.ui_preferences.consumable_auto.hp_enabled = false
	_tick(world)
	_check(int(inv.get("HP 물약", 0)) == 9, "HP toggle blocks automatic use")

	var max_mp: int = int(world._effective_max_mp())
	inv["마녀의 마력 회복제"] = 4
	world.quickslots = [{"kind":"item", "id":"마녀의 마력 회복제", "auto":true}]
	world.mp = 0
	_tick(world)
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 4, "Expensive MP needs separate permission")
	world.ui_preferences.consumable_auto.long_mp_enabled = true
	world.mp = max_mp - 1
	_tick(world)
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 4, "One missing MP does not consume")
	world.mp = 0
	_tick(world)
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 3, "Low MP consumes one after permission")
	_check(int(world.mp) == mini(1000, max_mp), "Original MP amount unchanged")
	_check(float(world.item_use_cooldowns.get("마녀의 마력 회복제", 0)) == 1800.0, "Original long cooldown unchanged")
	world.mp = 0
	_tick(world)
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 3, "Cooldown prevents second auto use")
	world.item_use_cooldowns.clear()
	world.mp = max_mp - 1
	world._use_quickslot_item("마녀의 마력 회복제")
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 2, "Manual use remains unchanged")

	var jobs: Array[String] = ["기사", "군주", "요정", "마법사", "다크엘프", "총사", "투사", "암흑기사", "신성검사", "광전사", "사신", "뇌신", "마검사"]
	for job: String in jobs:
		var food: String = "영리한 칠면조 구이" if job == "마법사" else ("날쌘 연어 찜" if job in ["요정", "총사"] else "힘센 한우 스테이크")
		world.job_class = job
		world.active_item_buffs.clear()
		world.item_use_cooldowns.clear()
		inv[food] = 2
		world._use_quickslot_item(food)
		_check(int(inv.get(food, 0)) == 1, job + " can use role food")
		_check(world.active_item_buffs.has(food), job + " receives real cooking buff")
		world.quickslots = [{"kind":"item", "id":food, "auto":true}]
		_tick(world)
		_check(int(inv.get(food, 0)) == 1, job + " active food not automatically consumed twice")

	world.job_class = "기사"
	world.active_item_buffs.clear()
	world.item_use_cooldowns.clear()
	world.ui_preferences["consumable_auto"] = defaults.duplicate(true)
	inv["날쌘 연어 찜"] = 2
	inv["HP 물약"] = 5
	inv["전투 강화의 주문서"] = 2
	world.quickslots = [{"kind":"item", "id":"날쌘 연어 찜", "auto":true}, {"kind":"item", "id":"전투 강화의 주문서", "auto":true}, {"kind":"item", "id":"HP 물약", "auto":true}]
	world.hp = maxi(1, int(world._effective_max_hp() * 0.4))
	_tick(world)
	_check(int(inv.get("HP 물약", 0)) == 4, "Wrong-class first slot cannot starve HP")
	_check(int(inv.get("날쌘 연어 찜", 0)) == 2 and int(inv.get("전투 강화의 주문서", 0)) == 2, "HP precedes maintenance buffs")

	world.ui_preferences["test_unrelated_preference"] = "preserved"
	var custom: Dictionary = defaults.duplicate(true)
	custom.hp_percent = 55
	custom.long_mp_enabled = true
	world.set_consumable_auto_settings(custom)
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.SAVE_PATH))
	_check(int(save.ui_preferences.consumable_auto.hp_percent) == 55, "HP setting saved")
	_check(bool(save.ui_preferences.consumable_auto.long_mp_enabled), "Expensive MP permission saved")
	_check(str(save.ui_preferences.test_unrelated_preference) == "preserved", "Unrelated preferences preserved")
	world.ui_preferences.consumable_auto.hp_percent = 95
	world._load_game(true)
	_check(int(world.get_consumable_auto_settings().hp_percent) == 55, "Setting restored from save")

	var controls: VBoxContainer = CONTROLS.new()
	world.hud.get_node("Root").add_child(controls)
	controls.configure(world.hud)
	var hp_slider: HSlider = controls.find_child("AutoHPPercent", true, false) as HSlider
	var long_toggle: CheckButton = controls.find_child("AutoLongMPEnabled", true, false) as CheckButton
	_check(hp_slider != null and long_toggle != null, "Actual settings controls exist")
	if hp_slider != null:
		hp_slider.value = 45
		_check(int(world.get_consumable_auto_settings().hp_percent) == 45, "UI signal changes gameplay condition")
	if long_toggle != null:
		long_toggle.button_pressed = false
		_check(not bool(world.get_consumable_auto_settings().long_mp_enabled), "UI expensive MP toggle reaches world")
	controls.queue_free()
	await process_frame

	# A valid legacy save lacking only the new key must use defaults, not the
	# previous character's live settings, without losing unrelated data.
	save = JSON.parse_string(FileAccess.get_file_as_string(world.SAVE_PATH))
	save.ui_preferences.erase("consumable_auto")
	var file: FileAccess = FileAccess.open(world.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save))
	file.close()
	world._load_game(true)
	_check(world.get_consumable_auto_settings() == defaults, "Legacy save uses safe defaults")
	_check(str(world.ui_preferences.test_unrelated_preference) == "preserved", "Legacy migration preserves unrelated data")
	world.queue_free()
	await process_frame
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CONSUMABLE_AUTO_SAFETY_OK: %d checks" % checks)
		quit(0)
	else:
		print("CONSUMABLE_AUTO_SAFETY_FAILED: %d/%d" % [failures.size(), checks])
		quit(1)
