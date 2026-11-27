extends SceneTree
## The original 523 설정 window (source_main_option_window, Option_All) over
## the TWILIGHT settings. Without arguments (no original files): the volume
## steps, the HUD routing (original first, 세부 설정 = the TWILIGHT screen) and
## fail-closed configuration. Real input: -- --pack=<private original main UI
## pack directory>: Option_All mounts the 환경 tab (master volume steps and is
## saved), the 정보 tab (name, version, coupon, 캐릭터 선택, 세부 설정) and
## refuses the tabs without a TWILIGHT rule; the 조작 tab's 물약 자동 사용 row
## (On / Off and the ratio step through the existing consumable setting) and
## the 출력 tab's 오브젝트 간소화 출력 (saved, then the file is restored).
const WINDOW=preload("res://scripts/ui/original_ui/source_main_option_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeWorld extends Node:
	var character_name: String="시험기사"
	var job_class: String="기사"
	var codes: Array[String]=[]
	var lobby: int=0
	var consumable: Dictionary={}
	func get_consumable_auto_settings() -> Dictionary:
		return consumable.duplicate(true)
	func set_consumable_auto_settings(value: Dictionary) -> void:
		consumable=value.duplicate(true)
	func redeem_promo_code(code: String) -> Dictionary:
		codes.append(code)
		return {"ok":code=="GOOD","reason":"사용할 수 없는 코드","diamond_gain":10,"gold_gain":0}
	func return_to_character_lobby() -> bool:
		lobby+=1
		return true

class FakeHud extends Node:
	signal consumable_auto_settings_changed(settings: Dictionary)
	var shown: Array[String]=[]
	var details: Array=[]
	func show_message(text: String) -> void:
		shown.append(text)
	func open_settings_info(expand_all: bool=false, original: bool=true) -> void:
		details.append([expand_all,original])

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_OPTION_WINDOW_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	hud.consumable_auto_settings_changed.connect(world.set_consumable_auto_settings)
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	check(WINDOW.volume_step(100.0)==10 and WINDOW.volume_step(0.0)==0 and WINDOW.volume_step(44.0)==4,"volume steps of ten")
	check(WINDOW.SETTINGS_PATH==preload("res://scripts/ui/renewal_settings.gd").SETTINGS_PATH,"the TWILIGHT settings file")
	check(WINDOW.next_potion_percent(70)==80 and WINDOW.next_potion_percent(90)==10 and WINDOW.next_potion_percent(75)==80 and WINDOW.next_potion_percent(5)==10,"the potion ratio steps by 10 and wraps after 90")
	check(WINDOW.CONNECTED.has("control") and WINDOW.CONNECTED.has("output") and not WINDOW.CONNECTED.has("game") and not WINDOW.CONNECTED.has("notice"),"조작 and 출력 are connected, 기본 and 알림 stay inert")
	var host: Dictionary=_host()
	var configured: Dictionary=WINDOW.new().configure(FakePack.new(),host.hud)
	check(not configured.get("ok",true) and configured.get("code")=="source_window_member_missing","fails closed without Option_All")
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("if original and not expand_all and _open_original_feature(\"options\"):return"),"설정 opens the original window first")
	check(hud_text.contains("if _open_original_feature(\"options\",[\"info\"]):return"),"쿠폰 코드 opens the original 정보 tab (its coupon field) first")
	var feature_paths: Dictionary=preload("res://scripts/ui/original_ui/source_main_hud.gd").FEATURE_WINDOW_PATHS
	check(load(feature_paths.get("options"))==WINDOW,"the window is a feature window")
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	check(window._details_requested().get("routed","")=="settings_details" and host.hud.details==[[false,false]],"세부 설정 opens the TWILIGHT settings")
	check(not window._coupon_requested().get("ok",true) and host.hud.shown[-1]=="쿠폰 번호를 입력해 주세요","an empty coupon is refused")
	check(window._lobby_requested().get("ok",false) and host.world.lobby==1,"캐릭터 선택 returns to the lobby")
	var potion: Dictionary=window.potion_settings()
	check(bool(potion.hp_enabled) and int(potion.hp_percent)==70,"the potion row reads the existing consumable defaults")
	window._potion_enabled(false)
	check(host.world.consumable.get("hp_enabled")==false and int(host.world.consumable.get("hp_percent",0))==70,"Off switches the existing HP auto-use off through the HUD signal")
	window._potion_percent_pressed()
	check(int(host.world.consumable.get("hp_percent",0))==80,"the ratio step is stored through the same signal")
	host.world.queue_free()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_OPTION_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

