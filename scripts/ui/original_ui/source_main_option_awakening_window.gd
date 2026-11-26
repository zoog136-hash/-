extends "res://scripts/ui/original_ui/source_main_change_page.gd"
## Original, shared 변신/마법인형 option-awakening page. All prices, experience,
## cards, eligibility, RNG and persistence come from the existing World owner.
## Registered material is a UI-only selection; a separate review is mandatory.
const ROOT="UI/Change/Change_Awaken_All.csb"
const OPTION="UI/Change/Change_Awaken_Option.csb"
const EMPTY="UI/Change/Change_Card_A_Empty.csb"
const AMOUNT="UI/Change/Change_Card_A_Amount.csb"
const ROOT_SHA="1a790cb7a91c8eac69562dd904bc82c9bb52fe4ab7a8ab2c2202ea16b01d2836"
const OPTION_SHA="07b1c4d81d3598b929e30db5857628131b1ec71c8df659db7d613508a50a87f5"
const P="Nd_Awaken_Option/"
const LEVEL=P+"Nd_LevelUp/"
const OUTSIDE=P+"Nd_List_Card/"
const RIGHT=OUTSIDE+"ListView_Swipe"
const PICKED=LEVEL+"ListView_Material"
const BONUS=LEVEL+"Nd_ChangeAwakenOption/ListView"
const BONUS_LIST_OFFSET: int=40112
const BONUS_TEXT_OFFSET: int=40164
const BONUS_MARKER_OFFSET: int=40212
const BONUS_ROW_PITCH: float=18.0
const PRIMARY=LEVEL+"Btn_Production"
const PAGE_SIZE=9
var _snapshot: Dictionary={}
var _materials: Dictionary={}
var _selected: Dictionary={}
var _shown: Array[String]=[]
var _filter: String="전체"
var _page_index: int=0
var _dialog: WeakRef
var _epoch: int=0
var _candidate_views: Dictionary={}
var _registered_views: Dictionary={}

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,OPTION,EMPTY,AMOUNT,GRADE_ROW]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	return members

func _root_member() -> String:
	return ROOT

func configure(pack: RefCounted, host: Node) -> Dictionary:
	# An absent authored scene is the kit's unavailable path, not a bad
	# identity. Do that check without binding a complete but untrusted pack.
	var scenes: Dictionary=pack.manifest.get("scenes",{})
	for member: String in required_members():
		if not scenes.has(member):return super.configure(pack,host)
	var files: Dictionary=pack.manifest.get("files",{})
	if files.get(ROOT,{}).get("sha256")!=ROOT_SHA or files.get(OPTION,{}).get("sha256")!=OPTION_SHA:
		return _fail("source_option_awakening_identity_mismatch")
	return super.configure(pack,host)

func open(parent: Node, snapshot: Dictionary) -> Dictionary:
	if not _supports(snapshot):return _fail("source_option_awakening_target_unsupported")
	_reset_selection()
	_scrolls.erase(BONUS)
	category=str(snapshot.category)
	_publish(snapshot)
	return open_window(parent)

func _supports(snapshot: Dictionary) -> bool:
	return snapshot.get("ok",false) and snapshot.get("category") in ["변신","마법인형"] and not str(snapshot.get("target_id","")).is_empty() and GRADE_MEMBERS.has(str(snapshot.get("target_record",{}).get("grade","")))

func apply_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _supports(snapshot) or snapshot.get("category")!=category or snapshot.get("target_id")!=_snapshot.get("target_id"):
		return _fail("source_option_awakening_target_changed")
	_epoch+=1
	cancel_review()
	if snapshot.get("revision")!=_snapshot.get("revision"):_selected.clear()
	_publish(snapshot)
	return _stage()

func _publish(snapshot: Dictionary) -> void:
	_snapshot=snapshot
	_materials.clear()
	for row: Dictionary in snapshot.get("materials",[]):
		if GRADE_MEMBERS.has(str(row.get("record",{}).get("grade",""))) and int(row.get("spare",0))>0 and int(row.get("experience_per_card",0))>0:
			_materials[str(row.id)]=row
	for id: String in _selected.keys():
		if int(_selected[id])>int(_materials.get(id,{}).get("spare",0)):_selected.erase(id)

