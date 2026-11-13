extends RefCounted
## The original 523 사망 복구 window: DeathPenalty_All (frame, 경험치 복구 /
## 아이템 복구 tabs, close) with DeathPenalty_Tab_ExpRecovery and
## DeathPenalty_Tab_ItemRecovery. Every unclaimed loss of the tab is one
## original DeathPenalty_List_ExpRecovery / _ItemRecovery row (newest first):
## its text, remaining time (the 24-hour window on Default, the extension
## window up to 72 hours on Default_Expension), its cost in the selected
## currency (Img_Aden / Img_Gem) and, for an item, the lost item's original
## picture. A row the current currency cannot recover shows Btn_Disabled with
## the service's reason. Free capacity shows DeathPenalty_List_Empty rows and
## one DeathPenalty_List_Lock row offers the slot expansion. The buttons run
## the existing scripts/death/runtime.gd quotes and transactions through the
## HUD's existing confirmation; every rule, cost and save stays there.
## Left empty (no rule here): the grade icon of an experience row
## (Icon_Exp_<grade>), the discount label, the war-zone mark and 상세보기.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const ROOT="UI/FloatingUi/DeathPenalty_All.csb"
const TAB_EXP="UI/FloatingUi/DeathPenalty_Tab_ExpRecovery.csb"
const TAB_ITEM="UI/FloatingUi/DeathPenalty_Tab_ItemRecovery.csb"
const ROW_EXP="UI/FloatingUi/DeathPenalty_List_ExpRecovery.csb"
const ROW_ITEM="UI/FloatingUi/DeathPenalty_List_ItemRecovery.csb"
const ROW_EMPTY="UI/FloatingUi/DeathPenalty_List_Empty.csb"
const ROW_LOCK="UI/FloatingUi/DeathPenalty_List_Lock.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316,15012]}
const REQUIRED: Array[String]=[ROOT,TAB_EXP,TAB_ITEM,ROW_EXP,ROW_ITEM,ROW_EMPTY,ROW_LOCK,SLOT]
const P_EXP="DeathPenalty_Tab_ExpRecovery/"
const P_ITEM="DeathPenalty_Tab_ItemRecovery/"
const DAY: int=86400
const LIMIT: int=259200
const MAX_ROWS: int=60
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _service: Object
var _parent: WeakRef
var _scene: Node2D
var _content: Node2D
var _tab: String="exp"
var _currency: String="adena"
var _selected: String=""
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var last_result: Dictionary={}
var last_action: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_death_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, service: Object) -> Dictionary:
	if not is_instance_valid(parent) or service==null:return _fail("source_death_window_host_unavailable")
	if not bool(service.get("source").get("ready")):return _fail("source_death_window_rules_not_installed")
	_parent=weakref(parent)
	_service=service
	_tab="exp"
	_selected=""
	_scroll=0.0
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func tab() -> String:
	return _tab

func currency() -> String:
	return _currency

## --- Model ------------------------------------------------------------------

## Unclaimed losses of the tab within 72 hours, newest first.
func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var entries: Array=_service.state.records.duplicate()
	entries.reverse()
	for entry: Dictionary in entries:
		if bool(entry.get(_tab+"_claimed",true)):continue
		if _tab=="item" and (entry.get("item",{}) as Dictionary).is_empty():continue
		var age: int=maxi(0,int(_service.now())-int(entry.at))
		if age>=LIMIT:continue
		rows.append({"entry":entry,"age":age,"id":str(entry.id)})
		if rows.size()>=MAX_ROWS:break
	return rows

