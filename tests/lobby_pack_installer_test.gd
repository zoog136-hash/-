extends SceneTree
const Installer = preload("res://scripts/characters/lobby_pack_installer.gd")
const Selection = preload("res://scripts/characters/lobby_source_selection.gd")
var failures: int = 0
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
func _initialize() -> void:
	for member: String in ["../escape", "/absolute", "a/../escape", "C:/escape", "a\\escape", "./x"]:
		check(not Installer.safe_member(member),"reject " + member)
	check(Installer.safe_member("originals/UI/Spine/a.png"),"safe member")
	check(not Installer.install_paths(PackedStringArray()).get("ok",true),"empty picker refused")
	check(not Installer.install_paths(PackedStringArray(["a.001","b.001","c.003"])).get("ok",true),"duplicate parts refused")
	check(not Selection.options(PackedStringArray(["--source-lobby=/explicit"])).get("ok",true),"invalid explicit override never hidden")
	check(Selection.options(PackedStringArray(["--source-lobby=/explicit","--source-lobby-sha256="+Installer.MANIFEST_SHA])).path == "/explicit","explicit override retained")
	var opaque: Array[Dictionary] = []
	for index: int in [2, 0, 1]:
		opaque.append({"path":"content://com.android.providers.downloads.documents/document/%d" % (index + 900), "bytes":Installer.PART_BYTES[index], "sha256":Installer.PART_HASHES[index]})
	var sorted: Dictionary = Installer.order_part_fingerprints(opaque)
	check(sorted.get("ok",false), "opaque Android URI names accepted by exact byte identity")
	check(sorted.paths[0].ends_with("900") and sorted.paths[2].ends_with("902"), "shuffled SAF selection ordered by SHA")
	opaque[0] = opaque[1].duplicate()
	check(not Installer.order_part_fingerprints(opaque).get("ok",true), "duplicate bytes rejected despite distinct names")
	opaque[0].sha256 = "untrusted"
	check(not Installer.order_part_fingerprints(opaque).get("ok",true), "foreign bytes rejected")
	if not Installer.saved_options().get("selected",false):
		var fixture: String = "user://invalid_lobby_fixture.zip"
		var output: FileAccess = FileAccess.open(fixture,FileAccess.WRITE)
		output.store_string("not a resource archive")
		output.close()
		check(Installer.install_archive(fixture).get("error") == "archive_size_mismatch_retry_download","invalid archive refused")
		check(not Installer.saved_options().get("selected",true),"failure leaves selection untouched")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	# Optional real-art audit. No copyrighted fixture is committed.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			var result: Dictionary = Installer.install_archive(argument.trim_prefix("--archive="))
			check(result.get("ok",false),"real archive installed: " + str(result))
			if result.get("ok",false):
				check(Installer.install_archive("missing.zip").get("reused",false),"verified install reused")
				check(Selection.selected_pack().get("ok",false),"saved installed pack opened")
	print("LOBBY_PACK_INSTALLER_RESULT ", JSON.stringify({"failures":[] if failures == 0 else [failures]}))
	quit(0 if failures == 0 else 1)
