extends SceneTree
## Android resource-pack installer: synthetic parts, no original files.
## Parts are installed out of order; the descriptor appears only after every
## part and every pinned manifest is in place. A damaged part installs nothing.
const PACK = preload("res://scripts/boot/source523_pack.gd")
const BASE := "user://source523_pack_test"
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	for name: String in directory.get_files(): directory.remove(name)
	for name: String in directory.get_directories(): remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)

func write_part(path: String, index: Dictionary, files: Dictionary) -> void:
	var packer := ZIPPacker.new()
	packer.open(path)
	packer.start_file("source523/source523_part.json")
	packer.write_file(JSON.stringify(index).to_utf8_buffer())
	packer.close_file()
	for name: String in files:
		packer.start_file("source523/" + name)
		packer.write_file(files[name])
		packer.close_file()
	packer.close()

func members(files: Dictionary) -> Array:
	var result: Array = []
	for name: String in files:
		if name != "source523_pack.json": result.append([name, files[name].size()])
	return result

func install(node: Node, paths: Array) -> void:
	node._queue_parts(PackedStringArray(paths))
	for frame: int in 600:
		if not node.is_processing() and not node._mounted and node._verify.is_empty(): return
		await process_frame

func run() -> void:
	remove_tree(BASE)
	DirAccess.make_dir_recursive_absolute(BASE.path_join("in"))
	var tables := "tables".to_utf8_buffer()
	var files_a: Dictionary = {"tables/source.zip":tables,
		"bank/manifest.json":JSON.stringify({"kind":"current523_reference_sp2_action_bank"}).to_utf8_buffer(),
		"bank/raw/Sprite/45-0.sp2":PackedByteArray([254, 0, 1, 2])}
	var files_b: Dictionary = {"images/manifest.json":"{}".to_utf8_buffer(),
		"maps/source523.json":JSON.stringify({"kind":"current523_s32_source_pack"}).to_utf8_buffer(),
		"tiles/tilepack523.json":"{}".to_utf8_buffer(),
		"maps/originals/Aden/a.s32":PackedByteArray([1, 2, 3])}
	var pack_id: String = "ab".repeat(32)
	var descriptor: Dictionary = {"schema":PACK.SCHEMA,"cumulative_version":523,"pack_id":pack_id,"start_land_id":4,
		"tables":{"path":"tables/source.zip","sha256":sha(tables)}}
	for section: String in ["bank","images","maps","tiles"]:
		var manifest: String = section + "/" + PACK.SECTIONS[section]
		var bytes: PackedByteArray = files_a.get(manifest, files_b.get(manifest, PackedByteArray()))
		descriptor[section] = {"root":section,"manifest":manifest,"manifest_sha256":sha(bytes)}
	var part_a: Dictionary = files_a.duplicate()
	part_a["source523_pack.json"] = JSON.stringify(descriptor).to_utf8_buffer()
	write_part(BASE.path_join("in/p1.zip"), {"schema":PACK.PART_SCHEMA,"pack_id":pack_id,"part":1,"parts":2,"members":members(files_a)}, part_a)
	write_part(BASE.path_join("in/p2.zip"), {"schema":PACK.PART_SCHEMA,"pack_id":pack_id,"part":2,"parts":2,"members":members(files_b)}, files_b)
	var broken: Dictionary = {"maps/originals/Aden/a.s32":PackedByteArray([1])}
	write_part(BASE.path_join("in/broken.zip"), {"schema":PACK.PART_SCHEMA,"pack_id":pack_id,"part":2,"parts":2,"members":[["maps/originals/Aden/a.s32", 3]]}, broken)

	var node: Node = PACK.new()
	node.root = BASE.path_join("root")
	node.tables_sha = sha(tables)
	root.add_child(node)
	node._show_installer()
	var target: String = BASE.path_join("root")
	await install(node, [ProjectSettings.globalize_path(BASE.path_join("in/broken.zip"))])
	check(not FileAccess.file_exists(target.path_join("source523_pack.json")) and node._state().get("done", []).is_empty(), "a damaged part installs nothing")
	await install(node, [ProjectSettings.globalize_path(BASE.path_join("in/p2.zip"))])
	check(node._state().get("done") == [2] and not FileAccess.file_exists(target.path_join("source523_pack.json")), "one of two parts leaves the pack inactive")
	await install(node, [ProjectSettings.globalize_path(BASE.path_join("in/p1.zip"))])
	check(FileAccess.file_exists(target.path_join("source523_pack.json")) and not FileAccess.file_exists(target.path_join("source523_pack.pending.json")), "all parts and pins activate the pack")
	check(FileAccess.get_file_as_bytes(target.path_join("bank/raw/Sprite/45-0.sp2")) == PackedByteArray([254, 0, 1, 2]) and FileAccess.get_file_as_bytes(target.path_join("maps/originals/Aden/a.s32")) == PackedByteArray([1, 2, 3]), "members are extracted unchanged")
	var read: Dictionary = PACK.read_descriptor(target.path_join("source523_pack.json"), sha(tables))
	check(read.ok, "installed descriptor validates")
	check(not PACK.read_descriptor(target.path_join("source523_pack.json")).ok, "only the runtime-pinned tables ZIP is accepted by default")
	if read.ok:
		var base: String = ProjectSettings.globalize_path(target)
		var selected: Dictionary = PACK.selections(base, read.descriptor)
		check(selected.environment.TWILIGHT_PATCH523_CONTENT == base.path_join("tables/source.zip") and selected.environment.TWILIGHT_SOURCE523_IMAGES == base.path_join("images") and not selected.environment.has("TWILIGHT_SOURCE_UI"), "environment points at the extracted pack")
		check(selected.bank.manifest_path == base.path_join("bank/manifest.json") and selected.bank.manifest_sha256 == descriptor.bank.manifest_sha256 and selected.bank.source_snapshot == "patch523", "bank selection keeps the manifest pin")
		check(selected.maps.raw_root == base.path_join("maps") and selected.maps.tile_root == base.path_join("tiles") and selected.start_land_id == 4, "map selection uses the extracted map and tile packs")
	var unsafe: Dictionary = descriptor.duplicate(true)
	unsafe.bank.root = "../bank"
	var unsafe_path: String = BASE.path_join("unsafe.json")
	var file := FileAccess.open(unsafe_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(unsafe))
	file.close()
	check(not PACK.read_descriptor(unsafe_path, sha(tables)).ok, "paths outside the pack are refused")
	paused = false
	node.queue_free()
	remove_tree(BASE)
	print("SOURCE523_PACK_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