func _reset_selection() -> void:
	_epoch+=1
	cancel_review()
	_selected.clear()
	_filter="전체"
	_page_index=0

func close() -> void:
	_reset_selection()
	_candidate_views.clear()
	_registered_views.clear()
	super.close()

func cancel_review() -> bool:
	var dialog: Variant=_dialog.get_ref() if _dialog!=null else null
	_dialog=null
	if not is_instance_valid(dialog) or dialog.is_queued_for_deletion() or not dialog.visible:return false
	dialog.dismiss()
	return true

func review_open() -> bool:
	var dialog: Variant=_dialog.get_ref() if _dialog!=null else null
	return is_instance_valid(dialog) and not dialog.is_queued_for_deletion() and dialog.visible

func _query() -> Array[String]:
	var out: Array[String]=[]
	for id: String in _materials:
		if _filter=="전체" or _filter==str(_materials[id].record.grade):out.append(id)
	return out

func _fee() -> int:
	var value: int=0
	for id: String in _selected:value+=int(_selected[id])*int(_materials[id].get("cost_per_card",0))
	return value

func _gained() -> int:
	var value: int=0
	for id: String in _selected:value+=int(_selected[id])*int(_materials[id].experience_per_card)
	return value

func _remaining() -> int:
	return maxi(0,int(_snapshot.required_experience)-int(_snapshot.experience))

func _experience_percent(units: int) -> float:
	return 100.0*float(units)/float(maxi(1,int(_snapshot.required_experience)))

func _attempt_mode() -> bool:
	return _remaining()==0

func _can_register() -> bool:
	return bool(_snapshot.get("can_feed",false)) and _remaining()>0

func _can_submit() -> bool:
	if _attempt_mode():return bool(_snapshot.get("can_awaken",false))
	return _can_register() and not _selected.is_empty() and _fee()<=int(_snapshot.gold)