func _mode_for(row: Dictionary) -> String:
	return "gem" if _currency=="gem" else "adena"

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null or _service==null:return _fail("source_death_window_host_unavailable")
	var rows: Array[Dictionary]=_rows()
	var ids: Array=rows.map(func(r: Dictionary) -> String: return str(r.id))
	if _selected not in ids:_selected=str(rows[0].id) if not rows.is_empty() else ""
	var exp: bool=_tab=="exp"
	var tab_key: String=P_EXP if exp else P_ITEM
	var list_key: String=tab_key+("Nd_ExpRecoveryList/" if exp else "Nd_ItemRecoveryList/")
	var spec: Dictionary={
		"Btn_Close":{"activate":Callable(self,"_close_requested")},
		"Tab/Btn_ExpRecovery_On":{"visible":exp,"activate":Callable(self,"_select_tab").bind("exp")},
		"Tab/Btn_ExpRecovery_Off":{"visible":not exp,"activate":Callable(self,"_select_tab").bind("exp")},
		"Tab/Btn_ItemRecovery_On":{"visible":not exp,"activate":Callable(self,"_select_tab").bind("item")},
		"Tab/Btn_ItemRecovery_Off":{"visible":exp,"activate":Callable(self,"_select_tab").bind("item")},
		"DeathPenalty_Tab_ExpRecovery":{"visible":exp},
		"DeathPenalty_Tab_ItemRecovery":{"visible":not exp},
	}
	for key: String in [P_EXP+"Nd_ExpRecoveryList/",P_ITEM+"Nd_ItemRecoveryList/"]:
		var kind: String="exp" if key.begins_with(P_EXP) else "item"
		spec[key+"ListView"]={"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")}
		spec[key+"Nd_Amount/Text_Number"]={"role":"source_text","text":"(%d/%d)" % [(_service.active_losses(kind) as Array).size(),int(_service.slot_capacity(kind))]}
		spec[key+"Nd_MoneyGemChange/Btn_MoneyGem"]={"activate":Callable(self,"_toggle_currency")}
		# The amount beside the currency mark has no binding rule here.
		spec[key+"Nd_MoneyGemChange/Nd_Money"]={"visible":_currency=="adena"}
		spec[key+"Nd_MoneyGemChange/Nd_Gem"]={"visible":_currency=="gem"}
		spec[key+"Nd_MoneyGemChange/Nd_Money/Label_Cost"]={"visible":false}
		spec[key+"Nd_MoneyGemChange/Nd_Gem/Label_Cost"]={"visible":false}
	var selected_row: Dictionary={}
	for row: Dictionary in rows:
		if str(row.id)==_selected:selected_row=row
	var paid: Dictionary=_service.quote(_selected,_tab,_mode_for(selected_row)) if not _selected.is_empty() else {"ok":false}
	if exp:
		var free: int=int(_service.free_remaining())
		var free_quote: Dictionary=_service.quote(_selected,"exp","free") if not _selected.is_empty() and free>0 else {"ok":false}
		var certificate: Dictionary=_service.certificate_wallet()
		var certificate_quote: Dictionary=_service.quote(_selected,"exp","certificate") if not _selected.is_empty() else {"ok":false}
		var menu: String=list_key+"Menu_Button/"
		spec[menu+"Btn_Recovery_Free"]={"visible":free>0,"activate":Callable(self,"_recover").bind("free"),"displaystate":free_quote.get("ok",false)}
		spec[menu+"Btn_Recovery"]={"visible":free<=0,"activate":Callable(self,"_recover").bind(_mode_for(selected_row)),"displaystate":paid.get("ok",false)}
		for state: String in ["Normal","Disabled"]:
			spec[menu+"Btn_Recovery_Free/"+state+"/Label"]={"role":"source_text","text":"일일무료복구(%d)" % free}
			spec[menu+"Btn_Recovery_Free/"+state]={"visible":(state=="Normal")==free_quote.get("ok",false)}
			spec[menu+"Btn_Recovery/"+state]={"visible":(state=="Normal")==paid.get("ok",false)}
			spec[menu+"Btn_Rescue/"+state+"/Label"]={"role":"source_text","text":"구호의 증서 복구(%d)" % (int(_service.world.inventory.get(str(certificate.name),0)) if not certificate.is_empty() else 0)}
			spec[menu+"Btn_Rescue/"+state]={"visible":(state=="Normal")==certificate_quote.get("ok",false)}
		spec[menu+"Btn_Rescue"]={"activate":Callable(self,"_recover").bind("certificate"),"displaystate":certificate_quote.get("ok",false)}
	else:
		var menu: String=list_key+"Menu_Button/"
		var all_ok: bool=false
		for row: Dictionary in rows:
			if _service.quote(str(row.id),"item",_mode_for(row)).get("ok",false):all_ok=true
		spec[menu+"Btn_Recovery"]={"activate":Callable(self,"_recover").bind(_mode_for(selected_row)),"displaystate":paid.get("ok",false)}
		spec[menu+"Btn_Recovery_All"]={"activate":Callable(self,"_recover_all"),"displaystate":all_ok}
		spec[menu+"Btn_ToolTip"]={"displaystate":false}
		for state: String in ["Normal","Disabled"]:
			spec[menu+"Btn_Recovery/"+state]={"visible":(state=="Normal")==paid.get("ok",false)}
			spec[menu+"Btn_Recovery_All/"+state]={"visible":(state=="Normal")==all_ok}
			spec[menu+"Btn_ToolTip/"+state]={"visible":state=="Disabled"}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var list: Dictionary=NamedTree.locate(next,out,list_key+"ListView")
	var list_node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=list_node.get_meta("source_list_content",null) if is_instance_valid(list_node) else null
	if not content is Node2D:
		next.free()
		return _fail("source_death_window_list_content_missing")
	var list_size: Vector2=NamedTree.list_size(out,_pack,TAB_EXP if exp else TAB_ITEM,list_key+"ListView")
	var placed: int=0
	var pictures: int=0
	var height: float=0.0
	for row: Dictionary in rows:
		var scene: Dictionary=_row(row)
		if not scene.get("ok",false):continue
		if scene.get("picture",false):pictures+=1
		height+=_tree.add_row(content,ROW_EXP if exp else ROW_ITEM,scene.scene,placed,list_size)
		placed+=1
	# Free recovery slots, then the slot expansion row.
	var capacity: int=int(_service.slot_capacity(_tab))
	var empties: int=0
	for index: int in range(maxi(0,mini(capacity,MAX_ROWS)-placed)):
		var empty: Dictionary=_tree.scene_of(ROW_EMPTY,{"Panel":{"input":Callable(self,"_list_input")},"Btn_Normal":{"activate":Callable(self,"_ignore")}},{})
		if not empty.get("ok",false):break
		height+=_tree.add_row(content,ROW_EMPTY,empty.scene,placed+empties,list_size)
		empties+=1
	var offer: Dictionary=_service.quote_slot(_tab)
	var lock_text: String="복구 슬롯 +%d · 다이아 %d" % [int(offer.amount),int(offer.cost)] if offer.get("ok",false) else str(offer.get("message",""))
	var lock: Dictionary=_tree.scene_of(ROW_LOCK,{"Panel":{"input":Callable(self,"_lock_input")},"Nd_Lock_Karma":{"visible":false},"Nd_Lock/Label":{"role":"source_text","text":lock_text}},{})
	if lock.get("ok",false):height+=_tree.add_row(content,ROW_LOCK,lock.scene,placed+empties,list_size)
	var previous: Node2D=_scene
	# DeathPenalty_All_Layout sits at (191.75, 345) in FloatingUiScene.
	next.position=Vector2(191.75,-345.0)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_content=content
	_scroll_min=minf(0.0,list_size.y-height)
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.y=_scroll
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"tab":_tab,"currency":_currency,"rows":placed,"empty_rows":empties,"pictures":pictures,"selected":_selected,"paid_ok":paid.get("ok",false),"paid_reason":str(paid.get("message",""))}
	return last_result

