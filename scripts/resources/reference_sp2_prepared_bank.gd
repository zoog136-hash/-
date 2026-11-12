extends RefCounted
## Main-thread-only weak index of validated, immutable bank metadata.
## Live banks own snapshots; this index retains no idle metadata, pixels,
## parsed-member lease, node or playback state. Eviction cannot revoke a user.
const MAX_KEYS: int = 64
static var _entries: Dictionary = {}
static var _order: Array[String] = []

var result: Dictionary = {}
var manifest: Dictionary = {}
var index: RefCounted
var exclusions: Dictionary = {}
var actor_pins: Dictionary = {}
var members: Dictionary = {}

static func lookup(key: String) -> RefCounted:
	prune()
	var reference: WeakRef = _entries.get(key)
	var value: RefCounted = reference.get_ref() if reference != null else null
	if value != null:
		_order.erase(key)
		_order.append(key)
	return value

static func remember(key: String, value: RefCounted) -> void:
	erase(key)
	prune()
	_entries[key] = weakref(value)
	_order.append(key)
	while _order.size() > MAX_KEYS: erase(_order[0])

static func erase(key: String) -> void:
	_entries.erase(key)
	_order.erase(key)

static func prune() -> void:
	for key: String in _order.duplicate():
		if (_entries[key] as WeakRef).get_ref() == null: erase(key)

static func clear() -> void:
	_entries.clear()
	_order.clear()

static func size() -> int:
	prune()
	return _entries.size()

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		if value.is_read_only(): return
		for child: Variant in value.values(): freeze(child)
		value.make_read_only()
	elif value is Array:
		if value.is_read_only(): return
		for child: Variant in value: freeze(child)
		value.make_read_only()
