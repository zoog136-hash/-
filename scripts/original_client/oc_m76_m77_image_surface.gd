extends RefCounted
## M76 (C04/C13, R76) image/texture cache lifetime and M77 (C14, R77) surface packing/upload.
## DESIGN_NOT_RECOVERED_API. No GL call is made. CPU arithmetic is reproduced with the widths the
## package fixes; nothing here proves an upload, real pixels, VRAM size or a driver result.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

# ---- M76 --------------------------------------------------------------------------------
## Image init bool is discarded; the Texture init bool gates insertion; the inner mipmap bool is
## not propagated.
static func cache_add(cache: Dictionary, key: String, image_init_ok: bool, texture_init_ok: bool, mipmap_ok: bool) -> Dictionary:
	var out: Dictionary = cache.duplicate(true)
	if texture_init_ok:
		out[key] = {"refs": 1}
	return {"cache": out, "inserted": texture_init_ok, "image_bool_used": false, "mipmap_bool_propagated": false,
		"image_init_ok_seen": image_init_ok, "mipmap_ok_seen": mipmap_ok}

## A selected null result hides the node. setter(null) substitutes the white texture. Different.
static func apply_selected_result(result: Variant) -> Dictionary:
	if result == null:
		return {"visible": false, "texture": "UNCHANGED"}
	return {"visible": true, "texture": result}

static func setter_null() -> Dictionary:
	return {"texture": "WHITE_TEXTURE_SUBSTITUTE"}

## Sweep removes Ref==1 entries only and runs before the CSB clear. A texture still held by a
## Sprite (refs > 1) survives until a LATER sweep after the holder lets go.
static func sweep(cache: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var removed: Array = []
	for k: String in cache:
		if int(cache[k].refs) == 1:
			removed.append(k)
		else:
			out[k] = cache[k].duplicate()
	return {"cache": out, "removed": removed}

static func close_screen(cache: Dictionary) -> Dictionary:
	var swept: Dictionary = sweep(cache)
	return {"order": ["transition_virtual_effects", "sweep_ref1", "csb_clear"], "cache": swept.cache, "removed": swept.removed,
		"destructor_ran": V.UNKNOWN, "next_sweep_required_for_held": true}

# ---- M77 --------------------------------------------------------------------------------
const GL_PIXEL_UNPACK_BUFFER := 0x88EC
const GL_PIXEL_UNPACK_BUFFER_BINDING := 0x88EF
const FIXED_WRITE_W := 1200
const FIXED_WRITE_H := 675

## CPU allocation: low32 signed bit product, divided by 8 toward zero, sent to malloc as u32.
@warning_ignore("integer_division")
static func cpu_alloc_bytes(w: int, h: int, bits_per_pixel: int) -> Dictionary:
	var product_i32: int = V.i32(w * h * bits_per_pixel)
	var div8: int = product_i32 / 8  # GDScript int division truncates toward zero, like IDIV
	return {"product_i32": product_i32, "div8_trunc": div8, "malloc_u32": V.u32(div8)}

## GPU init temporary CPU buffer: low32(W*H*4) sign-extended to 64 bits. Not a VRAM size.
static func gpu_temp_bytes(w: int, h: int) -> int:
	return V.i32(w * h * 4)

## The four scale samples are separate reads, not one snapshot.
static func scale_samples(cpu_cx: float, cpu_cy: float, gpu_cx: float, gpu_cy: float) -> Dictionary:
	return {"cpu": [cpu_cx, cpu_cy], "gpu": [gpu_cx, gpu_cy], "single_snapshot": false}

## C14-T01: requested dimensions and the fixed 1200x675 write envelope are reported apart; a write
## envelope larger than the requested buffer is flagged, never reported as a normal success.
static func resample_plan(src_w: int, src_h: int, cx: float, cy: float) -> Dictionary:
	var req_w: int = int(V.f32(float(src_w) * V.f32(cx)))
	var req_h: int = int(V.f32(float(src_h) * V.f32(cy)))
	var short: bool = req_w * req_h < FIXED_WRITE_W * FIXED_WRITE_H
	return V.rec("ResamplePlan", "M77", V.CONDITIONAL, {"requested": Vector2i(req_w, req_h), "write_envelope": Vector2i(FIXED_WRITE_W, FIXED_WRITE_H),
		"status": "WRITE_ENVELOPE_EXCEEDS_REQUESTED_BUFFER" if short else "ENVELOPE_FITS", "normal_success": not short})

## initWithMipmaps: after the gate passes, UNPACK_ALIGNMENT and the name change, then a GL error
## returns false: the new name/alignment and the OLD metadata coexist (no restore).
static func init_with_mipmaps(tex: Dictionary, gate_ok: bool, new_w: int, new_h: int, alignment: int, gl_error: bool) -> Dictionary:
	var out: Dictionary = tex.duplicate(true)
	if not gate_ok:
		return {"texture": out, "return_bool": false, "mutated": false}
	out["unpack_alignment"] = alignment
	out["name"] = int(tex.get("name", 0)) + 1
	if gl_error:
		return {"texture": out, "return_bool": false, "mutated": true, "restored": false}
	out["width"] = new_w
	out["height"] = new_h
	return {"texture": out, "return_bool": true, "mutated": true}

## updateWithData never calls glGetError: name 0 -> false, otherwise true after submit. The Surface
## caller ignores this bool.
static func update_with_data(name: int) -> Dictionary:
	if name == 0:
		return {"return_bool": false, "submitted": false, "gl_error_checked": false}
	return {"return_bool": true, "submitted": true, "gl_error_checked": false, "surface_uses_bool": false}
