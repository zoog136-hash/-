extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 설정 window: Option_All (full frame, title, close, the six
## tabs 기본 / 조작 / 환경 / 출력 / 알림 / 정보) over the existing TWILIGHT
## settings (renewal_settings: SETTINGS_PATH, the master audio bus) and the
## existing game actions:
## - 환경 (Option_Tab_Sound): the 배경음 row is the master volume (TWILIGHT has
##   one audio bus; TWILIGHT 근사: its title reads 전체 음량). Tapping the row
##   steps the volume 0..10 (the original Option_Slider_A is a Cocos Slider
##   this renderer does not mount: TWILIGHT 근사); the other sound rows stay out.
## - 정보 (Option_Tab_Info): 캐릭터 이름, 버전 정보 (the project version and the
##   installed UI add-on: source_ui_pack_version), the
##   쿠폰 field and 확 인 (World.redeem_promo_code), 캐릭터 선택
##   (World.return_to_character_lobby); 계정 탈퇴's place opens the TWILIGHT
##   세부 설정 screen (TWILIGHT 근사: save / load, effects, HUD toggles).
## - 조작 (Option_Tab_Hunt, 자동 사냥 제어): the 물약 자동 사용 row is the
##   existing HP 회복제 auto-use setting (World consumable_auto hp_enabled /
##   hp_percent). On / Off switch it; the Cocos Option_Slider_B is not mounted,
##   so tapping the selected On raises the HP ratio by 10% (90% wraps to 10%;
##   TWILIGHT 근사). The other rows have no TWILIGHT rule and stay out.
## - 출력 (Option_Tab_Etc): 오브젝트 간소화 출력 (소환수 및 일부 이펙트
##   간소화) is the existing 이펙트 세부 표현 간소화 + 동시 이펙트 수 줄이기
##   (renewal_settings visual effect_detail / limit_effect_count). The other
##   rows stay out.
## - 쿠폰 코드 (menu) opens this window on 정보 (its 쿠폰 field).
## Left inert (no TWILIGHT rule for their rows): 기본 / 알림 tabs
## (tapping says so), 계정 연동, 결제, 로그아웃, 만든 사람들, the help popups.
const ROOT="UI/Option/Option_All.csb"
const PackVersion=preload("res://scripts/ui/original_ui/source_ui_pack_version.gd")
const SETTINGS_PATH=preload("res://scripts/ui/saved_ui_settings.gd").SETTINGS_PATH
## tab -> [pressed button, released button, page project]
const TABS={"game":["Btn_Hunt_On","Btn_Hunt_Off","Option_Tab_Game"],"control":["Btn_Looting_On","Btn_Looting_Off","Option_Tab_Hunt"],
	"sound":["Btn_Sound_On","Btn_Sound_Off","Option_Tab_Sound"],"output":["Btn_Etc_On","Btn_Etc_Off","Option_Tab_Etc"],
	"notice":["Btn_Notice_On","Btn_Notice_Off","Option_Tab_Notice"],"info":["Btn_Info_On","Btn_Info_Off","Option_Tab_Info"]}
const CONNECTED: Array[String]=["control","sound","output","info"]
const POTION_STEP: int=10
const POLICY=preload("res://scripts/consumable_auto_policy.gd")
const PAGES: Array[String]=["Option_Tab_Hunt","Option_Tab_Looting","Option_Tab_Sound","Option_Tab_Game","Option_Tab_Etc","Option_Tab_Notice","Option_Tab_Info","Option_Popup_Help","Option_Popup_Help_AutoGet","Option_Popup_Help_Potion"]
var tab: String="sound"
var _coupon_editor: LineEdit

func _root_member() -> String:
	return ROOT

func open(parent: Node, first_tab: String="sound") -> Dictionary:
	tab=first_tab if TABS.has(first_tab) and first_tab in CONNECTED else "sound"
	return open_window(parent)

## Opening, switching tabs, and refreshing all stage their textures here.
func _stage() -> Dictionary:
	if _pack == null or not _pack.has_method("set_settings_frame_scope"):
		return super._stage()
	var previous: bool = _pack.set_settings_frame_scope(true)
	var result := super._stage()
	_pack.set_settings_frame_scope(previous)
	return result

## The saved master volume, 0..100.
static func volume() -> float:
	var saved:=ConfigFile.new()
	saved.load(SETTINGS_PATH)
	return clampf(float(saved.get_value("audio","volume",100.0)),0.0,100.0)

static func volume_step(value: float) -> int:
	return clampi(roundi(value/10.0),0,10)

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Fx_Img_BG_Particle"]={"exclude":true}
	for name: String in TABS:
		var on: bool=name==tab
		spec["Nd_TabMenu/"+str(TABS[name][0])]={"visible":on,"activate":Callable(self,"_tab_requested").bind(name)}
		spec["Nd_TabMenu/"+str(TABS[name][1])]={"visible":not on,"activate":Callable(self,"_tab_requested").bind(name)}
	for page: String in PAGES:
		if page!=str(TABS[tab][2]):spec[page]={"exclude":true}
	spec[str(TABS[tab][2])]={"visible":true}
	if tab=="sound":_sound_spec(spec)
	elif tab=="info":_info_spec(spec)
	elif tab=="control":_control_spec(spec)
	elif tab=="output":_output_spec(spec)
	return spec

## The panels of Option_Tab_Hunt's 자동 사냥 제어 list other than 물약 자동 사용.
const CONTROL_OTHER: Array[String]=["Panel_PotionPvp","Panel_Hp_Minimum","Panel_Mp","Panel_Mp_Skill","Panel_2","Panel_4","Panel_5","Panel_6","Panel_7","Panel_8","Panel_8_1","Panel_CustomSlot","Panel_Drag","Panel_9","Panel_10","Panel_11","Panel_12","Panel_13","Panel_3","Panel_ItemAutoChange","Panel_Signal"]
## The kept rows (Option_Tab_Hunt ListView_AutoControl/Panel_1, Option_Tab_Etc
## ListView_1/Panel_SimpleNPC) by their original node offsets.
const CONTROL_POTION_ROW: int=223920
const OUTPUT_SIMPLE_ROW: int=58592
## Option_Tab_Etc rows other than 오브젝트 간소화 출력.
const OUTPUT_OTHER: Array[String]=["Panel_CharacterInfo","Panel_CharacterName","Panel_CharacterNickName","Panel_DropItem","Panel_Npc","Panel_MyCharacter","Panel_Target","Panel_NpcWordBalloon","Panel_Dialogue","Panel_BossAlarm","Panel_Low"]

## The existing HP 회복제 auto-use setting (World.get_consumable_auto_settings).
func potion_settings() -> Dictionary:
	var owner: Object=world()
	return POLICY.normalize(owner.call("get_consumable_auto_settings") if owner!=null and owner.has_method("get_consumable_auto_settings") else {})

static func next_potion_percent(percent: int) -> int:
	var next: int=percent+POTION_STEP if percent%POTION_STEP==0 else ceili(float(percent)/float(POTION_STEP))*POTION_STEP
	return POTION_STEP if next>90 else next

func _control_spec(spec: Dictionary) -> void:
	var p: String="Option_Tab_Hunt/"
	for hidden: String in ["ListView_Search","ListView_AutoGet","ListView_Link","Nd_Popup_Link","ListView_Exchange","Bar_Recharge"]:spec[p+hidden]={"exclude":true}
	var list: String=p+"ListView_AutoControl/"
	for row: String in CONTROL_OTHER:spec[list+row]={"exclude":true}
	# The list's row contract names the one row left (its Panel_1).
	spec[p+"ListView_AutoControl"]={"row_offsets":[CONTROL_POTION_ROW]}
	var row: String=list+"Panel_1/"
	var potion: Dictionary=potion_settings()
	var on: bool=bool(potion.hp_enabled)
	for slot: String in ["Option_Slot","Option_Slot_2","Option_Slot_3","Option_Slot_4","Option_Slider_B","Img_Disabled","Btn_Help"]:spec[row+slot]={"exclude":true}
	spec[row+"Text_Volume"]={"role":"source_text","text":"%d%%" % int(potion.hp_percent)}
	spec[row+"Label_Notice"]={"role":"source_text","text":"On을 다시 누를 때마다 %d%%씩 올라갑니다 (90%% 다음은 10%%)" % POTION_STEP,"visible":on}
	spec[row+"Btn_Active_On"]={"visible":on,"activate":Callable(self,"_potion_percent_pressed")}
	spec[row+"Btn_Active_Off"]={"visible":not on,"activate":Callable(self,"_potion_enabled").bind(true)}
	spec[row+"Btn_Inactive_On"]={"visible":not on,"activate":Callable(self,"_ignore")}
	spec[row+"Btn_Inactive_Off"]={"visible":on,"activate":Callable(self,"_potion_enabled").bind(false)}

## 오브젝트 간소화 출력: on when both existing low-effect settings are on.
static func simple_objects() -> bool:
	var saved:=ConfigFile.new()
	saved.load(SETTINGS_PATH)
	return str(saved.get_value("visual","effect_detail","full"))=="low" and bool(saved.get_value("visual","limit_effect_count",false))

func _output_spec(spec: Dictionary) -> void:
	var list: String="Option_Tab_Etc/ListView_1/"
	for row: String in OUTPUT_OTHER:spec[list+row]={"exclude":true}
	spec["Option_Tab_Etc/ListView_1"]={"row_offsets":[OUTPUT_SIMPLE_ROW]}
	# The right list (렌더링 품질, 이펙트 출력 ...) and its two choice popups
	# have no TWILIGHT rule.
	for other: String in ["ListView_2","Btn_Popup_Set_Output","Btn_Popup_Set_Quality"]:spec["Option_Tab_Etc/"+other]={"exclude":true}
	var on: bool=simple_objects()
	var box: String=list+"Panel_SimpleNPC/Btn_CheckBox/"
	spec[box+"Btn_Normal"]={"visible":on,"activate":Callable(self,"_simple_objects_pressed").bind(false)}
	spec[box+"Btn_Disabled"]={"visible":not on,"activate":Callable(self,"_simple_objects_pressed").bind(true)}

func _sound_spec(spec: Dictionary) -> void:
	var p: String="Option_Tab_Sound/"
	spec[p+"Content_0/BackgroundSound/Option_Slider_A"]={"exclude":true}
	spec[p+"Content_0/BackgroundSound/Text_Title"]={"role":"source_text","text":"전체 음량"}
	spec[p+"Content_0/BackgroundSound/Text_Desc"]={"role":"source_text","text":"누를 때마다 한 단계씩 커지고, 10 다음은 0입니다."}
	spec[p+"Content_0/BackgroundSound/Text_Volume"]={"role":"source_text","text":str(volume_step(volume()))}
	for row: String in ["Content_0/AmbientSound","Content_0/EffectSound","Content_1"]:spec[p+row]={"exclude":true}

func _info_spec(spec: Dictionary) -> void:
	var p: String="Option_Tab_Info/"
	var owner: Object=world()
	var name: String=str(owner.get("character_name")) if owner!=null and owner.get("character_name") is String and not str(owner.get("character_name")).is_empty() else str(owner.get("job_class") if owner!=null else "")
	spec[p+"LeftContents/CharacterName/Text_Desc"]={"role":"source_text","text":name}
	spec[p+"LeftContents/Current_Account/Text_Desc"]={"role":"source_text","text":"이 기기 로컬 저장"}
	spec[p+"LeftContents/Login_Account"]={"exclude":true}
	spec[p+"LeftContents/Btn_Withdrawal"]={"activate":Callable(self,"_details_requested")}
	spec[p+"LeftContents/Btn_Withdrawal/Label"]={"role":"source_text","text":"세부 설정"}
	var version: String=str(ProjectSettings.get_setting("application/config/version",""))
	# 버전 정보: the project version, then the installed UI add-on (two lines
	# of the authored 500x45 text).
	var pack_info: Dictionary=PackVersion.describe(str(_pack.get("manifest_sha256")) if _pack!=null else "",_pack.get("manifest").get("scenes",{}) if _pack!=null and _pack.get("manifest") is Dictionary else null)
	spec[p+"RightContents/Version/Text_Desc"]={"role":"source_text","text":(version if not version.is_empty() else "TWILIGHT")+"\n"+PackVersion.label(pack_info)+"\n"+preload("res://scripts/ui/item_icon_resource_status.gd").label(preload("res://scripts/ui/item_icon_resource_status.gd").check(true))}
	spec[p+"RightContents/Coupon/TextField"]={"role":"source_text_field","editor":_editor()}
	spec[p+"RightContents/Coupon/Btn_Confirm"]={"activate":Callable(self,"_coupon_requested")}
	for absent: String in ["RightContents/Achievement","RightContents/Google","RightContents/Contact/Btn_Logout","RightContents/Btn_Credit"]:spec[p+absent]={"exclude":true}
	spec[p+"RightContents/Contact/Btn_Select"]={"activate":Callable(self,"_lobby_requested")}

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	if tab=="info":
		var located: Dictionary=_locate(root,out,"Coupon/TextField")
		if located.get("ok",false):
			var node: Variant=located.player.source_nodes.get(located.offset)
			var field: Variant=node.get_meta("source_text_field",null) if is_instance_valid(node) and node.has_meta("source_text_field") else null
			if field!=null and field.has_method("attach_editor"):field.attach_editor()
	var volume_area: bool=false
	if tab=="sound":volume_area=_volume_touch_area(root,out)
	return {"ok":true,"tab":tab,"volume_area":volume_area}

## The 배경음 row's Bg is not a touch node in Option_Tab_Sound (the client
## drags its Cocos Option_Slider_A, which this renderer does not mount), so
## a binding on it never received a tap: a transparent touch area over the
## row's own Bg steps the volume (TWILIGHT 근사 for the slider).
func _volume_touch_area(root: Node2D, out: Dictionary) -> bool:
	var located: Dictionary=_locate(root,out,"Content_0/BackgroundSound/Bg")
	if not located.get("ok",false):return false
	var node: Variant=located.player.source_nodes.get(located.offset)
	var origin: Variant=node.get_node_or_null("SourceContentOrigin") if is_instance_valid(node) else null
	if not origin is Node2D:return false
	var size: Vector2=_node_size(out,"Content_0/BackgroundSound/Bg")
	var area:=Control.new()
	area.name="OptionVolumeTouchArea"
	area.position=Vector2(0.0,-size.y)
	area.size=size
	area.mouse_filter=Control.MOUSE_FILTER_STOP
	area.gui_input.connect(_volume_area_input)
	(origin as Node2D).add_child(area)
	return true

var _volume_press: Vector2=Vector2.INF

func _volume_area_input(event: InputEvent) -> void:
	var touch: bool=event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)
	if not touch:return
	if event.pressed:
		_volume_press=event.position
		return
	var moved: bool=_volume_press.is_finite() and _volume_press.distance_to(event.position)>12.0
	_volume_press=Vector2.INF
	if not moved:_volume_pressed.call_deferred()

