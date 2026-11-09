extends RefCounted
## M88 pixel PMA + RGBA8888->RGB565, M89 Sprite vertex opacity + blend, M90 Sprite program-state
## selection, M91 program-state cache ownership (C13/C14). DESIGN_NOT_RECOVERED_API.
## Image pixel PMA, Sprite vertex opacity, blend pair and program state are four different states.
## Nothing here is a GPU, driver or pixel result.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")

# ---------------------------------------------------------------- M88
## Format enum 4 is RGB565 (not RGBA4444) in this binary's initialised descriptor table.
const DESCRIPTORS := {2: {"internal": 0x1908, "format": 0x1908, "type": 0x1401, "bpp": 32, "compressed": false, "alpha": true},
	4: {"internal": 0x1907, "format": 0x1907, "type": 0x8363, "bpp": 16, "compressed": false, "alpha": false}}

## 0030A930 per channel: floor(C*(A+1)/256). Not /255, not rounded. Alpha is kept.
static func pma_channel(c: int, a: int) -> int:
	return ((c & 0xFF) * ((a & 0xFF) + 1)) >> 8

## Premultiply runs only when the global byte is nonzero AND the updated PNG colour is 6.
## Width*height (low32 signed) <= 0 skips the loop but still sets the flag to 1.
static func premultiply(rgba: PackedByteArray, width: int, height: int, global_byte: int, png_color: int) -> Dictionary:
	if global_byte == 0 or png_color != 6:
		return {"pixels": rgba, "flag": 0, "ran": false}
	var n: int = V.i32(width * height)
	var out: PackedByteArray = rgba.duplicate()
	if n > 0:
		if out.size() < n * 4:
			return {"status": V.REJECTED_UNDEFENDED, "note": "pixel buffer shorter than width*height*4; original has no guard"}
		for i: int in n:
			var a: int = out[i * 4 + 3]
			for k: int in 3:
				out[i * 4 + k] = pma_channel(out[i * 4 + k], a)
	return {"pixels": out, "flag": 1, "ran": true}

## 00341694: ((R>>3)<<11)|((G>>2)<<5)|(B>>3), little-endian WORD, alpha not read.
static func rgb565_word(r: int, g: int, b: int) -> int:
	return (((r & 0xFF) >> 3) << 11) | (((g & 0xFF) >> 2) << 5) | ((b & 0xFF) >> 3)

static func rgb565_le_hex(r: int, g: int, b: int) -> String:
	var w: int = rgb565_word(r, g, b)
	return "%02X%02X" % [w & 0xFF, (w >> 8) & 0xFF]

## 00340B48 returns a FORMAT ENUM, not a bool. requested==source or 0 aliases the source.
## Source2 -> requested4: outLength = signed length/2 toward zero; pixels = floor(N/4) for N>=0.
## malloc has no null guard in the original: a null allocation is rejected by the DESIGN.
static func convert(src: PackedByteArray, length: int, source_format: int, requested: int, malloc_ok: bool = true) -> Dictionary:
	if requested == source_format or requested == 0:
		return {"format": source_format, "aliased": true, "out": src, "out_length": length}
	if source_format != 2 or requested != 4:
		return {"format": source_format, "aliased": true, "out": src, "out_length": length, "note": "unsupported dispatch passthrough"}
	if length < 0:
		return {"status": V.REJECTED_UNDEFENDED, "note": "negative length: N-3 wraps in 64 bits in the original"}
	var out_len: int = length / 2
	if not malloc_ok:
		return {"status": V.REJECTED_UNDEFENDED, "note": "no malloc-null guard before the converter writes"}
	var out := PackedByteArray()
	out.resize(out_len)
	var pixels: int = length / 4
	for i: int in pixels:
		var w: int = rgb565_word(src[i * 4], src[i * 4 + 1], src[i * 4 + 2])
		out[i * 2] = w & 0xFF
		out[i * 2 + 1] = (w >> 8) & 0xFF
	var r := {"format": 4, "aliased": false, "out": out, "out_length": out_len, "pixels_written": pixels}
	if out_len > pixels * 2:
		r["uninitialised_tail_bytes"] = out_len - pixels * 2
	return r

# ---------------------------------------------------------------- M89
const BLEND_NONPREMUL := [770, 771]
const BLEND_PREMUL := [1, 771]
const BLEND_SELECTED_OVERRIDE := [1, 1]

