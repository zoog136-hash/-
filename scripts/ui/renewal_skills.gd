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
var class_filter: OptionButton
var grade_filter: OptionButton
var learn_button: Button
var book_button: Button
var preview_button: Button
var preview_vfx: TwilightOriginalSkillVFX
var school_filter: OptionButton
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
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	search=LineEdit.new()
	search.name="SkillSearch"
	search.placeholder_text="스킬 이름 · 효과 검색"
	search.custom_minimum_size.x = 150
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value: String) -> void: refresh())
	toolbar.add_child(search)
	type_filter=OptionButton.new()
	for text: String in ["현재 직업 · 공용","액티브","패시브","전체 DB · 조회"]: type_filter.add_item(text)
	type_filter.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(type_filter)
	class_filter = OptionButton.new()
	class_filter.add_item("현재 직업")
	for job: String in hud.get_parent().JOB_CLASS_ORDER: class_filter.add_item(job)
	class_filter.add_item("공용")
	class_filter.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(class_filter)
	grade_filter = OptionButton.new()
	for grade: String in ["모든 등급","일반","고급","희귀","영웅","전설","신화","유일"]: grade_filter.add_item(grade)
	grade_filter.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(grade_filter)
	school_filter = OptionButton.new()
	for school: String in ["물 계열","땅 계열","바람 계열","불 계열"]: school_filter.add_item(school)
	school_filter.visible = str(hud.character_state.get("job_class", "")) == "요정"
	var schools: Array[String] = ["water","earth","wind","fire"]
	school_filter.select(maxi(0,schools.find(str(hud.get_parent().original_skills.catalog.schools.get("요정","water")))))
	school_filter.item_selected.connect(func(index: int) -> void:
		var world: Node = hud.get_parent()
		world.original_skills.catalog.schools["요정"] = schools[index]
		world._update_hud()
		world._save_game(true)
		refresh())
	toolbar.add_child(school_filter)
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
	detail.custom_minimum_size.y = 120
	detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	side.add_child(detail)
	cooldown=UI.label("",13,UI.MUTED)
	side.add_child(cooldown)
	var actions := GridContainer.new()
	actions.columns = 2
	side.add_child(actions)
	learn_button = UI.button("스킬 습득", func() -> void:
		if selected.is_empty(): return
		hud.get_parent().original_skills.catalog.learn(str(selected.id))
		select(cards.get_selected_items()[0]))
	learn_button.name = "LearnOriginalSkill"
	learn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(learn_button)
	book_button = UI.button("스킬북 구입", func() -> void:
		if selected.is_empty(): return
		hud.get_parent().original_skills.catalog.buy_book(str(selected.id))
		select(cards.get_selected_items()[0]))
	book_button.name = "BuyOriginalSkillBook"
	book_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(book_button)
	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(278,85)
	preview_container.stretch = true
	preview_container.visible = false
	side.add_child(preview_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(278,85)
	viewport.transparent_bg = true
	preview_container.add_child(viewport)
	preview_vfx = preload("res://scripts/skills/skill_vfx.gd").new()
	viewport.add_child(preview_vfx)
	preview_button = UI.button("이펙트 프리뷰", func() -> void:
		if selected.is_empty(): return
		preview_container.visible = true
		preview_vfx.clear()
		preview_vfx.emit_skill(str(selected.id), "cast", Vector2(90,45))
		preview_vfx.emit_skill(str(selected.id), "impact", Vector2(180,45)))
	side.add_child(preview_button)
	use_button=UI.button("스킬 사용",func() -> void:
		if not selected.is_empty(): hud.job_skill_pressed.emit(str(selected.get("name",""))))
	use_button.name="UseSkill"
	use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(use_button)
	quick_button=UI.button("퀵슬롯 · 자동",func() -> void:
		if not selected.is_empty():
			var skill_name := str(selected.get("name",""))
			hud._open_quickslot_picker("skill",skill_name,skill_name))
	quick_button.name="RegisterSkill"
	quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(quick_button)
	body.configure(cards,side,278)
	refresh()

func refresh() -> void:
	cards.clear()
	filtered.clear()
	var job := str(hud.character_state.get("job_class","기사")) if class_filter.selected == 0 else class_filter.get_item_text(class_filter.selected)
	var query := search.text.to_lower().strip_edges()
	for value: Variant in records:
		if not value is Dictionary: continue
		var record: Dictionary=value
		var activation := str(record.get("activation","active"))
		if type_filter.selected!=3 and str(record.get("class","공용")) not in [job,"공용"]: continue
		if grade_filter.selected > 0 and str(record.get("grade", "")) != grade_filter.get_item_text(grade_filter.selected): continue
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
		var learned: bool = hud.get_parent().original_skills.catalog.owned(record)
		var icon: Texture2D = load(str(record.icon)) as Texture2D if record.has("icon") else hud._skill_icon(str(record.get("effect","")),str(record.get("type","")))
		cards.add_item(("" if learned else "🔒 ") + str(record.get("name",""))+"\n"+("패시브" if passive else "MP %d" % int(record.get("mp",0))),icon)
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
	if selected.get("origin", "") == "LINEAGEM_20250617":
		select_original()
		return
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

func select_original() -> void:
	var world: Node = hud.get_parent()
	var service: TwilightOriginalSkillService = world.original_skills
	var catalog: TwilightOriginalSkillCatalog = service.catalog
	var skill: Dictionary = catalog.resolve(selected)
	var relation: Dictionary = catalog.relations.get(str(selected.id), {})
	var passive: bool = RULES.is_passive(selected)
	var learned: bool = catalog.owned(selected)
	var base: Dictionary = catalog.record_for(str(relation.get("upgrades_from", "")))
	var weapon_text := "제한 없음" if skill.get("weapons", []).is_empty() else " · ".join(skill.weapons)
	detail.text = "[font_size=22][color=#%s]%s[/color][/font_size]\n%s · %s · %s\n%s / 단계 %d\n\n%s\n\nMP %d / HP %d / 재사용 %.1f초\n지속 %.1f초 · 무기 %s\n\nLv.%d · %s\n%s\n선행 조건: %s\n%s\n\n수치: 원작 미확인 값은 TWILIGHT 밸런스\n시각 자료 대조: 진행 중" % [UI.grade(str(selected.grade)).to_html(false),UI.safe(selected.name),UI.safe(selected.get("class", "")),UI.safe(selected.grade),"패시브" if passive else "액티브",UI.safe(selected.school),int(selected.stage),UI.safe(selected.desc),int(skill.get("mp",0)),int(skill.get("hp",0)),float(skill.get("cooldown",0)),float(skill.get("duration",0)),weapon_text,int(selected.minimum_level),UI.safe(selected.book_name),"습득 완료" if learned else catalog.reason(selected),"원작 미확인" if relation.get("requires_status", "UNKNOWN") == "UNKNOWN" else "없음","강화 대상: " + str(base.get("name", "")) if not base.is_empty() else ""]
	detail.text += "\n스킬북 가격 %d 아데나" % int(selected.book_cost)
	if skill.mode == "counter": detail.text += "\n반격 발동 %.0f%% · 피해 배율 %.2f" % [float(skill.counter_chance)*100,float(skill.counter_multiplier)]
	var sources: Dictionary = catalog.read_json("sources.json")
	for id: String in selected.source_ids:
		var source: Dictionary = sources.get(id, {})
		detail.text += "\n[url=%s]%s 원작 자료[/url]" % [str(source.get("url", "")),str(source.get("effective", ""))]
	learn_button.disabled = not catalog.reason(selected).is_empty()
	book_button.disabled = not catalog.reason(selected, true).is_empty() or int(world.gold) < int(selected.book_cost)
	book_button.text = "스킬북 구입"
	use_button.disabled = passive or not learned
	use_button.text = "패시브 적용" if passive else "스킬 사용"
	quick_button.disabled = passive or not learned
	clock = 0

func _process(delta: float) -> void:
	clock-=delta
	if clock>0 or hud==null or selected.is_empty(): return
	clock=.15
	var world: Node=hud.get_parent()
	if selected.get("origin", "") == "LINEAGEM_20250617":
		use_button.disabled = not world.original_skills.ready(selected)
		quick_button.disabled = RULES.is_passive(selected) or not world.original_skills.catalog.owned(selected)
		var original_remain: float = float(world.skill_cooldowns.get(str(selected.name), 0))
		cooldown.text = "재사용 %.1f초" % original_remain if original_remain > 0 else "준비됨" if world.original_skills.catalog.owned(selected) else "미습득"
		return
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