func _row(row: Dictionary) -> Dictionary:
	var entry: Dictionary=row.entry
	var exp: bool=_tab=="exp"
	var member: String=ROW_EXP if exp else ROW_ITEM
	var quote: Dictionary=_service.quote(str(row.id),_tab,_mode_for(row))
	var selected: bool=str(row.id)==_selected
	var extended: bool=int(row.age)>=DAY
	var remain: int=maxi(0,(LIMIT if extended else DAY)-int(row.age))
	var time: String="%d시간 %d분" % [remain/3600,(remain%3600)/60]
	var text: String="경험치 %s" % _number(int(entry.get("exp",0))) if exp else str(entry.item.physical.get("name","")).get_slice(" · 원본#",0)
	var spec: Dictionary={"Panel":{"input":Callable(self,"_list_input")}}
	for state: String in ["Btn_Normal","Btn_Pressed","Btn_Disabled"]:
		var shown: bool=(state=="Btn_Disabled") if not quote.get("ok",false) else ((state=="Btn_Pressed")==selected)
		spec[state]={"visible":shown,"activate":Callable(self,"_row_pressed").bind(str(row.id))}
		spec[state+"/Default"]={"visible":not extended}
		spec[state+"/Default_Expension"]={"visible":extended}
		spec[state+"/Label_Exp"]={"role":"source_text","text":text}
		spec[state+"/Lable_Info"]={"role":"source_text","text":time,"visible":not extended}
		spec[state+"/Lable_Info_Expension"]={"role":"source_text","text":time,"visible":extended}
		spec[state+"/DeathPenalty_Text_Discount"]={"exclude":true}
		spec[state+"/Fx_DeathPenalty_WarZone"]={"exclude":true}
		spec[state+"/Fx_DeathPenalty_Select"]={"exclude":true}
		spec[state+"/Label_Cost"]={"role":"source_text","text":_number(int(quote.get("cost",0))),"visible":quote.get("ok",false)}
		spec[state+"/Img_Aden"]={"visible":quote.get("ok",false) and _currency=="adena"}
		spec[state+"/Img_Gem"]={"visible":quote.get("ok",false) and _currency=="gem"}
		if exp:
			for grade: String in ["Common","Rare","Unique","Legend","Epic"]:spec[state+"/Img_ExpSlot/Icon_Exp_"+grade]={"visible":false}
		else:
			spec[state+"/Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
			spec[state+"/Slot/Btn"]={"activate":Callable(self,"_row_pressed").bind(str(row.id))}
	spec["Btn_Disabled/Nd_Lock/Label"]={"role":"source_text","text":str(quote.get("message",""))}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(member,spec,out)
	if not built.get("ok",false):return built
	var picture: bool=false
	if not exp:
		var source_id: String=str(entry.item.get("source_id",""))
		var state: String="Btn_Disabled" if not quote.get("ok",false) else ("Btn_Pressed" if selected else "Btn_Normal")
		if source_id.is_valid_int():picture=_slot_picture(built.scene,out,state+"/Slot/Sp_IconSample",int(source_id),text)
	return {"ok":true,"scene":built.scene,"picture":picture}

func _slot_picture(root: Node2D, out: Dictionary, suffix: String, item_class_id: int, title: String) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item_class(item_class_id,title)
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## --- Actions -----------------------------------------------------------------

func _select_tab(value: String) -> Dictionary:
	_tab=value
	_selected=""
	_scroll=0.0
	return _stage()

func _toggle_currency() -> Dictionary:
	_currency="gem" if _currency=="adena" else "adena"
	return _stage()

func _row_pressed(id: String) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	_selected=id
	return _stage()

## The existing quote and transaction behind the HUD's confirmation.
func _recover(mode: String) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var request: Dictionary=_service.quote(_selected,_tab,mode)
	if not request.get("ok",false):
		_message(str(request.get("message","")))
		return request
	var currency_text: String={"free":"무료 횟수 1회","certificate":"%s %d개" % [str(request.get("certificate",{}).get("name","구호의 증서")),int(request.cost)],"adena":"%s 아데나" % _number(int(request.cost)),"gem":"%d 다이아" % int(request.cost)}[mode]
	var apply: Callable=func(_amount: int) -> void:
		var response: Dictionary=_service.recover(request)
		last_action=response
		_message(str(response.get("message","")))
		if is_open():_stage()
	if hud!=null and hud.has_method("confirm_action"):
		hud.call("confirm_action","사망 복구 확인","#%s %s을 복구합니다.\n소모: %s" % [str(request.id),"경험치" if _tab=="exp" else "원래 장비",currency_text],"복구",apply)
		return {"ok":true,"confirmation":true,"request":request}
	apply.call(0)
	return last_action

func _recover_all() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var requests: Array=[]
	var total: int=0
	for row: Dictionary in _rows():
		var request: Dictionary=_service.quote(str(row.id),"item",_mode_for(row))
		if request.get("ok",false):
			requests.append(request)
			total+=int(request.cost)
	if requests.is_empty():return _fail("source_death_window_nothing_to_recover")
	var apply: Callable=func(_amount: int) -> void:
		var done: int=0
		for request: Dictionary in requests:
			# Each recovery is its own existing quote check and atomic save.
			var current: Dictionary=_service.quote(str(request.id),"item",str(request.mode))
			if not current.get("ok",false):break
			if not _service.recover(current).get("ok",false):break
			done+=1
		last_action={"ok":done>0,"recovered":done,"requested":requests.size()}
		_message("아이템 %d / %d개 복구 · 저장했습니다" % [done,requests.size()])
		if is_open():_stage()
	if hud!=null and hud.has_method("confirm_action"):
		hud.call("confirm_action","사망 복구 확인","아이템 %d개를 모두 복구합니다.\n소모: %s %s" % [requests.size(),_number(total),"아데나" if _currency=="adena" else "다이아"],"복구",apply)
		return {"ok":true,"confirmation":true,"requests":requests.size()}
	apply.call(0)
	return last_action

func _lock_input(event: InputEvent) -> void:
	_list_input(event)
	var released: bool=(event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)
	if released and absf(_moved)<=12.0:_expand_slot.call_deferred()

func _expand_slot() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var request: Dictionary=_service.quote_slot(_tab)
	if not request.get("ok",false):
		_message(str(request.get("message","")))
		return request
	var apply: Callable=func(_amount: int) -> void:
		var response: Dictionary=_service.expand_slot(request)
		last_action=response
		_message(str(response.get("message","")))
		if is_open():_stage()
	if hud!=null and hud.has_method("confirm_action"):
		hud.call("confirm_action","복구 슬롯 확장 확인","%s 복구 슬롯을 %d칸 확장합니다.\n소모: 다이아 %d개" % ["경험치" if _tab=="exp" else "아이템",int(request.amount),int(request.cost)],"확장",apply)
		return {"ok":true,"confirmation":true}
	apply.call(0)
	return last_action

func _message(text: String) -> void:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message") and not text.is_empty():hud.call("show_message",text)

func _ignore() -> Dictionary:
	return {"ok":true}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=81.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
