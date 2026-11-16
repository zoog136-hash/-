extends "res://scripts/maps/source_population.gd"
class_name Current523SourcePopulation
## Population for a current523 source field. Regions activate within the
## inherited 40-cell window around the player and far actors return to the
## pool. New actors are spread over frames so entering a dense area on a phone
## does not resolve dozens of source records in one frame.
const SPAWNS_PER_FRAME: int = 2
## Spawn work per frame. A spawn whose setup is a first-time (cold) original
## bank load can take hundreds of ms on a phone; once this frame has spent the
## budget no further spawn starts in it, and after a heavy spawn the next
## HEAVY_REST_FRAMES frames start none, so two cold setups never stack into one
## long frame. Deferred slots retry shortly (no failure backoff): monsters can
## appear later, never fewer.
const FRAME_BUDGET_USEC: int = 8000
## A first-time monster kind builds its original SP2 bank one role (idle,
## walk, attack, ...) per spawn attempt instead of all roles in one frame.
const ROLE_BUILDS_PER_SPAWN: int = 1
## ... and verifies (parses) at most this many new original members of it.
const MEMBER_VERIFIES_PER_SPAWN: int = 2
const SP2_BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const SP2_LOADER = preload("res://scripts/resources/sp2_background_loader.gd")
const EFFECT_SELECTION = preload("res://scripts/resources/current523_source_effect_selection.gd")
## Spawn setups prepare cold original banks on worker threads (see
## reference_sp2_bank.background_loading). false = the synchronous path.
static var background_loading: bool = true
const HEAVY_SPAWN_USEC: int = 50000
const HEAVY_REST_FRAMES: int = 2
var _budget_frame: int = -1
var _budget_used: int = 0
var _budget_usec: int = 0
var _rest_until_frame: int = -1
## Slots deferred by the budget (or a bank build continued over attempts)
## retry on following frames, not only on the next 0.4 s population wake.
var _retry: Array[Dictionary] = []
const RETRY_PER_FRAME: int = 4

## Only records resolved from the current523 original may live on a source
## field. A record still resolved through the old base508 actor pack
## (non-empty source_m_asset_manifest_path, no current523 final mark) is held:
## the old pack is never a requirement or a fallback here.
static func current_record(record: Dictionary) -> bool:
	return record.get("source_m_current523_final") == true and str(record.get("source_m_asset_manifest_path", "")).is_empty()

func _spawn_slot(slot: Dictionary) -> void:
	var occupant: Variant = slot.get("monster")
	if is_instance_valid(occupant) and not occupant.dead: return
	var names: Array = slot.region.get("monster_types", [])
	if names.is_empty() or not current_record(records.get(str(names[0]), {})):
		slot.patch523_spawn_hold = "old_pack_record_refused"
		slot.remaining = INF
		return
	if slot.has("background_wait") and SP2_LOADER.pending(slot.background_wait):
		# Its original inputs are still being prepared off the main thread: no
		# setup attempt (and no failure backoff) until they are ready.
		slot.budget_deferred = true
		slot.remaining = maxf(float(slot.get("remaining", 0.0)), 0.05)
		FRAME_HITCH.count("spawn.background_pending")
		_queue_retry(slot)
		return
	var frame: int = Engine.get_process_frames()
	if not _budget_open(frame):
		# A frame-budget deferral is not a failed floor search: no backoff.
		slot.budget_deferred = true
		slot.remaining = maxf(float(slot.get("remaining", 0.0)), 0.05)
		_queue_retry(slot)
		return
	_budget_used += 1
	slot.erase("budget_deferred")
	var started: int = Time.get_ticks_usec()
	# One cold bank role per attempt (see reference_sp2_bank.role_build_budget).
	SP2_BANK.role_build_budget = ROLE_BUILDS_PER_SPAWN
	SP2_BANK.member_verify_budget = MEMBER_VERIFIES_PER_SPAWN
	# Cold original inputs are read/hashed/parsed on worker threads; the slot
	# waits for them instead of doing that work in this frame.
	SP2_BANK.background_loading = background_loading and SP2_LOADER.enabled
	SP2_BANK.background_wait.clear()
	super._spawn_slot(slot)
	SP2_BANK.background_loading = false
	SP2_BANK.role_build_budget = -1
	SP2_BANK.member_verify_budget = -1
	slot.erase("background_wait")
	if slot.get("patch523_spawn_hold") == "current523_view_deferred":
		# Not a hold: the next attempt continues the same bank build.
		slot.erase("patch523_spawn_hold")
		slot.budget_deferred = true
		slot.remaining = maxf(float(slot.get("remaining", 0.0)), 0.05)
		FRAME_HITCH.count("spawn.view_deferred")
		if not SP2_BANK.background_wait.is_empty():
			slot.background_wait = SP2_BANK.background_wait.duplicate()
			FRAME_HITCH.count("spawn.background_wait")
		_queue_retry(slot)
	var spent: int = Time.get_ticks_usec() - started
	_budget_usec += spent
	if spent >= HEAVY_SPAWN_USEC: _rest_until_frame = frame + HEAVY_REST_FRAMES

