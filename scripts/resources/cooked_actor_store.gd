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

## One bundle file: shared pages/images/states and its entries (one per
## cooked selection/request of this body, e.g. every weapon family).
class CookedActor:
	extends RefCounted
	var key: String = ""
	var index: Dictionary = {}
	var textures: Array[Texture2D] = []
	## entry key (var_to_str of its inputs) -> entry; each entry also holds
	## "runtime_tracks" shaped for the existing view API (duration/timing).
	var entries: Dictionary = {}
	var bytes: int = 0

static var budget_bytes: int = DEFAULT_BUDGET_BYTES
## Tests and desktop: a cooked directory (the folder holding FORMAT_TAG).
static var root_override: String = ""
## Tests and the cook tool: never use a cooked actor (original path only).
static var disabled: bool = false
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
	_effect_index = {}
	_effect_index_root = "-"
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
	if disabled: return ""
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

static func _bools(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value: out[str(key)] = bool(value[key]) if value[key] is bool else value[key]
	return out

## Playback mode original_source_preview.gd resolves for this request.
static func request_mode(manifest_path: String, consumer: String, override: String = "") -> String:
	if consumer.is_empty(): return override if override in ["strict", "compatible"] else "strict"
	return POLICY.mode(manifest_path.get_base_dir(), override)

## A card/NPC/class selection as given to _configure_selected_roles (before
## its optional roles are resolved): the fields that decide what is drawn.
static func selection_inputs(selected: Dictionary, override: String = "") -> Dictionary:
	var consumer: String = str(selected.get("consumer", ""))
	return {"kind":"selection","consumer":consumer,"sprite_id":int(selected.get("sprite_id", -1)),
		"role_actions":_ints(selected.get("role_actions", {})),"loop_policy":_bools(selected.get("loop_policy", {})),
		"optional_role_actions":_ints(selected.get("optional_role_actions", {})),"optional_role_actor_ids":_ints(selected.get("optional_role_actor_ids", {})),
		"optional_role_loop_policy":_bools(selected.get("optional_role_loop_policy", {})),"role_actor_ids":_ints(selected.get("role_actor_ids", {})),
		"manifest_sha256":str(selected.get("manifest_sha256", "")).to_lower(),
		"mode":request_mode(str(selected.get("manifest_path", "")), consumer, override),"screen_copy":COMPOSITOR.screen_copy_available}

## A direct _configure_reference_bank request (effects, ammo, overlays).
static func request_inputs(manifest_path: String, manifest_sha: String, sprite: int, bindings: Dictionary, loops: Dictionary, consumer: String, role_actor_ids: Dictionary, override: String = "") -> Dictionary:
	return {"kind":"request","consumer":consumer,"sprite_id":sprite,"role_actions":_ints(bindings),"loop_policy":_bools(loops),
		"role_actor_ids":_ints(role_actor_ids),"manifest_sha256":manifest_sha.to_lower(),
		"mode":request_mode(manifest_path, consumer, override),"screen_copy":COMPOSITOR.screen_copy_available}

## Requests that are never cooked: an independent source layer is drawn with
## its parent's draw flags, so it is part of its parent's cooked frames.
static func cookable_consumer(consumer: String) -> bool:
	return consumer != "source_layer"

## The bundle file of a consumer's body sprite (all its cooked entries).
static func file_for(inputs: Dictionary) -> String:
	return "actors/%s_%d.twca" % [str(inputs.get("consumer", "")).replace(":", "_"), int(inputs.get("sprite_id", -1))]

static func entry_key(inputs: Dictionary) -> String:
	return var_to_str(inputs)

## Back-compatible NPC selection lookup.
static func lookup(selected: Dictionary, override: String = "") -> Dictionary:
	return lookup_inputs(selection_inputs(selected, override))

## {actor, entry} cooked from exactly these inputs, or {} (original path).
static func lookup_inputs(inputs: Dictionary) -> Dictionary:
	if not cookable_consumer(str(inputs.get("consumer", ""))): return {}
	var folder: String = root()
	if folder.is_empty(): return {}
	var file: String = file_for(inputs)
	var actor: Variant = _cache.get(file)
	if actor is CookedActor:
		_cache.erase(file)
		_cache[file] = actor
		_count("hit")
	elif _missing.has(file):
		_count("missing_memo")
		return {}
	else:
		var loaded: Dictionary = load_actor(folder.path_join(file))
		if not loaded.ok:
			while _missing.size() >= MISSING_MAX: _missing.erase(_missing.keys()[0])
			_missing[file] = loaded.error
			_count("miss:" + str(loaded.error))
			return {}
		actor = loaded.actor
		_cache[file] = actor
		_bytes += actor.bytes
		_count("loaded")
		_trim()
	var entry: Variant = actor.entries.get(entry_key(inputs))
	if not entry is Dictionary or entry.get("inputs") != inputs:
		_count("entry_absent")
		return {}
	return {"actor":actor,"entry":entry}

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
	actor.key = path.get_file().get_basename()
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
	for value: Variant in index.entries:
		if not value is Dictionary or not value.get("inputs") is Dictionary or not value.get("tracks") is Dictionary: return {"ok":false,"error":"cooked_actor_entry"}
		var entry: Dictionary = value
		var runtime_tracks: Dictionary = {}
		for role: Variant in entry.tracks:
			var track: Variant = entry.tracks[role]
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
					var cooked_frame: Dictionary = {"duration":direction.durations[frame],"source_frame":direction.source_frames[frame],"source_group":direction.source_groups[frame],"cooked_index":frame}
					# The original preview's boundary epsilon depends on this key.
					if bool(direction.get("eps", false)): cooked_frame["presentation_duration"] = direction.durations[frame]
					frames.append(cooked_frame)
				directions.append(frames)
			runtime_tracks[str(role)] = {"loop":bool(track.loop),"static_pending_timing":bool(track.static_pending_timing),"fps":track.get("fps"),"effective_fps":track.get("effective_fps"),
				"timing_origin":track.get("timing_origin"),"source_action_id":track.get("source_action_id"),"source_sprite_id":track.get("source_sprite_id"),"directions":directions,"cooked":true}
		entry["runtime_tracks"] = runtime_tracks
		actor.entries[entry_key(entry.inputs)] = entry
	return {"ok":true,"actor":actor}

## The recorded draw state of `direction` for the frame the original clock
## selected (`frame` with `offset` seconds into it), or the held end state.
static func state_for(entry: Dictionary, role: String, direction: int, frame: int, offset: float, ended: bool) -> int:
	var cooked: Dictionary = entry.tracks[role].directions[direction]
	if ended: return int(cooked.end_state)
	var state: int = -1
	for segment: int in range(cooked.seg_start[frame], cooked.seg_start[frame + 1]):
		state = cooked.seg_state[segment]
		if offset < cooked.seg_end[segment]: break
	return state if state >= 0 else int(cooked.end_state)

static var _materials: Dictionary = {}

static func _material(blend: int) -> CanvasItemMaterial:
	if blend == CanvasItemMaterial.BLEND_MODE_MIX: return null
	if not _materials.has(blend):
		var material := CanvasItemMaterial.new()
		material.blend_mode = blend
		_materials[blend] = material
	return _materials[blend]

## Shows `state` with `sprites` (children of `owner`, grown on demand): one
## Sprite2D per recorded item, page texture + region, in recorded draw order.
static func apply_state(owner: Node2D, sprites: Array[Sprite2D], actor: CookedActor, state: int) -> void:
	var items: PackedInt32Array = actor.index.states[state]
	var images: PackedInt32Array = actor.index.images
	var colors: PackedFloat32Array = actor.index.colors
	var count: int = items.size() / FORMAT.ITEM_STRIDE
	while sprites.size() < count:
		var sprite := Sprite2D.new()
		sprite.name = "CookedLayer%d" % sprites.size()
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_filter_clip_enabled = true
		owner.add_child(sprite)
		sprites.append(sprite)
	for slot: int in range(sprites.size()):
		var sprite: Sprite2D = sprites[slot]
		if slot >= count:
			sprite.hide()
			continue
		var at: int = slot * FORMAT.ITEM_STRIDE
		var image: int = items[at] * 5
		var texture: Texture2D = actor.textures[images[image]]
		if sprite.texture != texture: sprite.texture = texture
		sprite.region_rect = Rect2(images[image + 1], images[image + 2], images[image + 3], images[image + 4])
		sprite.position = Vector2(items[at + 1], items[at + 2])
		sprite.material = _material(items[at + 3])
		sprite.z_index = items[at + 4]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE if items[at + 5] == FORMAT.FILTER_INHERIT else items[at + 5] as CanvasItem.TextureFilter
		var color: int = items[at + 6] * 4
		sprite.modulate = Color(colors[color], colors[color + 1], colors[color + 2], colors[color + 3])
		sprite.show()

## --- Effect action domains -------------------------------------------------
## The installed 523 bank manifest has no source_action_domains, which the
## effect selection requires (every effect was rejected: 2,165 requests).
## The cook run derives them once from the same pinned pack's own evidence
## (bank/action-outcomes.jsonl.gz + source-family-scan-failures.jsonl.gz: every
## effective SPR action with or without compiled frames, except the 602
## actions the pack records without any target address) and ships them in the
## pinned cooked pack. current523_source_effect_selection.gd reads them from
## here instead of parsing the ~45 MB bank manifest.
const EFFECT_INDEX := "effects/effect_index.bin"
const EFFECT_INDEX_FORMAT := "twilight-cooked-effect-index-v1"
const EFFECT_DOMAIN_BASIS := "cook_time_effective_SPR_actions_from_pack_evidence;602_unaddressed_actions_absent"
static var _effect_index: Dictionary = {}
static var _effect_index_root: String = "-"

static func effect_index(manifest_sha: String) -> Dictionary:
	var folder: String = root()
	if folder != _effect_index_root:
		_effect_index_root = folder
		_effect_index = {}
		var path: String = folder.path_join(EFFECT_INDEX)
		if not folder.is_empty() and FileAccess.file_exists(path) and FileAccess.get_size(path) < 64 * 1024 * 1024:
			var value: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path).decompress_dynamic(256 * 1024 * 1024, FileAccess.COMPRESSION_ZSTD))
			if value is Dictionary and value.get("format") == EFFECT_INDEX_FORMAT and value.get("domains") is Dictionary and value.get("compiled") is Dictionary and value.get("excluded") is Dictionary: _effect_index = value
	if _effect_index.is_empty() or str(_effect_index.get("manifest_sha256", "")) != manifest_sha.to_lower(): return {}
	return _effect_index

static func write_effect_index(path: String, index: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(var_to_bytes(index).compress(FileAccess.COMPRESSION_ZSTD))
	file.close()
	return OK
