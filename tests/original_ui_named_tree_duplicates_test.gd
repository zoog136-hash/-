extends SceneTree
## Original UI name-path binding names nodes uniquely: sibling nodes that
## share a name path are recorded (duplicate_paths) instead of silently
## overwritten, each node has a unique member|chain|offset key, locate_exact
## refuses a suffix that selects more than one node, ambiguous_suffixes
## lists spec suffixes landing on several nodes, and inert buttons (no spec
## action) are listed with their callback names. locate keeps its old
## result. Synthetic only (no original files).
##   godot --headless --path <repo> --script res://tests/original_ui_named_tree_duplicates_test.gd
const NAMED=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{},"externally_bound_texture_nodes":{}}
	var trees: Dictionary={}
	func scene(member: String) -> Dictionary:
		return trees.get(member,{})

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_NAMED_TREE_DUPLICATES_FAIL: "+label)

func _node(offset: int, kind: String, name: String, children: Array=[], extra: Dictionary={}) -> Dictionary:
	var widget: Dictionary={"name":name}
	widget.merge(extra,true)
	var options: Dictionary={"widgetOptions":widget}
	if kind=="ProjectNode":options["fileName"]=str(extra.get("file",""))
	return {"_offset":offset,"classname":kind,"options":options,"children":children}

func _initialize() -> void:
	var pack:=FakePack.new()
	pack.trees["UI/Row.csb"]={"nodeTree":{"children":[_node(10,"Panel","Panel",[_node(11,"Button","Btn_Ok",[],{"callBackName":"onOk"}),_node(12,"Text","Label")])]}}
	pack.trees["UI/Win.csb"]={"nodeTree":{"children":[_node(1,"Panel","Root",[
		_node(2,"Node","Nd_A",[_node(3,"Text","Label"),_node(4,"Text","Label")]),
		_node(5,"Node","Nd_B",[_node(6,"Text","Label_Title")]),
		_node(7,"ProjectNode","Nd_Row",[],{"file":"Row.csb"}),
		_node(8,"Button","Btn_Close",[],{"callBackName":"onClose"})])]}}
	var tree=NAMED.new(pack)
	var out: Dictionary={}
	var spec: Dictionary={"Nd_A/Label":{"role":"source_text","text":"x"},"Label_Title":{"role":"source_text","text":"t"},"Btn_Close":{"activate":Callable(self,"_noop")}}
	var bound: Dictionary=tree.bind("UI/Win.csb","",[],spec,out)
	check(tree.duplicate_paths.has("/Root/Nd_A/Label") and (tree.duplicate_paths["/Root/Nd_A/Label"] as Array).size()==2,"sibling nodes sharing a path are recorded")
	var offsets: Array=[]
	for entry: Dictionary in tree.duplicate_paths["/Root/Nd_A/Label"]:offsets.append(int(entry.offset))
	check(offsets==[3,4],"both nodes in tree order")
	check(int(out["/Root/Nd_A/Label"].offset)==4,"out keeps the last node under the path (unchanged)")
	check(bound.bindings.has(3) and bound.bindings.has(4),"a spec suffix still binds every node it matches")
	var keys: Dictionary={}
	for entry: Dictionary in tree.duplicate_paths["/Root/Nd_A/Label"]:keys[NAMED.node_key(entry)]=true
	keys[NAMED.node_key(out["/Root/Nd_Row/Panel/Btn_Ok"])]=true
	check(keys.size()==3 and NAMED.node_key(out["/Root/Nd_Row/Panel/Btn_Ok"])=="UI/Row.csb|7|11","node keys are unique (member|chain|offset)")
	var ambiguous: Dictionary=tree.ambiguous_suffixes(out,spec)
	check(ambiguous=={"Nd_A/Label":2},"spec suffixes landing on several nodes are listed (%s)" % str(ambiguous))
	var scene:=Node2D.new()
	var exact: Dictionary=NAMED.locate_exact(scene,out,"Nd_A/Label",tree.duplicate_paths)
	check(not exact.get("ok",true) and exact.get("error")=="source_named_node_ambiguous" and (exact.candidates as Array).size()==2,"locate_exact refuses a duplicated path")
	var title: Dictionary=NAMED.locate_exact(scene,out,"Label_Title",tree.duplicate_paths)
	check(title.get("ok",false) and int(title.offset)==6,"a unique suffix locates exactly")
	var first: Dictionary=NAMED.locate(scene,out,"Label")
	check(first.get("ok",false) and int(first.offset)==4,"locate keeps its first-path result")
	var many: Dictionary=NAMED.locate_exact(scene,out,"Label",tree.duplicate_paths)
	check(many.get("error")=="source_named_node_ambiguous","a suffix matching several paths is ambiguous")
	check(NAMED.locate_exact(scene,out,"Nope").get("error")=="source_named_node_missing","a missing suffix is missing")
	check(tree.inert_buttons=={"/Root/Nd_Row/Panel/Btn_Ok":"onOk"},"inert buttons are listed with their callbacks (%s)" % str(tree.inert_buttons))
	var layered: Dictionary=tree.bind("UI/Win.csb","",[],{
		"Label":{"text":"shared","visible":false},
		"Nd_A/Label":{"text":"overridden"},
		"Nd_Row/Panel/Label":{"visible":true},
		"Nd_B":{"exclude":true},
	},{})
	check(layered.bindings[3].text=="overridden" and not layered.bindings[4].visible,"overlapping suffixes merge in their original order")
	var child: Dictionary=layered.bindings[7].bindings
	check(child[12].text=="shared" and child[12].visible,"full-path rules still apply across an authored project")
	check(5 not in layered.scope and 6 not in layered.scope,"excluding a path skips its complete subtree")
	var again: Dictionary={}
	tree.bind("UI/Row.csb","",[],{},again)
	check(tree.duplicate_paths.is_empty(),"a new top-level bind starts a new record")
	scene.free()
	print("ORIGINAL_UI_NAMED_TREE_DUPLICATES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _noop() -> Dictionary:
	return {"ok":true}
