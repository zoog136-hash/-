extends RefCounted
## Build-time capture for cooked_actor_format.gd (tools/cook/cook_actors.gd and
## tests only; never used by the game at runtime).
##
## A configured original_source_preview.gd (the exact runtime renderer, its
## pinned bank, member verification and styles) is stepped through every role,
## stored direction and source frame. At each time sample the sprites the
## preview subtree draws are collected in canvas draw order (z, then tree
## order) with their pixels, offset, blend mode, modulate and filter. Samples
## are taken at the middle of every interval between frame boundaries of the
## preview and of its independent source children, so nothing that changes
## during playback is skipped. Pixels therefore come only from bytes the bank
## verified during this capture (cook-time verification).
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
const PRESENTATION = preload("res://scripts/animation/source_presentation_policy.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")

static func fail(reason: String) -> Dictionary:
	return {"ok":false,"error":reason}

## Visible sprites of `preview`'s subtree in draw order. Each item:
## {image (RGBA8), position (Vector2i, top-left relative to preview), blend,
##  z, filter, color}. {ok:false} for anything the cooked player cannot draw
## identically (shader materials, rotation/scale, flips, behind-parent).
static func capture(preview: Node2D) -> Dictionary:
	var items: Array = []
	var order: Array = [0]
	var inverse: Transform2D = preview.get_global_transform().affine_inverse()
	var problem: String = _collect(preview, preview, inverse, 0, Color.WHITE, FORMAT.FILTER_INHERIT, items, order)
	if not problem.is_empty(): return fail(problem)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z < b.z or (a.z == b.z and a.order < b.order))
	return {"ok":true,"items":items}

static func _collect(owner: Node2D, node: Node, inverse: Transform2D, z: int, color: Color, filter: int, out: Array, order: Array) -> String:
	for child: Node in node.get_children():
		if child is BackBufferCopy:
			if (child as BackBufferCopy).copy_mode != BackBufferCopy.COPY_MODE_DISABLED: return "cooked_capture_backbuffer_copy"
			continue
		if not child is CanvasItem: continue
		var item: CanvasItem = child
		if not item.visible: continue
		if item.top_level or not item.z_as_relative or item.show_behind_parent or item.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED: return "cooked_capture_unsupported_canvas_item"
		var item_z: int = z + item.z_index
		var item_color: Color = color * item.modulate
		var item_filter: int = filter if item.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE else int(item.texture_filter)
		order[0] += 1
		if item.material != null and not item.material is CanvasItemMaterial: return "cooked_capture_shader_material"
		if item is Sprite2D:
			var sprite: Sprite2D = item
			if sprite.texture != null:
				if sprite.flip_h or sprite.flip_v or sprite.hframes != 1 or sprite.vframes != 1: return "cooked_capture_sprite_frames"
				var xform: Transform2D = inverse * sprite.get_global_transform()
				if not xform.x.is_equal_approx(Vector2.RIGHT) or not xform.y.is_equal_approx(Vector2.DOWN): return "cooked_capture_transform"
				var rect: Rect2 = sprite.get_rect()
				var at: Vector2 = xform * rect.position
				if at != at.round(): return "cooked_capture_fractional_position"
				var image: Image = sprite.texture.get_image()
				if image == null or image.is_empty(): return "cooked_capture_image_unavailable"
				if image.is_compressed(): image.decompress()
				if image.get_format() != Image.FORMAT_RGBA8:
					image = image.duplicate() as Image
					image.convert(Image.FORMAT_RGBA8)
				if sprite.region_enabled: image = image.get_region(Rect2i(sprite.region_rect))
				if Vector2(image.get_size()) != rect.size: return "cooked_capture_size"
				var material: CanvasItemMaterial = _effective_material(sprite, owner)
				if material != null and material.light_mode != CanvasItemMaterial.LIGHT_MODE_NORMAL: return "cooked_capture_light_mode"
				out.append({"image":image,"position":Vector2i(at),"blend":int(material.blend_mode) if material != null else CanvasItemMaterial.BLEND_MODE_MIX,
					"z":item_z,"filter":item_filter,"color":item_color * sprite.self_modulate,"order":order[0]})
		var problem: String = _collect(owner, child, inverse, item_z, item_color, item_filter, out, order)
		if not problem.is_empty(): return problem
	return ""

