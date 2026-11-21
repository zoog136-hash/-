extends "res://tests/reference_sp2_asset_sharing_test.gd"
## Cached frame plans + composited draw groups (original_source_preview.gd
## cached_frames, actor_frame_composite_cache.gd). Synthetic SP2 members only
## (hand-made 2x2 frames with transparent texels), written under user://; never
## the private bank and not original-resource or M-visual evidence.
## Headless: draw lists flattened on the CPU (MIX/ADD) are compared with the
## per-layer path. With `-- --render` (xvfb + gl_compatibility) the same scenes
## are also rendered by the GPU and compared pixel for pixel.
const COMPOSITES = preload("res://scripts/resources/actor_frame_composite_cache.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

class CountingBank extends "res://scripts/resources/reference_sp2_bank.gd":
	var validations: int = 0
	var pixel_requests: int = 0
	var rechecks: int = 0
	func render_layer(layer: Dictionary, pixels: bool = true) -> Dictionary:
		validations += 1
		if pixels: pixel_requests += 1
		return super.render_layer(layer, pixels)
	func recheck_layers(stamps: Dictionary) -> Dictionary:
		rechecks += 1
		return super.recheck_layers(stamps)
	func reset_counts() -> void:
		validations = 0
		pixel_requests = 0
		rechecks = 0

var render_checks: int = 0
var timings: Dictionary = {}
var directory: String = ""

## FE SP2 with 2x2 frames in one of three coverage patterns (transparent
## texels inside the frame): full (4 samples), diag and anti (2 samples).
static func make_pattern_sp2(palette: Array, frames: Array) -> PackedByteArray:
	var out := PackedByteArray([254, 4])
	var put16 := func(value: int) -> void:
		out.append(value & 255)
		out.append((value >> 8) & 255)
	for word: int in palette: put16.call(word)
	out.append(1)
	out.append(frames.size())
	for index: int in range(frames.size()):
		for value: int in [0, 0, 2, 2]: put16.call(value)
		put16.call(1)
		out.append_array(PackedByteArray([0, 0, 0]))
		put16.call(index)
	var count := PackedByteArray()
	count.resize(4)
	count.encode_s32(0, frames.size())
	out.append_array(count)
	for frame: Array in frames:
		out.append_array(PackedByteArray([0, 0, 2]))
		match str(frame[0]):
			"full":
				put16.call((2 << 5) | (1 << 10))
				put16.call(2 << 5)
			"diag":
				put16.call((1 << 5) | (1 << 10))
				put16.call(1 | (1 << 5))
			_:
				put16.call(1 | (1 << 5) | (1 << 10))
				put16.call(1 << 5)
	for frame: Array in frames:
		for sample: int in frame[1]: out.append(sample)
	return out

const PATTERNS := ["full", "diag", "anti"]
const SPRITES := {9001:[0xF800,0x07E0,0x001F,0xFFFF], 9002:[0x7BEF,0xFFE0,0xF81F,0x07FF], 9003:[0x8410,0x0410,0x8010,0x0010], 9004:[0xFD20,0x2589,0x9999,0x4208], 9005:[0x1234,0x4321,0xABCD,0xDCBA]}

func write_bank(path_dir: String) -> Dictionary:
	var members: Dictionary = {}
	var raws: Dictionary = {}
	for id: int in SPRITES:
		var frames: Array = []
		for frame: int in range(3):
			var pattern: String = PATTERNS[(frame + id) % 3]
			frames.append([pattern, [(frame + 1) % 4, (frame + 2) % 4, 3, 1] if pattern == "full" else [(frame + id) % 4, (frame + 3) % 4]])
		var member: String = "Sprite/%d-0.sp2" % id
		var raw: String = path_dir.path_join("raw/" + member)
		write_bytes(raw, make_pattern_sp2(SPRITES[id], frames))
		members[member] = member_spec(member, raw)
		raws[id] = raw
	var path: String = path_dir.path_join("manifest.json")
	var sha: String = write_json(path, manifest(SPRITES.keys(), members, "composite_cache"))
	return {"path":path,"sha":sha,"raws":raws}

func base_layer(id: int, kind: String) -> Dictionary:
	return {"kind":kind,"source_sprite_id":id,"group_bit":0,"frame_index":0,"file_sprite_id":id,"member":"Sprite/%d-0.sp2" % id}

func layer(bank: RefCounted, id: int, kind: String, frame: int, offset: Array, attributes: Variant = null) -> Dictionary:
	var made: Dictionary = preview_layer(bank, base_layer(id, kind), frame)
	made.offset = offset
	if attributes is Array: made["source_attributes"] = attributes
	return made

## config: body_attrs, effect_attrs, weapon (sprite id).
func make_track(bank: RefCounted, config: Dictionary) -> Dictionary:
	var directions: Array = []
	for direction: int in range(8):
		var frames: Array = []
		for frame: int in range(3):
			var layers: Array = [layer(bank, 9001, "body", frame, [direction % 3, 0], config.get("body_attrs")), layer(bank, 9002, "clothes", (frame + 1) % 3, [1, 1]), layer(bank, int(config.get("weapon", 9003)), "clothes", frame % 2, [-1, direction % 2])]
			var effects: Array = [layer(bank, 9004, "clothes", frame % 2, [2, -1], config.get("effect_attrs", []))]
			frames.append({"duration":0.1,"source_ticks":1,"source_group":0,"source_frame":frame,"layers":layers,"effect_layers":effects})
		directions.append(frames)
	return {"source_action_id":0,"source_action_key":"composite_probe","source_sprite_id":9001,"loop":true,"directions":directions,"static_pending_timing":false,"timing_origin":"composite_probe"}

func make_view(parent: Node, bank: RefCounted, track: Dictionary, manifest_path: String, cached: bool) -> Node2D:
	var preview: Node2D = PREVIEW.new()
	preview.cached_frames = cached
	parent.add_child(preview)
	preview._root = manifest_path.get_base_dir()
	preview._playback_mode = "compatible"
	preview._reference_bank = bank
	preview._configure_source_nodes({"source_sprite_id":9001}, {"idle":track}, 3, manifest_path)
	preview._role = "idle"
	return preview

func open_bank(info: Dictionary) -> CountingBank:
	var bank := CountingBank.new()
	var opened: Dictionary = bank.load_static(info.path, info.sha, 9001)
	check(opened.get("ok", false), "synthetic bank opens: " + str(opened.get("error", "")))
	return bank

## Visible sprites in draw order (z, then tree order) with their draw state.
func draw_list(preview: Node2D) -> Array:
	var out: Array = []
	var order: Array = [0]
	_collect(preview, 0, out, order)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z < b.z or (a.z == b.z and a.order < b.order))
	return out

