extends SceneTree
## Run with a disposable profile. TWILIGHT_SOURCE_UI and its pin opt in to
## the real source bindings and verify how many text bindings are touched.
const QA = preload("res://tests/qa_class_selection.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const VITALS = preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
const STATS = preload("res://scripts/ui/original_ui/source_main_primary_stats.gd")
const WALLET = preload("res://scripts/ui/original_ui/source_main_wallet_bindings.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node
var hud: Node
var source: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for _frame: int in 4: await process_frame
	_check(QA.enter_game(world), "the normal class confirmation enters the game")
	world.set_process(false)
	world.set_physics_process(false)
	hud = world.hud
	source = hud.original_main_ui_controller
	if OS.has_environment("TWILIGHT_SOURCE_UI"):
		_check(is_instance_valid(source), "pinned original HUD admitted through the normal launch")
	world.hp = 10
	world.mp = 9
	world.gold = 50123
	world._refresh_combat_hud()
	HITCH.enabled = true
	var real: bool = is_instance_valid(source)
	if real:
		_check(is_instance_valid(source._char_scene) and is_instance_valid(source._exp_scene), "original vitals and EXP mounted")
		_check(is_instance_valid(source._wallet_scene) and is_instance_valid(source._primary_stats_scene), "original wallet and primary stats mounted")
		if not failures.is_empty():
			await _finish({})
			return
	var unaffected_mp: String = hud.v20_mp_text.text
	var unaffected_gold: String = hud.lineage_inventory_ui.gold_label.text
	HITCH._details.clear()
	world.hp += 1
	world._refresh_combat_hud()
	var hp_calls: int = _text_calls()
	_check(hud.v20_hp_text.text.begins_with("11 / ") and hud.hp_bar.value == 11, "HP reaches the fallback bar and text")
	_check(hud.v20_mp_text.text == unaffected_mp and hud.lineage_inventory_ui.gold_label.text == unaffected_gold, "HP keeps MP and wallet values")
	if real:
		_check(hp_calls == 1 and _text(source._char_scene, 37172).begins_with("11 / "), "HP touches just its original text (calls %d)" % hp_calls)
		_check(_text(source._char_scene, 35528).begins_with("9 / "), "original MP stays at its previous reading")
	HITCH._details.clear()
	world.mp += 1
	world._refresh_combat_hud()
	_check(hud.v20_mp_text.text.begins_with("10 / ") and hud.lineage_side_ui.mp_label.text.begins_with("MP 10 / "), "MP reaches the fallback HUD and side sheet")
	if real: _check(_text_calls() == 1 and _text(source._char_scene, 35528).begins_with("10 / "), "MP touches just its original text")
	HITCH._details.clear()
	world.level += 1
	world._refresh_combat_hud()
	_check(hud.v20_level_badge.text == str(world.level), "the fallback level badge changes")
	if real:
		var level_layer: Dictionary = source._char_scene.project_player([VITALS.CLASS_PROJECT])
		_check(level_layer.get("ok", false) and _text(level_layer.player, VITALS.CLASS_LEVEL) == str(world.level) and _text_calls() == 1, "level reaches only the mounted original badge")
	HITCH._details.clear()
	world.experience = 1
	world._refresh_combat_hud()
	_check(hud.exp_bar.value == 1, "EXP reaches the fallback bar")
	if real: _check(_text_calls() == 1, "EXP touches only its original binding")
	HITCH._details.clear()
	world.gold += 100
	world._refresh_combat_hud()
	_check(hud.character_state.gold == world.gold and hud.lineage_inventory_ui.gold_label.text.contains("50,223"), "adena pickup updates the bag wallet and HUD state")
	if real: _check(_text_calls() == 1 and _text(source._wallet_scene, WALLET.GOLD_TEXT) == str(world.gold), "adena touches only its original wallet binding")
	HITCH._details.clear()
	world.inventory["다이아"] = 123
	hud.update_currency_balances(world.inventory)
	_check(hud.currency_readout.text.contains("다이아 123"), "diamonds reach the fallback wallet")
	if real: _check(_text_calls() == 1 and _text(source._wallet_scene, WALLET.JEWEL_TEXT) == "123", "diamonds touch only their original wallet binding")
	HITCH._details.clear()
	world.inventory["명예 코인"] = 456
	hud.update_currency_balances(world.inventory)
	_check(hud.currency_readout.tooltip_text.contains("명예 코인  456"), "non-wallet coins still update the tooltip")
	if real: _check(_text_calls() == 0, "other coins do not touch either original wallet binding")
	HITCH._details.clear()
	world._refresh_combat_hud()
	_check(_text_calls() == 0, "an unchanged combat publish writes no original text")
	if real: _primary_stats()
	var distribution: Array = []
	for _batch: int in 3: distribution.append(_measure())
	if real:
		var previous: Node = source
		var rebound: Dictionary = hud.bind_original_main_ui(source.map_loading_art_pack())
		source = hud.original_main_ui_controller
		_check(rebound.get("ok", false) and source != previous, "replacement HUD replays the latest values")
		_check(_text(source._char_scene, 37172).begins_with(str(world.hp) + " / ") and _text(source._wallet_scene, WALLET.JEWEL_TEXT) == "123", "replacement HUD shows HP and currencies without a full world publish")
	await _finish({"real_source":real,"hp_text_calls":hp_calls,"batches":distribution})

func _primary_stats() -> void:
	var old_ac: String = _text(source._primary_stats_scene, STATS.AC_TEXT)
	var old_damage: int = hud.character_state.melee_damage
	HITCH._details.clear()
	hud.character_state["melee_damage"] = old_damage + 2
	_check(source.refresh_primary_stats().get("ok", false), "a changed attack stat is applied")
	_check(_text_calls() == 1 and _text(source._primary_stats_scene, STATS.AC_TEXT) == old_ac and _text(source._primary_stats_scene, STATS.MD_TEXT) == str(old_damage + 2), "attack changes just its original binding")
	hud.character_state["melee_damage"] = "bad state"
	_check(not source.refresh_primary_stats().get("ok", false) and not source._primary_stats_scene.visible and hud.v20_stat_text.visible, "invalid stats restore the fallback display")
	hud.character_state["melee_damage"] = old_damage
	_check(source.refresh_primary_stats().get("ok", false) and source._primary_stats_scene.visible and not hud.v20_stat_text.visible, "valid stats restore the original display")

func _measure() -> Dictionary:
	var samples: Array[int] = []
	HITCH._details.clear()
	for tick: int in 180:
		world.hp = 20 + (tick % 7)
		var started: int = Time.get_ticks_usec()
		world._refresh_combat_hud()
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	return {"p50_usec":samples[90],"p95_usec":samples[171],"max_usec":samples[-1],"text_calls":_text_calls()}

func _text_calls() -> int:
	return int(HITCH._details.get("ui.text_same", [0,0])[1]) + int(HITCH._details.get("ui.text_update", [0,0])[1]) + int(HITCH._details.get("ui.bitmap_update", [0,0])[1])

func _text(scene: Node, offset: int) -> String:
	if not is_instance_valid(scene):return ""
	var node: Node = scene.source_nodes.get(offset)
	if not is_instance_valid(node):return ""
	if node.has_meta("source_text"):return str(node.get_meta("source_text").original_options.text)
	if node.has_meta("source_bitmap_text"):return str(node.get_meta("source_bitmap_text")._options.text)
	return ""

func _finish(samples: Dictionary) -> void:
	print("SCOPED_PLAYER_HUD_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
