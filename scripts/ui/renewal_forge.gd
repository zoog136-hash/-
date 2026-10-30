extends VBoxContainer

# Enhancement probabilities and transactions are supplied by the world.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const ReferenceSurfaces=preload("res://scripts/ui/reference_surfaces.gd")

var hud: Node
var mode: String = "scroll"
var scroll_name: String = ""
var values: Array = []
var listing: ItemList
var detail: RichTextLabel
var action: Button
var selected_index: int = -1
var preview: TextureRect

var scroll_icon: TextureRect
var selected_name: Label
var selected_state: Label
var scroll_caption: Label
var wallet: Label
var browser: Control
var inventory_tab: Button
var scroll_tab: Button
var selection_built: bool=false
var info_scroll: ScrollContainer
var stage: PanelContainer

func configure_scrolls(controller: Node) -> void:
	hud = controller
	mode = "scroll"
	scroll_name = ""
	values.clear()
	for name: String in hud.lineage_inventory_ui.inventory:
		if int(hud.lineage_inventory_ui.inventory[name]) <= 0: continue
		if not name.contains("주문서"): continue
		if not (name.contains("무기") or name.contains("갑옷") or name.contains("장신구") or name.contains("축복 부여")): continue
		values.append({"name":name,"count":int(hud.lineage_inventory_ui.inventory[name])})
	values.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	_build()

func configure_targets(controller: Node, scroll: String, candidates: Array) -> void:
	hud = controller
	mode = "target"
	scroll_name = scroll
	values = candidates.duplicate(true)
	_build()

func configure_blessing(controller: Node, scroll: String, candidates: Array) -> void:
	hud = controller
	mode = "blessing"
	scroll_name = scroll
	values = candidates.duplicate(true)
	_build()

