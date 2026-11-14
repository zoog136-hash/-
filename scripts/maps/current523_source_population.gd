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
const HEAVY_SPAWN_USEC: int = 50000
const HEAVY_REST_FRAMES: int = 2
var _budget_frame: int = -1
var _budget_used: int = 0
var _budget_usec: int = 0
var _rest_until_frame: int = -1

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
	var frame: int = Engine.get_process_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_used = 0
		_budget_usec = 0
	if _budget_used >= SPAWNS_PER_FRAME or _budget_usec >= FRAME_BUDGET_USEC or frame <= _rest_until_frame:
		# A frame-budget deferral is not a failed floor search: no backoff.
		slot.budget_deferred = true
		slot.remaining = maxf(float(slot.get("remaining", 0.0)), 0.05)
		return
	_budget_used += 1
	slot.erase("budget_deferred")
	var started: int = Time.get_ticks_usec()
	super._spawn_slot(slot)
	var spent: int = Time.get_ticks_usec() - started
	_budget_usec += spent
	if spent >= HEAVY_SPAWN_USEC: _rest_until_frame = frame + HEAVY_REST_FRAMES

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
