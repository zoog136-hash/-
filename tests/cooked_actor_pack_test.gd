extends "res://tests/reference_sp2_load_memo_test.gd"
## Cooked actor pack (cooked_actor_format/cooker/store/preview, the view's
## cooked branch and the installer's pinned-SHA check). Synthetic SP2 members
## only (reference_sp2_load_memo_test fixture: body + shadow + ADD clothes),
## written under user://; never the private bank, never original-resource or
## M-visual evidence.
## Headless: the runtime preview and the cooked preview are stepped together
## and their draw lists flattened on the CPU (MIX/ADD) must match exactly.
## With `-- --render` (xvfb + gl_compatibility) both are also drawn by the GPU
## into viewports and compared pixel for pixel.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const COOKER = preload("res://scripts/resources/cooked_actor_cooker.gd")
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const COOKED_PREVIEW = preload("res://scripts/animation/cooked_actor_preview.gd")
const VIEW = preload("res://scripts/monsters/current523_source_bank_view.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const GPU_TEXTURE = preload("res://scripts/resources/gpu_actor_texture.gd")
const COMPOSITES = preload("res://scripts/resources/actor_frame_composite_cache.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const CANVAS: int = 32

var pixel_comparisons: int = 0
var render_checks: int = 0
var measured: Dictionary = {}

func selection(data: Dictionary, sprite: int = ACTOR) -> Dictionary:
	return {"ok":true,"consumer":"npc","sprite_id":sprite,"manifest_path":data.path,"manifest_sha256":data.sha,
		"role_actions":{"idle":3,"walk":0},"loop_policy":{"idle":true,"walk":false},"host_policy":"cooked_actor_pack_test"}

func runtime_preview(parent: Node, selected: Dictionary) -> Node2D:
	var preview: Node2D = PREVIEW.new()
	preview.cached_frames = true
	parent.add_child(preview)
	check(preview._configure_selected_roles(selected, "idle"), "runtime preview configures: " + str(preview.reference_bank_status.get("error", "")))
	return preview

func cook(data: Dictionary, directory: String, compress: int) -> Dictionary:
	var selected: Dictionary = selection(data)
	var inputs: Dictionary = STORE.inputs(selected)
	var preview: Node2D = runtime_preview(root, selected)
	var resolved: Dictionary = {"role_actions":selected.role_actions,"loop_policy":selected.loop_policy}
	var started: int = Time.get_ticks_usec()
	var cooked: Dictionary = COOKER.cook_preview(preview, inputs, compress < 0, resolved)
	measured["cook_usec"] = Time.get_ticks_usec() - started
	preview.free()
	check(cooked.get("ok", false), "cook succeeds: " + str(cooked.get("error", "")))
	if not cooked.get("ok", false): return {}
	var path: String = directory.path_join(FORMAT.FORMAT_TAG).path_join(FORMAT.actor_file(inputs.key))
	var written: Dictionary = COOKER.write_cooked(path, cooked, compress)
	check(written.get("ok", false), "cooked file written: " + str(written.get("error", "")))
	return {"path":path,"cooked":cooked,"written":written}

## CPU oracle of the canvas draw (MIX and ADD with texel alpha * modulate).
func flatten(items: Array, background: Color) -> Image:
	var canvas := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBAF)
	canvas.fill(background)
	for item: Dictionary in items:
		var image: Image = item.image
		var color: Color = item.color
		for y: int in image.get_height():
			for x: int in image.get_width():
				var at: Vector2i = Vector2i(x, y) + Vector2i(item.position) + Vector2i(CANVAS / 2, CANVAS / 2)
				if at.x < 0 or at.y < 0 or at.x >= CANVAS or at.y >= CANVAS: continue
				var source: Color = image.get_pixel(x, y) * Color(color.r, color.g, color.b, 1.0)
				var alpha: float = image.get_pixel(x, y).a * color.a
				var dest: Color = canvas.get_pixelv(at)
				if item.blend == CanvasItemMaterial.BLEND_MODE_ADD:
					dest = Color(dest.r + source.r * alpha, dest.g + source.g * alpha, dest.b + source.b * alpha, 1.0)
				else:
					dest = Color(source.r * alpha + dest.r * (1.0 - alpha), source.g * alpha + dest.g * (1.0 - alpha), source.b * alpha + dest.b * (1.0 - alpha), 1.0)
				canvas.set_pixelv(at, dest)
	return canvas

func same_pixels(a: Image, b: Image) -> bool:
	return a.get_data() == b.get_data()

func compare_draw(runtime: Node2D, cooked: Node2D, label: String) -> void:
	var left: Dictionary = COOKER.capture(runtime)
	var right: Dictionary = COOKER.capture(cooked)
	check(left.ok and right.ok, label + ": both capture")
	if not (left.ok and right.ok): return
	check(not left.items.is_empty(), label + ": runtime draws something")
	for background: Color in [Color(0.2, 0.4, 0.6), Color.WHITE, Color.BLACK]:
		pixel_comparisons += 1
		var equal: bool = same_pixels(flatten(left.items, background), flatten(right.items, background))
		check(equal, label + ": CPU-flattened pixels equal on " + str(background))
		if not equal and background == Color.BLACK: printerr("  runtime " + describe(left.items) + "\n  cooked  " + describe(right.items))

func describe(items: Array) -> String:
	var out: Array = []
	for item: Dictionary in items: out.append("%s@%s b%d z%d a%.2f %s" % [str(item.image.get_size()), str(item.position), item.blend, item.z, item.color.a, item.image.get_data().hex_encode()])
	return ", ".join(out)

func steps() -> Array:
	# delta, role, stored direction
	return [[0.0, "idle", 0], [0.05, "idle", 0], [0.1, "idle", 0], [0.2, "idle", 1], [0.33, "idle", 1], [0.0, "walk", 2], [0.12, "walk", 2],
		[0.2, "walk", 3], [0.5, "walk", 3], [2.0, "walk", 3], [0.0, "idle", 5], [0.25, "idle", 7], [1.0, "idle", 6], [0.01, "idle", 4]]

func run() -> void:
	scratch = "user://cooked_actor_pack_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var render: bool = "--render" in OS.get_cmdline_user_args()
	if render and DisplayServer.get_name() == "headless":
		check(false, "--render requires an actual renderer")
		render = false
	var previous_copy: bool = COMPOSITOR.screen_copy_available
	var previous_gpu: bool = GPU_TEXTURE.enabled
	COMPOSITOR.screen_copy_available = false
	GPU_TEXTURE.enabled = false
	ASSETS.reset_for_tests()
	COMPOSITES.reset_for_tests()
	BANK.forget_verified_members()
	STORE.reset_for_tests()
	var data: Dictionary = fixture(scratch.path_join("bank"))
	var lossless_dir: String = scratch.path_join("cooked_lossless")
	var made: Dictionary = cook(data, lossless_dir, -1)
	if made.is_empty():
		finish(previous_copy, previous_gpu)
		return
	var stats: Dictionary = made.cooked.index.stats
	check(int(stats.states) > 0 and int(stats.images) > 0 and int(stats.merged_layers) > int(stats.images), "cook records states, images and merged layers: " + str(stats))
	# 1. Index round trip: the file holds exactly what was cooked.
	var file := FileAccess.open(made.path, FileAccess.READ)
	var head: Dictionary = FORMAT.read_index(file)
	check(head.get("ok", false), "index reads back: " + str(head.get("error", "")))
	if head.get("ok", false):
		var index: Dictionary = head.index
		check(index.format == FORMAT.FORMAT, "explicit FORMAT constant stored")
		check(var_to_bytes(index.states) == var_to_bytes(made.cooked.index.states), "states round-trip byte-exact")
		check(var_to_bytes(index.tracks) == var_to_bytes(made.cooked.index.tracks), "tracks round-trip byte-exact")
		check(index.inputs == made.cooked.index.inputs and index.key == "npc:%d" % ACTOR, "selection inputs round-trip")
		var pages: Dictionary = FORMAT.read_pages(file, index, int(head.data_start))
		check(pages.get("ok", false) and pages.images.size() == index.pages.size(), "pages read back")
		if pages.get("ok", false):
			for at: int in range(0, index.images.size(), 5):
				var page: Image = pages.images[index.images[at]]
				var cell: Image = page.get_region(Rect2i(index.images[at + 1], index.images[at + 2], index.images[at + 3], index.images[at + 4]))
				check(cell.get_data() == made.cooked.images[at / 5].get_data(), "lossless page cell %d keeps exact pixels" % (at / 5))
				check(index.images[at + 1] % 4 == 0 and index.images[at + 2] % 4 == 0, "cells are 4-aligned")
	file.close()
	# 2. Corrupt / other-format files are rejected.
	var bad_path: String = scratch.path_join("bad.twca")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(made.path)
	var wrong: PackedByteArray = bytes.duplicate()
	wrong[4] = 99
	write_bytes(bad_path, wrong)
	check(not STORE.load_actor(bad_path).ok, "other file version rejected")
	write_bytes(bad_path, bytes.slice(0, bytes.size() / 2))
	check(not STORE.load_actor(bad_path).ok, "truncated file rejected")
	# 3. Lookup and fallback.
	STORE.root_override = lossless_dir
	var selected: Dictionary = selection(data)
	var actor: STORE.CookedActor = STORE.lookup(selected)
	check(actor != null, "installed cooked actor found: " + str(STORE.stats()))
	check(STORE.lookup(selection(data, ACTOR + 77)) == null, "actor missing from the cooked pack -> original path")
	var other_roles: Dictionary = selection(data)
	other_roles.role_actions = {"idle":3,"walk":3}
	check(STORE.lookup(other_roles) == null, "different role actions -> original path")
	var other_bank: Dictionary = selection(data)
	other_bank.manifest_sha256 = "0".repeat(64)
	check(STORE.lookup(other_bank) == null, "different bank manifest -> original path")
	COMPOSITOR.screen_copy_available = true
	check(STORE.lookup(selection(data)) == null, "screen-copy (desktop) path -> original path")
	COMPOSITOR.screen_copy_available = false
	STORE.root_override = scratch.path_join("nowhere")
	STORE.reset_for_tests()
	STORE.root_override = scratch.path_join("nowhere")
	check(STORE.lookup(selection(data)) == null and not STORE.available(), "no cooked pack installed -> original path")
	STORE.reset_for_tests()
	STORE.root_override = lossless_dir
	actor = STORE.lookup(selection(data))
	# 4. Pixel equality: runtime preview vs cooked preview, same steps.
	if actor != null:
		var runtime: Node2D = runtime_preview(root, selection(data))
		var cooked_view: Node2D = COOKED_PREVIEW.new()
		root.add_child(cooked_view)
		check(cooked_view.configure_cooked(actor, "idle"), "cooked preview configures")
		for step: Array in steps():
			var a: bool = runtime.advance_reference_source(step[0], step[1], step[2])
			var b: bool = cooked_view.advance_reference_source(step[0], step[1], step[2])
			check(a and b, "both advance " + str(step))
			check(runtime.last_source_frame == cooked_view.last_source_frame, "same source frame " + str(step) + ": %d/%d" % [runtime.last_source_frame, cooked_view.last_source_frame])
			compare_draw(runtime, cooked_view, "step " + str(step))
		# Restarted one-shot and its held end pose.
		runtime.restart_reference_source("walk", 7)
		cooked_view.restart_reference_source("walk", 7)
		for delta: float in [0.0, 0.3, 5.0]:
			runtime.advance_reference_source(delta, "walk", 6)
			cooked_view.advance_reference_source(delta, "walk", 6)
			check(runtime.last_source_frame == cooked_view.last_source_frame, "one-shot frame after %f" % delta)
			compare_draw(runtime, cooked_view, "one-shot %f" % delta)
		check(cooked_view.source_playback_mode() == runtime.source_playback_mode(), "same playback mode")
		measure(runtime, cooked_view)
		if render: await gpu_compare(data, actor)
		runtime.free()
		cooked_view.free()
		# 5. The monster view: same advance logic on both previews.
		await compare_views(data, actor)
	# 6. ETC2 variant: opaque pages block compressed, soft/ADD pages exact.
	var etc_dir: String = scratch.path_join("cooked_etc2")
	var etc: Dictionary = cook(data, etc_dir, Image.COMPRESS_ETC2)
	if not etc.is_empty():
		var loaded: Dictionary = STORE.load_actor(etc.path)
		check(loaded.get("ok", false), "ETC2 cooked actor loads: " + str(loaded.get("error", "")))
		if loaded.get("ok", false):
			var formats: Array = []
			for texture: Texture2D in loaded.actor.textures: formats.append(texture.get_image().get_format() if texture.get_image() != null else -1)
			var classes: Array = loaded.actor.index.page_classes
			for page: int in range(classes.size()):
				if classes[page] == FORMAT.PAGE_RGBA8: check(loaded.actor.index.pages[page].format == Image.FORMAT_RGBA8, "soft/ADD page stays RGBA8")
				else: check(Image.FORMAT_ETC2_R11 <= int(loaded.actor.index.pages[page].format) and int(loaded.actor.index.pages[page].format) <= Image.FORMAT_ETC2_RA_AS_RG, "opaque page ETC2 compressed: " + str(loaded.actor.index.pages[page].format))
			measured["etc2_file_bytes"] = etc.written.bytes
			measured["etc2_gpu_bytes"] = etc.written.gpu_bytes
			measured["lossless_gpu_bytes"] = made.written.gpu_bytes
	# 7. Bounded cache: distinct actors past the byte budget evict the oldest.
	STORE.reset_for_tests()
	var bound_dir: String = scratch.path_join("cooked_bound")
	var head_again: Dictionary = FORMAT.read_index(FileAccess.open(made.path, FileAccess.READ))
	var page_file := FileAccess.open(made.path, FileAccess.READ)
	var page_images: Array = FORMAT.read_pages(page_file, head_again.index, int(head_again.data_start)).images
	for offset: int in range(6):
		var copy: Dictionary = head_again.index.duplicate(true)
		var key: String = "npc:%d" % (ACTOR + 100 + offset)
		copy.key = key
		copy.inputs.key = key
		copy.inputs.sprite_id = ACTOR + 100 + offset
		copy.erase("pages")
		copy.erase("format")
		FORMAT.write(bound_dir.path_join(FORMAT.FORMAT_TAG).path_join(FORMAT.actor_file(key)), copy, page_images)
	STORE.root_override = bound_dir
	var one: STORE.CookedActor = STORE.lookup(selection(data, ACTOR + 100))
	check(one != null, "bound fixture actor loads")
	if one != null:
		STORE.budget_bytes = one.bytes * 2
		var over: bool = false
		for offset: int in range(6):
			check(STORE.lookup(selection(data, ACTOR + 100 + offset)) != null, "bound actor %d loads" % offset)
			if int(STORE.stats().bytes) > STORE.budget_bytes: over = true
		var bound: Dictionary = STORE.stats()
		check(not over and int(bound.entries) <= 2 and int(bound.counters.get("evicted", 0)) >= 4, "cache stays within its byte budget: " + JSON.stringify(bound))
	# 8. Install: only pinned part SHA-256s are accepted.
	install_checks()
	finish(previous_copy, previous_gpu)

func install_checks() -> void:
	var zip_path: String = scratch.path_join("cooked-part-1of1.zip")
	var packer := ZIPPacker.new()
	check(packer.open(zip_path) == OK, "fixture part zip opens")
	var index: Dictionary = {"schema":PACK.PART_SCHEMA,"pack_id":"c".repeat(64),"part":1,"parts":1,"cooked":true,"format":FORMAT.FORMAT,"members":[["cooked/v1/actors/npc_1.twca",4]]}
	packer.start_file("source523/source523_part.json")
	packer.write_file(JSON.stringify(index).to_utf8_buffer())
	packer.close_file()
	packer.start_file("source523/cooked/v1/actors/npc_1.twca")
	packer.write_file(PackedByteArray([1, 2, 3, 4]))
	packer.close_file()
	packer.close()
	var sha: String = FileAccess.get_sha256(zip_path)
	var pins: Dictionary = {sha:[1, 1, "cooked-part-1of1.zip"]}
	check(PACK.cooked_part_accepted(sha, index, pins, "c".repeat(64)).ok, "pinned part SHA-256 accepted")
	var tampered: PackedByteArray = FileAccess.get_file_as_bytes(zip_path)
	tampered[tampered.size() - 30] ^= 1
	write_bytes(zip_path, tampered)
	var tampered_sha: String = FileAccess.get_sha256(zip_path)
	var rejected: Dictionary = PACK.cooked_part_accepted(tampered_sha, index, pins, "c".repeat(64))
	check(not rejected.ok and rejected.reason == "cooked_part_sha256_not_pinned", "changed part bytes rejected: " + str(rejected))
	var renumbered: Dictionary = index.duplicate()
	renumbered.part = 2
	renumbered.parts = 2
	check(not PACK.cooked_part_accepted(sha, renumbered, pins, "c".repeat(64)).ok, "pinned bytes with another part number rejected")
	var other_id: Dictionary = index.duplicate()
	other_id.pack_id = "d".repeat(64)
	check(not PACK.cooked_part_accepted(sha, other_id, pins, "c".repeat(64)).ok, "another cooked pack id rejected")
	check(PACK.cooked_part_accepted(sha, index, {}, "").reason == "cooked_pack_not_pinned_in_this_build", "a build without pins accepts no cooked part")
	# Installed state: complete only when every part is recorded.
	var base: String = scratch.path_join("install")
	DirAccess.make_dir_recursive_absolute(base)
	var two: Dictionary = index.duplicate()
	two.parts = 2
	var state: Dictionary = PACK.record_cooked_part(base, two, "c".repeat(64))
	check(state.get("complete") == false and state.done == [1], "one of two parts: not complete")
	two.part = 2
	state = PACK.record_cooked_part(base, two, "c".repeat(64))
	check(state.get("complete") == true and state.done == [1, 2], "all parts: complete")

func compare_views(data: Dictionary, actor: STORE.CookedActor) -> void:
	var runtime_view: Node2D = VIEW.new()
	var cooked_view: Node2D = VIEW.new()
	root.add_child(runtime_view)
	root.add_child(cooked_view)
	var selected: Dictionary = selection(data)
	var preview: Node2D = PREVIEW.new()
	preview.cached_frames = true
	check(preview._configure_selected_roles(selected, "idle"), "view runtime preview configures")
	check(runtime_view._attach(preview, selected), "runtime view attaches")
	var cooked_preview: Node2D = COOKED_PREVIEW.new()
	cooked_preview.configure_cooked(actor, "idle")
	check(cooked_view._attach(cooked_preview, selection(data)), "cooked view attaches")
	check(is_equal_approx(runtime_view.duration("walk"), cooked_view.duration("walk")) and runtime_view.duration("walk") > 0.0, "same role duration")
	check(runtime_view.timing_status == cooked_view.timing_status, "same timing status")
	# delta, state, facing, sequence, attacking, dead
	for step: Array in [[0.0, "idle", 2, 0, false, false], [0.1, "walk", 3, 0, false, false], [0.15, "walk", 3, 0, false, false], [0.3, "idle", 5, 0, false, false], [0.05, "chase", 1, 0, false, false], [0.4, "walk", 0, 0, false, false]]:
		runtime_view.advance(step[0], step[1], step[2], step[3], step[4], step[5])
		cooked_view.advance(step[0], step[1], step[2], step[3], step[4], step[5])
		check(runtime_view.last_source_frame == cooked_view.last_source_frame and runtime_view._role == cooked_view._role, "views agree " + str(step))
		compare_draw(runtime_view._preview, cooked_view._preview, "view " + str(step))
	runtime_view.free()
	cooked_view.free()

func measure(runtime: Node2D, cooked_view: Node2D) -> void:
	for pair: Array in [["runtime", runtime], ["cooked", cooked_view]]:
		var view: Node2D = pair[1]
		var started: int = Time.get_ticks_usec()
		for index: int in range(200): view.advance_reference_source(0.033, "idle", index % 8)
		measured[pair[0] + "_usec_per_advance"] = float(Time.get_ticks_usec() - started) / 200.0

func gpu_compare(data: Dictionary, actor: STORE.CookedActor) -> void:
	for step: Array in [[0.0, "idle", 0], [0.1, "idle", 3], [0.0, "walk", 5], [0.15, "walk", 6]]:
		var images: Array = []
		for cooked: bool in [false, true]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(CANVAS, CANVAS)
			viewport.transparent_bg = false
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var background := ColorRect.new()
			background.color = Color(0.2, 0.4, 0.6)
			background.size = Vector2(CANVAS, CANVAS)
			viewport.add_child(background)
			var view: Node2D
			if cooked:
				view = COOKED_PREVIEW.new()
				view.configure_cooked(actor, "idle")
			else:
				view = PREVIEW.new()
				view.cached_frames = true
			view.position = Vector2(CANVAS / 2, CANVAS / 2)
			viewport.add_child(view)
			if not cooked: view._configure_selected_roles(selection(data), "idle")
			view.advance_reference_source(0.0, step[1], step[2])
			view.advance_reference_source(step[0], step[1], step[2])
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			images.append(viewport.get_texture().get_image())
			viewport.free()
		render_checks += 1
		check(images[0].get_data() == images[1].get_data(), "GPU pixels equal " + str(step))
		var plain := Image.create_empty(images[0].get_width(), images[0].get_height(), false, images[0].get_format())
		plain.fill(images[0].get_pixel(0, 0))
		check(images[0].get_data() != plain.get_data(), "GPU frame shows the actor " + str(step))

func finish(previous_copy: bool, previous_gpu: bool) -> void:
	COMPOSITOR.screen_copy_available = previous_copy
	GPU_TEXTURE.enabled = previous_gpu
	STORE.reset_for_tests()
	STORE.root_override = ""
	print("COOKED_ACTOR_PACK_RESULT " + JSON.stringify({"checks":checks,"pixel_comparisons":pixel_comparisons,"render_checks":render_checks,"failures":failures,"measured":measured,"format":FORMAT.FORMAT,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
