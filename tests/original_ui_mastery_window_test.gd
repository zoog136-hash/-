extends SceneTree
## The original 523 무기 숙련 window (source_main_mastery_window.gd) over the
## existing world.weapon_mastery runtime (synthetic schema fixture, never
## original content). Without arguments: every action goes quote -> HUD
## confirmation -> execute with the quoted state and payment, a refused quote
## only shows its message, a lock tap saves through set_color_lock, the first
## reached level without options is the 옵션 획득 target, a weapon with
## partially owned levels opens the existing panel (부분 옵션 복구), the shared
## player takes a stated node colour, and the HUD opens the window first.
## Real input: -- --pack=<private original main UI pack directory>:
## Mastery_All mounts with the weapon rows, the option rows with their field
## colours, the help toggle and the 옵션 획득 / 변경 하기 switch.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_mastery_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const Fixtures=preload("res://tests/mastery523_test.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeRuntime extends "res://scripts/mastery/mastery_runtime.gd":
	var executed: Array=[]
	var locked: Array=[]
	var refuse: Dictionary={}
	func quote(action: String, weapon: int, _target: int=0, prefix: int=0, payment: String="currency") -> Dictionary:
		if refuse.has(action):return {"ok":false,"reason":str(refuse[action])}
		return {"ok":true,"charge":{"CurrencyID":1,"Cost":1200+prefix},"before":{"weapon":weapon,"payment":payment},"frozen_levels":[]}
	func execute(action: String, weapon: int, target: int, prefix: int, expected: Dictionary, payment: String="currency") -> Dictionary:
		executed.append([action,weapon,target,prefix,expected,payment])
		return {"ok":true}
	func set_color_lock(weapon: int, level: int, slot: int, value: bool) -> Dictionary:
		locked.append([weapon,level,slot,value])
		return {"ok":true}
	func currency_name(_id: int) -> String:
		return "아데나"
	func weapon_name(base: int) -> String:
		return "weapon_%d" % base

class FakeWorld extends Node:
	var weapon_mastery: RefCounted
	var actual: int=1
	func _mastery_actual_weapon_type() -> int:
		return actual

class FakeHud extends Node:
	var messages: Array[String]=[]
	var confirmations: Array=[]
	var native: int=0
	func show_message(text: String) -> void:
		messages.append(text)
	func confirm_action(title: String, body: String, action: String, callback: Callable, _maximum: int=0) -> Control:
		confirmations.append([title,body,action])
		callback.call(1)
		return null
	func open_mastery_native() -> void:
		native+=1

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	var runtime:=FakeRuntime.new()
	runtime.core.configure(Fixtures.fixture())
	runtime.enabled=true
	runtime.world=world
	world.weapon_mastery=runtime
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud,"runtime":runtime}

## Weapon 1 at level 3 with levels 1 and 2 owned (four green fields).
static func _owned(runtime: RefCounted, weapon: int) -> void:
	var entry: Dictionary={"points":str(int(runtime.core.levels[weapon][2].CumulativePoint)),"options":[],"colors":{},"locks":{}}
	for level: int in [1,2]:
		for slot: int in [1,2]:
			for group: int in runtime.core.options:
				var row: Dictionary=runtime.core.options[group][weapon]
				if int(row.level)==level and int(row.Slot)==slot:
					entry.options.append({"group_id":group})
					break
		entry.colors[str(level)]=[2,2,2,2]
		entry.locks[str(level)]=[level==2,false,false,false]
	runtime.state.weapons[str(weapon)]=entry

