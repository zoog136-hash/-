extends "res://docs/remake/pr122-legendary-parallel/validate_legendary_corrected_dependencies_v01.gd"
## Only revised clips replay; parent guard transforms are compared at two phases.

func _guard_compare(entry: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var compared: int = 0
	for check: Dictionary in entry.get("inherited_guard_checks", []):
		for spec: Array in [[check["parent_record"], check["parent_record_sha256"]], [check["parent_registration"], check["parent_registration_sha256"]]]:
			if FileAccess.get_sha256(str(spec[0])) != str(spec[1]):
				errors.append("Parent evidence SHA mismatch")
		var child: Node2D = PLAYER.new()
		var parent: Node2D = PLAYER.new()
		root.add_child(child)
		root.add_child(parent)
		if not child.configure(str(entry["record"]), str(entry["registration"])) or not parent.configure(str(check["parent_record"]), str(check["parent_registration"])):
			errors.append("Parent/child registration configure failed")
		else:
			child.sprite.pause()
			parent.sprite.pause()
			child.sprite.frame = int(check["action_phase"])
			parent.sprite.frame = int(check["idle_phase"])
			child._apply_frame_registration()
			parent._apply_frame_registration()
			if not child.sprite.scale.is_equal_approx(parent.sprite.scale) or not child.sprite.offset.is_equal_approx(parent.sprite.offset) or not child.sprite.position.is_equal_approx(parent.sprite.position):
				errors.append("Guard did not inherit exact parent canvas, scale, anchor and target transform")
			var a: AtlasTexture = child.sprite.sprite_frames.get_frame_texture(child.sprite.animation, child.sprite.frame) as AtlasTexture
			var b: AtlasTexture = parent.sprite.sprite_frames.get_frame_texture(parent.sprite.animation, parent.sprite.frame) as AtlasTexture
			if a == null or b == null or a.atlas.resource_path != b.atlas.resource_path or a.region != b.region or a.margin != b.margin:
				errors.append("Guard source/region/margin differs from pinned parent")
			compared += 1
		child.queue_free()
		parent.queue_free()
		await process_frame
	return {"slot": entry["slot"], "compared_parent_guards": compared, "errors": errors,
		"status": "PASS" if errors.is_empty() and compared == 2 else "FAIL"}

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]):
		push_error("Supply only explicit affected manifest and new report")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var failures: int = 0
	var guards: Array = []
	for entry: Dictionary in manifest["revisions"]:
		var result: Dictionary = await _validate(entry)
		_results.append(result)
		if result["status"] != "PASS":
			failures += 1
		if entry.has("inherited_guard_checks"):
			var compare: Dictionary = await _guard_compare(entry)
			guards.append(compare)
			if compare["status"] != "PASS":
				failures += 1
	var report: Dictionary = {"scope": "Only revised guard-action playback and exact two-parent-frame transforms",
		"engine": Engine.get_version_info().get("string", ""), "records": _results, "guard_parent_checks": guards,
		"failures": failures, "PNG_mutations": 0, "healthy_action_replays": 0, "final_approved": 0}
	var handle: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	handle.store_string(JSON.stringify(report, "  ") + "\n")
	handle.close()
	print(JSON.stringify({"affected_clips": _results.size(), "guard_checks": guards.size(), "failures": failures}))
	quit(0 if failures == 0 else 1)
