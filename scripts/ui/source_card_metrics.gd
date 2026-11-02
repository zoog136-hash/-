extends RefCounted
## Original card slot geometry, adapted uniformly to the available four-column
## list. Text remains a separate accessible ItemList label; no texture generated.
const PROFILE = preload("res://data/ui/base508_card_layout.json")
const PREFAB = "UI/Change/Change_Card_A_Common.csb"

static func apply(hud: Node) -> void:
	if hud.catalog_category not in ["변신", "마법인형", "성물"]: return
	var records: Array = hud.catalog_data.get(hud.catalog_category, [])
	if records.is_empty() or records[0].get("source", "") != "lineagem_base508": return
	var slot := Vector2.ZERO
	var portrait := Vector2.ZERO
	for node: Dictionary in PROFILE.data.screens[PREFAB]:
		if node.name == "Panel_Root": slot = Vector2(node.size[0], node.size[1])
		if node.name == "Sp_Card_Common": portrait = Vector2(node.size[0], node.size[1])
	if slot.x <= 0 or portrait.x <= 0: return
	var list: ItemList = hud.catalog_list
	var available: float = list.size.x - list.get_v_scroll_bar().size.x - 16.0
	if available <= 0: return
	var scale_factor: float = minf(1.0, available / (slot.x * 4.0))
	var column_width: int = maxi(1, floori(slot.x * scale_factor))
	var icon_size := Vector2i(maxi(1, floori(portrait.x * scale_factor)), maxi(1, floori(portrait.y * scale_factor)))
	if list.fixed_column_width != column_width or list.fixed_icon_size != icon_size:
		list.max_columns = 4
		list.fixed_column_width = column_width
		list.fixed_icon_size = icon_size
	list.set_meta("source_card_geometry", {"prefab":PREFAB, "slot":slot, "portrait":portrait, "scale":scale_factor})