static func _effective_material(item: CanvasItem, owner: Node2D) -> CanvasItemMaterial:
	var node: CanvasItem = item
	while node != null and node.use_parent_material and node != owner:
		node = node.get_parent() as CanvasItem
	if node == null or node == owner: return null
	return node.material as CanvasItemMaterial

static func _binary_alpha(image: Image) -> bool:
	return image.detect_alpha() != Image.ALPHA_BLEND

## Merges runs of MIX / white / binary-alpha items of one z and filter into
## one image, as actor_frame_composite_cache.gd composes a draw group.
static func merge(items: Array) -> Array:
	var out: Array = []
	var run: Array = []
	for item: Dictionary in items:
		var mergeable: bool = item.blend == CanvasItemMaterial.BLEND_MODE_MIX and item.color == Color.WHITE and _binary_alpha(item.image)
		if mergeable and not run.is_empty() and run[0].z == item.z and run[0].filter == item.filter:
			run.append(item)
			continue
		_flush(run, out)
		run = []
		if mergeable: run.append(item)
		else: out.append(item)
	_flush(run, out)
	return out

static func _flush(run: Array, out: Array) -> void:
	if run.is_empty(): return
	if run.size() == 1:
		out.append(run[0])
		return
	var union := Rect2i(run[0].position, run[0].image.get_size())
	for item: Dictionary in run: union = union.merge(Rect2i(item.position, item.image.get_size()))
	var image := Image.create_empty(union.size.x, union.size.y, false, Image.FORMAT_RGBA8)
	for item: Dictionary in run:
		image.blit_rect_mask(item.image, item.image, Rect2i(Vector2i.ZERO, item.image.get_size()), item.position - union.position)
	out.append({"image":image,"position":union.position,"blend":CanvasItemMaterial.BLEND_MODE_MIX,"z":run[0].z,"filter":run[0].filter,"color":Color.WHITE,"merged":run.size()})

static func image_key(image: Image) -> String:
	return "%dx%d:%s" % [image.get_width(), image.get_height(), _sha(image.get_data())]

