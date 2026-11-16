extends RefCounted
## Process-wide cache of composited 523 actor frames (2026-11-16, phone: the
## per-frame multi-layer SP2 work was the largest CPU cost: monster.view
## 378 ms/s, preview.layers_same 230 ms/s at 4 fps).
##
## One entry is ONE texture made from several already verified SP2 layer
## renders of one draw group (the body layers, z 0, or the effect layers, z 1)
## of one selected source frame. original_source_preview.gd builds entries
## only from render_layer(layer, true) results of the same call, i.e. bytes
## that passed the bank's pin + member identity checks; this store itself never
## reads or verifies bytes and never writes anything to disk.
##
## Exactness: compose() overwrites with blit_rect_mask(), which equals the
## Canvas MIX draw of the separate layers only when every layer is drawn with
## MIX at alpha 1.0 and every texel alpha is 0 or 255 (the SP2 renderer writes
## exactly these two values). The caller only composites such groups; every
## other group keeps per-layer nodes (see FORMAT).
##
## Keys: FORMAT + pack root + verified manifest SHA-256 + the ordered drawn
## layer identities (member, stored bit, frame, offset). Never an actor
## instance, never a script source hash: editing scripts does not change keys;
## changing the composition rule must bump FORMAT.
##
## Memory: bounded LRU by payload bytes (width * height * 4). Evicting drops
## only this store's reference; a Sprite2D that currently shows the texture
## keeps it alive until it shows another frame (same as the shared SP2 store).
const FORMAT := "actor_frame_composite_v1:blit_rect_mask_binary_alpha_MIX_alpha1;RGBA8;nearest;union_rect"
const DEFAULT_BUDGET_BYTES := 32 * 1024 * 1024
static var budget_bytes: int = DEFAULT_BUDGET_BYTES
static var _entries: Dictionary = {} # key -> {texture, origin, bytes}, oldest first
static var _bytes: int = 0
static var _counters: Dictionary = {}

static func key(root: String, manifest_sha: String, group: String, items: Array) -> String:
	var parts: PackedStringArray = [FORMAT, root, manifest_sha, group]
	for item: Dictionary in items:
		var layer: Dictionary = item.layer
		parts.append("%s:%d:%d:%d:%d" % [str(layer.get("member", "")), int(layer.get("group_bit", -1)), int(layer.get("frame_index", -1)), int(item.offset.x), int(item.offset.y)])
	return "|".join(parts)

## The cached entry (most recently used last), or {}.
static func lookup(entry_key: String) -> Dictionary:
	var entry: Variant = _entries.get(entry_key)
	if not entry is Dictionary:
		_count("miss")
		return {}
	_entries.erase(entry_key)
	_entries[entry_key] = entry
	_count("hit")
	return entry

static func store(entry_key: String, texture: Texture2D, origin: Vector2i, payload_bytes: int) -> Dictionary:
	if _entries.has(entry_key): _bytes -= int(_entries[entry_key].bytes)
	_entries.erase(entry_key)
	var entry: Dictionary = {"texture":texture,"origin":origin,"bytes":payload_bytes}
	_entries[entry_key] = entry
	_bytes += payload_bytes
	_count("stored")
	trim(budget_bytes)
	return entry

## Evict least recently used entries until the payload fits `budget`. The
## newest entry is kept even when it alone exceeds the budget (it is on screen).
static func trim(budget: int) -> int:
	var evicted: int = 0
	while _bytes > budget and _entries.size() > 1:
		var oldest: String = _entries.keys()[0]
		_bytes -= int(_entries[oldest].bytes)
		_entries.erase(oldest)
		evicted += 1
	if evicted > 0: _count("evicted", evicted)
	return evicted

## {image, origin} composited in the given draw order, or {} when the items
## cannot be composited exactly (the caller keeps per-layer nodes then).
static func compose(items: Array) -> Dictionary:
	var union := Rect2i()
	var first: bool = true
	for item: Dictionary in items:
		var image: Image = item.image
		if image == null or image.is_empty() or image.get_format() != Image.FORMAT_RGBA8: return {}
		if image.detect_alpha() == Image.ALPHA_BLEND: return {}
		var rect := Rect2i(item.offset, image.get_size())
		union = rect if first else union.merge(rect)
		first = false
	if first or union.size.x <= 0 or union.size.y <= 0: return {}
	var out := Image.create_empty(union.size.x, union.size.y, false, Image.FORMAT_RGBA8)
	for item: Dictionary in items:
		var image: Image = item.image
		out.blit_rect_mask(image, image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(item.offset) - union.position)
	return {"image":out,"origin":union.position}

static func stats() -> Dictionary:
	return {"format":FORMAT,"entries":_entries.size(),"bytes":_bytes,"budget_bytes":budget_bytes,"counters":_counters.duplicate()}

static func reset_for_tests() -> void:
	_entries.clear()
	_bytes = 0
	_counters.clear()
	budget_bytes = DEFAULT_BUDGET_BYTES

static func _count(name: String, amount: int = 1) -> void:
	_counters[name] = int(_counters.get(name, 0)) + amount
