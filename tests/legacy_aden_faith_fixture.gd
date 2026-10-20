extends RefCounted
## Preserve explicit pre-PNG A3/grid/encounter contracts. Actual new PNG
## acceptance remains in aden_faith_png_runtime_test, not these fixtures.
static func delegate(tree: SceneTree, script: String) -> bool:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if not preload("res://scripts/maps/native_png_registry.gd").extra_installed() or "--legacy-aden-faith-layouts" in args:
		return false
	var command:=PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script",script])
	if DisplayServer.get_name()=="headless": command.append("--headless")
	else: command.append_array(PackedStringArray(["--rendering-driver","opengl3","--audio-driver","Dummy","--disable-vsync"]))
	command.append("--");command.append_array(args);command.append("--legacy-aden-faith-layouts")
	var output: Array=[]
	var result: int=OS.execute(OS.get_executable_path(),command,output,true)
	print("LEGACY_ADEN_FAITH_FIXTURE ",script,"; assertions retained on original A3/grid layout; new PNG acceptance is separate")
	for chunk: String in output: print(chunk)
	tree.quit(result)
	return true
