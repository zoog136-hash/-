extends Control
## UI reference: Korean LineageM synthesis screen, December 2023 / New Year 2024.
## https://lineagem.plaync.com/board/free/view?articleId=658baca5f6dba273d09ada3a
## https://lineagem-jp.com/guides/lm/guides/beginner_community
## The authoritative Cards.fuse still chooses materials, consumes and rolls.
signal fuse_requested(category: String, grade: String)
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
const RosterChrome=preload("res://scripts/ui/fusion_card_chrome.gd")
const SourceButton=preload("res://scripts/ui/native_touch_button.gd")
const ScrollButton=preload("res://scripts/growth/growth_touch_button.gd")
const SourceList=preload("res://scripts/ui/native_touch_list.gd")
const BACKDROP=preload("res://assets/ui/fusion_background_painted.png")
const MATERIAL_GRADES: Array[String]=["일반","고급","희귀","영웅","전설","신화"]
var catalog: Dictionary={}
var collection: Dictionary={}
var category: String="변신"
var grade: String="고급"
var filter_grade: String="전체"
var _built: bool=false
var _tabs: Dictionary={}
var _grade_buttons: Dictionary={}
var _grade_select: OptionButton
var _overall: Label
var _materials: Label
var _cards: ItemList
var _empty: Label
var _fuse: Button
var _note: Label
var _last_result: Label
var _auto: Button
var _body: HBoxContainer
var _left: ScrollContainer
var _roster: VBoxContainer
var _right: VBoxContainer
var _preview: HBoxContainer
var _previews: Array[Control]=[]
var _pity: Label
var _chrome: Control
var _details_scroll: ScrollContainer
var _scroll_host: Node
var _records: Array[Dictionary]=[]
var registered_materials: Array[Dictionary]=[]

func configure(catalog_value: Dictionary, collection_value: Dictionary, initial_category: String) -> void:
 catalog=catalog_value
 collection=collection_value.duplicate(true)
 _build()
 set_category(initial_category)

func set_collection_state(value: Dictionary) -> void:
 collection=value.duplicate(true)
 _refresh()

func set_category(value: String) -> void:
 if not Cards.CATEGORIES.has(value):return
 category=value
 _last_result.text=""
 _refresh()

func set_result(category_name: String, value: String) -> void:
 if category_name==category and is_instance_valid(_last_result):_last_result.text=value

func _plate(fill: Color, rim: Color) -> StyleBoxFlat:
 var style:=UI.box(fill,rim,5)
 style.shadow_size=0
 return style

func _touch(text: String, callback: Callable, blue: bool=false, scrollable: bool=false) -> Button:
 var button: Button=ScrollButton.new() if scrollable else SourceButton.new()
 button.text=text
 button.custom_minimum_size=Vector2(0,48)
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button.add_theme_font_size_override("font_size",17)
 button.add_theme_stylebox_override("normal",_plate(Color("203b57") if blue else Color("5b4720"),Color("536d86") if blue else Color("96773e")))
 button.add_theme_stylebox_override("hover",_plate(Color("31526e") if blue else Color("755c29"),Color("b1b6ac")))
 button.add_theme_stylebox_override("pressed",_plate(Color("142a3f") if blue else Color("3c2c12"),Color("c9b77e")))
 button.add_theme_stylebox_override("disabled",_plate(Color("13191f"),Color("353b40")))
 button.pressed.connect(callback)
 return button

