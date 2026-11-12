extends SceneTree
## Partial original scenes retain serialized records and independent metadata.
## No private CSB, art, gameplay state or timing threshold is required.
const SCOPE=preload("res://scripts/ui/original_ui/source_node_scope.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:_run.call_deferred()

func _node(offset: int, children: Array=[]) -> Dictionary:
	return {"_offset":offset,"classname":"Node","options":{"actionTag":offset,"position":[offset,0],"source":{"identity":"synthetic:"+str(offset),"fields":[{"value":offset}],"bytes":PackedByteArray([1,2,3])}},"children":children,"tail":{"original":true}}

func _tree() -> Dictionary:
	return {"schema_version":7,"nodeTree":_node(1,[_node(2,[_node(3),_node(4,[_node(5)])]),_node(7),_node(8)]),"action":{"duration":42,"speed":1.25,"timeLines":[{"actionTag":1,"property":"Alpha","frames":[{"value":255}]},{"actionTag":2,"property":"Position","frames":[{"value":[2,4]}]},{"actionTag":3,"property":"VisibleForFrame","frames":[{"value":true}]},{"actionTag":4,"property":"Alpha","frames":[{"value":100}]},{"actionTag":7,"property":"Scale","frames":[{"value":[1,1]}]}]},"animationList":[{"name":"original","startIndex":0,"endIndex":42}],"_source_sha256":"synthetic-evidence-not-original","metadata":{"nested":[{"identity":[1,"two",true,null]}]}}

func _projection() -> void:
	var tree: Dictionary=_tree()
	var input_bytes: PackedByteArray=var_to_bytes(tree)
	var requested: Array[int]=[3]
	var result: Dictionary=SCOPE.select(tree,requested)
	check(result.get("ok",false),"one descendant projects successfully")
	var expected: Dictionary=tree.duplicate(true)
	expected.nodeTree.children.resize(1)
	expected.nodeTree.children[0].children.resize(1)
	expected.action.timeLines.resize(3)
	expected["_selected_source_offsets"]=requested.duplicate()
	expected["_partial_source_scene"]=true
	check(var_to_bytes(result.get("tree",{}))==var_to_bytes(expected),"complete projected fields, types, order, provenance and tracks match the authored subset")
	check(result.get("retained_source_offsets")==[3,2,1],"ancestors and postorder offsets are retained")
	check(result.get("retained_action_tags")==[3,2,1],"retained action tag order follows source traversal")
	check(result.get("source_node_offsets")==[3] and result.get("selected_source_offsets")==[3],"both selection diagnostics retain requested offsets")
	check(result.get("partial_source_scene",false) and not result.get("complete_screen_contract",true),"partial projection does not claim a full screen")
	check(var_to_bytes(tree)==input_bytes,"projection leaves the complete input unchanged")
	var projected: Dictionary=result.tree
	projected.nodeTree.options.source.fields[0].value=999
	projected.nodeTree.children[0].options.position[0]=999
	projected.nodeTree.children[0].children[0].tail.original=false
	projected.action.timeLines[1].frames[0].value[0]=999
	projected.animationList[0].name="changed"
	projected.metadata.nested[0].identity[1]="changed"
	projected.nodeTree.options.source.bytes[0]=255
	check(var_to_bytes(tree)==input_bytes,"nested retained nodes, arrays, tracks, provenance and packed bytes are detached")
	var second: Dictionary=SCOPE.select(tree,[3])
	check(var_to_bytes(second.tree)==var_to_bytes(expected),"one caller cannot change a later projection")
	check(projected.keys()==tree.keys()+["_selected_source_offsets","_partial_source_scene"],"top-level metadata preserves serialized key order")
	check(projected.nodeTree.keys()==tree.nodeTree.keys(),"node fields preserve serialized key order")

func _selection_order_and_boundaries() -> void:
	var tree: Dictionary=_tree()
	var result: Dictionary=SCOPE.select(tree,[7,3])
	check(result.get("ok",false),"several requested branches project successfully")
	check(result.tree.nodeTree.children.size()==2 and result.tree.nodeTree.children[0]._offset==2 and result.tree.nodeTree.children[1]._offset==7,"children keep authored order independently of request order")
	check(result.get("retained_source_offsets")==[3,2,7,1],"retained offsets include exactly requested branches and ancestors")
	check(result.tree._selected_source_offsets==[7,3],"request order remains part of source scope evidence")
	check(result.tree.action.timeLines.map(func(track: Dictionary) -> int:return track.actionTag)==[1,2,3,7],"action tracks keep authored order and exact retained tags")
	var root_only: Dictionary=SCOPE.select(tree,[1])
	check(root_only.get("ok",false) and root_only.tree.nodeTree.children.is_empty(),"selecting a root does not implicitly include descendants")
	check(root_only.tree.action.duration==42 and root_only.tree.action.speed==1.25 and root_only.tree.animationList==tree.animationList,"duration, speed and clips remain original")
	var leaf: Dictionary={"nodeTree":{"_offset":1,"classname":"Node","options":{"actionTag":1}}}
	var leaf_before: PackedByteArray=var_to_bytes(leaf)
	var leaf_result: Dictionary=SCOPE.select(leaf,[1])
	check(leaf_result.get("ok",false) and leaf_result.tree.nodeTree.children==[],"a leaf without a serialized children field still projects to an empty child list")
	check(var_to_bytes(leaf)==leaf_before,"adding a projected leaf child list never mutates input")
	var marker:=Resource.new()
	leaf["resource_metadata"]=marker
	check(SCOPE.select(leaf,[1]).tree.resource_metadata==marker,"Resource metadata retains Dictionary.duplicate(true) identity semantics")

func _failure_contracts() -> void:
	var tree: Dictionary=_tree()
	check(SCOPE.select(tree,[]).get("code")=="source_node_scope_selection_empty","empty request is rejected")
	check(SCOPE.select(tree,[3,3])=={"ok":false,"code":"source_node_scope_duplicate_request","offset":3},"duplicate request is rejected with its exact offset")
	check(SCOPE.select({},[3]).get("code")=="source_node_scope_tree_missing","missing source tree is rejected")
	check(SCOPE.select(tree,[999])=={"ok":false,"code":"source_node_scope_node_missing","offset":999},"missing requested node is rejected")
	tree.nodeTree.children.append(_node(3))
	check(SCOPE.select(tree,[3])=={"ok":false,"code":"source_node_scope_node_ambiguous","offset":3},"ambiguous original offsets are rejected")

func _run() -> void:
	_projection()
	_selection_order_and_boundaries()
	_failure_contracts()
	print("ORIGINAL_UI_NODE_SCOPE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