func _build() -> void:
	# Inspected single-enhancement layout: selected scroll/target on the left,
	# equipment/scroll inventory on the right. No batch/fee rules are invented.
	# https://lineagem-jp.com/guides/lm/guides/item_enchant
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(UI.label("강화 주문서를 선택하세요." if mode=="scroll" else "축복할 장비를 선택하세요." if mode=="blessing" else "강화할 아이템을 선택하세요.",15,UI.TEXT))
	browser=Browser.new()
	browser.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(browser)
	var inventory:=VBoxContainer.new()
	inventory.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inventory.size_flags_vertical=Control.SIZE_EXPAND_FILL
	browser.add_child(inventory)
	var tabs:=HBoxContainer.new()
	inventory.add_child(tabs)
	var tab_group:=ButtonGroup.new()
	inventory_tab=UI.button("장비",func() -> void:
		if mode=="scroll":_execute(),Vector2(90,34))
	inventory_tab.name="ForgeEquipmentTab"
	inventory_tab.disabled=mode=="scroll" and values.is_empty()
	inventory_tab.toggle_mode=true
	inventory_tab.button_group=tab_group
	inventory_tab.button_pressed=mode in ["target","blessing"]
	tabs.add_child(inventory_tab)
	scroll_tab=UI.button("주문서",func() -> void:
		if mode in ["target","blessing"]:hud._open_enhance_chooser(),Vector2(90,34))
	scroll_tab.name="ForgeScrollTab"
	scroll_tab.toggle_mode=true
	scroll_tab.button_group=tab_group
	scroll_tab.button_pressed=mode=="scroll"
	tabs.add_child(scroll_tab)
	listing=ItemList.new()
	listing.set_script(preload("res://scripts/ui/native_touch_list.gd"))
	listing.name="EnhancementChoices"
	listing.icon_mode=ItemList.ICON_MODE_TOP
	listing.fixed_icon_size=Vector2i(54,54)
	listing.max_columns=4
	listing.fixed_column_width=76
	listing.same_column_width=true
	listing.max_text_lines=2
	listing.add_theme_font_size_override("font_size",12)
	listing.add_theme_constant_override("h_separation",8)
	listing.add_theme_constant_override("v_separation",10)
	listing.add_theme_stylebox_override("panel",UI.MATERIAL.from_flat(UI.box(Color("0c0c0e"),Color("534b3c"),5),true))
	listing.size_flags_vertical=Control.SIZE_EXPAND_FILL
	listing.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	inventory.add_child(listing)
	var footer:=HBoxContainer.new()
	inventory.add_child(footer)
	wallet=UI.label("아데나  "+UI.number_text(int(hud.character_state.get("gold",0))),12,UI.MUTED)
	wallet.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(wallet)
	footer.add_child(UI.label(str(values.size())+("개 장비" if mode in ["target","blessing"] else "종 주문서"),12,UI.MUTED))
	var side:=VBoxContainer.new()
	side.custom_minimum_size.x=320
	browser.add_child(side)
	info_scroll=ScrollContainer.new()
	info_scroll.name="ForgeInfoScroll"
	info_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	side.add_child(info_scroll)
	var information:=VBoxContainer.new()
	information.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info_scroll.add_child(information)
	hud.workspace.register_scroll_drag(info_scroll,information)
	stage=PanelContainer.new()
	stage.custom_minimum_size.y=150
	stage.add_theme_stylebox_override("panel",UI.MATERIAL.from_flat(UI.box(Color("291a16"),Color("6c5946"),10),true))
	information.add_child(stage)
	hud.workspace.register_scroll_drag(info_scroll,stage)
	var scene:=VBoxContainer.new()
	stage.add_child(scene)
	var pair:=HBoxContainer.new()
	pair.alignment=BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation",24)
	scene.add_child(pair)
	var scroll_slot:=VBoxContainer.new()
	pair.add_child(scroll_slot)
	scroll_icon=_slot(scroll_slot,"사용 주문서",Vector2(72,72))
	pair.add_child(UI.label("+",26,UI.TEXT))
	var target_slot:=VBoxContainer.new()
	pair.add_child(target_slot)
	preview=_slot(target_slot,"부여 대상" if mode=="blessing" else "강화 대상",Vector2(84,84))
	scroll_caption=UI.label("",12,UI.MUTED)
	scroll_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	scroll_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	scene.add_child(scroll_caption)
	selected_name=UI.label("",17,UI.GOLD)
	selected_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	information.add_child(selected_name)
	selected_state=UI.label("",12,UI.MUTED)
	selected_state.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	information.add_child(selected_state)
	detail=UI.rich("")
	detail.fit_content=true
	detail.scroll_active=false
	detail.add_theme_font_size_override("normal_font_size",13)
	information.add_child(detail)
	hud.workspace.register_scroll_drag(info_scroll,detail)
	action=UI.button("선택",_execute,Vector2(0,54))
	action.name="EnhanceAction"
	ReferenceSurfaces.action(action)
	side.add_child(action)
	if mode in ["target","blessing"]:side.add_child(UI.button("다른 주문서 선택",func() -> void:hud._open_enhance_chooser()))
	for entry: Dictionary in values:
		var reference: String=str(entry.get("target_id",entry.get("name","")))
		var info: Dictionary=hud.lineage_inventory_ui._find_item_record(reference)
		listing.add_item(("%s  ×%d" % [entry.get("name",""),int(entry.get("count",0))]) if mode=="scroll" else ("%s  +%d%s" % [entry.get("name",""),int(entry.get("level",0)),"  [장착]" if bool(entry.get("equipped",false)) else ""]),UI.item_icon(info,str(entry.get("name","")),hud.item_image_index.get("아이템",{})))
		listing.set_item_metadata(listing.item_count-1,reference)
		listing.set_item_custom_fg_color(listing.item_count-1,UI.grade(str(info.get("grade","일반"))))
		listing.set_item_custom_bg_color(listing.item_count-1,Color(UI.grade(str(info.get("grade","일반"))),.08))
		listing.set_item_tooltip(listing.item_count-1,str(entry.get("name",""))+" · 장비 ID "+str(entry.get("instance_id","")))
	browser.configure(inventory,side,380)
	browser.panes.move_child(browser.detail_frame,0)
	browser.move_child(browser.tabs,browser.get_child_count()-1)
	(browser.tabs.get_child(0) as Button).text="보유 목록"
	(browser.tabs.get_child(1) as Button).text="강화 정보"
	if values.is_empty():
		selected_name.text="선택 가능한 아이템 없음"
		detail.text="보유 강화 주문서가 없습니다. 상점에서 구매하세요." if mode=="scroll" else "이 주문서로 강화 가능한 장비가 없습니다."
		action.disabled=true
		if mode in ["target","blessing"]:
			UI.apply_item_visual(scroll_icon,hud.lineage_inventory_ui._find_item_record(scroll_name),scroll_name,hud.item_image_index.get("아이템",{}),"detail")
			scroll_caption.text=scroll_name
	else:
		listing.select(0)
		_select(0)
	selection_built=true
	resized.connect(_reflow_stage)
	_reflow_stage()