func _build() -> void:
 if _built:return
 _built=true
 name="CardFusionView"
 var surface:=TextureRect.new()
 surface.texture=BACKDROP
 surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 surface.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
 surface.modulate=Color(.24,.30,.36,1)
 add_child(surface);surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column:=VBoxContainer.new()
 add_child(column);column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 column.add_theme_constant_override("separation",8)
 var header:=HBoxContainer.new()
 header.name="CardFusionCategoryTabs"
 column.add_child(header)
 for key: String in Cards.CATEGORIES:
  var chosen: String=key
  var button:=_touch(key,func() -> void:set_category(chosen))
  button.name="FusionCategory"+key
  button.toggle_mode=true
  button.custom_minimum_size=Vector2(110,38)
  button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
  for state: String in ["normal","hover","pressed","hover_pressed"]:
   var selected: bool=state in ["pressed","hover_pressed"]
   var style:=_plate(Color(.07,.10,.13,.7 if selected else .2),Color("a79467") if selected else Color(.25,.3,.33,.3))
   style.border_width_left=0;style.border_width_right=0;style.border_width_top=0
   style.border_width_bottom=2 if selected else 1
   button.add_theme_stylebox_override(state,style)
  header.add_child(button);_tabs[key]=button
 var space:=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(space)
 var shop:=_touch("상점 바로가기",_open_shop,true)
 shop.custom_minimum_size=Vector2(158,38);shop.size_flags_horizontal=Control.SIZE_SHRINK_END
 shop.icon=load("res://assets/ui/shop.png");header.add_child(shop)
 # Legacy grade signal remains available; visible filters/portraits own input.
 _grade_select=OptionButton.new()
 for current: String in MATERIAL_GRADES:_grade_select.add_item(current+" → "+str(Cards.FUSION_NEXT[current]))
 _grade_select.select(1)
 _grade_select.item_selected.connect(func(index: int) -> void:_select_grade(MATERIAL_GRADES[index],false))
 add_child(_grade_select);_grade_select.hide()
 _body=HBoxContainer.new();_body.name="CardFusionColumns"
 _body.size_flags_vertical=Control.SIZE_EXPAND_FILL;_body.add_theme_constant_override("separation",12);column.add_child(_body)
 _left=ScrollContainer.new();_left.name="CardFusionGradeFilters"
 _left.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 _left.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_left.custom_minimum_size.x=142;_body.add_child(_left)
 var filters:=VBoxContainer.new();filters.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_theme_constant_override("separation",6);_left.add_child(filters)
 var grades: Array[String]=["전체","유일","신화","전설","영웅","희귀","고급","일반"]
 for current: String in grades:
  var chosen: String=current
  var button:=_touch(current,func() -> void:_select_grade(chosen,true),true,true)
  button.name="FusionGrade"+current;button.toggle_mode=true;button.custom_minimum_size.y=66
  button.add_theme_font_size_override("font_size",16)
  button.add_theme_stylebox_override("normal",_plate(Color("192833"),Color("2b3942")))
  var selected:=_plate(Color("2b3a45"),Color("98a6a8"));selected.border_width_left=4
  button.add_theme_stylebox_override("pressed",selected);button.add_theme_stylebox_override("hover_pressed",selected)
  filters.add_child(button);_grade_buttons[current]=button
 _roster=VBoxContainer.new();_roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_roster.size_flags_stretch_ratio=1.0;_body.add_child(_roster)
 _cards=SourceList.new();_cards.name="CardFusionOwnedList"
 _cards.size_flags_vertical=Control.SIZE_EXPAND_FILL;_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _cards.icon_mode=ItemList.ICON_MODE_TOP;_cards.max_columns=4;_cards.same_column_width=true;_cards.max_text_lines=1
 _cards.add_theme_font_size_override("font_size",1)
 _cards.add_theme_constant_override("h_separation",8);_cards.add_theme_constant_override("v_separation",8)
 _cards.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 var selection:=_plate(Color(.9,.8,.54,.06),Color("d6c59a"));selection.set_border_width_all(2)
 _cards.add_theme_stylebox_override("selected",selection);_cards.add_theme_stylebox_override("selected_focus",selection)
 _cards.item_selected.connect(func(index: int) -> void:_select_grade(str((_cards.get_item_metadata(index) as Dictionary).grade),false))
 _roster.add_child(_cards)
 _chrome=RosterChrome.new();_cards.add_child(_chrome);_chrome.configure(_cards)
 _overall=UI.label("",12,Color("c2c9c9"));_overall.name="CardFusionOverall";_roster.add_child(_overall)
 _right=VBoxContainer.new();_right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_right.size_flags_stretch_ratio=1.0;_right.add_theme_constant_override("separation",10);_body.add_child(_right)
 var heading:=HBoxContainer.new();_right.add_child(heading)
 var title:=UI.label("합성",18);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 var chance:=_touch("합성 확률",func() -> void:_note.visible=not _note.visible,true,true)
 chance.name="CardFusionProbability";chance.custom_minimum_size=Vector2(114,34);chance.size_flags_horizontal=Control.SIZE_SHRINK_END
 chance.add_theme_font_size_override("font_size",14);heading.add_child(chance)
 _materials=UI.label("",14);_materials.name="CardFusionMaterialsCount";_materials.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_right.add_child(_materials)
 _preview=HBoxContainer.new();_preview.name="CardFusionRegisteredMaterials";_preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;_preview.add_theme_constant_override("separation",8);_right.add_child(_preview)
 _empty=UI.label("",14,Color("a4adb3"));_empty.name="CardFusionEmpty";_empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_right.add_child(_empty)
 _note=UI.label("",12,Color("c4cccb"));_note.name="CardFusionRule";_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_note.hide();_right.add_child(_note)
 var actions:=HBoxContainer.new();actions.name="CardFusionActions";actions.add_theme_constant_override("separation",10);_right.add_child(actions)
 _auto=_touch("카드 자동 등록",_auto_register,true);_auto.name="CardFusionAutoRegister";actions.add_child(_auto)
 _fuse=_touch("합성",_request);_fuse.name="CardFusionConfirm";actions.add_child(_fuse)
 _last_result=UI.label("",12);_last_result.name="CardFusionResult";_last_result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_right.add_child(_last_result)
 _details_scroll=ScrollContainer.new();_details_scroll.name="CardFusionMaterialScroll"
 _details_scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 _details_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 _details_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var details:=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",10)
 _details_scroll.add_child(details)
 for child: Node in _right.get_children():
  if child!=actions and child!=_last_result:child.reparent(details)
 _right.add_child(_details_scroll);_right.move_child(_details_scroll,0)
 _pity=UI.label("",12,Color("b4bdbb"));_pity.name="CardFusionPity";_pity.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;column.add_child(_pity)
 resized.connect(_fit)
 _cards.resized.connect(_fit)
 var host: Node=get_parent()
 while host!=null:
  if host.has_method("register_scroll_drag"):
   _scroll_host=host
   host.call("register_scroll_drag",_left,_left)
   host.call("register_scroll_drag",_left,filters)
   # The shared cooperative button forwards release before accepting it;
   # plain native buttons can otherwise strand the window's previous finger.
   for button: Control in _grade_buttons.values():
    button.scroll_host=host;button.scroll_area=_left
   chance.scroll_host=host;chance.scroll_area=_details_scroll
   host.call("register_scroll_drag",_details_scroll,_details_scroll)
   _wire_details(details)
   break
  host=host.get_parent()

