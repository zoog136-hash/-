extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const SelectionSheet=preload("res://scripts/ui/selection_detail_sheet.gd")
var selection_sheet: Control
const ReferenceSurfaces=preload("res://scripts/ui/reference_surfaces.gd")
const CURRENT = preload("res://scripts/skills/current_official_skills.gd")
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
var reagent_button: Button
var official_toggle_preview: CheckButton
var preview_button: Button
var preview_vfx: TwilightOriginalSkillVFX
var preview_container: SubViewportContainer
var school_filter: OptionButton
var cards: ItemList
var detail: RichTextLabel
var cooldown: Label
var use_button: Button
var quick_button: Button
var clock: float = 0
var summon_controls: HBoxContainer
var summon_order: OptionButton
var touch_start: Vector2
var dragging: bool = false
var touch_active: bool = false
# Grayscale variants are created once per source texture while this view lives.
# Do not re-read/decompress icons during the cooldown polling loop.
var unlearned_icons: Dictionary = {}
var class_only: bool = false
var scope_buttons: Array[Button] = []

func configure(controller: Node) -> void:
	hud=controller
	visibility_changed.connect(_sync_visibility)
	records=hud.job_skills.duplicate(true)
	# The inspected 2023 menu has direct All/Technique tabs above an icon grid.
	# Names, costs and learning information remain in the existing inspector.
	var scope:=HBoxContainer.new();scope.name="SkillReferenceTabs"
	add_child(scope)
	for current: int in range(2):
		var selection: int=current
		var button: Button=UI.button("전체" if current==0 else "기술",func() -> void:
			class_only=selection==1
			type_filter.select(4 if class_only else 0);class_filter.select(0);refresh(),Vector2(100,44))
		button.name="SkillAllTab" if current==0 else "SkillTechniqueTab"
		button.toggle_mode=true
		scope.add_child(button);scope_buttons.append(button)
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scope.add_child(spacer)
	var toolbar := HFlowContainer.new()
	var filters_button: Button=UI.button("검색",func() -> void:toolbar.visible=not toolbar.visible,Vector2(64,44))
	filters_button.name="SkillFiltersToggle"
	filters_button.tooltip_text="이름 · 종류 · 직업 · 등급 검색"
	scope.add_child(filters_button)
	toolbar.hide()
	add_child(toolbar)
	search=LineEdit.new()
	search.name="SkillSearch"
	search.placeholder_text="스킬 이름 · 효과 검색"
	search.custom_minimum_size.x = 150
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value: String) -> void: refresh())
	toolbar.add_child(search)
	type_filter=OptionButton.new()
	for text: String in ["현재 직업 · 공용","액티브","패시브","등록 스킬 전체 · 조회","직업 기술"]: type_filter.add_item(text)
	type_filter.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(type_filter)
	class_filter = OptionButton.new()
	class_filter.add_item("현재 직업")
	for job: String in hud.get_parent().JOB_CLASS_ORDER: class_filter.add_item(job)
	class_filter.add_item("공용")
	class_filter.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(class_filter)
	grade_filter = OptionButton.new()
	for grade: String in ["모든 등급","일반","고급","희귀","영웅","전설","신화","유일","미확인"]: grade_filter.add_item(grade)
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
		world._request_deferred_save()
		refresh())
	toolbar.add_child(school_filter)
	var state: Dictionary = hud.character_state
	scope.tooltip_text="Lv.%d %s / 등록 %d · 신규 %d" % [state.get("level",1),state.get("job_class","기사"),records.size(),hud.get_parent().original_skills.catalog.current_official.records.size()]
	var body := Browser.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(body)
	cards=ItemList.new()
	cards.name="SkillCards"
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cards.max_columns=4
	cards.fixed_column_width=76
	cards.fixed_icon_size=Vector2i(54,54)
	cards.add_theme_font_size_override("font_size",1)
	cards.add_theme_constant_override("h_separation",6)
	cards.add_theme_constant_override("v_separation",6)
	cards.icon_mode=ItemList.ICON_MODE_TOP
	cards.max_text_lines=1
	cards.same_column_width=true
	cards.item_selected.connect(select)
	# Shared PointerTransfer handles native touch, scrolling and actual drops.
	body.add_child(cards)
	var side_scroll := ScrollContainer.new()
	side_scroll.name = "OriginalSkillDetailsScroll"
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side)
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
		if hud.get_parent().original_skills.catalog.learn(str(selected.id)):
			refresh()
		else:
			select(cards.get_selected_items()[0]))
	learn_button.name = "LearnOriginalSkill"
	learn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(learn_button)
	book_button = UI.button("스킬북 구입", func() -> void:
		if selected.is_empty(): return
		hud.get_parent().original_skills.catalog.buy_book(str(selected.id))
		select(cards.get_selected_items()[0]))
	book_button.name = "BuyOriginalSkillBook"
	reagent_button = UI.button("스킬 재료 구입",func() -> void:
		if not selected.is_empty():
			hud.get_parent().original_skills.local_runtime.buy_reagents(selected)
			select(cards.get_selected_items()[0]))
	reagent_button.visible = false
	actions.add_child(reagent_button)
	book_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(book_button)
	preview_container = SubViewportContainer.new()
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
		if selected.is_empty() or not is_visible_in_tree(): return
		if selection_sheet!=null and hud.workspace.was_scroll_dragged(selection_sheet.scroll):return
		preview_container.visible = true
		preview_vfx.clear()
		preview_vfx.emit_skill(str(selected.id), "cast", Vector2(90,45))
		preview_vfx.emit_skill(str(selected.id), "impact", Vector2(180,45))
		_fit_effect_preview(viewport))
	side.add_child(preview_button)
	official_toggle_preview = CheckButton.new()
	official_toggle_preview.name = "OfficialTogglePreview"
	official_toggle_preview.text = "ON/OFF 미리보기 · 전투 미적용"
	official_toggle_preview.visible = false
	official_toggle_preview.toggled.connect(func(on: bool) -> void:
		if not bool(selected.get("runtime_blocked", false)): return
		if on: preview_button.pressed.emit()
		else:
			preview_vfx.clear()
			preview_container.visible = false)
	side.add_child(official_toggle_preview)
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
	summon_controls = HBoxContainer.new()
	summon_controls.name = "SummonCommands"
	summon_controls.visible = false
	side.add_child(summon_controls)
	summon_order = OptionButton.new()
	for label: String in ["보호","공격","따라오기","대기"]: summon_order.add_item(label)
	summon_order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summon_order.item_selected.connect(func(index: int) -> void:
		var world: Node = hud.get_parent()
		var orders: Array[String] = ["guard","attack","follow","stay"]
		if not world.original_skills.summons.command(orders[index],world.selected_monster): world.hud.show_message("소환수 또는 공격 대상 없음"))
	summon_controls.add_child(summon_order)
	summon_controls.add_child(UI.button("소환 해제",func() -> void: hud.get_parent().original_skills.summons.command("dismiss")))
	selection_sheet=SelectionSheet.new()
	var inspector: Control=selection_sheet.bind_skill(self,side_scroll,side)
	body.configure(cards,inspector,278)
	body.move_child(body.tabs,body.get_child_count()-1)
	(body.tabs.get_child(0) as Button).text="스킬 목록"
	(body.tabs.get_child(1) as Button).text="상세보기"
	cards.add_theme_stylebox_override("panel",UI.MATERIAL.from_flat(UI.box(Color("211b14"),Color("675640"),4),true))
	for button: Button in [learn_button,book_button,use_button,quick_button]:ReferenceSurfaces.action(button)
	hud.workspace.register_scroll_drag(side_scroll,side_scroll)
	refresh()

