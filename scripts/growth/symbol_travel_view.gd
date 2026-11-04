extends VBoxContainer
var service
var source: Dictionary={}
var origin: String=""
var revision: int=0
var selected: int=-1
var listing: ItemList
var detail: Label
var result: Label
var label_input: LineEdit
var confirm: Button

func configure(owner, request: Dictionary) -> void:
	service=owner;source=request.duplicate(true);origin=service.world.active_map_id
	name="SymbolTravelView";size_flags_vertical=Control.SIZE_EXPAND_FILL
	result=Label.new();result.name="SymbolTravelResult";result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.hide();add_child(result)
	var remember_row:=HBoxContainer.new();add_child(remember_row)
	label_input=LineEdit.new();label_input.name="SymbolBookmarkName";label_input.placeholder_text="기억 장소 이름";label_input.max_length=int(service.POLICY.name_limit);label_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;remember_row.add_child(label_input)
	button("현재 위치 기억","SymbolRemember",func() -> void: show_result(service.remember(label_input.text,revision)),remember_row)
	listing=preload("res://scripts/ui/native_touch_list.gd").new();listing.name="SymbolBookmarks";listing.size_flags_vertical=Control.SIZE_EXPAND_FILL;listing.custom_minimum_size.y=90;listing.item_selected.connect(select);add_child(listing)
	detail=Label.new();detail.name="SymbolTravelDetail";detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(detail)
	confirm=button("선택한 기억 장소로 이동","SymbolTravelConfirm",commit)
	var bottom:=HBoxContainer.new();add_child(bottom)
	button("선택한 장소 삭제","SymbolForget",func() -> void: show_result(service.forget(selected,revision)),bottom)
	button("닫기 · 소모 없음","SymbolTravelCancel",func() -> void: service.world.hud._close_workspace(),bottom)
	refresh()

func button(caption: String, id: String, action: Callable, parent: Node=null) -> Button:
	if parent==null:parent=self
	var b=preload("res://scripts/ui/native_touch_button.gd").new();b.name=id;b.text=caption;b.custom_minimum_size.y=44;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(action);parent.add_child(b);return b

func refresh() -> void:
	revision=int(service.runtime.state.revision);selected=-1;listing.clear()
	for row: Dictionary in service.marks():
		listing.add_item(str(row.name)+("" if row.map_id==origin else " · 다른 맵"))
	select(-1)

func select(index: int) -> void:
	selected=index
	var offer: Dictionary=service.quote(index,source,origin,revision)
	detail.text=str(offer.message);confirm.disabled=not bool(offer.ok)

func show_result(outcome: Dictionary) -> void:
	result.text=str(outcome.message);result.show();refresh()

func commit() -> void:
	var outcome: Dictionary=service.travel(selected,source,origin,revision)
	show_result(outcome)
	if outcome.ok:source={};select(-1)
