extends RefCounted
## Static own-SPR104 metadata only. Native loader035FBA67 replaces the 9-bit
## field on every104; aliases and file remaps do not OR/inherit this field.
## This does not resolve dynamic actor+134, extra+138, effect maps or draw gates.
const FLAG_MASK: int = 0x1ff

static func _failure(message: String) -> Dictionary:
	return {"ok":false,"flags":0,"present":false,"origin":"unresolved_own_104","error":message}

## Consume the caller's ordered own104 bodies without modifying its raw trace.
## Signed decimal accumulation retains only the low9 bits, avoiding int64
## conversion overflow. A malformed entry invalidates the projection, even if
## a later entry is valid; unsupported source syntax is never silently skipped.
static func resolve(attributes: Array) -> Dictionary:
	var flags: int = 0
	for raw: Variant in attributes:
		if not raw is String: return _failure("Own104 body is not a decimal string.")
		var value: String = raw.strip_edges()
		if value.is_empty(): return _failure("Own104 body is empty.")
		var start: int = 0
		var negative: bool = false
		if value[0] in ["+","-"]:
			negative = value[0] == "-"
			start = 1
		if start == value.length(): return _failure("Own104 body has no decimal digits.")
		var low: int = 0
		for index: int in range(start,value.length()):
			var digit: int = value.unicode_at(index) - 48
			if digit < 0 or digit > 9: return _failure("Own104 body contains non-decimal syntax.")
			low = (low * 10 + digit) & FLAG_MASK
		flags = (-low if negative else low) & FLAG_MASK
	return {"ok":true,"flags":flags,"present":not attributes.is_empty(),
		"origin":"last_own_104_decimal_low9" if not attributes.is_empty() else "absent_own_104_default_zero"}

## Caller must first verify this complete declaration path against its pinned
## source proof. The compiler orders it requested ID first, mapped aliases last.
## Explicit owner identity and alias links prevent selecting a physical target
## or an unrelated role actor. Only path[0]'s104 bodies affect the projection;
## the caller keeps every path entry as evidence, including unused alias attrs.
static func resolve_own_path(path: Array, requested_sprite_id: int) -> Dictionary:
	if requested_sprite_id < 0 or path.is_empty(): return _failure("Missing own104 metadata owner/path.")
	var seen: Dictionary = {}
	for index: int in range(path.size()):
		var entry: Variant = path[index]
		if not entry is Dictionary or not entry.get("sprite_id") is int or int(entry.sprite_id) < 0 or not entry.has("alias_target"):
			return _failure("Invalid own104 declaration identity.")
		var sprite_id: int = int(entry.sprite_id)
		if seen.has(sprite_id): return _failure("Cyclic own104 declaration path.")
		seen[sprite_id] = true
		if index == 0 and sprite_id != requested_sprite_id: return _failure("Own104 metadata owner differs from requested ID.")
		var target: Variant = entry.alias_target
		if index + 1 == path.size():
			if target != null: return _failure("Own104 declaration alias path is incomplete.")
		else:
			var next: Variant = path[index+1]
			if not target is int or not next is Dictionary or next.get("sprite_id") != target:
				return _failure("Own104 declaration alias link differs from its proof path.")
	var directives: Variant = path[0].get("literal_attribute_directives")
	if not directives is Array: return _failure("Own104 directives were not supplied.")
	var attributes: Array = []
	for directive: Variant in directives:
		if not directive is Dictionary or not directive.get("code") is int or int(directive.code) != 104 or not directive.get("body") is String or not directive.get("line") is int or int(directive.line) < 1:
			return _failure("Invalid own104 directive evidence.")
		attributes.append(directive.body)
	var projected: Dictionary = resolve(attributes)
	if not projected.ok: return projected
	projected["owner_sprite_id"] = requested_sprite_id
	projected["owner_path_index"] = 0
	return projected