func _editor() -> LineEdit:
	if not is_instance_valid(_coupon_editor):
		_coupon_editor=preload("res://scripts/ui/native_touch_line_edit.gd").new()
		_coupon_editor.name="OptionCouponInput"
		_coupon_editor.max_length=32
		_coupon_editor.visible=false
		var parent: Object=_parent.get_ref() if _parent!=null else null
		if parent is Node:(parent as Node).add_child(_coupon_editor)
	return _coupon_editor

func _tab_requested(name: String) -> Dictionary:
	if name==tab:return {"ok":true,"same":true}
	if name not in CONNECTED:
		_say("이 탭의 항목은 지원하지 않습니다. 정보 탭의 세부 설정에서 바꿀 수 있습니다")
		return {"ok":true,"handled":false,"inert_tab":name}
	tab=name
	return _stage()

## 환경: the master volume one step up (10 wraps to 0), saved like renewal_settings.
func _volume_pressed() -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	var step: int=(volume_step(volume())+1)%11
	var level: float=float(step*10)
	var saved:=ConfigFile.new()
	saved.load(SETTINGS_PATH)
	saved.set_value("audio","volume",level)
	if saved.save(SETTINGS_PATH)!=OK:return _say("설정을 저장하지 못했습니다")
	if AudioServer.get_bus_count()>0:
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,level/100.0)))
		AudioServer.set_bus_mute(0,bool(saved.get_value("audio","muted",false)) or level<=0.0)
	var staged: Dictionary=_stage()
	staged["volume"]=level
	return staged

