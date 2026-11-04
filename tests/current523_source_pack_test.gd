extends SceneTree
## Default raw bytes are authored fixtures, never delivered original maps.
## Optional: --pack-root=<private pack> --manifest-sha=<explicit pin> --asset=1/
## adds metadata and every available original S32 read, with no render claim.
const PACK = preload("res://scripts/maps/current523_source_pack.gd")
const FORMAT = preload("res://scripts/maps/current523_aden_pack.gd")
var checks: int = 0
var failures: Array[String] = []
var actual_evidence: Dictionary = {}

class FixturePack extends PACK:
	func prepare_fixture(directory: String, asset: String, member: String, gzip_storage: bool = false) -> void:
		# Only raw-reader tests bypass catalog loading, under an explicit fixture
		# class. No native Land proof or source inventory is fabricated here.
		var bytes := PackedByteArray()
		bytes.resize(49166)
		bytes.fill(0)
		bytes.encode_u32(0,4294967295)
		bytes.encode_u32(4,2147483903)
		var observed: Dictionary = FORMAT.scan_sections(bytes)
		var sections: Dictionary = {}
		for name: String in FORMAT.SECTION_NAMES:
			var raw: Dictionary = observed[name]
			var section: Dictionary = {"offset":raw.offset,"bytes":raw.bytes,
				"sha256":PACK._hash(bytes.slice(int(raw.offset),int(raw.offset)+int(raw.bytes)))}
			if raw.has("count"):
				section.count = raw.count
				section.records_offset = int(raw.offset)+(2 if name == "covers" else 4)
			if name == "objects": section.part_count = raw.object_part_count
			sections[name] = section
		var relative: String = "originals/"+member
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory.path_join(relative.get_base_dir())))
		var file := FileAccess.open(directory.path_join(relative),FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
		_root = directory
		source_asset = asset
		_members[member] = {"member":member,"asset_path":asset,"path":relative,"bytes":bytes.size(),
			"sha256":PACK._hash(bytes),"format":"s32","status":"ready","availability":"present",
			"core_end":49166,"object_part_count":0,"attribute_offset":32770,
			"attribute_sha256":sections.attributes.sha256,"sections":sections}
		_supported[member] = true
		if gzip_storage:
			var stored: PackedByteArray = bytes.compress(FileAccess.COMPRESSION_GZIP)
			var zipped := FileAccess.open(directory.path_join(relative+".gz"),FileAccess.WRITE)
			zipped.store_buffer(stored)
			zipped.close()
			_members[member].path = relative+".gz"
			_members[member].storage_format = "gzip"
			_members[member].stored_bytes = stored.size()
			_members[member].stored_sha256 = PACK._hash(stored)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(relative)))
		loaded = true

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	var empty = PACK.new()
	check(not empty.load_catalog("/missing/source-pack",""),"catalog requires caller manifest SHA")
	check(not empty.load_catalog("/missing/source-pack","0".repeat(64)),"missing source manifest denies")
	check(not empty.catalog_loaded and not empty.loaded and empty.land_record(4).is_empty(),"failed replacement exposes no native registry")
	check(PACK._asset_root("13341") == "Map/13341/" and PACK._asset_root("13341/") == "Map/13341/","literal raw AssetPath resolution keeps declaration separate from physical root")
	for member: String in ["Map/../x.s32","/Map/1/x.s32","Map/1/x/y.s32","Map/1/x.s32/","Map/1/x:bad.s32","Map/1/.s32"]:
		check(not PACK._member_name(member),"unsafe literal member rejects: "+member)
	check(PACK.candidate_origin("Map/1/80008000.s32") == Vector2i(32768,32768),"eight hex basename has explicitly provisional origin")
	check(PACK.candidate_origin("Map/1/800f7ff3e.s32") == null,"nonstandard original remains unplaced")
	check(PACK.candidate_origin("Map/1/80008000.seg") == null,"unsupported SEG has no S32 origin")
	var left := FixturePack.new()
	var right := FixturePack.new()
	left.prepare_fixture("user://generic_fixture_left","fixture_left/","Map/fixture_left/80008000.s32")
	right.prepare_fixture("user://generic_fixture_right","fixture_right/","Map/fixture_right/80008000.s32")
	var left_member: String = left.source_members()[0]
	var right_member: String = right.source_members()[0]
	var raw: Dictionary = left.read_member(left_member)
	check(raw.member == left_member and raw.asset_path == "fixture_left/","generic raw reader preserves actual fixture identity")
	check(raw.sections.floor.decode_u32(0) == 4294967295 and raw.sections.floor.decode_u32(4) == 2147483903,"unsigned raw values preserved without movement interpretation")
	check(left.read_member(right_member).is_empty(),"member from another physical asset never aliases into registry")
	var metadata: Dictionary = left.source_metadata(left_member)
	metadata.sections.floor.sha256 = "wrong"
	check(left.source_metadata(left_member).sections.floor.sha256 != "wrong","source metadata query is immutable")
	var fixture_file := FileAccess.open("user://generic_fixture_left/originals/"+left_member,FileAccess.READ_WRITE)
	fixture_file.store_8(1)
	fixture_file.close()
	check(left.read_member(left_member).is_empty() and left.problem.contains("SHA256"),"same-sized corrupted raw bytes deny at actual read")
	check(not right.read_member(right_member).is_empty(),"one failed asset read leaves independent asset intact")
	var zipped := FixturePack.new()
	var zipped_member: String = "Map/fixture_gzip/80008000.s32"
	zipped.prepare_fixture("user://generic_fixture_gzip","fixture_gzip/",zipped_member,true)
	var original_meta: Dictionary = zipped.source_metadata(zipped_member)
	check(not zipped.read_member(zipped_member).is_empty(),"authored gzip fixture preserves valid raw S32 sections")
	zipped._members[zipped_member].stored_sha256 = "0".repeat(64)
	check(zipped.read_member(zipped_member).is_empty() and zipped.problem.contains("Stored source SHA"),"wrong gzip stored hash denies before decoder")
	zipped._members[zipped_member] = original_meta.duplicate(true)
	zipped._members[zipped_member].sha256 = "0".repeat(64)
	check(zipped.read_member(zipped_member).is_empty() and zipped.problem.contains("Original source SHA"),"wrong original hash denies after valid bounded gzip decode")
	zipped._members[zipped_member] = original_meta.duplicate(true)
	zipped._members[zipped_member].bytes = int(original_meta.bytes)+1
	check(zipped.read_member(zipped_member).is_empty() and zipped.problem.contains("ISIZE"),"wrong original size denies before decoder")
	zipped._members[zipped_member] = original_meta.duplicate(true)
	zipped._members[zipped_member].path = "../escape.s32.gz"
	check(zipped.read_member(zipped_member).is_empty() and zipped.problem.contains("metadata"),"noncanonical gzip path denies before file access")
	zipped._members[zipped_member] = original_meta.duplicate(true)
	var gz_path: String = "user://generic_fixture_gzip/"+str(original_meta.path)
	var stored_gzip: PackedByteArray = FileAccess.get_file_as_bytes(gz_path)
	stored_gzip[0] = 0
	var bad_gzip := FileAccess.open(gz_path,FileAccess.WRITE)
	bad_gzip.store_buffer(stored_gzip)
	bad_gzip.close()
	check(zipped.read_member(zipped_member).is_empty() and zipped.problem.contains("Stored source SHA"),"same-size corrupted gzip payload denies its stored pin")
	var root: String = argument("--pack-root=")
	var pin: String = argument("--manifest-sha=")
	var asset: String = argument("--asset=")
	if not root.is_empty(): _actual_sources(root,pin,asset)
	else: check(pin.is_empty() and asset.is_empty(),"actual pack arguments must be supplied together")
	print("CURRENT523_SOURCE_PACK_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"fixture_only":root.is_empty(),"actual_source_evidence":actual_evidence,"native_m_rules_verified":false}))
	quit(0 if failures.is_empty() else 1)

func _actual_sources(root: String, pin: String, asset: String) -> void:
	var pack = PACK.new()
	check(pack.load_catalog(root,pin),"caller-pinned actual catalog loads: "+pack.problem)
	if not pack.catalog_loaded: return
	var identity: Dictionary = pack.catalog_identity()
	check(identity.get("manifest_sha256") == pin and identity.get("native_land_table_sha256") == PACK.LAND_SHA256,"catalog-only identity is available before selecting a terrain asset")
	identity.manifest_sha256 = "wrong"
	check(pack.catalog_identity().manifest_sha256 == pin,"catalog identity query returns an independent value")
	var lands: Array = pack.catalog_lands()
	check(lands.size() == 1065 and int(lands[0].declaration.ID) == 0,"all catalog Lands are sorted before selecting an asset")
	lands[0].declaration.AssetPath = "wrong/"
	check(pack.land_record(0).declaration.AssetPath == "0/","all-Land catalog query returns deep copies")
	check(pack.land_record(47443).declaration.AssetPath == "13341","native missing slash preserved")
	check(pack.asset_record("0/").land_ids == [0,12156],"shared physical root preserves distinct logical Land IDs")
	var land: Dictionary = pack.land_record(1)
	land.declaration.AssetPath = "wrong/"
	check(pack.land_record(1).declaration.AssetPath == "1/","native catalog query is immutable")
	var first: RefCounted=pack.fork_catalog()
	var second: RefCounted=pack.fork_catalog()
	check(first!=null and second!=null and first.select_asset("1/") and second.select_asset("3/"),"verified snapshot creates independent source selections")
	check(first.source_asset=="1/" and second.source_asset=="3/" and pack.source_asset.is_empty(),"selecting a copied catalog does not change parent or sibling")
	check(not first.load_catalog(root,"0".repeat(64)) and pack.catalog_identity().manifest_sha256==pin and second.source_asset=="3/" and not second.source_members().is_empty(),"failed copied-catalog reset cannot clear parent or sibling registry")
	check(pack.load_pack(root,pin,asset),"selected exact native AssetPath loads supported sources: "+pack.problem)
	if not pack.loaded: return
	check(pack.source_asset == asset and pack.format_root() == PACK._asset_root(asset),"selected source binding stays literal")
	var consumed: int = 0
	for member: String in pack.supported_s32_members():
		var row: Dictionary = pack.read_member(member)
		check(not row.is_empty(),"actual source hashes and partitions verify: "+member)
		if row.is_empty(): continue
		check(row.member == member and row.source_sha256 == pack.source_metadata(member).sha256,"actual source identity retained: "+member)
		check(row.sections.floor.size() == 32768 and row.sections.attributes.size() == 16384,"actual fixed raw sections retained: "+member)
		consumed += 1
	var unavailable: int = 0
	for member: String in pack.source_members():
		if member in pack.supported_s32_members(): continue
		check(pack.read_member(member).is_empty(),"missing, unsupported or quarantined chunk cannot be read: "+member)
		unavailable += 1
	actual_evidence = {"manifest_sha256":pin,"asset_path":asset,"expected_members":pack.source_members().size(),
		"verified_supported_s32_members":consumed,"unavailable_members_denied":unavailable,
		"native_land_table_sha256":PACK.LAND_SHA256,"render_verified":false}
	check(not pack.load_catalog(root,"0".repeat(64)) and not pack.loaded and pack.land_record(1).is_empty() and pack.catalog_identity().is_empty(),"incorrect manifest pin clears accepted runtime and catalog identity")