func refresh() -> void:
	var scroll_position: float = cards.get_v_scroll_bar().value
	cards.clear()
	filtered.clear()
	var job := str(hud.character_state.get("job_class","기사")) if class_filter.selected == 0 else class_filter.get_item_text(class_filter.selected)
	var selected_id: String = str(selected.get("id",selected.get("name","")))
	var query := search.text.to_lower().strip_edges()
	class_only=type_filter.selected==4
	for index: int in range(scope_buttons.size()):scope_buttons[index].button_pressed=(index==1)==class_only
	for value: Variant in records:
		if not value is Dictionary: continue
		var record: Dictionary=value
		var activation := str(record.get("activation","active"))
		if bool(record.get("toggle_classified", false)) and str(record.name) == "슈팅 스타": activation = "passive"
		if type_filter.selected != 3:
			var allowed: Array = record.get("classes", [record.get("class", "공용")])
			if job == "공용":
				if str(record.get("class", "")) != "공용": continue
			elif not allowed.has(job): continue
		if class_only and str(record.get("class","공용"))=="공용":continue
		if grade_filter.selected > 0 and str(record.get("grade", "")) != grade_filter.get_item_text(grade_filter.selected): continue
		if type_filter.selected==1 and activation=="passive": continue
		if type_filter.selected==2 and activation!="passive": continue
		if query!="" and not (str(record.get("name",""))+str(record.get("desc",""))+str(record.get("historical_aliases",[]))).to_lower().contains(query): continue
		filtered.append(record)
	filtered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ga: int=UI.GRADES.keys().find(str(a.get("grade","일반")))
		var gb: int=UI.GRADES.keys().find(str(b.get("grade","일반")))
		return str(a.get("name",""))<str(b.get("name","")) if ga==gb else ga<gb)
	for index: int in range(filtered.size()):
		var record: Dictionary=filtered[index]
		var passive := RULES.is_passive(record)
		var learned: bool = hud.get_parent().original_skills.catalog.owned(record)
		var icon: Texture2D = _icon_for_skill(record,learned)
		var subtitle: String = CURRENT.mode_label(record) if bool(record.get("runtime_blocked", false)) else "패시브" if passive else "MP %d" % int(record.get("mp",0))
		cards.add_item(" ",icon)
		cards.set_item_metadata(index,str(record.get("id",record.get("name",""))))
		cards.set_item_tooltip(index,("미구현 · " if bool(record.get("runtime_blocked",false)) else "습득 · " if learned else "미습득 · ")+str(record.get("name",""))+" · "+subtitle)
		var color: Color=UI.grade(str(record.get("grade","일반"))) if learned else Color("aaa7a1")
		cards.set_item_icon_modulate(index,Color.WHITE if learned else Color(.68,.68,.68,.62))
		cards.set_item_custom_fg_color(index,color)
		cards.set_item_custom_bg_color(index,Color(color,.07))
	if filtered.is_empty():
		_clear_selection()
	else:
		var chosen: int = 0
		for i: int in range(filtered.size()):
			if str(filtered[i].get("id",filtered[i].get("name",""))) == selected_id: chosen = i
		cards.select(chosen)
		select(chosen)
		cards.get_v_scroll_bar().set_deferred("value",scroll_position)

