extends RefCounted
## M96 shader compiler input assembly, M98 uniform location flags/cache, M101 clear MVP binary32
## arithmetic, M106 Sprite type1/type31 shader source (C14/C18/C13). DESIGN_NOT_RECOVERED_API.
## All outputs are API REQUESTS with their inputs. Compile/link/GPU/pixel results are never claimed.
const V = preload("res://scripts/original_client/oc_m82_m109_vocab.gd")
const GL_VERTEX_SHADER := 0x8B31
const GL_FRAGMENT_SHADER := 0x8B30

# ---------------------------------------------------------------- M96
## 0033184C: an EMPTY define string leaves the output unchanged (not cleared). Otherwise ';' is
## appended if missing, every nonempty token becomes "\n#define <token>", then one "\n".
## No '=' substitution, trim, escape, dedup or validation.
static func transform_defines(defines: String, output: String) -> String:
	if defines.is_empty():
		return output
	var tmp: String = defines if defines.ends_with(";") else defines + ";"
	var out: String = output
	var token := ""
	for ch: String in tmp:
		if ch == ";":
			if not token.is_empty():
				out += "\n#define " + token
				token = ""
		else:
			token += ch
	return out + "\n"

## 003305BC compile helper. Source null -> false with NO out write. Four fragments in order
## [header_copy, prelude, transformed_defines, source], no lengths array. Result is
## (status==1) when status != 0; an unwritten status is an undefended input.
static func compile_stage(stage_type: int, source: Variant, header: String, prelude: String, defines_out: String, status: Variant) -> Dictionary:
	if source == null:
		return {"result": false, "out_written": false, "requests": []}
	var req: Array = [["glCreateShader", stage_type], ["glShaderSource", 4, [header, prelude, defines_out, source], null], ["glCompileShader"], ["glGetShaderiv", 0x8B81]]
	if status == null:
		return {"result": null, "out_written": true, "requests": req, "status": V.REJECTED_UNDEFENDED, "note": "compile_status local is not initialised before the query"}
	var s: int = int(status)
	var result := false
	if s == 0:
		req.append_array([["glGetShaderiv", 0x8B88], ["malloc"], ["glGetShaderSource"], ["free"]])
	else:
		result = s == 1
	return {"result": result, "out_written": true, "requests": req, "no_info_log_no_delete": true}

## 00330C78: the program is created even if both sources are null; stage fields zeroed; vertex
## first; a failure returns false keeping program/stage handles (no GPU delete here).
static func init_program(vertex: Variant, fragment: Variant, header: String, prelude: String, defines: String, vertex_status: Variant, fragment_status: Variant) -> Dictionary:
	var req: Array = [["glCreateProgram"]]
	var dout: String = transform_defines(defines, "")
	var prog := {"program": "created", "vertex": 0, "fragment": 0}
	if vertex != null:
		var v: Dictionary = compile_stage(GL_VERTEX_SHADER, vertex, header, prelude, dout, vertex_status)
		req.append_array(v.requests)
		prog["vertex"] = "vs"
		if v.result != true:
			return {"result": false, "program": prog, "requests": req, "fragment_reached": false}
	if fragment != null:
		var f: Dictionary = compile_stage(GL_FRAGMENT_SHADER, fragment, header, prelude, dout, fragment_status)
		req.append_array(f.requests)
		prog["fragment"] = "fs"
		if f.result != true:
			return {"result": false, "program": prog, "requests": req, "fragment_reached": true}
	if str(prog.vertex) != "0":
		req.append(["glAttachShader", "vs"])
	if str(prog.fragment) != "0":
		req.append(["glAttachShader", "fs"])
	return {"result": true, "program": prog, "requests": req, "compile_link_success_claimed": false}

# ---------------------------------------------------------------- M98
const FLAG_BITS := {"P": 0x20, "multiP": 0x40, "MV": 0x10, "MVP": 0x04, "multiMVP": 0x08, "normal": 0x02, "random": 0x80}

## Flag bit = u32(location) != 0xFFFFFFFF (so -2 turns the bit ON). time01 = any of three.
static func location_flags(old_flags: int, locations: Dictionary, time_locations: Array) -> int:
	var low: int = 0
	for k: String in FLAG_BITS:
		if V.u32(int(locations.get(k, -1))) != 0xFFFFFFFF:
			low |= FLAG_BITS[k]
	for t: int in time_locations:
		if V.u32(t) != 0xFFFFFFFF:
			low |= 0x01
	return (old_flags & ~0xFF) | low

