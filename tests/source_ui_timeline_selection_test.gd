extends SceneTree
## Compile an in-memory selector oracle (Cocos: a frame before the first
## keyframe enters that keyframe); execute actual seek_frame paths.
## No persistent production cache, private source files or Android claims.
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const OLD_SELECTION="""		var selected: Dictionary={}
		for raw: Dictionary in timeline.frames:
			var value: Dictionary=_frame_value(raw)
			if float(value.frameIndex)<=frame_number and (selected.is_empty() or float(value.frameIndex)>=float(selected.frameIndex)): selected=value
		var first_entry: bool=false
		if selected.is_empty():
			# Cocos enters the first keyframe before it (events / inner actions excepted).
			if timeline.property in ["FrameEvent","ActionValue"]: continue
			for raw: Dictionary in timeline.frames:
				var first_value: Dictionary=_frame_value(raw)
				if selected.is_empty() or float(first_value.frameIndex)<float(selected.frameIndex): selected=first_value
			if selected.is_empty(): continue
			first_entry=true
		var following: Dictionary={}
		for raw: Dictionary in timeline.frames:
			var value: Dictionary=_frame_value(raw)
			if not first_entry and float(value.frameIndex)>float(selected.frameIndex) and (following.is_empty() or float(value.frameIndex)<float(following.frameIndex)): following=value
"""
class Pack extends RefCounted:
	var manifest: Dictionary={}
	var manifest_sha256: String=""
	var tree: Dictionary={}
	func scene(_member: String) -> Dictionary:return tree.duplicate(true)
var checks: int=0
var failures: Array[String]=[]
var decode_proofs: int=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_UI_TIMELINE_SELECTION_FAIL ",label)
func _initialize() -> void:run.call_deferred()
func instrument(old: bool) -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	var begin: int=source.find("\t\tvar selected: Dictionary={}",source.find("func _seek_frame("))
	var end: int=source.find("\t\tvar ratio: float=0.0",begin)
	check(begin>=0 and end>begin,"actual selector source located")
	if old:source=source.left(begin)+OLD_SELECTION+source.substr(end)
	# Count actual union decoder calls in test copies, never a production hook.
	source=source.replace("extends Node2D\n","extends Node2D\nvar _test_decodes: int=0\n")
	var indent: String="\t\t\t" if old else "\t\t\t\t"
	source=source.replace("\n"+indent+"var value: Dictionary=_frame_value(raw)","\n"+indent+"_test_decodes+=1\n"+indent+"var value: Dictionary=_frame_value(raw)")
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"instrumented actual scene compiles")
	return script
func player(script: Script) -> Node2D:
	var result: Node2D=script.new()
	var target:=Node2D.new();target.name="Target";result.add_child(target)
	result.set("_tags",{10:target});result.set_process(false)
	return result
func action(indices: Array, tween: bool) -> Dictionary:
	var positions: Array=[]
	var events: Array=[]
	for i: int in indices.size():
		positions.append({"pointFrame":{"_type":"PointFrame","frameIndex":indices[i],"postion":[float(i*11+7),float(i*3-5)],"tween":tween,"easingData":{"type":0},"_offset":i+100}})
		events.append({"eventFrame":{"_type":"EventFrame","frameIndex":indices[i],"value":"event_%d"%i,"tween":false,"_offset":i+200}})
	return {"action":{"duration":100,"timeLines":[{"property":"Position","actionTag":10,"_offset":1,"frames":positions},{"property":"FrameEvent","actionTag":10,"_offset":2,"frames":events}]}}
func compare(players: Array[Node2D], tree: Dictionary, at: float) -> void:
	var bytes: PackedByteArray=var_to_bytes(tree)
	for p: Node2D in players:
		p.set("source_tree",tree)
		p.get_node("Target").position=Vector2(999,-999)
		if "_test_decodes" in p:p.set("_test_decodes",0)
		p.call("seek_frame",at)
	var oracle: Node2D=players[0]
	for p: Node2D in players.slice(1):
		check(p.get_node("Target").position==oracle.get_node("Target").position,"position/tween predecessor-successor equivalence at %s"%at)
		check(p.get("_entered_frames")==oracle.get("_entered_frames"),"last duplicate event selection equivalence")
		check(p.get("_frame")==oracle.get("_frame"),"requested frame retained")
	check(var_to_bytes(tree)==bytes,"live source remains unchanged")
	var timelines: Array=tree.get("action",{}).get("timeLines",[])
	var expected_old: int=0
	var expected_new: int=0
	for timeline: Dictionary in timelines:
		var selected: bool=false
		for raw: Dictionary in timeline.frames:
			if float(SCENE._frame_value(raw).frameIndex)<=at:selected=true
		expected_new+=timeline.frames.size()
		var first_entry: bool=not selected and not timeline.frames.is_empty() and str(timeline.property) not in ["FrameEvent","ActionValue"]
		expected_old+=timeline.frames.size()*(2 if selected or first_entry else 1)
	check(int(oracle.get("_test_decodes"))==expected_old,"old actual decoder calls")
	check(int(players[1].get("_test_decodes"))==expected_new,"one actual decoder call per live frame")
	decode_proofs+=1
