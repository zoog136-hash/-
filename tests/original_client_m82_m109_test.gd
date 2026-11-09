extends "res://tests/original_client_test_base.gd"
## M82-M109 acceptance tests (design level; the original binary is never executed, no GPU or
## pixel result is observed). Real package values come from fixture.real; synthetic inputs are
## either in fixture.synthetic or marked "synthetic" in the line that uses them.
## Optional real-byte checks (M105-R01, M108-R01) run only when OC_M82_M109_ASSET_DIR points to a
## folder holding the package's CSB/plist/PNG files; otherwise those ids are not emitted.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")
const RD = preload("res://scripts/original_client/oc_m82_m83_resource_decode.gd")
const WI = preload("res://scripts/original_client/oc_m84_m87_world_input.gd")
const IS = preload("res://scripts/original_client/oc_m88_m91_image_sprite.gd")
const SC = preload("res://scripts/original_client/oc_m92_m94_stencil_clear.gd")
const SP = preload("res://scripts/original_client/oc_m95_m99_spell_state.gd")
const SH = preload("res://scripts/original_client/oc_m96_m106_shader_source.gd")
const QS = preload("res://scripts/original_client/oc_m100_m102_quickslot.gd")
const TC = preload("res://scripts/original_client/oc_m103_m108_timeclear.gd")
const WK = preload("res://scripts/original_client/oc_m104_m109_walker.gd")
const FIXTURE_PATH := "res://data/original_client/fixtures/m82_m109_fixture.json"

var fx: Dictionary = {}
var real: Dictionary = {}
var syn: Dictionary = {}

func run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	fx = parsed if parsed is Dictionary else {}
	check("FIXTURE", not fx.is_empty(), "fixture could not be read")
	if fx.is_empty():
		finish("ORIGINAL_CLIENT_M82_M109_RESULT")
		return
	real = fx.real
	syn = fx.synthetic
	m82(); m83(); m84(); m85(); m86(); m87(); m88(); m89(); m90(); m91(); m92(); m93(); m94()
	m95(); m96(); m97(); m98(); m99(); m100(); m101(); m102(); m103(); m104(); m105(); m106()
	m107(); m108(); m109(); raw_assets()
	finish("ORIGINAL_CLIENT_M82_M109_RESULT", {"fixture_id": fx.get("fixture_id", ""), "fixture_sha256": FileAccess.get_sha256(FIXTURE_PATH)})

func m82() -> void:
	var files: Dictionary = real.m82_sp2.files
	var total_records := 0
	for logical: String in files:
		var f: Dictionary = files[logical]
		var b: PackedByteArray = V.hex_to_bytes(f.hex)
		check("M82-A01", V.sha256_bytes(b) == f.sha256 and b.size() == int(f.length), logical + " real bytes hash")
		var nat: Dictionary = RD.native_fe_metadata(b)
		check("M82-A01", nat.accepted and nat.palette_count == 1 and nat.palette == [0] and nat.mask_at == 4 and nat.mask == 0 and nat.cursor == 5 and nat.directions.is_empty(), logical + " native byte4 mask0 / cursor5 / no direction")
		var alt: Dictionary = RD.alternate_alignment_annotation(b)
		check("M82-A01", alt.annotation_only and not alt.native_success and alt.valid and alt.mask_at == 8 and alt.mask == int(f.alternate_mask) and alt.directions.size() == int(f.alternate_directions) and alt.records == int(f.alternate_records), logical + " byte8 annotation kept separate")
		check("M82-A01", alt.inverted_bounds == alt.records and 9 + 5 * alt.directions.size() + 10 * alt.records == b.size(), logical + " 9+5d+10r == size, all bboxes inverted")
		check("M82-A01", nat.mask != alt.mask, logical + " the two alignments disagree on the same bytes")
		total_records += int(alt.records)
	check("M82-A01", total_records == 705 and files.size() == 4, "705 empty records over the four selected files")
	var nf: Dictionary = real.m82_sp2.non_fe
	var nb: PackedByteArray = V.hex_to_bytes(nf.prefix32_hex)
	check("M82-X1", RD.native_fe_metadata(nb).accepted == false, "non-FE marker 08 is false")
	var cand: Dictionary = RD.forced_frame_stream_candidate(nb)
	check("M82-X1", cand.frame_count == 8 and cand.bbox == [-1, -88, 53, 4] and cand.fragments == 64512 and cand.required_end == 322571 and 322571 > int(nf.length), "forced candidate needs 322571 > 48981 bytes")
	var p0 := PackedByteArray([0xFE, 0x00])
	p0.resize(2 + 512 + 1)
	check("M82-X2", RD.native_fe_metadata(p0).palette_count == 256, "palette count 0 means 256 (synthetic bytes)")

func m83() -> void:
	var entry: Dictionary = RD.make_image()
	var r: Dictionary = RD.png_decode(entry, "pixel_malloc_null", 64, 64, 6, 256)
	var img: Dictionary = r.image
	check("M83-A01", not r.ok and not r.rollback and img.width == 64 and img.height == 64 and img.render_format == 2 and img.length == 16384 and img.data == null, "malloc null keeps W/H/F/N, P=null, no rollback")
	check("M83-A01", r.row_table_freed_by_wrapper and img.premultiplied == 0, "only the row table is freed")
	var t: Dictionary = RD.png_decode(entry, "transform_error", 32, 16, 6, 128)
	check("M83-X1", t.image.width == 32 and t.image.height == 16 and t.image.render_format == -1 and t.image.data == null, "error after read_info keeps W/H")
	check("M83-X1", RD.png_decode(entry, "signature", 64, 64, 6, 256).image == entry, "signature mismatch writes nothing")
	var unk: Dictionary = RD.png_decode(entry, "success", 8, 8, 5, 32)
	check("M83-X1", unk.ok and unk.image.render_format == -1 and unk.image.premultiplied == 0, "unsupported colour keeps F, no separate failure; premultiply only colour6")
	check("M83-X1", RD.png_decode(entry, "read_image_error", 8, 8, 6, 32).evidence == V.CONDITIONAL, "read_image error false is conditional")
	check("M83-X2", RD.row_loop_terminates(65535).terminates and RD.row_loop_terminates(65536).status == V.REJECTED_UNDEFENDED, "H65536 rejected (16-bit counter), 65535 ok")
	var io: Dictionary = RD.io_callback_check(0x7ffffff0, 32, 1000)
	check("M83-X2", io.error_callback == false and io.status == V.REJECTED_UNDEFENDED, "signed32 end wraps negative: passes original check, flagged")
	check("M83-X2", RD.io_callback_check(990, 32, 1000).error_callback, "plain overrun calls the error callback")
	var tex: Dictionary = RD.texture_init({"width": 4096, "height": 8}, 2048)
	check("M83-X3", not tex.ok and tex.filename_already_written and tex.events.find("copy_filename") < tex.events.find("size_reject"), "filename copied before size guard")
	check("M83-X3", RD.texture_init({"width": 0, "height": -5}, 2048).ok, "0/negative not rejected by the size guard")

