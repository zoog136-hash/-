extends SceneTree
## Integration check of the image pack's texture cache through the REAL
## Source523ImagePack._texture()/_bytes() path. The pack root is a temporary
## folder with synthetic PNG files; member records are set directly (the same
## fields _open_verified() records), so no private original, manifest or
## user:// bake is involved. This does not cover _open_verified(), the real
## catalog, real pack inputs, UI or Android. Run:
##   godot --headless --path <repo> --script res://tests/source523_image_pack_texture_cache_test.gd
const PACK = preload("res://scripts/resources/source523_image_pack.gd")
var checks: int = 0
var failures: Array[String] = []
var pack_root: String = ""

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		if failures.size() < 20: failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	pack_root = OS.get_cache_dir().path_join("twilight_texture_cache_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(pack_root.path_join("img"))
	_reuse_through_texture()
	_verification_still_runs_on_hit()
	_dimension_and_decode_failures()
	_budget_through_pack_api()
	_remove_tree(pack_root)
	print("SOURCE523_IMAGE_PACK_TEXTURE_CACHE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,
		"scope":"real_texture_and_bytes_with_synthetic_png","real_input_checked":false}))
	quit(0 if failures.is_empty() else 1)

## Writes a w x h PNG and returns the member record _texture() expects.
func _png(name: String, w: int, h: int, color: Color) -> Dictionary:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var bytes: PackedByteArray = image.save_png_to_buffer()
	var relative: String = "img/" + name + ".png"
	var file := FileAccess.open(pack_root.path_join(relative), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return {"file":relative, "plain_bytes":bytes.size(), "sha256":_sha(bytes), "format":"PNG", "width":w, "height":h}

func _sha(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _pack(members: Dictionary) -> RefCounted:
	var pack: RefCounted = PACK.new()
	pack._root = pack_root
	pack._members = members
	return pack

func _overwrite(relative: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(pack_root.path_join(relative), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _read(relative: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(pack_root.path_join(relative))

func _reuse_through_texture() -> void:
	var a: Dictionary = _png("a", 4, 4, Color.RED)
	var pack: RefCounted = _pack({"a.png":a})
	var first: Dictionary = pack._texture("a.png", {})
	check(first.ok and first.texture is Texture2D, "a verified member decodes to a texture")
	check(first.status == "verified_original_texture" and first.original_bytes_unchanged == true, "the success status is unchanged")
	var second: Dictionary = pack._texture("a.png", {})
	check(second.ok and second.texture == first.texture, "the same member returns the same texture (no second decode)")
	var metrics: Dictionary = pack.texture_cache_metrics()
	check(metrics.misses == 1 and metrics.resident_hits == 1, "one miss then one resident hit")
	check(metrics.resident_decoded_bytes_estimate == 4 * 4 * 4, "resident bytes are the decoded RGBA8 payload")
	check(pack.get("_textures") == null, "the unbounded per-pack texture dictionary is gone")

func _verification_still_runs_on_hit() -> void:
	var b: Dictionary = _png("b", 4, 4, Color.GREEN)
	var pack: RefCounted = _pack({"b.png":b})
	var good: Dictionary = pack._texture("b.png", {})
	check(good.ok, "member b decodes")
	var original: PackedByteArray = _read(b.file)
	# Same length, one changed byte: a cached texture must not be returned.
	var tampered: PackedByteArray = original.duplicate()
	tampered[tampered.size() - 5] = tampered[tampered.size() - 5] ^ 0xff
	_overwrite(b.file, tampered)
	var same_length: Dictionary = pack._texture("b.png", {})
	check(not same_length.ok and same_length.status == "file_sha_mismatch" and same_length.texture == null, "same-length tampering fails even with a resident entry")
	# Changed size.
	var longer: PackedByteArray = original.duplicate()
	longer.append(0)
	_overwrite(b.file, longer)
	var size_changed: Dictionary = pack._texture("b.png", {})
	check(not size_changed.ok and size_changed.status == "file_bytes_mismatch", "a size change fails even with a resident entry")
	# Missing file.
	DirAccess.remove_absolute(pack_root.path_join(b.file))
	var missing_file: Dictionary = pack._texture("b.png", {})
	check(not missing_file.ok and missing_file.status == "file_bytes_mismatch", "a missing file fails even with a resident entry")
	# Restored bytes verify again and reuse the still-cached texture.
	_overwrite(b.file, original)
	var restored: Dictionary = pack._texture("b.png", {})
	check(restored.ok and restored.texture == good.texture, "restored exact bytes verify and reuse the cached texture")
	# Missing member record and a wrong pin.
	check(pack._texture("nope.png", {}).status == "missing_current_member", "a missing member still fails")
	var wrong_pin: Dictionary = b.duplicate()
	wrong_pin.sha256 = "0".repeat(64)
	var pinned: RefCounted = _pack({"b.png":wrong_pin})
	pinned._texture_cache = pack._texture_cache # share a cache that holds b
	var bad_pin: Dictionary = pinned._texture("b.png", {})
	check(not bad_pin.ok and bad_pin.status == "file_sha_mismatch", "a wrong pin fails even when the cache holds that path")
	var bad_contract: Dictionary = b.duplicate()
	bad_contract.sha256 = "not-a-sha"
	check(_pack({"b.png":bad_contract})._texture("b.png", {}).status == "invalid_file_contract", "an invalid contract still fails")

func _dimension_and_decode_failures() -> void:
	var c: Dictionary = _png("c", 4, 2, Color.BLUE)
	var wrong_size: Dictionary = c.duplicate()
	wrong_size.width = 5
	var result: Dictionary = _pack({"c.png":wrong_size})._texture("c.png", {})
	check(not result.ok and result.status == "original_image_decode_failed", "wrong declared dimensions fail")
	# A decode failure (verified bytes that do not decode as the declared
	# format). An undeclared format is used instead of corrupt PNG bytes because
	# the engine's PNG loader prints ERROR: lines, which the core gate counts as
	# failures; both reach the same original_image_decode_failed branch.
	var d: Dictionary = _png("d", 2, 2, Color.WHITE)
	var undecodable: Dictionary = d.duplicate()
	undecodable.format = "GIF"
	var pack: RefCounted = _pack({"d.png":undecodable})
	var bad: Dictionary = pack._texture("d.png", {})
	check(not bad.ok and bad.status == "original_image_decode_failed" and bad.texture == null, "an image that does not decode fails")
	check(pack.texture_cache_metrics().tracked_entries == 0, "a failed decode is not cached")
	check(not pack._texture("d.png", {}).ok, "a failed decode fails again (no cached success)")
	var valid: Dictionary = _pack({"d.png":d})._texture("d.png", {})
	check(valid.ok, "the same bytes decode when the declared format is right")

func _budget_through_pack_api() -> void:
	var members: Dictionary = {}
	for index: int in 6:
		members["k%d.png" % index] = _png("k%d" % index, 8, 8, Color(index / 6.0, 0, 0)) # 256 decoded bytes each
	var pack: RefCounted = _pack(members)
	pack.configure_texture_cache(512, 4096)
	var held: Array[Texture2D] = []
	for index: int in 6:
		var result: Dictionary = pack._texture("k%d.png" % index, {})
		check(result.ok, "member k%d decodes" % index)
		held.append(result.texture)
	var metrics: Dictionary = pack.texture_cache_metrics()
	check(metrics.resident_decoded_bytes_estimate <= 512 and metrics.resident_entries == 2, "the configured budget bounds resident textures")
	check(metrics.tracked_entries == 6, "evicted textures that callers still hold stay tracked")
	var again: Dictionary = pack._texture("k0.png", {})
	check(again.ok and again.texture == held[0] and pack.texture_cache_metrics().weak_hits == 1, "an evicted texture a caller still holds is reused, not decoded again")
	pack.trim_texture_cache(0)
	metrics = pack.texture_cache_metrics()
	check(metrics.resident_entries == 0 and metrics.budget_bytes == 512, "trim drops resident references and keeps the budget")
	check(held[1].get_width() == 8, "trim leaves caller-held textures usable")
	pack.clear_texture_cache(true)
	check(pack.texture_cache_metrics().tracked_entries == 0, "clear(true) forgets tracking")
	var after: Dictionary = pack._texture("k1.png", {})
	check(after.ok and after.texture != held[1], "after clear(true) the next request decodes again (documented duplicate)")

func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for name: String in dir.get_files(): dir.remove(name)
	for name: String in dir.get_directories(): _remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