func _spec() -> Dictionary:
	_shown=_query()
	var pages: int=maxi(1,ceili(float(_shown.size())/float(PAGE_SIZE)))
	_page_index=clampi(_page_index,0,pages-1)
	var attempted: bool=_attempt_mode()
	var current: int=int(_snapshot.experience)
	var after: int=current+mini(_remaining(),_gained())
	var was_awakened: bool=bool(_snapshot.get("awakened",false))
	var title: String=str(_snapshot.target_record.get("name",""))
	var tip: String=str(_snapshot.get("blocked_reason",""))
	if tip.is_empty():
		if was_awakened:tip="이미 옵션 각성한 카드입니다."
		elif not _snapshot.get("owned",false):tip="먼저 대상 카드를 획득하세요."
		else:tip="등록한 중복 카드만 소모됩니다. 최초 획득 카드는 보존됩니다."
	var spec: Dictionary={"Change_Awaken_Skill":{"exclude":true},"Change_Awaken_SkillExp":{"exclude":true},
		"Nd_Awaken_Tab_2":{"exclude":true},"Nd_Awaken_Tab_1/Btn_Option_On":{"activate":Callable(self,"_ignore")},
		"Nd_Awaken_Tab_1/Btn_Skill_Off":{"visible":true, "activate":Callable(self, "_open_skill")},"Nd_Awaken_Tab_1/Btn_Skill_On":{"exclude":true},
		"Nd_Awaken_Tab_1/Btn_Exp_Off":{"exclude":true},"Nd_Awaken_Tab_1/Btn_Exp_On":{"exclude":true},
		"Btn_Close":{"activate":Callable(self,"_close_requested")},
		"Nd_Awaken_Clear":{"exclude":true},"CardChange_Popup_CollectionView":{"exclude":true},
		"Nd_Bg/Fx_Img_BG_Particle":{"exclude":true},"Fx_Start":{"exclude":true},"Fx_Soul":{"exclude":true},
		"Fx_Result":{"exclude":true},"Fx_Awaken":{"exclude":true},"Fx_Whitescreen_0":{"exclude":true},
		"Particle_9_0":{"exclude":true},"Sprite_81":{"exclude":true},
		"Nd_Content/Btn_Back":{"activate":Callable(self,"_back")},
		"Nd_Fail_History/Btn_History":{"activate":Callable(self,"_history")},
		P+"Btn_HelpBox":{"activate":Callable(self,"_explain")},
		P+"Label_Tip":_text(tip),
		LEVEL+"Label_Title":_text(title),
		LEVEL+"ProgressBar_Exp":{"role":"source_percent","percent":_experience_percent(current)},
		LEVEL+"Panel_Exp_Before/Label_Exp_0":_text("%.4f%%" % _experience_percent(current)),
		LEVEL+"Panel_Exp_After/Label_Exp_0":_text("%.4f%%" % _experience_percent(after)),
		LEVEL+"Panel_Exp_After/Label_Level":{"visible":false},
		LEVEL+"Panel_Exp_After/Fx_Levelup":{"exclude":true},
		LEVEL+"Label_Skill_Percent":_text("성공 확률 %.2f%%" % float(_snapshot.success_chance_pct)),
		LEVEL+"Nd_Exp_Retrieval":{"visible":attempted and not was_awakened},
		LEVEL+"Nd_Exp_Retrieval/Label_Exp_Retrieval_Percent":_text("실패 시 %.4f%% 유지" % _experience_percent(int(_snapshot.failure_refund_experience))),
		LEVEL+"Nd_Exp_Retrieval/Label_Notice":{"visible":false},
		LEVEL+"Nd_Card/Card/Panel_Root/Btn_Plus":{"exclude":true},
		LEVEL+"Fx_CardSelect_Material":{"exclude":true},
		LEVEL+"Fx_Btn_Production":{"exclude":true},
		LEVEL+"Btn_Probability":{"activate":Callable(self,"_explain")},
		BONUS:{"row_offsets":[],"input":Callable(self,"_list_input").bind(BONUS)},BONUS+"/Label_Option":{"exclude":true},
		PRIMARY:{"activate":Callable(self,"_review"),"displaystate":_can_submit()},
		PRIMARY+"/Text_Price":_text(_number(int(_snapshot.attempt_cost) if attempted else _fee())),
		PRIMARY+"/Normal/Label":_text("각성 시도" if attempted else "경험치 주입"),
		PRIMARY+"/Disabled/Label":_text("각성 시도" if attempted else "경험치 주입"),
		OUTSIDE+"Btn_Prev":{"activate":Callable(self,"_paginate").bind(-1),"displaystate":_page_index>0},
		OUTSIDE+"Btn_Next":{"activate":Callable(self,"_paginate").bind(1),"displaystate":_page_index+1<pages},
		OUTSIDE+"Label_PageInfo":_text("%d / %d" % [_page_index+1,pages]),
		OUTSIDE+"Btn_Use_All":{"activate":Callable(self,"_auto_register"),"displaystate":_can_register() and not _shown.is_empty()},
		OUTSIDE+"Btn_Cancel_All":{"activate":Callable(self,"_clear_selection"),"displaystate":not _selected.is_empty()},
		OUTSIDE+"Label_Title":_text(category+" 카드"),
		OUTSIDE+"Nd_Notice":{"visible":_shown.is_empty()},
		OUTSIDE+"Fx_CardSelect":{"exclude":true}}
	return spec