func m84() -> void:
	var mp: Dictionary = {}
	var on: Dictionary = WI.power_set({"byte31": 0, "byte51": 0}, 0, mp)
	check("M84-A01", not on.skipped and on.owner.byte31 == 1 and on.visible == false and on.events[0] == "byte31=1" and on.events[2].begins_with("update"), "state0 set: write state before update")
	check("M84-A01", WI.power_set({"byte31": 1}, 0, mp).skipped and not WI.power_set({"byte31": 1}, 1, mp).skipped, "state1 force0 skip, force1 runs")
	check("M84-A01", not WI.power_set({"byte31": 2}, 0, mp).skipped and not WI.power_clear({"byte31": 2, "byte51": 1}, 0, mp).skipped, "other nonzero state2 is neither exact1 nor exact0")
	check("M84-A01", WI.power_clear({"byte31": 0}, 0, mp).skipped and not WI.power_clear({"byte31": 0, "byte51": 3}, 1, mp).skipped, "clear: state0 force0 skip, force1 runs")
	var cl: Dictionary = WI.power_clear({"byte31": 1, "byte51": 1}, 0, on.map)
	check("M84-X1", cl.map.has(WI.KEY_POWER) and cl.map[WI.KEY_POWER] == 0 and cl.visible, "0 is a retained value, not erase")
	check("M84-X1", WI.skip_update({"a": 2}, "b", 0).visible, "only exactly 1 blocks visibility (synthetic byte 2)")
	var g1: Dictionary = WI.app_gate(false, true)
	check("M84-X2", g1.gate == false and g1.calls == 2 and g1.second_value == 4, "0 then 4 across two calls: gate false (compare 5 never hits)")
	check("M84-X2", WI.app_gate(true, false).gate and WI.app_slot("+10", true, {}).events.is_empty(), "gate true skips event and blocker")
	var groups := {"A": ["la"], "B": ["lb", "la"], "C": ["lc"]}
	check("M84-X3", WI.layout_event(true, "la", 1, groups, {}).events.has("publish093D") and not WI.layout_event(true, "la", 1, groups, {}).map.has(WI.KEY_LAYOUT), "A membership publishes 93D and sets no blocker")
	check("M84-X3", WI.layout_event(true, "lb", 1, groups, {}).map.get(WI.KEY_LAYOUT) == 1 and WI.layout_event(true, "la", 0, groups, {}).map.get(WI.KEY_LAYOUT) == 0, "clear uses pure B membership")
	check("M84-X3", WI.layout_event(false, "lb", 1, groups, {}).events.is_empty(), "typed cast failure skips")
	check("M84-X4", WI.glfw_focus_event_name(1) == "glview_window_focused" and WI.glfw_focus_event_name(-1) == "glview_window_unfocused" and WI.glfw_focus_event_name(2) == "glview_window_unfocused", "exact focused==1")

func m85() -> void:
	check("M85-A01", WI.caller_next_gate(false, 2) and not WI.caller_next_gate(true, 1) and WI.caller_next_gate(false, -1), "AL ignored; unsigned list size >= 2")
	var a: Dictionary = WI.caller_01F5E8D0(4)
	check("M85-A01", a.range == 2 and WI.caller_01F5E8D0(3).range == 1 and a.rayAllow40 == 0 and a.callbackMode == 0 and a.distanceOnly == 0 and a.callback == "01F84C00", "01F5E8D0 arguments")
	check("M85-X1", WI.caller_01C0E470(5, 9).callbackMode == 1 and WI.caller_01C0E470(5, 9).range == 1 and WI.caller_01C0E470(12, 9).range == 9 and WI.caller_01C0E470(43, 9).callbackMode == 0 and WI.caller_01C0E470(2, 9).callbackMode == 0, "category mask {5,12,32,42}")
	check("M85-X2", WI.abs32(-2147483648) == -2147483648 and WI.abs32(-5) == 5, "abs32 INT_MIN anomaly preserved")
	check("M85-X2", WI.distance_predicate(Vector2i(4, 1), Vector2i(0, 0), 2) and not WI.distance_predicate(Vector2i(6, 0), Vector2i(0, 0), 2), "x halved by sar (synthetic points)")
	check("M85-X2", WI.accept_budget(1) == 12 and WI.accept_budget(2) == 16 and WI.accept_budget(-1) == 4, "budget = trunc(range*8/2)+8")
	check("M85-X3", WI.search_prologue(Vector2i(1, 1), Vector2i(1, 1), 0, false).returned and not WI.search_prologue(Vector2i(0, 0), Vector2i(1, 1), -1, true).returned, "range must be signed >0 for initial H")

func m86() -> void:
	var full: Array = WI.cleanup_trace(true, true)
	check("M86-A01", full.find("current_shutdown") < full.find("current_delete") and full.find("current_delete") < full.find("pending_global_null") and full.find("pending_packet_release") < full.find("pending_root_free"), "normal-progress order")
	var cut: Array = WI.cleanup_trace(true, true, "vector20_clear")
	check("M86-A01", cut[-1] == "vector20_clear" and not cut.has("pending_global_null") and not cut.has("vector38_clear"), "abort leaves a prefix only")
	check("M86-A01", WI.cleanup_trace(false, true)[0] == "pending_global_null", "null current singleton has no current stage")
	check("M86-X1", WI.relative_order("pool_shutdown", "current_delete") == V.UNKNOWN and WI.relative_order("weak_oid_clear", "vector38_clear") == "BEFORE" and WI.relative_order("pending_root_free", "current_shutdown") == "AFTER", "pool order UNKNOWN, recorded edges kept")
	check("M86-X1", WI.ACTOR_OWNERS == ["current+08", "current+20", "current+38"] and WI.NOT_ACTOR_OWNERS["current OID weak tree"] == "weak", "owner kinds kept apart")

func m87() -> void:
	var w: Dictionary = WI.make_window()
	w.key[5] = 1; w.key[3] = 3; w.key[348] = 1; w.mouse[7] = 1
	w["sticky_key"] = 1
	var got: Array = []
	var focus_cb := func(win: Dictionary, _f: int) -> void: win.key[10] = 1
	var key_cb := func(win: Dictionary, key: int, action: int, _m: int) -> void:
		got.append([key, action, win.key[key]])
		if key == 5:
			win.key[7] = 1
			win.key[2] = 1
	WI.focus_changed(w, 0, focus_cb, key_cb, Callable())
	var keys: Array = got.map(func(x: Array) -> int: return x[0])
	check("M87-A01", keys == [5, 7, 10, 348], "callback-written later key 7 and focus-callback key 10 released live; passed key 2 not revisited: %s" % str(keys))
	check("M87-A01", w.key[3] == 3 and w.key[2] == 1 and got.all(func(x: Array) -> bool: return x[1] == 0 and x[2] == 3), "sticky: state3 written before callback, action stays 0; state3 key not selected")
	check("M87-A01", w.mouse[7] == 0, "mouse 0..7 released (non-sticky -> 0)")
	var w2: Dictionary = WI.make_window()
	w2.key[1] = 1
	WI.focus_changed(w2, -1, Callable(), Callable(), Callable())
	check("M87-X1", w2.key[1] == 1 and (w2.log as Array).has("custom:glview_window_unfocused"), "focus -1: unfocused custom event, no native release loop")
	var gk: Dictionary = WI.game_key_release([26], 26, false, true)
	check("M87-X2", gk.held == [26] and gk.event == null, "block31 ignores directional release; no other clear implied")
	check("M87-X2", WI.game_key_release([26, 27], 26, false, false).event == "C4" and WI.game_key_release([26], 26, false, false).event == "C5", "C4/C5")

