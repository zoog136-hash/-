extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const SelectionSheet=preload("res://scripts/ui/selection_detail_sheet.gd")
var selection_sheet: Control
const ReferenceSurfaces=preload("res://scripts/ui/reference_surfaces.gd")
const CURRENT = preload("res://scripts/skills/current_official_skills.gd")
const RULES = preload("res://scripts/skill_rules.gd")
const SOURCE523 = preload("res://scripts/skills/player_skills523.gd")
const Source523Images = preload("res://scripts/ui/source523_skill_buff_images.gd")
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
var decoded_skill_icons: Dictionary = {}
var class_only: bool = false
var scope_buttons: Array[Button] = []
var guardian_scope_button: Button
var guardian_special: VBoxContainer
var guardian_result: Label
var guardian_cast_buttons: Dictionary={}
var guardian_special_scroll: ScrollContainer
var guardian_hidden_state: Dictionary={}
var guardian_special_clock: float=0

func configure(controller: Node) -> void:
	hud=controller
	visibility_changed.connect(_sync_visibility)
	records=hud.job_skills.duplicate(true)
	var source = hud.get_parent().original_skills.catalog.source523
	if not source.profiles.is_empty() or not source.last_error.is_empty():
		var source_label: Label = UI.label("523 원본 규칙 · 확인된 비용과 대상 제한 적용" if not source.profiles.is_empty() else "523 자료를 읽지 못했습니다 · 기존 게임 규칙 사용",12,UI.MUTED)
		source_label.name = "PlayerSkills523Status"
		source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(source_label)
	# The inspected 2023 menu has direct All/Technique tabs above an icon grid.
	# Names, costs and learning information remain in the existing inspector.
	var scope:=HBoxContainer.new();scope.name="SkillReferenceTabs"
	add_child(scope)
	for current: int in range(2):
		var selection: int=current
		var button: Button=UI.button("전체" if current==0 else "기술",func() -> void:
			_hide_guardian_special()
			class_only=selection==1
			type_filter.select(4 if class_only else 0);class_filter.select(0);refresh(),Vector2(76,44))
		button.name="SkillAllTab" if current==0 else "SkillTechniqueTab"
		button.toggle_mode=true
		scope.add_child(button);scope_buttons.append(button)
	var special_button: Button=UI.button("특수 · 수호성",_show_guardian_special,Vector2(105,44))
	special_button.name="SkillGuardianSpecialTab"
	special_button.toggle_mode=true;guardian_scope_button=special_button
	scope.add_child(special_button)
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scope.add_child(spacer)
	var toolbar := HFlowContainer.new()
	var filters_button: Button=UI.button("검색",func() -> void:_hide_guardian_special();toolbar.visible=not toolbar.visible,Vector2(64,44))
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
	var group_button:Button=UI.button("스킬 계열 전환",func()->void:hud._navigate("spell_groups"))
	group_button.name="OpenSpellGroupConversion";toolbar.add_child(group_button)
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
		var source_status: Dictionary=hud.get_parent().original_skills.catalog.source_learning_status(record)
		var source_for_job: bool=not source_status.is_empty() and int(source_status.learned_class_id)==hud.get_parent().BASE508.source_class_id(job)
		if type_filter.selected != 3:
			var allowed: Array = record.get("classes", [record.get("class", "공용")])
			if job == "공용":
				if str(record.get("class", "")) != "공용": continue
			elif not allowed.has(job) and not source_for_job: continue
		if class_only and str(record.get("class","공용"))=="공용":continue
		if grade_filter.selected > 0 and str(record.get("grade", "")) != grade_filter.get_item_text(grade_filter.selected): continue
		var projected: Dictionary=hud.get_parent().original_skills.catalog.resolve(record)
		var activation := str(projected.get("activation","active"))
		if bool(record.get("toggle_classified", false)) and str(record.name) == "슈팅 스타": activation = "passive"
		if type_filter.selected==1 and activation=="passive": continue
		if type_filter.selected==2 and activation!="passive": continue
		if query!="" and not (str(record.get("name",""))+str(record.get("desc",""))+str(record.get("historical_aliases",[]))).to_lower().contains(query): continue
		filtered.append(record)
	filtered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ga: int=UI.GRADES.keys().find(str(a.get("grade","일반")))
		var gb: int=UI.GRADES.keys().find(str(b.get("grade","일반")))
		return str(a.get("name",""))<str(b.get("name","")) if ga==gb else ga<gb)
	var original_images: Dictionary = {}
	cards.add_theme_font_size_override("font_size",11 if Source523Images.selected() else 1)
	for index: int in range(filtered.size()):
		var record: Dictionary=filtered[index]
		var passive := RULES.is_passive(hud.get_parent().original_skills.catalog.resolve(record))
		var source_known: bool=not hud.get_parent().original_skills.catalog.source_learning_status(record).is_empty()
		var learned: bool = hud.get_parent().original_skills.catalog.owned(record) or source_known
		var source_image: Dictionary = Source523Images.describe_skill(record)
		var icon: Texture2D = source_image.get("texture") if source_image.handled else _icon_for_skill(record,learned)
		var effective: Dictionary = hud.get_parent().original_skills.catalog.resolve(record)
		var subtitle: String = CURRENT.mode_label(record) if bool(record.get("runtime_blocked", false)) else "패시브" if passive else "MP %d" % int(effective.get("mp",0))
		cards.add_item(Source523Images.missing_label(source_image) if source_image.handled and icon == null else " ",icon)
		cards.set_item_metadata(index,str(record.get("id",record.get("name",""))))
		if source_image.handled:
			original_images[str(record.get("id",""))] = Source523Images.evidence(source_image)
		cards.set_item_tooltip(index,("원본 학습 · 실행 대기 · " if source_known else "미구현 · " if bool(record.get("runtime_blocked",false)) else "습득 · " if learned else "미습득 · ")+str(record.get("name",""))+" · "+subtitle)
		var color: Color=UI.grade(str(record.get("grade","일반"))) if learned else Color("aaa7a1")
		cards.set_item_icon_modulate(index,Color.WHITE if source_image.handled or learned else Color(.68,.68,.68,.62))
		cards.set_item_custom_fg_color(index,color)
		cards.set_item_custom_bg_color(index,Color(color,.07))
	cards.set_meta("source523_images",original_images)
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
	var original: Dictionary = Source523Images.describe_skill(record)
	if original.handled: return original.get("texture") as Texture2D
	var path: String = str(record.get("icon",""))
	if not learned and not path.is_empty() and unlearned_icons.has(path):
		return unlearned_icons[path] as Texture2D
	var source: Texture2D
	if path.get_extension()=="svg" and FileAccess.file_exists(path) and not FileAccess.file_exists(path+".import"):
		# Decode the unchanged committed SVG in runtime-only consumers where
		# editor import metadata is absent; never synthesize replacement art.
		if not decoded_skill_icons.has(path):
			var image:=Image.new()
			if image.load_svg_from_string(FileAccess.get_file_as_string(path))==OK:decoded_skill_icons[path]=ImageTexture.create_from_image(image)
			else:push_error("Committed skill SVG cannot be decoded: "+path)
		source=decoded_skill_icons.get(path)
	else:source=load(path) as Texture2D if not path.is_empty() else hud._skill_icon(str(record.get("effect","")),str(record.get("type","")))
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