static func _text(value: String) -> Dictionary:
	return {"role":"source_text","text":value}

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var classes: Array=[]
	for grade: String in SIDEBAR:
		var amount: int=0
		for id: String in _materials:
			if grade=="전체" or _materials[id].record.grade==grade:amount+=int(_materials[id].spare)
		classes.append(_grade_row(grade,"(%s)" % _number(amount),grade==_filter,Callable(self,"_select_filter").bind(grade)))
	var menu: Dictionary=_fill_list(root,out,P+"ListView_Class",classes)
	if not menu.get("ok",false):return menu
	var page: Array=[]
	for index: int in range(_page_index*PAGE_SIZE,mini(_shown.size(),(_page_index+1)*PAGE_SIZE)):
		var id: String=_shown[index]
		page.append(_material_row(id,false))
	var groups: Array=[]
	for row: int in range(3):
		var cards: Array=page.slice(row*3,row*3+3)
		var candidates: Dictionary=_fill_list(root,out,RIGHT+"/ListView_%d" % (row+1),cards,2.0,false,3)
		if not candidates.get("ok",false):return candidates
		groups.append([candidates,cards])
	var registered: Array=[]
	for id: String in _selected:registered.append(_material_row(id,true))
	var picked: Dictionary=_fill_list(root,out,PICKED,registered,4.0,true)
	if not picked.get("ok",false):return picked
	var title_card: Dictionary=_card_row(_snapshot.target_record,false,Callable())
	title_card.spec["Panel_Root/CB_Check"]={"exclude":true}
	var target_out: Dictionary={}
	var art: Dictionary=_scene_of(title_card.member,title_card.spec,target_out)
	if not art.get("ok",false):return art
	var home: Dictionary=_locate(root,out,LEVEL+"Nd_Card/Card")
	if not home.get("ok",false):
		art.scene.free()
		return home
	var anchor: Node2D=home.player.source_nodes.get(home.offset)
	anchor.add_child(art.scene)
	var picture: bool=_card_picture(art.scene,target_out,_snapshot.target_record)
	var painted: int=0
	var candidates_next: Dictionary={}
	var registered_next: Dictionary={}
	groups.append([picked,registered])
	for group: Array in groups:
		for i: int in range(group[1].size()):
			var row: Dictionary=group[1][i]
			var built: Dictionary=_decorate_material(group[0].scenes[i],group[0].outs[i],row)
			if not built.get("ok",false):return built
			if built.picture:painted+=1
			var entries: Dictionary=registered_next if row.registered else candidates_next
			entries[row.id]=built
	var options: Dictionary=_fill_bonus_options(root,out)
	if not options.get("ok",false):return options
	_candidate_views=candidates_next
	_registered_views=registered_next
	return {"ok":true,"category":category,"target_id":_snapshot.target_id,"target_picture":picture,
		"material_pictures":painted,"eligible":_materials.size(),"page_slots":page.size(),"registered":_selected.duplicate(),
		"cost":int(_snapshot.attempt_cost) if _attempt_mode() else _fee(),"options_shown":options.rows}

func _fill_bonus_options(root: Node2D, out: Dictionary) -> Dictionary:
	var list: Dictionary=_list(root,out,BONUS)
	if not list.get("ok",false):return list
	var lines: Array=[]
	lines.append_array(_snapshot.get("bonus_options",[]))
	if category=="마법인형":
		for slot: Dictionary in _snapshot.get("slot_definitions",[]):
			if int(slot.get("group",{}).get("SlotIndex",0))!=11:continue
			lines.append("추가 인형 슬롯 각성 효과")
			lines.append_array(slot.get("labels",[]))
	if lines.is_empty():lines.append("확인된 각성 옵션이 없습니다.")
	var scope: Array[int]=[BONUS_TEXT_OFFSET,BONUS_MARKER_OFFSET]
	var bindings: Dictionary={BONUS_LIST_OFFSET:{"role":"source_list","row_offsets":[BONUS_TEXT_OFFSET],"input":Callable(self,"_list_input").bind(BONUS)}}
	for index: int in lines.size():
		bindings[BONUS_TEXT_OFFSET]=_text(str(lines[index]))
		var template:=Scene.new()
		var built: Dictionary=template.configure_nodes(_pack,OPTION,scope,bindings)
		if not built.get("ok",false):
			template.free()
			return built
		var row: Node2D=template.source_nodes[BONUS_TEXT_OFFSET]
		# The template includes the ListView and the entire authoring path
		# above it. Move just the arranged row to the live ListView so that
		# its parent coordinates and clip are applied once.
		row.position.y+=float(index)*BONUS_ROW_PITCH
		row.get_parent().remove_child(row)
		list.content.add_child(row)
		template.free()
	var height: float=(list.size as Vector2).y
	_scrolls[BONUS]={"content":list.content,"value":0.0,"min":minf(0.0,height-float(lines.size())*BONUS_ROW_PITCH)}
	return {"ok":true,"rows":lines.size()}

func _decorate_material(scene: Node2D, out: Dictionary, row: Dictionary) -> Dictionary:
	var picture: bool=_card_picture(scene,out,row.record)
	if not picture:_missing_portrait_name(scene,out,str(row.record.get("name","")))
	scene.set_meta("source_option_material",{"id":row.id,"selected":row.registered})
	var count_out: Dictionary={}
	var count: Dictionary=_scene_of(AMOUNT,_quantity_spec(int(row.amount)),count_out)
	if not count.get("ok",false):return count
	scene.add_child(count.scene)
	return {"ok":true,"scene":scene,"check":_locate(scene,out,"Panel_Root/CB_Check"),
		"count":_locate(count.scene,count_out,"Panel/Text_2"),"picture":picture}