func m88() -> void:
	check("M88-A01", IS.pma_channel(128, 1) == 1 and floori(128.0 / 255.0) == 0 and IS.pma_channel(255, 0) == 0 and IS.pma_channel(77, 255) == 77, "floor(C*(A+1)/256), not /255")
	var mismatches := 0
	for c: int in 256:
		for a: int in 256:
			if IS.pma_channel(c, a) != (c * (a + 1)) / 256:
				mismatches += 1
	check("M88-A01", mismatches == 0, "65536 pairs match the integer formula")
	for p: Dictionary in syn.m88_pixels:
		var px := PackedByteArray(p.rgba)
		var on: Dictionary = IS.premultiply(px, 1, 1, 1, 6)
		var hex_on: String = IS.rgb565_le_hex(on.pixels[0], on.pixels[1], on.pixels[2])
		check("M88-A01", hex_on == p.pma_on_rgb565_le, "synthetic %s on -> %s" % [str(p.rgba), hex_on])
		if p.has("pma_off_rgb565_le"):
			check("M88-A01", IS.rgb565_le_hex(px[0], px[1], px[2]) == p.pma_off_rgb565_le, "synthetic off")
	check("M88-X1", IS.premultiply(PackedByteArray([9, 9, 9, 0]), 1, 1, 0, 6).flag == 0 and IS.premultiply(PackedByteArray([9, 9, 9, 0]), 1, 1, 1, 2).flag == 0, "needs global!=0 and colour6")
	check("M88-X1", IS.premultiply(PackedByteArray(), 0, 5, 1, 6).flag == 1, "w*h<=0: flag1, no loop")
	var src := PackedByteArray([255, 0, 0, 255, 0, 255, 0, 255])
	var cv: Dictionary = IS.convert(src, 8, 2, 4)
	check("M88-X2", cv.format == 4 and cv.out_length == 4 and cv.out.hex_encode() == "00f8e007", "format enum result, LE words")
	check("M88-X2", IS.convert(src, 8, 2, 2).aliased and IS.convert(src, 8, 2, 0).aliased, "requested==source or 0 aliases")
	var c6: Dictionary = IS.convert(PackedByteArray([1, 2, 3, 4, 5, 6]), 6, 2, 4)
	check("M88-X2", c6.out_length == 3 and c6.pixels_written == 1 and c6.uninitialised_tail_bytes == 1, "N6: alloc3/write2")
	check("M88-X2", IS.convert(src, 8, 2, 4, false).status == V.REJECTED_UNDEFENDED and IS.convert(src, -4, 2, 4).status == V.REJECTED_UNDEFENDED, "malloc-null / negative length rejected, not 'safe false'")
	check("M88-X3", IS.DESCRIPTORS[4].type == 0x8363 and IS.DESCRIPTORS[4].alpha == false and str(real.m88_png.descriptor_key4_hex[2]) == "8363", "format4 is RGB565 (real descriptor)")
	check("M88-X3", int(real.m88_png.alpha255_count) == 4096 and int(real.m88_png.rgba_bytes) / 2 == int(real.m88_png.rgb565_bytes), "real 64x64 fixture is all alpha255: on/off identical, translucent cases synthetic")

func m89() -> void:
	check("M89-A01", IS.vertex_channel(128, 1, true) == 0 and IS.pma_channel(128, 1) == 1, "Sprite truncation differs from Image PMA at C128 A1")
	check("M89-A01", IS.vertex_channel(128, 128, true) == 64 and IS.vertex_channel(200, 0, true) == 0 and IS.vertex_channel(200, 255, true) == 200 and IS.vertex_channel(200, 3, false) == 200, "binary32 divide -> multiply -> trunc")
	var cases := [[false, true, 2], [true, true, 0], [false, false, 1], [true, false, 1]]
	for cs: Array in cases:
		var s: Dictionary = IS.make_sprite({"premultiplied_flag": 0}, cs[1])
		var tex := {"premultiplied_flag": 1 if cs[0] else 0, "id": "new"}
		var r: Dictionary = IS.icon_apply(s, 1, tex, true)
		check("M89-A01", r.suffix_applied and s.blend == [1, 1] and s.modifier == true and s.update_color_calls == cs[2], "flag %s initial %s -> %d refreshes, got %d" % [str(cs[0]), str(cs[1]), cs[2], s.update_color_calls])
	var t0 := {"premultiplied_flag": 0}
	var same: Dictionary = IS.make_sprite(t0, false)
	IS.icon_apply(same, 1, t0, true)
	check("M89-X1", same.update_color_calls == 1, "same pointer: no internal refresh, caller true once")
	var m3: Dictionary = IS.make_sprite(null, true, 3)
	IS.icon_apply(m3, 1, {"premultiplied_flag": 1}, true)
	check("M89-X1", m3.update_color_calls == 0 and m3.texture == null, "mode3 skips tail; modifier already true")
	check("M89-X2", IS.icon_apply(IS.make_sprite(null, false), 101, t0, true).suffix_applied == false and IS.icon_apply(IS.make_sprite(null, false), 1, null, true).branch == "loader_null_hide", "101 branch and loader-null hide are separate")
	var plain: Dictionary = IS.make_sprite(null, false)
	IS.set_texture(plain, {"premultiplied_flag": 1})
	check("M89-X2", plain.blend == [1, 771], "default pair from Texture flag before the override")

func m90() -> void:
	check("M90-A01", IS.selection_prefix({"program_state": "existing"}, {"field78": {"dword1C": 7}}).requested == false, "nonnull root+1C8 preserves, no request")
	check("M90-A01", IS.selection_prefix({"program_state": null}, null).name == "ShaderPositionTextureColor_noMVP", "null state + null texture -> original name")
	check("M90-X1", IS.program_name({"field78": {"dword1C": 0xFFFFFFFF}}, "ShaderPositionTextureColor_noMVP") == "#ShaderETC1ASPositionTextureColor_noMVP" and IS.program_name({"field78": null}, "ShaderUIGrayScale") == "ShaderUIGrayScale" and IS.program_name({"field78": {"dword1C": 3}}, "Other") == "Other", "nonzero DWORD + exact name swap")
	var cache: Dictionary = {"p": null}
	check("M90-X2", IS.state_cache_get(cache, "p", true, true, true).result == null and IS.state_cache_get(cache, "p", true, true, true).hit, "hit returns stored null as is")
	var f: Dictionary = IS.state_cache_get({}, "q", true, true, false)
	check("M90-X2", f.result != null and f.events == ["init", "release(RBX)"] and f.evidence == V.UNKNOWN, "init false returns released bits, not null")
	var root := {"program_state": "old"}
	check("M90-X3", IS.node_set_program_state(root, "new") == ["release(old)", "store", "retain(incoming)", "bind(state+128=root)"] and IS.node_set_program_state(root, "new").is_empty(), "setter order; equal is no-op")

func m91() -> void:
	check("M91-X1", IS.fnv1a_pointer(0) == -6284781860667377211 and IS.fnv1a_pointer(0x180596068) == -1859618229060838563, "FNV-1a over the 8 pointer bytes (64-bit patterns; synthetic pointer values)")
	var c: Dictionary = IS.make_cache()
	var fm: Dictionary = IS.fresh_miss(c, 77, "cand", "prog")
	check("M91-A01", fm.sequence == [1, 2, 1] and fm.program_refs == 2, "fresh miss 1->2->1, program +1 separately")
	var dup: Dictionary = IS.lower_insert(c, 77, "other", false, false)
	check("M91-A01", dup.flag == 0 and dup.payload == "cand" and dup.path == "first_lookup_duplicate", "first-lookup duplicate keeps payload, flag0")
	var grown: Dictionary = IS.lower_insert(c, 77, "other", true, true)
	check("M91-A01", grown.flag == 1 and grown.path == "insertion_position_after_growth" and grown.evidence == V.UNKNOWN, "growth reprobe equality is NOT the flag0 branch")
	var c2: Dictionary = IS.make_cache()
	c2.nodes[5] = ["old"]
	c2.refs["old"] = 1
	var rep: Dictionary = IS.insert_helper(c2, 5, "old")
	check("M91-X2", rep.events[0] == "retain(candidate)" and rep.events[1] == "release(old)" and c2.refs["old"] == 1, "replacement retains before releasing: same object net 0")

