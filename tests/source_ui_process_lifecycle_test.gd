extends SceneTree
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
class MissingTexturePack extends RefCounted:
	func texture(_reference: Dictionary, _required: bool) -> Texture2D:return null
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);printerr("SOURCE_UI_PROCESS_LIFECYCLE_FAIL ",message)
func _initialize() -> void:run.call_deferred()
func counted(legacy: bool) -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	if legacy:
		var first: int=source.find("var _playing:")
		var last: int=source.find("var _loop:",first)
		source=source.left(first)+"var _playing: bool=false\n"+source.substr(last)
		first=source.find("func _ready()")
		last=source.find("func configure_project",first)
		source=source.left(first)+source.substr(last)
	source=source.replace("extends Node2D\n","extends Node2D\nvar test_callbacks: int=0\n")
	source=source.replace("func _process(delta: float) -> void:\n","func _process(delta: float) -> void:\n\ttest_callbacks+=1\n")
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"actual renderer instrumented")
	return script
func player(script: Script=SCENE) -> Node2D:
	var p: Node2D=script.new()
	p.source_tree={"animationList":[{"name":"move","startIndex":0,"endIndex":60}],"action":{"duration":60,"timeLines":[]}}
	return p
func frames(count: int) -> void:
	for i: int in count:await process_frame
func callback_cost(_event: String) -> void:
	var at: int=HITCH.now()
	OS.delay_usec(2000)
	HITCH.add("items",at)
	OS.delay_usec(3000)
func run() -> void:
	var scripts: Array[Script]=[counted(true),counted(false)]
	var groups: Array=[[],[]]
	for kind: int in 2:
		for i: int in 128:
			var p: Node2D=player(scripts[kind]);groups[kind].append(p);root.add_child(p)
	await frames(2)
	for group: Array in groups:
		for p: Node2D in group:p.test_callbacks=0
	await frames(8)
	var calls: Array[int]=[0,0]
	for kind: int in 2:
		for p: Node2D in groups[kind]:
			calls[kind]+=p.test_callbacks
			check(p._frame==0 and not p._playing,"idle frame/pixels retained")
	check(calls[0]>=128*7 and calls[1]==0,"engine dispatch removed only for inactive scenes")
	for group: Array in groups:
		for p: Node2D in group:p.free()
	var p: Node2D=player()
	root.add_child(p)
	check(not p.is_processing(),"new attached static scene disabled")
	check(p.play("move",true).ok and p.is_processing(),"play enables engine processing")
	await frames(3)
	check(p._frame>0 and p._playing,"engine advances live animation")
	p.stop()
	var stopped: float=p._frame
	await frames(3)
	check(not p.is_processing() and p._frame==stopped,"stop retains frame through engine steps")
	p.seek_frame(17)
	check(not p.is_processing() and p._frame==17,"manual seek remains usable without waking clock")
	check(not p.play("missing").ok and not p.is_processing(),"missing clip remains stopped")
	p.play("move",false);p._process(2.0)
	check(not p._playing and not p.is_processing() and p._frame==60,"natural end delivers terminal frame and sleeps")
	p.play("move",true);p._process(2.0)
	check(p._playing and p.is_processing() and p._frame==0,"loop resets without carrying overshoot")
	p.hide();var hidden_frame: float=p._frame
	await frames(3)
	check(p._frame>hidden_frame,"hidden playing scene keeps authored clock")
	p.stop();root.remove_child(p);root.add_child(p)
	check(not p.is_processing(),"stopped re-entry remains stopped")
	p.free()
	p=player();p.play("move",true);root.add_child(p)
	check(p.is_processing(),"play before tree entry survives ready")
	p.free()
	# Parent's actual ActionValue path directly assigns child playback state.
	for kind: int in [0,1,2]:
		var parent: Node2D=player();var child: Node2D=player()
		var target:=Node2D.new();parent.add_child(target);target.add_child(child)
		target.set_meta("source_project_player",child);parent._tags={7:target}
		parent.source_tree.action.timeLines=[{"property":"ActionValue","actionTag":7,"_offset":1,"frames":[{"innerActionFrame":{"frameIndex":0,"_offset":2,"innerActionType":kind,"currentAniamtionName":"move","singleFrameIndex":11}}]}]
		root.add_child(parent);parent.seek_frame(0)
		check(child._playing==(kind!=2) and child.is_processing()==(kind!=2),"nested action controls scheduler: %d"%kind)
		check(child._frame==(11 if kind==2 else 0),"nested action start/single frame retained")
		parent.free()
	# Real callback cancellation must disable future dispatch immediately.
	p=player();var target:=Node2D.new();p.add_child(target);p._tags={1:target}
	p.source_tree.action.timeLines=[{"property":"FrameEvent","actionTag":1,"_offset":3,"frames":[{"eventFrame":{"frameIndex":1,"_offset":4,"value":"stop"}}]}]
	p._bindings={"frame_events":{4:p.stop.unbind(1)}}
	root.add_child(p);p.play("move",true);p._process(1.0/60.0)
	check(not p.is_processing() and not p._playing,"callback stop controls scheduler")
	p.free()
	p=player();target=Node2D.new();p.add_child(target);p._tags={1:target}
	p.source_tree.action.timeLines=[{"property":"FrameEvent","actionTag":1,"_offset":3,"frames":[{"eventFrame":{"frameIndex":1,"_offset":4,"value":"sample"}}]}]
	p._bindings={"frame_events":{4:callback_cost}}
	root.add_child(p)
	HITCH.reset_for_test("user://ui_process_test")
	HITCH.frame("ui");p.play("move",true);p._process(1.0/60.0)
	HITCH.backdate_frame_for_test(120000);HITCH.frame("ui")
	var sections: Dictionary={}
	for part: Array in HITCH.summary().worst[0].sections:sections[part[0]]=part[1]
	check(sections.get("ui_animation",0)>=2 and sections.get("items",0)>=1,"actual UI clock accounted excluding nested callback section")
	p.free()
	p=player();target=Node2D.new();p.add_child(target);p._tags={1:target}
	var sprite:=Sprite2D.new();target.add_child(sprite);target.set_meta("source_sprite",sprite)
	p.source_pack=MissingTexturePack.new()
	p.source_tree.action.timeLines=[{"property":"FileData","actionTag":1,"frames":[{"textureFrame":{"frameIndex":1,"textureFile":{}}}]}]
	root.add_child(p);p.play("move",true);p._process(1.0/60.0)
	check(not p._playing and not p.is_processing(),"texture failure sleeps without replacement pixels")
	p.free()
	print("SOURCE_UI_PROCESS_LIFECYCLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"idle_callbacks":calls,"scenes_per_group":128,"engine_frames":8}))
	quit(0 if failures.is_empty() else 1)