## An inventory tap is only a draft edit. Keep the original shell, grades
## and nine source card rows mounted; refresh labels and just the newly
## added/removed registered card. Transactions still get a fresh snapshot.
func _update_selection() -> Dictionary:
	var list: Dictionary=_list(_scene,_out,PICKED)
	if not list.get("ok",false):return _stage()
	var previous: Variant=_stage_trees
	_stage_trees={}
	var gained: int=_gained()
	for id: String in _candidate_views:
		var view: Dictionary=_candidate_views[id]
		var left: int=int(_materials[id].spare)-int(_selected.get(id,0))
		_set_bound(view.count,"set_bound_text",str(left))
		_set_bound(view.check,"set_bound_displaystate",_can_register() and left>0 and gained<_remaining())
	for id: String in _registered_views.keys():
		if not _selected.has(id):
			var stale: Node2D=_registered_views[id].scene
			stale.hide()
			stale.queue_free()
			_registered_views.erase(id)
	var x: float=0.0
	var size: Vector2=list.size
	var key: String=list.key
	for id: String in _selected:
		var row: Dictionary=_material_row(id,true)
		if not _registered_views.has(id):
			var out: Dictionary={}
			var built: Dictionary=_scene_of(row.member,row.spec,out,key)
			if not built.get("ok",false):
				_stage_trees=previous
				return _stage()
			var added: Dictionary=_decorate_material(built.scene,out,row)
			if not added.get("ok",false):
				built.scene.free()
				_stage_trees=previous
				return _stage()
			_registered_views[id]=added
			built.scene.set_meta(ROW_LIST_META,key)
			_forward_row_drags(built.scene,key,_outer_list_key(_scene))
		var current: Dictionary=_registered_views[id]
		var geometry: Dictionary=_row_geometry(row.member)
		var bottom_left:=Vector2(x,size.y-geometry.size.y)
		if current.scene.get_parent()==null:_place(list.content,current.scene,geometry,bottom_left)
		else:
			var at: Vector2=bottom_left-(geometry.origin as Vector2)
			current.scene.position=Vector2(at.x,-at.y)
		_set_bound(current.count,"set_bound_text",str(row.amount))
		x+=float(geometry.size.x)+4.0
	_stage_trees=previous
	var covered: float=maxf(0.0,x-4.0)
	var saved_offset: float=float(_scrolls.get(key,{}).get("value",0.0))
	_scrolls[key]={"content":list.content,"min":minf(0.0,size.x-covered),"value":0.0,"axis":"x"}
	_scroll_to(key,saved_offset)
	_set_bound(_locate(_scene,_out,LEVEL+"Panel_Exp_After/Label_Exp_0"),"set_bound_text","%.4f%%" % _experience_percent(int(_snapshot.experience)+mini(_remaining(),gained)))
	_set_bound(_locate(_scene,_out,PRIMARY+"/Text_Price"),"set_bound_text",_number(_fee()))
	_set_bound(_locate(_scene,_out,PRIMARY),"set_bound_displaystate",_can_submit())
	_set_bound(_locate(_scene,_out,OUTSIDE+"Btn_Cancel_All"),"set_bound_displaystate",not _selected.is_empty())
	last_result.filled.registered=_selected.duplicate()
	last_result.filled.cost=_fee()
	return last_result

static func _set_bound(hit: Dictionary, method: String, value: Variant) -> void:
	if hit.get("ok",false):hit.player.call(method,hit.offset,value)

func _material_row(id: String, remove: bool) -> Dictionary:
	var row: Dictionary=_materials[id]
	var used: int=int(_selected.get(id,0))
	var choice: Dictionary=_card_row(row.record,false,Callable(self,"_select_material").bind(id,remove))
	choice.spec["Panel_Root/CB_Check"]["displaystate"]=remove or (_can_register() and used<int(row.spare) and _gained()<_remaining())
	choice["id"]=id
	choice["registered"]=remove
	choice["amount"]=used if remove else int(row.spare)-used
	return choice