func m92() -> void:
	var mgr: Dictionary = SC.make_manager()
	var b31: Dictionary = SC.before(mgr, 30, {})
	check("M92-A01", b31.layer == 31 and b31.bit_raw32 == 0x80000000 and b31.cumulative_raw32 == 0xFFFFFFFF, "layer31 raw32 kept")
	check("M92-A01", b31.requests[5] == ["glStencilFunc", SC.GL_NEVER, 0x80000000, 0x80000000], "CPU request uses raw32 for ref and mask")
	check("M92-A01", V.i32(0x80000000) == -2147483648 and SC.effective_ref(0x80000000, 32) == 0 and SC.effective_ref(0xFFFFFFFF, 32) == 0, "signed GLint ref clamps to 0 (API model)")
	check("M92-A01", SC.api_replace(0, 0x80000000, 0x80000000, 32) == 0 and SC.api_equal(0, 0xFFFFFFFF, 0xFFFFFFFF, 32), "REPLACE cannot set bit31; zero stencil passes EQUAL")
	var b32: Dictionary = SC.before(SC.make_manager(), 31, {})
	check("M92-A01", b32.layer == 32 and b32.bit_raw32 == 1 and b32.cumulative_raw32 == 1, "layer32 low5bit alias, not clamped")
	var b7: Dictionary = SC.before(SC.make_manager(), 6, {})
	check("M92-X1", SC.effective_ref(b7.cumulative_raw32, 8) == 0xFF and SC.api_equal(0xFF, b7.cumulative_raw32, b7.cumulative_raw32, 8) and not SC.api_equal(0x7F, b7.cumulative_raw32, b7.cumulative_raw32, 8), "normal intersection for 0<=layer<min(B,31) (synthetic B=8)")
	var inv: Dictionary = SC.before(SC.make_manager(1.0, 1), 0, {})
	check("M92-X2", inv.requests[6][1] == SC.GL_REPLACE and inv.requests[9][1] == SC.GL_ZERO and not inv.requests.any(func(r: Array) -> bool: return r[0] == "glEnable" and r[1] == "ALPHA_TEST"), "inverted ops; threshold 1.0 skips alpha")
	check("M92-X2", SC.before(SC.make_manager(0.5), 0, {}).requests.any(func(r: Array) -> bool: return r[0] == "glAlphaFunc"), "threshold<1 adds alpha")
	var m := SC.make_manager()
	SC.before(m, 0, {"func": 0x207, "ref": 0, "value_mask": 0xFF, "sfail": SC.GL_KEEP, "zfail": SC.GL_KEEP, "zpass": SC.GL_KEEP, "write_mask": 0xFF, "stencil_enabled": 1, "depth_write_raw": 1})
	var av: Dictionary = SC.after_visit(m, 1)
	check("M92-X3", av.layer == 0 and not av.requests.any(func(r: Array) -> bool: return r[0] in ["glEnable", "glDepthMask"]), "partial restore, no re-enable")

func m93() -> void:
	var st := {"byte12": 0, "bits4C": 0xFFFFFFFF}
	SC.set_depth_write(st, 0)
	check("M93-A01", st.bits4C == 0xFFFFFFEF and st.byte12 == 0, "bit10 is mask 0x10")
	SC.set_depth_write(st, 2)
	check("M93-A01", st.byte12 == 2 and (st.bits4C & 0x10) == 0x10, "raw DL 2 stored")
	var m := SC.make_manager()
	SC.before(m, 0, {"depth_write_raw": 2})
	var ad: Array = SC.after_draw(m)
	var gl_req: Array = ad.filter(func(r: Array) -> bool: return r[0] == "glDepthMask")[0]
	var helper: Array = ad.filter(func(r: Array) -> bool: return r[0] == "setDepthWrite(default)")[0]
	check("M93-A01", gl_req[1] == 2 and helper[1] == 1, "raw GLboolean2 request vs canonical helper 1 are different bytes")
	var cache := {"bits": 0x10, "depth_write": 1}
	var nr: Array = SC.bind_no_restore_depth(cache, {"bits4C": 0, "byte12": 0})
	check("M93-X1", nr.is_empty() and cache.depth_write == 1, "no-restore false source does not reset true cache")
	var cache2 := {"bits": 0x10, "depth_write": 1}
	var br: Array = SC.bind(cache2, {"bits4C": 0x01, "byte12": 0})
	check("M93-X1", br == [["glDepthMask", 0]] and cache2.depth_write == 0 and cache2.bits == 0x01, "bind = restore then no-restore (not interchangeable)")
	var dst := {"callable": {"target": "x"}}
	var bs: Dictionary = SC.bind_stencil_callable(dst, "00231760", null)
	check("M93-X2", bs.events[0].begins_with("destroy") and dst.callable.retained == false and dst.callable.manager == null and bs.manager_null_guard_on_invoke == false, "raw manager copy, null kept, no guard")

func m94() -> void:
	var lit: Dictionary = real.m94_literals
	for name: String in lit.texts:
		check("M94-A01", V.sha256_text(lit.texts[name]) == lit.sha256_without_nul[name], "real literal hash " + name)
	var lc: Dictionary = SC.literal_contract(lit.texts["vertex.glsl"], lit.texts["fragment.glsl"])
	check("M94-A01", lc.uses_u_color and lc.uses_mvp and lc.declares_a_position and not lc.declares_aVertex and lc.fragment_passthrough and lc.gpu_result == V.NOT_OBSERVED, "u_color / CC_MVPMatrix requested names in real literals; no GPU claim")
	check("M94-A01", lit.texts["program_key.txt"] == SC.PROGRAM_KEY and lit.texts["aVertex.txt"] == SC.EXPLICIT_BIND[0], "program key and explicit bind name")
	var table := {}
	var fail: Dictionary = SC.register_type10(table, "p1", 0)
	check("M94-X1", fail.handle == 0 and fail.inserted and fail.events.has("updateUniforms") and not fail.usable_program_claimed, "link fail still updates and inserts the name")
	var dup: Dictionary = SC.register_type10(table, "p2", 1)
	check("M94-X1", not dup.inserted and table[SC.PROGRAM_KEY] == "p1", "duplicate keeps existing payload")

func m95() -> void:
	var j: Dictionary = real.m95_m97_current525_joins
	var rows := {}
	var lists := {}
	for sid: String in j.spells:
		var l: Array = []
		for r: Dictionary in j.spells[sid]:
			rows[int(r.bonus)] = {"type": int(r.type), "value": int(r.value)}
			l.append(int(r.bonus))
		lists[int(sid)] = l
	# real IDs 34922 / 89112 and Bonus rows; tree188 counters are synthetic
	var world := {"bonus_lists": lists, "bonus_rows": rows, "tree188": {34922: {"current": 1, "packet_max": 0, "active": 1}, 89112: {"current": 5, "packet_max": 0, "active": 4}}}
	check("M95-A01", SP.stackable_admission(world, 34922).result == "continue_next_validation", "34922: active1 < max2 continues (not success)")
	var at_max: Dictionary = SP.stackable_admission(world, 89112)
	check("M95-A01", at_max.result == "false" and at_max.code == SP.RESULT_ACTIVE_AT_MAX, "89112: active4 >= max4 -> D1E4")
	var w0 := {"bonus_lists": {1: [10, 11, 12]}, "bonus_rows": {10: {"type": 9492, "value": 0}, 11: {"type": 9482, "value": 0}, 12: {"type": 9482, "value": 7}}, "tree188": {1: {"current": 3, "packet_max": 0, "active": 0}}}
	var first0: Dictionary = SP.stackable_admission(w0, 1)
	check("M95-A01", first0.result == "false" and first0.code == SP.RESULT_ACTIVE_AT_MAX, "first max 0 wins over later 7 (synthetic)")
	var tr: Array = first0.trace
	check("M95-A01", tr.count("remap_id(1)") == 4 and tr.find("tree188_lookup(1).current") < tr.find("tree188_lookup(1).active"), "each getter remaps separately, in call order")
	w0.tree188[1].current = 0
	var d1da: Dictionary = SP.stackable_admission(w0, 1)
	check("M95-X1", d1da.code == SP.RESULT_CURRENT_NOT_POSITIVE and not (d1da.trace as Array).has("tree188_lookup(1).active"), "current<=0: D1DA, later reads skipped")
	check("M95-X1", SP.stackable_admission({"bonus_lists": {}, "tree188": {}}, 9).result == "continue_next_validation", "no membership: continue")
	var cyc := {"remap": [[1, 2], [2, 1]], "bonus_lists": {}}
	check("M95-X2", SP.stackable_admission(cyc, 1).result == "rejected_input", "remap cycle flagged, no invented reject message")
	var chain := {"remap": [[1, 2], [2, 3]], "bonus_lists": {3: [10]}, "bonus_rows": {10: {"type": 9492, "value": 1}}, "tree188": {3: {"current": -1, "packet_max": 0, "active": 0}}}
	check("M95-X2", SP.stackable_admission(chain, 1).code == SP.RESULT_CURRENT_NOT_POSITIVE, "remap restarts; negative current not normalised")

