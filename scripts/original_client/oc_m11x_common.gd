extends RefCounted
## DESIGN_NOT_RECOVERED_API. Shared helpers for the M110-M123 design modules (reference package
## 01-123, guide sections M110-M123). Nothing here is recovered original C++; every record is a
## new TWILIGHT type that follows the written contract. No original binary is executed.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

## Evidence levels as named by the 01-123 guide. They are separate from the 01-46 vocabulary.
const EVIDENCE_CONFIRMED := "CONFIRMED_BOUNDED_STATIC"
const EVIDENCE_CONDITIONAL := "CONDITIONAL"
const EVIDENCE_UNKNOWN := "UNKNOWN"
const DESIGN := "DESIGN_NOT_RECOVERED_API"

## Outcome label for a path where the original has no guard (null dereference, bad_function_call,
## IDIV by zero, ...). The design module stops and reports it; this is NOT a safe original return.
const UNGUARDED_BOUNDARY := "UNGUARDED_ORIGINAL_BOUNDARY_NOT_A_SAFE_RETURN"

static func i32(v: int) -> int:
	return VOCAB.i32(v)

static func u32(v: int) -> int:
	return VOCAB.u32(v)

static func i8(v: int) -> int:
	return VOCAB.i8(v)

static func u16(v: int) -> int:
	return VOCAB.u16(v)

## uint64 values are carried in a GDScript int (two's complement). 0xFFFF...FF is -1.
static func u64_gt(a: int, b: int) -> bool:
	if (a < 0) != (b < 0):
		return a < 0
	return a > b

## low64(a + b) without relying on signed-overflow behaviour.
static func u64_add(a: int, b: int) -> int:
	var lo: int = (a & 0xFFFFFFFF) + (b & 0xFFFFFFFF)
	var hi: int = ((a >> 32) & 0xFFFFFFFF) + ((b >> 32) & 0xFFFFFFFF) + (lo >> 32)
	return ((hi & 0xFFFFFFFF) << 32) | (lo & 0xFFFFFFFF)

## "0x..." hex text to a 64-bit pattern (JSON cannot carry uint64 exactly).
static func u64_from_hex(text: String) -> int:
	var s: String = text.trim_prefix("0x").trim_prefix("0X")
	var v: int = 0
	for ch: String in s:
		v = (v << 4) | ch.hex_to_int()
	return v

## C/C++ remainder: truncates toward zero, so the sign follows the dividend.
@warning_ignore("integer_division")
static func rem_trunc(a: int, b: int) -> int:
	var q: int = absi(a) / absi(b)
	if (a < 0) != (b < 0):
		q = -q
	return a - q * b

## C/C++ signed division (truncates toward zero). b == 0 is an unguarded boundary for callers.
@warning_ignore("integer_division")
static func div_trunc(a: int, b: int) -> int:
	var q: int = absi(a) / absi(b)
	return -q if (a < 0) != (b < 0) else q

## Shared control block model (+8 strong, +0C weak). Events record vslot0/vslot8 requests.
static func make_control(strong: int = 1, weak: int = 1) -> Dictionary:
	return {"record": "ControlBlock", "strong": strong, "weak": weak, "events": []}

static func retain(control: Variant) -> void:
	if control != null:
		control["strong"] = int(control.strong) + 1

## release_local: strong decrement; on last strong vslot0, then weak decrement; on last weak vslot8.
static func release_local(control: Variant) -> void:
	if control == null:
		return
	var old_strong: int = int(control.strong)
	control["strong"] = old_strong - 1
	(control.events as Array).append("strong-decrement")
	if old_strong == 1:
		(control.events as Array).append("destroy-owned")
		var old_weak: int = int(control.weak)
		control["weak"] = old_weak - 1
		if old_weak == 1:
			(control.events as Array).append("destroy-control")

## Signed lower_bound + exact reject over rows already in native sorted order. Returns the index
## of the FIRST row whose key equals `key`, or -1. key_fn maps a row to a comparable Array of
## signed int32 values (lexicographic). The caller keeps the "valid sorted table" prerequisite.
static func lower_bound_exact(rows: Array, key_fn: Callable, key: Array) -> int:
	var lo: int = 0
	var hi: int = rows.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if lex_less(key_fn.call(rows[mid]), key):
			lo = mid + 1
		else:
			hi = mid
	if lo < rows.size() and not lex_less(key, key_fn.call(rows[lo])):
		return lo
	return -1

static func lex_less(a: Array, b: Array) -> bool:
	for i: int in mini(a.size(), b.size()):
		var x: int = i32(int(a[i]))
		var y: int = i32(int(b[i]))
		if x != y:
			return x < y
	return a.size() < b.size()

## UI alias + dot path lookup (M74 contract): ASCII-normalised alias table, absent alias resolves to
## an empty string; dot tokens skip empties; each hop takes the FIRST direct child with that name.
static func resolve_alias(aliases: Dictionary, key: String) -> String:
	return str(aliases.get(VOCAB.lower_ascii(key), aliases.get(key, "")))

static func dot_path(root: Variant, path: String) -> Variant:
	if root == null:
		return null
	var tokens: Array = []
	for t: String in path.split("."):
		if not t.is_empty():
			tokens.append(t)
	if tokens.is_empty():
		return null
	var node: Variant = root
	for t: String in tokens:
		var found: Variant = null
		for child: Variant in node.get("children", []):
			if child.name == t:
				found = child
				break
		if found == null:
			return null
		node = found
	return node

static func typed_child(root: Variant, aliases: Dictionary, key: String, node_type: String) -> Variant:
	var alias: String = resolve_alias(aliases, key)
	if alias.is_empty() or root == null:
		return null
	var node: Variant = dot_path(root, alias)
	if node == null or node.type != node_type:
		return null
	return node

static func make_node(node_name: String, node_type: String, children: Array = []) -> Dictionary:
	return {"name": node_name, "type": node_type, "children": children, "visible": true, "text": null, "texture": null, "set_calls": 0}

## Typed DynamicData<int> read: absent or failed cast -> 0; success -> signed DWORD.
static func typed_int_or_zero(map: Dictionary, key: String) -> int:
	if not map.has(key):
		return 0
	var v: Variant = map[key]
	if v is int:
		return i32(v)
	return 0

## Typed pointer read: absent or failed cast -> null (no manufactured default).
static func typed_int_pointer(map: Dictionary, key: String) -> Variant:
	var v: Variant = map.get(key)
	return i32(v) if v is int else null

## JSON parse that reports failure as null without engine error output (status-checked like the
## original 006CC790 consumer; arbitrary JSON types are not interpreted further).
static func parse_json_quiet(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data
