extends VBoxContainer
## Read-only display of the four collection definitions already supported by
## option_awakening_runtime. It invents no ordinary card collections or rewards.
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
const Ownership=preload("res://scripts/ui/catalog_card_ownership.gd")
const ScrollButton=preload("res://scripts/growth/growth_touch_button.gd")
const TouchButton=preload("res://scripts/ui/native_touch_button.gd")
var status: OptionButton
var body: VBoxContainer
var rows: Array=[]
var selected_id: String=""
var selected_card: String=""
var card_index: Dictionary={}
var ownership: Dictionary={}
var settings: Dictionary={}
var scroll_host: Node
var scroll_area: ScrollContainer
var _signature: String=""

func configure(host: Node,area: ScrollContainer) -> void:
	scroll_host=host;scroll_area=area
	name="AwakeningCollectionProgress"
	var top:=HBoxContainer.new();add_child(top)
	var title: Label=UI.label("지원 각성 컬렉션",14,UI.GOLD)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
	status=OptionButton.new();status.name="AwakeningCollectionState"
	for value: String in ["전체","진행 중","미완성","완성"]:status.add_item(value)
	status.item_selected.connect(func(_index: int) -> void:_render())
	top.add_child(status)
	var policy: Label=UI.label("확인된 4개만 표시 · 조건 달성 시 자동 적용 · 카드 소모 없음",11,UI.MUTED)
	policy.name="SupportedCollectionScope"
	policy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(policy)
	body=VBoxContainer.new();body.name="AwakeningCollectionRows";add_child(body)

func set_rows(values: Array,catalog: Dictionary,state: Dictionary,effect_settings: Dictionary) -> void:
	visible=not values.is_empty()
	if card_index.is_empty():
		for category: String in Cards.CATEGORIES:
			for record: Dictionary in catalog.get(category,[]):card_index[category+":"+Cards.card_id(record)]=record
	var signature: String=str(hash(values))+str(hash(state))+str(hash(effect_settings))
	if signature==_signature:return
	_signature=signature;rows=values.duplicate(true);ownership=state;settings=effect_settings
	if selected_id.is_empty() and not rows.is_empty():selected_id=str(rows[0].id)
	_render()

func _met_count(row: Dictionary) -> int:
	var count: int=0
	for requirement: Dictionary in row.requirements:
		if bool(requirement.get("met",false)):count+=1
	return count

func _render() -> void:
	for child: Node in body.get_children():body.remove_child(child);child.queue_free()
	var displayed: Array=[]
	for row: Dictionary in rows:
		var complete: bool=bool(row.get("completed",false))
		if status.selected==1 and (complete or _met_count(row)==0):continue
		if status.selected==2 and complete:continue
		if status.selected==3 and not complete:continue
		displayed.append(row)
	if not displayed.any(func(row: Dictionary) -> bool:return str(row.id)==selected_id):
		selected_id="" if displayed.is_empty() else str(displayed[0].id)
	for row: Dictionary in displayed:
		var cid: String=str(row.id)
		var complete: bool=bool(row.get("completed",false))
		var header: Button=_button()
		header.name="Collection_"+cid;header.set_meta("collection_id",cid)
		header.text="%s (%d/%d)" % [row.name,_met_count(row),row.requirements.size()]
		header.custom_minimum_size.y=44
		header.alignment=HORIZONTAL_ALIGNMENT_LEFT
		header.add_theme_color_override("font_color",Color("8bd29c") if complete else UI.TEXT)
		header.pressed.connect(func() -> void:selected_id=cid;_render())
		body.add_child(header)
		var reward: Label=UI.label(" · ".join(row.get("bonus_options",[])),12,UI.GOLD if complete else UI.MUTED)
		reward.name="CollectionReward";reward.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(reward)
		if cid!=selected_id:continue
		var grid:=GridContainer.new();grid.columns=4;grid.name="SelectedCollectionCards";body.add_child(grid)
		for requirement: Dictionary in row.requirements:_add_card(grid,requirement)
	if displayed.is_empty():body.add_child(UI.label("해당 상태의 지원 컬렉션이 없습니다",12,UI.MUTED))

func _button() -> Button:
	var button: Button=UI.button("",Callable(),Vector2.ZERO)
	if is_instance_valid(scroll_host):
		button.set_script(ScrollButton);button.scroll_host=scroll_host;button.scroll_area=scroll_area
	else:button.set_script(TouchButton)
	return button

func _add_card(grid: GridContainer,requirement: Dictionary) -> void:
	var category: String=str(requirement.category)
	var identity: String=str(requirement.id)
	var acquired: bool=(ownership.get("owned",{}).get(category,{}) as Dictionary).has(identity)
	var met: bool=bool(requirement.get("met",false))
	var record: Dictionary=card_index.get(category+":"+identity,{})
	var column:=VBoxContainer.new();column.custom_minimum_size.x=90;grid.add_child(column)
	var card: Button=_button();card.name="CollectionCard";card.custom_minimum_size=Vector2(90,122)
	card.set_meta("card_id",identity);card.set_meta("category",category);card.set_meta("permanent_owned",acquired);card.set_meta("condition_met",met)
	column.add_child(card)
	var rank: int=maxi(0,Chrome.GRADES.find(str(requirement.get("grade","일반"))))
	var art:=TextureRect.new();art.name="CollectionCardArt";art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture=Ownership.icon_for(record,acquired);art.modulate=Color.WHITE if acquired else Ownership.UNOWNED_ICON_TINT
	card.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if acquired:
		var aura:=ColorRect.new();aura.mouse_filter=Control.MOUSE_FILTER_IGNORE
		aura.material=Chrome.material_for(rank,true,false,bool(settings.get("reduced_motion",false)),str(settings.get("effect_detail","full"))=="low")
		card.add_child(aura);aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var metal:=TextureRect.new();metal.mouse_filter=Control.MOUSE_FILTER_IGNORE
	metal.texture=Chrome.texture_for(rank);metal.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	metal.material=Chrome.material_for(rank,false,false,bool(settings.get("reduced_motion",false)))
	metal.modulate=Color.WHITE if acquired else Ownership.UNOWNED_FRAME_TINT
	card.add_child(metal);metal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var duplicates: int=int(ownership.get("spare",{}).get(category,{}).get(identity,0))
	if duplicates>0:
		var amount: Label=UI.label(str(duplicates),11)
		card.add_child(amount);amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
	var title: Label=UI.label(str(requirement.name),10,UI.TEXT)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.max_lines_visible=2;column.add_child(title)
	var state_text: String="달성" if met else "미보유" if not acquired else "각성 필요" if bool(requirement.get("awakened",false)) else "보유"
	var state: Label=UI.label(state_text,10,Color("8bd29c") if met else UI.MUTED);column.add_child(state)
	card.tooltip_text=str(requirement.name)+" · "+state_text+" · "+identity
	card.pressed.connect(func() -> void:
		selected_card=identity
		state.text=state_text+" · 선택")