func _fit() -> void:
 if not _built:return
 var width: float=maxf(46,floorf((_cards.size.x-72)/4.0))
 _cards.fixed_icon_size=Vector2i(int(width),int(width*1.25))
 _cards.fixed_column_width=int(width)+4
 _chrome.refresh()
 var screen_scale: float=maxf(.5,get_global_transform_with_canvas().y.length()*get_viewport().get_screen_transform().y.length())
 _fuse.custom_minimum_size.y=ceilf(44.0/screen_scale)
 _auto.custom_minimum_size.y=_fuse.custom_minimum_size.y
 for preview: Control in _previews:
  var extent: float=minf(100,(_right.size.x-32)/4.0)
  extent=minf(extent,maxf(60,size.y-235)*.74)
  preview.custom_minimum_size=Vector2(extent,0)
  (preview.get_child(0) as Control).custom_minimum_size.y=extent/.74

func _select_grade(value: String, filter: bool) -> void:
 var scroll: float=_cards.get_v_scroll_bar().value
 if filter:filter_grade=value
 if value!="전체":grade=value
 if MATERIAL_GRADES.has(grade):_grade_select.select(MATERIAL_GRADES.find(grade))
 _refresh()
 if not filter:_cards.get_v_scroll_bar().set_deferred("value",scroll)