func m96() -> void:
	check("M96-A01", SH.compile_stage(SH.GL_VERTEX_SHADER, null, "", "", "", 1).out_written == false, "source-null helper: false, no out write")
	var both: Dictionary = SH.init_program(null, null, "", "P", "", null, null)
	check("M96-A01", both.result == true and both.requests[0] == ["glCreateProgram"] and both.requests.size() == 1, "both-null caller: program created, true, nothing attached")
	var vfail: Dictionary = SH.init_program("v", "f", "", "P", "", 0, 1)
	check("M96-A01", vfail.result == false and not vfail.fragment_reached and vfail.program.vertex == "vs", "vertex status0 stops before fragment; handles kept")
	check("M96-A01", SH.compile_stage(SH.GL_FRAGMENT_SHADER, "f", "", "", "", 2).result == false and SH.compile_stage(SH.GL_FRAGMENT_SHADER, "f", "", "", "", 1).result, "status2 is not success (==1)")
	check("M96-A01", SH.compile_stage(SH.GL_FRAGMENT_SHADER, "f", "", "", "", null).status == V.REJECTED_UNDEFENDED, "unwritten status rejected")
	var pre: Dictionary = real.m96_prelude
	var pb: PackedByteArray = V.hex_to_bytes(pre.hex_with_nul)
	check("M96-X1", pb.size() == int(pre.bytes) + 1 and V.sha256_bytes(pb.slice(0, int(pre.bytes))) == pre.sha256, "real prelude 425 bytes")
	var cs: Dictionary = SH.compile_stage(SH.GL_VERTEX_SHADER, "SRC", "H", pb.slice(0, int(pre.bytes)).get_string_from_utf8(), "D", 1)
	check("M96-X1", cs.requests[1][1] == 4 and cs.requests[1][2][0] == "H" and cs.requests[1][2][3] == "SRC" and (cs.requests[1][2][1] as String).ends_with("//CC INCLUDES END\n\n") and cs.requests[1][3] == null, "four fragments, no lengths array")
	check("M96-X2", SH.transform_defines("", "keep") == "keep" and SH.transform_defines("A;;B=1", "") == "\n#define A\n#define B=1\n" and SH.transform_defines("X", "") == "\n#define X\n", "define transform, empty leaves output")

func m97() -> void:
	var j: Dictionary = real.m95_m97_current525_joins
	var links: Array = []
	var bonus := {}
	for r: Dictionary in j.spells["34922"]:
		links.append({"spell_id": 34922, "bonus_id": int(r.bonus), "min_spell_level": 99})  # level 99 synthetic: must not filter
		bonus[int(r.bonus)] = {"id": int(r.bonus), "type": int(r.type)}
	links.append({"spell_id": 34922, "bonus_id": 1628382, "min_spell_level": 0})  # synthetic duplicate
	links.append({"spell_id": 34922, "bonus_id": 424242, "min_spell_level": 0})   # synthetic missing link
	var v: Dictionary = SP.build_bonus_vector(34922, links, bonus)
	var ids: Array = v.vector8.map(func(x: Dictionary) -> int: return int(x.id))
	check("M97-A01", ids == [1628382, 1628392, 1628382], "native row order, duplicate kept, missing skipped: %s" % str(ids))
	check("M97-A01", not (v.read_fields as Array).has("MinSpellLevel"), "MinSpellLevel not read")
	var cache := {}
	var mgr := {34922: v}
	var first: Dictionary = SP.cache_list(cache, mgr, 34922)
	mgr.erase(34922)
	var again: Dictionary = SP.cache_list(cache, mgr, 34922)
	check("M97-X1", first.producer_called and again.hit and not again.producer_called and again.list == first.list, "initialised hit returns cached list (stale allowed)")
	check("M97-X1", SP.cache_list(cache, mgr, 5).list.is_empty() and SP.cache_list(cache, mgr, 5).hit, "manager miss caches an empty list")

func m98() -> void:
	var flags: int = SH.location_flags(0xABCD00, {"MVP": -2, "P": -1, "MV": 0}, [-1, -1, 7])
	check("M98-A01", (flags & 0x04) != 0 and (flags & 0x20) == 0 and (flags & 0x10) != 0 and (flags & 0x01) != 0 and (flags & ~0xFF) == 0xABCD00, "flag != -1: -2 on, -1 off, 0 on; time any")
	var cache := {}
	check("M98-A01", SH.uniform4fv(cache, -2, PackedFloat32Array([1, 1, 1, 1]), 1).is_empty() and not cache.has(-2), "-2: flag on but cache admission/request skipped")
	check("M98-A01", SH.uniform4fv(cache, 0, PackedFloat32Array([0.0, 1, 1, 1]), 1).size() == 1 and SH.uniform4fv(cache, 0, PackedFloat32Array([0.0, 1, 1, 1]), 1).is_empty(), "same bytes skip")
	var negz: float = 0.0
	negz = -negz
	check("M98-A01", negz == 0.0 and SH.uniform4fv(cache, 0, PackedFloat32Array([negz, 1, 1, 1]), 1).size() == 1, "-0.0 == 0.0 as float but different bytes -> request")
	var big := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8])
	var c2 := {}
	SH.admit(c2, 3, big)
	SH.admit(c2, 3, PackedByteArray([9, 9]))
	check("M98-X1", c2[3].size == 8 and c2[3].bytes == PackedByteArray([9, 9, 3, 4, 5, 6, 7, 8]), "shrink keeps stored size and suffix")
	check("M98-X1", SH.uniform_matrix4fv({}, 4, PackedFloat32Array(range(16)), 1)[0] == ["glUniformMatrix4fv", 4, 1, 0], "matrix request count<<6 bytes, transpose 0")

func m99() -> void:
	var tree := {}
	var h: Dictionary = SP.handle_packet363(tree, {"dword10": 34922, "dword14": 5, "dword18": 9, "dword1C": 1})  # real spell ID 34922, synthetic values
	check("M99-A01", h.events == ["writer", "map{spellId:34922}", "sink(event8A1)"] and tree[34922] == {"current": 5, "packet_max": 9, "active": 1}, "writer then event")
	SP.handle_packet363(tree, {"dword10": 34922, "dword14": 0, "dword18": -3, "dword1C": 0x80000000})
	check("M99-A01", tree.size() == 1 and tree[34922] == {"current": 0, "packet_max": -3, "active": -2147483648}, "zero/negative overwrite, no erase/clamp")
	var again: Dictionary = SP.handle_packet363(tree, {"dword10": 34922, "dword14": 0, "dword18": -3, "dword1C": 0x80000000})
	check("M99-X1", again.events.has("sink(event8A1)"), "identical values still dispatch")
	check("M99-X1", SP.handle_packet363({}, {"dword10": 1, "dword14": 1, "dword18": 1, "dword1C": 1}, false).events[2] == "sink(null_event)", "null event still requests the sink")
	var w := {"remap": [[34922, 77]], "tree188": tree}
	check("M99-X2", SP.packet_max_get(w, 34922).value == 0, "raw-key writer vs remapped reader: miss returns 0 while raw stays")
	check("M99-X2", SP.packet_max_get({"tree188": tree}, 34922).value == -3, "packet node+24 getter")
	check("M99-X3", SP.parse363([[0x08, 1], [0x10, 2], [0x08, 3]]) == {"dword10": 3, "dword14": 2, "dword18": 0, "dword1C": 0}, "absent fields stay 0, last duplicate wins")
	SP.reset529(tree)
	check("M99-X3", tree.is_empty(), "reset529 clears")

func _qs_world() -> Dictionary:
	# synthetic slots/rows; 34922 used as a real spell ID label only
	var mapping := PackedByteArray()
	mapping.resize(0x30)
	mapping.encode_s32(0x24, 501)
	mapping.encode_s32(0x20, 999)  # decoy at payload+0x18
	var loaded := PackedByteArray()
	loaded.resize(0x30)
	loaded[0x28] = 1
	loaded[0x20] = 0   # decoy: full-row+0x20 must NOT be read
	return {"slots": {1000: {"metadata_id": 34922, "dword10": 7001, "is_spell": true}}, "mapping_rows": {7001: mapping}, "loaded_rows": {501: loaded, 999: loaded},
		"service_c0": {}, "reload_90": {}, "reads": [], "stackable": func(_id: int) -> bool: return true, "stack_count": func(_id: int) -> int: return 3}

