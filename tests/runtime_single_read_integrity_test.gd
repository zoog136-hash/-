extends SceneTree
## Synthetic data through production consumers. The fixture is named so a
## host byte-read probe can independently count exact payloads with no runtime
## instrumentation or change to original asset handling.
const CHECKED_BYTES = preload("res://scripts/resources/checked_resource_bytes.gd")
const EFFECTS = preload("res://scripts/resources/current523_source_effect_selection.gd")
const AWAKE = preload("res://scripts/resources/current523_source_awakening_selection.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const WORKER = preload("res://scripts/resources/sp2_background_loader.gd")
const FRAMES = preload("res://scripts/monsters/patch523_effect_frames.gd")
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const ROOT = "user://pinned-read-fixture"
const LAND_SPEC = {"ID":4,"AssetPath":"Aden/"}
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr(message)

func write(path: String, bytes: PackedByteArray) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return BANK.digest(bytes)

func encoded(value: Variant) -> PackedByteArray:
	var bytes := PackedByteArray([0xEF, 0xBB, 0xBF])
	bytes.append_array((JSON.stringify(value, "\t").replace("\n","\r\n") + "\r\n").to_utf8_buffer())
	return bytes

func put(path: String, value: Variant) -> Dictionary:
	var bytes: PackedByteArray = encoded(value)
	return {"sha256":write(path, bytes),"bytes":bytes.size(),"file":path.get_file()}

func options(path: String, sha: String) -> Dictionary:
	return {"manifest_path":path,"manifest_sha256":sha}

func run() -> void:
	var previous_worker: bool = WORKER.enabled
	WORKER.enabled = false
	for relative: String in ["", "sprite-test/frames", "land-good/lands", "land-bad/lands", "land-missing-size/lands"]:
		DirAccess.make_dir_recursive_absolute(ROOT.path_join(relative))
	var manifest: Dictionary = {"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","actors":{},"source_action_domains":{},"source_dummy_exclusion_policy":BANK.SOURCE_DUMMY_EXCLUSION_POLICY,"excluded_source_actors":{},"proof":"한글"}
	for item: Array in [[EFFECTS,"effect","current523_effect_bank_pin_changed"],[AWAKE,"awakening","current523_awakening_bank_pin_changed"]]:
		var script: Script = item[0]
		var base: String = ROOT.path_join(str(item[1]))
		var good: String = base + "-good.json"
		var spec: Dictionary = put(good, manifest)
		var loaded: Dictionary = script._bank(options(good,spec.sha256))
		check(loaded.get("ok",false) and loaded.get("manifest") == manifest, str(item[1]) + ": valid BOM/CRLF manifest and Korean text")
		var bad: String = base + "-bad.json"
		var changed: Dictionary = manifest.duplicate(); changed.proof = "변경"
		var altered: Dictionary = put(bad, changed)
		check(altered.bytes == spec.bytes and altered.sha256 != spec.sha256, str(item[1]) + ": equal-byte-length mutation")
		check(script._bank(options(bad,spec.sha256)).get("reason") == item[2], str(item[1]) + ": matching size, wrong SHA rejected")
		var warm: String = base + "-warm.json"
		put(warm, manifest)
		check(script._bank(options(warm,spec.sha256)).get("ok",false) and script._bank(options(warm,spec.sha256)).get("ok",false), str(item[1]) + ": warm re-use keeps accepted contents")
		write(warm,encoded(changed) + PackedByteArray([32]))
		check(script._bank(options(warm,spec.sha256)).get("reason") == item[2], str(item[1]) + ": changed warmed file rejected")
	text_semantics()
	raster()
	world_links()
	WORKER.enabled = previous_worker
	print("RUNTIME_SINGLE_READ_INTEGRITY_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func text_semantics() -> void:
	var path: String = ROOT.path_join("compat.json")
	var original: Dictionary = {"name":"아덴","spaces":" a b ","rows":[1,2,false]}
	var bytes: PackedByteArray = encoded(original)
	var sha: String = write(path, bytes)
	var file := FileAccess.open(path,FileAccess.READ)
	var previous: Variant = JSON.parse_string(file.get_as_text())
	file.seek(0)
	var result: Dictionary = CHECKED_BYTES.read_json(file,bytes.size(),sha)
	check(result.verified and result.value == previous and result.value == JSON.parse_string(FileAccess.get_file_as_string(path)) and result.value.name == original.name and result.value.rows.map(func(value): return int(value)) == [1,2,0], "JSON parity: UTF-8 BOM, CRLF, Hangul and typed fields")
	file.seek(0)
	check(not CHECKED_BYTES.read_json(file,bytes.size()+1,sha).verified, "short read does not accept a valid prefix")

func raster() -> void:
	var base: String = ROOT.path_join("sprite-test")
	var path: String = base.path_join("frames/good.png")
	var image := Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2,0.4,0.6,1))
	image.set_pixel(0,0,Color(1,0,0,0.5))
	var bytes: PackedByteArray = image.save_png_to_buffer()
	var sha: String = write(path,bytes)
	var row: Dictionary = {"source_action_id":0,"source_sprite_id":123,"source_fps":8,"runtime_rgba_bytes":24,"frames":[{"path":"frames/good.png","bytes":bytes.size(),"sha256":sha,"offset":[-3,9],"source_ticks":1}]}
	var value: Dictionary = {"schema":1,"kind":"patch523_source_effect_frames","source_snapshot":"patch523","mode":"M_commandwise_RGB565_candidate","native_runtime_verified":false,"catalog_sha256":"2d43c3da5e26afc917cb73e599181eb0c57d7982cee13e496576cd6d9bda808b","records":{"123":row}}
	var manifest: String = base.path_join("good.json")
	var spec: Dictionary = put(manifest, value)
	var frames = FRAMES.new()
	check(frames.load_pack(manifest,spec.sha256), "exact raster manifest accepted")
	frames.enabled = true
	var sprite: Node2D = frames.make_effect(123,0)
	check(sprite != null and sprite.frame_index == 0 and sprite.sprite.position == Vector2(-3,9) and sprite.total == 0.125 and sprite.decoded_budget == 24, "first exact raster pose, offset, duration and budget unchanged")
	if sprite != null:
		# The headless renderer exposes the source Image through ImageTexture.
		var actual: Image = sprite.sprite.texture.get_image()
		check(actual != null and actual.get_size() == image.get_size() and actual.get_data() == image.get_data(), "all first-frame texel bytes unchanged")
		sprite.free()
	var bad: String = base.path_join("bad.json")
	put(bad, value)
	check(not FRAMES.new().load_pack(bad,"0".repeat(64)), "wrong raster manifest pin rejects")
	bytes[-1] = (int(bytes[-1]) + 1) % 256
	write(base.path_join("frames/bad.png"),bytes)
	frames.records["123"].frames[0].path = "frames/bad.png"
	check(frames.make_effect(123,0) == null and frames.error == "frame_hash_or_size_rejected", "same-size bad PNG rejected before decoding")

