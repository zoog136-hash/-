extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var checks: int=0
var errors: Array[String]=[]
func inspect(node: Node) -> void:
	if node.has_meta("source_list_layout"):
		var layout: Dictionary=node.get_meta("source_list_layout")
		var inner: Node2D=node.find_child("SourceOriginalListRows",true,false)
		checks+=1
		if inner==null:errors.append("original list rows missing");return
		checks+=1
		if inner.position!=layout.inner_position:errors.append("initial inner position")
		var rows: Array[Node]=inner.get_children()
		checks+=1
		if rows.size()!=layout.positions.size():errors.append("original row count");return
		for index: int in range(rows.size()):
			checks+=2
			if rows[index].position!=layout.positions[index]:errors.append("source row placement")
			if rows[index].z_index!=index:errors.append("source ListView refresh order")
	for child: Node in node.get_children():inspect(child)
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	if not pack.open(args[0],receipt.manifest_sha256).ok:quit(1);return
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	for row: Dictionary in prior.entries:
		var scene=SCENE.new()
		var configured: Dictionary=scene.configure(pack,row.member,true)
		checks+=1
		if not configured.ok:errors.append(row.member+":"+str(configured));scene.free();continue
		inspect(scene)
		scene.free()
		var strict=SCENE.new()
		checks+=1
		if strict.configure(pack,row.member,false).ok:errors.append(row.member+":unbound list reached strict consumption")
		strict.free()
	print("ORIGINAL_LIST_SCENE "+JSON.stringify({"checks":checks,"errors":errors,"scope":"original rows mounted in scene, initial placement/order and strict rejection of unbound gameplay content"}))
	quit(0 if errors.is_empty() else 1)
