extends RefCounted
## Preserve explicit pre-PNG A3/grid/encounter contracts. Actual new PNG
## acceptance remains in aden_faith_png_runtime_test, not these fixtures.
static func delegate(tree: SceneTree, script: String, all_maps: bool = false) -> bool:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	var flag: String = "--legacy-map-layouts" if all_maps else "--legacy-aden-faith-layouts"
	if "--legacy-map-layouts" in args or flag in args:
		return false
	var registry = preload("res://scripts/maps/native_png_registry.gd")
	if not (registry.enabled() if all_maps else registry.extra_installed()):
		return false
	var command:=PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script",script])
	if DisplayServer.get_name()=="headless": command.append("--headless")
	else: command.append_array(PackedStringArray(["--rendering-driver","opengl3","--audio-driver","Dummy","--disable-vsync"]))
	command.append("--");command.append_array(args);command.append(flag)
	var output: Array=[]
	var result: int=OS.execute(OS.get_executable_path(),command,output,true)
	print("LEGACY_ADEN_FAITH_FIXTURE ",script," ",flag,"; assertions retained on original A3/grid layout; new PNG acceptance is separate")
	for chunk: String in output: print(chunk)
	tree.quit(result)
	return true