func _select(index: int) -> void:
	if index<0 or index>=values.size():return
	selected_index=index
	var entry: Dictionary=values[index]
	var reference: String=str(entry.get("target_id",entry.get("name","")))
	if mode=="scroll":
		UI.apply_item_visual(scroll_icon,hud.lineage_inventory_ui._find_item_record(reference),str(entry.get("name","")),hud.item_image_index.get("아이템",{}),"detail")
		UI.clear_item_visual(preview);preview.texture=null
		selected_name.text=str(entry.get("name",""))
		selected_state.text="보유 "+UI.number_text(int(entry.get("count",0)))+"장"
		scroll_caption.text="주문서를 선택한 뒤 강화 대상을 고르세요."
		detail.text="장비 목록에서 강화 대상을 선택하세요. 대상의 현재 강화 수치와 확률을 확인한 뒤 진행합니다."
		action.text="장비 선택하기"
	else:
		UI.apply_item_visual(preview,hud.lineage_inventory_ui._find_item_record(reference),str(entry.get("name","")),hud.item_image_index.get("아이템",{}),"detail")
		UI.apply_item_visual(scroll_icon,hud.lineage_inventory_ui._find_item_record(scroll_name),scroll_name,hud.item_image_index.get("아이템",{}),"detail")
		selected_name.text=str(entry.get("name",""))+"  +"+str(int(entry.get("level",0)))
		selected_state.text=("장착 중" if bool(entry.get("equipped",false)) else "인벤토리 보관")+" · 안전 강화 +"+str(int(entry.get("safe_level",0)))
		selected_state.tooltip_text="장비 ID "+str(entry.get("instance_id",""))
		scroll_caption.text=scroll_name+" · 보유 "+UI.number_text(int(hud.lineage_inventory_ui.inventory.get(scroll_name,0)))+"장"
		var content: String="[table=2]"
		for row: Array in [["성공",float(entry.get("success_chance",0.0))],["유지",float(entry.get("no_change_chance",0.0))],["하락",float(entry.get("decrease_chance",0.0))],["소실",float(entry.get("destroy_chance",0.0))]]:
			content+="[cell expand=1]%s[/cell][cell expand=1][right]%.1f%%[/right][/cell]" % [row[0],row[1]]
		content+="[/table]\n성공 강화폭  %s\n%s\n\n강화 시 주문서 1장 소모" % [UI.safe(entry.get("gain_text","+1")),UI.safe(entry.get("bonus_text","능력치 상승"))]
		detail.text=content
		action.text="강화 시작 · 주문서 1장"
	if mode=="blessing":
		selected_state.text=("장착 중" if bool(entry.get("equipped",false)) else "인벤토리 보관")+" · 축복 부여"
		detail.text="축복 성공률: %.1f%% (TWILIGHT 임시값)\n축복 옵션: %s\n\n성공/실패 모두 주문서 1장 소모 · 장비 유지" % [float(entry.get("success_chance",0.0)),UI.safe(entry.get("bonus_text",""))]
		action.text="축복 부여 · 주문서 1장"
	action.disabled=false
	if selection_built and browser.size.x<660:
		browser.detail_active=true
		browser.reflow()

func _execute() -> void:
	if selected_index < 0 or selected_index >= values.size(): return
	var entry: Dictionary = values[selected_index]
	if mode == "blessing":
		var target_reference: String = str(entry.get("target_id", ""))
		if not target_reference.is_empty():
			var blessing_scroll: String = scroll_name
			hud.confirm_action("축복 부여 확인", "%s +%d\n%s 1장 사용\n축복 성공률 %.1f%% · 실패해도 장비 유지" % [
				str(entry.get("name", "")), int(entry.get("level", 0)), blessing_scroll, float(entry.get("success_chance", 0))
			], "축복 부여", func(_count: int) -> void: hud.blessing_target_requested.emit(blessing_scroll, target_reference))
	elif mode == "scroll":
		var item := str(entry.get("name",""))
		if int(hud.lineage_inventory_ui.inventory.get(item,0)) > 0:
			hud.inventory_item_activated.emit(item)
	else:
		var target := str(entry.get("target_id", entry.get("name","")))
		if target != "":
			var scroll: String = scroll_name
			hud.confirm_action("강화 확인","%s +%d\n%s 1장 소모\n성공 %.1f%% · 하락 %.1f%% · 소실 %.1f%%" % [str(entry.get("name","")),int(entry.get("level",0)),scroll,float(entry.get("success_chance",0)),float(entry.get("decrease_chance",0)),float(entry.get("destroy_chance",0))],"강화",func(_count: int) -> void:
				hud.enhancement_requested.emit(scroll,target))
func _slot(parent: VBoxContainer, title: String, extent: Vector2) -> TextureRect:
	var caption: Label=UI.label(title,12,UI.MUTED)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(caption)
	var frame:=PanelContainer.new()
	frame.add_theme_stylebox_override("panel",UI.slot_recess())
	parent.add_child(frame)
	hud.workspace.register_scroll_drag(info_scroll,frame)
	var image:=TextureRect.new()
	image.custom_minimum_size=extent
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	return image

func _reflow_stage() -> void:
	var short: bool=size.y<400
	stage.custom_minimum_size.y=110 if short else 150
	scroll_icon.custom_minimum_size=Vector2(60,60) if short else Vector2(72,72)
	preview.custom_minimum_size=Vector2(60,60) if short else Vector2(84,84)
