extends VBoxContainer
const POLICY = preload("res://scripts/npc/teleport_policy.gd")
var hud: Node
var world: Node
var listing: ItemList
var detail: Label
var travel: Button
var destinations: Array[Dictionary] = []
var selected_index: int = -1

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.text = "아덴 텔레포트 · 현재 월드 25개 지역"
	add_child(heading)
	listing = ItemList.new()
	listing.name = "NpcTeleportDestinations"
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	add_child(listing)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)
	travel = Button.new()
	travel.name = "NpcTeleportConfirm"
	travel.text = "지역 선택"
	travel.pressed.connect(_travel)
	add_child(travel)
	_refresh()

func _refresh() -> void:
	listing.clear()
	destinations.clear()
	selected_index = -1
	var source: Array = world.get("maps")
	for raw: Variant in source:
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw as Dictionary
		var map_id: String = str(row.get("id", ""))
		if not (world.get("maps_by_id") as Dictionary).has(map_id):
			continue
		destinations.append({"id":map_id,"name":str(row.get("name",map_id))})
		var rule: Dictionary = POLICY._rule(map_id)
		listing.add_item("%s · %d레벨 / %d 아데나" % [
			str(row.get("name",map_id)), int(rule["min_level"]), int(rule["price"])
		])
	if not destinations.is_empty():
		listing.select(0)
		_select(0)

func _select(index: int) -> void:
	if index < 0 or index >= destinations.size():
		return
	selected_index = index
	var row: Dictionary = destinations[index]
	var req: Dictionary = POLICY.quote(
		str(row["id"]),world.get("maps_by_id"),str(world.get("active_map_id")),
		int(world.get("level")),int(world.get("gold"))
	)
	var rule: Dictionary = POLICY._rule(str(row["id"]))
	detail.text = "%s · 필요 레벨 %d · 비용 %d 아데나%s" % [
		str(row["name"]), int(rule["min_level"]), int(rule["price"]),
		"" if bool(req.get("ok",false)) else " · " + str(req.get("reason",""))
	]
	travel.disabled = not bool(req.get("ok",false))
	travel.text = "선택한 지역으로 이동" if not travel.disabled else "이동할 수 없습니다"

func _travel() -> void:
	if selected_index < 0 or selected_index >= destinations.size():
		return
	var map_id: String = str(destinations[selected_index]["id"])
	if hud.has_signal("npc_teleport_requested"):
		hud.emit_signal("npc_teleport_requested",map_id)
