extends RefCounted
## M52 (C11/C12, R52). DESIGN_NOT_RECOVERED_API. Label atlas assignment side effects and locale
## listener priorities. The +3CC byte has no confirmed name; it is kept as "byte3CC".
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

const PURGE_LISTENER_PRIORITY := 1
const RESET_LISTENER_PRIORITY := 2

static func make_label(atlas: Variant, byte3cc: int) -> Dictionary:
	return {"atlas": atlas, "byte3CC": byte3cc, "retains": [], "releases": []}

## Same non-null atlas: byte3CC is cleared first, ownership swap is skipped (no retain/release).
## Same null: nothing, not even the clear. Different non-null: clear then ownership swap
## (CONDITIONAL: the exact swap order is not in this package). non-null -> null is not described.
static func set_atlas(label: Dictionary, new_atlas: Variant) -> Dictionary:
	var out: Dictionary = label.duplicate(true)
	var old: Variant = label.atlas
	if new_atlas == null and old == null:
		return V.rec("SetAtlas", "M52", V.CONFIRMED, {"label": out, "cleared_3cc": false, "ownership_swapped": false})
	if new_atlas == null:
		return V.rec("SetAtlas", "M52", V.NOT_DESCRIBED, {"label": out, "cleared_3cc": null, "ownership_swapped": null})
	out["byte3CC"] = 0
	if new_atlas == old:
		return V.rec("SetAtlas", "M52", V.CONFIRMED, {"label": out, "cleared_3cc": true, "ownership_swapped": false})
	(out.retains as Array).append(new_atlas)
	if old != null:
		(out.releases as Array).append(old)
	out["atlas"] = new_atlas
	return V.rec("SetAtlas", "M52", V.CONDITIONAL, {"label": out, "cleared_3cc": true, "ownership_swapped": true})

## Fixed priorities only; they do not prove the real order of different events or thread safety.
static func listener_priorities() -> Dictionary:
	return {"purge": PURGE_LISTENER_PRIORITY, "reset": RESET_LISTENER_PRIORITY, "event_order_proven": false}

## Locale reload: cache clear, table reload gate, UTF conversion and the later layout are four
## separate results. There is no single combined "success".
static func locale_reload(cache_cleared: bool, reload_gate_open: bool, utf_ok: bool, layout_ok: Variant) -> Dictionary:
	return V.rec("LocaleReload", "M52", V.CONFIRMED, {"cache_cleared": cache_cleared, "table_reload": reload_gate_open,
		"utf_conversion_ok": utf_ok, "layout_result": layout_ok if layout_ok != null else V.UNKNOWN, "combined_success": null})
