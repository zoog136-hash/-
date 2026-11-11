extends SceneTree
## Field HUD pieces that the original 523 main UI now presents.
## Without arguments: the original Text "transfer" metadata rule and the
## TWILIGHT joystick's display switch (no original files needed).
## Real input: -- --pack=<private original main UI pack directory>
## (built by tools/ui/build_client523_main_ui_pack.py): the original system
## message boxes and the original movement pad mount and follow the game.
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE_SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const SYSTEM_MESSAGE=preload("res://scripts/ui/original_ui/source_main_system_message_bindings.gd")
const JOYSTICK_VIEW=preload("res://scripts/ui/original_ui/source_main_joystick_view.gd")
const JOYSTICK=preload("res://scripts/virtual_joystick.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={}
	var manifest_sha256: String=""
	var tree: Dictionary={}
	func scene(_member: String) -> Dictionary:
		return tree.duplicate(true)
	func font(_reference: Dictionary) -> FontFile:
		return null
	func texture(_reference: Dictionary, _cocos: bool=false) -> Texture2D:
		return null

class FakeHud extends Node:
	var message_label: Label

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_transfer_metadata()
	await _joystick_display_switch()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_HUD_FIELD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

static func _widget(name: String, custom: String) -> Dictionary:
	return {"name":name,"actionTag":0,"rotationSkew":[0.0,0.0],"zOrder":0,"visible":1,"alpha":255,"position":[0.0,0.0],"scale":[1.0,1.0],"anchorPoint":[0.5,0.5],"color":[255,255,255,255],"size":[10.0,10.0],"flipX":0,"flipY":0,"ignoreSize":0,"touchEnabled":0,"frameEvent":"","customProperty":custom,"callBackType":null,"callBackName":null}

func _configure_text(classname: String, custom: String) -> Dictionary:
	var pack:=FakePack.new()
	var child: Dictionary={"_offset":124,"classname":classname,"children":[],"options":{"widgetOptions":_widget("Text_Line",custom),"fontSize":20,"text":"x","fontResource":{"path":""}}}
	pack.tree={"nodeTree":{"_offset":76,"classname":"Node","children":[child],"options":{"nodeOptions":_widget("Node","")}}}
	var scene:=SOURCE_SCENE.new()
	var result: Dictionary=scene.configure(pack,"UI/Synthetic.csb",false,{124:{"role":"source_text","text":"x"}})
	scene.free()
	return result

func _transfer_metadata() -> void:
	# Validation passes; the synthetic pack has no font, so building stops later.
	var accepted: Dictionary=_configure_text("Text",'{"transfer":"false"}')
	check(accepted.get("error")!="unsupported_source_scene","Text transfer metadata is accepted: "+str(accepted))
	for case: Array in [["Text",'{"transfer":"maybe"}'],["Text",'{"transfer":"false","shader":"x"}'],["Sprite",'{"transfer":"true"}']]:
		var rejected: Dictionary=_configure_text(case[0],case[1])
		check(rejected.get("error")=="unsupported_source_scene" and "custom_property" in rejected.get("details",[]),"other custom properties stay rejected: "+str(case))

func _joystick_display_switch() -> void:
	var stick=JOYSTICK.new()
	root.add_child(stick)
	stick.size=Vector2(160,160)
	stick.draw_visual=false
	var values: Array=[]
	stick.vector_changed.connect(func(value: Vector2) -> void: values.append(value))
	var touch:=InputEventScreenTouch.new()
	touch.index=0;touch.pressed=true;touch.position=Vector2(150,80)
	stick._gui_input(touch)
	check(stick.value.is_equal_approx(Vector2.RIGHT) and not values.is_empty(),"a hidden-drawing joystick still moves: "+str(stick.value))
	touch.pressed=false
	stick._gui_input(touch)
	check(stick.value==Vector2.ZERO,"release still stops")
	stick.queue_free()
	await process_frame

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var opened: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(opened.get("ok",false),"pack opens: "+str(opened))
	if not opened.get("ok",false):return
	var coordinates:=Node2D.new()
	coordinates.position=Vector2(0,675)
	root.add_child(coordinates)
	# Original system message boxes (priority 1 top, 2 bottom) with live text.
	var hud:=FakeHud.new()
	hud.message_label=Label.new()
	hud.message_label.text="시스템 메시지"
	hud.add_child(hud.message_label)
	root.add_child(hud)
	for priority: int in [1,2]:
		var contract: Dictionary=SYSTEM_MESSAGE.build(pack,hud,priority)
		check(contract.get("ok",false),"system message contract %d: %s" % [priority,contract])
		if not contract.get("ok",false):continue
		var scope: Array[int]=[]
		scope.assign(contract.source_node_offsets)
		var scene:=SOURCE_SCENE.new()
		var mounted: Dictionary=scene.configure_project(pack,contract.parent_member,contract.parent_project_offset,contract.bindings,scope)
		check(mounted.get("ok",false),"original system message %d mounts: %s" % [priority,mounted])
		if not mounted.get("ok",false):scene.free();continue
		coordinates.add_child(scene)
		hud.message_label.text="다음 메시지"
		check(SYSTEM_MESSAGE.refresh(scene,hud).get("ok",false),"system message %d follows the existing label" % priority)
		scene.queue_free()
	# Original movement pad over the existing joystick.
	if not JOYSTICK_VIEW.available(pack):
		check(false,"the pack carries "+JOYSTICK_VIEW.MEMBER)
		return
	var host:=Control.new()
	host.size=Vector2(1200,675)
	root.add_child(host)
	var stick=JOYSTICK.new()
	host.add_child(stick)
	stick.position=Vector2(20,476);stick.size=Vector2(160,160)
	var view=JOYSTICK_VIEW.new()
	var shown: Dictionary=view.open(pack,coordinates,stick)
	check(shown.get("ok",false) and shown.get("handled",false),"original movement pad mounts: "+str(shown))
	if not shown.get("handled",false):return
	await process_frame
	view.refresh()
	check(not stick.draw_visual,"TWILIGHT joystick drawing is off while the original pad is shown")
	var pad: Node2D=view._scene.source_nodes[JOYSTICK_VIEW.PAD]
	var centre: Vector2=pad.get_global_transform_with_canvas().origin
	check(stick.get_global_rect().get_center().distance_to(centre)<1.0,"the existing touch area sits on the original pad: %s vs %s" % [stick.get_global_rect(),centre])
	var knob: Node2D=view._scene.source_nodes[JOYSTICK_VIEW.KNOB]
	var rest: Vector2=knob.position
	stick._set_value(Vector2.RIGHT)
	view.refresh()
	check(knob.position.x>rest.x and is_equal_approx(knob.position.y,rest.y),"the original knob follows the joystick")
	check(view._scene.playback_status().get("playing",false),"the original arrow loop plays while moving")
	stick._set_value(Vector2.ZERO)
	view.refresh()
	check(knob.position==rest,"the knob returns to rest")
	view.close()
	check(stick.draw_visual and stick.position==Vector2(20,476),"closing restores the existing joystick")
	host.queue_free();coordinates.queue_free();hud.queue_free()
	await process_frame