func _available(current: String) -> int:
 var total: int=0
 var seen: Dictionary={}
 var extras: Dictionary=collection.get("spare",{}).get(category,{})
 for raw: Variant in catalog.get(category,[]):
  if not raw is Dictionary:continue
  var record: Dictionary=raw
  var identity: String=Cards.card_id(record)
  if str(record.get("grade",""))==current and not seen.has(identity):
   seen[identity]=true;total+=maxi(0,int(extras.get(identity,0)))
 return total

func _refresh() -> void:
 if not _built:return
 for key: String in _tabs:(_tabs[key] as Button).button_pressed=key==category
 var owned: Dictionary=collection.get("owned",{}).get(category,{})
 var spare: Dictionary=collection.get("spare",{}).get(category,{})
 var total: int=0
 for identity: String in spare:total+=maxi(0,int(spare[identity]))
 _overall.text="보유 %d종 · 총 %d장 · 중복 %d장" % [owned.size(),owned.size()+total,total]
 _records.clear()
 var seen: Dictionary={}
 var source_exists: bool=false
 var target_exists: bool=false
 var required: int=int(Cards.FUSION_MATERIALS.get(grade,0))
 var target: String=str(Cards.FUSION_NEXT.get(grade,""))
 registered_materials.clear()
 var remaining: int=required
 for raw: Variant in catalog.get(category,[]):
  if not raw is Dictionary:continue
  var row: Dictionary=raw;var identity: String=Cards.card_id(row)
  if identity.is_empty() or seen.has(identity):continue
  seen[identity]=true
  var current: String=str(row.get("grade",""))
  if current==target:target_exists=true
  if current==grade:
   source_exists=true
   var used: int=mini(remaining,maxi(0,int(spare.get(identity,0))))
   if used>0:registered_materials.append({"id":identity,"record":row,"count":used});remaining-=used
  var copies: int=(1 if owned.has(identity) else 0)+maxi(0,int(spare.get(identity,0)))
  if copies>0 and (filter_grade=="전체" or current==filter_grade):_records.append(row)
 _records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return Cards.GRADES.find(str(a.grade))>Cards.GRADES.find(str(b.grade)))
 _cards.clear()
 for record: Dictionary in _records:
  var identity: String=Cards.card_id(record)
  var duplicates: int=maxi(0,int(spare.get(identity,0)))
  var copies: int=(1 if owned.has(identity) else 0)+duplicates
  var path: String=str(record.get("image_path",""))
  var picture: Texture2D=load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
  var index: int=_cards.add_item(str(duplicates),picture)
  _cards.set_item_metadata(index,{"id":identity,"grade":str(record.grade),"copies":copies,"duplicates":duplicates})
  _cards.set_item_tooltip(index,"%s · %s · 보유 %d장 / 합성 재료 %d장" % [record.name,record.grade,copies,duplicates])
  _cards.set_item_custom_bg_color(index,Color(UI.grade(str(record.grade)),.09))
  _cards.set_item_custom_fg_color(index,Color(1,1,1,0))
 for current: String in _grade_buttons:
  var button: Button=_grade_buttons[current]
  button.text="%s\n(%d)" % [current,total if current=="전체" else _available(current)]
  button.button_pressed=filter_grade==current
 var available: int=_available(grade)
 var probability: float=float(Cards.FUSION_WEIGHTS.get(grade,0))/100.0
 _materials.text="%s → %s · 중복 카드 %d / %d장" % [grade,target,available,required] if required>0 else "유일 등급은 합성할 수 없습니다"
 _note.text="현재 게임 합성 성공률 %.2f%%\n처음 획득한 카드 1장은 영구 보관되며 중복만 소비됩니다." % probability
 _fuse.disabled=required==0 or available<required or not target_exists or not source_exists
 _fuse.text="합성"
 _fuse.tooltip_text=_materials.text+" · 성공률 %.2f%%" % probability
 _empty.visible=available<required or not source_exists
 _empty.text="같은 등급의 중복 카드 %d장이 더 필요합니다." % maxi(0,required-available) if required>0 else "다른 등급의 카드를 선택해 주세요."
 _refresh_previews()
 var pity: Dictionary=collection.get("pity",{}).get(category,{})
 _pity.text="합성 시도 보상   희귀 %d/%d   영웅 %d/%d" % [int(pity.get("희귀",0)),Cards.PITY_LIMIT,int(pity.get("영웅",0)),Cards.PITY_LIMIT]
 _fit()

