extends RefCounted
## Historical layouts are development fixtures, not a production fallback.
## Keep existing repository test/capture commands working, but ignore legacy
## switches on ordinary game launches or unrelated external helper scripts.
static func validation_script() -> bool:
	var args: PackedStringArray=OS.get_cmdline_args()
	for i: int in range(args.size()-1):
		if args[i] not in ["--script","-s"]:continue
		var path: String=args[i+1]
		if path.begins_with("res://tests/") or path.begins_with(ProjectSettings.globalize_path("res://tests/")):return true
		if path in ["res://tools/map_restore/capture_maps.gd",ProjectSettings.globalize_path("res://tools/map_restore/capture_maps.gd")]:return true
	return false

static func active(flag: String) -> bool:
	if flag not in OS.get_cmdline_user_args():return false
	if flag=="--png-review":return true
	return validation_script()
