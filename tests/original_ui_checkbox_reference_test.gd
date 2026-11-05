extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const CHECKBOX=preload("res://scripts/ui/original_ui/source_checkbox.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=3:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	if not pack.open(args[0],receipt.manifest_sha256).ok:quit(1);return
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var reference: Array=JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	var checks: int=0
	var errors: Array[String]=[]
	for index: int in range(cases.size()):
		var row: Dictionary=cases[index]
		checks+=1
		if pack.manifest.files[row.member].sha256!=row.source_sha256:errors.append("original CSB provenance");continue
		var checkbox=CHECKBOX.new()
		var configured: Dictionary=checkbox.configure(pack,row.node.options)
		checks+=1
		if not configured.ok:errors.append(row.member+":"+str(configured));checkbox.free();continue
		for state_index: int in range(4):
			if state_index>0:checkbox.set_source_state(["","pressed","normal","disabled"][state_index])
			var expected: Dictionary=reference[index][state_index]
			checks+=1
			if checkbox.selected!=expected.selected:errors.append("source selection")
			for renderer: int in range(5):
				var sprite: Sprite2D=checkbox.renderers[renderer]
				var values: Array=expected.sprites[renderer]
				checks+=1
				if sprite.visible!=values[0]:errors.append(row.member+":original renderer visibility")
				if sprite.texture!=null:
					checks+=1
					if bool(sprite.material.get_shader_parameter("source_gray"))!=values[1]:errors.append(row.member+":original gray state")
				for component: int in range(4):
					checks+=1
					var actual: float=[sprite.scale.x,sprite.scale.y,sprite.position.x,sprite.position.y][component]
					if absf(actual-float(values[component+2]))>0.00001:errors.append(row.member+":original renderer geometry")
		checkbox.free()
	print("ORIGINAL_CHECKBOX_REFERENCE "+JSON.stringify({"checks":checks,"errors":errors.slice(0,20),"error_count":errors.size(),"original_components":cases.size(),"scope":"original five-renderer states against unmodified upstream CheckBox methods; no gameplay completion"}))
	quit(0 if errors.is_empty() else 1)