## 조작 · 물약 자동 사용 On / Off: the existing HP 회복제 auto-use switch.
func _potion_enabled(enabled: bool) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	return _store_potion({"hp_enabled":enabled})

## The selected On tapped again: the HP ratio one step up.
func _potion_percent_pressed() -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	return _store_potion({"hp_percent":next_potion_percent(int(potion_settings().hp_percent))})

func _store_potion(change: Dictionary) -> Dictionary:
	var owner: Object=hud()
	if owner==null or not owner.has_signal("consumable_auto_settings_changed"):return _say("지금은 물약 자동 사용을 바꿀 수 없습니다")
	var settings: Dictionary=potion_settings()
	settings.merge(change,true)
	# The same path as the TWILIGHT 소모품 자동 사용 screen (World saves it).
	owner.emit_signal("consumable_auto_settings_changed",POLICY.normalize(settings))
	var staged: Dictionary=_stage()
	staged["potion"]=potion_settings()
	return staged

## 출력 · 오브젝트 간소화 출력: saved and applied like renewal_settings.
func _simple_objects_pressed(enabled: bool) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	var saved:=ConfigFile.new()
	saved.load(SETTINGS_PATH)
	saved.set_value("visual","effect_detail","low" if enabled else "full")
	saved.set_value("visual","limit_effect_count",enabled)
	if saved.save(SETTINGS_PATH)!=OK:return _say("설정을 저장하지 못했습니다")
	var owner: Object=world()
	if owner!=null and owner.has_method("apply_presentation_settings"):
		owner.call("apply_presentation_settings",{"impact_intensity":clampf(float(saved.get_value("visual","impact_intensity",.85)),0.0,1.0),"reduced_motion":bool(saved.get_value("visual","reduced_motion",false)),"effect_detail":saved.get_value("visual","effect_detail","full"),"limit_effect_count":enabled,"hide_doll":saved.get_value("visual","hide_doll",false)})
	var staged: Dictionary=_stage()
	staged["simple_objects"]=enabled
	return staged