func _run() -> void:
	var host: Dictionary=_host()
	var runtime: FakeRuntime=host.runtime
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	_owned(runtime,1)
	window.selected=1
	check(WINDOW.claimable_level(runtime,1)==3,"the first reached level without options is the 옵션 획득 target: "+str(WINDOW.claimable_level(runtime,1)))
	var options: Dictionary=WINDOW.level_options(runtime,runtime.core.record(runtime.state,1),1,1)
	check(options.size()==2 and str(options[1].name)=="근거리 대미지" and str(options[1].value).begins_with("+"),"a level's two options split into name and value by original Slot: "+str(options))
	var asked: Dictionary=window._ask("acquire",3,"currency")
	check(asked.get("ok",false) and host.hud.confirmations.size()==1 and runtime.executed==[["acquire",1,0,3,{"weapon":1,"payment":"currency"},"currency"]],"옵션 획득 confirms and executes the quoted plan: "+str(runtime.executed))
	window._ask("reset",0,"ticket")
	check(runtime.executed.size()==2 and runtime.executed[1][0]=="reset" and runtime.executed[1][5]=="ticket","변경 하기 (ticket) pays with the ticket")
	runtime.refuse={"purchase":"daily_purchase_limit"}
	asked=window._ask("purchase",0,"currency")
	check(not asked.get("ok",true) and host.hud.messages.has(runtime.reason_text("daily_purchase_limit")) and runtime.executed.size()==2,"a refused quote only shows its message")
	window._lock(2,0,false)
	check(runtime.locked==[[1,2,0,false]],"a lock tap saves through set_color_lock: "+str(runtime.locked))
	# A weapon whose level misses an option: the existing panel (부분 옵션 복구).
	runtime.state.weapons["2"]={"points":"0","options":[],"colors":{"1":[2,2,2,2]},"locks":{}}
	var routed: Dictionary=window._select(2)
	check(routed.get("native_panel",false) and host.hud.native==1,"a partially owned weapon opens the existing mastery panel: "+str(routed))
	var parent:=Node2D.new()
	root.add_child(parent)
	host.world.actual=2
	var opened: Dictionary=window.open(parent)
	check(opened.get("native_panel",false) and host.hud.native==2,"opening on a partially owned weapon opens the existing panel")
	parent.queue_free()
	# 사용자 목록 17: the weapon row's original gauge ring fills with the progress.
	var levels: Array=runtime.core.levels[1]
	var low: int=int(levels[1].CumulativePoint)
	var high: int=int(levels[2].CumulativePoint)
	runtime.state.weapons["1"]["points"]=str(low+(high-low)/2)
	var half: float=WINDOW.gauge_ratio(runtime,1)
	check(absf(half-float((high-low)/2)/float(high-low))<0.001,"the gauge ratio is the progress to the next level: "+str(half))
	runtime.state.weapons["1"]["points"]=str(int(levels[-1].CumulativePoint))
	check(is_equal_approx(WINDOW.gauge_ratio(runtime,1),1.0),"the last level fills the ring")
	var ring:=Sprite2D.new()
	ring.texture=ImageTexture.create_from_image(Image.create(8,8,false,Image.FORMAT_RGBA8))
	ring.rotation=PI
	var Radial=preload("res://scripts/ui/original_ui/source_radial_fill.gd")
	check(Radial.apply(ring,0.25) and is_equal_approx(float((ring.material as ShaderMaterial).get_shader_parameter("fill_ratio")),0.25),"the ring shows a quarter of its picture")
	check(is_equal_approx(float((ring.material as ShaderMaterial).get_shader_parameter("start_turn")),0.5),"a ring authored at 180 degrees still starts at the top of the screen")
	check(not Radial.apply(Sprite2D.new(),0.5),"no picture: nothing is drawn")
	ring.free()
	# The shared player takes a stated colour into its per-colour materials.
	var player: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(player.contains(".get(\"color\")") and not player.contains("instance uniform vec"),"the shared player reads a colour binding (no instance uniform)")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_feature(\"weapon_mastery\")") and renewal.contains("\"weapon_mastery\": open_weapon_mastery()"),"무기 숙련 opens the original window first")
	var main_hud: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_hud.contains("\"weapon_mastery\":preload(\"res://scripts/ui/original_ui/source_main_mastery_window.gd\")"),"the main HUD controller owns the window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_MASTERY_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

static func _source_rgba(root: Node, offset: int) -> Array:
	for node: Node in root.find_children("*","",true,false):
		if node.has_meta("original_ui_source") and int(node.get_meta("original_ui_source").get("node_offset",-1))==offset:return node.get_meta("source_rgba")
	return []

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	check(pack.manifest.get("externally_bound_texture_nodes",{}).get(WINDOW.WEAPON_ROW,[]).has(3640),"the weapon icon sprite is bound by code")
	var host: Dictionary=_host()
	var runtime: FakeRuntime=host.runtime
	_owned(runtime,1)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent)
	var filled: Dictionary=opened.get("filled",{})
	check(opened.get("handled",false),"Mastery_All mounts: "+str(opened))
	check(int(filled.get("weapons",0))==runtime.core.levels.size() and int(filled.get("option_rows",0))==2,"weapon rows and owned option rows: "+str(filled))
	var green: Array=WINDOW.grade_color(runtime,2)
	var shown: Array=_source_rgba(window._scene,58180)
	check(green.is_empty() or (shown.size()==4 and shown.slice(0,3)==green),"the field colour is the original table colour: "+str(shown)+" "+str(green))
	check(not window._spec().get("Btn_OptionGet",{}).get("visible",true) or WINDOW.claimable_level(runtime,1)>0,"옵션 획득 shows only for a claimable level")
	var helped: Dictionary=window._help(true)
	check(helped.get("handled",false) and window.help,"the help panel opens")
	check(window._help(false).get("handled",false) and not window.help,"Btn_Back returns to the detail panel")
	var other: int=int(runtime.core.levels.keys()[1])
	check(window._select(other).get("handled",false) and int(window.last_result.filled.option_rows)==0,"another weapon mounts with no owned rows")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