func _collect(node: Node, z: int, out: Array, order: Array) -> void:
	for child: Node in node.get_children():
		if not child is CanvasItem or not (child as CanvasItem).visible: continue
		var item_z: int = z + (child as CanvasItem).z_index
		order[0] += 1
		if child is Sprite2D and (child as Sprite2D).texture != null:
			var sprite: Sprite2D = child
			var material: Material = sprite.material
			var blend: Variant = null
			if material is CanvasItemMaterial: blend = (material as CanvasItemMaterial).blend_mode
			elif material is ShaderMaterial: blend = "shader:" + str((material as ShaderMaterial).get_shader_parameter("operation"))
			out.append({"z":item_z,"order":order[0],"image":sprite.texture.get_image(),"position":Vector2i(sprite.position),"blend":blend,"alpha":sprite.modulate.a})
		_collect(child, item_z, out, order)

## CPU oracle of the Canvas draw: MIX and ADD with texture alpha * modulate.a.
func flatten(list: Array, background: Color) -> Image:
	var canvas := Image.create_empty(16, 16, false, Image.FORMAT_RGBAF)
	canvas.fill(background)
	for item: Dictionary in list:
		var image: Image = item.image
		for y: int in image.get_height():
			for x: int in image.get_width():
				var at: Vector2i = Vector2i(x, y) + Vector2i(item.position) + Vector2i(8, 8)
				if at.x < 0 or at.y < 0 or at.x >= 16 or at.y >= 16: continue
				var source: Color = image.get_pixel(x, y)
				var alpha: float = source.a * float(item.alpha)
				var dest: Color = canvas.get_pixelv(at)
				if item.blend == CanvasItemMaterial.BLEND_MODE_ADD:
					dest = Color(dest.r + source.r * alpha, dest.g + source.g * alpha, dest.b + source.b * alpha, 1.0)
				else:
					dest = Color(source.r * alpha + dest.r * (1.0 - alpha), source.g * alpha + dest.g * (1.0 - alpha), source.b * alpha + dest.b * (1.0 - alpha), 1.0)
				canvas.set_pixelv(at, dest)
	return canvas