func m100() -> void:
	var w: Dictionary = _qs_world()
	w.loaded_rows[501] = w.loaded_rows[501].duplicate()
	w.loaded_rows[501][0x28] = 0
	var r: Dictionary = QS.on_event_8A1(w, {"spellId": 34922}, [{"bucket": 1, "index": 0}])
	var rf: Dictionary = r.refreshed[0]
	check("M100-A01", w.reads == ["first_slot", "first_metadata", "second_slot", "second_metadata", "bullet_read_1", "bullet_read_2", "bullet_read_3"], "first slot / second slot / three BulletID reads are separate observations: %s" % str(w.reads))
	check("M100-A01", rf.count == 0 and rf.flag34 == 1 and w.service_c0.has(501) and w.service_c0[501] == 0, "override uses +C0 get-or-create (inserts 0), replacing stack count 3")
	check("M100-A01", rf.ops[2] == ["publish", QS.EVENT_OFF] and rf.ops[3] == ["Nd_Count.visible", true], "flag35=0: 9EF request then visible=(flag34||count>0)")
	var w2: Dictionary = _qs_world()
	w2["on_read"] = func(world: Dictionary, what: String) -> void:
		if what == "bullet_read_2":
			var row: PackedByteArray = world.mapping_rows[7001]
			row.encode_s32(0x24, 999)
			world.mapping_rows[7001] = row
	var r2: Dictionary = QS.on_event_8A1(w2, {"spellId": 34922}, [{"bucket": 1, "index": 0}])
	check("M100-A01", r2.refreshed[0].reads.bullet_read_1 == 501 and r2.refreshed[0].reads.bullet_read_3 == 999 and w2.service_c0.has(999), "third BulletID read is fresh (not the first value)")
	check("M100-X1", r2.refreshed[0].flag35 == 1 and r2.refreshed[0].ops[2] == ["Nd_Count.visible", false] and r2.refreshed[0].ops[3] == ["publish", QS.EVENT_OFF], "flag35: hide first, count0 -> 9EF")
	var w3: Dictionary = _qs_world()
	w3.service_c0[501] = 4
	check("M100-X1", QS.on_event_8A1(w3, {"spellId": 34922}, [{"bucket": 1, "index": 0}]).refreshed[0].ops[3] == ["publish", QS.EVENT_ON], "flag35+flag34 count>0 -> 9EE")
	check("M100-X2", QS.on_event_8A1(_qs_world(), {}, [{"bucket": 1, "index": 0}]).refreshed.is_empty(), "missing spellId reads 0, no refresh")
	var w4: Dictionary = _qs_world()
	w4.mapping_rows.erase(7001)
	var r4: Dictionary = QS.on_event_8A1(w4, {"spellId": 34922}, [{"bucket": 1, "index": 0}])
	check("M100-X2", r4.refreshed[0].count == 3 and r4.refreshed[0].flag34 == 0, "mapping miss keeps stack counter count")
	var w5: Dictionary = _qs_world()
	w5.loaded_rows.erase(501)
	check("M100-X2", QS.on_event_8A1(w5, {"spellId": 34922}, [{"bucket": 1, "index": 0}]).refreshed[0].status == V.REJECTED_UNDEFENDED, "Loaded row miss is unguarded -> rejected, not invented")
	check("M100-X3", QS.set_count({}, -5, 0, 0, {}).ops[0] == ["formatter", 1, -5], "signed count to formatter mode1, no clamp")

func m101() -> void:
	var idc: Dictionary = real.m101_identity_007F33B0
	var ident: Array = SH.identity_from_hex(idc.hex)
	check("M101-X1", ident == [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0], "real 007F33B0 bytes are identity in the file (not an uploaded-MVP claim)")
	var a: Array = []
	a.resize(16)
	a.fill(0.0)
	a[0] = 1e8; a[4] = 1.0; a[8] = -1e8; a[12] = 1.0  # synthetic cancellation row r=0
	var b: Array = ident.duplicate()
	b[1] = 1.0; b[2] = 1.0; b[3] = 1.0  # B column 0 = (1,1,1,1) synthetic
	var t32: Array = SH.mvp_multiply(a, b)
	var t64: Array = SH.mvp_multiply_binary64(a, b)
	check("M101-A01", t32[0] == 1.0 and t64[0] == 2.0, "binary32 left-associated adds differ from binary64 accumulate: %s vs %s" % [str(t32[0]), str(t64[0])])
	var ops: Array = real.m101_operation_index_table
	var idx_ok := true
	for o: Dictionary in ops:
		var oi: int = int(o.o)
		var c: int = oi / 4
		var r: int = oi % 4
		var oa: Array = o.A.map(func(x: Variant) -> int: return int(x))
		var ob: Array = o.B.map(func(x: Variant) -> int: return int(x))
		if oa != [r, 4 + r, 8 + r, 12 + r] or ob != [4 * c, 4 * c + 1, 4 * c + 2, 4 * c + 3]:
			idx_ok = false
	check("M101-A01", ops.size() == 16 and idx_ok, "real operation index table matches T[4c+r] column-major indices")
	var alias_a: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	var expect: Array = SH.mvp_multiply(alias_a.duplicate(), alias_a.duplicate())
	check("M101-A01", SH.mvp_multiply(alias_a, alias_a) == expect and alias_a[0] == 1, "temp-first commit: D=A alias gives same result (synthetic)")
	check("M101-A01", SH.copy64(Vector2i(0, 64), Vector2i(32, 96)).status == V.REJECTED_UNDEFENDED and SH.copy64(Vector2i(0, 64), Vector2i(64, 128)).copied, "initial memcpy needs non-overlap")

func m102() -> void:
	var cb: Dictionary = QS.packet370_callback({"dword10": 501, "dword14": -2, "dword18": 300, "dword1C": 1000, "dword20": 1})
	check("M102-A01", cb.event == 0x92D and not cb.map.has("field5") and cb.map.bulletCount == -2, "four fields to 92D, field5 not carried")
	var w: Dictionary = _qs_world()
	var r: Dictionary = QS.receive_92D(w, cb, [{"bucket": 1, "index": 0}])
	check("M102-A01", r.order == ["write_reload_90", "write_ammo_C0", "traverse"] and w.reload_90[501] == [300, 1000] and w.service_c0[501] == -2, "reload -> ammo (negative kept) -> refresh")
	var rf: Dictionary = r.refreshed[0]
	check("M102-A01", rf.flag35 == 1 and rf.progress_target == "item+118", "flag from payload+20 = full row+0x28 (decoy +0x20 is 0)")
	check("M102-A01", QS.LOADED_ROW_WITHOUT_AMMO == 0x28 and QS.MAPPING_ROW_BULLET_ID == 0x24, "corrected_v2 offsets")
	check("M102-X1", QS.receive_92D(_qs_world(), {"map": {"bulletId": 777, "bulletCount": 1}}, [{"bucket": 1, "index": 0}]).refreshed.is_empty(), "bullet1 != capture id: no refresh")
	check("M102-X1", QS.receive_92D(_qs_world(), null, []).order.is_empty(), "cast null returns before writes")
	check("M102-X1", w.reads.slice(-3) == ["bullet_read_1", "bullet_read_2", "bullet_read_3"], "three fresh BulletID reads")

func _tc_owner() -> Dictionary:
	# synthetic UI owner/page/slot values
	var slot := {"target": "slotA", "visible_28": true, "ancestors": [{"visible": true}, {"visible": true}, {"visible": true}], "converted": Vector2(10, 20), "anchor": Vector2(0.5, 0.5), "size": Vector2(63, 63)}
	return {"current_page_80": 0, "current_page_88": 0, "first_count": 6, "visible_88": true, "special": 99, "visible_90": false, "limit": 0, "pages": {0: [slot], 6: [slot]}, "manager": {"list": []}}