func _refresh_previews() -> void:
 for child: Node in _preview.get_children():_preview.remove_child(child);child.queue_free()
 _previews.clear()
 for entry: Dictionary in registered_materials:
  var cell:=VBoxContainer.new();cell.add_theme_constant_override("separation",3);_preview.add_child(cell);_previews.append(cell)
  var record: Dictionary=entry.record
  var art:=Control.new();art.custom_minimum_size=Vector2(0,142);cell.add_child(art)
  var portrait:=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  var path: String=str(record.get("image_path",""))
  if not path.is_empty() and ResourceLoader.exists(path):portrait.texture=load(path)
  art.add_child(portrait);portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  var aura:=Control.new();aura.mouse_filter=Control.MOUSE_FILTER_IGNORE
  aura.material=Chrome.material_for(maxi(0,Cards.GRADES.find(str(record.grade))),true,true)
  art.add_child(aura);aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  aura.draw.connect(func() -> void:aura.draw_rect(Rect2(Vector2.ZERO,aura.size),Color.WHITE))
  aura.resized.connect(aura.queue_redraw)
  var frame:=TextureRect.new();frame.texture=Chrome.texture_for(maxi(0,Cards.GRADES.find(str(record.grade))));frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;frame.stretch_mode=TextureRect.STRETCH_SCALE;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
  art.add_child(frame);frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  frame.material=Chrome.material_for(maxi(0,Cards.GRADES.find(str(record.grade))),false,true)
  var amount:=UI.label(str(entry.count),16);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
  amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.add_child(amount);amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  cell.tooltip_text=str(record.name)+" · "+str(entry.id)+" · 합성에 사용될 중복 "+str(entry.count)+"장"
 if registered_materials.is_empty():
  var message:=UI.label("왼쪽 카드를 선택해 주세요.",14,Color("929fa7"));message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_preview.add_child(message)
 _wire_details(_preview)

func _wire_details(node: Node) -> void:
 if not is_instance_valid(_scroll_host):return
 if node is Control and not node.get_meta("fusion_scroll_wired",false):
  _scroll_host.call("register_scroll_drag",_details_scroll,node)
  node.set_meta("fusion_scroll_wired",true)
 for child: Node in node.get_children():_wire_details(child)

func _auto_register() -> void:
 if not _fuse.disabled:_refresh();return
 for current: String in MATERIAL_GRADES:
  if _available(current)>=int(Cards.FUSION_MATERIALS[current]):
   grade=current;filter_grade="전체";_grade_select.select(MATERIAL_GRADES.find(current));_refresh();return

func _open_shop() -> void:
 var host: Node=get_parent()
 while host!=null:
  if host.has_method("open_shop"):host.call("open_shop");return
  host=host.get_parent()

func _request() -> void:
 if not _fuse.disabled and Cards.CATEGORIES.has(category) and Cards.FUSION_NEXT.has(grade):fuse_requested.emit(category,grade)
