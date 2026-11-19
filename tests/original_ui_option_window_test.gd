extends SceneTree
## The original 523 설정 window (source_main_option_window, Option_All) over
## the TWILIGHT settings. Without arguments (no original files): the volume
## steps, the HUD routing (original first, 세부 설정 = the TWILIGHT screen) and
## fail-closed configuration. Real input: -- --pack=<private original main UI
## pack directory>: Option_All mounts the 환경 tab (master volume steps and is
## saved), the 정보 tab (name, version, coupon, 캐릭터 선택, 세부 설정) and
## refuses the tabs without a TWILIGHT rule.
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
	func redeem_promo_code(code: String) -> Dictionary:
		codes.append(code)
		return {"ok":code=="GOOD","reason":"사용할 수 없는 코드","diamond_gain":10,"gold_gain":0}
	func return_to_character_lobby() -> bool:
		lobby+=1
		return true

class FakeHud extends Node:
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
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	check(WINDOW.volume_step(100.0)==10 and WINDOW.volume_step(0.0)==0 and WINDOW.volume_step(44.0)==4,"volume steps of ten")
	check(WINDOW.SETTINGS_PATH==preload("res://scripts/ui/renewal_settings.gd").SETTINGS_PATH,"the TWILIGHT settings file")
	var host: Dictionary=_host()
	var configured: Dictionary=WINDOW.new().configure(FakePack.new(),host.hud)
	check(not configured.get("ok",true) and configured.get("code")=="source_window_member_missing","fails closed without Option_All")
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains("if original and not expand_all and _open_original_feature(\"options\"):return"),"설정 opens the original window first")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_text.contains("\"options\":preload(\"res://scripts/ui/original_ui/source_main_option_window.gd\")"),"the window is a feature window")
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	check(window._details_requested().get("routed","")=="settings_details" and host.hud.details==[[false,false]],"세부 설정 opens the TWILIGHT settings")
	check(not window._coupon_requested().get("ok",true) and host.hud.shown[-1]=="쿠폰 번호를 입력해 주세요","an empty coupon is refused")
	check(window._lobby_requested().get("ok",false) and host.world.lobby==1,"캐릭터 선택 returns to the lobby")
	host.world.queue_free()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_OPTION_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

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
	var before: int=WINDOW.volume_step(WINDOW.volume())
	var stepped: Dictionary=window._volume_pressed()
	check(stepped.get("handled",false) and WINDOW.volume_step(WINDOW.volume())==(before+1)%11,"the volume row steps and saves: "+str(stepped.get("volume")))
	var inert: Dictionary=window._tab_requested("notice")
	check(not inert.get("handled",true) and window.tab=="sound" and host.hud.shown[-1].contains("세부 설정"),"a tab without a TWILIGHT rule says so")
	var info: Dictionary=window._tab_requested("info")
	check(info.get("handled",false) and window.tab=="info","the 정보 tab mounts: "+str(info).left(300))
	window._editor().text="BAD"
	var coupon: Dictionary=window._coupon_requested()
	check(host.world.codes==["BAD"] and coupon.get("handled",false) and host.hud.shown[-1]=="사용할 수 없는 코드","확 인 redeems the coupon field")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
