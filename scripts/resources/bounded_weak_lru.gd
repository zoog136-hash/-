extends RefCounted
## Bounded strong LRU with weak reuse (Lineage M style "keep a small reserve").
##
## Main-thread only. The cache owns only its own strong references: an evicted
## Object value stays reachable through a WeakRef while some other owner (a
## live node, a SpriteFrames, an AtlasTexture) still holds it, so lookup()
## returns that exact instance instead of a second decode. A non-Object value
## (Dictionary/Array) has no weak form; once evicted it is simply gone and the
## owner re-reads it. Costs are caller estimates (for textures the decoded
## payload, not GPU/RSS).
var max_entries: int = 64
var max_cost: int = 0 # 0 = no cost bound
var _strong: Dictionary = {}
var _order: Array = [] # Oldest first; deterministic.
var _cost: Dictionary = {}
var _weak: Dictionary = {}
var _strong_cost: int = 0
var hits: int = 0
var weak_hits: int = 0
var misses: int = 0
var evictions: int = 0

func _init(entries: int = 64, cost: int = 0) -> void:
	configure(entries, cost)

func configure(entries: int, cost: int = 0) -> void:
	max_entries = maxi(0, entries)
	max_cost = maxi(0, cost)
	trim(max_entries, max_cost)

## The cached value, or null. A weak hit is re-admitted as most recent.
func lookup(key: Variant) -> Variant:
	if _strong.has(key):
		hits += 1
		_order.erase(key)
		_order.append(key)
		return _strong[key]
	var reference: WeakRef = _weak.get(key) as WeakRef
	if reference != null:
		var value: Object = reference.get_ref()
		if value != null:
			weak_hits += 1
			_admit(key, value, int(_cost.get(key, 1)))
			return value
		_weak.erase(key)
		_cost.erase(key)
	misses += 1
	return null

func has(key: Variant) -> bool:
	if _strong.has(key): return true
	var reference: WeakRef = _weak.get(key) as WeakRef
	return reference != null and reference.get_ref() != null

func store(key: Variant, value: Variant, cost: int = 1) -> void:
	erase(key)
	if value == null: return
	var bytes: int = maxi(1, cost)
	_cost[key] = bytes
	if value is Object: _weak[key] = weakref(value)
	_admit(key, value, bytes)

func _admit(key: Variant, value: Variant, bytes: int) -> void:
	if _strong.has(key): return
	if max_entries == 0 or (max_cost > 0 and bytes > max_cost):
		if not value is Object: _cost.erase(key)
		return
	_strong[key] = value
	_order.append(key)
	_strong_cost += bytes
	trim(max_entries, max_cost, key)

func _drop(key: Variant) -> void:
	if not _strong.has(key): return
	var value: Variant = _strong[key]
	_strong.erase(key)
	_order.erase(key)
	_strong_cost -= int(_cost.get(key, 1))
	if not value is Object: _cost.erase(key)
	evictions += 1

func erase(key: Variant) -> void:
	_drop(key)
	_weak.erase(key)
	_cost.erase(key)

## Drops this cache's oldest strong references until both bounds hold.
## `keep` (the entry just admitted) survives as long as it fits alone.
func trim(entries: int, cost: int = 0, keep: Variant = null) -> void:
	var index: int = 0
	while index < _order.size() and (_order.size() > maxi(0, entries) or (cost > 0 and _strong_cost > cost)):
		var key: Variant = _order[index]
		if keep != null and typeof(key) == typeof(keep) and key == keep and _order.size() > 1:
			index += 1
			continue
		_drop(key)
	prune()

## Forgets weak entries whose value no other owner still holds.
func prune() -> void:
	for key: Variant in _weak.keys():
		if not _strong.has(key) and (_weak[key] as WeakRef).get_ref() == null:
			_weak.erase(key)
			_cost.erase(key)

func clear(forget_weak: bool = false) -> void:
	for key: Variant in _order.duplicate(): _drop(key)
	if forget_weak:
		_weak.clear()
		_cost.clear()
	prune()

func strong_size() -> int: return _strong.size()
func strong_cost() -> int: return _strong_cost
func tracked_size() -> int: return _weak.size()

func metrics() -> Dictionary:
	return {"max_entries":max_entries, "max_cost":max_cost, "strong_entries":_strong.size(),
		"strong_cost":_strong_cost, "weak_entries":_weak.size(), "hits":hits,
		"weak_hits":weak_hits, "misses":misses, "evictions":evictions}