static func _sha(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()

class Session:
	extends RefCounted
	var images: Array = [] # Image
	var image_ids: Dictionary = {} # key -> id
	var image_class: Array = [] # PAGE_ETC2 / PAGE_RGBA8
	var states: Array = [] # PackedInt32Array
	var state_ids: Dictionary = {}
	var samples: int = 0
	var merged_items: int = 0
	var colors := PackedFloat32Array()
	var color_ids: Dictionary = {}

static func _state_id(session: Session, items: Array, lossless: bool) -> int:
	var ints := PackedInt32Array()
	for item: Dictionary in items:
		var opaque: bool = item.blend == CanvasItemMaterial.BLEND_MODE_MIX and item.color == Color.WHITE and _binary_alpha(item.image)
		var page_class: String = FORMAT.PAGE_ETC2 if opaque and not lossless else FORMAT.PAGE_RGBA8
		var key: String = image_key(item.image) + ":" + page_class
		var id: int = int(session.image_ids.get(key, -1))
		if id < 0:
			id = session.images.size()
			session.images.append(item.image)
			session.image_class.append(page_class)
			session.image_ids[key] = id
		session.merged_items += int(item.get("merged", 1))
		var color: Color = item.color
		var color_key: String = var_to_str(color)
		if not session.color_ids.has(color_key):
			session.color_ids[color_key] = session.colors.size() / 4
			session.colors.append_array([color.r, color.g, color.b, color.a])
		ints.append_array([id, item.position.x, item.position.y, int(item.blend), int(item.z), int(item.filter), int(session.color_ids[color_key]), 0])
	var signature: String = ints.to_byte_array().hex_encode()
	if session.state_ids.has(signature): return int(session.state_ids[signature])
	session.state_ids[signature] = session.states.size()
	session.states.append(ints)
	return session.states.size() - 1


## Total duration and cumulative boundaries of one direction's frames.
static func _boundaries(frames: Array, loop: bool, total_limit: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var total: float = 0.0
	for frame: Dictionary in frames: total += PRESENTATION.duration(frame)
	if total <= 0.0: return out
	var start: float = 0.0
	while start < total_limit:
		var at: float = start
		for frame: Dictionary in frames:
			at += PRESENTATION.duration(frame)
			if at < total_limit: out.append(at)
		if not loop: break
		start += total
	return out

## Steps one configured preview through all its tracks. `inputs` is the
## selection the runtime must match (stored as-is). Returns {ok, index, images,
## image_class, stats} or {ok:false,error}.
static func cook_preview(preview: Node2D, inputs: Dictionary, lossless: bool = false, resolved: Dictionary = {}) -> Dictionary:
	var session := Session.new()
	var tracks_out: Dictionary = {}
	var sequence: int = 1000000
	var roles: Array = preview._playback_tracks.keys()
	roles.sort()
	var resampled: int = 0
	for role: String in roles:
		var track: Dictionary = preview._playback_tracks[role]
		var static_track: bool = bool(track.get("static_pending_timing", false))
		var loop: bool = bool(track.get("loop", false))
		var directions_out: Array = []
		if track.get("directions", []).size() != 8: return fail("cooked_track_directions:" + role)
		for direction: int in range(8):
			var frames: Array = track.directions[direction]
			if frames.is_empty(): return fail("cooked_track_frames:" + role)
			var durations := PackedFloat64Array()
			var source_frames := PackedInt32Array()
			var source_groups := PackedInt32Array()
			var starts := PackedFloat64Array()
			var total: float = 0.0
			for frame: Dictionary in frames:
				starts.append(total)
				durations.append(PRESENTATION.duration(frame))
				total += PRESENTATION.duration(frame)
				source_frames.append(int(frame.get("source_frame", -1)))
				source_groups.append(int(frame.get("source_group", -1)))
			sequence += 1
			preview.restart_reference_source(role, sequence)
			if not preview.advance_reference_source(0.0, role, direction): return fail("cooked_advance:" + str(preview.reference_bank_status.get("error", role)))
			var cuts: Dictionary = {}
			var seg_start := PackedInt32Array()
			var seg_end := PackedFloat64Array()
			var seg_state := PackedInt32Array()
			if static_track or total <= 0.0:
				var captured: Dictionary = capture(preview)
				if not captured.ok: return captured
				session.samples += 1
				for _index: int in range(frames.size()):
					seg_start.append(seg_state.size())
					seg_end.append(INF)
					seg_state.append(_state_id(session, merge(captured.items), lossless))
				seg_start.append(seg_state.size())
			else:
				for at: float in _boundaries(frames, false, total): cuts[at] = true
				for child: Variant in preview._reference_source_children.values():
					if not is_instance_valid(child): continue
					var child_track: Dictionary = child._playback_tracks.get("source_layer", {})
					if child_track.is_empty() or bool(child_track.get("static_pending_timing", false)): continue
					var child_frames: Array = child_track.directions[direction]
					var child_total: float = 0.0
					for frame: Dictionary in child_frames: child_total += PRESENTATION.duration(frame)
					if loop and child_total > 0.0 and not is_zero_approx(fmod(total, child_total)) and not is_equal_approx(fmod(total, child_total), child_total): resampled += 1
					for at: float in _boundaries(child_frames, loop, total): cuts[at] = true
				var points: Array = cuts.keys()
				points.append(0.0)
				points.append(total)
				points.sort()
				var clock: float = 0.0
				var frame_index: int = 0
				seg_start.append(0)
				for index: int in range(points.size() - 1):
					var a: float = points[index]
					var b: float = points[index + 1]
					if b - a <= 0.0000001: continue
					var middle: float = (a + b) * 0.5
					while frame_index < frames.size() - 1 and middle >= starts[frame_index] + durations[frame_index]:
						frame_index += 1
						seg_start.append(seg_state.size())
					if not preview.advance_reference_source(middle - clock, role, direction): return fail("cooked_advance:" + str(preview.reference_bank_status.get("error", role)))
					clock = middle
					var captured: Dictionary = capture(preview)
					if not captured.ok: return captured
					session.samples += 1
					var state: int = _state_id(session, merge(captured.items), lossless)
					var end: float = b - starts[frame_index]
					if seg_state.size() > seg_start[frame_index] and seg_state[-1] == state:
						seg_end[-1] = end
					else:
						seg_end.append(end)
						seg_state.append(state)
				while seg_start.size() < frames.size() + 1: seg_start.append(seg_state.size())
			# What a finished one-shot holds (clock at or past the end).
			var end_state: int = -1
			if not static_track and total > 0.0 and not loop:
				var current: float = float(preview._clock)
				if not preview.advance_reference_source(maxf(0.0, total - current) + 0.001, role, direction): return fail("cooked_advance:" + str(preview.reference_bank_status.get("error", role)))
				var held: Dictionary = capture(preview)
				if not held.ok: return held
				session.samples += 1
				end_state = _state_id(session, merge(held.items), lossless)
			elif not seg_state.is_empty():
				end_state = seg_state[0]
			directions_out.append({"end_state":end_state,"durations":durations,"source_frames":source_frames,"source_groups":source_groups,
				"seg_start":seg_start,"seg_end":seg_end,"seg_state":seg_state,"eps":frames[0].has("presentation_duration")})
		tracks_out[role] = {"loop":loop,"static_pending_timing":static_track,"fps":track.get("fps"),"effective_fps":track.get("effective_fps"),
			"timing_origin":track.get("timing_origin"),"source_action_id":track.get("source_action_id"),"source_sprite_id":track.get("source_sprite_id"),"directions":directions_out}
	var index: Dictionary = {"key":str(inputs.get("key","")),"inputs":inputs.duplicate(true),"resolved_selection":resolved.duplicate(true),"mode":preview.source_playback_mode(),
		"screen_copy":COMPOSITOR.screen_copy_available,"tracks":tracks_out,"attachment_status":preview.attachment_status(),
		"states":session.states,"colors":session.colors,"stats":{"samples":session.samples,"states":session.states.size(),"images":session.images.size(),"merged_layers":session.merged_items,"resampled_child_tracks":resampled}}
	return {"ok":true,"index":index,"images":session.images,"image_class":session.image_class}

## Packs captured images into pages and writes the cooked actor file.
## `compress`: Image.COMPRESS_* for opaque pages, or -1 for RGBA8 everywhere.
static func write_cooked(path: String, cooked: Dictionary, compress: int) -> Dictionary:
	var index: Dictionary = cooked.index.duplicate()
	var classes: Array = [FORMAT.PAGE_ETC2, FORMAT.PAGE_RGBA8]
	var image_table := PackedInt32Array()
	image_table.resize(cooked.images.size() * 5)
	var pages: Array = []
	var page_classes: Array = []
	for page_class: String in classes:
		var members: Array = []
		var sizes: Array = []
		for id: int in range(cooked.images.size()):
			if cooked.image_class[id] != page_class: continue
			members.append(id)
			sizes.append(cooked.images[id].get_size())
		if members.is_empty(): continue
		var packed: Dictionary = FORMAT.pack(sizes)
		var first: int = pages.size()
		for size: Vector2i in packed.pages:
			var page := Image.create_empty(FORMAT.pad4(size.x), FORMAT.pad4(size.y), false, Image.FORMAT_RGBA8)
			pages.append(page)
			page_classes.append(page_class)
		for slot: int in range(members.size()):
			var id: int = members[slot]
			var place: Array = packed.placements[slot]
			var image: Image = cooked.images[id]
			pages[first + int(place[0])].blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(int(place[1]), int(place[2])))
			var at: int = id * 5
			image_table[at] = first + int(place[0])
			image_table[at + 1] = int(place[1])
			image_table[at + 2] = int(place[2])
			image_table[at + 3] = image.get_width()
			image_table[at + 4] = image.get_height()
	var page_bytes: int = 0
	for page_index: int in range(pages.size()):
		var page: Image = pages[page_index]
		if page_classes[page_index] == FORMAT.PAGE_ETC2 and compress >= 0:
			page.fix_alpha_edges()
			if page.compress(compress, Image.COMPRESS_SOURCE_GENERIC) != OK or not page.is_compressed(): return fail("cooked_page_compress")
		page_bytes += page.get_data_size()
	index["images"] = image_table
	index["page_classes"] = page_classes
	index["stats"] = cooked.index.stats.duplicate()
	index.stats["pages"] = pages.size()
	index.stats["gpu_bytes"] = page_bytes
	var written: Dictionary = FORMAT.write(path, index, pages)
	if written.ok: written["gpu_bytes"] = page_bytes
	return written

## Real-data check used by the cook run: steps a fresh runtime preview and the
## cooked preview of the written file together and compares what they draw.
## Structure (count, offsets, sizes, blend, z, filter, modulate) and source
## frame must be identical, RGBA8 items byte-identical; ETC2 items report their
## largest channel error and PSNR (lossy by design, user-approved).
static func verify(runtime: Node2D, cooked: Node2D, steps: Array) -> Dictionary:
	var result: Dictionary = {"ok":true,"steps":0,"items":0,"exact_items":0,"etc2_items":0,"etc2_max_error":0,"etc2_squared":0.0,"etc2_samples":0,"problems":[]}
	for step: Array in steps:
		var a: bool = runtime.advance_reference_source(step[0], step[1], step[2])
		var b: bool = cooked.advance_reference_source(step[0], step[1], step[2])
		result.steps += 1
		if not (a and b) or runtime.last_source_frame != cooked.last_source_frame:
			result.problems.append("frame %s: %s/%s %d/%d" % [str(step), str(a), str(b), runtime.last_source_frame, cooked.last_source_frame])
			continue
		var left: Dictionary = capture(runtime)
		var right: Dictionary = capture(cooked)
		if not left.ok or not right.ok:
			result.problems.append("capture %s" % str(step))
			continue
		var expected: Array = merge(left.items)
		var shown: Array = right.items
		if expected.size() != shown.size():
			result.problems.append("items %s: %d/%d" % [str(step), expected.size(), shown.size()])
			continue
		for index: int in range(expected.size()):
			var e: Dictionary = expected[index]
			var s: Dictionary = shown[index]
			result.items += 1
			if e.position != s.position or e.image.get_size() != s.image.get_size() or e.blend != s.blend or e.z != s.z or e.filter != s.filter or e.color != s.color:
				result.problems.append("item %s #%d differs" % [str(step), index])
				continue
			if e.image.get_data() == s.image.get_data():
				result.exact_items += 1
				continue
			var opaque: bool = e.blend == CanvasItemMaterial.BLEND_MODE_MIX and e.color == Color.WHITE and _binary_alpha(e.image)
			if not opaque:
				result.problems.append("exact item %s #%d pixels differ" % [str(step), index])
				continue
			result.etc2_items += 1
			var left_bytes: PackedByteArray = e.image.get_data()
			var right_bytes: PackedByteArray = s.image.get_data()
			for at: int in range(0, left_bytes.size(), 4):
				if left_bytes[at + 3] == 0 and right_bytes[at + 3] < 8: continue
				for channel: int in range(4):
					var error: int = absi(int(left_bytes[at + channel]) - int(right_bytes[at + channel]))
					result.etc2_max_error = maxi(result.etc2_max_error, error)
					result.etc2_squared += error * error
					result.etc2_samples += 1
	result.ok = result.problems.is_empty()
	if result.etc2_samples > 0:
		var mse: float = result.etc2_squared / float(result.etc2_samples)
		result["etc2_psnr_db"] = 99.0 if mse <= 0.0 else 10.0 * log(255.0 * 255.0 / mse) / log(10.0)
	result.erase("etc2_squared")
	if result.problems.size() > 8: result.problems = result.problems.slice(0, 8)
	return result

## Deterministic verification steps over every role and direction.
static func verify_steps(roles: Array, seed_value: int) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var steps: Array = []
	for role: String in roles:
		for direction: int in range(8):
			steps.append([0.0, role, direction])
			for _index: int in range(3): steps.append([random.randf_range(0.0, 0.4), role, direction])
	return steps
