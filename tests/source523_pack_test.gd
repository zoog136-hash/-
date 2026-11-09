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
		if not node.is_processing() and not node._mounted and node._copy_source == null and node._verify.is_empty(): return
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
	check(DirAccess.get_files_at(target).size() == 2, "imported part copies are removed after extraction")
	check(FileAccess.get_file_as_bytes(target.path_join("bank/raw/Sprite/45-0.sp2")) == PackedByteArray([254, 0, 1, 2]) and FileAccess.get_file_as_bytes(target.path_join("maps/originals/Aden/a.s32")) == PackedByteArray([1, 2, 3]), "members are extracted unchanged")
	var read: Dictionary = PACK.read_descriptor(target.path_join("source523_pack.json"), sha(tables))
	check(read.ok, "installed descriptor validates")
	check(not PACK.read_descriptor(target.path_join("source523_pack.json")).ok, "only the runtime-pinned tables ZIP is accepted by default")
	if read.ok:
		var base: String = ProjectSettings.globalize_path(target)
		var selected: Dictionary = PACK.selections(base, read.descriptor)
		check(selected.environment.TWILIGHT_PATCH523_CONTENT == base.path_join("tables/source.zip") and selected.environment.TWILIGHT_SOURCE523_IMAGES == base.path_join("images") and not selected.environment.has("TWILIGHT_SOURCE_UI"), "environment points at the extracted pack")
		check(selected.bank.manifest_path == base.path_join("bank/manifest.json") and selected.bank.manifest_sha256 == descriptor.bank.manifest_sha256 and selected.bank.source_snapshot == "patch523", "bank selection keeps the manifest pin")
		check(not selected.environment.has("TWILIGHT_SOURCE523_UI_ICONS"), "no icon selection without its section")
		var with_icons: Dictionary = read.descriptor.duplicate(true)
		with_icons.ui_icons = {"root":"ui_icons","manifest":"ui_icons/icon-selection.json","manifest_sha256":"cd".repeat(32)}
		var icon_env: Dictionary = PACK.selections(base, with_icons).environment
		check(icon_env.TWILIGHT_SOURCE523_UI_ICONS == base.path_join("ui_icons/icon-selection.json") and icon_env.TWILIGHT_SOURCE523_UI_ICONS_SHA256 == "cd".repeat(32), "icon selection points at the extracted selection file")
		check(selected.maps.raw_root == base.path_join("maps") and selected.maps.tile_root == base.path_join("tiles") and selected.start_land_id == 4, "map selection uses the extracted map and tile packs")
	var unsafe: Dictionary = descriptor.duplicate(true)
	unsafe.bank.root = "../bank"
	var unsafe_path: String = BASE.path_join("unsafe.json")
	var file := FileAccess.open(unsafe_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(unsafe))
	file.close()
	check(not PACK.read_descriptor(unsafe_path, sha(tables)).ok, "paths outside the pack are refused")
	# Add-on: 523 map travel definitions added to the installed pack.
	var links_manifest: PackedByteArray = JSON.stringify({"kind":"fixture-world-links"}).to_utf8_buffer()
	PACK.world_links_sha = sha(links_manifest)
	var links: Dictionary = {"world_links/manifest.json":links_manifest,"world_links/lands/4.json":"{}".to_utf8_buffer()}
	var section: Dictionary = {"world_links":{"root":"world_links","manifest":"world_links/manifest.json","manifest_sha256":sha(links_manifest)}}
	var addon_id: String = "ef".repeat(32)
	var addon_files: Dictionary = links.duplicate()
	addon_files["source523_addon.json"] = JSON.stringify({"schema":PACK.ADDON_SCHEMA,"cumulative_version":523,"addon_id":addon_id,"sections":section}).to_utf8_buffer()
	var addon_index: Dictionary = {"schema":PACK.PART_SCHEMA,"pack_id":addon_id,"part":1,"parts":1,"addon":true,"members":[["world_links/manifest.json",links_manifest.size()],["world_links/lands/4.json",2]]}
	write_part(BASE.path_join("in/addon.zip"), addon_index, addon_files)
	var bad_files: Dictionary = addon_files.duplicate()
	var bad_section: Dictionary = section.duplicate(true)
	bad_section.world_links.manifest_sha256 = "00".repeat(32)
	bad_files["source523_addon.json"] = JSON.stringify({"schema":PACK.ADDON_SCHEMA,"cumulative_version":523,"addon_id":addon_id,"sections":bad_section}).to_utf8_buffer()
	write_part(BASE.path_join("in/addon_bad.zip"), addon_index, bad_files)
	var state_before: Dictionary = node._state()
	var descriptor_before: PackedByteArray = FileAccess.get_file_as_bytes(target.path_join("source523_pack.json"))
	await install(node, [BASE.path_join("in/addon_bad.zip")])
	check(not FileAccess.file_exists(target.path_join(PACK.ADDONS)) and not FileAccess.file_exists(target.path_join("world_links/manifest.json")), "an add-on with another definitions pin installs nothing")
	await install(node, [BASE.path_join("in/addon.zip")])
	check(FileAccess.get_file_as_bytes(target.path_join("world_links/manifest.json")) == links_manifest and FileAccess.file_exists(target.path_join("world_links/lands/4.json")), "add-on files are extracted")
	check(node._state() == state_before and FileAccess.get_file_as_bytes(target.path_join("source523_pack.json")) == descriptor_before, "an add-on leaves the installed pack's parts and descriptor alone")
	var addons: Dictionary = PACK.read_addons(ProjectSettings.globalize_path(target))
	check(addons.has("world_links") and PACK.has_world_links(read.descriptor, addons) and not PACK.has_world_links(read.descriptor, {}), "the add-on supplies the travel definitions")
	if read.ok:
		var with_links: Dictionary = PACK.selections("/pack", read.descriptor, addons)
		check(with_links.get("definitions", {}).get("directory") == "/pack/world_links" and with_links.definitions.manifest_sha256 == sha(links_manifest), "travel definitions point at the extracted add-on")
		check(not PACK.selections("/pack", read.descriptor).has("definitions"), "no definitions without the add-on")
	var unknown_index: Dictionary = addon_index.duplicate(true)
	check(PACK.read_addon(JSON.stringify({"schema":PACK.ADDON_SCHEMA,"cumulative_version":523,"addon_id":addon_id,"sections":{"bank":section.world_links}}).to_utf8_buffer(), unknown_index).is_empty(), "an add-on cannot replace a base section")
	check(PACK.read_addon(addon_files["source523_addon.json"], {"pack_id":"12".repeat(32)}).is_empty(), "an add-on descriptor must match its part")
	var ui_section: Dictionary = {"ui":{"root":"ui","manifest":"ui/original_ui.json","manifest_sha256":"34".repeat(32)}}
	check(not PACK.read_addon(JSON.stringify({"schema":PACK.ADDON_SCHEMA,"cumulative_version":523,"addon_id":addon_id,"sections":ui_section}).to_utf8_buffer(), unknown_index).is_empty(), "a main UI add-on is accepted")
	ui_section.ui.manifest = "ui/other.json"
	check(PACK.read_addon(JSON.stringify({"schema":PACK.ADDON_SCHEMA,"cumulative_version":523,"addon_id":addon_id,"sections":ui_section}).to_utf8_buffer(), unknown_index).is_empty(), "a main UI add-on must name original_ui.json")
	check(PACK.missing_addons(read.descriptor, addons) == ["ui"], "after the travel definitions only the main UI add-on is asked for")
	PACK.world_links_sha = PACK.WORLD_LINKS_SHA
	paused = false
	node.queue_free()
	remove_tree(BASE)
	print("SOURCE523_PACK_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
