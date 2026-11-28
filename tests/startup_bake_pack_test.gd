extends SceneTree
## Regression for a sealed bootstrap pack and its regular device-cache readers.
const SEED := preload("res://scripts/boot/startup_bake_pack.gd")
const BAKE := preload("res://scripts/resources/current523_bake_cache.gd")
const QUEST := preload("res://scripts/quests/quest_item_provider238.gd")
const NAME := "startup_seed_fixture"
var KEY := "a".repeat(64)
var failures: Array[String] = []
var checks := 0

class CatalogHost extends Node:
	var catalog_db := {"아이템":[]}
	var catalog_item_by_source_id: Dictionary = {}
	func _catalog_item_from_source_id(id: String) -> Dictionary:
		return catalog_item_by_source_id.get(id, {})

func check_quest_restore() -> void:
	var host := CatalogHost.new()
	var provider := QUEST.new()
	provider._definition_ids = {31:true}
	var row := {"sourceId":"m523:item:3020", "quest238_definition_only":true}
	var cached := {"ids":[3020], "definitions":{}, "rows":[row]}
	var duplicate := {"ids":[3020, 3020], "definitions":{}, "rows":[row]}
	check(not provider._apply_startup_rewards(host, duplicate) and provider.definition_ids() == [31] and host.catalog_db["아이템"].is_empty(), "invalid quest cache leaves all owners untouched")
	check(provider._apply_startup_rewards(host, cached) and provider.definition_ids() == [31, 3020] and host.catalog_db["아이템"] == [row], "verified quest cache preserves catalog order and ownership separation")
	var collision := {"ids":[3021], "definitions":{}, "rows":[row]}
	check(not provider._apply_startup_rewards(host, collision) and provider.definition_ids() == [31, 3020] and host.catalog_db["아이템"] == [row], "a cached definition cannot overwrite an existing catalog owner")
	host.free()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func archive(path: String, index: PackedByteArray, data: PackedByteArray) -> String:
	var zip := ZIPPacker.new()
	zip.open(path)
	zip.start_file(SEED.INDEX)
	zip.write_file(index)
	zip.close_file()
	for i: int in ceili(float(data.size()) / SEED.CHUNK):
		zip.start_file("data/%s/%d" % [NAME, i])
		zip.write_file(data.slice(i * SEED.CHUNK, mini((i + 1) * SEED.CHUNK, data.size())))
		zip.close_file()
	zip.close()
	return FileAccess.get_sha256(path)

