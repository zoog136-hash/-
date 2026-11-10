extends RefCounted
## NEW PROPOSAL. Main-thread only, one instance per verified image pack.
## Bytes are decoded Image payload estimates, NOT GPU/RSS or all live textures.
## Metadata is bounded separately. Forgetting a weak entry can permit a later
## duplicate decode while an untracked external owner still holds the old one.
const DEFAULT_BUDGET_BYTES: int = 32 * 1024 * 1024 # Proposal, not measured.
const DEFAULT_MAX_ENTRIES: int = 4096
var _budget: int = DEFAULT_BUDGET_BYTES
var _max_entries: int = DEFAULT_MAX_ENTRIES
var _resident: Dictionary = {}
var _weak: Dictionary = {}
var _cost: Dictionary = {}
var _resident_lru: Array[String] = [] # Oldest first; deterministic.
var _tracked_lru: Array[String] = []
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
	if _resident.has(key):
		_resident_hits += 1
		_touch(_resident_lru, key)
		_touch(_tracked_lru, key)
		return _resident[key]
	if _weak.has(key):
		var texture: Texture2D = _weak[key].get_ref() as Texture2D
		if texture != null:
			_weak_hits += 1
			_touch(_tracked_lru, key)
			_admit(key, texture)
			return texture
		_forget(key)
	_misses += 1
	return null

## Caller supplies the decoded Image.get_data_size(), not compressed file bytes.
func remember(key: String, texture: Texture2D, decoded_bytes: int) -> void:
	prune()
	_forget(key)
	if texture == null or decoded_bytes <= 0 or _max_entries == 0:
		return
	_weak[key] = weakref(texture)
	_cost[key] = decoded_bytes
	_tracked_lru.append(key)
	_admit(key, texture)
	_limit_metadata()

func _admit(key: String, texture: Texture2D) -> void:
	var bytes: int = _cost[key]
	if bytes > _budget or _budget == 0:
		return
	trim_to(_budget - bytes)
	_resident[key] = texture
	_resident_bytes += bytes
	_resident_lru.append(key)

func _touch(order: Array[String], key: String) -> void:
	order.erase(key)
	order.append(key)

func _drop_resident(key: String) -> void:
	if not _resident.has(key):
		return
	_resident_bytes -= int(_cost[key])
	_resident.erase(key)
	_resident_lru.erase(key)
	_evictions += 1

func _forget(key: String) -> void:
	_drop_resident(key)
	_weak.erase(key)
	_cost.erase(key)
	_tracked_lru.erase(key)

func _limit_metadata() -> void:
	while _tracked_lru.size() > _max_entries:
		_forget(_tracked_lru[0])

## Releases strong cache references only; external Texture2D owners survive.
## Does not change configured budget. A later lookup can re-admit a weak hit.
func trim_to(target_bytes: int) -> void:
	var target: int = maxi(0, target_bytes)
	while _resident_bytes > target and not _resident_lru.is_empty():
		_drop_resident(_resident_lru[0])

func clear(forget_weak: bool = false) -> void:
	trim_to(0)
	if forget_weak:
		_weak.clear()
		_cost.clear()
		_tracked_lru.clear()
	else:
		prune()

func prune() -> void:
	for key: String in _tracked_lru.duplicate():
		if not _resident.has(key) and _weak[key].get_ref() == null:
			_forget(key)

## Snapshot only: never prune, reset counters, or expose internal dictionaries.
func metrics() -> Dictionary:
	return {"budget_bytes":_budget, "max_entries":_max_entries,
		"resident_decoded_bytes_estimate":_resident_bytes,
		"resident_entries":_resident.size(), "tracked_entries":_weak.size(),
		"resident_hits":_resident_hits, "weak_hits":_weak_hits,
		"misses":_misses, "evictions":_evictions,
		"accounting":"decoded_image_payload_only_not_gpu_or_rss"}