## updateColor 003CF8B0 vertex channel: modifier!=0 -> trunc(f32(C * f32(A/255.0))). A unchanged.
static func vertex_channel(c: int, a: int, modifier: bool) -> int:
	if not modifier:
		return c & 0xFF
	var t: float = V.f32(float(a & 0xFF) / 255.0)
	return V.trunc_to_int(V.f32(float(c & 0xFF) * t)) & 0xFF

static func make_sprite(texture: Variant, modifier: bool, mode: int = 0) -> Dictionary:
	return {"texture": texture, "blend": BLEND_NONPREMUL, "modifier": modifier, "mode": mode, "update_color_calls": 0}

## setOpacityModifyRGB 003CEA44: same value returns; a different one writes, then updateColor.
static func set_opacity_modify_rgb(sprite: Dictionary, value: bool) -> void:
	if bool(sprite.modifier) == value:
		return
	sprite["modifier"] = value
	sprite["update_color_calls"] = int(sprite.update_color_calls) + 1

## setTexture 003CF14C tail: mode3 or the same Texture pointer skips ownership/updateBlendFunc.
## updateBlendFunc reads only Texture byte+30 (null/0 -> (770,771), nonzero -> (1,771)).
static func set_texture(sprite: Dictionary, texture: Variant) -> void:
	if int(sprite.mode) == 3 or sprite.texture == texture:
		return
	sprite["texture"] = texture
	var flag: int = 0 if texture == null else int((texture as Dictionary).premultiplied_flag)
	sprite["blend"] = BLEND_NONPREMUL if flag == 0 else BLEND_PREMUL
	set_opacity_modify_rgb(sprite, flag != 0)

## EXE 00C381A0 path. Only the non101 success suffix (both lookups, nonnull loader texture,
## nonnull second Sprite cast) overrides blend (1,1) + modifier=true. Loader null -> hide path.
static func icon_apply(sprite: Dictionary, asset_type: int, loader_texture: Variant, second_cast_ok: bool) -> Dictionary:
	if asset_type == 101:
		return {"branch": "type101_separate_branch", "suffix_applied": false}
	if loader_texture == null:
		return {"branch": "loader_null_hide", "suffix_applied": false}
	if not second_cast_ok:
		return {"branch": "cast_failed", "suffix_applied": false}
	set_texture(sprite, loader_texture)
	sprite["visible"] = true
	sprite["blend"] = BLEND_SELECTED_OVERRIDE  # 0013263C writes the pair only, no colour refresh
	set_opacity_modify_rgb(sprite, true)
	return {"branch": "non101_success", "suffix_applied": true, "evidence": V.CONDITIONAL}

# ---------------------------------------------------------------- M90
const NAME_SWAPS := {"ShaderPositionTextureColor": "#ShaderETC1ASPositionTextureColor",
	"ShaderPositionTextureColor_noMVP": "#ShaderETC1ASPositionTextureColor_noMVP",
	"ShaderUIGrayScale": "#ShaderETC1ASPositionTextureGray_noMVP"}
const SELECTED_NAME := "ShaderPositionTextureColor_noMVP"  # *007F3A30

## 00337648: Texture null -> original name; else DWORD [Texture+78 -> q +1C] (q null -> 0).
## Only a nonzero DWORD (0xFFFFFFFF too) plus an exact name match swaps the name.
static func program_name(texture: Variant, original_name: String) -> String:
	if texture == null:
		return original_name
	var q: Variant = (texture as Dictionary).get("field78", null)
	var alpha_name: int = 0 if q == null else V.u32(int((q as Dictionary).dword1C))
	if alpha_name == 0:
		return original_name
	return NAME_SWAPS.get(original_name, original_name)

## Selection prefix: root+1C8 nonnull preserves the state and makes NO request (same Texture or
## mode3 is NOT what gates this prefix).
static func selection_prefix(root: Dictionary, texture: Variant) -> Dictionary:
	if root.get("program_state") != null:
		return {"requested": false, "name": null}
	return {"requested": true, "name": program_name(texture, SELECTED_NAME)}

