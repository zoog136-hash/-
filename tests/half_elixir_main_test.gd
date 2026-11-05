extends SceneTree
## Runs actual Main against isolated user data and a privately supplied ZIP.
const QA = preload("res://tests/qa_class_selection.gd")
const Source = preload("res://scripts/growth/half_elixir_source.gd")
class NativeImageLoader extends ResourceFormatLoader:
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["png", "webp", "jpg", "jpeg", "svg", "ttf", "otf", "wav", "ogg"])
	func _handles_type(type: StringName) -> bool:
		return type in [&"Texture2D", &"ImageTexture", &"Texture", &"Font", &"FontFile", &"AudioStream", &"AudioStreamWAV", &"AudioStreamOggVorbis"]
	func _get_resource_type(path: String) -> String:
		if path.get_extension().to_lower() in ["ttf", "otf"]: return "FontFile"
		if path.get_extension().to_lower() == "wav": return "AudioStreamWAV"
		if path.get_extension().to_lower() == "ogg": return "AudioStreamOggVorbis"
		return "Texture2D" if path.get_extension().to_lower() in _get_recognized_extensions() else ""
	func _exists(path: String) -> bool:
		return FileAccess.file_exists(path)
	func _load(path: String, _original: String, _subthreads: bool, _cache: int) -> Variant:
		if path.get_extension().to_lower() == "wav": return AudioStreamWAV.load_from_file(path)
		if path.get_extension().to_lower() == "ogg": return AudioStreamOggVorbis.load_from_file(path)
		if path.get_extension().to_lower() in ["ttf", "otf"]:
			var font := FontFile.new()
			font.data = FileAccess.get_file_as_bytes(path)
			return font
		var im := Image.load_from_file(path)
		if im == null or im.is_empty(): return ERR_FILE_CORRUPT
		return ImageTexture.create_from_image(im)

var loader: NativeImageLoader
var checks: int = 0
var failures: Array = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("HALF_MAIN_FAIL: ", message)

func _initialize() -> void:
	loader = NativeImageLoader.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	call_deferred("run")

