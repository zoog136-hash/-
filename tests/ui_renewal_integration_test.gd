extends SceneTree

# Headless integration smoke; no destructive enhancement or file loading.
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures.append(message)
		print("UI RENEWAL FAIL: "+message)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false,"Main.tscn cannot load")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	for frame: int in range(8): await process_frame
	var hud: Node = world.get_node("HUD")
	var workspace: PanelContainer = hud.get("workspace") as PanelContainer
	_check(workspace != null,"renewal workspace exists")
	_check(hud.has_signal("shop_buy_requested"),"shop signal preserved")
	_check(hud.has_signal("enhancement_requested"),"enhancement signal preserved")
	_check(hud.has_signal("save_pressed"),"save signal preserved")
	_check(hud.has_signal("load_pressed"),"load signal preserved")
	if workspace == null:
		world.queue_free()
		_finish()
		return
	hud.call("open_shop")
	await process_frame
	_check(workspace.visible,"shop window visible")
	var listing: ItemList = workspace.find_child("ShopItems",true,false) as ItemList
	var buy: Button = workspace.find_child("ShopBuy",true,false) as Button
	_check(listing != null and listing.item_count == 13,"13 original shop products")
	_check(buy != null and not buy.disabled,"potion affordable")
	var old_gold := int(world.get("gold"))
	var inventory: Dictionary = world.get("inventory")
	var old_count := int(inventory.get("HP 물약",0))
	if buy != null and not buy.disabled:
		buy.pressed.emit()
		await process_frame
		_check(int(world.get("gold")) == old_gold-50,"purchase deducts existing world currency")
		var updated: Dictionary = world.get("inventory")
		_check(int(updated.get("HP 물약",0)) == old_count+1,"purchase grants an existing item")
	hud.call("_open_enhance_chooser")
	await process_frame
	var choices: ItemList = workspace.find_child("EnhancementChoices",true,false) as ItemList
	_check(choices != null and choices.item_count > 0,"owned scrolls listed")
	hud.call("open_enhancement","무기 마법 주문서 (각인)",[])
	await process_frame
	var enhance: Button = workspace.find_child("EnhanceAction",true,false) as Button
	_check(enhance != null and enhance.disabled,"no target prevents enhancement")
	hud.call("open_quest_info")
	await process_frame
	var quest: ProgressBar = workspace.find_child("QuestProgress",true,false) as ProgressBar
	_check(quest != null,"quest progress exists")
	if quest != null:
		var state: Dictionary = (hud.get("character_state") as Dictionary).duplicate(true)
		state["quest_goal"] = 9
		state["quest_kills"] = 4
		hud.call("set_character_state",state)
		_check(is_equal_approx(quest.value,4.0),"quest reflects refreshed character state")
	hud.call("open_settings_info")
	await process_frame
	var audio: HSlider = workspace.find_child("MasterVolume",true,false) as HSlider
	var log_toggle: CheckButton = workspace.find_child("CombatLogToggle",true,false) as CheckButton
	_check(audio != null and log_toggle != null,"settings controls exist")
	if log_toggle != null:
		log_toggle.button_pressed = false
		_check(not (hud.get("log_label") as Control).visible,"log visibility updates")
		log_toggle.button_pressed = true
	for section: String in ["open_macro_info","open_chat_info","open_skills","open_character"]:
		hud.call(section)
		await process_frame
		_check(workspace.visible,"window visible "+section)
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("UI_RENEWAL_INTEGRATION_OK %d assertions" % assertions)
		quit(0)
	else:
		print("UI_RENEWAL_INTEGRATION_FAILED %d/%d" % [failures.size(),assertions])
		quit(1)
