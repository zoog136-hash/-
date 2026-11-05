extends SceneTree
const LAYOUT=preload("res://scripts/ui/original_ui/source_list_layout.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var reference: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var errors: Array[String]=[]
	var checks: int=0
	for index: int in range(cases.size()):
		var options: Dictionary=cases[index].node.options
		var extent:=Vector2(options.widgetOptions.size[0],options.widgetOptions.size[1])
		var items: Array[Dictionary]=[]
		for child: Dictionary in cases[index].node.children:
			var w: Dictionary=child.options.widgetOptions
			var extent_value: Array=child.options.scale9Size if bool(child.options.get("backGroundScale9Enabled",false)) else w.size
			items.append({"size":extent_value,"anchor":w.anchorPoint,"ignore_size":bool(w.ignoreSize)})
		var result: Dictionary=LAYOUT.arrange(options,extent,items)
		checks+=1
		if not result.ok:errors.append(cases[index].member+":"+str(result));continue
		for component: int in range(2):
			checks+=1
			if absf(result.inner_size[component]-reference[index].inner[component])>0.0002:errors.append(cases[index].member+":inner extent")
		for row: int in range(items.size()):
			for component: int in range(2):
				checks+=1
				if absf(result.positions[row][component]-reference[index].positions[row][component])>0.0002:errors.append(cases[index].member+":original row position")
	print("ORIGINAL_LIST_REFERENCE "+JSON.stringify({"checks":checks,"errors":errors,"cases":cases.size(),"scope":"supplied list row fields against unmodified upstream ListView/LinearLayoutManager functions; not gameplay data or scroll input"}))
	quit(0 if errors.is_empty() else 1)