func _icon_for_skill(record: Dictionary, learned: bool) -> Texture2D:
	var path: String = str(record.get("icon",""))
	if not learned and not path.is_empty() and unlearned_icons.has(path):
		return unlearned_icons[path] as Texture2D
	var source: Texture2D = load(path) as Texture2D if not path.is_empty() else hud._skill_icon(str(record.get("effect","")),str(record.get("type","")))
	return source if learned else _unlearned_icon(source)

func _unlearned_icon(source: Texture2D) -> Texture2D:
	if source == null: return null
	var key: String = source.resource_path if not source.resource_path.is_empty() else "texture:%d" % source.get_instance_id()
	if unlearned_icons.has(key): return unlearned_icons[key] as Texture2D
	var source_image: Image = source.get_image()
	if source_image == null or source_image.is_empty(): return source
	var image: Image = source_image.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK: return source
	# ItemList cannot apply a different shader per row. Use the native luminance
	# conversion once at the displayed icon size, preserving source alpha.
	var extent: int = maxi(image.get_width(),image.get_height())
	if extent > 54:
		var ratio: float = 54.0 / float(extent)
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_LA8)
	var gray: ImageTexture = ImageTexture.create_from_image(image)
	unlearned_icons[key] = gray
	return gray

func select(index: int) -> void:
	if index<0 or index>=filtered.size(): return
	if str(selected.get("id",selected.get("name","")))!=str(filtered[index].get("id",filtered[index].get("name",""))):
		preview_vfx.clear()
		preview_container.hide()
	selected=filtered[index]
	summon_controls.hide()
	learn_button.disabled=true
	book_button.disabled=true
	preview_button.disabled=true
	learn_button.tooltip_text="이 스킬은 습득 조작을 지원하지 않습니다."
	book_button.tooltip_text="이 스킬은 스킬북 구입을 지원하지 않습니다."
	use_button.tooltip_text=""
	quick_button.tooltip_text=""
	official_toggle_preview.set_pressed_no_signal(false)
	official_toggle_preview.visible = bool(selected.get("toggle_classified", false)) and bool(selected.get("runtime_blocked",false))
	reagent_button.visible = false
	preview_button.disabled = false
	if bool(selected.get("runtime_blocked", false)):
		detail.text = CURRENT.detail_text(selected)
		learn_button.disabled = true
		book_button.disabled = true
		use_button.disabled = true
		quick_button.disabled = true
		use_button.text = "실행 보류"
		learn_button.tooltip_text = CURRENT.blocked_reason(selected)
		book_button.tooltip_text = "습득 스킬북·입수/가격 미확인"
		summon_controls.visible = false
		cooldown.text = "확인된 수치만 표시 · 프리뷰 가능"
		selection_sheet.show_skill()
		return
	use_button.text = "스킬 사용"
	if selected.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029"]:
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
	selection_sheet.show_skill()

