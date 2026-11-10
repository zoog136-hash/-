extends SceneTree
## Proves which game code now calls the M81 / M87 / M100 adapters, that the replaced inline
## code is gone, and counts every case whose behaviour is identical to or changed from the old
## code over large input grids. The original binary is never executed.
const AUTO = preload("res://scripts/original_client/oc_m81_autoslot.gd")
const INPUT = preload("res://scripts/original_client/oc_m84_m87_world_input.gd")
const RELEASE = preload("res://scripts/input/focus_input_release.gd")
const BINDINGS = preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
const JOYSTICK = preload("res://scripts/virtual_joystick.gd")
var failures: Array[String] = []
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	if not failures.has(message): failures.append(message)

static func body(text: String, signature: String) -> String:
	var start: int = text.find(signature)
	if start < 0:
		return ""
	var stop: int = text.find("\nfunc ", start + signature.length())
	return text.substr(start, (stop if stop >= 0 else text.length()) - start)

func run() -> void:
	wiring()
	m81_order()
	m81_timer()
	await m87_keys()
	m87_joystick()
	m100_amount()
	m100_snapshot()
	report["failures"] = failures
	print("ORIGINAL_CLIENT_WIRING_M81_M87_M100_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

# ------------------------------------------------------------------ (a) wiring
func wiring() -> void:
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	var process: String = body(world, "func _process(delta: float) -> void:")
	if not process.contains("ORIGINAL_AUTOSLOT.timer_step(auto_heal_sweep_elapsed, delta)"): fail("world _process does not use the M81 timer")
	if not process.contains("ORIGINAL_AUTOSLOT.manager_callback(auto_active, true, _auto_quickslot_queued_pass, _auto_quickslot_spell_pass, _auto_quickslot_aux_pass)"): fail("world _process does not use the M81 manager callback")
	if process.contains("\t\t_run_auto_heal_quickslots()\n\t\t_run_auto_hunt()"): fail("old per-frame heal sweep remains")
	if not body(world, "func _auto_quickslot_spell_pass() -> bool:").contains("_run_auto_heal_quickslots()"): fail("spell pass does not run the heal sweep")
	if not body(world, "func _auto_quickslot_order() -> Array[int]:").contains("ORIGINAL_AUTOSLOT.build_local_order(pairs, true, [], Callable())"): fail("order not built by the adapter")
	for signature: String in ["func _run_auto_heal_quickslots() -> void:", "func _run_auto_combat_quickslots() -> bool:"]:
		var sweep: String = body(world, signature)
		if not sweep.contains("for index: int in _auto_quickslot_order():"): fail("sweep not ordered by adapter: " + signature)
		if sweep.contains("for value: Variant in quickslots:"): fail("old direct iteration remains: " + signature)
	var notification: String = body(world, "func _notification(what: int) -> void:")
	if not (notification.contains("NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT") and notification.contains("FOCUS_INPUT_RELEASE.release_game_input()")): fail("world focus loss not wired")
	if not body(world, "func _quickslot_ammo_source(entry: Dictionary) -> Dictionary:").contains("ammo_per_hit"): fail("world ammo source missing")
	var stick: String = FileAccess.get_file_as_string("res://scripts/virtual_joystick.gd")
	if not stick.contains("ORIGINAL_INPUT.focus_changed(window, 0"): fail("joystick does not call the M87 adapter")
	if stick.contains("NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED"): fail("joystick still releases unconditionally on focus loss")
	if not FileAccess.get_file_as_string("res://scripts/input/focus_input_release.gd").contains("ORIGINAL_INPUT.focus_changed(window, focused"): fail("focus helper does not call the M87 adapter")
	var bind: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
	if not (bind.contains("ORIGINAL_COUNT.refresh(model") and bind.contains("amount_presentation(not entry.is_empty(),caption.text,ammo)")): fail("bindings do not call the M100 adapter")
	if bind.contains('"visible":row.filled and not str(row.amount_text).is_empty()'): fail("old amount visibility remains")
	for path: String in ["res://scripts/input/focus_input_release.gd", "res://scripts/virtual_joystick.gd", "res://scripts/ui/original_ui/source_main_quickslot_bindings.gd"]:
		var script: Variant = load(path)
		if not (script is GDScript) or not (script as GDScript).can_instantiate(): fail("does not compile: " + path)

# ------------------------------------------------------------------ (b) M81
## World builds pair (index/5, index%5) for each absolute index; old code walked indices 0..n-1.
func m81_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var compared: int = 0
	var identical: int = 0
	for size: int in range(0, 51):
		var pairs: Array = []
		for index: int in range(size):
			pairs.append({"page": index / 5, "button": index % 5})
		for trial: int in range(40):
			var registered: Array = pairs.duplicate(true)
			if trial > 0:
				for i: int in range(registered.size() - 1, 0, -1):
					var j: int = rng.randi_range(0, i)
					var t: Variant = registered[i]; registered[i] = registered[j]; registered[j] = t
			var order: Array = AUTO.build_local_order(registered, true, [], Callable()).order
			var keys: Array = order.map(func(p: Dictionary) -> int: return AUTO.priority_key(p))
			compared += 1
			if keys == range(size): identical += 1
			else: fail("order differs size=%d trial=%d" % [size, trial])
	# Sweep visit order over random AUTO masks of the 50 real slots: same eligible sequence.
	var full: Array = []
	for index: int in range(50): full.append({"page": index / 5, "button": index % 5})
	var order50: Array = AUTO.build_local_order(full, true, [], Callable()).order.map(func(p: Dictionary) -> int: return AUTO.priority_key(p))
	var masks: int = 0
	var masks_identical: int = 0
	for trial: int in range(20000):
		var mask: int = rng.randi() | (rng.randi() << 32)
		var old_seq: Array = []
		var new_seq: Array = []
		for index: int in range(50):
			if (mask >> index) & 1: old_seq.append(index)
		for index: int in order50:
			if (mask >> index) & 1: new_seq.append(index)
		masks += 1
		if old_seq == new_seq: masks_identical += 1
	if masks_identical != masks: fail("sweep sequence differs for some AUTO mask")
	report["m81_order"] = {"orders_compared": compared, "orders_identical": identical, "auto_masks_compared": masks, "auto_masks_identical": masks_identical, "changed": (compared - identical) + (masks - masks_identical)}

## Old: heal sweep every frame while auto is active. New: only on a 0.5 s strict-> fire.
func m81_timer() -> void:
	var deltas: Array = [1.0 / 30.0, 1.0 / 60.0, 1.0 / 90.0, 1.0 / 120.0, 1.0 / 144.0, 0.1, 0.25, 0.5, 0.75, 1.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	var frames: int = 0
	var old_runs: int = 0
	var new_runs: int = 0
	var identical: int = 0
	var per_delta: Dictionary = {}
	for series: int in range(deltas.size() + 1):
		var elapsed: float = 0.0
		var clock: float = 0.0
		var last_fire: float = 0.0
		var max_gap: float = 0.0
		var fires: int = 0
		for frame: int in range(1200):
			var dt: float = float(deltas[series]) if series < deltas.size() else rng.randf_range(0.004, 0.06)
			clock += dt
			var step: Dictionary = AUTO.timer_step(elapsed, dt)
			elapsed = step.elapsed
			frames += 1
			old_runs += 1
			if step.fired:
				new_runs += 1
				fires += 1
				identical += 1
				max_gap = maxf(max_gap, clock - last_fire)
				last_fire = clock
			# dt <= interval stays bounded; a longer frame fires every frame and the single
			# subtraction lets elapsed grow by dt-0.5 (original: no catch-up loop, no clamp).
			if elapsed < 0.0 or (dt <= 0.5 and elapsed > 0.5 + 1e-6) or (dt > 0.5 and not step.fired): fail("elapsed out of range series=%d" % series)
		var label: String = ("%.4f" % float(deltas[series])) if series < deltas.size() else "jitter"
		per_delta[label] = {"frames": 1200, "old_sweeps": 1200, "new_sweeps": fires, "max_gap_s": snappedf(max_gap, 0.0001)}
		if series < deltas.size() and max_gap > 0.5 + float(deltas[series]) + 1e-4: fail("gap above 0.5 s + one frame for dt=" + label)
	# Strict > and single subtraction exactly as the original.
	var e: Dictionary = AUTO.timer_step(0.25, 0.25)
	if e.fired: fail("0.5 == interval must not fire")
	var hitch: Dictionary = AUTO.timer_step(0.0, 3.0)
	var drained: int = 1 if hitch.fired else 0
	var h: float = hitch.elapsed
	while true:
		var s: Dictionary = AUTO.timer_step(h, 1.0 / 60.0)
		h = s.elapsed
		if not s.fired: break
		drained += 1
	if not (hitch.fired and is_equal_approx(hitch.elapsed, 2.5)): fail("hitch must subtract once")
	# Manager order: disabled auto runs the queued pass only; enabled runs both passes, ORed.
	manager_calls.clear()
	var off: Dictionary = AUTO.manager_callback(false, true, _queued, _spell, _aux)
	if manager_calls != ["q"] or off.result: fail("disabled manager must stop after queued pass")
	manager_calls.clear()
	var on: Dictionary = AUTO.manager_callback(true, true, _queued, _spell, _aux)
	if manager_calls != ["q", "s", "a"] or on.result: fail("enabled manager must run queued, spell, aux")
	report["m81_heal_cadence"] = {"frames": frames, "old_heal_sweeps": old_runs, "new_heal_sweeps": new_runs, "frames_identical": identical, "frames_changed_sweep_skipped": frames - identical, "per_delta": per_delta, "hitch_3s_consecutive_fires_at_60fps": drained}

var manager_calls: Array = []
func _queued() -> void: manager_calls.append("q")
func _spell() -> bool:
	manager_calls.append("s")
	return false
func _aux() -> bool:
	manager_calls.append("a")
	return false

# ------------------------------------------------------------------ (c) M87
func m87_keys() -> void:
	var bound: Dictionary = RELEASE.bindings()
	if bound.size() != 9: fail("expected 9 held-key bindings from project input map, got %d" % bound.size())
	var keys: Array = bound.keys()
	keys.sort()
	var compared: int = 0
	var identical: int = 0
	var changed: int = 0
	for focused: int in [1, 0, -1]:
		for mask: int in range(1 << keys.size()):
			var held: Dictionary = {}
			var pressed_actions: Dictionary = {}
			for i: int in keys.size():
				if (mask >> i) & 1:
					held[int(bound[keys[i]].physical)] = true
					for a: String in bound[keys[i]].actions: pressed_actions[a] = true
			var probe := func(physical: int, actions: Array) -> bool:
				if not held.has(physical): return false
				for a: String in actions:
					if pressed_actions.has(a): return true
				return false
			var released: Array = []
			var release_action := func(action: String) -> void:
				released.append(action)
				pressed_actions.erase(action)
			var result: Dictionary = RELEASE.release(focused, probe, release_action, bound)
			compared += 1
			# Old game code: no focus handling in world, actions stayed pressed.
			if released.is_empty(): identical += 1
			else: changed += 1
			if focused != 0 and not released.is_empty(): fail("released while focused=%d" % focused)
			if focused == 0 and not pressed_actions.is_empty(): fail("action left pressed mask=%d" % mask)
			var sorted_released: Array = result.released_keys.duplicate()
			sorted_released.sort()
			if result.released_keys != sorted_released: fail("keys not released in ascending index order")
	# Real Godot input: a held key is released once; a second notification releases nothing.
	var press := InputEventKey.new()
	press.physical_keycode = KEY_A
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	var before: bool = Input.is_action_pressed("move_left")
	var first: Dictionary = RELEASE.release_game_input()
	var after: bool = Input.is_action_pressed("move_left")
	var second: Dictionary = RELEASE.release_game_input()
	if not before or after or first.released_actions != ["move_left"] or not second.released_actions.is_empty(): fail("live Input release failed before=%s after=%s first=%s second=%s" % [before, after, first.released_actions, second.released_actions])
	var up := InputEventKey.new()
	up.physical_keycode = KEY_A
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	var idle: Dictionary = RELEASE.release_game_input()
	if not idle.released_actions.is_empty(): fail("idle focus loss released something")
	report["m87_keys"] = {"cases": compared, "identical_to_old_no_release": identical, "changed_released_held_keys": changed, "live_input_first_release": first.released_actions, "live_input_second_release": second.released_actions}

func m87_joystick() -> void:
	var compared: int = 0
	var same_state: int = 0
	var emission_removed: int = 0
	var released: int = 0
	for touch: int in [-1, 0, 3]:
		for mouse: bool in [false, true]:
			for v: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2(0.7071, -0.7071)]:
				for what: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
					var results: Array = []
					for mode: int in [0, 1]:
						var stick: Control = JOYSTICK.new()
						root.add_child(stick)
						stick.active_touch = touch
						stick.mouse_active = mouse
						stick.value = v
						var emitted: Array = [0]
						stick.vector_changed.connect(func(_x: Vector2) -> void: emitted[0] += 1)
						if mode == 0: stick.call("_release_pointer")  # old: every listed notification released
						else: stick.notification(what)
						results.append([stick.active_touch, stick.mouse_active, stick.value, emitted[0]])
						stick.free()
					compared += 1
					if results[0].slice(0, 3) == results[1].slice(0, 3): same_state += 1
					else: fail("joystick state differs touch=%d mouse=%s v=%s what=%d" % [touch, mouse, v, what])
					if results[0][3] != results[1][3]: emission_removed += 1
					if results[1][3] == 1: released += 1
	report["m87_joystick"] = {"cases": compared, "final_state_identical": same_state, "redundant_zero_emission_removed_idle_focus_loss": emission_removed, "released_with_signal": released}

# ------------------------------------------------------------------ (d) M100
func m100_amount() -> void:
	var counts: Array = [-2147483648, -1000, -2, -1, 0, 1, 2, 3, 9, 10, 99, 100, 999, 1000, 9999, 2147483647]
	for i: int in range(0, 2001): counts.append(i)
	var compared: int = 0
	var identical: int = 0
	var changed_text: int = 0
	var changed_visible: int = 0
	for filled: bool in [false, true]:
		for existing: String in ["", "0", "3", "120", "이미지 없음"]:
			var sources: Array = [{}]
			for c: int in counts:
				sources.append({"ammo_count": c, "can_use_without_ammo": false})
				sources.append({"ammo_count": c, "can_use_without_ammo": true})
			for ammo: Dictionary in sources:
				var old_text: String = existing
				var old_visible: bool = filled and not existing.is_empty()
				var now: Dictionary = BINDINGS.amount_presentation(filled, existing, ammo)
				compared += 1
				if now.text == old_text and now.visible == old_visible:
					identical += 1
				else:
					if now.text != old_text: changed_text += 1
					if now.visible != old_visible: changed_visible += 1
				if ammo.is_empty() or not filled:
					if now.basis != "existing_caption" or now.text != old_text or now.visible != old_visible: fail("non-ammo row changed")
				else:
					if now.text != str(int(ammo.ammo_count)): fail("ammo text wrong %s" % ammo)
					var want_visible: bool = not bool(ammo.can_use_without_ammo)
					if now.visible != want_visible: fail("ammo visibility wrong %s" % ammo)
	report["m100_amount"] = {"cases": compared, "identical": identical, "changed": compared - identical, "changed_text": changed_text, "changed_visibility": changed_visible}

## The real snapshot over a stand-in HUD/world (no private pack): only the ammo skill row changes.
func m100_snapshot() -> void:
	var world_script := GDScript.new()
	world_script.source_code = "extends Node\nvar ammo: int = 7\nfunc _quickslot_pages() -> Array: return [0, 0]\nfunc _quickslot_ammo_source(entry: Dictionary) -> Dictionary:\n\treturn {\"ammo_count\": ammo, \"can_use_without_ammo\": false} if entry.get(\"id\", \"\") == \"트리플 애로우\" else {}\n"
	world_script.reload()
	var hud_script := GDScript.new()
	hud_script.source_code = "extends Node\nvar quickslot_entries: Array = []\nvar quickslot_captions: Array = []\nvar quickslot_cooldown_labels: Array = []\nfunc quickslot_index(v: int) -> int: return v\nfunc _emit_quickslot(_v: int) -> void: pass\n"
	hud_script.reload()
	var world: Node = world_script.new()
	var hud: Node = hud_script.new()
	world.add_child(hud)
	root.add_child(world)
	var entries: Array = [{"kind": "item", "id": "체력 회복제"}, {"kind": "skill", "id": "트리플 애로우"}, {"kind": "skill", "id": "힐"}, {}]
	var hud_entries: Array = hud.get("quickslot_entries")
	var hud_captions: Array = hud.get("quickslot_captions")
	var hud_cooldowns: Array = hud.get("quickslot_cooldown_labels")
	for i: int in range(10):
		hud_entries.append(entries[i] if i < entries.size() else {})
		var caption := Label.new()
		caption.text = "15" if i == 0 else ""
		hud_captions.append(caption)
		hud_cooldowns.append(Label.new())
	var b: RefCounted = BINDINGS.new()
	b.set("_hud", weakref(hud))
	var snap: Dictionary = b.snapshot()
	if not snap.get("ok", false): fail("snapshot failed %s" % snap)
	else:
		var rows: Array = snap.rows
		if rows[0].amount_text != "15" or not rows[0].amount_visible or rows[0].amount_basis != "existing_caption": fail("item row changed")
		if rows[1].amount_text != "7" or not rows[1].amount_visible or rows[1].amount_basis != "original_ammo_count": fail("ammo skill row not from adapter")
		if rows[2].amount_text != "" or rows[2].amount_visible: fail("plain skill row changed")
		if rows[3].amount_visible: fail("empty row visible")
		world.set("ammo", 0)
		var zero: Dictionary = b.snapshot()
		if zero.rows[1].amount_text != "0" or not zero.rows[1].amount_visible: fail("zero ammo must stay visible (flag34)")
		report["m100_snapshot"] = {"rows": rows.size(), "ammo_row": [rows[1].amount_text, rows[1].amount_visible], "zero_ammo_row": [zero.rows[1].amount_text, zero.rows[1].amount_visible]}
	for label: Label in hud_captions: label.free()
	for label: Label in hud_cooldowns: label.free()
	world.free()
