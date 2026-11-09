extends RefCounted
## C10 / P2. DESIGN_NOT_RECOVERED_API. Request-key cache and file-key cache are different
## things: a request (the id the caller asked for) is cached separately from the file it
## was remapped to. A cached null is not retried just because a remap was added later.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const SELECT = preload("res://scripts/original_client/sprite_selection.gd")
const REQUEST_LIMIT := 450 # approved figure; not a global memory hard limit and eviction is not modelled
const SELECTED_BYTE_LIMIT := 64 * 1024 * 1024

var request_cache: Dictionary = {}
var file_cache: Dictionary = {}
var remap: Dictionary = {}
var generation: int = 0
var mode: int = 1
var manager_retained: bool = true
var loads: int = 0

static func make_entry(request_key: int, file_key: int, value_state: String, owner_generation: int, failure_state: String) -> Dictionary:
	return {"record": "CacheEntry", "design_status": VOCAB.EVIDENCE_DESIGN, "request_key": request_key, "file_key": file_key,
		"value_state": value_state, "owner_generation": owner_generation, "failure_state": failure_state}

## loader(file_key) -> value or null.
func request(request_key: int, loader: Callable) -> Dictionary:
	if request_cache.has(request_key):
		return request_cache[request_key]
	var mapped: Dictionary = SELECT.apply_whole_remap(request_key, remap)
	var file_key: int = mapped.mapped_id
	var entry: Dictionary
	if file_cache.has(file_key):
		entry = make_entry(request_key, file_key, "loaded", generation, "")
	else:
		loads += 1
		var value: Variant = loader.call(file_key)
		if value == null:
			entry = make_entry(request_key, file_key, "null", generation, "load_failed")
		else:
			file_cache[file_key] = value
			entry = make_entry(request_key, file_key, "loaded", generation, "")
	request_cache[request_key] = entry
	return entry

## Adding a remap later does not retry an already cached null request.
func add_remap(request_id: int, mapped_id: int) -> void:
	remap[request_id] = mapped_id

## DESIGN hot reload: a new generation with empty caches. The original has no such
## invalidation, so this is recorded as a design addition and never as original behaviour.
func hot_reload() -> Dictionary:
	generation += 1
	request_cache.clear()
	file_cache.clear()
	return {"generation": generation, "design_addition": "hot_reload_new_generation_not_in_original"}

## Mode 1 -> 0 does not delete the DAT manager; retained state and active mode are separate.
func switch_mode(new_mode: int) -> Dictionary:
	mode = new_mode
	return {"mode": mode, "manager_retained": manager_retained, "manager_deleted_by_switch": false}
