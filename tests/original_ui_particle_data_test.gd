extends SceneTree
const DATA=preload("res://scripts/ui/original_ui/source_particle_data.gd")
const STATE=preload("res://scripts/ui/original_ui/source_particle_state.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var expected: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var checks: int=0
	var errors: Array[String]=[]
	for row: Dictionary in expected:
		checks+=1
		if FileAccess.get_sha256(args[0].path_join("originals").path_join(row.member))!=row.sha256:
			errors.append(row.member+":original hash mismatch");continue
		var decoded: Dictionary=DATA.parse(FileAccess.get_file_as_bytes(args[0].path_join("originals").path_join(row.member)))
		checks+=1
		if not decoded.ok:errors.append(row.member+":"+str(decoded));continue
		checks+=1
		# JSON reference numbers are floats; XML integer values retain int type.
		if decoded.values.size()!=row.values.size():errors.append(row.member+":dictionary key count")
		for key: Variant in row.values:
			if not decoded.values.has(key) or decoded.values[key]!=row.values[key]:errors.append(row.member+":dictionary value:"+str(key))
		var state=STATE.new()
		var configured: Dictionary=state.configure(decoded.values)
		checks+=1
		if not configured.ok:errors.append(row.member+":"+str(configured))
	checks+=1
	if DATA.parse("<plist><dict><key>maxParticles</key><real>3</real>".to_utf8_buffer()).ok:errors.append("incomplete original dictionary accepted")
	print("ORIGINAL_PARTICLE_DATA "+JSON.stringify({"checks":checks,"errors":errors,"scope":"exact original plist dictionaries and bounded configuration; not particle render parity"}))
	quit(0 if errors.is_empty() else 1)
