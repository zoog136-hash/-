extends RefCounted
## M92 corrected_v2 minimap stencil requests, M93 stencil callable swap + StateBlock depth,
## M94 clear shader type10 registration (C18/C14/C13). DESIGN_NOT_RECOVERED_API.
## Every output is a request log. CPU raw32 values are kept exactly; the signed GLint clamp
## is a separate, explicitly-labelled API model, never a rewrite of the request.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")
const GL_NEVER := 0x0200
const GL_EQUAL := 0x0202
const GL_KEEP := 0x1E00
const GL_REPLACE := 0x1E01
const GL_ZERO := 0

# ---------------------------------------------------------------- M92
static func make_manager(threshold: float = 1.0, inverted: int = 0) -> Dictionary:
	return {"threshold": threshold, "inverted": inverted, "cumulative_30": null}

## 0020FBC8. layer = u32(layer+1); bit = u32(1 << (layer&31)); M+30 = u32((bit-1)|bit).
## Returns the new global layer and the raw32 request list. No bit-budget check exists.
static func before(manager: Dictionary, global_layer: int, saved: Dictionary) -> Dictionary:
	var layer: int = V.u32(global_layer + 1)
	var bit: int = V.u32(1 << (layer & 31))
	var cumulative: int = V.u32((bit - 1) | bit)
	manager["cumulative_30"] = cumulative
	manager["saved"] = saved.duplicate()
	var inv: bool = int(manager.inverted) != 0
	var req: Array = [
		["glEnable", "STENCIL_TEST"], ["glStencilMask", bit],
		["glGetBooleanv", "DEPTH_WRITEMASK"], ["glDepthMask", 0], ["setDepthWrite(default)", 0],
		["glStencilFunc", GL_NEVER, bit, bit], ["glStencilOp", GL_REPLACE if inv else GL_ZERO, GL_KEEP, GL_KEEP],
		["clear_draw", "ShaderPosition_uColor", "u_color(1,1,1,1)", "DrawArrays(6,0,4)"],
		["glStencilFunc", GL_NEVER, bit, bit], ["glStencilOp", GL_ZERO if inv else GL_REPLACE, GL_KEEP, GL_KEEP]]
	if 1.0 > float(manager.threshold):  # COMISS ordered compare; NaN skips
		req.append_array([["glEnable", "ALPHA_TEST"], ["glAlphaFunc", 0x0204, manager.threshold]])
	return {"layer": layer, "bit_raw32": bit, "cumulative_raw32": cumulative, "requests": req}

static func after_draw(manager: Dictionary) -> Array:
	var req: Array = []
	var s: Dictionary = manager.saved
	if 1.0 > float(manager.threshold):
		req.append(["glAlphaFunc", s.get("alpha_func"), s.get("alpha_ref")])
		if int(s.get("alpha_enabled", 0)) == 0:
			req.append(["glDisable", "ALPHA_TEST"])
	req.append(["glDepthMask", int(s.depth_write_raw)])  # raw saved GLboolean byte
	req.append(["setDepthWrite(default)", 1 if int(s.depth_write_raw) != 0 else 0])
	req.append(["glStencilFunc", GL_EQUAL, manager.cumulative_30, manager.cumulative_30])
	req.append(["glStencilOp", GL_KEEP, GL_KEEP, GL_KEEP])
	return req

## 0020FB78: partial restore; no unconditional re-enable, no depth/alpha restore here.
static func after_visit(manager: Dictionary, global_layer: int) -> Dictionary:
	var s: Dictionary = manager.saved
	var req: Array = [["glStencilFunc", s.func, s.ref, s.value_mask], ["glStencilOp", s.sfail, s.zfail, s.zpass], ["glStencilMask", s.write_mask]]
	if int(s.stencil_enabled) == 0:
		req.append(["glDisable", "STENCIL_TEST"])
	return {"layer": V.u32(global_layer - 1), "requests": req}

## API MODEL (not CPU): GLint = s32(raw32); effective = min(max(GLint,0), 2^B-1).
static func effective_ref(raw32: int, bits: int) -> int:
	var maxv: int = (1 << bits) - 1
	return mini(maxi(V.i32(raw32), 0), maxv)

static func api_replace(old: int, raw32: int, write_mask: int, bits: int) -> int:
	var maxv: int = (1 << bits) - 1
	return ((old & ~write_mask) | (effective_ref(raw32, bits) & write_mask)) & maxv

