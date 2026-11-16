extends RefCounted
## Runtime reader of the installed cooked actor pack (cooked_actor_format.gd).
##
## The pack's ZIP parts were verified by SHA-256 against the pins in
## scripts/boot/cooked_actor_pins.gd when they were installed
## (source523_pack.gd). Actor files are read here without per-draw or
## per-advance byte checks: integrity is install-time (docs/RESOURCE_INTEGRITY_POLICY.md,
## "변환 시 1회 검증 + 변환물 SHA 고정"). A file that is missing, malformed, of
## another FORMAT, or cooked from another selection (bank manifest, roles,
## playback mode, copy-free path) is never used: the caller falls back to the
## original runtime path for that actor.
##
## Loaded actors (index + GPU textures) are kept in a bounded LRU by texture
## bytes. Evicting only drops this store's reference; actors on screen keep
## their textures alive until they are freed.
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
const PINS = preload("res://scripts/boot/cooked_actor_pins.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const INSTALL_ROOT := "user://source523"
const STATE := "user://source523/cooked_actors.json"
const SETTINGS := "user://twilight_cooked_actors.cfg"
const DEFAULT_BUDGET_BYTES: int = 96 * 1024 * 1024
const MISSING_MAX: int = 4096

class CookedActor:
	extends RefCounted
	var key: String = ""
	var index: Dictionary = {}
	var textures: Array[Texture2D] = []
	## Runtime-shaped tracks for the existing view API (duration/timing_status).
	var tracks: Dictionary = {}
	var bytes: int = 0

static var budget_bytes: int = DEFAULT_BUDGET_BYTES
## Tests and desktop: a cooked directory (the folder holding FORMAT_TAG).
static var root_override: String = ""
static var _root: String = ""
static var _root_known: bool = false
static var _cache: Dictionary = {} # key -> CookedActor, oldest first
static var _bytes: int = 0
static var _missing: Dictionary = {}
static var _counters: Dictionary = {}

static func _count(name: String, amount: int = 1) -> void:
	_counters[name] = int(_counters.get(name, 0)) + amount

static func reset_for_tests() -> void:
	_cache.clear()
	_missing.clear()
	_counters.clear()
	_bytes = 0
	_root = ""
	_root_known = false
	budget_bytes = DEFAULT_BUDGET_BYTES

static func stats() -> Dictionary:
	return {"format":FORMAT.FORMAT,"root":root(),"entries":_cache.size(),"bytes":_bytes,"budget_bytes":budget_bytes,"missing":_missing.size(),"counters":_counters.duplicate()}

## The user setting (default on). Off: every actor uses the original path.
static func setting_enabled() -> bool:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK: return true
	return bool(config.get_value("cooked", "enabled", true))

static func set_setting_enabled(value: bool) -> Error:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("cooked", "enabled", value)
	_root_known = false
	return config.save(SETTINGS)

## The installed state written by the installer once every pinned part was
## verified and extracted, or {}.
static func installed_state() -> Dictionary:
	if not FileAccess.file_exists(STATE) or FileAccess.get_size(STATE) > 64 * 1024: return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	if not value is Dictionary or value.get("format") != FORMAT.FORMAT or value.get("cooked_id") != PINS.cooked_id or str(PINS.cooked_id).is_empty() or value.get("complete") != true: return {}
	return value

## Absolute folder of FORMAT_TAG's actor files, or "" when the cooked pack is
## not installed, is another build's pack, or is turned off.
static func root() -> String:
	if _root_known: return _root
	_root_known = true
	_root = ""
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--twilight-cooked-actors-off" in arguments or OS.get_environment("TWILIGHT_COOKED_ACTORS") == "0": return _root
	var requested: String = root_override
	for argument: String in arguments:
		if argument.begins_with("--twilight-cooked-actors="): requested = argument.trim_prefix("--twilight-cooked-actors=")
	if not requested.is_empty():
		if DirAccess.dir_exists_absolute(requested.path_join(FORMAT.FORMAT_TAG)): _root = requested.path_join(FORMAT.FORMAT_TAG)
		return _root
	if not setting_enabled() or installed_state().is_empty(): return _root
	_root = ProjectSettings.globalize_path(INSTALL_ROOT.path_join(PINS.COOKED_DIR).path_join(FORMAT.FORMAT_TAG))
	return _root

static func available() -> bool:
	return not root().is_empty()

static func _ints(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value: out[str(key)] = int(value[key]) if value[key] is int or value[key] is float else value[key]
	return out

## The selection fields a cooked actor must have been made from.
static func inputs(selected: Dictionary) -> Dictionary:
	var consumer: String = str(selected.get("consumer", ""))
	var sprite: int = int(selected.get("sprite_id", -1))
	return {"key":"%s:%d" % [consumer, sprite],"consumer":consumer,"sprite_id":sprite,
		"role_actions":_ints(selected.get("role_actions", {})),"loop_policy":selected.get("loop_policy", {}).duplicate(),
		"optional_role_actions":_ints(selected.get("optional_role_actions", {})),"optional_role_actor_ids":_ints(selected.get("optional_role_actor_ids", {})),
		"optional_role_loop_policy":selected.get("optional_role_loop_policy", {}).duplicate(),"role_actor_ids":_ints(selected.get("role_actor_ids", {})),
		"manifest_sha256":str(selected.get("manifest_sha256", "")).to_lower()}

## The cooked actor for this exact selection, or null (original path).
static func lookup(selected: Dictionary) -> CookedActor:
	var folder: String = root()
	if folder.is_empty(): return null
	var wanted: Dictionary = inputs(selected)
	var key: String = wanted.key
	var actor: Variant = _cache.get(key)
	if actor is CookedActor:
		_cache.erase(key)
		_cache[key] = actor
		_count("hit")
		return actor if _matches(actor, wanted, selected) else null
	if _missing.has(key):
		_count("missing_memo")
		return null
	var loaded: Dictionary = load_actor(folder.path_join(FORMAT.actor_file(key)))
	if not loaded.ok:
		while _missing.size() >= MISSING_MAX: _missing.erase(_missing.keys()[0])
		_missing[key] = loaded.error
		_count("miss:" + str(loaded.error))
		return null
	actor = loaded.actor
	_cache[key] = actor
	_bytes += actor.bytes
	_count("loaded")
	_trim()
	return actor if _matches(actor, wanted, selected) else null

static func _matches(actor: CookedActor, wanted: Dictionary, selected: Dictionary) -> bool:
	var mode: String = POLICY.mode(str(selected.get("manifest_path", "")).get_base_dir())
	if actor.index.get("inputs") != wanted or actor.index.get("mode") != mode or bool(actor.index.get("screen_copy", true)) != COMPOSITOR.screen_copy_available:
		_count("selection_differs")
		return false
	return true

static func _trim() -> void:
	while _bytes > budget_bytes and _cache.size() > 1:
		var oldest: String = _cache.keys()[0]
		_bytes -= int(_cache[oldest].bytes)
		_cache.erase(oldest)
		_count("evicted")

## Reads one cooked actor file into textures and runtime tracks.
static func load_actor(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"error":"absent"}
	var file := FileAccess.open(path, FileAccess.READ)
	var head: Dictionary = FORMAT.read_index(file)
	if not head.ok: return head
	var index: Dictionary = head.index
	var pages: Dictionary = FORMAT.read_pages(file, index, int(head.data_start))
	file.close()
	if not pages.ok: return pages
	var actor := CookedActor.new()
	actor.key = str(index.get("key", ""))
	actor.index = index
	for image: Image in pages.images:
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		if texture == null: return {"ok":false,"error":"cooked_actor_texture"}
		actor.textures.append(texture)
		actor.bytes += image.get_data_size()
	var images: PackedInt32Array = index.images
	if images.size() % 5 != 0: return {"ok":false,"error":"cooked_actor_images"}
	for at: int in range(0, images.size(), 5):
		if images[at] < 0 or images[at] >= actor.textures.size(): return {"ok":false,"error":"cooked_actor_image_page"}
		var size: Vector2 = actor.textures[images[at]].get_size()
		if images[at + 1] < 0 or images[at + 2] < 0 or images[at + 1] + images[at + 3] > size.x or images[at + 2] + images[at + 4] > size.y: return {"ok":false,"error":"cooked_actor_image_rect"}
	var image_count: int = images.size() / 5
	for state: Variant in index.states:
		if not state is PackedInt32Array or state.size() % FORMAT.ITEM_STRIDE != 0: return {"ok":false,"error":"cooked_actor_state"}
		for at: int in range(0, state.size(), FORMAT.ITEM_STRIDE):
			if state[at] < 0 or state[at] >= image_count or state[at + 6] < 0 or state[at + 6] * 4 + 3 >= index.colors.size(): return {"ok":false,"error":"cooked_actor_state_image"}
	for role: Variant in index.tracks:
		var track: Variant = index.tracks[role]
		if not track is Dictionary or not track.get("directions") is Array or track.directions.size() != 8: return {"ok":false,"error":"cooked_actor_track"}
		var directions: Array = []
		for direction: Variant in track.directions:
			if not direction is Dictionary or not direction.get("durations") is PackedFloat64Array or direction.durations.is_empty(): return {"ok":false,"error":"cooked_actor_direction"}
			if direction.seg_start.size() != direction.durations.size() + 1 or direction.seg_end.size() != direction.seg_state.size(): return {"ok":false,"error":"cooked_actor_segments"}
			for state: int in direction.seg_state:
				if state < 0 or state >= index.states.size(): return {"ok":false,"error":"cooked_actor_segment_state"}
			if int(direction.get("end_state", -1)) >= index.states.size(): return {"ok":false,"error":"cooked_actor_end_state"}
			var frames: Array = []
			for frame: int in range(direction.durations.size()):
				frames.append({"duration":direction.durations[frame],"source_frame":direction.source_frames[frame],"source_group":direction.source_groups[frame]})
			directions.append(frames)
		actor.tracks[str(role)] = {"loop":bool(track.loop),"static_pending_timing":bool(track.static_pending_timing),"fps":track.get("fps"),"effective_fps":track.get("effective_fps"),
			"timing_origin":track.get("timing_origin"),"source_action_id":track.get("source_action_id"),"source_sprite_id":track.get("source_sprite_id"),"directions":directions,"cooked":true}
	return {"ok":true,"actor":actor}
