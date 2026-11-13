extends SceneTree
## Execute the old/new production selector, instrument only its actual copy
## input in in-memory scripts. Synthetic trees, no Android timing assertions.
const SCOPE=preload("res://scripts/ui/original_ui/source_node_scope.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const OLD_BLOCK="""	var scoped: Dictionary=tree.duplicate(false)
	scoped.nodeTree={}
	scoped=scoped.duplicate(true)
	scoped.nodeTree=node
	scoped["_selected_source_offsets"]=offsets.duplicate()
	scoped["_partial_source_scene"]=true
	if scoped.get("action") is Dictionary and scoped.action.get("timeLines") is Array:
		var tracks: Array=[]
		for track: Dictionary in scoped.action.timeLines:
			if action_tags.has(int(track.get("actionTag",0))):tracks.append(track)
		scoped.action.timeLines=tracks
"""
class Pack extends RefCounted:
	var manifest: Dictionary={}
	var manifest_sha256: String="synthetic"
	var value: Dictionary={}
	func scene(_member: String) -> Dictionary:return value.duplicate(true)

var checks: int=0
var failures: Array[String]=[]
var samples: Array=[]
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func compiled(old: bool) -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_node_scope.gd")
	var begin: int=source.find("\tvar scoped: Dictionary=tree.duplicate(false)")
	var end: int=source.find("\t# Durations, speed",begin)
	check(begin>=0 and end>begin,"production copy block located")
	if old:source=source.left(begin)+OLD_BLOCK+source.substr(end)
	source=source.replace("extends RefCounted\n","extends RefCounted\nstatic var copied_frames: int=0\nstatic var copied_tracks: int=0\n")
	source=source.replace("\tscoped=scoped.duplicate(true)","""	if scoped.get("action") is Dictionary and scoped.action.get("timeLines") is Array:
		for track: Dictionary in scoped.action.timeLines:
			copied_tracks+=1
			copied_frames+=track.get("frames",[]).size()
	scoped=scoped.duplicate(true)""")
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"instrumented selector compiles")
	return script
func node(offset: int, children: Array=[]) -> Dictionary:
	return {"_offset":offset,"classname":"Node","options":{"actionTag":offset,"position":[offset,0],"rotationSkew":[0,0],"name":"node_%d"%offset,"size":[20,20],"scale":[1,1],"visible":true,"zOrder":0,"color":[255,255,255,255],"alpha":255,"anchorPoint":[0,0],"nested":{"values":[1,2]}},"children":children}
func tree(branches: int, frames: int) -> Dictionary:
	var children: Array=[]
	var tracks: Array=[]
	for index: int in branches:
		children.append(node(index+2))
		var values: Array=[]
		for frame: int in frames:values.append({"intFrame":{"_type":"IntFrame","frameIndex":frame,"value":(index+frame)%256,"payload":PackedByteArray([1,2,3])}})
		tracks.append({"actionTag":index+2,"property":"Alpha","frames":values})
	return {"schema":7,"nodeTree":node(1,children),"action":{"duration":frames,"timeLines":tracks,"speed":1.25,"metadata":{"order":[1,2,3]}},"animationList":[{"name":"original","startIndex":0,"endIndex":frames}],"metadata":{"values":[{"value":123}]},"_source_sha256":"synthetic-not-original"}
func equal_result(old: Script, fresh: Script, input: Dictionary, offsets: Array[int]) -> Dictionary:
	var before: PackedByteArray=var_to_bytes(input)
	var expected: Dictionary=old.select(input,offsets)
	var result: Dictionary=fresh.select(input,offsets)
	check(var_to_bytes(expected)==var_to_bytes(result),"old/new ordered result bytes including errors identical")
	check(var_to_bytes(SCOPE.select(input,offsets))==var_to_bytes(expected),"uninstrumented production matches oracle")
	check(var_to_bytes(input)==before,"input dictionaries and arrays unchanged")
	return result
func run() -> void:
	HITCH.reset_for_test("user://scope_copies_test")
	var old:=compiled(true)
	var fresh:=compiled(false)
	for size: int in [4,32,128]:
		var input: Dictionary=tree(size,64)
		for values: Array in [[2],[1],[size+1,2],[2,2],[999],[]]:
			var requested: Array[int]=[]
			requested.assign(values)
			old.copied_frames=0;fresh.copied_frames=0
			old.copied_tracks=0;fresh.copied_tracks=0
			var result: Dictionary=equal_result(old,fresh,input,requested)
			if not result.get("ok",false):continue
			check(old.copied_frames==size*64,"old actual copy includes every timeline frame")
			var retained_tracks: int=result.tree.action.timeLines.size()
			check(fresh.copied_frames==retained_tracks*64 and fresh.copied_tracks==retained_tracks,"new actual copy includes only retained tracks and frames")
			if requested==[2]:samples.append({"input_tracks":size,"frames_per_track":64,"old_copied_frames":old.copied_frames,"new_copied_frames":fresh.copied_frames})
			var baseline: PackedByteArray=var_to_bytes(input)
			result.tree.action.metadata.order[0]=99
			result.tree.animationList[0].name="changed"
			result.tree.metadata.values[0].value=-1
			result.tree.nodeTree.options.nested.values[0]=99
			if not result.tree.action.timeLines.is_empty():
				result.tree.action.timeLines[0].frames[0].intFrame.value=999
				result.tree.action.timeLines[0].frames[0].intFrame.payload[0]=99
			check(var_to_bytes(input)==baseline,"all retained action/node/metadata/packed bytes remain independently owned")
	# Preserve unusual but previously accepted action shapes and duplicate tags.
	for action: Variant in [null,{},[],"serialized",{"timeLines":null},{"timeLines":"serialized"},{"timeLines":[]},{"timeLines":[{"actionTag":0,"frames":[]},{"actionTag":2,"frames":[]}]}]:
		var input: Dictionary=tree(4,2)
		input.action=action
		equal_result(old,fresh,input,[2])
	var input: Dictionary=tree(4,2)
	input.erase("action")
	equal_result(old,fresh,input,[2])
	input=tree(4,2)
	input.nodeTree.children[1].options.actionTag=2
	equal_result(old,fresh,input,[2,3])
	input.nodeTree.children.append(node(2))
	equal_result(old,fresh,input,[2])
	_render_contract(old)
	check(HITCH._details.has("ui.scene_scope"),"scope work has bounded inclusive diagnostic")
	print("SOURCE_SCOPE_TRACK_COPIES_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"android_measured":false}))
	quit(0 if failures.is_empty() else 1)

func _render_contract(old: Script) -> void:
	var input: Dictionary=tree(8,32)
	# An invalid unselected track was discarded by the old selector too.
	input.action.timeLines[6].property="unselected-invalid"
	var requested: Array[int]=[2,5]
	var expected: Dictionary=old.select(input,requested)
	var old_pack:=Pack.new();old_pack.value=expected.tree
	var new_pack:=Pack.new();new_pack.value=input
	var a:=SCENE.new();var b:=SCENE.new()
	check(a.configure_nodes(old_pack,"synthetic",[2,5],{})==b.configure_nodes(new_pack,"synthetic",[2,5],{}),"actual renderer configuration result equals previous projection")
	check(not a.source_tree.is_empty() and not b.source_tree.is_empty(),"both actual source scenes build")
	check(var_to_bytes(a.source_tree)==var_to_bytes(b.source_tree),"actual renderer stores byte-equivalent independent source descriptors")
	for frame: float in [0.0,0.5,1.0,7.5,31.0,44.0]:
		a.seek_frame(frame);b.seek_frame(frame)
		check(a.source_nodes.keys()==b.source_nodes.keys(),"rendered nodes retain source order")
		for offset: int in a.source_nodes:
			var an: Node2D=a.source_nodes[offset];var bn: Node2D=b.source_nodes[offset]
			check(an.transform==bn.transform and an.modulate==bn.modulate and an.visible==bn.visible,"live transforms/alpha/visibility match at selected frame")
	# Independent player state remains local after identical source selection.
	a.seek_frame(2.0)
	check(b._frame==44.0,"one renderer's seek never changes the other playback state")
	a.free();b.free()
