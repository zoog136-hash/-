extends VBoxContainer
## Destination selection is separate from the existing combat AUTO toggle.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var world: Node
var entries: Array = []
var regions: OptionButton
var landings: OptionButton
var details: Label
var status: Label
var selected_id: int = -1

func configure(owner_world: Node) -> void:
	world = owner_world
	name = "AutoHuntingDestinations"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(HSeparator.new())
	add_child(UI.label("자동사냥 지역", 18, UI.GOLD))
	if not world.has_method("auto_hunting_destinations"):
		return
	var catalog: Dictionary = world.call("auto_hunting_destinations")
	entries = catalog.get("entries", [])
	if entries.is_empty():
		add_child(UI.label(str(catalog.get("reason", "자동사냥 지역 자료를 설치해 주세요")), 13))
		return
	regions = OptionButton.new()
	regions.name = "AutoHuntingRegion"
	regions.custom_minimum_size.y = 42
	regions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regions.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for entry: Dictionary in entries:
		var title: String = str(entry.hunting_territory.Name) if entry.hunting_territory is Dictionary else str(entry.destinations[0].territory.Name)
		regions.add_item("%s · 권장 Lv.%d" % [title, int(entry.schedule.RecommendLevel)])
	add_child(regions)
	landings = OptionButton.new()
	landings.name = "AutoHuntingLanding"
	landings.custom_minimum_size.y = 42
	landings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	landings.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(landings)
	details = UI.label("", 13)
	details.name = "AutoHuntingDestinationDetails"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	status = UI.label("", 13)
	status.name = "AutoHuntingMovementStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	regions.item_selected.connect(_select_region)
	landings.item_selected.connect(_select_landing)
	_select_region(0)

func _select_region(index: int) -> void:
	if index < 0 or index >= entries.size(): return
	selected_id = index
	var entry: Dictionary = entries[index]
	landings.clear()
	for landing: Dictionary in entry.destinations:
		landings.add_item(str(landing.territory.Name))
	landings.visible = entry.destinations.size() > 1
	var minimum: int = 0
	for condition: Dictionary in entry.prerequisites:
		if str(condition.type.Name) == "MinLevel": minimum = maxi(minimum, int(condition.definition.Value))
	var cost: String = "%d 아데나" % int(entry.teleport.TeleportCost) if entry.currency.Name == "Adena" else "%d %s" % [int(entry.teleport.TeleportCost), str(entry.currency.Name)]
	details.text = "이동 비용 %s\n%s\n%s" % [cost,
		"입장 Lv.%d 이상" % minimum if minimum > 0 else "별도 레벨 입장 조건 없음",
		"사냥 영역 미지정 · 도착 지역만 제공" if entry.hunting_territory == null else "사냥 영역과 도착 지역은 별도 지정"]
	_select_landing(0)

func _select_landing(index: int) -> void:
	if selected_id < 0: return
	var entry: Dictionary = entries[selected_id]
	if index < 0 or index >= entry.destinations.size(): return
	var assessment: Dictionary = world.call("auto_hunting_movement_assessment", int(entry.schedule.ID), int(entry.destinations[index].link.ID))
	status.text = str(assessment.get("reason", "이동 조건 확인 중"))
