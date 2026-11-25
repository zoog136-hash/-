extends RefCounted
## NEW PROPOSAL. Main-thread only, one instance per verified image pack.
## Bytes are decoded Image payload estimates, NOT GPU/RSS or all live textures.
## Metadata is bounded separately. Forgetting a weak entry can permit a later
## duplicate decode while an untracked external owner still holds the old one.
const DEFAULT_BUDGET_BYTES: int = 32 * 1024 * 1024 # Proposal, not measured.
const DEFAULT_MAX_ENTRIES: int = 4096
var _budget: int = DEFAULT_BUDGET_BYTES
var _max_entries: int = DEFAULT_MAX_ENTRIES
# Godot dictionaries preserve insertion order. Each map doubles as its LRU,
# oldest key first, without searching or shifting arrays on a texture hit.
var _resident: Dictionary = {}
var _cost: Dictionary = {} # All tracked keys in last-use order.
# A texture has either a resident owner or a weak reference. Allocate the
# latter only when the cache first relinquishes ownership or cannot admit it.
var _weak: Dictionary = {}
var _resident_bytes: int = 0
var _resident_hits: int = 0
var _weak_hits: int = 0
var _misses: int = 0
var _evictions: int = 0

func configure(budget_bytes: int, max_entries: int = DEFAULT_MAX_ENTRIES) -> void:
	_budget = maxi(0, budget_bytes)
	_max_entries = maxi(0, max_entries)
	prune()
	trim_to(_budget)
	_limit_metadata()

func lookup(key: String) -> Texture2D:
	var resident: Texture2D = _resident.get(key)
	if resident != null:
		_resident_hits += 1
		_touch(_resident, key, resident)
		_touch(_cost, key, _cost[key])
		return resident
	if _weak.has(key):
		var texture: Texture2D = _weak[key].get_ref() as Texture2D
		if texture != null:
			_weak_hits += 1
			_touch(_cost, key, _cost[key])
			_admit(key, texture)
			return texture
		_forget(key)
	_misses += 1
	return null

## Caller supplies the decoded Image.get_data_size(), not compressed file bytes.
func remember(key: String, texture: Texture2D, decoded_bytes: int) -> void:
	prune()
	if _cost.has(key):
		_forget(key)
	if texture == null or decoded_bytes <= 0 or _max_entries == 0:
		return
	_cost[key] = decoded_bytes
	_admit(key, texture)
	_limit_metadata()

func _admit(key: String, texture: Texture2D) -> void:
	var bytes: int = _cost[key]
	if bytes > _budget or _budget == 0:
		if not _weak.has(key):
			_weak[key] = weakref(texture)
		return
	trim_to(_budget - bytes)
	_resident[key] = texture
	_resident_bytes += bytes
	_weak.erase(key)

func _touch(entries: Dictionary, key: String, value: Variant) -> void:
	entries.erase(key)
	entries[key] = value

func _oldest_key(entries: Dictionary) -> String:
	for key: String in entries:
		return key
	return ""

func _drop_resident(key: String) -> void:
	if not _resident.erase(key):
		return
	_resident_bytes -= int(_cost[key])
	_evictions += 1

func _forget(key: String) -> void:
	_drop_resident(key)
	_weak.erase(key)
	_cost.erase(key)

func _limit_metadata() -> void:
	while _cost.size() > _max_entries:
		_forget(_oldest_key(_cost))

## Releases strong cache references only; external Texture2D owners survive.
## Does not change configured budget. A later lookup can re-admit a weak hit.
func trim_to(target_bytes: int) -> void:
	var target: int = maxi(0, target_bytes)
	while _resident_bytes > target and not _resident.is_empty():
		var oldest: String = _oldest_key(_resident)
		_weak[oldest] = weakref(_resident[oldest])
		_drop_resident(oldest)

func clear(forget_weak: bool = false) -> void:
	if forget_weak:
		# No future lookup can reuse these entries. Drop their owners directly.
		_evictions += _resident.size()
		_resident_bytes = 0
		_resident.clear()
		_weak.clear()
		_cost.clear()
	else:
		trim_to(0)
		prune()

func prune() -> void:
	if _weak.is_empty():
		return
	for key: String in _weak.keys():
		if _weak[key].get_ref() == null:
			_forget(key)

## Snapshot only: never prune, reset counters, or expose internal dictionaries.
func metrics() -> Dictionary:
	return {"budget_bytes":_budget, "max_entries":_max_entries,
		"resident_decoded_bytes_estimate":_resident_bytes,
		"resident_entries":_resident.size(), "tracked_entries":_cost.size(),
		"resident_hits":_resident_hits, "weak_hits":_weak_hits,
		"misses":_misses, "evictions":_evictions,
		"accounting":"decoded_image_payload_only_not_gpu_or_rss"}
