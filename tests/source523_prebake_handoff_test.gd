extends SceneTree
## Authored fixtures exercise real manifest/bake SHA and source-byte guards.
## Fixture setup replaces native metadata acceptance explicitly; these are not
## delivered original maps, native Land evidence or a rendered-game test.
const HANDOFF = preload("res://scripts/boot/source523_prebake_handoff.gd")
const RAW = preload("res://scripts/maps/current523_source_pack.gd")
const TILES = preload("res://scripts/maps/current523_tile_pack.gd")
const FORMAT = preload("res://scripts/maps/current523_aden_pack.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
var checks: int = 0
var failures: Array[String] = []
var measurements: Dictionary = {}

class SourceFixture extends RAW:
	func seed(directory: String, pin: String, bytes: PackedByteArray) -> void:
		_root = directory; _manifest_sha256 = pin
		catalog_loaded = true; loaded = true; source_asset = "fixture/"
		var sections: Dictionary = {}
		var scanned: Dictionary = FORMAT.scan_sections(bytes)
		for name: String in FORMAT.SECTION_NAMES:
			var part: Dictionary = scanned[name]
			var value: Dictionary = {"offset":part.offset,"bytes":part.bytes,"sha256":RAW._hash(bytes.slice(int(part.offset),int(part.offset)+int(part.bytes)))}
			if part.has("count"):
				value.count = part.count
				value.records_offset = int(part.offset) + (2 if name == "covers" else 4)
			if name == "objects": value.part_count = part.object_part_count
			sections[name] = value
		var member: String = "Map/fixture/80008000.s32"
		_members[member] = {"member":member,"asset_path":source_asset,"path":"originals/"+member,"bytes":bytes.size(),"sha256":RAW._hash(bytes),"format":"s32","status":"ready","availability":"present","core_end":49166,"object_part_count":0,"attribute_offset":32770,"attribute_sha256":sections.attributes.sha256,"sections":sections}
		_supported[member] = true

class TileFixture extends TILES:
	func seed(directory: String, pin: String) -> void:
		_root = directory; _manifest_sha256 = pin; loaded = true
		_blocks[0] = 1
		_tiles[0] = {"original_path":"originals/Tile/0.ti2","source_bytes":3,"source_sha256":"abc".sha256_text()}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func store(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes); file.close()

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	HANDOFF.clear()
	var directory: String = ProjectSettings.globalize_path("user://prebake-handoff-authored-fixture")
	var manifest: PackedByteArray = "{\"authored_handoff_fixture_only\":true}\n".to_utf8_buffer()
	var pin: String = RAW._hash(manifest)
	store(directory.path_join(RAW.MANIFEST_NAME), manifest)
	store(directory.path_join(TILES.MANIFEST_NAME), manifest)
	var bytes := PackedByteArray(); bytes.resize(49166); bytes.fill(0)
	var member: String = "Map/fixture/80008000.s32"
	store(directory.path_join("originals/"+member), bytes)
	var source := SourceFixture.new(); source.seed(directory,pin,bytes)
	var tile := TileFixture.new(); tile.seed(directory,pin)
	HANDOFF.put("maps",directory,pin,source)
	HANDOFF.put("tiles",directory,pin,tile)
	check(HANDOFF.take("maps",directory+"-other",pin)==null,"different root cannot adopt prepared catalog")
	check(HANDOFF.take("maps",directory,"0".repeat(64))==null,"different pin cannot adopt prepared catalog")
	check(HANDOFF.take("images",directory,pin)==null,"unregistered domain is never handed off")
	var controller := CONTROLLER.new()
	var options: Dictionary = {"raw_root":directory,"source_manifest_sha256":pin,"tile_root":directory,"tile_manifest_sha256":pin}
	check(controller._catalog_for(options)==source,"controller takes actual prepared source reader")
	check(controller._tiles_for(options)==tile,"controller takes actual prepared tile reader")
	check(controller.input_cache_metrics().source_catalog_handoffs==1 and controller.input_cache_metrics().source_catalog_loads==0,"source handoff avoids duplicate metadata load")
	check(controller.input_cache_metrics().tile_catalog_handoffs==1 and controller.input_cache_metrics().tile_catalog_loads==0,"tile handoff avoids duplicate metadata load")
	check(HANDOFF.take("maps",directory,pin)==null and HANDOFF.take("tiles",directory,pin)==null,"handoff ownership is consumed once")
	check(controller._catalog_for(options)==source and controller._tiles_for(options)==tile,"existing same-controller validation remains available")
	check(not source.read_member(member).is_empty(),"authored raw bytes accepted before corruption")
	var bad: PackedByteArray = bytes.duplicate(); bad[0] = 1
	store(directory.path_join("originals/"+member),bad)
	check(source.read_member(member).is_empty() and source.problem.contains("SHA256"),"same-size original S32 mutation still fails SHA after handoff")
	store(directory.path_join("originals/Tile/0.ti2"),"abd".to_utf8_buffer())
	check(tile.texture_for(0)==null and tile.problem.contains("digest"),"same-size original TI2 mutation still fails SHA after handoff")
	for kind: String in ["maps","tiles"]:
		var reader: RefCounted = source if kind=="maps" else tile
		var name: String = RAW.MANIFEST_NAME if kind=="maps" else TILES.MANIFEST_NAME
		HANDOFF.put(kind,directory,pin,reader)
		store(directory.path_join(name)," ".to_utf8_buffer()+manifest.slice(1))
		check(HANDOFF.take(kind,directory,pin)==null,"same-size changed manifest is rejected on take: "+kind)
		store(directory.path_join(name),manifest)
		check(HANDOFF.take(kind,directory,pin)==null,"rejected transfer cannot be replayed: "+kind)
	# Use a real record bake to prove a handoff retains the normal reopen's
	# persisted-file SHA check, even after an already verified reader was kept.
	var bake_name: String = RAW.bake_name_for(pin)
	var bake_key: String = RAW.bake_key_for(pin)
	var writer: RefCounted = BAKE.record_writer(bake_name,bake_key)
	check(writer!=null,"authored record bake writer available")
	if writer!=null:
		writer.add("fixture",{"authored":true})
		check(BAKE.finish_records(writer),"authored record bake committed")
		source._records = BAKE.open_records(bake_name,bake_key)
		check(source._records!=null,"authored record bake SHA/index verified")
		HANDOFF.put("maps",directory,pin,source)
		check(HANDOFF.take("maps",directory,pin)==source,"unchanged record bake can transfer its existing index")
		HANDOFF.put("maps",directory,pin,source)
		var path: String = BAKE.data_path(bake_name)
		var damaged: PackedByteArray = FileAccess.get_file_as_bytes(path); damaged[0] ^= 1
		store(path,damaged)
		check(HANDOFF.take("maps",directory,pin)==null,"same-size changed bake is rejected before retained index use")
		BAKE.clear(bake_name)
	HANDOFF.put("maps",directory,pin,source); HANDOFF.clear()
	check(HANDOFF.take("maps",directory,pin)==null,"cancel cleanup drops unpublished ownership")
	var options_path: String = arg("--handoff-options=")
	if not options_path.is_empty(): _full_fixture(options_path)
	HANDOFF.clear()
	print("SOURCE523_PREBAKE_HANDOFF_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true,"actual_original_resources":false,"measurements":measurements}))
	quit(0 if failures.is_empty() else 1)

func _full_fixture(path: String) -> void:
	var options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(options.get("synthetic_only",false),"extended fixture explicitly marks synthetic evidence")
	if not options.get("synthetic_only",false): return
	for kind: String in ["maps","tiles"]:
		var directory: String = options.raw_root if kind=="maps" else options.tile_root
		var pin: String = options.source_manifest_sha256 if kind=="maps" else options.tile_manifest_sha256
		var script: Script = RAW if kind=="maps" else TILES
		_full_corruption_guard(options,kind,directory,pin,script)
		var cold_baseline: Array[int] = []; var cold_handoff: Array[int] = []; var consumer_baseline: Array[int] = []; var consumer_handoff: Array[int] = []; var warm: Array[int] = []; var prewarm: Array[int] = []
		for round: int in range(7):
			HANDOFF.clear(); BAKE.clear(script.bake_name_for(pin))
			var began: int = Time.get_ticks_usec()
			var reader: RefCounted = script.new()
			var opened: bool = reader.load_catalog(directory,pin) if kind=="maps" else reader.load_pack(directory,pin)
			var prewarm_us: int = Time.get_ticks_usec()-began
			check(opened,"full synthetic cold metadata validates: "+kind)
			prewarm.append(prewarm_us)
			# Pair both consumer paths with exactly the same cold verification cost.
			# Alternate order to reduce systematic page-cache/order bias; neither
			# path bypasses the manifest or persisted-bake SHA checks.
			for transfer: bool in ([false,true] if round%2==0 else [true,false]):
				if transfer: HANDOFF.put(kind,directory,pin,reader)
				var consumer_started: int = Time.get_ticks_usec()
				var controller := CONTROLLER.new()
				var adopted: RefCounted = controller._catalog_for(options) if kind=="maps" else controller._tiles_for(options)
				var consumer_us: int = Time.get_ticks_usec()-consumer_started
				check(adopted!=null,"full synthetic controller accepts: "+kind)
				check((controller.input_cache_metrics().source_catalog_handoffs if kind=="maps" else controller.input_cache_metrics().tile_catalog_handoffs)==(1 if transfer else 0),"full synthetic expected ownership path: "+kind)
				if transfer: cold_handoff.append(prewarm_us+consumer_us); consumer_handoff.append(consumer_us)
				else: cold_baseline.append(prewarm_us+consumer_us); consumer_baseline.append(consumer_us)
			HANDOFF.clear()
			var warm_started: int = Time.get_ticks_usec()
			var ordinary: RefCounted = script.new()
			opened = ordinary.load_catalog(directory,pin) if kind=="maps" else ordinary.load_pack(directory,pin)
			warm.append(Time.get_ticks_usec()-warm_started)
			check(opened,"full synthetic warm open accepts: "+kind)
		measurements[kind] = {"rounds":7,"unit":"us","design":"paired_shared_cold_prewarm_alternating_consumer_order","shared_cold_prewarm":prewarm,"cold_prebake_plus_reopen":cold_baseline,"cold_prebake_plus_handoff":cold_handoff,"consumer_reopen":consumer_baseline,"consumer_handoff":consumer_handoff,"warm_consumer_only":warm,"manifest_bytes":FileAccess.get_size(directory.path_join(script.MANIFEST_NAME))}

func _full_corruption_guard(options: Dictionary, kind: String, directory: String, pin: String, script: Script) -> void:
	var reader: RefCounted = script.new()
	check(reader.load_catalog(directory,pin) if kind=="maps" else reader.load_pack(directory,pin),"full synthetic guard reader opens: "+kind)
	var manifest_path: String = directory.path_join(script.MANIFEST_NAME)
	var original_manifest: PackedByteArray = FileAccess.get_file_as_bytes(manifest_path)
	var mutated: PackedByteArray = original_manifest.duplicate(); mutated[0] ^= 1
	HANDOFF.put(kind,directory,pin,reader); store(manifest_path,mutated)
	var controller := CONTROLLER.new()
	var accepted: RefCounted = controller._catalog_for(options) if kind=="maps" else controller._tiles_for(options)
	check(accepted==null,"ordinary open also rejects tampered manifest after refusing handoff: "+kind)
	store(manifest_path,original_manifest)
	HANDOFF.put(kind,directory,pin,reader)
	var bake_path: String = BAKE.data_path(script.bake_name_for(pin))
	var damaged: PackedByteArray = FileAccess.get_file_as_bytes(bake_path); damaged[0] ^= 1
	store(bake_path,damaged)
	controller = CONTROLLER.new()
	accepted = controller._catalog_for(options) if kind=="maps" else controller._tiles_for(options)
	check(accepted!=null and accepted!=reader,"damaged device bake rebuilds from valid original metadata: "+kind)
	check((controller.input_cache_metrics().source_catalog_handoffs if kind=="maps" else controller.input_cache_metrics().tile_catalog_handoffs)==0,"corrupt bake never reaches consumer through handoff: "+kind)
	HANDOFF.put(kind,directory,pin,accepted)
	var transferred: RefCounted = HANDOFF.take(kind,directory,pin)
	check(transferred==accepted,"rebuilt verified metadata can be transferred: "+kind)
	var byte_path: String
	if kind=="maps":
		check(transferred.select_asset("0/"),"synthetic source reader selects its declared asset after transfer")
		byte_path = directory.path_join("originals/Map/0/80008000.s32")
		check(not transferred.read_member("Map/0/80008000.s32").is_empty(),"synthetic source reader verifies original bytes before mutation")
	else:
		byte_path = directory.path_join("originals/Tile/0.ti2")
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(byte_path)
	mutated = original_bytes.duplicate(); mutated[0] ^= 1; store(byte_path,mutated)
	check(transferred.read_member("Map/0/80008000.s32").is_empty() if kind=="maps" else transferred.texture_for(0)==null,"full synthetic original-byte SHA still rejects after transfer: "+kind)
	store(byte_path,original_bytes)