## The original frame stays in place when a private portrait is unavailable.
## Show the exact card name within its slot; do not make anonymous duplicates
## selectable or substitute a different portrait.
static func _missing_portrait_name(scene: Node2D, out: Dictionary, title: String) -> void:
	var located: Dictionary=_locate(scene,out,"Panel_Root")
	if not located.get("ok",false):return
	var host: Node2D=located.player.source_nodes.get(located.offset)
	var origin: Node=host.get_node_or_null("SourceContentOrigin")
	if origin==null:return
	var name_view:=Label.new()
	name_view.position=Vector2(10,-106)
	name_view.size=Vector2(104,70)
	name_view.text=title
	name_view.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_view.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	name_view.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	name_view.clip_text=true
	name_view.add_theme_font_size_override("font_size",13)
	name_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	origin.add_child(name_view)

static func _quantity_spec(amount: int) -> Dictionary:
	return {"Panel/Img_ChageCard_Amount_Bg_1":{"exclude":true},"Panel/Img_Amount":{"exclude":true},"Panel/Text_1":{"exclude":true},
		"Panel/Text_2":_text(str(amount)),"Panel/Icon_New":{"exclude":true},"Panel/Btn_Book":{"exclude":true},
		"Panel/Change_Card_LevelUp":{"exclude":true},"Panel/Btn_Move":{"exclude":true},"Panel/Nd_Transcend":{"exclude":true}}

func _select_filter(grade: String) -> Dictionary:
	if review_open():return _fail("source_option_awakening_review_open")
	_filter=grade
	_page_index=0
	return _stage()

func _paginate(delta: int) -> Dictionary:
	if review_open():return _fail("source_option_awakening_review_open")
	_page_index+=delta
	return _stage()

func _select_material(_checked: bool, id: String, remove: bool) -> Dictionary:
	if review_open() or _dragged() or not _materials.has(id):return _fail("source_option_awakening_card_ineligible")
	var current: int=int(_selected.get(id,0))
	if remove:
		if current<=1:_selected.erase(id)
		else:_selected[id]=current-1
	elif _can_register() and current<int(_materials[id].spare) and _gained()<_remaining():
		_selected[id]=current+1
	else:return _fail("source_option_awakening_card_ineligible")
	return _update_selection()

func _clear_selection() -> Dictionary:
	if review_open():return _fail("source_option_awakening_review_open")
	_selected.clear()
	return _update_selection()

func _auto_register() -> Dictionary:
	if review_open() or not _can_register():return _fail("source_option_awakening_card_ineligible")
	var remaining: int=maxi(0,_remaining()-_gained())
	var available_gold: int=maxi(0,int(_snapshot.gold)-_fee())
	for id: String in _shown:
		if remaining<=0:break
		var row: Dictionary=_materials[id]
		var current: int=int(_selected.get(id,0))
		var unit: int=int(row.experience_per_card)
		var cost: int=int(row.get("cost_per_card",0))
		var count: int=mini(int(row.spare)-current,ceili(float(remaining)/float(unit)))
		if cost>0:count=mini(count,available_gold/cost)
		if count<=0:continue
		_selected[id]=current+count
		remaining-=count*unit
		available_gold-=count*cost
	return _update_selection()

func _open_skill() -> Dictionary:
	if review_open(): return _fail("source_option_awakening_review_open")
	var owner: Object = hud()
	if not is_instance_valid(owner): return _fail("source_skill_awakening_host_missing")
	owner.open_card_skill_awakening(category, str(_snapshot.target_id))
	return {"ok":true}

func _back() -> Dictionary:
	return _route("open_catalog",[category])

func _history() -> Dictionary:
	var controller: Object=hud().get("original_main_ui_controller")
	if controller==null:return _fail("source_option_awakening_history_unavailable")
	var opened: Dictionary=controller.try_open_overlay_window("fail_history",["Btn_Change_Awaken" if category=="변신" else "Btn_Magic_Awaken"])
	if not opened.get("ok",false):_message("실패 이력 화면을 불러올 수 없습니다.")
	return opened