## True when the open window bound an original node whose key ends with `suffix`.
static func _has_key(window: Object, suffix: String) -> bool:
	var keys: Variant=window.get("_out")
	if not keys is Dictionary:return false
	for key: String in keys:
		if key.ends_with("/"+suffix):return true
	return false

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and str(opened.filled.tab)=="sound","Option_All mounts the 환경 tab: "+str(opened).left(300))
	check(bool(opened.get("filled",{}).get("volume_area",false)),"the 배경음 row has a touch area (its Bg is not an original touch node)")
	var before: int=WINDOW.volume_step(WINDOW.volume())
	var stepped: Dictionary=window._volume_pressed()
	check(stepped.get("handled",false) and WINDOW.volume_step(WINDOW.volume())==(before+1)%11,"the volume row steps and saves: "+str(stepped.get("volume")))
	var inert: Dictionary=window._tab_requested("notice")
	check(not inert.get("handled",true) and window.tab=="sound" and host.hud.shown[-1].contains("세부 설정"),"a tab without a TWILIGHT rule says so")
	var settings_before: String=FileAccess.get_file_as_string(WINDOW.SETTINGS_PATH) if FileAccess.file_exists(WINDOW.SETTINGS_PATH) else ""
	var control: Dictionary=window._tab_requested("control")
	check(control.get("handled",false) and window.tab=="control","the 조작 tab mounts: "+str(control).left(300))
	check(_has_key(window,"ListView_AutoControl/Panel_1/Btn_Active_On") and not _has_key(window,"ListView_AutoControl/Panel_PotionPvp") and not _has_key(window,"ListView_Search/Panel_1"),"조작 shows only the 물약 자동 사용 row")
	window._potion_enabled(true)
	var stepped_potion: Dictionary=window._potion_percent_pressed()
	check(stepped_potion.get("handled",false) and bool(host.world.consumable.get("hp_enabled",false)) and int(stepped_potion.potion.hp_percent)==80,"On + the selected On step the existing HP auto-use: "+str(stepped_potion.get("potion")))
	var output: Dictionary=window._tab_requested("output")
	check(output.get("handled",false) and window.tab=="output" and _has_key(window,"Panel_SimpleNPC/Btn_CheckBox/Btn_Normal") and not _has_key(window,"ListView_1/Panel_DropItem"),"the 출력 tab mounts its 오브젝트 간소화 row only: "+str(output).left(200))
	var simple: Dictionary=window._simple_objects_pressed(true)
	check(simple.get("handled",false) and WINDOW.simple_objects(),"오브젝트 간소화 On saves 간소화 + 동시 이펙트 수 줄이기")
	window._simple_objects_pressed(false)
	check(not WINDOW.simple_objects(),"오브젝트 간소화 Off restores 전체")
	if settings_before.is_empty():DirAccess.remove_absolute(ProjectSettings.globalize_path(WINDOW.SETTINGS_PATH))
	else:
		var restore:=FileAccess.open(WINDOW.SETTINGS_PATH,FileAccess.WRITE)
		restore.store_string(settings_before)
		restore.close()
	var info: Dictionary=window._tab_requested("info")
	check(info.get("handled",false) and window.tab=="info","the 정보 tab mounts: "+str(info).left(300))
	window._editor().text="BAD"
	var coupon: Dictionary=window._coupon_requested()
	check(host.world.codes==["BAD"] and coupon.get("handled",false) and host.hud.shown[-1]=="사용할 수 없는 코드","확 인 redeems the coupon field")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
