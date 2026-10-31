extends RefCounted
# Four-column transfer slots inspected against LineageM's warehouse screen.
# https://lineagem-jp.com/guides/lm/guides/area_storage
# The existing NPC sale flow reuses the same item selection presentation.
# Single-item transactions, prices, capacity and physical IDs stay with the view/world.
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const NativeTouchButton=preload("res://scripts/ui/native_touch_button.gd")
var view: Node
var warehouse: bool=false
var picture: TextureRect
var title: Label
var count_label: Label
var tabs: Array[Button]=[]

func bind(owner_view: Node,is_warehouse: bool) -> void:
	view=owner_view;warehouse=is_warehouse
	var listing: ItemList=view.listing
	listing.icon_mode=ItemList.ICON_MODE_TOP
	listing.fixed_icon_size=Vector2i(54,54)
	listing.max_columns=4;listing.fixed_column_width=76;listing.same_column_width=true
	listing.max_text_lines=1
	listing.add_theme_font_size_override("font_size",11)
	listing.add_theme_constant_override("h_separation",5)
	listing.add_theme_constant_override("v_separation",7)
	listing.add_theme_stylebox_override("panel",Surfaces.inset(4))
	var amount_row: HBoxContainer=view.quantity.get_parent()
	var surface:=PanelContainer.new()
	surface.name="TransferSelection"
	surface.add_theme_stylebox_override("panel",Surfaces.inset(5))
	view.add_child(surface);view.move_child(surface,listing.get_index()+1)
	var row:=HBoxContainer.new();surface.add_child(row)
	picture=TextureRect.new();picture.name="TransferSelectionPicture"
	picture.custom_minimum_size=Vector2(36,36)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(picture)
	var words:=VBoxContainer.new();words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation",2);row.add_child(words)
	title=UI.label("",14);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;words.add_child(title)
	count_label=UI.label("",11,UI.MUTED);words.add_child(count_label)
	view.move_child(amount_row,surface.get_index()+1)
	var caption: Label=UI.label("수량",12,UI.MUTED)
	amount_row.add_child(caption);amount_row.move_child(caption,0)
	view.quantity.custom_minimum_size=Vector2(76,40)
	view.quantity.size_flags_horizontal=Control.SIZE_FILL
	view.action.reparent(amount_row)
	view.action.custom_minimum_size=Vector2(0,40)
	view.action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Surfaces.action(view.action)
	if warehouse:
		(view.get_child(0) as Control).hide()
		view.mode.hide()
		var modes:=HBoxContainer.new();modes.name="WarehouseDirectionTabs"
		view.add_child(modes);view.move_child(modes,1)
		# No ButtonGroup: a group ignores a tap on the tab it still thinks is
		# pressed, and plain buttons inside the scrolling window could lose the
		# touch on Android, so "찾기 → 보관하기" did not switch back. The native
		# touch button always emits, and refresh() repaints both tab states.
		for index: int in range(2):
			var button: Button=UI.button("보관하기" if index==0 else "찾기",func() -> void:
				_select_mode(index),Vector2(0,38))
			button.set_script(NativeTouchButton)
			button.name="WarehouseDepositTab" if index==0 else "WarehouseWithdrawTab"
			button.toggle_mode=true
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			modes.add_child(button);tabs.append(button)
		view.quantity.value_changed.connect(func(_amount: float) -> void:refresh())
		view.summary.add_theme_color_override("font_color",UI.MUTED)
	else:
		view.details.add_theme_font_size_override("font_size",12)
		view.details.add_theme_color_override("font_color",UI.GOLD)
		view.resized.connect(_fit)
		_fit()

func _select_mode(index: int) -> void:
	if not is_instance_valid(view):return
	if view.mode.selected!=index:
		view.mode.select(index)
		view.mode.item_selected.emit(index)
	else:
		refresh()

func _fit() -> void:
	if not is_instance_valid(view):return
	(view.get_child(0) as Control).visible=view.size.y>=400

func refresh(report: Dictionary={},rebuild_rows: bool=false) -> void:
	var index: int=int(view.selected_index) if warehouse else int(view.selected)
	if warehouse:
		for i: int in range(tabs.size()):tabs[i].set_pressed_no_signal(view.mode.selected==i)
		view.action.text="보관하기" if view.mode.selected==0 else "찾기"
		view.summary.text="장착 장비 제외 · 찾을 때 소지 무게 확인"
	else:view.action.text="판매하기"
	if rebuild_rows:
		for i: int in range(view.entries.size()):
			var entry: Dictionary=view.entries[i]
			view.listing.set_item_metadata(i,str(entry.name)+"@@@"+str(entry.get("instance_id","")))
			var id: String=str(entry.get("instance_id",""))
			var physical: Dictionary=view.world.item_instances
			if warehouse and view.mode.selected==1:physical=view.world.warehouse.instances
			var badge: String="+%d" % int((physical.get(id,{}) as Dictionary).get("level",0)) if not id.is_empty() else "×"+str(int(entry.count))
			view.listing.set_item_text(i,badge)
			view.listing.set_item_tooltip(i,str(entry.name)+" · "+badge)
	if index<0 or index>=view.entries.size():
		picture.texture=null;title.text="선택한 아이템 없음";count_label.text=""
		if not warehouse:view.details.text="조건에 맞는 판매 아이템이 없습니다."
		return
	var entry: Dictionary=view.entries[index]
	picture.texture=view.listing.get_item_icon(index)
	title.text=str(entry.name)
	var id: String=str(entry.get("instance_id",""))
	var physical: Dictionary=view.world.item_instances
	if warehouse and view.mode.selected==1:physical=view.world.warehouse.instances
	if not id.is_empty() and physical.has(id):title.text="+%d %s" % [int(physical[id].get("level",0)),entry.name]
	count_label.text="보유 %s개 · 선택 %s개" % [UI.number_text(int(entry.count)),UI.number_text(int(view.quantity.value))]
	if not warehouse and not report.is_empty():
		view.details.text="받을 금액  "+UI.number_text(int(report.get("payment",0)))+" 아데나" if bool(report.get("ok",false)) else str(report.get("reason","매입 불가"))

	if not warehouse and view.world._item_locked(str(entry.name),id):
		view.action.disabled=true
		view.details.text="잠긴 아이템은 판매할 수 없습니다."
