extends RefCounted
## Main-thread-only weak index of validated, immutable bank metadata.
## Live banks own snapshots; apart from the RECENT_KEEP most recently used
## snapshots (below) this index retains no idle metadata, pixels,
## parsed-member lease, node or playback state. Eviction cannot revoke a user.
const MAX_KEYS: int = 64
## Strong references to the most recently used snapshots. Without them, once
## every monster of a kind died (auto hunting) its snapshot was freed and the
## next respawn rebuilt the whole bank from the original files: 2026-11-16
## 523.545 sp2.bank_load 338 ms x 5 per second with only 5 monsters alive.
## Snapshots are immutable metadata (compact parse, #530), a few hundred KB
## each; validation (_prepared_valid: pins and member stamps) still runs on
## every reuse.
const RECENT_KEEP: int = 16
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
static var _entries: Dictionary = {}
static var _order: Array[String] = []
static var _recent: Array = []
static var _recent_keys: Array[String] = []

static func _keep_recent(key: String, value: RefCounted) -> void:
	var index: int = _recent_keys.find(key)
	if index >= 0:
		_recent_keys.remove_at(index)
		_recent.remove_at(index)
	_recent_keys.append(key)
	_recent.append(value)
	while _recent.size() > RECENT_KEEP:
		_recent_keys.remove_at(0)
		_recent.remove_at(0)

## Drops the recent strong references (memory pressure, tests).
static func release_recent() -> void:
	_recent.clear()
	_recent_keys.clear()

var result: Dictionary = {}
var manifest: Dictionary = {}
var index: RefCounted
var exclusions: Dictionary = {}
var actor_pins: Dictionary = {}
var members: Dictionary = {}
var _node_layout: Dictionary = {}

static func effect_node_key(layer: Dictionary) -> Variant:
	var instance: Variant = layer.get("source_layer_instance_key")
	if instance is String and not instance.is_empty(): return "source_instance:" + instance
	return int(layer.layer_id)

## Only immutable source descriptors; styles, nodes and clocks stay per-view.
## This memo shares the existing live snapshot's lifetime, with no extra owner.
func layout() -> Dictionary:
	if not _node_layout.is_empty():
		HITCH.count("sp2.layout_hit")
		return _node_layout
	var started: int = HITCH.now()
	var layer_count: int = 0
	var effects: Array = []
	var seen: Dictionary = {}
	var frames_scanned: int = 0
	for track: Dictionary in result.record.tracks.values():
		for frames: Array in track.directions:
			for frame: Dictionary in frames:
				frames_scanned += 1
				layer_count = maxi(layer_count,frame.layers.size())
				for effect: Dictionary in frame.get("effect_layers",[]):
					var key: Variant = effect_node_key(effect)
					if seen.has(key): continue
					seen[key] = true
					effects.append(effect)
	_node_layout = {"layer_count":layer_count,"effects":effects}
	freeze(_node_layout)
	HITCH.count("sp2.layout_build")
	HITCH.count("sp2.layout_frames_scanned",frames_scanned)
	HITCH.detail("sp2.layout_build",started)
	return _node_layout

static func lookup(key: String) -> RefCounted:
	prune()
	var reference: WeakRef = _entries.get(key)
	var value: RefCounted = reference.get_ref() if reference != null else null
	if value != null:
		_order.erase(key)
		_order.append(key)
		_keep_recent(key, value)
	return value

static func remember(key: String, value: RefCounted) -> void:
	erase(key)
	prune()
	_entries[key] = weakref(value)
	_order.append(key)
	_keep_recent(key, value)
	while _order.size() > MAX_KEYS: erase(_order[0])

static func erase(key: String) -> void:
	_entries.erase(key)
	_order.erase(key)
	var index: int = _recent_keys.find(key)
	if index >= 0:
		_recent_keys.remove_at(index)
		_recent.remove_at(index)

static func prune() -> void:
	for key: String in _order.duplicate():
		if (_entries[key] as WeakRef).get_ref() == null: erase(key)

static func clear() -> void:
	_entries.clear()
	_order.clear()
	release_recent()

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
