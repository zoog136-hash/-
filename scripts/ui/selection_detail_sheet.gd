extends VBoxContainer

# Inspected reference: official LineageM menu/UI guide and the live Light
# detail capture at https://www.inven.co.kr/board/lineagem/5056/3048 .
# Reference values are not imported into gameplay.
# Presentation only. The owning shop/skill view retains every transaction,
# selected ID, quantity limit, readiness decision and effect implementation.
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
var owner_view: Node
var picture: TextureRect
var title: Label
var category: Label
var source: RichTextLabel
var scroll: ScrollContainer
var total: Label
var raw_skill_text: String=""
var info_text: String=""
var info_tab: Button
var source_tab: Button
var source_active: bool=false

func _hero() -> HBoxContainer:
	var surface:=PanelContainer.new()
	surface.add_theme_stylebox_override("panel",Surfaces.inset(7))
	add_child(surface)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	surface.add_child(row)
	var slot:=PanelContainer.new()
	slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel",UI.slot_recess())
	row.add_child(slot)
	picture=TextureRect.new()
	picture.name="SelectionPicture"
	picture.custom_minimum_size=Vector2(56,56)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	slot.add_child(picture)
	var words:=VBoxContainer.new()
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(words)
	title=UI.label("",17)
	title.name="SelectionTitle"
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	category=UI.label("",12,UI.MUTED)
	category.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words.add_child(category)
	return row

func _scroller(parent: Control) -> void:
	scroll=ScrollContainer.new()
	scroll.name="SelectionInformationScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	source.reparent(scroll)
	source.fit_content=true
	source.scroll_active=false
	source.custom_minimum_size=Vector2.ZERO
	source.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	source.add_theme_font_size_override("normal_font_size",13)
	owner_view.hud.workspace.register_scroll_drag(scroll,source)

func bind_shop(view: Node,side: VBoxContainer) -> void:
	name="ShopSelectionSheet"
	owner_view=view;source=view.detail
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	side.add_child(self);side.move_child(self,0)
	_hero();_scroller(self)
	var price:=PanelContainer.new()
	price.add_theme_stylebox_override("panel",Surfaces.inset(7))
	side.add_child(price);side.move_child(price,1)
	var line:=HBoxContainer.new();price.add_child(line)
	line.add_child(UI.label("구매 금액",13,UI.MUTED))
	total=UI.label("",16,UI.GOLD)
	total.name="ShopTotalPrice"
	total.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	total.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.add_child(total)
	Surfaces.action(view.purchase)

func _table(rows: Array) -> String:
	var text: String="[table=2]"
	for row: Array in rows:
		text+="[cell expand=1]%s[/cell][cell expand=1][right]%s[/right][/cell]" % [UI.safe(row[0]),UI.safe(row[1])]
	return text+"[/table]"

func show_shop(item_name: String,record: Dictionary,quantity: int,price: int,owned: int,wallet: int) -> void:
	picture.texture=UI.item_icon(record,item_name,owner_view.hud.item_image_index.get("아이템",{}))
	title.text=item_name
	title.add_theme_color_override("font_color",UI.grade(str(record.get("grade","일반"))))
	category.text=str(owner_view.selected[2])+" · 보유 "+UI.number_text(owned)+"개"
	var description: String=str(record.get("desc",record.get("description","")))
	source.text=UI.safe(description)+("\n\n" if not description.is_empty() else "")
	source.text+="[b]"+UI.safe(item_name)+" · 구매 정보[/b]\n"+_table([["판매 단가",UI.number_text(price)+" 아데나"],["선택 수량",UI.number_text(quantity)+"개"],["합계",UI.number_text(maxi(0,price)*quantity)+" 아데나"],["보유 아데나",UI.number_text(wallet)]])
	if not owner_view.selected_vendor_id.is_empty():source.text+="\n기본 판매가 · 강화 +0 · 세금 없음"
	total.text=UI.number_text(price*quantity)+" 아데나" if price>0 else "구매 불가"

func clear_shop() -> void:
	picture.texture=null;title.text="상품을 선택하세요";category.text=""
	total.text="—"
	scroll.scroll_vertical=0

