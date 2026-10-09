extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const RULES = preload("res://scripts/skill_rules.gd")
var hud: Node
var records: Array = []
var filtered: Array = []
var selected: Dictionary = {}
var search: LineEdit
var type_filter: OptionButton
var cards: ItemList
var detail: RichTextLabel
var cooldown: Label
var use_button: Button
var quick_button: Button
var clock: float = 0
var touch_start: Vector2
var dragging: bool = false
var touch_active: bool = false

func configure(controller: Node) -> void:
	hud=controller
	records=hud.job_skills
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	search=LineEdit.new()
	search.name="SkillSearch"
	search.placeholder_text="스킬 이름 · 효과 검색"
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value: String) -> void: refresh())
	toolbar.add_child(search)
	type_filter=OptionButton.new()
	for text: String in ["현재 직업 · 공용","액티브","패시브","전체 DB · 조회"]: type_filter.add_item(text)
	type_filter.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(type_filter)
	var state: Dictionary = hud.character_state
	add_child(UI.section("Lv.%d  %s  /  마법과 기술" % [state.get("level",1),state.get("job_class","기사")],14))
	var body := Browser.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(body)
	cards=ItemList.new()
	cards.name="SkillCards"
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cards.max_columns=4
	cards.fixed_column_width=110
	cards.fixed_icon_size=Vector2i(54,54)
	cards.icon_mode=ItemList.ICON_MODE_TOP
	cards.max_text_lines=2
	cards.same_column_width=true
	cards.item_selected.connect(select)
	cards.gui_input.connect(_touch)
	body.add_child(cards)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x=278
	body.add_child(side)
	side.add_child(UI.label("스킬 정보",18,UI.GOLD))
	detail=UI.rich("")
	detail.fit_content=false
	detail.scroll_active=true
	detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	side.add_child(detail)
	cooldown=UI.label("",13,UI.MUTED)
	side.add_child(cooldown)
	use_button=UI.button("스킬 사용",func() -> void:
		if not selected.is_empty(): hud.job_skill_pressed.emit(str(selected.get("name",""))))
	use_button.name="UseSkill"
	side.add_child(use_button)
	quick_button=UI.button("퀵슬롯 · 자동사용 등록",func() -> void:
		if not selected.is_empty():
			var skill_name := str(selected.get("name",""))
			hud._open_quickslot_picker("skill",skill_name,skill_name))
	quick_button.name="RegisterSkill"
	side.add_child(quick_button)
	body.configure(cards,side,278)
	refresh()

func refresh() -> void:
	cards.clear()
	filtered.clear()
	var job := str(hud.character_state.get("job_class","기사"))
	var query := search.text.to_lower().strip_edges()
	for value: Variant in records:
		if not value is Dictionary: continue
		var record: Dictionary=value
		var activation := str(record.get("activation","active"))
		if type_filter.selected!=3 and str(record.get("class","공용")) not in [job,"공용"]: continue
		if type_filter.selected==1 and activation=="passive": continue
		if type_filter.selected==2 and activation!="passive": continue
		if query!="" and not (str(record.get("name",""))+str(record.get("desc",""))).to_lower().contains(query): continue
		filtered.append(record)
	filtered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ga: int=UI.GRADES.keys().find(str(a.get("grade","일반")))
		var gb: int=UI.GRADES.keys().find(str(b.get("grade","일반")))
		return str(a.get("name",""))<str(b.get("name","")) if ga==gb else ga<gb)
	for index: int in range(filtered.size()):
		var record: Dictionary=filtered[index]
		var passive := RULES.is_passive(record)
		cards.add_item(str(record.get("name",""))+"\n"+("패시브" if passive else "MP %d" % int(record.get("mp",0))),hud._skill_icon(str(record.get("effect","")),str(record.get("type",""))))
		var color: Color=UI.grade(str(record.get("grade","일반")))
		cards.set_item_custom_fg_color(index,color)
		cards.set_item_custom_bg_color(index,Color(color,.07))
	if filtered.is_empty():
		selected={}
		detail.text="검색 조건에 맞는 스킬이 없습니다."
		use_button.disabled=true
		quick_button.disabled=true
	else:
		cards.select(0)
		select(0)

func select(index: int) -> void:
	if index<0 or index>=filtered.size(): return
	selected=filtered[index]
	var passive := RULES.is_passive(selected)
	var owned := str(selected.get("class","공용")) in ["공용",str(hud.character_state.get("job_class","기사"))]
	var supported := RULES.is_supported(RULES.effect_kind(selected))
	detail.text="[font_size=24][color=#%s]%s[/color][/font_size]\n%s · %s\n\nMP 소모  %d\n재사용 대기  %.1f초\n\n%s\n\n%s" % [UI.grade(str(selected.get("grade","일반"))).to_html(false),UI.safe(selected.get("name","")),UI.safe(selected.get("class","공용")),"패시브" if passive else "액티브",selected.get("mp",0),0.0 if passive else RULES.cooldown_seconds(selected),UI.safe(selected.get("desc","")),("현재 직업에서 사용 가능" if owned else "다른 직업 · 조회 전용")]
	if passive:
		detail.text+="\n"+("상시 적용" if RULES.passive_trigger(selected)=="always" else "조건부 발동: "+RULES.passive_trigger(selected))
	if not supported: detail.text+="\n이 효과는 현재 게임 버전에서 미지원"
	use_button.disabled=passive or not owned or not supported
	quick_button.disabled=passive or not owned or not supported
	use_button.text="패시브 · 자동 적용" if passive else "스킬 사용"
	clock=0

func _process(delta: float) -> void:
	clock-=delta
	if clock>0 or hud==null or selected.is_empty(): return
	clock=.15
	var world: Node=hud.get_parent()
	var remain := float(world.skill_cooldowns.get(str(selected.get("name","")),0))
	cooldown.text="재사용 %.1f초 남음" % remain if remain>0 else "재사용 준비됨"
	var owned := str(selected.get("class","공용")) in ["공용",str(hud.character_state.get("job_class","기사"))]
	use_button.disabled=RULES.is_passive(selected) or not owned or not RULES.is_supported(RULES.effect_kind(selected)) or remain>0 or int(hud.character_state.get("mp",0))<int(selected.get("mp",0))

func _touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start=event.position
			touch_active=true
			dragging=false
		else:
			if touch_active and not dragging:
				var index: int=cards.get_item_at_position(event.position,true)
				if index>=0: cards.select(index); select(index)
			touch_active=false
	elif event is InputEventScreenDrag and touch_active:
		if event.position.distance_to(touch_start)>8: dragging=true
		if dragging:
			cards.get_v_scroll_bar().value-=event.relative.y
			cards.accept_event()
