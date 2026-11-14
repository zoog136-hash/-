extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser=preload("res://scripts/ui/renewal_browser.gd")
const CraftRules=preload("res://scripts/crafting/expanded_crafting.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const SOURCE_IMAGES=preload("res://scripts/ui/source523_image_assets.gd")
var hud: Node
var world: Node
var listing: ItemList
var probability_summary: Label
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
var candidate_box: VBoxContainer
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
## A recipe the next crafting window opens on (the original 523 재료 아이템
## 출처 popup's craft list); consumed by configure().
static var pending_focus: String=""
static var last_focus: Dictionary={}

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
	var source_info: Button = UI.button("원본 강화 정보", func() -> void: hud.open_patch523_equipment_info())
	source_info.name = "Patch523EquipmentInfoButton"
	filters.add_child(source_info)
	category_filter = OptionButton.new()
	category_filter.name = "CraftCategoryFilter"
	category_filter.custom_minimum_size.y=40
	for title: String in ["전체", "물약", "무기", "방어구", "장신구", "재료"]:
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
	candidate_box=VBoxContainer.new()
	candidate_box.name="Patch523MaterialCandidates"
	information.add_child(candidate_box)
	material_grid=GridContainer.new()
	material_grid.columns=2
	material_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	information.add_child(material_grid)
	hud.workspace.register_scroll_drag(material_scroll,material_grid)
	probability_summary=UI.label("",12,UI.GOLD)
	probability_summary.name="Patch523CraftOdds"
	probability_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	probability_summary.hide()
	inspector.add_child(probability_summary)
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
	if not pending_focus.is_empty():
		var target: String=pending_focus
		pending_focus=""
		last_focus={"recipe_id":target,"focused":focus_recipe(target)}

## Shows every recipe and selects `recipe_id` when the game has it.
func focus_recipe(recipe_id: String) -> bool:
	if not all_recipe_ids.has(recipe_id):return false
	category_filter.select(0)
	grade_filter.select(0)
	name_filter.text=""
	_rebuild_listing()
	var index: int=recipe_ids.find(recipe_id)
	if index<0:return false
	listing.select(index)
	listing.ensure_current_is_visible()
	_select(index)
	return current_id==recipe_id

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
	var source_images: Dictionary = {}
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
		var item_class_id: int = _recipe_item_class_id(recipe,output,id)
		var source_recipe_image: bool = _uses_source_recipe_images(recipe,id)
		var original: Dictionary = SOURCE_IMAGES.describe_item_class(item_class_id,output_name) if item_class_id>0 else {}
		listing.add_item("[%s] %s" % [grade,str(recipe.get("name",id))],original.get("texture") as Texture2D if source_recipe_image else UI.item_icon(item_records.get(output_name,{}),output_name,hud.item_image_index.get("아이템",{})))
		if source_recipe_image:
			var evidence: Dictionary=original.duplicate(true)
			evidence.erase("texture")
			if item_class_id==0: evidence={"source_status":"zero_sentinel","actual_game_consumption_observed":false}
			elif item_class_id<0: evidence={"source_status":"source_item_identity_required","actual_game_consumption_observed":false}
			source_images[id]=evidence
		listing.set_item_metadata(listing.item_count-1,id)
		listing.set_item_custom_fg_color(listing.item_count-1,UI.grade(grade))
		listing.set_item_tooltip(listing.item_count-1,str(recipe.get("name",id)))
	listing.set_meta("source523_images",source_images)
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
	amount.max_value=1 if world.crafting.recipes.get(current_id,{}).has("outcomes") else 20
	_refresh_quote()

func _refresh_quote() -> void:
	if current_id.is_empty():
		return
	var service: Object = world.get("crafting")
	var recipe: Dictionary = (service.get("recipes") as Dictionary).get(current_id,{})
	if current_id.begins_with("patch523:"):
		var selection: Dictionary = world.patch523_equipment.material_selection(current_id, world.patch523_material_choices.get(current_id, {}))
		if selection.get("recipe") is Dictionary: recipe = selection.recipe
	var count: int = int(amount.value)
	var quote: Dictionary = world.call("_craft_quote",current_id,count)
	var result: Dictionary=recipe.get("result",{})
	var output_name: String=str(result.get("item",""))
	var items: Dictionary=world._patch523_craft_item_index() if current_id.begins_with("patch523:") else world._craft_item_index()
	var output: Dictionary=items.get(output_name,{})
	if material_recipe!=current_id:
		var source_images: Dictionary=_source_recipe_image_references()
		_build_materials(recipe,items,source_images)
		var source_output: Variant=source_images.get(str(result.get("source_id","")))
		if source_output is Dictionary and not source_output.is_empty():
			UI.apply_source_item_reference(product,source_output,output_name,"detail")
		elif _recipe_item_class_id(recipe,result,current_id)>0:
			UI.apply_item_class_icon(product,_recipe_item_class_id(recipe,result,current_id),output_name,"detail")
		elif _uses_source_recipe_images(recipe,current_id):
			UI.clear_item_visual(product)
			product.texture=null
		else:
			UI.apply_item_visual(product,output,output_name,hud.item_image_index.get("아이템",{}),"detail")
	var source_recipe: bool = recipe.get("source_snapshot", "") == "patch523"
	probability_summary.visible=recipe.has("outcomes") or recipe.has("craft_conditions")
	var chances: PackedStringArray=[]
	for outcome: Dictionary in recipe.get("outcomes",[]):
		var label: String=str(outcome.label)
		if int(recipe.get("source_success_view_count",1))>1:label="지급 없음" if outcome.get("empty_result",false) else "%s ×%d" % [str(outcome.item),int(outcome.quantity)]
		chances.append("%s %.2f%%" % [label,float(outcome.probability)/10000.0])
	probability_summary.text=("원본 결과 확률 · " + " / ".join(chances)) if recipe.has("outcomes") else ""
	if recipe.has("craft_conditions"):
		probability_summary.text+=world.patch523_equipment.CONDITIONS.brief(recipe,world._patch523_craft_context())
	probability_summary.tooltip_text=world.patch523_craft_condition_summary(recipe) if source_recipe else ""
	if not recipe.get("host_material_bindings",[]).is_empty(): probability_summary.text+=" · 게임 재료 연결 적용"

	var state_label: String = (" +%d · %s" % [int(result.get("level", 0)), "축복" if int(result.get("bless_code", 1)) == 2 else "일반"]) if source_recipe and not bool(result.get("wallet_currency",false)) else ""
	product_name.text=output_name+state_label+" ×"+str(int(result.get("quantity",0))*count)
	product_name.add_theme_color_override("font_color",UI.grade(str(output.get("grade","일반"))))
	product_grade.text=str(output.get("grade","일반"))+" · "+str(recipe.get("category",""))
	for row: Dictionary in material_rows:
		var available: int=_available_material(str(row.item),items)
		if source_recipe:
			available = world.patch523_equipment.available_material(row.source_material, world.inventory, items, world.item_instances, world.equipped_items, world.ui_preferences.get("item_locks", {}), int(recipe.get("popup_text_id", 0)) != 0, int(world.gold),world._patch523_craft_context())
		var required: int=int(row.unit)*count
		(row.count as Label).text=UI.number_text(available)+" / "+UI.number_text(required)
		(row.count as Label).add_theme_color_override("font_color",UI.grade("고급") if available>=required else Color("ec8075"))
		var owned_key: String=world.patch523_equipment.ownership_key(row.source_material) if source_recipe else str(row.item)
		(row.panel as Control).tooltip_text=str(row.item)+" · 전체 보유 "+str(int((world.inventory as Dictionary).get(owned_key,0)))+("\n표시된 원본 ID·강화·축복 조건과 일치하는 미장착·잠금 해제 재료만 사용합니다." if source_recipe else "\n장착·강화·속성·축복·개별 옵션 장비는 제외됩니다.")
	if source_recipe and quote.get("ok",false):
		for debit: Dictionary in quote.get("material_rows",[]):
			for row: Dictionary in material_rows:
				if str(row.source_material.source_id)==str(debit.source_id):(row.panel as Control).tooltip_text+="\n실제 소비: %s ×%d" % [str(debit.key),int(debit.quantity)]
	cost.text=UI.number_text(world.patch523_equipment.recipe_cost(recipe,count) if source_recipe else int(recipe.get("adena",0))*count)+" 아데나"
	wallet.text="보유 아데나  "+UI.number_text(int(world.gold))
	detail.text="[color=#79bf83]제작 가능[/color]" if bool(quote.get("ok",false)) else "[color=#ec8075]"+UI.safe(quote.get("reason","제작 불가"))+"[/color]"
	if bool(result.get("wallet_currency",false)):
		detail.text += "\n제작 결과 아데나는 지갑에 지급합니다."
	if result.has("inventory_key"): detail.text+="\n원본 코인 수량을 보유 재화 [%s]에 그대로 적립합니다." % UI.safe(str(result.inventory_key))
	var source_use: String = world.PATCH523_ITEM_USE.summary(world.patch523_equipment.record(str(result.get("source_id","")))) if source_recipe else ""
	if not source_use.is_empty(): detail.text += "\n" + UI.safe(source_use)
	if source_recipe:
		var condition_text: String=world.patch523_craft_condition_summary(recipe)
		if not condition_text.is_empty(): detail.text+="\n"+UI.safe(condition_text)
		detail.text += "\n원본523 %s · 표시된 강화·축복 상태의 재료만 사용합니다." % ("확률 제작" if recipe.has("outcomes") else "확정 제작")
		for binding: Dictionary in recipe.get("host_material_bindings",[]):
			detail.text += "\n" + UI.safe(str(binding.binding_origin))
		if recipe.has("outcomes") and bool(recipe.get("preserve_refund_instance",false)):
			detail.text += "\n게임 설정: 같은 장비의 실패 반환은 물리 ID와 기록을 보존합니다."
		for outcome: Dictionary in recipe.get("outcomes",[]):
			detail.text += ("\n%s %.4f%% · 지급 없음" % [UI.safe(str(outcome.label)),float(outcome.probability)/10000.0]) if outcome.get("empty_result",false) else ("\n%s %.4f%% · %s +%d ×%d" % [UI.safe(str(outcome.label)),float(outcome.probability)/10000.0,UI.safe(str(outcome.item)),int(outcome.level),int(outcome.quantity)])
		if recipe.has("probability_origin"):detail.text+="\n"+UI.safe(str(recipe.probability_origin))
		if recipe.has("missing_failure_policy"):
			var failure: Dictionary=recipe.missing_failure_policy
			detail.text+="\nTWILIGHT 누락 실패 정책 · 재료 %s / 비용 %s" % ["소모" if failure.consume_materials_on_failure else "보존","소모" if failure.consume_fee_on_failure else "보존"]
		if str(result.get("source_id", "")) in ["30671", "130551"] and int(result.get("bless_code", 1)) == 2:
			detail.text += "\n축복 인장의 해당 단계 명중·대미지·리덕션·물약·경험치·아인하사드·스턴 내성·쿨타임 효과를 적용합니다."
		for material: Dictionary in recipe.get("materials", []):
			if material.has("inventory_key"): detail.text+="\n보유 재화 [%s]에서 원본 수량을 사용합니다." % UI.safe(str(material.inventory_key))
			if bool(material.get("physical", false)):
				detail.text += "\n%s +%d · %s" % [UI.safe(material.item), int(material.level), "축복" if int(material.bless_code) == 2 else "일반"]
		if int(recipe.get("popup_text_id", 0)) != 0:
			detail.text += "\n[color=#ec8075]재료 장비의 속성 제련 효과는 결과물에 계승되지 않습니다.[/color]"
	action.disabled = not bool(quote.get("ok",false))
	_update_action_label()

func _clear_materials() -> void:
	material_rows.clear()
	material_recipe=""
	for child: Node in material_grid.get_children():child.free()
	for child: Node in candidate_box.get_children():
		candidate_box.remove_child(child)
		child.queue_free()

func _uses_source_recipe_images(recipe: Dictionary, recipe_id: String) -> bool:
	return SOURCE_IMAGES.selected() and recipe.get("source_snapshot")=="patch523" and recipe_id.begins_with("patch523:")

func _recipe_item_class_id(recipe: Dictionary, source_item: Dictionary, recipe_id: String) -> int:
	if not _uses_source_recipe_images(recipe,recipe_id):
		return -1
	# The existing compiled ItemCraft input/output contract declares source_id
	# in the ItemClass namespace. No name, generic ClassID or ownership is joined.
	var literal: Variant=source_item.get("source_id")
	if not literal is String or not literal.is_valid_int(): return -1
	var item_class_id: int=int(literal)
	if str(item_class_id)!=literal or item_class_id<0: return -1
	return item_class_id

func _source_recipe_image_references() -> Dictionary:
	if not SOURCE_IMAGES.selected() or not current_id.begins_with("patch523:"):
		return {}
	var source_id: String=current_id.trim_prefix("patch523:")
	if not source_id.is_valid_int() or str(int(source_id))!=source_id or int(source_id)<=0:
		return {}
	var rules: Object=world.patch523_equipment
	if rules==null or not rules.has_method("recipe_definition"):
		return {}
	# Read the published data contract for this already selected recipe only.
	# Its can_execute:false never changes the existing quote/execute admission.
	var definition: Variant=rules.call("recipe_definition",int(source_id))
	if not definition is Dictionary or definition.get("kind")!="current523_craft_definition" or definition.get("craft_id")!=int(source_id) or definition.get("reference_only")!=true or definition.get("can_execute")!=false:
		return {}
	var references: Variant=definition.get("items")
	return references if references is Dictionary else {}

func _build_materials(recipe: Dictionary,items: Dictionary,source_images: Dictionary={}) -> void:
	_clear_materials()
	material_recipe=current_id
	material_scroll.scroll_vertical=0
	for source_slot: Dictionary in recipe.get("material_slots", []):
		var candidates: Array = source_slot.candidates
		if candidates.size() < 2: continue
		var slot_key: String = str(int(source_slot.slot_index))
		candidate_box.add_child(UI.label("재료 슬롯 %s · 후보 1종을 선택" % slot_key, 12, UI.GOLD))
		var chooser := OptionButton.new()
		chooser.name = "Patch523Candidate_" + slot_key
		chooser.custom_minimum_size.y = 40
		chooser.expand_icon = true
		chooser.add_item("재료 후보 선택…")
		var candidate_images: Dictionary = {}
		for material: Dictionary in candidates:
			chooser.add_item("아데나 ×%d · 지갑" % int(material.quantity) if bool(material.get("wallet",false)) else "%s +%d · %s ×%d" % [str(material.item),int(material.level),"축복" if int(material.bless_code)==2 else "일반",int(material.quantity)])
			if _uses_source_recipe_images(recipe,current_id):
				# This option is one original ItemCraft input candidate, with the
				# same declared ItemClass source_id used by the material picture.
				# The row_id below remains the independent transaction identity.
				var item_class_id: int = _recipe_item_class_id(recipe,material,current_id)
				var reference: Variant = source_images.get(str(material.get("source_id","")))
				var original: Dictionary = SOURCE_IMAGES.describe_item_reference(reference,str(material.item)) if reference is Dictionary and not reference.is_empty() else SOURCE_IMAGES.describe_item_class(item_class_id,str(material.item))
				if original.get("item_class_id") != item_class_id:
					original = SOURCE_IMAGES.describe_item_class(-1,str(material.item))
					original["reason"] = "source_material_candidate_identity_mismatch"
					original["source_status"] = "source_material_candidate_identity_mismatch"
				chooser.set_item_icon(chooser.item_count-1,original.get("texture") as Texture2D)
				var evidence: Dictionary = original.duplicate(true)
				evidence.erase("texture")
				evidence["source_material_row_id"] = material.row_id
				candidate_images[chooser.item_count-1] = evidence
			if int(world.patch523_material_choices.get(current_id, {}).get(slot_key, -1)) == int(material.row_id): chooser.select(chooser.item_count-1)
		chooser.set_meta("source523_item_images",candidate_images)
		chooser.item_selected.connect(func(index: int) -> void:
			var chosen: Dictionary = world.patch523_material_choices.get(current_id, {}).duplicate(true)
			if index == 0: chosen.erase(slot_key)
			else: chosen[slot_key] = int(candidates[index-1].row_id)
			world.patch523_material_choices[current_id] = chosen
			material_recipe = ""
			_refresh_quote())
		candidate_box.add_child(chooser)
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
		var source_item: Variant=source_images.get(str(material.get("source_id","")))
		if source_item is Dictionary and not source_item.is_empty():
			UI.apply_source_item_reference(icon,source_item,item_name,"slot")
		elif _recipe_item_class_id(recipe,material,current_id)>0:
			UI.apply_item_class_icon(icon,_recipe_item_class_id(recipe,material,current_id),item_name,"slot")
		elif _uses_source_recipe_images(recipe,current_id):
			UI.clear_item_visual(icon)
			icon.texture=null
		else:
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
		material_rows.append({"item":item_name,"unit":int(material.get("quantity",0)),"count":counter,"panel":panel,"source_material":material.duplicate(true)})

func _available_material(item_name: String,items: Dictionary) -> int:
	# Use the transaction service's predicates, including blessing/custom records.
	# The quote above has already synchronized the physical inventory.
	return available_material_of(world,item_name,items)

func _craft() -> void:
	if current_id.is_empty():
		return
	confirm_craft(hud,world,current_id,int(amount.value))

## The existing 제작 확인 (shared with the original Production window): the
## world's quote must admit `count`, then 제작 emits craft_requested.
static func confirm_craft(controller: Node, game: Node, id: String, count: int) -> bool:
	if not controller.has_signal("craft_requested"): return false
	var report: Dictionary = game._craft_quote(id,count)
	if not bool(report.get("ok",false)): return false
	var recipe: Dictionary = game.crafting.recipes.get(id, {})
	var warning: String = "\n재료 장비의 속성 제련 효과는 계승되지 않습니다." if int(recipe.get("popup_text_id", 0)) != 0 else ""
	if id.begins_with("patch523:"): warning += "\n아데나 소모: %s" % UI.number_text(int(report.cost))
	if recipe.has("craft_conditions"): warning+="\n"+game.patch523_craft_condition_summary(recipe)
	if recipe.get("result",{}).has("inventory_key"): warning+="\n원본 결과를 보유 재화 [%s]에 적립합니다." % str(recipe.result.inventory_key)
	for outcome: Dictionary in recipe.get("outcomes",[]):
		warning += ("\n%s %.4f%% → 지급 없음" % [str(outcome.label),float(outcome.probability)/10000.0]) if outcome.get("empty_result",false) else ("\n%s %.4f%% → %s +%d ×%d" % [str(outcome.label),float(outcome.probability)/10000.0,str(outcome.item),int(outcome.level),int(outcome.quantity)])
	if not recipe.get("host_material_bindings",[]).is_empty(): warning += "\n게임 설정: 원본549 재료를 기존 드래곤 다이아몬드 스택에 연결합니다."
	if recipe.has("outcomes"): warning += "\n결과는 저장 후 확정됩니다."
	if recipe.has("missing_failure_policy"):
		var failure: Dictionary=recipe.missing_failure_policy
		warning+="\n누락 실패는 TWILIGHT 설정: 지급 없음 · 재료 %s / 비용 %s" % ["소모" if failure.consume_materials_on_failure else "보존","소모" if failure.consume_fee_on_failure else "보존"]
	controller.confirm_action("제작 확인","선택한 제작식 ×%d\n표시된 재료와 아데나를 소모합니다.%s" % [count,warning],"제작",func(_amount: int) -> void:
		controller.emit_signal("craft_requested",id,count))
	return true

## The recipe as the quote reads it (a patch523 recipe with its chosen
## material candidates).
static func recipe_of(game: Node, id: String) -> Dictionary:
	var recipe: Dictionary = (game.crafting.recipes as Dictionary).get(id,{})
	if id.begins_with("patch523:"):
		var selection: Dictionary = game.patch523_equipment.material_selection(id, game.patch523_material_choices.get(id, {}))
		if selection.get("recipe") is Dictionary: recipe = selection.recipe
	return recipe

## Owned / required of each material row, as the forge's material panel shows.
static func material_status(game: Node, id: String, count: int) -> Array:
	var recipe: Dictionary = recipe_of(game,id)
	var source_recipe: bool = recipe.get("source_snapshot", "") == "patch523"
	var items: Dictionary = game._patch523_craft_item_index() if id.begins_with("patch523:") else game._craft_item_index()
	var rows: Array = []
	for raw: Variant in recipe.get("materials",[]):
		if not raw is Dictionary: continue
		var material: Dictionary = raw
		var item_name: String = str(material.get("item",""))
		var available: int
		if source_recipe:
			available = game.patch523_equipment.available_material(material, game.inventory, items, game.item_instances, game.equipped_items, game.ui_preferences.get("item_locks", {}), int(recipe.get("popup_text_id", 0)) != 0, int(game.gold),game._patch523_craft_context())
		else:
			available = available_material_of(game,item_name,items)
		rows.append({"item":item_name,"available":available,"required":int(material.get("quantity",0))*count,"record":items.get(item_name,{}),"source_id":str(material.get("source_id","")),"material":material.duplicate(true)})
	return rows

static func available_material_of(game: Node, item_name: String, items: Dictionary) -> int:
	var owned: int=int((game.inventory as Dictionary).get(item_name,0))
	if not CraftRules._is_equipment(items.get(item_name,{})):return owned
	var eligible: int=0
	for id: Variant in game.item_instances:
		var instance: Dictionary=game.item_instances[id]
		if str(instance.get("name",""))==item_name and not CraftRules._equipped(game.equipped_items,str(id)) and CraftRules._pristine(instance):eligible+=1
	return mini(owned,eligible)
