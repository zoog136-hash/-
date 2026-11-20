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
const VIEW = preload("res://scripts/monsters/current523_source_bank_view.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const GPU_TEXTURE = preload("res://scripts/resources/gpu_actor_texture.gd")
const COMPOSITES = preload("res://scripts/resources/actor_frame_composite_cache.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const PINS = preload("res://scripts/boot/cooked_actor_pins.gd")
const CANVAS: int = 32

var pixel_comparisons: int = 0
var render_checks: int = 0
var measured: Dictionary = {}

func selection(data: Dictionary, sprite: int = ACTOR) -> Dictionary:
	return {"ok":true,"consumer":"npc","sprite_id":sprite,"manifest_path":data.path,"manifest_sha256":data.sha,
		"role_actions":{"idle":3,"walk":0},"loop_policy":{"idle":true,"walk":false},"host_policy":"cooked_actor_pack_test"}

func runtime_preview(parent: Node, selected: Dictionary) -> Node2D:
	STORE.disabled = true
	var preview: Node2D = PREVIEW.new()
	preview.cached_frames = true
	parent.add_child(preview)
	check(preview._configure_selected_roles(selected, "idle"), "runtime preview configures: " + str(preview.reference_bank_status.get("error", "")))
	check(not preview.cooked_actor(), "runtime preview uses the original bank")
	STORE.disabled = false
	return preview

## The same production preview with the cooked pack installed.
func cooked_preview(parent: Node, selected: Dictionary) -> Node2D:
	var preview: Node2D = PREVIEW.new()
	preview.cached_frames = true
	parent.add_child(preview)
	check(preview._configure_selected_roles(selected, "idle") and preview.cooked_actor(), "preview plays the cooked actor: " + str(preview.reference_bank_status))
	return preview

## Two entries in one bundle: the selection and a "weapon variant" whose
## roles reuse the same source actions (as most transform weapon families do).
func variant(data: Dictionary) -> Dictionary:
	var selected: Dictionary = selection(data)
	selected.role_actions = {"idle":0,"walk":3}
	return selected

func cook(data: Dictionary, directory: String, compress: int) -> Dictionary:
	var session := COOKER.Session.new()
	var entries: Array = []
	var started: int = Time.get_ticks_usec()
	for selected: Dictionary in [selection(data), variant(data)]:
		var inputs: Dictionary = STORE.selection_inputs(selected)
		var preview: Node2D = runtime_preview(root, selected)
		var cooked: Dictionary = COOKER.cook_preview(preview, inputs, compress < 0, {"role_actions":selected.role_actions,"loop_policy":selected.loop_policy}, session)
		preview.free()
		check(cooked.get("ok", false), "cook succeeds: " + str(cooked.get("error", "")))
		if not cooked.get("ok", false): return {}
		entries.append(cooked.entry)
	measured["cook_usec"] = Time.get_ticks_usec() - started
	var path: String = directory.path_join(FORMAT.FORMAT_TAG).path_join(STORE.file_for(entries[0].inputs))
	var written: Dictionary = COOKER.write_cooked(path, session, entries, compress)
	check(written.get("ok", false), "cooked file written: " + str(written.get("error", "")))
	return {"path":path,"session":session,"entries":entries,"written":written}

func check_incomplete_attachment(data: Dictionary) -> void:
	var selected: Dictionary=selection(data)
	var preview: Node2D=runtime_preview(root,selected)
	STORE.disabled=true
	preview._record=preview._record.duplicate()
	preview._record.independent_source_layers={"idle":[{"kind":"shadow","from_sprite_id":ACTOR,"target_sprite_id":ACTOR+778,"child_action_id":3,"child_source_action_key":"missing-action"}]}
	preview._reference_card_context={"consumer":"npc","manifest_sha256":data.sha}
	check(preview.advance_reference_source(0.0,"idle",0) and not preview._reference_child_problem.is_empty(),"live body continues when a declared shadow cannot be loaded")
	preview._reference_card_context.clear()
	var result: Dictionary=COOKER.cook_preview(preview,STORE.selection_inputs(selected),true)
	check(not result.get("ok",false) and str(result.get("error","")).begins_with("cooked_source_layer_incomplete:") and not result.has("entry"),"cooker rejects partial actor instead of baking its missing shadow")
	preview.free()
	STORE.disabled=false

func check_cooked_attachment(data: Dictionary) -> void:
	var directory: String=data.path.get_base_dir()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(data.path))
	var sprite: int=ACTOR+100
	for offset: int in 3:
		var member: String="Sprite/%d-0.sp2" % (sprite+offset)
		var spec: Dictionary=manifest.members["Sprite/%d-0.sp2" % (ACTOR+offset)].duplicate()
		write_bytes(directory.path_join("raw/"+member),FileAccess.get_file_as_bytes(directory.path_join(spec.path)))
		spec.member=member
		spec.path="raw/"+member
		manifest.members[member]=spec
	var child_action: String=JSON.stringify(source_action(3))
	for offset: int in 3:
		child_action=child_action.replace(str(ACTOR+offset),str(sprite+offset))
	var relative: String="actors/%d/action-3.json" % sprite
	write_bytes(directory.path_join(relative),child_action.to_utf8_buffer())
	manifest.actors["sprite:%d" % sprite]={"3":{"path":relative,"sha256":FileAccess.get_sha256(directory.path_join(relative))}}
	var manifest_path: String=directory.path_join("manifest-with-child.json")
	var selected: Dictionary=selection({"path":manifest_path,"sha":write_json(manifest_path,manifest)})
	var preview: Node2D=runtime_preview(root,selected)
	STORE.disabled=true
	preview._record=preview._record.duplicate()
	preview._record.independent_source_layers={"idle":[{"kind":"shadow","from_sprite_id":ACTOR,"target_sprite_id":sprite,"child_action_id":3,"child_source_action_key":"list_9.spr:B%d:A3" % sprite,"source_declaration":{},"dispatch_policy":"fixture"}]}
	var cooked: Dictionary=COOKER.cook_preview(preview,STORE.selection_inputs(selected),true)
	var shadow_seen: bool=false
	if cooked.get("ok",false):
		var state_id: int=cooked.entry.tracks.idle.directions[0].seg_state[0]
		var draw: PackedInt32Array=cooked.session.states[state_id]
		for at: int in range(0,draw.size(),FORMAT.ITEM_STRIDE):
			if draw[at+4]==-1:shadow_seen=true
	check(cooked.get("ok",false) and shadow_seen,"a valid independent shadow is written behind the parent in an offline cook: " + str(cooked.get("error","")))
	preview.free()
	STORE.disabled=false

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
	check_incomplete_attachment(data)
	check_cooked_attachment(data)
	var lossless_dir: String = scratch.path_join("cooked_lossless")
	var made: Dictionary = cook(data, lossless_dir, -1)
	if made.is_empty():
		finish(previous_copy, previous_gpu)
		return
	var stats: Dictionary = made.written.stats
	check(int(stats.states) > 0 and int(stats.images) > 0 and int(stats.merged_layers) > int(stats.images) and int(stats.entries) == 2, "cook records states, images, merged layers and two entries: " + str(stats))
	check(int(made.entries[1].stats.new_images) == 0 and int(made.entries[1].stats.new_states) == 0, "the variant entry reuses every image and state of the bundle: " + str(made.entries[1].stats))
	# 1. Index round trip: the file holds exactly what was cooked.
	var file := FileAccess.open(made.path, FileAccess.READ)
	var head: Dictionary = FORMAT.read_index(file)
	check(head.get("ok", false), "index reads back: " + str(head.get("error", "")))
	if head.get("ok", false):
		var index: Dictionary = head.index
		check(index.format == FORMAT.FORMAT, "explicit FORMAT constant stored")
		check(var_to_bytes(index.states) == var_to_bytes(made.session.states), "states round-trip byte-exact")
		check(index.entries.size() == 2 and var_to_bytes(index.entries[0].tracks) == var_to_bytes(made.entries[0].tracks) and var_to_bytes(index.entries[1].tracks) == var_to_bytes(made.entries[1].tracks), "entry tracks round-trip byte-exact")
		check(index.entries[0].inputs == made.entries[0].inputs and index.entries[0].inputs.sprite_id == ACTOR and index.entries[0].inputs.kind == "selection", "selection inputs round-trip")
		var pages: Dictionary = FORMAT.read_pages(file, index, int(head.data_start))
		check(pages.get("ok", false) and pages.images.size() == index.pages.size(), "pages read back")
		if pages.get("ok", false):
			for at: int in range(0, index.images.size(), 5):
				var page: Image = pages.images[index.images[at]]
				var cell: Image = page.get_region(Rect2i(index.images[at + 1], index.images[at + 2], index.images[at + 3], index.images[at + 4]))
				check(cell.get_data() == made.session.images[at / 5].get_data(), "lossless page cell %d keeps exact pixels" % (at / 5))
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
	var actor: Dictionary = STORE.lookup(selected)
	check(not actor.is_empty(), "installed cooked actor found: " + str(STORE.stats()))
	if not actor.is_empty(): check_direction_totals(actor.entry)
	check(not STORE.lookup(variant(data)).is_empty() and STORE.lookup(variant(data)).actor == actor.actor, "the variant entry comes from the same bundle")
	check(STORE.lookup(selection(data, ACTOR + 77)).is_empty(), "actor missing from the cooked pack -> original path")
	var other_roles: Dictionary = selection(data)
	other_roles.role_actions = {"idle":3,"walk":3}
	check(STORE.lookup(other_roles).is_empty(), "different role actions -> original path")
	var other_bank: Dictionary = selection(data)
	other_bank.manifest_sha256 = "0".repeat(64)
	check(STORE.lookup(other_bank).is_empty(), "different bank manifest -> original path")
	COMPOSITOR.screen_copy_available = true
	check(STORE.lookup(selection(data)).is_empty(), "screen-copy (desktop) path -> original path")
	COMPOSITOR.screen_copy_available = false
	STORE.root_override = scratch.path_join("nowhere")
	STORE.reset_for_tests()
	STORE.root_override = scratch.path_join("nowhere")
	check(STORE.lookup(selection(data)).is_empty() and not STORE.available(), "no cooked pack installed -> original path")
	STORE.reset_for_tests()
	STORE.root_override = lossless_dir
	actor = STORE.lookup(selection(data))
	# 4. Pixel equality: runtime preview vs cooked preview, same steps.
	if not actor.is_empty():
		var runtime: Node2D = runtime_preview(root, selection(data))
		var cooked_view: Node2D = cooked_preview(root, selection(data))
		check(cooked_view._layers.is_empty() and cooked_view._effect_nodes.is_empty(), "cooked preview builds no SP2 layer nodes")
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
		var verified: Dictionary = COOKER.verify(runtime, cooked_view, COOKER.verify_steps(["idle", "walk"], 7))
		check(verified.ok and verified.exact_items == verified.items and verified.items > 0, "cook-run verifier agrees (lossless): " + str(verified))
		measure(runtime, cooked_view)
		if render: await gpu_compare(data, actor)
		runtime.free()
		cooked_view.free()
		# 5. The monster view: same advance logic on both previews.
		await compare_views(data)
		# 5b. A direct effect-style request (one-shot overlay) is cooked too.
		await compare_request(data)
	# 6. ASTC variant: opaque pages block compressed, soft/ADD pages exact.
	var etc_dir: String = scratch.path_join("cooked_etc2")
	var etc: Dictionary = cook(data, etc_dir, Image.COMPRESS_ASTC)
	if not etc.is_empty():
		var loaded: Dictionary = STORE.load_actor(etc.path)
		check(loaded.get("ok", false), "ASTC cooked actor loads: " + str(loaded.get("error", "")))
		if loaded.get("ok", false):
			check(STORE.page_texture(loaded.actor, 0) != null, "a block-compressed bundle's page loads")
			var classes: Array = loaded.actor.index.page_classes
			for page: int in range(classes.size()):
				if classes[page] == FORMAT.PAGE_RGBA8: check(loaded.actor.index.pages[page].format == Image.FORMAT_RGBA8, "soft/ADD page stays RGBA8")
				else: check(int(loaded.actor.index.pages[page].format) == Image.FORMAT_ASTC_4x4, "opaque page ASTC 4x4 compressed: " + str(loaded.actor.index.pages[page].format))
			measured["etc2_file_bytes"] = etc.written.bytes
			measured["etc2_gpu_bytes"] = etc.written.gpu_bytes
			measured["lossless_gpu_bytes"] = made.written.gpu_bytes
			check(etc.written.stats.has("etc2_cells") and etc.written.stats.has("rgba8_cells"), "hybrid rule counts cells: " + str(etc.written.stats))
	hybrid_checks()
	# 7. Bounded cache: distinct actors past the byte budget evict the oldest.
	STORE.reset_for_tests()
	var bound_dir: String = scratch.path_join("cooked_bound")
	var head_again: Dictionary = FORMAT.read_index(FileAccess.open(made.path, FileAccess.READ))
	var page_file := FileAccess.open(made.path, FileAccess.READ)
	var page_images: Array = FORMAT.read_pages(page_file, head_again.index, int(head_again.data_start)).images
	for offset: int in range(6):
		var copy: Dictionary = head_again.index.duplicate(true)
		copy.entries = [copy.entries[0]]
		copy.entries[0].inputs = STORE.selection_inputs(selection(data, ACTOR + 100 + offset))
		copy.erase("pages")
		copy.erase("format")
		FORMAT.write(bound_dir.path_join(FORMAT.FORMAT_TAG).path_join(STORE.file_for(copy.entries[0].inputs)), copy, page_images)
	STORE.root_override = bound_dir
	var one: Dictionary = STORE.lookup(selection(data, ACTOR + 100))
	check(not one.is_empty(), "bound fixture actor loads")
	if not one.is_empty():
		# Page textures load lazily and stay within the byte budget.
		var page_bytes: int = 0
		for page: Dictionary in one.actor.index.pages: page_bytes = maxi(page_bytes, int(page.raw))
		STORE.budget_bytes = page_bytes * 2
		check(int(STORE.stats().pages) == 0, "looking an actor up loads no page pixels")
		var over: bool = false
		for offset: int in range(6):
			var found: Dictionary = STORE.lookup(selection(data, ACTOR + 100 + offset))
			check(not found.is_empty(), "bound actor %d loads" % offset)
			if found.is_empty(): continue
			for page: int in range(found.actor.index.pages.size()):
				check(STORE.page_texture(found.actor, page) != null, "page %d of actor %d loads" % [page, offset])
				if int(STORE.stats().bytes) > STORE.budget_bytes: over = true
		var bound: Dictionary = STORE.stats()
		check(not over and int(bound.counters.get("page_evicted", 0)) >= 4, "page textures stay within their byte budget: " + JSON.stringify(bound))
	# 8. Install: only pinned part SHA-256s are accepted.
	install_checks()
	effect_domain_checks(data)
	content_key_checks(data)
	await check_lazy_page_recovery(render)
	finish(previous_copy, previous_gpu)

func check_lazy_page_recovery(render: bool) -> void:
	STORE.reset_for_tests()
	var bg:=Image.create_empty(4,4,false,Image.FORMAT_RGBA8)
	bg.fill(Color.RED)
	var fg:=Image.create_empty(4,4,false,Image.FORMAT_RGBA8)
	fg.fill(Color.GREEN)
	var direction: Dictionary={"durations":PackedFloat64Array([1,1]),"source_frames":PackedInt32Array([0,1]),"source_groups":PackedInt32Array([0,0]),"seg_start":PackedInt32Array([0,1,2]),"seg_end":PackedFloat64Array([1,1]),"seg_state":PackedInt32Array([0,1]),"end_state":1}
	var directions: Array=[]
	directions.resize(8)
	directions.fill(direction)
	var index: Dictionary={
		"images":PackedInt32Array([0,0,0,4,4, 1,0,0,4,4]),
		"states":[PackedInt32Array([0,0,0,0,0,0,0,0]),PackedInt32Array([0,8,0,0,0,0,0,0, 1,12,0,0,1,0,0,0, 0,16,0,0,2,0,0,0])],
		"entries":[{"inputs":{"manifest_sha256":"a".repeat(64)},"tracks":{"idle":{"loop":true,"static_pending_timing":false,"directions":directions}}}],
		"colors":PackedFloat32Array([1,1,1,1]),
	}
	var path: String=scratch.path_join("two-pages.twca")
	check(FORMAT.write(path,index,[bg,fg]).ok,"two-page recovery fixture writes")
	var loaded: Dictionary=STORE.load_actor(path)
	check(loaded.get("ok",false),"two-page index loads")
	if not loaded.get("ok",false): return
	var actor: STORE.CookedActor=loaded.actor
	var cooked={"actor":actor,"entry":actor.entries.values()[0]}
	var view:=PREVIEW.new()
	var viewport: SubViewport
	if render:
		viewport=SubViewport.new()
		viewport.size=Vector2i(CANVAS,CANVAS)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background:=ColorRect.new()
		background.color=Color.BLACK
		background.size=Vector2(CANVAS,CANVAS)
		viewport.add_child(background)
		view.position=Vector2(2,2)
		viewport.add_child(view)
	else:
		root.add_child(view)
	check(view._configure_cooked(cooked,path,"idle","npc",ACTOR),"real cooked preview configures")
	view.advance_reference_source(0.0,"idle",0)
	check(view._cooked_state==0 and view._cooked_sprites.size()==1,"the first complete pose is visible")
	var original_pixels: Image
	if render:
		original_pixels=await read_cooked_pose(viewport)
		check(original_pixels.get_pixel(3,3)==Color.RED,"OpenGL shows the initial pose")
	actor.path=path+".temporarily-missing"
	view.advance_reference_source(1.0,"idle",0)
	check(view._cooked_state==0 and view._cooked_sprites.size()==1 and view._cooked_sprites[0].visible and view._cooked_sprites[0].position==Vector2.ZERO,"a missing lazy page leaves the previous pose intact")
	var reads: int=int(STORE.stats().counters.get("page_unreadable",0))
	view.advance_reference_source(0.0,"idle",0)
	check(reads==1 and int(STORE.stats().counters.get("page_unreadable",0))==1,"immediate retry of the failed page is throttled")
	if render:
		var held_pixels: Image=await read_cooked_pose(viewport)
		check(held_pixels.get_data()==original_pixels.get_data(),"OpenGL keeps the whole previous pose on a failed page")
	actor.path=path
	var retries: Variant=actor.get("page_retry_after")
	if retries is Dictionary: retries.clear() # Advance the retry window without a wall-clock sleep.
	view.advance_reference_source(0.0,"idle",0)
	check(view._cooked_state==1 and view._cooked_sprites.size()==3 and view._cooked_sprites[1].visible,"the unchanged desired state recovers all layers")
	if render:
		var recovered: Image=await read_cooked_pose(viewport)
		var all_layers: bool=recovered.get_pixel(11,3)==Color.RED and recovered.get_pixel(15,3)==Color.GREEN and recovered.get_pixel(19,3)==Color.RED
		check(all_layers and recovered.get_pixel(3,3)==Color.BLACK,"OpenGL replaces the held pose with all three recovered layers")
		render_checks+=3
		viewport.free()
	else:
		view.free()
	STORE.reset_for_tests()
	STORE.budget_bytes=64 # One RGBA8 page: A/B/A must still resolve A only once.
	actor=STORE.load_actor(path).actor
	var owner:=Node2D.new()
	root.add_child(owner)
	var sprites: Array[Sprite2D]=[]
	STORE.apply_state(owner,sprites,actor,1)
	var loaded_pages: int=int(STORE.stats().counters.get("page_loaded",0))
	check(loaded_pages==2 and sprites.size()==3 and sprites[0].texture==sprites[2].texture,"A/B/A loads two pages and shares A across its layers (loaded %d)" % loaded_pages)
	check(int(STORE.stats().bytes)<=64,"preflight does not raise the shared page cache budget")
	owner.free()

func read_cooked_pose(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func check_direction_totals(entry: Dictionary) -> void:
	const PRESENTATION = preload("res://scripts/animation/source_presentation_policy.gd")
	for role: String in entry.runtime_tracks:
		var track: Dictionary = entry.runtime_tracks[role]
		var expected := PackedFloat64Array()
		for frames: Array in track.directions:
			var total: float = 0.0
			for frame: Dictionary in frames:
				total += PRESENTATION.duration(frame)
			expected.append(total)
		check(track.get("direction_totals") == expected, "shared cooked clock totals match the runtime policy in all directions for " + role)

## The block-compression (ASTC 4x4) acceptance rule on synthetic cells: a smooth opaque cell passes,
## a high-contrast noise cell and a cell whose binary alpha would not survive
## keep RGBA8.
func hybrid_checks() -> void:
	var smooth := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16: smooth.set_pixel(x, y, Color(x / 16.0, y / 16.0, 0.5, 1.0))
	var passed: Dictionary = COOKER.etc2_check(smooth, Image.COMPRESS_ASTC, COOKER.ETC2_MIN_PSNR)
	check(passed.ok and passed.psnr >= COOKER.ETC2_MIN_PSNR, "smooth opaque cell is block compressed: " + str(passed.psnr))
	var noise := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = 5
	for y: int in 16:
		for x: int in 16: noise.set_pixel(x, y, Color(random.randf(), random.randf(), random.randf(), 1.0 if random.randf() < 0.7 else 0.0))
	var rejected: Dictionary = COOKER.etc2_check(noise, Image.COMPRESS_ASTC, COOKER.ETC2_MIN_PSNR)
	check(not rejected.ok, "noisy/binary-alpha cell keeps RGBA8: " + str([rejected.psnr, rejected.get("alpha", false)]))
	measured["etc2_check_psnr"] = [passed.psnr, rejected.psnr]

## Cook-time effect action domains (cooked pack) follow the effect
## selection's rules; a manifest without domains is rejected once, not
## re-hashed and re-parsed on every request.
func effect_domain_checks(data: Dictionary) -> void:
	var EFFECT = load("res://scripts/resources/current523_source_effect_selection.gd")
	var index: Dictionary = {"format":STORE.EFFECT_INDEX_FORMAT,"manifest_sha256":data.sha,"domain_basis":STORE.EFFECT_DOMAIN_BASIS,
		"domains":{"sprite:10":PackedInt32Array([0]),"sprite:11":PackedInt32Array([0, 1]),"sprite:12":PackedInt32Array([2])},
		"compiled":{"sprite:10":PackedInt32Array([0]),"sprite:11":PackedInt32Array([0, 1])},"excluded":{"sprite:13":{"dummy":true}}}
	EFFECT.cooked_domain_index = index
	var options: Dictionary = {"manifest_path":data.path,"manifest_sha256":data.sha}
	var sole: Dictionary = EFFECT._action(options, 10)
	check(sole.ok and sole.action_id == 0 and sole.source_action_domain.action_domain_basis == STORE.EFFECT_DOMAIN_BASIS, "sole domain action selected from the cooked index")
	check(EFFECT._action(options, 11).reason == "current523_effect_original_action_selection_not_unique", "two actions: not unique")
	check(EFFECT._action(options, 11, 1).ok, "declared action in the domain")
	check(EFFECT._action(options, 11, 5).reason == "current523_effect_requested_action_not_declared", "undeclared action rejected")
	check(EFFECT._action(options, 12).reason == "current523_effect_original_action_inputs_unavailable", "domain action without compiled frames rejected")
	check(EFFECT._action(options, 13).reason == "current523_effect_source_declared_dummy", "dummy rejected")
	check(EFFECT._action(options, 99).reason == "current523_effect_complete_original_action_domain_missing", "unknown actor rejected")
	EFFECT.cooked_domain_index = {}
	# The fixture manifest has no source_action_domains: rejected, then memoized.
	var first: Dictionary = EFFECT._bank(options)
	check(not first.ok and first.reason == "current523_effect_original_action_domain_required", "manifest without domains rejected")
	check(EFFECT._rejected_key.begins_with(data.path) and EFFECT._bank(options) == first, "rejection memoized while the file is unchanged")

## A cooked entry is found by the original content and FORMAT only: the
## bank manifest SHA-256 (the same bank in pack-b2162b06 and its repack
## pack-63fb1355), the selection's source roles/actions, playback mode and
## copy-free path. No game-code revision, script hash or original pack ID is a
## key, so a code update (OTA) keeps using the installed cooked pack; only a
## FORMAT change or another bank invalidates it.
func content_key_checks(data: Dictionary) -> void:
	var inputs: Dictionary = STORE.selection_inputs(selection(data))
	var keys: Array = inputs.keys()
	keys.sort()
	check(keys == ["consumer","kind","loop_policy","manifest_sha256","mode","optional_role_actions","optional_role_actor_ids","optional_role_loop_policy","role_actions","role_actor_ids","screen_copy","sprite_id"], "selection key fields are content only: " + str(keys))
	var request: Dictionary = STORE.request_inputs(data.path, data.sha, ACTOR, {"idle":3}, {"idle":false}, "overlay", {})
	var request_keys: Array = request.keys()
	request_keys.sort()
	check(request_keys == ["consumer","kind","loop_policy","manifest_sha256","mode","role_actions","role_actor_ids","screen_copy","sprite_id"], "request key fields are content only: " + str(request_keys))
	check(STORE.file_for(inputs) == "actors/npc_%d.twca" % ACTOR, "bundle file named by consumer and body sprite only")
	# The same bank at another install path (another pack's folder) gives the
	# same key; the pinned source pack ID is not part of it.
	var moved: Dictionary = selection(data)
	moved.manifest_path = "/elsewhere/pack-b2162b06/source523/bank/manifest.json"
	check(STORE.entry_key(STORE.selection_inputs(moved)) == STORE.entry_key(inputs), "install location / pack ID does not change the key")
	var saved_pack: String = PINS.SOURCE_PACK_ID
	check(not STORE.entry_key(inputs).contains(saved_pack) and not STORE.entry_key(inputs).contains(FORMAT.FORMAT), "neither pack ID nor code identity inside the key")
	# FORMAT is checked by the reader, not by the key: a file of another
	# FORMAT is rejected outright (tested above), the key stays content.

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

func attach(view: Node2D, preview: Node2D) -> void:
	# What configure_admitted does after SELECTION.select (which needs the
	# real pinned tables): the same preview API calls.
	view._preview = preview
	view.add_child(preview)
	view._tracks = preview._playback_tracks
	view._mode = preview.source_playback_mode()
	for role: String in preview._playback_tracks:
		var track: Dictionary = view._tracks.get(role,{})
		view.timing_status[role] = {"effective_fps":track.get("effective_fps"),"origin":track.get("timing_origin"),"source_fps":track.get("fps")}
	view.attachment_status = preview.attachment_status()
	preview.advance_reference_source(0.0, "idle", 5)

func compare_views(data: Dictionary) -> void:
	var runtime_view: Node2D = VIEW.new()
	var cooked_view: Node2D = VIEW.new()
	root.add_child(runtime_view)
	root.add_child(cooked_view)
	var runtime: Node2D = runtime_preview(root, selection(data))
	root.remove_child(runtime)
	attach(runtime_view, runtime)
	var cooked: Node2D = cooked_preview(root, selection(data))
	root.remove_child(cooked)
	attach(cooked_view, cooked)
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

func compare_request(data: Dictionary) -> void:
	var directory: String = scratch.path_join("cooked_request")
	STORE.disabled = true
	var source: Node2D = PREVIEW.new()
	root.add_child(source)
	check(source._configure_reference_bank(data.path, data.sha, ACTOR, {"idle":3}, {"idle":false}, "idle", "overlay"), "effect request configures")
	var inputs: Dictionary = STORE.request_inputs(data.path, data.sha, ACTOR, {"idle":3}, {"idle":false}, "overlay", {})
	var cooked: Dictionary = COOKER.cook_preview(source, inputs, true)
	source.free()
	check(cooked.ok, "effect request cooks")
	var path: String = directory.path_join(FORMAT.FORMAT_TAG).path_join(STORE.file_for(inputs))
	check(COOKER.write_cooked(path, cooked.session, [cooked.entry], -1).ok, "effect request written")
	var runtime: Node2D = PREVIEW.new()
	root.add_child(runtime)
	runtime._configure_reference_bank(data.path, data.sha, ACTOR, {"idle":3}, {"idle":false}, "idle", "overlay")
	runtime._is_overlay = true
	STORE.disabled = false
	STORE.reset_for_tests()
	STORE.root_override = directory
	var played: Node2D = PREVIEW.new()
	root.add_child(played)
	check(played._configure_reference_bank(data.path, data.sha, ACTOR, {"idle":3}, {"idle":false}, "idle", "overlay") and played.cooked_actor(), "effect request plays cooked")
	played._is_overlay = true
	var looped: Node2D = PREVIEW.new()
	root.add_child(looped)
	check(looped._configure_reference_bank(data.path, data.sha, ACTOR, {"idle":3}, {"idle":true}, "idle", "overlay") and not looped.cooked_actor(), "another loop policy is not this cooked request")
	looped.free()
	var layer: Node2D = PREVIEW.new()
	root.add_child(layer)
	layer._configure_reference_bank(data.path, data.sha, ACTOR, {"idle":3}, {"idle":false}, "idle", "source_layer")
	check(not layer.cooked_actor(), "independent source layers are never cooked")
	layer.free()
	for delta: float in [0.0, 0.05, 0.1, 0.2]:
		runtime.advance_reference_source(delta, "idle", 4)
		played.advance_reference_source(delta, "idle", 4)
		check(runtime.last_source_frame == played.last_source_frame, "effect frame after %f" % delta)
		compare_draw(runtime, played, "effect %f" % delta)
	runtime.advance_reference_source(5.0, "idle", 4)
	played.advance_reference_source(5.0, "idle", 4)
	check(runtime.is_queued_for_deletion() and played.is_queued_for_deletion(), "both one-shot overlays free themselves at the end")
	STORE.root_override = scratch.path_join("cooked_lossless")
	STORE.reset_for_tests()
	STORE.root_override = scratch.path_join("cooked_lossless")
	await process_frame

func measure(runtime: Node2D, cooked_view: Node2D) -> void:
	for pair: Array in [["runtime", runtime], ["cooked", cooked_view]]:
		var view: Node2D = pair[1]
		var started: int = Time.get_ticks_usec()
		for index: int in range(200): view.advance_reference_source(0.033, "idle", index % 8)
		measured[pair[0] + "_usec_per_advance"] = float(Time.get_ticks_usec() - started) / 200.0

func gpu_compare(data: Dictionary, _actor: Dictionary) -> void:
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
			STORE.disabled = not cooked
			var view: Node2D = PREVIEW.new()
			view.cached_frames = true
			view.position = Vector2(CANVAS / 2, CANVAS / 2)
			viewport.add_child(view)
			view._configure_selected_roles(selection(data), "idle")
			check(view.cooked_actor() == cooked, "GPU view source " + str(cooked))
			STORE.disabled = false
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
