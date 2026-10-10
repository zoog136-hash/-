extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var world: Node
var listing: ItemList
var detail: RichTextLabel
var amount: SpinBox
var action: Button
var recipe_ids: Array[String] = []
var current_id: String = ""

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.label("제작 장인 · TWILIGHT 로컬 제작법",20,UI.GOLD))
	add_child(UI.label("재료 및 아데나를 확인한 뒤 제작합니다. 강화·장착 장비는 재료로 소모되지 않습니다.",12,UI.MUTED))
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(UI.label("제작 수량",13,UI.TEXT))
	amount = SpinBox.new()
	amount.name = "CraftQuantity"
	amount.min_value = 1
	amount.max_value = 20
	amount.step = 1
	amount.value = 1
	amount.value_changed.connect(func(_value: float) -> void: _refresh_quote())
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(amount)
	action = UI.button("제작 실행",_craft,Vector2(180,42))
	action.name = "CraftExecute"
	row.add_child(action)
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(layout)
	listing = ItemList.new()
	listing.name = "CraftRecipes"
	listing.custom_minimum_size.x = 260
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	layout.add_child(listing)
	detail = UI.rich("")
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(detail)
	var data: Object = world.get("crafting")
	var registry: Dictionary = data.get("recipes")
	for raw_id: Variant in registry.keys():
		var id: String = str(raw_id)
		var recipe: Dictionary = registry[id]
		recipe_ids.append(id)
		listing.add_item(str(recipe.get("name",id)))
	if recipe_ids.is_empty():
		detail.text = "사용 가능한 제작법이 없습니다."
		action.disabled = true
	else:
		listing.select(0)
		_select(0)

func _select(index: int) -> void:
	if index < 0 or index >= recipe_ids.size():
		return
	current_id = recipe_ids[index]
	_refresh_quote()

func _refresh_quote() -> void:
	if current_id.is_empty():
		return
	var service: Object = world.get("crafting")
	var recipe: Dictionary = (service.get("recipes") as Dictionary).get(current_id,{})
	var count: int = int(amount.value)
	var quote: Dictionary = world.call("_craft_quote",current_id,count)
	var content: String = "[color=#d8b878][font_size=20]%s[/font_size][/color]\n\n" % UI.safe(recipe.get("name",""))
	content += "제작 결과: %s ×%d\n아데나: %d\n\n필요 재료:\n" % [
		UI.safe((recipe.get("result",{}) as Dictionary).get("item","")),
		int((recipe.get("result",{}) as Dictionary).get("quantity",0))*count,
		int(recipe.get("adena",0))*count
	]
	var inventory: Dictionary = world.get("inventory")
	for raw: Variant in recipe.get("materials",[]):
		if raw is Dictionary:
			var material: Dictionary = raw as Dictionary
			var name: String = str(material.get("item",""))
			content += "· %s ×%d / 보유 %d\n" % [UI.safe(name),int(material.get("quantity",0))*count,int(inventory.get(name,0))]
	content += "\n" + ("제작 가능" if bool(quote.get("ok",false)) else UI.safe(quote.get("reason","제작 불가")))
	detail.text = content
	action.disabled = not bool(quote.get("ok",false))
	action.text = "제작 실행 · %d개" % count

func _craft() -> void:
	if current_id.is_empty():
		return
	if hud.has_signal("craft_requested"):
		hud.emit_signal("craft_requested",current_id,int(amount.value))