## Selects the skill `id` (from the original skill window's 상세 보기).
func focus_skill(id: String) -> void:
	for index: int in range(filtered.size()):
		if str(filtered[index].get("id",filtered[index].get("name","")))==id:
			cards.select(index)
			select(index)
			return

func select(index: int) -> void:
	if index<0 or index>=filtered.size(): return
	if str(selected.get("id",selected.get("name","")))!=str(filtered[index].get("id",filtered[index].get("name",""))):
		preview_vfx.clear()
		preview_container.hide()
	selected=filtered[index]
	_bind_skill_action_images(selected)
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
	if _show_source_learning():return
	if bool(selected.get("runtime_blocked", false)):
		detail.text = CURRENT.detail_text(selected)
		detail.text += SOURCE523.detail_text(hud.get_parent().original_skills.catalog.resolve(selected))
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
	_bind_skill_action_images({})
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

func _bind_skill_action_images(record: Dictionary) -> void:
	# These existing actions use this selected skill record. Book/reagent
	# controls retain their separate, not-yet-declared item image identities.
	for button: Button in [learn_button,use_button,quick_button]:
		button.icon = null
		if button.has_meta("source523_skill_image"): button.remove_meta("source523_skill_image")
	if record.is_empty() or not Source523Images.selected(): return
	var image: Dictionary = Source523Images.describe_skill(record,"IconID")
	var evidence: Dictionary = Source523Images.evidence(image)
	for button: Button in [learn_button,use_button,quick_button]:
		button.icon = image.get("texture") as Texture2D
		button.expand_icon = true
		button.set_meta("source523_skill_image",evidence.duplicate(true))

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
	var passive: bool = RULES.is_passive(skill)
	var base_cooldown: float = float(skill.get("cooldown",0))
	var final_cooldown: float = base_cooldown*world._skill_cooldown_factor()
	var weapons: String = "제한 없음" if skill.get("weapons",[]).is_empty() else " · ".join(skill.weapons)
	detail.text = "[font_size=20][color=#%s]%s[/color][/font_size]\n%s · %s\n\n%s\n\nMP %d  /  HP %d\n기본 재사용 %.1f초\n보정 후 재사용 %.1f초\n지속시간 %s\n사용 무기 %s\n\n%s" % [UI.grade(str(selected.grade)).to_html(false),UI.safe(selected.name),str(skill.get("display_class",selected.get("class",""))),"패시브" if passive else "액티브",UI.safe(skill.get("runtime_desc",selected.desc)),int(skill.get("mp",0)),int(skill.get("hp",0)),base_cooldown,final_cooldown,SOURCE523.duration_text(skill),weapons,"습득 완료" if learned else UI.safe(catalog.reason(selected))]
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
	detail.text += SOURCE523.detail_text(skill)
	if passive: detail.text = detail.text.replace("기본 재사용 %.1f초\n보정 후 재사용 %.1f초" % [base_cooldown,final_cooldown],"패시브 · 조건 충족 시 적용")
	if passive: detail.text = detail.text.replace("지속시간 %.1f초" % float(skill.get("duration",0)),"상시 / 조건부 적용")
	summon_controls.visible = str(selected.mode) == "summon" and learned
	learn_button.disabled = not catalog.reason(selected).is_empty()
	learn_button.tooltip_text = catalog.reason(selected)
	book_button.disabled = not catalog.reason(selected,true).is_empty() or int(world.gold) < int(selected.book_cost)
	book_button.tooltip_text = catalog.reason(selected,true) if not catalog.reason(selected,true).is_empty() else "%d 아데나" % int(selected.book_cost)
	use_button.disabled = passive or not learned or catalog.level_locked(selected)
	use_button.tooltip_text = "패시브는 직접 사용할 수 없습니다" if passive else "미습득 스킬입니다" if not learned else "Lv.%d 필요" % catalog.minimum_level_for(selected) if catalog.level_locked(selected) else ""
	if not str(skill.get("source523_block_reason", "")).is_empty():
		use_button.disabled = true
		use_button.tooltip_text = str(skill.source523_block_reason)
	quick_button.disabled = passive or not learned
	quick_button.tooltip_text = use_button.tooltip_text
	if not str(skill.get("source523_block_reason", "")).is_empty(): quick_button.disabled = true
	clock = 0
	selection_sheet.show_skill()

