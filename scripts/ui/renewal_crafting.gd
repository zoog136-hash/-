extends VBoxContainer
const CRAFT = preload("res://scripts/crafting/local_crafting.gd")
var hud: Node
var world: Node
var listing: ItemList
var details: Label
var batches: SpinBox
var craft_button: Button
var recipe_ids: Array[String] = []
var selected_id: String = ""

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "아덴 제작 장인 · TWILIGHT 로컬 조제식"
	add_child(title)
	listing = ItemList.new()
	listing.name = "CraftRecipes"
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	add_child(listing)
	for id: String in CRAFT.RECIPES.keys():
		var recipe: Dictionary = CRAFT.RECIPES[id]
		recipe_ids.append(id)
		listing.add_item(str(recipe["title"]))
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	label.text = "제작 횟수"
	row.add_child(label)
	batches = SpinBox.new()
	batches.name = "CraftBatches"
	batches.min_value = 1
	batches.max_value = CRAFT.MAX_BATCH
	batches.step = 1
	batches.value = 1
	batches.value_changed.connect(func(_value: float) -> void: _update_quote())
	row.add_child(batches)
	craft_button = Button.new()
	craft_button.name = "CraftExecute"
	craft_button.text = "제작"
	craft_button.pressed.connect(_craft)
	row.add_child(craft_button)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	if not recipe_ids.is_empty():
		listing.select(0)
		_select(0)

func _select(index: int) -> void:
	if index < 0 or index >= recipe_ids.size():
		return
	selected_id = recipe_ids[index]
	_update_quote()

func _update_quote() -> void:
	if selected_id.is_empty():
		return
	var recipe: Dictionary = CRAFT.RECIPES[selected_id]
	var count: int = int(batches.value)
	var materials: PackedStringArray = []
	for name: Variant in (recipe["materials"] as Dictionary).keys():
		materials.append("%s ×%d" % [str(name),int(recipe["materials"][name]) * count])
	var report: Dictionary = CRAFT.quote(
		selected_id,count,world.get("inventory"),int(world.get("gold")),
		world.get("loot_catalog"),world.get("item_weight_index"),
		int(world.call("_inventory_total_weight")),int(world.call("_carrying_capacity"))
	)
	details.text = "%s ×%d\n필요 재료: %s\n제작 비용: %d 아데나\n%s" % [
		str(recipe["output"]),int(recipe["output_count"]) * count,
		", ".join(materials),int(recipe["gold"]) * count,
		"제작 가능" if bool(report.get("ok",false)) else str(report.get("reason","제작 불가"))
	]
	craft_button.disabled = not bool(report.get("ok",false))

func _craft() -> void:
	if selected_id.is_empty():
		return
	if hud.has_signal("craft_requested"):
		hud.emit_signal("craft_requested",selected_id,int(batches.value))