func max_difference(a: Image, b: Image) -> float:
	var worst: float = 0.0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var left: Color = a.get_pixel(x, y)
			var right: Color = b.get_pixel(x, y)
			worst = maxf(worst, maxf(absf(left.r - right.r), maxf(absf(left.g - right.g), absf(left.b - right.b))))
	return worst

func shader_items(list: Array, shader: bool) -> Array:
	var out: Array = []
	for item: Dictionary in list:
		if str(item.blend).begins_with("shader") == shader: out.append(item)
	return out

func list_signature(list: Array) -> Array:
	var out: Array = []
	for item: Dictionary in list: out.append([image_sha(item.image), item.position, item.blend, item.alpha, item.z])
	return out

## The cached preview draws what the per-layer preview draws.
func same_output(cached: Node2D, plain: Node2D, label: String) -> void:
	var left: Array = draw_list(cached)
	var right: Array = draw_list(plain)
	# Destination-copy shader layers sample what is below them: they must stay
	# identical nodes, and everything else must flatten to identical pixels.
	check(list_signature(shader_items(left, true)) == list_signature(shader_items(right, true)), label + ": shader layers keep identical per-layer nodes")
	for background: Color in [Color(0.2, 0.4, 0.6), Color.WHITE]:
		check(max_difference(flatten(shader_items(left, false), background), flatten(shader_items(right, false), background)) == 0.0, label + ": CPU-flattened pixels equal on " + str(background))
	check(cached.reference_source_frame_status().get("selected_layers") == plain.reference_source_frame_status().get("selected_layers"), label + ": shown source provenance equal")

func steps() -> Array:
	# delta, direction
	return [[0.0, 0], [0.0, 0], [0.05, 0], [0.06, 0], [0.1, 0], [0.0, 3], [0.1, 3], [0.1, 5], [0.31, 5], [0.0, 7], [0.1, 1]]

