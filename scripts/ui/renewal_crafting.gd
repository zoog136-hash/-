extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser=preload("res://scripts/ui/renewal_browser.gd")
var hud: Node
var world: Node
var listing: ItemList
var detail: RichTextLabel
var amount: SpinBox
var action: Button
var recipe_ids: Array[String] = []
var all_recipe_ids: Array[String] = []
var category_filter: OptionButton
var grade_filter: OptionButton
var name_filter: LineEdit
var current_id: String = ""

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.section("제작법",19))
	add_child(UI.label("재료 및 아데나를 확인한 뒤 제작합니다. 강화·장착 장비는 재료로 소모되지 않습니다.",12,UI.MUTED))
	var filters := HBoxContainer.new()
	add_child(filters)
	category_filter = OptionButton.new()
	category_filter.name = "CraftCategoryFilter"
	for title: String in ["전체", "물약", "무기", "방어구", "장신구"]:
		category_filter.add_item(title)
	category_filter.select(0)
	category_filter.item_selected.connect(func(_selected: int) -> void: _rebuild_listing())
	filters.add_child(category_filter)
	grade_filter = OptionButton.new()
	grade_filter.name = "CraftGradeFilter"
	for grade_title: String in ["전체 등급","일반","고급","희귀","영웅","전설","신화","유일"]:
		grade_filter.add_item(grade_title)
	grade_filter.select(0)
	grade_filter.item_selected.connect(func(_selection: int) -> void: _rebuild_listing())
	filters.add_child(grade_filter)
	name_filter = LineEdit.new()
	name_filter.name = "CraftNameFilter"
	name_filter.placeholder_text = "제작법 / 결과 아이템 검색"
	name_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_filter.text_changed.connect(func(_value: String) -> void: _rebuild_listing())
	filters.add_child(name_filter)
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
	UI.primary_button(action)
	action.name = "CraftExecute"
	row.add_child(action)
	var layout := Browser.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(layout)
	listing = ItemList.new()
	listing.set_script(preload("res://scripts/ui/native_touch_list.gd"))
	listing.name = "CraftRecipes"
	listing.fixed_icon_size = Vector2i(36,36)
	listing.custom_minimum_size.x = 260
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	layout.add_child(listing)
	var inspector:=VBoxContainer.new()
	inspector.size_flags_vertical=Control.SIZE_EXPAND_FILL
	layout.add_child(inspector)
	detail = UI.rich("")
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector.add_child(detail)
	row.reparent(inspector)
	layout.configure(listing,inspector,330)
	var data: Object = world.get("crafting")
	var registry: Dictionary = data.get("recipes")
	for raw_id: Variant in registry.keys():
		var id: String = str(raw_id)
		var recipe: Dictionary = registry[id]
		all_recipe_ids.append(id)
	_rebuild_listing()

func _rebuild_listing() -> void:
	listing.clear()
	recipe_ids.clear()
	var selected_category: String = category_filter.get_item_text(category_filter.selected)
	var selected_grade: String = grade_filter.get_item_text(grade_filter.selected)
	var item_records: Dictionary = world.call("_craft_item_index")
	var needle: String = name_filter.text.strip_edges().to_lower()
	var service: Object = world.get("crafting")
	var registry: Dictionary = service.get("recipes")
	for id: String in all_recipe_ids:
		var recipe: Dictionary = registry.get(id,{})
		var output: Dictionary = recipe.get("result",{})
		var match_text: String = (str(recipe.get("name","")) + " " + str(output.get("item",""))).to_lower()
		if selected_category != "전체" and str(recipe.get("category","")) != selected_category:
			continue
		var output_name: String = str(output.get("item",""))
		var grade: String = str((item_records.get(output_name,{}) as Dictionary).get("grade","일반"))
		if selected_grade != "전체 등급" and grade != selected_grade:
			continue
		if not needle.is_empty() and not match_text.contains(needle):
			continue
		recipe_ids.append(id)
		listing.add_item("[%s] %s" % [grade,str(recipe.get("name",id))],UI.item_icon(item_records.get(output_name,{}),output_name,hud.item_image_index.get("아이템",{})))
	if recipe_ids.is_empty():
		current_id = ""
		detail.text = "조건에 맞는 제작법이 없습니다."
		action.disabled = true
		return
	var choice: int = recipe_ids.find(current_id)
	if choice < 0:
		choice = 0
	listing.select(choice)
	_select(choice)

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
		var id: String = current_id
		var count: int = int(amount.value)
		var report: Dictionary = world._craft_quote(id,count)
		if not bool(report.get("ok",false)): return
		hud.confirm_action("제작 확인","선택한 제작식 ×%d\n표시된 재료와 아데나를 소모합니다." % count,"제작",func(_amount: int) -> void:
			hud.emit_signal("craft_requested",id,count))
