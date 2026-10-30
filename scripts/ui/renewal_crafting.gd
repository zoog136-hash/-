extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser=preload("res://scripts/ui/renewal_browser.gd")
const CraftRules=preload("res://scripts/crafting/expanded_crafting.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
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
var layout: Control
var product: TextureRect
var product_name: Label
var product_grade: Label
var material_grid: GridContainer
var material_scroll: ScrollContainer
var material_rows: Array[Dictionary]=[]
var material_recipe: String=""
var cost: Label
var wallet: Label
var filters: HBoxContainer
var product_title: Label
var price: HBoxContainer
var compact_short: bool=false

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Inspected Korean normal crafting: recipe list, output/quantity, material
	# icon rows with available/required counts, then the existing transaction.
	# https://www.lineagem.com.tw/make/make-shields
	filters = HBoxContainer.new()
	add_child(filters)
	category_filter = OptionButton.new()
	category_filter.name = "CraftCategoryFilter"
	category_filter.custom_minimum_size.y=40
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
	layout = Browser.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(layout)
	listing = ItemList.new()
	listing.set_script(preload("res://scripts/ui/native_touch_list.gd"))
	listing.name = "CraftRecipes"
	listing.fixed_icon_size = Vector2i(44,44)
	listing.max_columns=1
	listing.add_theme_font_size_override("font_size",13)
	listing.custom_minimum_size.x = 260
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(func(index: int) -> void:
		_select(index)
		if layout.size.x<660:
			layout.detail_active=true
			layout.reflow())
	layout.add_child(listing)
	var inspector:=VBoxContainer.new()
	inspector.size_flags_vertical=Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation",5)
	layout.add_child(inspector)
	material_scroll=ScrollContainer.new()
	material_scroll.name="CraftMaterialsScroll"
	material_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	material_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	inspector.add_child(material_scroll)
	var information:=VBoxContainer.new()
	information.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	information.add_theme_constant_override("separation",5)
	material_scroll.add_child(information)
	hud.workspace.register_scroll_drag(material_scroll,information)
	product_title=UI.label("제작 아이템",15,UI.GOLD)
	information.add_child(product_title)
	var result_panel:=PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel",Surfaces.inset(8))
	information.add_child(result_panel)
	hud.workspace.register_scroll_drag(material_scroll,result_panel)
	var result_row:=HBoxContainer.new()
	result_row.add_theme_constant_override("separation",10)
	result_panel.add_child(result_row)
	var result_slot:=PanelContainer.new()
	result_slot.add_theme_stylebox_override("panel",UI.slot_recess())
	result_row.add_child(result_slot)
	product=TextureRect.new()
	product.name="CraftProductIcon"
	product.custom_minimum_size=Vector2(64,64)
	product.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	product.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	product.mouse_filter=Control.MOUSE_FILTER_IGNORE
	result_slot.add_child(product)
	var result_text:=VBoxContainer.new()
	result_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	result_row.add_child(result_text)
	product_name=UI.label("",17)
	product_name.name="CraftProductName"
	product_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result_text.add_child(product_name)
	product_grade=UI.label("",12,UI.MUTED)
	result_text.add_child(product_grade)
	var quantity:=VBoxContainer.new()
	result_row.add_child(quantity)
	quantity.add_child(UI.label("제작 수량",12,UI.MUTED))
	amount=SpinBox.new()
	amount.name="CraftQuantity"
	amount.min_value=1
	amount.max_value=20
	amount.step=1
	amount.value=1
	amount.custom_minimum_size=Vector2(84,40)
	amount.value_changed.connect(func(_value: float) -> void:_refresh_quote())
	quantity.add_child(amount)
	information.add_child(UI.label("재료 · 사용 가능 / 필요",13,UI.GOLD))
	material_grid=GridContainer.new()
	material_grid.columns=2
	material_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	information.add_child(material_grid)
	hud.workspace.register_scroll_drag(material_scroll,material_grid)
	price=HBoxContainer.new()
	inspector.add_child(price)
	price.add_child(UI.label("제작 비용",13,UI.MUTED))
	cost=UI.label("",15,UI.GOLD)
	cost.name="CraftCost"
	cost.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	price.add_child(cost)
	wallet=UI.label("",12,UI.MUTED)
	wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	information.add_child(wallet)
	detail=UI.rich("")
	detail.name="CraftAvailability"
	detail.add_theme_font_size_override("normal_font_size",12)
	information.add_child(detail)
	hud.workspace.register_scroll_drag(material_scroll,detail)
	action=UI.button("제작",_craft,Vector2(0,48))
	Surfaces.action(action)
	action.name="CraftExecute"
	inspector.add_child(action)
	layout.configure(listing,inspector,460)
	layout.resized.connect(_reflow)
	_reflow()
	var data: Object = world.get("crafting")
	var registry: Dictionary = data.get("recipes")
	for raw_id: Variant in registry.keys():
		var id: String = str(raw_id)
		var recipe: Dictionary = registry[id]
		all_recipe_ids.append(id)
	_rebuild_listing()

func _reflow() -> void:
	# Reuse the existing compact list/detail navigation in the filter row so
	# short windows retain a usable inspector and the pinned transaction button.
	var compact: bool=layout.size.x<660
	if compact and layout.tabs.get_parent()!=filters:layout.tabs.reparent(filters)
	elif not compact and layout.tabs.get_parent()!=layout:
		layout.tabs.reparent(layout)
		layout.move_child(layout.tabs,0)
	for index: int in range(2):
		var tab: Button=layout.tabs.get_child(index)
		tab.custom_minimum_size=Vector2(64 if compact else 104,40 if compact else 34)
		if index==1:tab.text="상세" if compact else "선택 상세"
	compact_short=compact and size.y<300
	product_title.visible=not compact_short
	product.custom_minimum_size=Vector2(48,48) if compact_short else Vector2(64,64)
	price.visible=not compact_short
	_update_action_label()

func _update_action_label() -> void:
	if current_id.is_empty():return
	action.text="제작 실행 · %d개" % int(amount.value)
	if compact_short:action.text+="  ·  "+cost.text

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
		listing.set_item_metadata(listing.item_count-1,id)
		listing.set_item_custom_fg_color(listing.item_count-1,UI.grade(grade))
		listing.set_item_tooltip(listing.item_count-1,str(recipe.get("name",id)))
	if recipe_ids.is_empty():
		current_id = ""
		product.texture=null
		UI.clear_item_visual(product)
		product_name.text="선택한 제작법 없음"
		product_grade.text=""
		_clear_materials()
		cost.text="—"
		wallet.text=""
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
	var result: Dictionary=recipe.get("result",{})
	var output_name: String=str(result.get("item",""))
	var items: Dictionary=world._craft_item_index()
	var output: Dictionary=items.get(output_name,{})
	if material_recipe!=current_id:
		_build_materials(recipe,items)
		UI.apply_item_visual(product,output,output_name,hud.item_image_index.get("아이템",{}),"detail")
	product_name.text=output_name+" ×"+str(int(result.get("quantity",0))*count)
	product_name.add_theme_color_override("font_color",UI.grade(str(output.get("grade","일반"))))
	product_grade.text=str(output.get("grade","일반"))+" · "+str(recipe.get("category",""))
	for row: Dictionary in material_rows:
		var available: int=_available_material(str(row.item),items)
		var required: int=int(row.unit)*count
		(row.count as Label).text=UI.number_text(available)+" / "+UI.number_text(required)
		(row.count as Label).add_theme_color_override("font_color",UI.grade("고급") if available>=required else Color("ec8075"))
		(row.panel as Control).tooltip_text=str(row.item)+" · 전체 보유 "+str(int((world.inventory as Dictionary).get(row.item,0)))+"\n장착·강화·속성·축복·개별 옵션 장비는 제외됩니다."
	cost.text=UI.number_text(int(recipe.get("adena",0))*count)+" 아데나"
	wallet.text="보유 아데나  "+UI.number_text(int(world.gold))
	detail.text="[color=#79bf83]제작 가능[/color]" if bool(quote.get("ok",false)) else "[color=#ec8075]"+UI.safe(quote.get("reason","제작 불가"))+"[/color]"
	action.disabled = not bool(quote.get("ok",false))
	_update_action_label()

func _clear_materials() -> void:
	material_rows.clear()
	material_recipe=""
	for child: Node in material_grid.get_children():child.free()

func _build_materials(recipe: Dictionary,items: Dictionary) -> void:
	_clear_materials()
	material_recipe=current_id
	material_scroll.scroll_vertical=0
	for raw: Variant in recipe.get("materials",[]):
		if not raw is Dictionary:continue
		var material: Dictionary=raw
		var item_name: String=str(material.get("item",""))
		var record: Dictionary=items.get(item_name,{})
		var panel:=PanelContainer.new()
		panel.custom_minimum_size.y=54
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",Surfaces.inset(5))
		material_grid.add_child(panel)
		hud.workspace.register_scroll_drag(material_scroll,panel)
		var row:=HBoxContainer.new()
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var slot:=PanelContainer.new()
		slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("panel",UI.slot_recess())
		row.add_child(slot)
		var icon:=TextureRect.new()
		icon.custom_minimum_size=Vector2(36,36)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		UI.apply_item_visual(icon,record,item_name,hud.item_image_index.get("아이템",{}),"slot")
		var text:=VBoxContainer.new()
		text.mouse_filter=Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override("separation",2)
		text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var title: Label=UI.label(item_name,12,UI.grade(str(record.get("grade","일반"))))
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text.add_child(title)
		var counter: Label=UI.label("",13)
		text.add_child(counter)
		material_rows.append({"item":item_name,"unit":int(material.get("quantity",0)),"count":counter,"panel":panel})

func _available_material(item_name: String,items: Dictionary) -> int:
	var owned: int=int((world.inventory as Dictionary).get(item_name,0))
	if not CraftRules._is_equipment(items.get(item_name,{})):return owned
	# Use the transaction service's predicates, including blessing/custom records.
	# The quote above has already synchronized the physical inventory.
	var eligible: int=0
	for id: Variant in world.item_instances:
		var instance: Dictionary=world.item_instances[id]
		if str(instance.get("name",""))==item_name and not CraftRules._equipped(world.equipped_items,str(id)) and CraftRules._pristine(instance):eligible+=1
	return mini(owned,eligible)

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