func bind_skill(view: Node,old_scroll: ScrollContainer,side: VBoxContainer) -> Control:
	name="SkillSelectionSheet"
	owner_view=view;source=view.detail
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	old_scroll.get_parent().add_child(self)
	var hero: HBoxContainer=_hero()
	view.preview_button.reparent(hero)
	view.preview_button.text="미리보기"
	view.preview_button.custom_minimum_size=Vector2(72,32)
	view.preview_button.add_theme_font_size_override("font_size",12)
	var controls:=VBoxContainer.new()
	hero.add_child(controls)
	view.preview_button.reparent(controls)
	var toggle: Button=UI.button("습득 · 출처",func() -> void:_switch_skill_tab(not source_active),Vector2(84,32))
	toggle.add_theme_font_size_override("font_size",12)
	toggle.toggle_mode=true
	controls.add_child(toggle)
	info_tab=toggle;source_tab=toggle
	picture.custom_minimum_size=Vector2(40,40)
	view.preview_button.custom_minimum_size=Vector2(84,32)
	old_scroll.reparent(self)
	scroll=old_scroll
	(side.get_child(0) as Control).hide()
	var surface: Control=hero.get_parent()
	surface.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	surface.reparent(side);side.move_child(surface,0)
	view.hud.workspace.register_scroll_drag(scroll,surface)
	for button: Button in [source_tab,view.preview_button]:view.hud.workspace.register_scroll_drag(scroll,button)
	source.fit_content=true;source.scroll_active=false;source.custom_minimum_size=Vector2.ZERO
	view.hud.workspace.register_scroll_drag(scroll,source)
	view.cooldown.reparent(self)
	var actions: Control=view.learn_button.get_parent()
	actions.reparent(self)
	view.summon_controls.reparent(self)
	visibility_changed.connect(_fit_skill_chrome)
	resized.connect(_fit_skill_chrome)
	call_deferred("_fit_skill_chrome")
	return self

func _fit_skill_chrome() -> void:
	if not is_instance_valid(owner_view) or not is_instance_valid(owner_view.search):return
	var compact_detail: bool=is_visible_in_tree() and owner_view.size.x<660
	var filters: Control=owner_view.find_child("SkillFiltersToggle",true,false)
	filters.visible=not compact_detail or owner_view.search.get_parent().visible
	var scope: Control=owner_view.find_child("SkillReferenceTabs",true,false)
	if scope!=null:scope.visible=not compact_detail
	for child: Node in owner_view.get_children():
		if child is Label and child.text.begins_with("Lv."):child.visible=not compact_detail

func show_skill() -> void:
	var selected: Dictionary=owner_view.selected
	if selected.is_empty():
		picture.texture=null;title.text="선택한 스킬 없음";category.text=""
		info_text=source.text;raw_skill_text=source.text
		_show_skill_tab();return
	raw_skill_text=source.text
	var identity: String=str(selected.get("id",selected.get("name","")))
	picture.texture=null
	for index: int in range(owner_view.filtered.size()):
		var record: Dictionary=owner_view.filtered[index]
		if str(record.get("id",record.get("name","")))==identity:
			picture.texture=owner_view.cards.get_item_icon(index)
			break
	title.text=str(selected.get("name",""))
	title.add_theme_color_override("font_color",UI.grade(str(selected.get("grade","일반"))))
	category.text=str(selected.get("class",""))+" · "+str(selected.get("grade","일반"))+" · "+("패시브" if owner_view.RULES.is_passive(selected) else "액티브")
	info_text=raw_skill_text
	var original: bool=selected.get("origin","")=="LINEAGEM_20250617"
	var learned: bool=false
	if original:
		var world: Node=owner_view.hud.get_parent()
		var skill: Dictionary=world.original_skills.catalog.resolve(selected)
		learned=world.original_skills.catalog.owned(selected)
		category.text+=" · "+("습득 완료" if learned else "미습득")
		var rows: Array=[]
		if not owner_view.RULES.is_passive(selected):
			rows=[["소모 MP / HP","%d / %d" % [int(skill.get("mp",0)),int(skill.get("hp",0))]],["재사용","%.1f초" % (float(skill.get("cooldown",0))*world._skill_cooldown_factor())],["지속시간","%.1f초" % float(skill.get("duration",0))]]
		rows.append(["사용 무기","제한 없음" if skill.get("weapons",[]).is_empty() else " · ".join(skill.weapons)])
		info_text=_table(rows)+"\n\n[b]효과[/b]\n"+UI.safe(selected.get("desc",""))+"\n\n"+("습득 완료" if learned else UI.safe(world.original_skills.catalog.reason(selected)))
	owner_view.use_button.text="패시브" if owner_view.RULES.is_passive(selected) else "스킬 사용"
	owner_view.learn_button.visible=original and not learned
	owner_view.book_button.visible=original and not learned
	owner_view.use_button.visible=not original or learned
	owner_view.quick_button.visible=not original or learned
	_show_skill_tab()

func _switch_skill_tab(show_source: bool) -> void:
	if owner_view.hud.workspace.was_scroll_dragged(scroll):return
	source_active=show_source
	_show_skill_tab()

func _show_skill_tab() -> void:
	source_tab.set_pressed_no_signal(source_active)
	source_tab.text="사용 정보" if source_active else "습득 · 출처"
	source.text=raw_skill_text if source_active else info_text
	scroll.scroll_vertical=0
