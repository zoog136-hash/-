extends SceneTree
## Actual _stage/Scene.configure_nodes with synthetic scene metadata. This
## isolates UI node lifecycle from record decoding, fonts and private images.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_quest_window.gd")
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={"synthetic_metadata":true,"private_images":false}

class Pack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}
	var manifest_sha256: String="synthetic-only"
	var trees: Dictionary={}
	func scene(member: String) -> Dictionary:return trees.get(member,{})

class SceneWindow extends "res://scripts/ui/original_ui/source_main_quest_window.gd":
	# The list and its actual 60 source row scenes are production code. Detail
	# content is excluded to measure scene construction independently of images.
	func _page_bindings(_selected: Dictionary,_empty: bool) -> Dictionary:
		var scope: Array[int]=[LIST]
		return {"ok":true,"scope":scope,"bindings":{LIST:{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")}},"reward_owners":[]}

class Entries extends RefCounted:
	func entries(_level: int,_inventory: Dictionary) -> Array[Dictionary]:
		var rows: Array[Dictionary]=[]
		for i: int in 60:rows.append({"id":str(i),"source_id":i+1,"title":"Synthetic row "+str(i),"category":"main","available":true,"progress":1,"objective":{"count":1}})
		return rows

class World extends Node:
	var quest_service: RefCounted=Entries.new()
	var quest_auto: RefCounted
	var level: int=80
	var inventory: Dictionary={}

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

static func _node(offset: int,kind: String="Node") -> Dictionary:
	var widget: Dictionary={"name":"Synthetic"+str(offset),"actionTag":offset,"rotationSkew":[0.0,0.0],"zOrder":0,"visible":true,"alpha":255,"position":[0.0,0.0],"scale":[1.0,1.0],"anchorPoint":[0.0,0.0],"color":[255,255,255,255],"size":[450.0,80.0],"flipX":false,"flipY":false,"ignoreSize":false,"touchEnabled":kind in ["Panel","ListView"]}
	var options: Dictionary={"widgetOptions":widget}
	if kind in ["Panel","ListView"]:
		options.merge({"colorType":0,"backGroundImageData":{"path":""},"backGroundScale9Enabled":false,"clipEnabled":true})
	return {"_offset":offset,"classname":kind,"options":options,"children":[]}

func _pack() -> Pack:
	var pack:=Pack.new()
	var root_node: Dictionary=_node(99999)
	var offsets: Array=WINDOW.ROOT_SCOPE.duplicate()
	for value: int in WINDOW.TAB_LABELS.values():offsets.append(value)
	for value: int in WINDOW.TABS.mission:offsets.append(value)
	for offset: int in offsets:
		var node: Dictionary=_node(offset,"ProjectNode" if offset==WINDOW.MAIN_PROJECT else "Node")
		if offset==WINDOW.MAIN_PROJECT:node.options.merge({"fileName":WINDOW.TAB_MAIN,"innerActionSpeed":1.0})
		root_node.children.append(node)
	pack.trees[WINDOW.ROOT]={"nodeTree":root_node}
	var page: Dictionary=_node(99998)
	page.children.append(_node(WINDOW.LIST,"ListView"))
	page.children[0].options.widgetOptions.size=[450.0,460.0]
	pack.trees[WINDOW.TAB_MAIN]={"nodeTree":page}
	for member: String in WINDOW.ROWS:
		var row: Dictionary=_node(99997)
		var spec: Dictionary=WINDOW.ROWS[member]
		for key: String in spec:
			if int(spec[key])>=0:row.children.append(_node(int(spec[key]),"Panel" if key=="panel" else "Node"))
		pack.trees[member]={"nodeTree":row}
	for member: String in [WINDOW.ROOT,WINDOW.TAB_MAIN,WINDOW.ROW_REWARD,WINDOW.ROW_PROGRESS,WINDOW.ROW_COMPLETE,WINDOW.SLOT_SET]:pack.manifest.scenes[member]={}
	return pack

func _initialize() -> void:_run.call_deferred()

func _frames() -> void:
	await process_frame
	await process_frame

func _run() -> void:
	var pack: Pack=_pack()
	var host:=Node2D.new();root.add_child(host)
	var world:=World.new();root.add_child(world)
	var window:=SceneWindow.new()
	check(window.configure(pack,world).get("ok",false),"synthetic pack configures production window")
	var before: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	var result: Dictionary=window.open(host,world,Callable())
	evidence.ui_stage_usec=Time.get_ticks_usec()-started
	evidence.ui_static_growth=OS.get_static_memory_usage()-before
	check(result.get("ok",false) and window._row_scenes.size()==60,"actual stage builds all 60 original-row scene instances: "+str(result))
	if not result.get("ok",false):window.close();host.free();world.free();_finish();return
	var old_scene: WeakRef=weakref(window._scene)
	for i: int in 50:window.open(host,world,Callable())
	evidence.trees_after_50_opens=host.get_child_count()
	check(host.get_child_count()==1 and window._scene==old_scene.get_ref(),"repeated open creates no queued duplicate native trees")
	for i: int in 50:window._select_category("main" if i%2 else "common")
	evidence.trees_after_50_tabs=host.get_child_count()
	check(host.get_child_count()==1,"rapid categories retain one tree until frame callback")
	await _frames()
	check(host.get_child_count()==1 and old_scene.get_ref()==null and window._row_scenes.size()==60,"old tree is freed after the single tab replacement")
	window._select_quest("59")
	await _frames()
	check(window._selected_id=="59" and window._row_scenes.size()==60 and host.get_child_count()==1,"last row selection survives replacement without accumulated trees")
	var tree_ref: WeakRef=weakref(window._scene)
	window._select_quest("58")
	var callback: Callable=window._refresh_callback
	window.close()
	check(not process_frame.is_connected(callback),"close disconnects pending refresh signal")
	await _frames()
	check(tree_ref.get_ref()==null and host.get_child_count()==0,"close releases all native scene children")
	check(window.open(host,world,Callable()).get("ok",false),"native scene reopens after close")
	window.close();await _frames()
	# RefCounted callable ownership is checked, not assumed to be a cycle.
	for member: String in WINDOW.RoutinePage.REQUIRED:pack.manifest.scenes[member]={}
	window.configure(pack,world)
	var window_ref: WeakRef=weakref(window)
	var routine_ref: WeakRef=weakref(window._routine_page)
	window=null
	check(window_ref.get_ref()==null and routine_ref.get_ref()==null,"mission refresh callable does not retain window or page after owner release")
	host.free();world.free()
	_finish()

func _finish() -> void:
	print("QUEST_WINDOW_SCENE_LIFECYCLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
