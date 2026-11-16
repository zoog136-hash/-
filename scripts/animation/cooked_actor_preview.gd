extends Node2D
## Plays one cooked actor (cooked_actor_store.gd) with the part of the
## original_source_preview.gd API that current523_source_bank_view.gd uses:
## installed(), _playback_tracks, source_playback_mode(), attachment_status(),
## advance_reference_source(), restart_reference_source(), last_source_frame,
## reference_bank_status, reference_source_frame_status().
##
## Frame selection is the original preview's (_advance_selected_source):
## the same clock, loop/one-shot rule, boundary epsilon and durations; the
## sub-frame segments recorded at cook time follow independent source children.
## A frame is one recorded draw state: one Sprite2D per item (page texture +
## region, offset, z, filter, blend, modulate) in the recorded draw order.
## No SP2 parsing, compositing or original-byte check happens here.
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
const PRESENTATION = preload("res://scripts/animation/source_presentation_policy.gd")

var actor: STORE.CookedActor = null
var _playback_tracks: Dictionary = {}
var reference_bank_status: Dictionary = {}
var source_selection_status: Dictionary = {}
var source_effect_status: Dictionary = {}
var _reference_request_context: Dictionary = {}
var _reference_card_context: Dictionary = {}
var cached_frames: bool = true
var last_source_frame: int = -1
var source_facing: int = 0
var _role: String = "idle"
var _clock: float = 0.0
var _sequence: int = -1
var _state: int = -1
var _sprites: Array[Sprite2D] = []
var _direction: int = 0
static var _materials: Dictionary = {}

func configure_cooked(cooked: STORE.CookedActor, initial_role: String) -> bool:
	if cooked == null or not cooked.tracks.has(initial_role): return false
	actor = cooked
	_playback_tracks = cooked.tracks
	_role = initial_role
	reference_bank_status = {"ok":true,"error":"","purpose":"cooked_actor","format":FORMAT.FORMAT,"key":cooked.key}
	visible = true
	return true

func installed() -> bool:
	return actor != null

func source_playback_mode() -> String:
	return str(actor.index.get("mode", "strict")) if actor != null else "strict"

func attachment_status() -> Dictionary:
	var status: Dictionary = actor.index.get("attachment_status", {}).duplicate(true) if actor != null else {}
	status["cooked_actor"] = true
	return status

func cached_frame_status() -> Dictionary:
	return {"active":actor != null,"cooked":true,"state":_state}

func _load_reference_overlay_bindings(_selection: Dictionary) -> void:
	pass

func notify_current_source_spell_event(_spell: Dictionary, _stage: String, _point: Vector2, _facing: int, _context: Dictionary = {}) -> bool:
	return false

func restart_reference_source(explicit_role: String, sequence: int) -> bool:
	if actor == null or not _playback_tracks.has(explicit_role): return false
	_role = explicit_role
	_sequence = sequence
	_clock = 0.0
	return true

func reference_source_frame_status() -> Dictionary:
	if actor == null: return {}
	var track: Dictionary = _playback_tracks.get(_role, {})
	return {"purpose":"cooked_actor","consumer":str(actor.index.get("inputs", {}).get("consumer", "")),"request_key":actor.key,"role":_role,
		"source_action_id":track.get("source_action_id"),"source_actor_id":track.get("source_sprite_id"),"stored_direction":_direction,
		"source_frame":last_source_frame,"cooked_state":_state,"format":FORMAT.FORMAT,"actual_observed_original_bytes":null,"M_visual_equivalence_verified":false}

func advance_reference_source(delta: float, explicit_role: String, stored_direction: int) -> bool:
	if actor == null or not _playback_tracks.has(explicit_role) or stored_direction < 0 or stored_direction > 7 or not is_finite(delta) or delta < 0.0: return false
	if explicit_role != _role:
		_role = explicit_role
		_clock = 0.0
	source_facing = stored_direction
	_direction = stored_direction
	_clock += maxf(0.0, delta)
	var cooked_track: Dictionary = actor.index.tracks[_role]
	var direction: Dictionary = cooked_track.directions[stored_direction]
	var durations: PackedFloat64Array = direction.durations
	var static_track: bool = bool(cooked_track.static_pending_timing)
	var loop: bool = bool(cooked_track.loop)
	var total: float = 1.0
	if not static_track:
		total = 0.0
		for value: float in durations: total += value
	# Same selection as original_source_preview.gd _advance_selected_source().
	var time: float = fmod(_clock, total) if loop else minf(_clock, total)
	var epsilon: float = 0.000000001 if bool(direction.get("eps", false)) else 0.0
	if loop and total - time <= epsilon: time = 0.0
	var selected: int = 0 if static_track else durations.size() - 1
	if not static_track:
		for index: int in range(durations.size()):
			if time + epsilon < durations[index]:
				selected = index
				break
			time -= durations[index]
	last_source_frame = direction.source_frames[selected]
	var state: int = -1
	if not static_track and not loop and _clock >= total:
		state = int(direction.end_state)
	else:
		var first: int = direction.seg_start[selected]
		var last: int = direction.seg_start[selected + 1]
		for segment: int in range(first, last):
			state = direction.seg_state[segment]
			if time < direction.seg_end[segment]: break
		if state < 0: state = int(direction.end_state)
	if state < 0: return false
	if state != _state: _apply(state)
	return true

static func _material(blend: int) -> CanvasItemMaterial:
	if blend == CanvasItemMaterial.BLEND_MODE_MIX: return null
	if not _materials.has(blend):
		var material := CanvasItemMaterial.new()
		material.blend_mode = blend
		_materials[blend] = material
	return _materials[blend]

func _apply(state: int) -> void:
	_state = state
	var items: PackedInt32Array = actor.index.states[state]
	var images: PackedInt32Array = actor.index.images
	var count: int = items.size() / FORMAT.ITEM_STRIDE
	while _sprites.size() < count:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_filter_clip_enabled = true
		add_child(sprite)
		_sprites.append(sprite)
	for slot: int in range(_sprites.size()):
		var sprite: Sprite2D = _sprites[slot]
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
		var colors: PackedFloat32Array = actor.index.colors
		var color: int = items[at + 6] * 4
		sprite.modulate = Color(colors[color], colors[color + 1], colors[color + 2], colors[color + 3])
		sprite.show()