func _process(delta: float) -> void:
	if hud!=null and not selected.is_empty() and not hud.get_parent().original_skills.catalog.source_learning_status(selected).is_empty():
		use_button.disabled=true;quick_button.disabled=true;cooldown.text="원본 학습 기록 보관 · 실행 대기"
		return
	if is_instance_valid(guardian_special) and guardian_special.is_visible_in_tree():
		guardian_special_clock-=delta
		if guardian_special_clock>0:return
		guardian_special_clock=.25
		for id: String in guardian_cast_buttons:
			var quote: Dictionary=hud.get_parent().growth.quote("guardian_cast",id)
			var button: Button=guardian_cast_buttons[id]
			button.disabled=not quote.ok;button.tooltip_text=str(quote.message)
		return
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
		var effective: Dictionary = world.original_skills.catalog.resolve(selected)
		if effective.has("progression523"):
			use_button.text="패시브 · 자동 적용" if str(effective.activation)=="passive" else ("OFF · 비활성화" if world.original_skills.progression.is_on(selected) else "ON · 활성화") if str(effective.mode)=="source_toggle" else "스킬 사용"
		if not str(effective.get("source523_block_reason", "")).is_empty(): registration_error = str(effective.source523_block_reason)
		if effective.has("source523"): use_button.tooltip_text = world.original_skills.cost_reason(effective)
		quick_button.disabled = not registration_error.is_empty()
		quick_button.tooltip_text = registration_error
		var original_remain: float = float(world.skill_cooldowns.get(str(selected.name), 0))
		cooldown.text = "패시브 적용" if RULES.is_passive(effective) and world.original_skills.catalog.owned(selected) else "재사용 %.1f초" % original_remain if original_remain > 0 else "준비됨" if world.original_skills.catalog.owned(selected) else "미습득"
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
	detail.text += SOURCE523.detail_text(catalog.resolve(selected))
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

func _hide_guardian_special() -> void:
	if is_instance_valid(guardian_scope_button):guardian_scope_button.button_pressed=false
	for index: int in range(scope_buttons.size()):scope_buttons[index].button_pressed=(index==1)==class_only
	for child: Node in get_children():
		if guardian_hidden_state.has(child.get_instance_id()):child.visible=bool(guardian_hidden_state[child.get_instance_id()])
	if is_instance_valid(guardian_special):guardian_special.hide()
	if is_instance_valid(guardian_special_scroll):guardian_special_scroll.hide()