func m103() -> void:
	var o: Dictionary = _tc_owner()
	var first: Dictionary = TC.on_event_9EE(o, {"map": {"page_index": 0, "button_index": 0}})
	check("M103-A01", first.called and first.result.action == "requested" and first.result.effect.byte20 == 1 and o.manager.list.size() == 1, "first request creates one effect, byte20 = requested only")
	var dup: Dictionary = TC.slot_request(o, 0, 0, true)
	check("M103-A01", dup.action == "no_effect" and dup.reason == "duplicate_null_pair" and o.manager.list.size() == 1, "duplicate: null pair, no restart")
	o.manager.list.append({"target": "other", "tag": TC.RUNTIME_TAG, "strong": 1})
	var off: Dictionary = TC.slot_request(o, 0, 0, false)
	check("M103-A01", off.action == "cleanup" and off.removed == 1 and o.manager.list.size() == 1 and o.manager.list[0].target == "other", "false cleanup removes only target/tag matches")
	var o2: Dictionary = _tc_owner()
	o2.pages[0][0].ancestors[2].visible = false
	check("M103-A01", TC.slot_request(o2, 0, 0, true).action == "hidden_ancestor_return_no_cleanup" and o2.manager.list.is_empty(), "hidden third ancestor: return, list untouched")
	check("M103-A01", TC.slot_request(_tc_owner(), 3, 0, true).gate == "page_mismatch_return", "page mismatch returns")
	check("M103-X1", TC.slot_request(_tc_owner(), 6, 0, true).action == "requested", "current_page_88 + first_count page accepted")
	check("M103-X1", TC.on_event_9EE(_tc_owner(), {"map": {"page_index": 0}}).called == false and TC.on_event_9EE(_tc_owner(), {"map": {"page_index": "0", "button_index": 0}}).called == false, "missing/wrong type is not zero")
	var pos: Vector2 = TC.effect_position(Vector2(10.1, -3.3), Vector2(0.5, 0.5), Vector2(63, 63))
	var ex: float = V.f32(V.f32(V.f32(10.1) - V.f32(31.5)) + V.f32(V.f32(63.0) / 2.0))
	check("M103-X2", pos.x == ex, "round32 per step, size/2.0f (synthetic coordinates)")

func m104() -> void:
	var rows: Array = real.m104_buffcard_awaken_effect.rows
	check("M104-A01", WK.awaken_lookup(rows, 2, 4) == 1524 and WK.awaken_lookup(rows, 98, 52) == 3361 and WK.awaken_lookup(rows, 1, 1) == null, "real candidate rows: (2,4)->1524, (98,52)->3361, default (1,1) absent")
	var env := {"mode": 0, "self": "me", "cards": {11: {"grade": 4, "deck": 2}}, "awaken_rows": rows, "luid": "owner", "components": {}}
	var wkr := {"byte65": 1, "card": 11, "d0": null, "pending78": []}
	var pc := {"owner": "me", "slots": [wkr, null, null, null]}
	var res: Dictionary = WK.augment(pc, [[1524, "A"], [7, "B"]], 0, env)
	check("M104-A01", res.actions[0].path == "pending_assign" and wkr.pending78 == [[1524, "owner"], [1524, "A"], [7, "B"]], "augmentation first, order and duplicate 1524 kept")
	check("M104-A01", res.actions[0].tuples.size() == 3 and not res.has("live_instances"), "selected list is not a downstream live-instance count")
	var wpeer := {"byte65": 1, "card": 11, "d0": "peerX", "pending78": [["old"]]}
	var r2: Dictionary = WK.augment({"owner": "me", "slots": [wpeer, null, null, null]}, [], 0, env)
	check("M104-X1", r2.actions[0].path == "component_missing_no_pending_fallback" and wpeer.pending78 == [["old"]], "peer without component: no pending fallback")
	env.components["peerX"] = "comp"
	check("M104-X1", WK.augment({"owner": "me", "slots": [wpeer, null, null, null]}, [], 0, env).actions[0].path == "immediate_reconcile", "peer with component reconciles now")
	env.mode = 1
	var other := {"byte65": 1, "card": 11, "d0": null, "pending78": []}
	WK.augment({"owner": "someone", "slots": [other, null, null, null]}, [[5, "Z"]], 0, env)
	check("M104-X2", other.pending78 == [[5, "Z"]], "mode1 needs self owner: no augmentation")
	check("M104-X2", WK.augment(pc, [], 2, env).actions == ["dispose(incoming)"] and WK.augment(pc, [], -1, env).actions == ["dispose(incoming)"], "unsigned index > 1 disposes")
	check("M104-X3", WK.physical_key_bytes(2, 4).hex_encode() == "0400000002000000" and WK.key_less([-1, 9], [0, -9]), "physical [grade,deck] bytes vs signed (deck,grade) order")
	check("M104-X3", (WK.awaken_lookup([[2, 4, 1], [1, 4, 2]], 1, 4) as Dictionary).status == V.REJECTED_UNDEFENDED, "unsorted table rejected, not repaired")
	check("M104-X3", WK.grow_capacity(5, 10) == 15 and WK.grow_capacity(20, 10) == 20 and WK.grow_capacity(WK.VECTOR24_MAX + 1, 0).status == "length_error", "growth rule")

func m105() -> void:
	var csb: Dictionary = real.m105_csb
	var c: Dictionary = TC.csb_contract(csb)
	check("M105-A01", c.nodes == 6 and c.tracks == 3 and c.keys == 23 and c.file_keys == 15 and c.file_unique == 14, "real CSB 6 nodes / 3 tracks / 23 keys / 15 FileData keys, 14 unique")
	check("M105-A01", c.last_file_key == [75, "Fx_Seet_GlowLoop_01.png"], "key75 = _01 (not _15)")
	check("M105-A01", c.runtime_tag_is_authored == false and TC.RUNTIME_TAG == 9001, "tag 2329 is the code's runtime tag, not an authored action/node tag")
	check("M105-A01", c.start == ["Start", 5, 75] and c.duration_frames == 75 and c.speed == 1.0 and c.duration_seconds == V.UNKNOWN, "Start 5..75, duration75 frames (seconds UNKNOWN), explicit speed 1.0")
	check("M105-A01", c.alpha_tween_loader_value == true and c.file_tween_explicit_false, "Alpha tween absent -> loader true; FileData explicit false")
	check("M105-X1", not TC.easing_slot3_consumed("Alpha") and TC.easing_slot3_consumed("FileData"), "Alpha slot3 easing not applied")
	var alpha: Array = csb.keyframes.filter(func(k: Dictionary) -> bool: return k.property == "Alpha").map(func(k: Dictionary) -> Array: return [int(k.action_tag), int(k.index), int(k.alpha)])
	check("M105-X1", alpha.has([-1253072878, 65, 25]) and alpha.has([-2025293431, 65, 38]), "real Alpha keys frame65 -> 25 / 38")
	check("M105-X1", csb.string_table.TIME_CLEAR_SLOT_ANIM_NAME == "Start" and csb.root_plists.size() == 18, "Start name and 18 root texture references")

func m106() -> void:
	var lit: Dictionary = real.m106_literals
	check("M106-A01", SH.vertex_contract(lit["vertex.glsl"]).uses_pmatrix and not SH.vertex_contract(lit["vertex.glsl"]).uses_mvp, "real noMVP vertex uses CC_PMatrix")
	check("M106-A01", (lit["split_fragment.glsl"] as String).contains("texture2D(CC_Texture1, v_texCoord).r") and lit["split_name.txt"] == "#ShaderETC1ASPositionTextureColor_noMVP", "real split literal reads Texture1.r")
	var v := Color(1, 1, 1, 0.5)
	var t0 := Color(0.5, 0.25, 1.0, 0.125)
	var t1 := Color(0.5, 0, 0, 0.75)  # synthetic: Texture1.r != Texture1.a
	var sp: Color = SH.split_output(v, t0, t1)
	check("M106-A01", sp.r == 0.25 and sp.a == 0.25 and sp.a != v.a * t1.a and sp.a != v.a * t0.a, "alpha source is Texture1.r")
	var nm: Color = SH.normal_output(v, t0)
	check("M106-A01", nm.r == 0.5 and nm.a == 0.0625, "normal V*T without extra PMA")
	check("M106-X1", SH.loader_selected(1).fragment == "normal" and SH.loader_selected(31).fragment == "split" and SH.loader_selected(2).status == V.UNKNOWN and SH.loader_selected(1).link_bool_gate == false, "type1/31 only; no bool gates")