func _clear_selection() -> void:
	selected={}
	detail.text="검색 조건에 맞는 스킬이 없습니다."
	cooldown.text=""
	for button: Button in [learn_button,book_button,use_button,quick_button,preview_button]:
		button.disabled=true
		button.tooltip_text="스킬을 먼저 선택하세요."
	use_button.text="스킬 사용"
	summon_controls.hide()
	official_toggle_preview.hide()
	reagent_button.hide()
	preview_vfx.clear()
	preview_container.hide()
	selection_sheet.show_skill()

func original_field_text(value: String, field: Dictionary) -> String:
	var display := UI.safe(value)
	match str(field.get("status", "UNKNOWN")):
		"VERIFIED": return display + " (원작 확인)"
		"INFERRED": return display + " (추정)"
		"CUSTOM_BALANCE": return display + " (TWILIGHT 설정)"
		"NOT_APPLICABLE": return "해당 없음"
	return "원작 미확인" if value.is_empty() else "원작 미확인 (게임 표시: %s)" % display

func select_original() -> void:
	if bool(selected.get("local_design",false)):
		select_local()
		return
	var world: Node = hud.get_parent()
	var service: TwilightOriginalSkillService = world.original_skills
	var catalog: TwilightOriginalSkillCatalog = service.catalog
	var skill: Dictionary = catalog.resolve(selected)
	preview_button.disabled=skill.is_empty()
	preview_button.tooltip_text="선택한 스킬의 기존 이펙트 미리보기" if not preview_button.disabled else "미리보기를 지원하지 않는 스킬입니다."
	var learned: bool = catalog.owned(selected)
	var passive: bool = RULES.is_passive(selected)
	var base_cooldown: float = float(skill.get("cooldown",0))
	var final_cooldown: float = base_cooldown*world._skill_cooldown_factor()
	var weapons: String = "제한 없음" if skill.get("weapons",[]).is_empty() else " · ".join(skill.weapons)
	detail.text = "[font_size=20][color=#%s]%s[/color][/font_size]\n%s · %s\n\n%s\n\nMP %d  /  HP %d\n기본 재사용 %.1f초\n보정 후 재사용 %.1f초\n지속시간 %.1f초\n사용 무기 %s\n\n%s" % [UI.grade(str(selected.grade)).to_html(false),UI.safe(selected.name),str(skill.get("display_class",selected.get("class",""))),"패시브" if passive else "액티브",UI.safe(selected.desc),int(skill.get("mp",0)),int(skill.get("hp",0)),base_cooldown,final_cooldown,float(skill.get("duration",0)),weapons,"습득 완료" if learned else UI.safe(catalog.reason(selected))]
	var fields: Dictionary = selected.get("fields",{})
	var basic: Dictionary = fields.get("basic",{})
	var learning: Dictionary = fields.get("learning",{})
	var level_field: Dictionary = {"status":"VERIFIED"} if skill.has("current_class_reference") else learning.get("minimum_level",{})
	var acquisition: Dictionary = learning.get("book_acquisition",{})
	var acquisition_text: String = "" if acquisition.get("value") == null else str(acquisition.value)
	detail.text += "\n\n%s · %s\n습득 %s\n스킬북 가격 %s\n원작 입수처: %s\n사용 수치: TWILIGHT 설정" % [original_field_text(str(selected.grade),basic.get("grade",{})),original_field_text("패시브" if passive else "액티브",basic.get("activation",{})),original_field_text("Lv.%d" % catalog.minimum_level_for(selected),level_field),original_field_text("%d 아데나" % int(selected.book_cost),learning.get("adena_cost",{})),original_field_text(acquisition_text,acquisition)]
	if skill.has("current_class_reference"):
		var fact:Dictionary=skill.current_class_reference
		detail.text += "\n\n공식 공통 마법: %s Lv.%s / MP %s\n기존 스킬 ID·TWILIGHT 동작 공유\n%s" % [str(fact["class"]),str(fact.level_display),str(fact.mp_display),str(fact.source_url)]
	if catalog.current_official.mode_audit.has(str(selected.id)):
		detail.text += "\n\n현재 공식 분류: 패시브 / 기존 게임 동작: 액티브\n기존 비용·행동·저장 호환을 위한 전환 검토 중"
	if passive: detail.text = detail.text.replace("기본 재사용 %.1f초\n보정 후 재사용 %.1f초" % [base_cooldown,final_cooldown],"패시브 · 조건 충족 시 적용")
	if passive: detail.text = detail.text.replace("지속시간 %.1f초" % float(skill.get("duration",0)),"상시 / 조건부 적용")
	summon_controls.visible = str(selected.mode) == "summon" and learned
	learn_button.disabled = not catalog.reason(selected).is_empty()
	learn_button.tooltip_text = catalog.reason(selected)
	book_button.disabled = not catalog.reason(selected,true).is_empty() or int(world.gold) < int(selected.book_cost)
	book_button.tooltip_text = catalog.reason(selected,true) if not catalog.reason(selected,true).is_empty() else "%d 아데나" % int(selected.book_cost)
	use_button.disabled = passive or not learned or catalog.level_locked(selected)
	use_button.tooltip_text = "패시브는 직접 사용할 수 없습니다" if passive else "미습득 스킬입니다" if not learned else "Lv.%d 필요" % catalog.minimum_level_for(selected) if catalog.level_locked(selected) else ""
	quick_button.disabled = passive or not learned
	quick_button.tooltip_text = use_button.tooltip_text
	clock = 0
	selection_sheet.show_skill()