static func api_equal(stencil: int, ref32: int, mask32: int, bits: int) -> bool:
	var maxv: int = (1 << bits) - 1
	return (stencil & mask32 & maxv) == (effective_ref(ref32, bits) & mask32 & maxv)

# ---------------------------------------------------------------- M93
## 0033F64C setDepthWrite: raw DL to +12; bit10 means MASK 0x10. No GL call.
static func set_depth_write(state: Dictionary, dl: int) -> void:
	state["byte12"] = dl & 0xFF
	state["bits4C"] = (int(state.bits4C) & 0xFFFFFFEF) | (0x10 if (dl & 0xFF) != 0 else 0)

## restore(keepMask) depth projection on the cache C.
static func restore_depth(cache: Dictionary, keep_mask: int) -> Array:
	var req: Array = []
	if (int(cache.bits) | keep_mask) == keep_mask:
		return req
	if (keep_mask & 0x10) == 0 and (int(cache.bits) & 0x10) != 0:
		req.append(["glDepthMask", 0])
		cache["bits"] = int(cache.bits) & 0xFFFFFFEF
		cache["depth_write"] = 0
	return req

## bindNoRestore depth projection: only a SET source bit10 with a differing byte issues a request;
## a false source never resets a true cache. Whole-DWORD union afterwards.
static func bind_no_restore_depth(cache: Dictionary, source: Dictionary) -> Array:
	var req: Array = []
	if (int(source.bits4C) & 0x10) != 0 and int(source.byte12) != int(cache.depth_write):
		req.append(["glDepthMask", 1 if int(source.byte12) != 0 else 0])
		cache["depth_write"] = int(source.byte12)
	cache["bits"] = int(cache.bits) | int(source.bits4C)
	return req

## 0033E518 bind = restore(source bits) then bindNoRestore. Not interchangeable.
static func bind(cache: Dictionary, source: Dictionary) -> Array:
	var req: Array = restore_depth(cache, int(source.bits4C))
	req.append_array(bind_no_restore_depth(cache, source))
	return req

## Selected callable swap (normal path): the destination gets a copied {target, manager} with
## raw manager pointer semantics (no retain); an old destination callable is destroyed first.
static func bind_stencil_callable(destination: Dictionary, target: String, manager: Variant) -> Dictionary:
	var ev: Array = []
	if destination.get("callable") != null:
		ev.append("destroy(old_destination_callable)")
	destination["callable"] = {"target": target, "manager": manager, "retained": false}
	ev.append("D.ptr=D")
	return {"events": ev, "manager_null_guard_on_invoke": false}

# ---------------------------------------------------------------- M94
const PROGRAM_KEY := "ShaderPosition_uColor"
const EXPLICIT_BIND := ["aVertex", 0]
const COMMON_BIND_FIRST := ["a_position", 0]

## 00334398 / 003331F0 case10: init AL ignored, aVertex bound at 0, common bindings (7 entries,
## first a_position), link, status0 -> handle 0, updateUniforms anyway, then name insert.
## Duplicate name keeps the existing payload and frees the new node (no program release).
static func register_type10(table: Dictionary, program_id: String, link_status: int) -> Dictionary:
	var ev: Array = ["alloc+ctor", "source_forward(vertex,fragment)", "bind(aVertex,0)", "common_bind[0..6] first a_position", "link"]
	var handle: Variant = "handle_" + program_id
	if link_status == 0:
		handle = 0
		ev.append("handle=0")
	else:
		ev.append("delete_attached_shaders")
	ev.append("updateUniforms")
	var inserted: bool = false
	if table.has(PROGRAM_KEY):
		ev.append("duplicate_name:keep_existing_free_new_node")
	else:
		table[PROGRAM_KEY] = program_id
		inserted = true
		ev.append("insert")
	return {"events": ev, "handle": handle, "inserted": inserted, "usable_program_claimed": false, "render_status": V.NOT_OBSERVED}

## Literal cross-check: names requested by the clear draw versus names in the real literals.
static func literal_contract(vertex: String, fragment: String) -> Dictionary:
	return {"uses_u_color": vertex.contains("uniform vec4 u_color;"), "uses_mvp": vertex.contains("gl_Position = CC_MVPMatrix * a_position;"),
		"declares_a_position": vertex.contains("attribute vec4 a_position;"), "declares_aVertex": vertex.contains("aVertex"),
		"fragment_passthrough": fragment.contains("gl_FragColor = v_fragmentColor;"), "point_size": vertex.contains("gl_PointSize = u_pointSize;"),
		"gpu_result": V.NOT_OBSERVED}