func m107() -> void:
	var node := {"id": "fx", "parent": "B"}  # created under target A, reparented to B (synthetic)
	var effect := {"node": node, "target": "A", "optional_control": {"strong": 1, "weak": 1}, "callable68": "c68", "callable28": "c28"}
	var getp := func(_e: Dictionary, n: Dictionary) -> Variant: return n.parent
	var rm := func(_e: Dictionary, _p: Variant, _c: Variant) -> void: pass
	var ev: Array = TC.ui_effect_destroy(effect, getp, rm)
	check("M107-A01", ev[0] == ["removeChild", "B", "fx", true], "current parent B, not creator target A")
	check("M107-A01", ev[1] == ["Ref_release", "fx"] and ev[2] == ["control.virtual0"] and ev[3] == ["control.virtual8"] and ev[4] == ["destroy", "callable68"] and ev[5] == ["destroy", "callable28"] and ev.size() == 6, "release, +B0, then +68 then +28 destroyed; flags0 no free")
	var e2 := {"node": {"id": "n1", "parent": null}, "target": "A"}
	check("M107-X1", TC.ui_effect_destroy(e2, getp, rm) == [["Ref_release", "n1"]], "parent null: remove skipped, release kept")
	var e3 := {"node": {"id": "n1", "parent": "P"}, "target": "A"}
	var swap := func(e: Dictionary, _p: Variant, _c: Variant) -> void: e["node"] = {"id": "n2"}
	check("M107-X1", TC.ui_effect_destroy(e3, getp, swap)[1] == ["Ref_release", "n2"], "release re-reads +18 after removeChild")
	check("M107-X1", TC.ui_effect_destroy({"node": null}, getp, rm).is_empty() and TC.ui_effect_destroy({"node": null}, getp, rm, 1) == [["sized_free", 0xC0]], "node-null gate; flags&1 free")

func m108() -> void:
	var atlas: Dictionary = real.m108_atlas
	var c: Dictionary = TC.atlas_contract(atlas)
	check("M108-A01", c.selected == 16 and c.per_plist["UI_Resource/Atlas_Z_Fx_Seet_GlowLoop.plist"] == 14 and c.per_plist["UI_Resource/Atlas_Hud.plist"] == 2 and c.all_unrotated_untrimmed, "16 selected = 14 GlowLoop + 2 HUD, unrotated/untrimmed")
	var names: Dictionary = {}
	for f: Dictionary in atlas.frames:
		names[f.name] = f.frame
	check("M108-A01", names["Fx_Seet_GlowLoop_13.png"] == "{{1314,329},{256,256}}" and names["Hud_QuicSlot_Glow.png"] == "{{487,1888},{44,44}}" and names["Hud_Orim_SkillSlot_Line.png"] == "{{1307,1720},{62,62}}", "real authored rectangles")
	check("M108-A01", real.m105_csb.root_plists.size() == 18 and real.m105_csb.keyframes.size() == 23 and c.selected == 16, "18 resource occurrences, 23 keys and 16 selected frames are different counts")
	check("M108-A01", atlas.containers["UI_Resource/Atlas_Hud.plist"].origin == 521 and atlas.containers["UI_Resource/Atlas_Z_Fx_Seet_GlowLoop.plist"].origin == 518 and atlas.assets_sha256.size() == 4, "UI38/521 and UI51/518; four asset hashes recorded")
	check("M108-X1", c.runtime_spriteframe_claimed == false and c.metadata_premultiply_is_runtime_pma == false, "no runtime SpriteFrame/PMA claim")

func m109() -> void:
	var w := {"d0": "peer0", "pending78": [[1, "a"]]}
	var calls := [0]
	var hooks := {"factory": func(_w: Dictionary) -> Variant:
		calls[0] += 1
		return "peerF", "components": {"peerF": "comp", "peerG": "compG"}}
	check("M109-A01", WK.apply_pending(w, hooks).skipped and calls[0] == 0 and w.pending78 == [[1, "a"]], "already associated: whole operation skipped, pending not applied")
	var w2 := {"d0": null, "pending78": [[1, "a"]]}
	hooks["callbacks"] = func(win: Dictionary) -> void:
		win.pending78.append([2, "b"])
		win["d0"] = "peerG"
	var r: Dictionary = WK.apply_pending(w2, hooks)
	check("M109-A01", r.peer_used == "peerG" and r.reconciled_with == [[1, "a"], [2, "b"]] and r.pending_after == [[1, "a"], [2, "b"]], "callback mutation is seen by the re-read; pending preserved (no clear)")
	check("M109-A01", r.events.find("store_d0") < r.events.find("callable_replace_cleanup") and r.events.find("callable_replace_cleanup") < r.events.find("reconcile(component,&W+78)"), "store D0 -> callbacks -> re-read -> reconcile")
	var w3 := {"d0": null, "pending78": []}
	check("M109-X1", WK.apply_pending(w3, {"factory": func(_w: Dictionary) -> Variant: return "p", "components": {}}).events[-1] == "pending_empty_return" and w3.d0 == "p", "empty pending: store but no reconcile")
	var w4 := {"d0": null, "pending78": [[1]]}
	var r4: Dictionary = WK.apply_pending(w4, {"factory": func(_w: Dictionary) -> Variant: return null, "components": {}})
	check("M109-X1", r4.events.has("factory_null_stored_without_guard") and r4.events[-1] == "component_missing", "no caller factory-null guard is invented")
	var out: Array = WK.controller([{"d0": "x"}, null, {"d0": "y"}, null], 0, hooks)
	check("M109-X2", out.size() == 2 and out[0].opaque == "01CAC840", "DL0 -> opaque 01CAC840 on raw slots")

func raw_assets() -> void:
	var dir: String = OS.get_environment("OC_M82_M109_ASSET_DIR")
	if dir.is_empty():
		return
	var csb_path: String = dir.path_join("Fx_Slot_Saintpaladin_TimeClear.csb")
	if FileAccess.file_exists(csb_path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(csb_path)
		var rc: Dictionary = TC.csb_raw_check(bytes, real.m105_csb)
		check("M105-R01", rc.mismatches.is_empty(), "real CSB byte offsets: %s" % str(rc.mismatches))
	var atlas: Dictionary = real.m108_atlas
	var ok := true
	var detail: Array = []
	for asset: String in atlas.assets_sha256:
		var p: String = dir.path_join(asset)
		if not FileAccess.file_exists(p) or FileAccess.get_sha256(p) != atlas.assets_sha256[asset]:
			ok = false
			detail.append(asset)
	for plist: String in ["Atlas_Hud.plist", "Atlas_Z_Fx_Seet_GlowLoop.plist"]:
		var p2: String = dir.path_join(plist)
		if not FileAccess.file_exists(p2):
			continue
		var text: String = FileAccess.get_file_as_string(p2)
		var names: Array = atlas.frames.filter(func(f: Dictionary) -> bool: return str(f.plist).ends_with(plist)).map(func(f: Dictionary) -> String: return f.name)
		var parsed: Dictionary = TC.plist_frames(text, names)
		for f: Dictionary in atlas.frames:
			if str(f.plist).ends_with(plist):
				if not parsed.has(f.name) or parsed[f.name].frame != f.frame or parsed[f.name].rotated:
					ok = false
					detail.append(f.name)
	check("M108-R01", ok, "real plist frames / asset hashes: %s" % str(detail))
