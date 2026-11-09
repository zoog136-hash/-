extends SceneTree
## The over-the-air updater mounts only a newer pack built for this APK,
## decides feed records correctly, and installs a download atomically.
const UPDATER = preload("res://scripts/boot/updater.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _write(path: String, text: String) -> void:
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(text)
	out.close()

func _clean() -> void:
	var dir := DirAccess.open(UPDATER.DIR)
	if dir == null: return
	for name: String in dir.get_files(): dir.remove(name)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(UPDATER.DIR)
	_clean()
	var apk: Dictionary = {"version_code":10,"version_name":"523.10","compat_key":"a".repeat(64)}
	var sha: String = "b".repeat(64)
	var newer: Dictionary = {"version_code":11,"version_name":"523.11","compat_key":"a".repeat(64),"file":"twilight-update-11.pck","size":5,"sha256":sha,"url":"https://example.invalid/twilight-update-11.pck"}
	check(UPDATER.decide(newer, apk, {}) == "download", "a newer pack for this APK downloads")
	var same: Dictionary = newer.duplicate(); same.version_code = 10
	check(UPDATER.decide(same, apk, {}) == "none", "the same version is not downloaded")
	check(UPDATER.decide(newer, apk, {"version_code":11}) == "none", "an already mounted version is not downloaded again")
	var other: Dictionary = newer.duplicate(); other.compat_key = "c".repeat(64)
	check(UPDATER.decide(other, apk, {}) == "apk", "a pack for another APK asks for a new APK")
	var plain: Dictionary = newer.duplicate(); plain.url = "http://example.invalid/x.pck"
	check(UPDATER.decide(plain, apk, {}) == "none", "only https downloads")
	var unsafe: Dictionary = newer.duplicate(); unsafe.file = "../x.pck"
	check(UPDATER.decide(unsafe, apk, {}) == "none", "a file name with a path is refused")
	check(UPDATER.decide(newer, {}, {}) == "none", "a build without build info never updates")
	check(UPDATER.fits({"version_code":11,"compat_key":apk.compat_key,"file":"p.pck"}, apk), "a newer matching pack fits")
	check(not UPDATER.fits({"version_code":10,"compat_key":apk.compat_key,"file":"p.pck"}, apk), "an APK as new as the pack wins")
	check(not UPDATER.fits({"version_code":11,"compat_key":"x","file":"p.pck"}, apk), "another APK's pack does not fit")
	# Mount: a real pack overriding one res:// file.
	var probe: String = "res://zz_updater_probe.txt"
	var source: String = UPDATER.DIR.path_join("probe.txt")
	_write(source, "from the update pack")
	var packer := PCKPacker.new()
	var pack_path: String = UPDATER.DIR.path_join("twilight-update-11.pck")
	check(packer.pck_start(pack_path) == OK and packer.add_file(probe, source) == OK and packer.flush() == OK, "test pack written")
	var updater: Node = UPDATER.new()
	updater.builtin = apk
	var record: Dictionary = {"version_code":11,"version_name":"523.11","compat_key":apk.compat_key,"file":"twilight-update-11.pck","size":FileAccess.get_size(pack_path),"sha256":FileAccess.get_sha256(pack_path)}
	_write(UPDATER.ACTIVE, JSON.stringify(record))
	_write(UPDATER.DIR.path_join("twilight-update-9.pck"), "old")
	updater.mount()
	check(updater.active.get("version_code") == 11, "the recorded pack is mounted")
	check(FileAccess.get_file_as_string(probe) == "from the update pack", "files from the pack replace the APK's")
	check(not FileAccess.file_exists(UPDATER.DIR.path_join("twilight-update-9.pck")), "older packs are removed")
	check(updater.version_name() == "523.11", "the shown version is the mounted pack's")
	# A newer APK makes the pack obsolete.
	var newer_apk: Node = UPDATER.new()
	newer_apk.builtin = {"version_code":12,"compat_key":apk.compat_key}
	newer_apk.mount()
	check(newer_apk.active.is_empty() and not FileAccess.file_exists(UPDATER.ACTIVE), "an APK newer than the pack forgets it")
	# Install moves a download into place and records it.
	var download: String = UPDATER.DIR.path_join("download.tmp")
	_write(download, "12345")
	var installed: Node = UPDATER.new()
	installed.builtin = apk
	var feed: Dictionary = {"version_code":13,"version_name":"523.13","compat_key":apk.compat_key,"file":"twilight-update-13.pck","size":5,"sha256":FileAccess.get_sha256(download)}
	check(installed.install(download, feed) == "", "install succeeds")
	var saved: Dictionary = UPDATER.read_json(UPDATER.ACTIVE)
	check(saved.get("file") == "twilight-update-13.pck" and int(saved.get("version_code", 0)) == 13 and int(saved.get("size", 0)) == 5, "the record names the installed pack")
	check(FileAccess.file_exists(UPDATER.DIR.path_join("twilight-update-13.pck")) and not FileAccess.file_exists(download), "the download moved into place")
	check(not FileAccess.file_exists(UPDATER.ACTIVE + ".pending"), "no pending record is left")
	for node: Node in [updater, newer_apk, installed]: node.free()
	_clean()
	print("UPDATER_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