func _budget_open(frame: int) -> bool:
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_used = 0
		_budget_usec = 0
	return _budget_used < SPAWNS_PER_FRAME and _budget_usec < FRAME_BUDGET_USEC and frame > _rest_until_frame

func _queue_retry(slot: Dictionary) -> void:
	if slot.get("retry_queued") == true: return
	slot.retry_queued = true
	_retry.append(slot)

func configure(controller: Node, value: PlayableField) -> void:
	for slot: Dictionary in _retry: slot.erase("retry_queued")
	_retry.clear()
	super.configure(controller, value)
	# The first effect of the session would otherwise read/hash/parse the whole
	# bank manifest inside a hit (current523_source_effect_selection.prewarm).
	if value != null and background_loading: EFFECT_SELECTION.prewarm()

func _process(delta: float) -> void:
	super._process(delta)
	if _retry.is_empty(): return
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_drain_retry()
	FRAME_HITCH.add_self("field_population", hitch_started, hitch_nested)

func _drain_retry() -> void:
	if field == null:
		_retry.clear()
		return
	var tried: int = 0
	# Slots waiting for background preparation are passed over (no token, no
	# setup) until their tasks finished; each is looked at once per frame.
	var waiting: Array[Dictionary] = []
	SP2_LOADER.poll()
	while not _retry.is_empty() and tried < RETRY_PER_FRAME and _budget_open(Engine.get_process_frames()):
		var slot: Dictionary = _retry.pop_front()
		if slot.has("background_wait") and SP2_LOADER.pending(slot.background_wait):
			waiting.append(slot)
			continue
		slot.erase("background_wait")
		slot.erase("retry_queued")
		var occupant: Variant = slot.get("monster")
		if (is_instance_valid(occupant) and not occupant.dead) or slot.has("patch523_spawn_hold") or not _zone_active(slot.region): continue
		# Retries (budget deferrals and the one-role-per-attempt original bank
		# build) are spawn attempts too, so they share the steady respawn pace
		# after the first fill: on the phone they bypassed it and ran ~5 setups
		# a second at ~85 ms each (2026-11-16 523.530: field_population
		# 437 ms of CPU per second). Bosses are never paced.
		if str(slot.region.get("mode","normal"))!="boss" and not _take_spawn_token():
			slot.retry_queued = true
			_retry.push_front(slot)
			break
		tried += 1
		_spawn_slot(slot)
		if is_instance_valid(slot.get("monster")):
			slot.erase("budget_deferred")
			slot.spawn_failures = 0
	# Waiting slots keep their place at the front of the queue.
	if not waiting.is_empty():
		waiting.append_array(_retry)
		_retry = waiting

func _spawn_retry_delay(slot: Dictionary) -> float:
	if slot.has("budget_deferred"):
		slot.erase("budget_deferred")
		return 0.2
	return super._spawn_retry_delay(slot)

## Summary of what the current field asked for and what the roster accepted.
func source_metrics() -> Dictionary:
	var result: Dictionary = {"regions": 0, "registered": 0, "slots": slots.size(), "alive": 0, "held": {}}
	if field == null: return result
	for region: Dictionary in field.data.get("monster_spawn", []):
		result.regions += 1
		if current_record(records.get(str(region.get("source_m_key", "")), {})): result.registered += 1
	for slot: Dictionary in slots:
		if is_instance_valid(slot.monster) and not slot.monster.dead: result.alive += 1
		if slot.has("patch523_spawn_hold"):
			var reason: String = str(slot.patch523_spawn_hold)
			result.held[reason] = int(result.held.get(reason, 0)) + 1
	return result