func run() -> void:
	var scene = load("res://Main.tscn")
	if scene == null: check(false, "actual Main scene"); quit(1); return
	var world = scene.instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual initial class confirmation")
	world.set_process(false); world.player.set_physics_process(false); world.save_timer = -100000.0
	var path: String = OS.get_environment("TWILIGHT_HALF_ELIXIR_SOURCE")
	check(not path.is_empty(), "explicit private source")
	var runtime = world.half_elixir
	if OS.get_environment("TWILIGHT_HALF_ELIXIR_RESTART_ONLY") == "1":
		check(runtime.source != null and runtime.state.points == 380 and runtime.state.extension == 50, "new process restores installed source and final progress")
		check(runtime.validate(runtime.state).is_empty(), "new process validates complete saved state")
		print("HALF_ELIXIR_RESTART_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
		world.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1); return
	# Reset only this isolated QA profile in memory before exercising installation.
	runtime.accept(runtime.fresh())
	world.inventory.clear()
	var installed: Dictionary = runtime.install(path)
	check(installed.ok, "actual source installation and atomic save")
	if not installed.ok: printerr(installed.message); world.queue_free(); quit(1); return
	var data = runtime.source
	check(data.audits.rules == 142 and data.audits.extension_coordinates == 1430, "complete source tables")
	var pair: String = ""
	for candidate: String in data.pairs:
		if data.enabled("ElixirExtend", candidate): pair = candidate; break
	check(not pair.is_empty(), "source-enabled expansion context exists")
	check(runtime.execute(runtime.request("context", pair)).ok, "explicit source region and world")
	var charge_id: String = data.charges.keys()[0]
	var charge_name: String = data.charges[charge_id].name
	var before: String = FileAccess.get_sha256(world.save_path())
	check(not runtime.execute(runtime.request("charge", charge_id)).ok, "no free ownership")
	check(FileAccess.get_sha256(world.save_path()) == before, "insufficient ownership does not write")
	# Explicit test fixtures live only in this isolated profile. Production gives nothing.
	world.level = int(data.charges[charge_id].raw.LevelLimitMin)
	world.inventory[charge_name] = 500
	world.gold = 100000000
	world.hud.toggle_menu()
	check(world.hud.menu_page.find_child("MenuTile_half_elixir", true, false) != null, "normal Main menu entry")
	world.hud._navigate("half_elixir")
	var view = world.hud.workspace.find_child("HalfElixirView", true, false)
	check(view != null, "actual production panel")
	if view == null: world.queue_free(); quit(1); return
	var button = view.find_child("HalfCharge_" + charge_id, true, false)
	check(button != null, "owned source item button")
	button.pressed.emit()
	view.find_child("HalfCancel", true, false).pressed.emit()
	check(runtime.state.points == 0 and world.inventory[charge_name] == 500, "actual cancel preserves wallet")
	button.pressed.emit()
	var quoted: Dictionary = view.pending.duplicate(true)
	view.find_child("HalfConfirm", true, false).pressed.emit()
	check(runtime.state.points == 1 and world.inventory[charge_name] == 499, "actual UI confirmation consumes once")
	check(runtime.execute(quoted).get("duplicate", false) and world.inventory[charge_name] == 499, "duplicate nonce is idempotent")
	for amount: int in [100, 100, 100, 79]: check(runtime.execute(runtime.request("charge", charge_id, amount)).ok, "real source batch charge")
	var selected: Dictionary = data.profile(pair)
	var hp_id: String = ""
	for id: String in selected:
		if selected[id].type == "HPPlus": hp_id = id; break
	var base_hp: int = world._effective_max_hp()
	view.refresh()
	view.find_child("HalfInvest_" + hp_id, true, false).pressed.emit()
	view.find_child("HalfConfirm", true, false).pressed.emit()
	check(world._effective_max_hp() == base_hp + int(data.effect(hp_id, 1).value), "actual HP consumer changes")
	var snapshot: String = JSON.stringify(runtime.state, "", true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	world.equipment_collections.test_save_writer = func(_p: String, _d: Dictionary) -> int: return ERR_CANT_CREATE
	check(not runtime.execute(runtime.request("invest", hp_id)).ok, "actual writer failure is reported")
	check(JSON.stringify(runtime.state, "", true) == snapshot and world.inventory == inventory, "writer failure leaves live state and wallet intact")
	world.equipment_collections.test_save_writer = Callable()
	var extension_request: Dictionary = runtime.request("extend")
	runtime.rolls[extension_request.nonce] = 0.0
	var old_gold: int = world.gold
	check(runtime.execute(extension_request).ok and runtime.state.extension == 5, "first source expansion")
	check(world.gold == old_gold - int(data.costs[0].Cost), "exact first-step source fee")
	var failed_request: Dictionary = runtime.request("extend")
	runtime.rolls[failed_request.nonce] = 1.0
	old_gold = world.gold
	check(runtime.execute(failed_request).ok and runtime.state.extension == 5, "configured failed expansion keeps coordinate")
	check(world.gold == old_gold - int(data.costs[5].Cost), "explicit TWILIGHT failure fee policy")
	for id: String in data.rules:
		if data.memberships.get(str(int(data.rules[id].raw.ServerLimitSetID)), {}).is_empty(): check(not runtime.execute(runtime.request("invest", id)).ok, "empty source membership stays blocked")
	var reset_id: String = ""
	for id: String in data.resets:
		if not data.resets[id].get("blocked", false): reset_id = id; break
	check(not reset_id.is_empty(), "source reset item exists")
	world.inventory[data.resets[reset_id].name] = 1
	check(runtime.execute(runtime.request("reset", reset_id)).ok, "source reset uses actual material")
	check(runtime.state.points == 380 and runtime.points_used() == 0 and runtime.state.extension == 5, "reset refunds points, preserves expansion, does not refund potions")
	# Exercise every reachable rule through the real transaction service, not fixtures
	# containing copied source rows. Each profile starts with isolated QA ownership.
	var profiles: Dictionary = {}
	var exercised: Dictionary = {}
	for candidate: String in data.pairs:
		var ids: Array = data.profile(candidate).keys(); ids.sort()
		var signature: String = JSON.stringify(ids)
		if profiles.has(signature): continue
		profiles[signature] = true
		var baseline: Dictionary = runtime.fresh()
		baseline.source_sha256 = data.sha
		runtime.accept(baseline)
		check(runtime.execute(runtime.request("context", candidate)).ok, "profile context transaction")
		world.inventory[charge_name] = 400
		for batch: int in [100, 100, 100, 80]:
			check(runtime.execute(runtime.request("charge", charge_id, batch)).ok, "profile owned charge transaction")
		for id: String in ids:
			var effect_before: Dictionary = data.effect(id, 1)
			var methods: Dictionary = {"HPPlus":"_effective_max_hp", "ArmorClass":"_effective_ac", "MagicResist":"_effective_mr", "MeleeDamage":"_melee_damage_stat", "RangeDamage":"_ranged_damage_stat", "MagicDamage":"_magic_damage_stat", "PVEMeleeAdditionDamage":"_melee_damage_stat", "PVERangeAdditionDamage":"_ranged_damage_stat", "PVEMagicAdditionDamage":"_magic_damage_stat", "MeleeHit":"_melee_accuracy_stat", "RangeHit":"_ranged_accuracy_stat", "MagicHit":"_magic_accuracy_stat", "PVEMeleeHit":"_melee_accuracy_stat", "PVERangeHit":"_ranged_accuracy_stat", "PVEMagicHit":"_magic_accuracy_stat", "PierceMeleeEvasion":"_melee_accuracy_stat", "PierceRangeEvasion":"_ranged_accuracy_stat", "SpellPower":"_spell_power_stat", "DamageReduction":"_damage_reduction_stat"}
			var method: String = methods.get(effect_before.type, "")
			if effect_before.type in ["SpecialResistance", "HitSpecialResistance"] and effect_before.target in ["Stun", "Hold", "Fear"]:
				method = "_" + effect_before.target.to_lower() + ("_resistance_stat" if effect_before.type == "SpecialResistance" else "_accuracy_stat")
			var before_value: int = int(world.call(method)) if not method.is_empty() else 0
			var carry_before: int = world._catalog_stat_sum("weightBonus")
			check(runtime.execute(runtime.request("invest", id)).ok, "reachable source investment " + id)
			exercised[id] = true
			if not method.is_empty():
				var sign_value: int = -1 if effect_before.type == "ArmorClass" else 1
				check(int(world.call(method)) - before_value == int(effect_before.value) * sign_value, "actual Main stat consumer " + id)
			if effect_before.type == "CarryPlus": check(world._catalog_stat_sum("weightBonus") - carry_before == int(effect_before.value), "actual carry consumer")
			var effect: Dictionary = data.effect(id, 1)
			var expected: float = 0.0
			for other: String in runtime.state.allocations:
				var row: Dictionary = data.effect(other, int(runtime.state.allocations[other]))
				if row.type == effect.type and row.target == effect.target: expected += float(row.value)
			check(is_equal_approx(runtime.value(effect.type, effect.target), expected), "typed effect consumption " + id)
		check(runtime.validate(runtime.state).is_empty(), "whole profile persisted state")
	check(exercised.size() == 138 and profiles.size() == 4, "all reachable rules executed across four profiles")
	# All ten source fee transitions use the same staged transaction path.
	var baseline: Dictionary = runtime.fresh()
	baseline.source_sha256 = data.sha
	runtime.accept(baseline)
	check(runtime.execute(runtime.request("context", pair)).ok, "expansion profile")
	world.inventory[charge_name] = 400
	for batch: int in [100, 100, 100, 80]: check(runtime.execute(runtime.request("charge", charge_id, batch)).ok, "expansion minimum ownership")
	world.gold = 100000000
	for currency: Dictionary in data.currencies.values():
		for member: Dictionary in currency.members:
			if int(member.UnitID) == 4 and not bool(member.ForGive): world.inventory[str(member.get("name", ""))] = 1000
	for step: int in range(10):
		var request: Dictionary = runtime.request("extend")
		runtime.rolls[request.nonce] = 0.0
		check(runtime.execute(request).ok and runtime.state.extension == (step + 1) * 5, "source expansion step " + str(step))
	check(not runtime.execute(runtime.request("extend")).ok and runtime.state.extension == 50, "no invented eleventh expansion")
	var stale: Dictionary = runtime.request("charge", charge_id)
	stale.revision -= 1
	check(not runtime.execute(stale).ok, "stale confirmation rejected")
	check(world._save_game(true) == OK, "actual production save")
	var saved: Dictionary = runtime.state.duplicate(true)
	runtime.state = runtime.fresh()
	world._load_game(true)
	var restored_equal: bool = JSON.parse_string(JSON.stringify(runtime.state)) == JSON.parse_string(JSON.stringify(saved))
	if not restored_equal: print("HALF_RELOAD_DIAGNOSTIC ", JSON.stringify({"saved_points":saved.points, "restored_points":runtime.state.points, "saved_revision":saved.revision, "restored_revision":runtime.state.revision, "message":world.hud.message_label.text}))
	check(restored_equal, "actual reconnect restores state and source")
	var original_bytes := FileAccess.get_file_as_bytes(world.save_path())
	var raw: Dictionary = JSON.parse_string(original_bytes.get_string_from_utf8())
	raw.half_elixir523.points = -1
	var file := FileAccess.open(world.save_path(), FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	world._load_game(true)
	check(runtime.save_blocked, "corrupt namespace blocks overwrite")
	check(world._save_game(true) != OK, "corrupt save cannot be silently replaced")
	file = FileAccess.open(world.save_path(), FileAccess.WRITE); file.store_buffer(original_bytes); file.close()
	world._load_game(true)
	check(not runtime.save_blocked, "valid save can recover")
	print("HALF_ELIXIR_MAIN_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "platform":"actual Main, isolated Linux profile; Android untested"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