func check_reuse(base: String, index_sha: String, original: PackedByteArray) -> void:
	var source := "c".repeat(64)
	var current_key := "d".repeat(64)
	var receipt := {
		"schema": SEED.REUSE_SCHEMA, "engine": BAKE.engine_key(), "index_sha256": index_sha, "source": source,
		"files": {NAME: {"previous_key": KEY, "key": current_key, "sha256": SEED._hash(original), "bytes": original.size()}}
	}
	var proof := JSON.stringify(receipt).to_utf8_buffer()
	check(SEED._decode_reuse(proof, "e".repeat(64)).is_empty(), "changed original selection rejects proof")
	receipt.engine = "different engine"
	check(SEED._decode_reuse(JSON.stringify(receipt).to_utf8_buffer(), source).is_empty(), "different engine rejects proof")
	SEED._reuse = SEED._decode_reuse(proof, source)
	check(BAKE.read(NAME, current_key) == bytes_to_var(original), "seed with exactly proven payload and new key reopens")
	check(BAKE.read(NAME, "e".repeat(64)) == null, "matching file cannot satisfy a different current input key")
	receipt.engine = BAKE.engine_key()
	receipt.index_sha256 = "e".repeat(64)
	SEED._reuse = SEED._decode_reuse(JSON.stringify(receipt).to_utf8_buffer(), source)
	check(BAKE.read(NAME, current_key) == null and BAKE.read(NAME, KEY) != null, "different index cannot relabel an installed seed")
	receipt.index_sha256 = ""
	var device_proof := SEED._decode_reuse(JSON.stringify(receipt).to_utf8_buffer(), source)
	SEED._reuse = device_proof
	check(BAKE.read(NAME, current_key) == null, "device-only proof cannot relabel an installed seed")
	check(BAKE.write(NAME, KEY, bytes_to_var(original)), "old local cache fixture written")
	check(BAKE.read(NAME, current_key) == bytes_to_var(original), "device-only proof works beside an unrelated seed")
	SEED.select(base, "")
	SEED._reuse = device_proof
	check(BAKE.read(NAME, current_key) == bytes_to_var(original), "device-only proof works without a seed pin")
	var local_entry: Dictionary = BAKE._checked_entry(NAME, current_key)
	check(local_entry.get("reused", false) and not local_entry.get("seed", false), "proven local cache is preferred")
	var local := FileAccess.open(local_entry.path, FileAccess.READ_WRITE)
	local.store_8(0xff)
	local.close()
	check(BAKE.read(NAME, current_key) == null, "reused local cache must still pass the payload SHA")
	BAKE.clear(NAME)
	SEED.select(base, index_sha)
	SEED._reuse = SEED._decode_reuse(proof, source)
	var marker := BAKE.verified_file(NAME, current_key)
	var seed_file := FileAccess.open(marker, FileAccess.READ_WRITE)
	seed_file.store_8(0xff)
	seed_file.close()
	check(BAKE.verified_file(NAME, current_key).is_empty(), "reused seed must still pass the payload SHA")
	var file := FileAccess.open(marker, FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	SEED.select(base, index_sha)
	check(BAKE.read(NAME, current_key) == null and BAKE.read(NAME, KEY) != null, "selection clears proof and keeps the exact-key path")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var base := "user://startup_seed_test_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(base)
	var bytes := var_to_bytes({"text":"startup", "padding":"x".repeat(SEED.CHUNK)})
	var index := JSON.stringify({"schema":SEED.SCHEMA,"files":{
		NAME:{"key":KEY,"sha256":SEED._hash(bytes),"bytes":bytes.size()}
	}}).to_utf8_buffer()
	var index_sha := SEED._hash(index)
	var path := base.path_join("startup.zip")
	var archive_sha := archive(path, index, bytes)
	var pin := {"archive_sha256":archive_sha, "index_sha256":index_sha}
	var seed := SEED.new()
	check(not seed.begin(path, base, pin, "0".repeat(64)), "unapproved archive digest rejected")
	check(seed.begin(path, base, pin, archive_sha), "pinned ZIP opens")
	seed.advance()
	seed.close()
	SEED.select(base, index_sha)
	check(not BAKE.present(NAME, KEY), "interrupted install publishes no pointer")
	check(seed._written == SEED.CHUNK, "installer advanced by one bounded chunk")
	seed = SEED.new()
	check(seed.begin(path, base, pin, archive_sha), "retry opens")
	for i: int in 5: seed.advance()
	check(seed.done and seed.problem.is_empty(), "all chunks and index published")
	seed.close()
	SEED.select(base, "c".repeat(64))
	check(BAKE.read(NAME, KEY) == null, "different installed bundle ignored")
	SEED.select(base, index_sha)
	check(BAKE.present(NAME, KEY) and BAKE.read(NAME, KEY) == bytes_to_var(bytes), "real cache fallback matches exact payload")
	check(not BAKE.present(NAME, "b".repeat(64)), "different producer key is still a miss")
	check_reuse(base, index_sha, bytes)
	check(BAKE.write(NAME, "b".repeat(64), {"local":true}), "ordinary local cache published")
	check(BAKE.read(NAME, "b".repeat(64)) == {"local":true}, "local generation retained beside seed")
	check(BAKE.read(NAME, KEY) == bytes_to_var(bytes), "different local key does not mask seed")
	var marker := BAKE.verified_file(NAME, KEY)
	check(marker.get_base_dir().begins_with(base), "file-format readers get the verified installed member")
	var data := FileAccess.open(marker, FileAccess.READ_WRITE)
	data.seek(data.get_length()-1)
	data.store_8(0xff)
	data.close()
	check(BAKE.read(NAME, KEY) == null and BAKE.verified_file(NAME, KEY).is_empty(), "corrupted installed seed rejected")
	check(BAKE.read(NAME, "b".repeat(64)) == {"local":true}, "corruption doesn't affect local generation")
	check(BAKE.write(NAME, KEY, {"local":2}) and BAKE.read(NAME, KEY) == {"local":2}, "ordinary rebuild replaces only its local cache")
	SEED.select("", "")
	BAKE.clear(NAME)
	check_quest_restore()
	print("STARTUP_BAKE_PACK_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