func _show_guardian_special() -> void:
	guardian_scope_button.button_pressed=true
	for button: Button in scope_buttons:button.button_pressed=false
	if not is_instance_valid(guardian_special_scroll) or not guardian_special_scroll.visible:
		guardian_hidden_state.clear()
		for child: Node in get_children():guardian_hidden_state[child.get_instance_id()]=child.visible
	if not is_instance_valid(guardian_special):
		guardian_special_scroll=ScrollContainer.new();guardian_special_scroll.name="GuardianSpecialScroll"
		guardian_special_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		guardian_special_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		add_child(guardian_special_scroll)
		guardian_special=VBoxContainer.new();guardian_special.name="GuardianSpecialSkills"
		guardian_special.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		guardian_special_scroll.add_child(guardian_special)
	for child: Node in get_children():child.visible=child.name=="SkillReferenceTabs" or child==guardian_special_scroll
	guardian_special.show()
	for child: Node in guardian_special.get_children():guardian_special.remove_child(child);child.queue_free()
	guardian_cast_buttons.clear()
	guardian_result=UI.label("수호성 사용 스킬 · 명예 코인 소모 / 질리언 스킬 재사용 시간 공유",14)
	guardian_result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	guardian_special.add_child(guardian_result)
	var rt=hud.get_parent().growth
	for id: String in rt.state.nodes:
		if not rt.guardian_source.has_node(id) or rt.node(id).kind!="active":continue
		var button: Button=_guardian_special_button(str(rt.node(id).name)+" · 명예 코인 10개",func() -> void:
			var response: Dictionary=rt.execute("guardian_cast",id,1,int(rt.state.revision))
			guardian_result.text=str(response.message),Vector2(220,48))
		button.name="GuardianSpecial_"+id
		guardian_cast_buttons[id]=button;guardian_special.add_child(button)
		var quick: Button=_guardian_special_button(str(rt.node(id).name)+" · 퀵슬롯 등록",func() -> void:hud._open_quickslot_picker("skill","guardian:"+id,str(rt.node(id).name)),Vector2(220,44))
		quick.name="GuardianQuick_"+id;guardian_special.add_child(quick)
		var image: Dictionary = {}
		var rewards: Array = rt.guardian_rewards(id)
		if Source523Images.selected() and rewards.size() == 1 and rewards[0] is Dictionary and rewards[0].get("spell") is Dictionary:
			image = Source523Images.describe_spell_class_row(rewards[0].spell, "IconID")
		for action_button: Button in [button, quick]:
			action_button.icon = null
			if action_button.has_meta("source523_skill_image"): action_button.remove_meta("source523_skill_image")
			if not image.is_empty():
				action_button.icon = image.get("texture") as Texture2D
				action_button.expand_icon = true
				action_button.set_meta("source523_skill_image", Source523Images.evidence(image))
	if guardian_cast_buttons.is_empty():guardian_special.add_child(UI.label("질리언의 사용 스킬을 개방하면 여기에 표시됩니다.",14))
	guardian_special.add_child(_guardian_special_button("명예 코인 10개 구입 · TWILIGHT 재료 상점",func() -> void:
		var response: Dictionary=rt.execute("guardian_buy_coins","",1,int(rt.state.revision));guardian_result.text=str(response.message),Vector2(220,48)))
	guardian_special.add_child(_guardian_special_button("수호성 열기",func() -> void:hud.open_growth("guardians"),Vector2(220,48)))

func _guardian_special_button(text: String,callback: Callable,extent: Vector2=Vector2(220,44)) -> Button:
	var button: Button=UI.button(text,callback,extent)
	button.clip_text=true;button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;button.tooltip_text=text
	button.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
	button.scroll_host=hud.workspace;button.scroll_area=guardian_special_scroll
	return button

func _show_source_learning()->bool:
	var source_status: Dictionary=hud.get_parent().original_skills.catalog.source_learning_status(selected)
	if source_status.is_empty():return false
	preview_vfx.clear();preview_container.hide();summon_controls.hide()
	learn_button.disabled=true;book_button.disabled=true;use_button.disabled=true;quick_button.disabled=true;preview_button.disabled=true
	use_button.text="실행 대기"
	learn_button.tooltip_text="원본 학습 기록이 저장되어 있습니다."
	book_button.tooltip_text=learn_button.tooltip_text
	use_button.tooltip_text=str(source_status.message);quick_button.tooltip_text=str(source_status.message)
	detail.text="[font_size=20]"+str(selected.name)+"[/font_size]\n원본 학습 완료 · 주문 #"+str(int(source_status.spell_class_id))+"\n\n"+str(source_status.message)+"\n학습 기록과 사용한 책의 출처는 저장됩니다. 실행·자동 사용·퀵슬롯 등록은 연결 확인 전까지 보류됩니다."
	cooldown.text="원본 학습 기록 보관 · 실행 대기"
	selection_sheet.show_skill()
	return true
