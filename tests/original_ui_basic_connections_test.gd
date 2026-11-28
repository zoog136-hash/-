extends SceneTree
## Run with TWILIGHT_SOURCE_UI and TWILIGHT_SOURCE_UI_SHA256 for original-pixel
## checks, or without the optional pack to check offline routing and fallback.
const DETAIL=preload("res://scripts/ui/original_ui/source_main_skill_detail.gd")
const SKILL=preload("res://scripts/ui/original_ui/source_main_skill_window.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const HUD=preload("res://scripts/ui/renewal_hud.gd")
const TILES=preload("res://scripts/ui/original_ui/source_main_menu_tiles.gd")
const ROUTER=preload("res://scripts/ui/original_ui/source_button_router.gd")
class SkillHost extends Node:
	var action_skill: String=""
	func open_skills_workspace(id: String) -> void:
		action_skill=id
class EmptyPack extends RefCounted:
	var manifest: Dictionary={}
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
	run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var host:=SkillHost.new()
	root.add_child(host)
	var detail=DETAIL.new()
	var record: Dictionary={"id":"probe","name":"테스트 스킬","mp":14,"cooldown":1.25,"class":"기사","desc":"기본 설명"}
	var rows: Array=DETAIL.readout(record,record)
	check(["MP","14"] in rows and ["재사용","1.2초"] in rows and ["","기본 설명"] in rows,"the rows show selected skill values")
	check(not detail.open(EmptyPack.new(),host,record,host,func()->void:pass).ok,"missing add-on retains fallback")
	check(HUD.ORIGINAL_MENU_CELLS[12]=="memory_places","remembered places is original row 3 column 3")
	check(not HUD.ORIGINAL_MENU_CELLS.has("attendance") and not HUD.ORIGINAL_MENU_CELLS.has("pass"),"no attendance or pass")
	check(TILES.member_of("memory_places")=="UI/CsbFile/MainMenu/MainMenu_Memory.csb","memory uses the actual asset cell")
	var path: String=OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String=OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	var real: bool=not path.is_empty() and not sha.is_empty()
	if real:
		var pack=PACK.new()
		var opened: Dictionary=pack.open(path,sha)
		check(opened.get("ok",false),"original pack opens: "+str(opened.get("code","")))
		if opened.get("ok",false):
			await verify_original(pack,host,record)
	host.queue_free()
	await process_frame
	print("ORIGINAL_UI_BASIC_CONNECTIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_pack":real}))
	quit(0 if failures.is_empty() else 1)

func verify_original(pack: RefCounted,host: SkillHost,record: Dictionary) -> void:
	var window=SKILL.new()
	window._pack=pack
	window._hud=weakref(host)
	window._scene=Node2D.new()
	host.add_child(window._scene)
	window._records.assign([record])
	window._selected=str(record.id)
	window._scroll=-67.0
	var epoch: int=window._scene.get_instance_id()
	var result: Dictionary=window.open_original_detail(host,record,Callable())
	if not pack.manifest.get("scenes",{}).has(DETAIL.MEMBER):
		check(not result.get("ok",false) and window._detail_requested().get("existing_skill_window",false) and host.action_skill=="probe","an installed older pack keeps the existing skill actions")
		return
	check(result.get("handled",false) and result.get("member","")==DETAIL.MEMBER,"the skill detailed-view callback mounts the original popup: "+str(result))
	if not window.detail_is_open():return
	var scene: Node2D=window._detail._scene
	check(not window._scene.visible and not window.gesture_is_live(epoch),"covered list does not accept drags")
	check(scene.source_nodes.has(18428) and not scene.source_nodes.has(3152),"original title, no help")
	check(host.action_skill.is_empty(),"viewing details does not use or learn it")
	await process_frame
	var button: Node=scene.source_nodes[316].get_meta("source_button")
	var position: Vector2=button.get("_input_area").get_global_rect().get_center()
	var router=ROUTER.new()
	for pressed: bool in [true,false]:
		var t:=InputEventScreenTouch.new()
		t.index=0
		t.position=position
		t.pressed=pressed
		check(router.route(t,position,[button]).get("handled",false),"real close button owns touch")
	check(not window.detail_is_open() and window._scene.visible and window._scroll==-67.0 and window._selected=="probe","closing restores selected list at the same scroll")
	check(window._slot_pressed("probe").get("selected")=="probe" and host.action_skill.is_empty(),"a repeated slot tap stays in the original list")
	check(window._detail_requested().get("existing_skill_window",false) and host.action_skill=="probe","the detail action opens the focused skill workspace")
	var tiles=TILES.new()
	tiles.configure(pack)
	var tile: Dictionary=tiles.tile("memory_places")
	check(tile.get("ok",false) and tile.get("member","")==TILES.member_of("memory_places"),"real memory tile mounts")
	if is_instance_valid(tile.get("scene")):tile.scene.free()