func failures_unchanged() -> void:
	for malformed: Dictionary in [{},{"pointFrame":{"_type":"PointFrame","frameIndex":0},"scaleFrame":{"_type":"ScaleFrame","frameIndex":0}}]:
		var pack:=Pack.new()
		pack.tree={"nodeTree":{"classname":"Node","options":{"rotationSkew":[0,0]}},"action":{"timeLines":[{"property":"Position","actionTag":10,"frames":[malformed]}]}}
		var p:=SCENE.new();var result: Dictionary=p.configure(pack,"synthetic")
		check(not result.get("ok",false) and result.get("details",[]).has("unsupported_frame_union"),"missing/ambiguous union still rejected before scene commit")
		check(p.source_tree.is_empty() and p.get_child_count()==0,"invalid scene creates no nodes")
		p.free()
	var pack:=Pack.new();pack.tree={"nodeTree":{"classname":"Node","options":{"rotationSkew":[0,0]}},"action":{"timeLines":[{"property":"Unknown","actionTag":10,"frames":[]}]}}
	var p:=SCENE.new();var result: Dictionary=p.configure(pack,"synthetic")
	check(not result.get("ok",false) and result.get("details",[]).has("unsupported_timeline:Unknown"),"unknown property remains rejected")
	p.free()
func ordered_configuration(counted: Script) -> void:
	var times: Array=[]
	for i: int in 64:times.append(float(i>>1))
	var tree: Dictionary=action(times,true)
	var widget: Dictionary={"name":"Indexed","actionTag":10,"rotationSkew":[0.0,0.0],"zOrder":0,"visible":true,"alpha":255,"position":[0,0],"scale":[1,1],"anchorPoint":[0,0],"color":[255,255,255,255],"size":[0,0]}
	tree["nodeTree"]={"classname":"Node","_offset":10,"options":widget,"children":[]}
	var source:=Pack.new()
	source.tree=tree
	var indexed: Node2D=counted.new()
	var scan: Node2D=counted.new()
	var configured: Dictionary=indexed.configure(source,"ordered",true)
	var scan_result: Dictionary=scan.configure(source,"ordered",true)
	check(configured.get("ok",false) and scan_result.get("ok",false),"ordered original shape configures")
	if configured.get("ok",false) and scan_result.get("ok",false):
		check(indexed.get("_indexed_keyframes").size()==2,"both long ordered tracks indexed")
		scan.set("_indexed_keyframes",{})
		for at: float in [-1.0,0.0,0.2,1.0,11.5,31.0,32.0,INF,NAN,0.0]:
			indexed.set("_test_decodes",0)
			scan.set("_test_decodes",0)
			indexed.seek_frame(at)
			scan.seek_frame(at)
			check(indexed.source_nodes[10].position==scan.source_nodes[10].position and indexed.get("_entered_frames")==scan.get("_entered_frames"),"ordered seek matches scan at %s"%at)
			check(is_nan(at) or (indexed.get("_test_decodes")==0 and scan.get("_test_decodes")==128),"indexed seeks skip the original frame union decoding")
		check(var_to_bytes(indexed.source_tree)==var_to_bytes(tree),"the indexed tree still contains the exact authored records")
		indexed.source_tree=action([0,4,8],true)
		check(indexed.get("_indexed_keyframes").is_empty(),"replacing the source tree clears the old track index")
	indexed.free()
	scan.free()
	# An unordered long track keeps the serialized tie order via the scan.
	source.tree=tree.duplicate(true)
	source.tree.action.timeLines[0].frames.reverse()
	var unordered: Node2D=counted.new()
	var unordered_result: Dictionary=unordered.configure(source,"unordered",true)
	check(unordered_result.get("ok",false) and unordered.get("_indexed_keyframes").keys()==[1],"only the ordered track is indexed")
	unordered.free()
func run() -> void:
	var old:=instrument(true)
	var counted:=instrument(false)
	var players: Array[Node2D]=[player(old),player(counted),player(SCENE)]
	var patterns: Array=[[],[0],[3,0,3,-2,8,8,1],[1,1,1,1],[-2.5,0.25,0.25,4.75]]
	var dense: Array=[]
	for i: int in 64:dense.append(float((i*37)%17)-8.0)
	patterns.append(dense)
	for indices: Array in patterns:
		for tween: bool in [false,true]:
			var tree: Dictionary=action(indices,tween)
			for at: float in [-10.0,-2.5,-2.0,-0.25,0.0,0.125,0.25,0.5,1.0,2.0,3.0,3.5,4.75,8.0,10.0,100.0]:compare(players,tree,at)
	var mutable: Dictionary=action([0,4,8],true)
	compare(players,mutable,2)
	mutable.action.timeLines[0].frames[0].pointFrame.postion=[70.0,30.0]
	mutable.action.timeLines[0].frames[1].pointFrame.frameIndex=1.5
	mutable.action.timeLines[1].frames.reverse()
	compare(players,mutable,2)
	# Missing tags skip their tracks; an absent action leaves visible state alone.
	for p: Node2D in players:p.set("_tags",{})
	compare(players,action([0,4],true),1)
	compare(players,{},1)
	for p: Node2D in players:p.free()
	ordered_configuration(counted)
	failures_unchanged()
	print("SOURCE_UI_TIMELINE_SELECTION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"decode_comparisons":decode_proofs,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
