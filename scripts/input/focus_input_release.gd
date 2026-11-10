extends RefCounted
## M87 (C12) focus-loss input release applied to the game's held keyboard actions.
## The original GLFW window releases, after the focus callback, every key 0..348 and mouse
## button 0..7 whose CURRENT state byte is exactly 1 (sticky mode stores 3, otherwise 0),
## re-reading the live state for every index. Here the game's held movement/attack keys are
## projected into that window: a key is state 1 while Godot reports its physical key pressed.
## Releasing it releases every game action bound to that key. Godot has no sticky-key mode,
## so sticky stays 0 and released state is 0. Mouse/touch holds stay with their owners
## (VirtualJoystick, WorldInteractions), which run their own focus handling.
const ORIGINAL_INPUT = preload("res://scripts/original_client/oc_m84_m87_world_input.gd")
## Held actions the game reads every frame (Input.get_vector in player.gd) plus attack.
const HELD_ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down", "attack"]
## GLFW key codes for the non-ASCII keys bound in project.godot. Printable ASCII keys
## (space, digits, letters) share the GLFW value with Godot's keycode.
const GLFW_ARROWS := {KEY_RIGHT: 262, KEY_LEFT: 263, KEY_DOWN: 264, KEY_UP: 265}

static func glfw_key(physical_keycode: int) -> int:
	if GLFW_ARROWS.has(physical_keycode):
		return int(GLFW_ARROWS[physical_keycode])
	if physical_keycode >= 32 and physical_keycode <= 96:
		return physical_keycode
	return -1

## {glfw_key: {"physical": Key, "actions": [action...]}} from the live InputMap.
static func bindings(actions: Array[String] = HELD_ACTIONS) -> Dictionary:
	var out: Dictionary = {}
	for action: String in actions:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if not event is InputEventKey:
				continue
			var physical: int = int((event as InputEventKey).physical_keycode)
			var key: int = glfw_key(physical)
			if key < 0:
				continue
			var row: Dictionary = out.get(key, {"physical": physical, "actions": []})
			if not (row.actions as Array).has(action):
				(row.actions as Array).append(action)
			out[key] = row
	return out

## probe(physical_keycode, actions) -> bool : is the key held right now (read live, never
## snapshotted). The game probe also requires one of its actions to be still pressed, so a key
## already released by the engine or by an earlier focus notification reads 0 (no release).
## release(action) : the game's release of one action.
## Returns the window log plus the released keys/actions, in original order.
static func release(focused: int, probe: Callable, release_action: Callable, map: Dictionary = {}) -> Dictionary:
	var bound: Dictionary = bindings() if map.is_empty() else map
	var window: Dictionary = ORIGINAL_INPUT.make_window()
	_refresh(window, bound, probe, -1)
	var released_keys: Array = []
	var released_actions: Array = []
	var key_cb := func(w: Dictionary, key: int, action: int, _mods: int) -> void:
		if action != 0 or not bound.has(key):
			return
		released_keys.append(key)
		for name: String in bound[key].actions:
			release_action.call(name)
			if not released_actions.has(name):
				released_actions.append(name)
		# The original loop loads each later byte live: mirror any change the
		# release caused (or that happened meanwhile) before the next index.
		_refresh(w, bound, probe, key)
	ORIGINAL_INPUT.focus_changed(window, focused, Callable(), key_cb, Callable())
	return {"log": window.log, "released_keys": released_keys, "released_actions": released_actions}

## Live state for every bound key after `after`: 1 while held, otherwise 0.
static func _refresh(window: Dictionary, bound: Dictionary, probe: Callable, after: int) -> void:
	for key: int in bound:
		if key > after and key <= ORIGINAL_INPUT.KEY_LAST:
			(window.key as Array)[key] = 1 if bool(probe.call(int(bound[key].physical), bound[key].actions)) else 0

## Game entry point: Godot's live physical key state and Input.action_release.
static func release_game_input() -> Dictionary:
	return release(0, func(physical: int, actions: Array) -> bool: return game_probe(physical, actions),
		func(action: String) -> void: Input.action_release(action))

static func game_probe(physical: int, actions: Array) -> bool:
	if not Input.is_physical_key_pressed(physical as Key):
		return false
	for action: String in actions:
		if Input.is_action_pressed(action):
			return true
	return false