## Cache admission: signed location < 0 -> false (no request). Byte comparison, not float
## equality. Grow reallocates; shrink compares/copies n bytes, keeps stored size and suffix.
## The cache is updated BEFORE the API request; no driver status/rollback.
static func admit(cache: Dictionary, location: int, data: PackedByteArray) -> bool:
	if V.i32(location) < 0:
		return false
	var n: int = data.size()
	if not cache.has(location):
		cache[location] = {"bytes": data.duplicate(), "size": n}
		return true
	var node: Dictionary = cache[location]
	if int(node.size) < n:
		node["bytes"] = data.duplicate()
		node["size"] = n
		return true
	var stored: PackedByteArray = node.bytes
	if stored.slice(0, n) == data:
		return false
	for i: int in n:
		stored[i] = data[i]
	node["bytes"] = stored
	return true

static func uniform4fv(cache: Dictionary, location: int, floats: PackedFloat32Array, count: int) -> Array:
	var bytes: PackedByteArray = floats.to_byte_array().slice(0, V.u32(count << 4))
	if admit(cache, location, bytes):
		return [["glUniform4fv", location, count]]
	return []

static func uniform_matrix4fv(cache: Dictionary, location: int, floats: PackedFloat32Array, count: int) -> Array:
	var bytes: PackedByteArray = floats.to_byte_array().slice(0, V.u32(count << 6))
	if admit(cache, location, bytes):
		return [["glUniformMatrix4fv", location, count, 0]]
	return []

# ---------------------------------------------------------------- M101
## 002E2364 column-major T[4c+r] = ((A[r]B[4c] + A[4+r]B[4c+1]) + A[8+r]B[4c+2]) + A[12+r]B[4c+3]
## with binary32 multiply and left-associated binary32 add, written to a temporary first, then
## copied 64 bytes to D. A = selector1 matrix, B = selector0 matrix. Not FMA, not binary64.
static func mvp_multiply(a: Array, b: Array) -> Array:
	var t: Array = []
	t.resize(16)
	for c: int in 4:
		for r: int in 4:
			var p: Array = []
			for k: int in 4:
				p.append(V.f32(V.f32(float(a[4 * k + r])) * V.f32(float(b[4 * c + k]))))
			t[4 * c + r] = V.f32(V.f32(V.f32(p[0] + p[1]) + p[2]) + p[3])
	return t

## Same math accumulated in binary64 (documents why the order/width matters; NOT the contract).
static func mvp_multiply_binary64(a: Array, b: Array) -> Array:
	var t: Array = []
	t.resize(16)
	for c: int in 4:
		for r: int in 4:
			var s: float = 0.0
			for k: int in 4:
				s += float(a[4 * k + r]) * float(b[4 * c + k])
			t[4 * c + r] = V.f32(s)
	return t

## The arithmetic body writes the temporary first, so D may alias A or B. The initial copy is a
## memcpy and requires non-overlap: an overlapping copy is an undefended input.
static func copy64(dst_range: Vector2i, src_range: Vector2i) -> Dictionary:
	var overlap: bool = dst_range.x < src_range.y and src_range.x < dst_range.y and dst_range != src_range
	if overlap:
		return {"status": V.REJECTED_UNDEFENDED, "note": "memcpy overlap"}
	return {"copied": true}

static func identity_from_hex(hex: String) -> Array:
	var b: PackedByteArray = hex.hex_decode()
	var out: Array = []
	for i: int in 16:
		out.append(b.decode_float(i * 4))
	return out

# ---------------------------------------------------------------- M106
const TYPE_FRAGMENT := {1: "normal", 31: "split"}

## Loader slice: type1 -> normal fragment *007F3D40, type31 -> split *007F3E30, shared vertex.
static func loader_selected(type_id: int) -> Dictionary:
	if not TYPE_FRAGMENT.has(type_id):
		return {"status": V.UNKNOWN, "note": "outside the selected semantics"}
	return {"fragment": TYPE_FRAGMENT[type_id], "vertex": "shared_007F3D48", "init_bool_gate": false, "link_bool_gate": false}

## Source-level math only (exact rational model, not GLSL precision or sampling).
static func normal_output(v: Color, t: Color) -> Color:
	return Color(v.r * t.r, v.g * t.g, v.b * t.b, v.a * t.a)

## split: a = Texture1.r; T.a and Texture1.a are discarded; no discard/threshold.
static func split_output(v: Color, t0: Color, t1: Color) -> Color:
	var a: float = t1.r
	return Color(v.r * t0.r * a, v.g * t0.g * a, v.b * t0.b * a, v.a * a)

## Vertex: noMVP also uses CC_PMatrix * a_position (not an identity assumption).
static func vertex_contract(vertex_text: String) -> Dictionary:
	return {"uses_pmatrix": vertex_text.contains("CC_PMatrix * a_position"), "uses_mvp": vertex_text.contains("CC_MVPMatrix"), "gpu_result": V.NOT_OBSERVED}