func run() -> void:
	ASSETS.reset_for_tests()
	COMPOSITES.reset_for_tests()
	BANK.forget_verified_members()
	directory = argument("--data=", "user://actor_frame_composite_%d" % OS.get_process_id())
	var render: bool = "--render" in OS.get_cmdline_user_args()
	if render and DisplayServer.get_name() == "headless":
		check(false, "--render requires an actual renderer")
		render = false
	var info: Dictionary = write_bank(directory.path_join("bank"))
	var previous_copy: bool = COMPOSITOR.screen_copy_available
	# 1. Output equality with the per-layer path, every style family, with and
	#    without the destination copy (Android has none).
	var configs: Array = [
		{"name":"plain","effect_attrs":[]},
		{"name":"effect_add","effect_attrs":["8"]},
		{"name":"effect_half","effect_attrs":["128"]},
		{"name":"body_add","body_attrs":["8"],"effect_attrs":[]},
		{"name":"body_multiply","body_attrs":["128"],"effect_attrs":[]},
		{"name":"strict_hidden_effect","effect_attrs":[],"strict":true},
		{"name":"translucent_actor","effect_attrs":[],"alpha":0.5},
	]
	var expected_modes: Dictionary = {"plain":{"body":"composite","effects":"nodes"},"effect_add":{"body":"composite","effects":"nodes"},"body_add":{"body":"nodes","effects":"nodes"}}
	for copy: bool in [false, true]:
		COMPOSITOR.screen_copy_available = copy
		for config: Dictionary in configs:
			var label: String = "%s copy=%s" % [config.name, str(copy)]
			var bank: CountingBank = open_bank(info)
			var track: Dictionary = make_track(bank, config)
			var cached: Node2D = make_view(root, bank, track, info.path, true)
			var plain: Node2D = make_view(root, bank, track, info.path, false)
			if config.get("strict", false):
				cached._playback_mode = "strict"
				plain._playback_mode = "strict"
			cached.modulate.a = float(config.get("alpha", 1.0))
			plain.modulate.a = cached.modulate.a
			for step: Array in steps():
				var a: bool = cached.advance_reference_source(step[0], "idle", step[1])
				var b: bool = plain.advance_reference_source(step[0], "idle", step[1])
				check(a and b, label + ": both advance " + str(step))
				same_output(cached, plain, label + " step " + str(step))
				if config.has("alpha"): check(list_signature(draw_list(cached)) == list_signature(draw_list(plain)), label + ": translucent nodes identical " + str(step))
			check(cached.cached_frame_status().active, label + ": cached path active")
			if not copy and expected_modes.has(config.name):
				check(cached.cached_frame_status().groups == expected_modes[config.name], label + ": draw group modes " + str(cached.cached_frame_status().groups))
			check(plain.cached_frame_status().active == false, label + ": opt-out preview stays per-layer")
			cached.free()
			plain.free()
	COMPOSITOR.screen_copy_available = false
	# Composite groups really replace their layer nodes with one sprite.
	var bank: CountingBank = open_bank(info)
	var track: Dictionary = make_track(bank, {"effect_attrs":[]})
	var view: Node2D = make_view(root, bank, track, info.path, true)
	check(view.advance_reference_source(0.0, "idle", 0), "composite view advances")
	var visible_layers: int = 0
	for sprite: Sprite2D in view._layers: visible_layers += int(sprite.visible)
	var composite: Sprite2D = view._composite_nodes.get("body")
	check(visible_layers == 0 and composite != null and composite.visible and composite.texture != null, "three body layers draw as one composited sprite")
	check(composite.get_index() < view._layers[0].get_index() and composite.z_index == 0 and composite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "composite keeps the body draw slot, z and filter")
	# A translucent actor (concealment) draws its layers one by one again.
	var translucent_plain: Node2D = make_view(root, bank, track, info.path, false)
	for alpha: float in [0.15, 1.0]:
		view.modulate.a = alpha
		translucent_plain.modulate.a = alpha
		translucent_plain._clock = view._clock
		check(view.advance_reference_source(0.0, "idle", 0) and translucent_plain.advance_reference_source(0.0, "idle", 0), "translucency %f advances" % alpha)
		var layers_shown: int = 0
		for sprite: Sprite2D in view._layers: layers_shown += int(sprite.visible)
		if alpha < 1.0:
			check(not view._composite_nodes.body.visible and layers_shown == 3 and view.cached_frame_status().translucent, "translucent actor keeps per-layer nodes")
			check(list_signature(draw_list(view)) == list_signature(draw_list(translucent_plain)), "translucent actor draws the per-layer path's nodes")
		else:
			check(view._composite_nodes.body.visible and layers_shown == 0, "opaque again: composite restored")
			same_output(view, translucent_plain, "opaque after translucency")
	translucent_plain.free()
	# 2. A planned frame skips the per-layer work; its recheck runs once per advance.
	bank.reset_counts()
	for index: int in range(10): check(view.advance_reference_source(0.0, "idle", 0), "warm advance %d" % index)
	check(bank.validations == 0 and bank.pixel_requests == 0 and bank.rechecks == 10, "warm frame: no render_layer, one recheck per advance: " + str([bank.validations, bank.pixel_requests, bank.rechecks]))
	# Revisiting an already planned frame also costs one recheck only.
	view.advance_reference_source(0.1, "idle", 0)
	bank.reset_counts()
	view.advance_reference_source(0.2, "idle", 0) # back to frame 0 (loop 0.3 s)
	check(bank.validations == 0 and bank.rechecks == 1, "revisited planned frame: one recheck, no layer work")
	# Another actor with the same frame shares the composite (no pixel decode).
	var other_bank: CountingBank = open_bank(info)
	var other: Node2D = make_view(root, other_bank, make_track(other_bank, {"effect_attrs":[]}), info.path, true)
	var stored_before: int = int(COMPOSITES.stats().counters.get("stored", 0))
	other_bank.reset_counts()
	check(other.advance_reference_source(0.0, "idle", 0), "second actor advances")
	check(other_bank.pixel_requests == 0 and int(COMPOSITES.stats().counters.get("stored", 0)) == stored_before, "second actor reuses the shared composite without decoding")
	# 4 planning verifications + 1 for the single effect layer's shared texture.
	check(other_bank.validations == 5, "second actor still verifies each of its layers when planning: " + str(other_bank.validations))
	check(is_same(other._composite_nodes.body.texture, view._composite_nodes.body.texture) or image_sha(other._composite_nodes.body.texture.get_image()) == image_sha(view._composite_nodes.body.texture.get_image()), "shared composite pixels")
	other.free()
	# 3. Invalidation: frame, direction and equipment produce other composites.
	var keys: Dictionary = {}
	view._clock = 0.0
	for step: Array in [[0.0, 0], [0.15, 0], [0.0, 4], [0.1, 4]]:
		view.advance_reference_source(step[0], "idle", step[1])
		keys[image_sha(view._composite_nodes.body.texture.get_image()) + str(view._composite_nodes.body.position)] = [view.last_source_frame, step]
	check(keys.size() == 4, "frame and direction changes show four distinct composites: " + str(keys.values()))
	var plain_view: Node2D = make_view(root, bank, track, info.path, false)
	plain_view._clock = view._clock
	plain_view.advance_reference_source(0.0, "idle", 4)
	same_output(view, plain_view, "after direction/frame changes")
	plain_view.free()
	var weapon_b: Dictionary = make_track(bank, {"effect_attrs":[],"weapon":9005})
	var swapped: Node2D = make_view(root, bank, weapon_b, info.path, true)
	var swapped_plain: Node2D = make_view(root, bank, weapon_b, info.path, false)
	var stored: int = int(COMPOSITES.stats().counters.get("stored", 0))
	swapped.advance_reference_source(0.0, "idle", 0)
	swapped_plain.advance_reference_source(0.0, "idle", 0)
	check(int(COMPOSITES.stats().counters.get("stored", 0)) == stored + 1, "equipment change builds its own composite")
	same_output(swapped, swapped_plain, "equipment change")
	swapped.free(); swapped_plain.free()
	view.free()
	# 4. LRU byte budget.
	COMPOSITES.reset_for_tests()
	var lru_bank: CountingBank = open_bank(info)
	var lru: Node2D = make_view(root, lru_bank, make_track(lru_bank, {"effect_attrs":[]}), info.path, true)
	lru.advance_reference_source(0.0, "idle", 0)
	var one: int = int(COMPOSITES.stats().bytes)
	COMPOSITES.budget_bytes = one * 3
	var over_budget: bool = false
	for direction: int in range(8):
		for frame: int in range(3):
			lru.advance_reference_source(0.1, "idle", direction)
			if int(COMPOSITES.stats().bytes) > COMPOSITES.budget_bytes: over_budget = true
	var stats: Dictionary = COMPOSITES.stats()
	check(not over_budget and int(stats.entries) <= 3 and int(stats.counters.get("evicted", 0)) > 0, "composite store stays within its byte budget: " + JSON.stringify(stats))
	# An evicted frame is rebuilt from verified pixels and still matches.
	lru_bank.reset_counts()
	var lru_plain: Node2D = make_view(root, lru_bank, lru._playback_tracks.idle, info.path, false)
	lru._clock = 0.0
	lru.advance_reference_source(0.0, "idle", 0)
	check(lru_bank.pixel_requests == 3, "evicted composite rebuilt from three verified layer renders: " + str(lru_bank.pixel_requests))
	lru_plain.advance_reference_source(0.0, "idle", 0)
	same_output(lru, lru_plain, "rebuilt after eviction")
	lru.free(); lru_plain.free()
	COMPOSITES.reset_for_tests()
	# 5. Integrity: a cached frame still rejects changed or deleted originals
	#    and a changed manifest on the very next advance.
	for mutation: String in ["changed_size", "deleted", "same_size_bytes", "manifest", "hidden_effect_member"]:
		var trial_info: Dictionary = write_bank(directory.path_join("trial_" + mutation))
		BANK.forget_verified_members()
		var trial_bank: CountingBank = open_bank(trial_info)
		var trial: Node2D = make_view(root, trial_bank, make_track(trial_bank, {"effect_attrs":["999"] if mutation == "hidden_effect_member" else []}), trial_info.path, true)
		if mutation == "deleted": trial.use_companion_frame_plans()
		check(trial.advance_reference_source(0.0, "idle", 0) and trial.advance_reference_source(0.0, "idle", 0), mutation + ": warm cached frame")
		var target: String = trial_info.raws[9004 if mutation == "hidden_effect_member" else 9002]
		match mutation:
			"changed_size": write_bytes(target, FileAccess.get_file_as_bytes(target) + PackedByteArray([0]))
			"deleted": DirAccess.remove_absolute(target)
			"same_size_bytes", "hidden_effect_member":
				var bytes: PackedByteArray = FileAccess.get_file_as_bytes(target)
				bytes[-1] = (bytes[-1] + 1) % 4
				write_bytes(target, bytes)
				# Same second, same size: the stamp alone cannot see it (existing
				# bank policy). Drop the stamp as a new modification time would.
				BANK._verified_members.erase(target)
			"manifest":
				var text: String = FileAccess.get_file_as_string(trial_info.path)
				write_bytes(trial_info.path, (text + " ").to_utf8_buffer())
		# Successful file checks are shared within one rendered frame; the
		# change is rejected by the first advance of the next frame.
		var frame: int = Engine.get_process_frames()
		while Engine.get_process_frames() == frame: await process_frame
		check(not trial.advance_reference_source(0.0, "idle", 0), mutation + ": next frame's advance rejects")
		check(trial._reference_bank == null and trial._layers.is_empty() and trial._composite_nodes.is_empty(), mutation + ": rejection releases the actor's frame state")
		check(not str(trial.reference_bank_status.get("error", "")).is_empty(), mutation + ": rejection reason kept: " + str(trial.reference_bank_status.get("error", "")))
		trial.free()
	# Texture budgets keep the per-layer path.
	BANK.forget_verified_members()
	var budget_bank: CountingBank = open_bank(info)
	var budgeted: Node2D = make_view(root, budget_bank, make_track(budget_bank, {"effect_attrs":[]}), info.path, true)
	budgeted._reference_texture_budget = {"limit":1024 * 1024, "used":0}
	check(budgeted.advance_reference_source(0.0, "idle", 0) and not budgeted.cached_frame_status().active, "texture-budgeted effect owner keeps the per-layer path")
	budgeted.free()
	var companion_bank: CountingBank = open_bank(info)
	var companion_track: Dictionary = make_track(companion_bank, {"effect_attrs":["8"]})
	var companion: Node2D = make_view(root, companion_bank, companion_track, info.path, false)
	var per_layer: Node2D = make_view(root, companion_bank, companion_track, info.path, false)
	companion.use_companion_frame_plans()
	for direction: int in 8:
		for _frame: int in 3:
			check(companion.advance_reference_source(0.1,"idle",direction) and per_layer.advance_reference_source(0.1,"idle",direction), "companion preserves playback")
			same_output(companion, per_layer, "companion direction %d" % direction)
	check(companion.cached_frame_status().plans == 16, "companion plans stay at their own cap")
	check(companion.cached_frame_status().groups == {"body":"nodes","effects":"nodes"} and companion._composite_nodes.is_empty(), "companion keeps layer textures without composite uploads")
	companion_bank.reset_counts()
	check(companion.advance_reference_source(0.0,"idle",7) and companion_bank.rechecks == 1 and companion_bank.validations == 0, "warm companion pose uses the existing pin/member recheck")
	companion.free()
	per_layer.free()
	# 6. CPU per advance (synthetic, this machine; phone ~30-60x slower).
	measure(info)
	# 7. GPU pixels (gl_compatibility) for every config.
	if render:
		for copy: bool in [false, true]:
			COMPOSITOR.screen_copy_available = copy
			for config: Dictionary in configs:
				await gpu_compare(info, config, copy)
			await gpu_compare(info, {"name":"companion","effect_attrs":["8"]}, copy, true)
	COMPOSITOR.screen_copy_available = previous_copy
	print("ACTOR_FRAME_COMPOSITE_CACHE_RESULT " + JSON.stringify({"checks":checks,"render_checks":render_checks,"failures":failures,"timings_usec_per_advance":timings,"cache":COMPOSITES.stats(),"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)

func measure(info: Dictionary) -> void:
	COMPOSITOR.screen_copy_available = false
	for config: Dictionary in [{"name":"plain","effect_attrs":[]}, {"name":"effect_add","effect_attrs":["8"]}]:
		for cached: bool in [false, true]:
			var bank: CountingBank = open_bank(info)
			var view: Node2D = make_view(root, bank, make_track(bank, config), info.path, cached)
			# Warm: every frame of direction 0 planned / textured once.
			for index: int in range(4): view.advance_reference_source(0.1, "idle", 0)
			var count: int = 400
			var started: int = Time.get_ticks_usec()
			for index: int in range(count): view.advance_reference_source(0.0, "idle", 0)
			var same: float = float(Time.get_ticks_usec() - started) / count
			started = Time.get_ticks_usec()
			for index: int in range(count): view.advance_reference_source(0.1, "idle", 0)
			var changing: float = float(Time.get_ticks_usec() - started) / count
			# One actor per rendered frame: no other actor shared this frame's
			# file checks (the per-frame memo is emptied before each advance).
			started = Time.get_ticks_usec()
			for index: int in range(count):
				BANK._recheck_ok.clear()
				view.advance_reference_source(0.0, "idle", 0)
			var cold: float = float(Time.get_ticks_usec() - started) / count
			timings["%s_%s" % [config.name, "cached" if cached else "per_layer"]] = {"same_frame":snappedf(same, 0.1),"changing_frame":snappedf(changing, 0.1),"same_frame_unshared_file_checks":snappedf(cold, 0.1)}
			view.free()

func gpu_compare(info: Dictionary, config: Dictionary, copy: bool, companion_mode: bool = false) -> void:
	var bank: CountingBank = open_bank(info)
	var track: Dictionary = make_track(bank, config)
	var viewports: Array = []
	var views: Array = []
	for cached: bool in [true, false]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(16, 16)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background := ColorRect.new()
		background.color = Color(0.2, 0.4, 0.6)
		background.size = Vector2(16, 16)
		background.z_index = -10
		viewport.add_child(background)
		var view: Node2D = make_view(viewport, bank, track, info.path, cached)
		if cached and companion_mode: view.use_companion_frame_plans()
		view.position = Vector2(8, 8)
		view.modulate.a = float(config.get("alpha", 1.0))
		if config.get("strict", false): view._playback_mode = "strict"
		viewports.append(viewport)
		views.append(view)
	for step: Array in steps():
		for view: Node2D in views: view.advance_reference_source(step[0], "idle", step[1])
		await process_frame
		await RenderingServer.frame_post_draw
		var left: Image = viewports[0].get_texture().get_image()
		var right: Image = viewports[1].get_texture().get_image()
		render_checks += 1
		var difference: float = max_difference(left, right)
		check(difference == 0.0, "GPU pixels equal %s copy=%s step %s: max %f" % [config.name, str(copy), str(step), difference])
	for viewport: SubViewport in viewports: viewport.free()