func _coupon_requested() -> Dictionary:
	var owner: Object=world()
	if owner==null or not owner.has_method("redeem_promo_code"):return _say("지금은 쿠폰을 사용할 수 없습니다")
	var code: String=_coupon_editor.text.strip_edges() if is_instance_valid(_coupon_editor) else ""
	if code.is_empty():return _say("쿠폰 번호를 입력해 주세요")
	var result: Dictionary=owner.call("redeem_promo_code",code)
	if bool(result.get("ok",false)):
		_coupon_editor.clear()
		_say("지급 완료 · 다이아 %d · 아데나 %d" % [int(result.get("diamond_gain",0)),int(result.get("gold_gain",0))])
	else:_say(str(result.get("reason","쿠폰을 사용할 수 없습니다")))
	var staged: Dictionary=_stage()
	staged["coupon"]=result
	return staged

func _lobby_requested() -> Dictionary:
	var owner: Object=world()
	if owner==null or not owner.has_method("return_to_character_lobby"):return _say("캐릭터 선택으로 돌아갈 수 없습니다")
	close()
	return {"ok":true,"lobby":owner.call("return_to_character_lobby")}

func _details_requested() -> Dictionary:
	var owner: Object=hud()
	if owner==null or not owner.has_method("open_settings_info"):return _say("세부 설정을 열 수 없습니다")
	close()
	owner.call("open_settings_info",false,false)
	return {"ok":true,"routed":"settings_details"}

func _say(text: String) -> Dictionary:
	var owner: Object=hud()
	if owner!=null and owner.has_method("show_message"):owner.call("show_message",text)
	return {"ok":false,"handled":true,"message":text}