func _process(delta: float) -> void:
	if bool(selected.get("runtime_blocked", false)): return
	clock-=delta
	if clock>0 or hud==null or selected.is_empty(): return
	clock=.15
	var world: Node=hud.get_parent()
	if selected.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029"]:
		use_button.disabled = not world.original_skills.ready(selected)
		if bool(selected.get("local_design",false)) and selected.mode=="local_toggle":
			use_button.text = "OFF · 범위 해제" if world.original_skills.local_runtime.is_on(selected) else "ON · 활성화"
		var registration_error: String = world._quickslot_registration_error("skill",str(selected.id))
		quick_button.disabled = not registration_error.is_empty()
		quick_button.tooltip_text = registration_error
		var original_remain: float = float(world.skill_cooldowns.get(str(selected.name), 0))
		cooldown.text = "패시브 적용" if RULES.is_passive(selected) and world.original_skills.catalog.owned(selected) else "재사용 %.1f초" % original_remain if original_remain > 0 else "준비됨" if world.original_skills.catalog.owned(selected) else "미습득"
		if str(selected.mode) == "summon" and world.original_skills.summons.active(str(selected.id)): cooldown.text += " · 소환 %.0f초" % world.original_skills.summons.remaining
		return
	var remain := float(world.skill_cooldowns.get(str(selected.get("name","")),0))
	cooldown.text="재사용 %.1f초 남음" % remain if remain>0 else "재사용 준비됨"
	var owned := str(selected.get("class","공용")) in ["공용",str(hud.character_state.get("job_class","기사"))]
	use_button.disabled=RULES.is_passive(selected) or not owned or not RULES.is_supported(RULES.effect_kind(selected)) or remain>0 or int(hud.character_state.get("mp",0))<int(selected.get("mp",0))