## 00338A48 state cache. Hit (iterator != QWORD[cache+8]) returns node+18 as is, null included.
## init false still releases and returns the same RBX bits (not null, liveness not guaranteed).
static func state_cache_get(cache: Dictionary, program: String, alloc_ok: bool, ctor_ok: bool, init_ok: bool) -> Dictionary:
	if cache.has(program):
		return {"result": cache[program], "hit": true, "events": []}
	if not alloc_ok:
		return {"result": null, "hit": false, "events": ["alloc_null"]}
	if not ctor_ok:
		return {"result": null, "hit": false, "events": ["ctor_null"]}
	var ev: Array = ["init"]
	var obj := {"id": "state_for_" + program}
	if init_ok:
		cache[program] = obj
		ev.append("insert")
	ev.append("release(RBX)")
	var r := {"result": obj, "hit": false, "events": ev}
	if not init_ok:
		r["evidence"] = V.UNKNOWN
		r["note"] = "same bits returned after release; not a valid-object, NULL or confirmed-UAF claim"
	return r

## Default Node::setGLProgramState 003BD2D8: equal -> nothing; else release old, store, retain
## new, re-read the field, bind if nonnull. (Opposite of the Texture tail retain-then-release.)
static func node_set_program_state(root: Dictionary, incoming: Variant) -> Array:
	var ev: Array = []
	var old: Variant = root.get("program_state")
	if old == incoming:
		return ev
	if old != null:
		ev.append("release(old)")
	root["program_state"] = incoming
	ev.append("store")
	if incoming != null:
		ev.append("retain(incoming)")
	if root.get("program_state") != null:
		ev.append("bind(state+128=root)")
	return ev

# ---------------------------------------------------------------- M91
## 00173D28: FNV-1a over exactly the 8 little-endian bytes of the pointer VALUE.
static func fnv1a_pointer(pointer_value: int) -> int:
	var h: int = -3750763034362895579  # 0xCBF29CE484222325 as a signed 64-bit pattern
	for i: int in 8:
		h = h ^ ((pointer_value >> (8 * i)) & 0xFF)
		h = V.mul_u64(h, 0x100000001B3)
	return h

## A small model of the state cache keyed by program pointer, with refcounts kept per object.
static func make_cache() -> Dictionary:
	return {"nodes": {}, "refs": {}}

## 0023819C insertion helper: retain candidate FIRST; if a node for key exists, release old and
## erase (erase internals opaque), then the lower insert 00208C48.
## `growth` + `key_present_after_growth` model the reprobe after rehash: equality found there is
## the insertion-position path (flag1, node appended), NOT the first-lookup duplicate (flag0).
static func insert_helper(cache: Dictionary, key: int, candidate: String, growth: bool = false, key_present_after_growth: bool = false) -> Dictionary:
	var refs: Dictionary = cache.refs
	refs[candidate] = int(refs.get(candidate, 0)) + 1
	var ev: Array = ["retain(candidate)"]
	if (cache.nodes as Dictionary).has(key):
		var old: String = cache.nodes[key][0]
		refs[old] = int(refs[old]) - 1
		ev.append("release(old)")
		ev.append("erase(node)")
		(cache.nodes as Dictionary).erase(key)
		ev.append("erase_internals_opaque")
	var lower: Dictionary = lower_insert(cache, key, candidate, growth, key_present_after_growth)
	ev.append("lower_insert_flag%d" % int(lower.flag))
	return {"events": ev, "lower": lower}

static func lower_insert(cache: Dictionary, key: int, candidate: String, growth: bool, key_present_after_growth: bool) -> Dictionary:
	var nodes: Dictionary = cache.nodes
	if nodes.has(key) and not growth:
		return {"flag": 0, "payload": nodes[key][0], "path": "first_lookup_duplicate"}
	if growth and key_present_after_growth:
		var dup: Array = nodes.get(key, []).duplicate()
		dup.append(candidate)
		nodes[key] = dup
		return {"flag": 1, "payload": candidate, "path": "insertion_position_after_growth", "evidence": V.UNKNOWN,
			"note": "requires key-set change during rehash/reentry; not the flag0 duplicate semantics"}
	nodes[key] = [candidate]
	return {"flag": 1, "payload": candidate, "path": "fresh_insert"}

## Normal fresh miss count sequence: ctor 1 -> insertion retain 2 -> caller release 1. The
## program p gets its own +1 from init. Node setter (old null) later adds 1 more.
static func fresh_miss(cache: Dictionary, key: int, candidate: String, program: String) -> Dictionary:
	var refs: Dictionary = cache.refs
	refs[candidate] = 1
	refs[program] = int(refs.get(program, 1)) + 1
	var seq: Array = [refs[candidate]]
	insert_helper(cache, key, candidate)
	seq.append(refs[candidate])
	refs[candidate] = int(refs[candidate]) - 1
	seq.append(refs[candidate])
	return {"sequence": seq, "program_refs": refs[program]}