func make_land(relative: String, invalid: bool = false, missing_size: bool = false) -> Dictionary:
	var base: String = ROOT.path_join(relative)
	var shard: Dictionary = {"schema":1,"source_snapshot":"patch523","land":LAND_SPEC,"territories":[],"portals":[],"spawn_relations":[],"spawn_views":[],"npc_classes":[],"pack_context":{"NpcSpawnPackSchedulePeriod":[],"DaynightSpawnPack":[],"WorldBossRaidView":[],"NpcRepresentativeSpawnView":[]},"unresolved_class_view_packs":[]}
	var shard_spec: Dictionary = put(base.path_join("lands/4.json"),shard)
	shard_spec.file = "lands/4.json"; shard_spec.asset_path = "Aden/"
	if missing_size: shard_spec.erase("bytes")
	var tables: Dictionary = {}
	for table: String in ["NpcCategory","ServerLimit","WeeklyOpenTimeGroup","WeeklyOpenTimeGroupSet","WeeklyOpenTime","WeeklyOpenTimeEntity","LandAttribute","LandAttributeType","LandTimeLimit","LandTimeLimitGroup","LandWeeklyOpenTime","DateTimes","DateTimes_Korean","CompetitionDungeon","CompetitionDungeonLand","CompetitionDungeonView","LandTeleport","LandTeleportTerritories","LandTeleportPrerequisite","Prerequisite","PrerequisiteType","WorldBossRaidPrerequisite","WorldBossRaidPrerequisiteView"]: tables[table] = []
	tables.LandTeleport = [{"ID":7,"Name":"아덴"}]
	var conditions: Dictionary = {"schema":1,"source_snapshot":"patch523","tables":tables}
	var cond_spec: Dictionary = put(base.path_join("conditions.json"),conditions)
	var manifest: Dictionary = {"schema":1,"source_snapshot":"patch523","source_zip_sha256":LINKS.SOURCE_SHA256,"lands":{"4":shard_spec},"conditions":cond_spec}
	var manifest_spec: Dictionary = put(base.path_join("manifest.json"),manifest)
	if invalid:
		tables.LandTeleport[0].Name = "기란"
		var changed: Dictionary = put(base.path_join("conditions.json"),conditions)
		check(changed.bytes == cond_spec.bytes and changed.sha256 != cond_spec.sha256, "same-size world condition mutation")
	return {"root":base,"sha":manifest_spec.sha256}

func world_links() -> void:
	LINKS.reset_shared()
	var good: Dictionary = make_land("land-good")
	var links = LINKS.new()
	check(links.load_land(good.root,4,"Aden/",good.sha), "cold Land accepts exact manifest, shard and conditions")
	check(links.context_row("LandTeleport",7).get("Name") == "아덴" and int(links.land.get("ID",-1)) == LAND_SPEC.ID and links.land.get("AssetPath") == LAND_SPEC.AssetPath, "unchanged returned Land/shard and context values")
	var bad: Dictionary = make_land("land-bad",true)
	check(not links.load_land(bad.root,4,"Aden/",bad.sha) and not links.loaded, "cold Land rejects equal-length tampered conditions")
	var no_length: Dictionary = make_land("land-missing-size",false,true)
	check(not links.load_land(no_length.root,4,"Aden/",no_length.sha) and not links.loaded, "cold Land rejects declared shard with missing byte count")