func _explain() -> Dictionary:
	var text: String="성공 확률 %.2f%% · 각성 시도 %s 아데나\n실패하면 경험치 %.4f%%가 유지됩니다." % [
		float(_snapshot.success_chance_pct),_number(int(_snapshot.attempt_cost)),_experience_percent(int(_snapshot.failure_refund_experience))]
	_message(text)
	return {"ok":true,"probability":_snapshot.success_chance_pct}

func _review() -> Dictionary:
	if review_open() or not _can_submit():return _fail("source_option_awakening_review_unavailable")
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action") or owner.get_node_or_null("Root/TwilightConfirmation")!=null:
		return _fail("source_option_awakening_confirmation_unavailable")
	var attempt: bool=_attempt_mode()
	var frozen: Dictionary={"id":str(_snapshot.target_id),"category":category,"revision":int(_snapshot.revision),"epoch":_epoch,
		"materials":_selected.duplicate(),"terms":_terms(_snapshot,_selected,attempt),"attempt":attempt}
	var body: PackedStringArray=[str(_snapshot.target_record.get("name",""))]
	if attempt:
		body.append("시도 비용 %s 아데나 · 성공 확률 %.2f%%" % [_number(int(_snapshot.attempt_cost)),float(_snapshot.success_chance_pct)])
		body.append("실패해도 비용이 소모되고, 경험치 %.4f%%가 유지됩니다." % _experience_percent(int(_snapshot.failure_refund_experience)))
	else:
		for id: String in frozen.materials:body.append("%s × %d장" % [str(_materials[id].record.name),int(frozen.materials[id])])
		body.append("경험치 %.4f%% → %.4f%% · 비용 %s 아데나" % [_experience_percent(int(_snapshot.experience)),
			_experience_percent(int(_snapshot.experience)+mini(_remaining(),_gained())),_number(_fee())])
		if _gained()>_remaining():body.append("필요량을 넘는 경험치는 사라집니다.")
		body.append("최초 획득 카드는 보존됩니다.")
	var ask: String="confirm_awakening_action" if owner.has_method("confirm_awakening_action") else "confirm_action"
	var dialog: Control=owner.call(ask,"옵션 각성 확인","\n".join(body),"각성 시도" if attempt else "경험치 주입",
		Callable(self,"_confirm").bind(frozen))
	if not is_instance_valid(dialog):return _fail("source_option_awakening_confirmation_unavailable")
	_dialog=weakref(dialog)
	return {"ok":true,"reviewing":true}

static func _terms(snapshot: Dictionary, cards: Dictionary, attempt: bool) -> Dictionary:
	var terms: Dictionary={"exp":snapshot.get("experience"),"required":snapshot.get("required_experience")}
	if attempt:
		terms.merge({"allowed":snapshot.get("can_awaken"),"gold":snapshot.get("attempt_cost"),"chance":snapshot.get("success_chance_pct"),
			"refund":snapshot.get("failure_refund_experience")})
	else:
		terms["allowed"]=snapshot.get("can_feed")
		var remaining: Array=cards.keys()
		var rows: Dictionary={}
		for row: Dictionary in snapshot.get("materials",[]):
			var id: String=str(row.id)
			if cards.has(id) and int(cards[id])<=int(row.spare):
				rows[id]=[int(row.experience_per_card),int(row.get("cost_per_card",0))]
				remaining.erase(id)
		terms["materials"]=rows
		terms["unavailable"]=remaining
	return terms

func _confirm(_count: int, frozen: Dictionary) -> void:
	_dialog=null
	var owner: Object=hud()
	var game: Object=world()
	if owner==null or game==null or not is_open() or frozen.epoch!=_epoch:return
	var attempt: bool=bool(frozen.attempt)
	var latest: Dictionary=game.option_awakening.view(frozen.category,frozen.id)
	if not latest.get("ok",false) or frozen.revision!=int(latest.revision) or frozen.terms!=_terms(latest,frozen.materials,attempt):
		_message("보유 정보가 바뀌었습니다. 다시 확인해 주세요.")
		if latest.get("ok",false):apply_snapshot(latest)
		return
	_epoch+=1
	if attempt:owner.emit_signal("option_awakening_attempt_requested",frozen.category,frozen.id)
	else:owner.emit_signal("option_awakening_feed_requested",frozen.category,frozen.id,frozen.materials)