func _sync_visibility() -> void:
	set_process(is_visible_in_tree())
	clock = 0
	if not is_visible_in_tree() and is_instance_valid(preview_vfx):
		preview_vfx.clear()
		preview_container.hide()

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

func _fit_effect_preview(viewport: SubViewport) -> void:
	# Imported SPR origins can lie above the small preview. Fit the whole union
	# here only; combat/world anchors and the underlying source frames stay intact.
	var bounds := Rect2()
	var found := false
	for item: Dictionary in preview_vfx.live:
		var sprite: AnimatedSprite2D = item.get("spx_sprite") as AnimatedSprite2D
		if not is_instance_valid(sprite): continue
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
		var origin: Vector2 = sprite.offset - texture.get_size() * .5 if sprite.centered else sprite.offset
		var box := Rect2(sprite.position + origin * sprite.scale, texture.get_size() * sprite.scale)
		bounds = bounds.merge(box) if found else box
		found = true
	viewport.canvas_transform = Transform2D.IDENTITY
	if not found: return
	var extent := Vector2(viewport.size)
	var ratio := minf(1.0, minf((extent.x - 12) / maxf(1, bounds.size.x), (extent.y - 12) / maxf(1, bounds.size.y)))
	var transform := Transform2D.IDENTITY.scaled(Vector2.ONE * ratio)
	transform.origin = extent * .5 - bounds.get_center() * ratio
	viewport.canvas_transform = transform

func select_local() -> void:
	var service: TwilightOriginalSkillService = hud.get_parent().original_skills
	var catalog: TwilightOriginalSkillCatalog = service.catalog
	var owned: bool = catalog.owned(selected)
	var passive: bool = RULES.is_passive(selected)
	detail.text = CURRENT.runtime_text(catalog.resolve(selected))
	detail.text += "\n\n" + ("습득 완료" if owned else catalog.reason(selected))
	learn_button.disabled = not catalog.reason(selected).is_empty()
	learn_button.tooltip_text = catalog.reason(selected)
	book_button.disabled = not catalog.reason(selected,true).is_empty() or int(hud.get_parent().gold)<int(selected.book_cost)
	book_button.tooltip_text = "TWILIGHT 스킬북 %d 아데나" % int(selected.book_cost)
	reagent_button.visible = not selected.get("items",{}).is_empty() or not selected.get("proc_items",{}).is_empty()
	reagent_button.disabled = not catalog.permitted(selected)
	reagent_button.tooltip_text = "TWILIGHT 재료 가격 · 명예 코인 100 / 정령옥 200 / 흑요석 500 아데나 (필요 수량 구입)"
	use_button.disabled = not service.ready(selected)
	use_button.text = "패시브 · 자동 발동" if passive else ("OFF · 범위 해제" if service.local_runtime.is_on(selected) else "ON · 활성화") if selected.mode=="local_toggle" else "스킬 사용"
	quick_button.disabled = passive or not owned
	summon_controls.visible = selected.mode=="summon" and owned
	cooldown.text = "패시브 적용" if passive and owned else "미습득" if not owned else "ON" if service.local_runtime.is_on(selected) else "준비 / 재사용 확인"
	clock = 0
	selection_sheet.show_skill()
