extends RefCounted
## Process-wide owner of decoded original UI atlas pages, shared by every
## source_pack.gd instance that opened the same verified pack.
##
## Identity: manifest SHA-256 + normalized pack root + page member + the
## member's pinned SHA-256 + page pixel mode. Pages are pixel-mode independent
## (always RGBA8 straight alpha with the "cocos_png_pma" meta); the Cocos
## premultiplied output is a separate frame identity below.
##
## Ownership: an entry is LIVE while any pack instance (an open screen/owner)
## holds a lease on it, IDLE otherwise. Only IDLE entries are evicted, oldest
## use first, until cache-owned page bytes fit the budget. Live bytes are never
## evicted, so the total may exceed the budget while screens hold leases.
## Leases are plain integer owner ids; the cache never stores pack objects and
## packs never store cache objects, so there is no reference cycle.
##
## Frames: reconstructed frame textures (trim/rotation/canvas/PMA exactly as
## source_pack.gd produced them) are shared by WeakRef only. The registry never
## extends a frame's life; it lets a second pack instance reuse the identical
## ImageTexture another owner still holds instead of decoding a duplicate.
##
## enabled=false restores the previous per-instance behaviour unchanged.
## Main thread only, like the source_pack.gd callers.

const DEFAULT_BUDGET_BYTES: int = 48*1024*1024
const PAGE_MODE: String = "rgba8_straight_pma_meta_v1"

static var enabled: bool = true
static var budget_bytes: int = DEFAULT_BUDGET_BYTES
static var _entries: Dictionary = {}
static var _frames: Dictionary = {}
static var _clock: int = 0
static var _counters: Dictionary = {"page_hits":0,"page_misses":0,"page_stores":0,"page_evictions":0,"evicted_bytes":0,"frame_hits":0,"frame_registrations":0}

static func page_key(manifest_sha256: String, root: String, member: String, member_sha256: String) -> String:
	return "page|"+PAGE_MODE+"|"+manifest_sha256+"|"+_root_identity(root)+"|"+member+"|"+member_sha256

static func frame_key(manifest_sha256: String, root: String, kind: String, plist: String, path: String, cocos_pixels: bool) -> String:
	return "frame|"+manifest_sha256+"|"+_root_identity(root)+"|"+kind+"|"+plist+"|"+path+"|"+("cocos_pixels" if cocos_pixels else "straight")

static func _root_identity(root: String) -> String:
	return root.simplify_path().trim_suffix("/")

## Returns the shared page and leases it to owner, or null on a miss.
static func acquire_page(key: String, owner: int) -> Image:
	var entry: Variant = _entries.get(key)
	if not entry is Dictionary:
		_counters.page_misses += 1
		return null
	_clock += 1
	entry.last_used = _clock
	entry.leases[owner] = true
	_counters.page_hits += 1
	return entry.image

## Publishes a freshly decoded page leased to owner. If an equal key already
## exists the existing image wins so every owner sees one object.
static func store_page(key: String, owner: int, image: Image) -> Image:
	if _entries.has(key): return acquire_page(key, owner)
	_clock += 1
	_entries[key] = {"image":image,"bytes":image.get_data_size(),"leases":{owner:true},"last_used":_clock}
	_counters.page_stores += 1
	trim_idle()
	return image

## Releases one owner's leases exactly once; repeated release is a no-op.
static func release(owner: int, keys: Array) -> void:
	for key: Variant in keys:
		var entry: Variant = _entries.get(key)
		if entry is Dictionary: entry.leases.erase(owner)
	trim_idle()

## Evicts IDLE entries, oldest first, until cache-owned bytes <= target.
static func trim_idle(target: int = -1) -> int:
	var limit: int = budget_bytes if target < 0 else target
	var total: int = 0
	var idle: Array[Dictionary] = []
	for key: String in _entries:
		var entry: Dictionary = _entries[key]
		total += int(entry.bytes)
		if entry.leases.is_empty(): idle.append({"key":key,"last_used":int(entry.last_used),"bytes":int(entry.bytes)})
	if total <= limit or idle.is_empty(): return 0
	idle.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.last_used < b.last_used)
	var freed: int = 0
	for row: Dictionary in idle:
		if total <= limit: break
		_entries.erase(row.key)
		total -= int(row.bytes); freed += int(row.bytes)
		_counters.page_evictions += 1
		_counters.evicted_bytes += int(row.bytes)
	return freed

static func shared_frame(key: String) -> Texture2D:
	var ref: Variant = _frames.get(key)
	if ref is WeakRef:
		var alive: Variant = ref.get_ref()
		if alive is Texture2D:
			_counters.frame_hits += 1
			return alive
		_frames.erase(key)
	return null

static func register_frame(key: String, texture: Texture2D) -> void:
	_frames[key] = weakref(texture)
	_counters.frame_registrations += 1

static func stats() -> Dictionary:
	var live_count: int = 0; var live_bytes: int = 0; var idle_count: int = 0; var idle_bytes: int = 0
	var lease_count: int = 0
	for entry: Dictionary in _entries.values():
		if entry.leases.is_empty():
			idle_count += 1; idle_bytes += int(entry.bytes)
		else:
			live_count += 1; live_bytes += int(entry.bytes); lease_count += entry.leases.size()
	var frames_alive: int = 0
	for key: String in _frames.keys():
		if _frames[key].get_ref() == null: _frames.erase(key)
		else: frames_alive += 1
	var result: Dictionary = _counters.duplicate()
	result.merge({"enabled":enabled,"budget_bytes":budget_bytes,"live_pages":live_count,"live_bytes":live_bytes,"live_leases":lease_count,"idle_pages":idle_count,"idle_bytes":idle_bytes,"cache_owned_bytes":live_bytes+idle_bytes,"shared_frames_alive":frames_alive,"accounting":"cpu_rgba8_page_bytes_only; textures/gpu/driver/decode temporaries excluded"}, true)
	return result

static func page_leases(key: String) -> int:
	var entry: Variant = _entries.get(key)
	return entry.leases.size() if entry is Dictionary else -1

## Test/probe helper. Never called by game code.
static func reset() -> void:
	_entries.clear(); _frames.clear(); _clock = 0
	for key: String in _counters: _counters[key] = 0
	budget_bytes = DEFAULT_BUDGET_BYTES
	enabled = true
