extends RefCounted
## C20 / P5. DESIGN_NOT_RECOVERED_API. One inventory slot's display state. The server's
## quantity is kept apart from the string that happens to be shown.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

static func make_slot() -> Dictionary:
	return {"record": "InventorySlotViewModel", "design_status": VOCAB.EVIDENCE_DESIGN, "item_identity": null, "icon": null, "animation": null,
		"quantity_i64": 0, "enchant_i32": 0, "name": "", "color": "BLACK", "badges": {"tag": null, "asset": null, "visible": false},
		"old_text": "", "visible_flags": {"quantity": false, "enchant": false, "badge": false}}

static func _group(value: int) -> String:
	var digits: String = str(value)
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return out

## Korean mode 1: truncating man (10,000) and eok (100,000,000) units with digit grouping.
@warning_ignore("integer_division")
static func korean_quantity_mode1(quantity: int) -> Dictionary:
	if quantity <= 1:
		return {"text": "", "visible": false}
	if quantity >= 100000000:
		return {"text": _group(quantity / 100000000) + "억", "visible": true}
	if quantity >= 10000:
		return {"text": _group(quantity / 10000) + "만", "visible": true}
	return {"text": _group(quantity), "visible": true}

## Quantity <= 1 only hides; the previously stored text is kept.
static func set_quantity(slot: Dictionary, quantity: int) -> Dictionary:
	var out: Dictionary = slot.duplicate(true)
	out["quantity_i64"] = quantity
	var shown: Dictionary = korean_quantity_mode1(quantity)
	out["visible_flags"]["quantity"] = shown.visible
	if shown.visible:
		out["old_text"] = shown.text
	return out

static func set_enchant(slot: Dictionary, enchant: int) -> Dictionary:
	var out: Dictionary = slot.duplicate(true)
	out["enchant_i32"] = enchant
	out["visible_flags"]["enchant"] = enchant > 0
	return out

## Badge: same tag changes visibility only; a different tag with visible=false does nothing;
## a different tag with visible=true applies the new asset and tag.
static func apply_badge(slot: Dictionary, tag: Variant, asset: Variant, visible: bool) -> Dictionary:
	var out: Dictionary = slot.duplicate(true)
	var current: Variant = out.badges.tag
	if current == tag:
		out["badges"]["visible"] = visible
	elif visible:
		out["badges"] = {"tag": tag, "asset": asset, "visible": true}
	out["visible_flags"]["badge"] = out.badges.visible
	return out

## An icon/animation cache hit still refreshes quantity, enchant and badge.
static func refresh_slot(slot: Dictionary, icon_cache_hit: bool, quantity: int, enchant: int, badge_tag: Variant, badge_asset: Variant, badge_visible: bool) -> Dictionary:
	var out: Dictionary = set_quantity(slot, quantity)
	out = set_enchant(out, enchant)
	out = apply_badge(out, badge_tag, badge_asset, badge_visible)
	out["icon_cache_hit"] = icon_cache_hit
	return out

## A failed item or row resolve does not clear the existing slot.
static func resolve_failed(slot: Dictionary) -> Dictionary:
	return slot.duplicate(true)

static func grade_color(grade_color_row: Variant) -> String:
	return str(grade_color_row) if grade_color_row != null and str(grade_color_row) != "" else "BLACK"
