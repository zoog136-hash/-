extends SceneTree

# Safe headless regression: use Godot test-runner's isolated save directory.
var failures: Array[String] = []
var checked: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures.append(message)
		print("AIN FAIL: " + message)

func _run() -> void:
	var service_script: GDScript = load("res://scripts/ainhasad_service.gd") as GDScript
	_check(service_script != null, "ain service script")
	if service_script == null:
		_finish()
		return
	var ain: TwilightAinhasadService = service_script.new()
	ain.import_state({})
	_check(ain.blessing == 200 and is_equal_approx(ain.experience_rate(), 4.0), "green default")
	_check(ain.charge(1) == 1 and ain.blessing == 201, "charge stage boundary")
	_check(is_equal_approx(ain.experience_rate(), 7.0) and is_equal_approx(ain.adena_rate(), 2.0), "gold stage")
	_check(ain.consume_for_kill(21000) == 0, "fractional spending first half")
	_check(ain.consume_for_kill(21000) == 1 and ain.blessing == 200, "fractional spending accumulated")
	ain.blessing = 0
	_check(not ain.protected_drops() and is_equal_approx(ain.experience_rate(), 1.0), "zero stage and drops")
	_check(ain.start_dragon_orb(), "orb activation")
	_check(not ain.start_dragon_orb(), "orb cannot stack")
	_check(ain.protected_drops() and is_equal_approx(ain.experience_rate(), 4.0), "orb zero-stage protection")
	_check(ain.charge(201) == 201 and is_equal_approx(ain.experience_rate(), 7.0), "gold overrides orb")
	_check(TwilightAinhasadService.charge_amount("드래곤의 다이아몬드", 35) == 100, "base recharge")
	_check(TwilightAinhasadService.charge_amount("드래곤의 다이아몬드", 85) == 200, "level 85 recharge")
	_check(TwilightAinhasadService.charge_amount("드래곤의 고급 다이아몬드", 89) == 2500, "level 89 recharge")
	var now: int = int(Time.get_unix_time_from_system())
	ain.import_state({"blessing":196, "last_regen_at":now - 240, "dragon_orb_expires_at":0})
	_check(ain.blessing == 198, "offline time recovery")
	_check(ain.advance_time(now + 240) and ain.blessing == 200, "regen caps at 200")
	ain.last_orb_purchase_month = TwilightAinhasadService.month_key()
	_check(not ain.may_purchase_orb(), "monthly orb purchase limit")
	var save: Dictionary = ain.export_state()
	var restored: TwilightAinhasadService = service_script.new()
	restored.import_state(save)
	_check(restored.blessing == ain.blessing and restored.auto_recharge == ain.auto_recharge, "save roundtrip")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	_check(scene != null, "main game scene load")
	if scene != null:
		var world: Node = scene.instantiate()
		root.add_child(world)
		for frame: int in range(8):
			await process_frame
		var hud: Node = world.get_node("HUD")
		var runtime_ain: TwilightAinhasadService = world.get("ain_service") as TwilightAinhasadService
		_check(runtime_ain != null, "runtime blessing service")
		_check(hud.has_signal("ain_item_requested"), "HUD recharge signal")
		var leaf: Label = hud.get("v20_leaf_count") as Label
		var panel: PanelContainer = hud.get("v20_ain_panel") as PanelContainer
		_check(leaf != null and panel != null, "existing upper-left leaf and detail window")
		if runtime_ain != null and leaf != null:
			runtime_ain.blessing = 0
			world.call("_update_ain_hud")
			_check(leaf.text == "0", "real leaf count instead of old green leaf inventory")
			var owned: Dictionary = world.get("inventory") as Dictionary
			owned["드래곤의 루비"] = 2
			world.call("_on_inventory_item_activated", "드래곤의 루비")
			_check(runtime_ain.blessing == 30 and int(owned.get("드래곤의 루비", 0)) == 1, "inventory item applies +30 and consumes exactly one")
			world.call("_on_ain_auto_changed", true)
			_check(runtime_ain.auto_recharge, "auto recharge checkbox persists")
			world.call("_save_game", true)
			var bought: Dictionary = world.get("inventory") as Dictionary
			_check(bought.has("드래곤의 루비"), "game save path intact")
		world.queue_free()
		await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("AINHASAD_SMOKE_OK: %d assertions" % checked)
		quit(0)
	else:
		print("AINHASAD_SMOKE_FAILED: %s" % ", ".join(failures))
		quit(1)
