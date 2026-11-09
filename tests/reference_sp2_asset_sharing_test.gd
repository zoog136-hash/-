extends SceneTree
## Acceptance probe for handoff P2 (shared SP2 parse + frame textures).
## Synthetic data only: it writes tiny hand-made FE SP2 members and pinned
## bank manifests under --data (default user://zz_probe_sp2_assets), never the
## private bank, never Main.tscn. Run:
##   godot --headless --path <repo> --script res://tests/reference_sp2_asset_sharing_test.gd [-- --data=<new dir>]
## Synthetic pixels prove sharing/lease/key mechanics and equality with the
## unshared decoder path; they are not original-resource or M-visual evidence.
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const N = 6
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func argument(prefix: String, fallback: String) -> String:
	for item: String in OS.get_cmdline_user_args():
		if item.begins_with(prefix): return item.trim_prefix(prefix)
	return fallback

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func write_json(path: String, value: Dictionary) -> String:
	write_bytes(path, JSON.stringify(value).to_utf8_buffer())
	return FileAccess.get_sha256(path)

## One FE (uncompressed) SP2 body: 4-entry RGB565 palette, direction bit 0,
## one 2x2 frame per entry of `frames` (four palette indices each).
static func make_sp2(palette: Array, frames: Array) -> PackedByteArray:
	var out := PackedByteArray([254, 4])
	var put16 := func(value: int) -> void:
		out.append(value & 255)
		out.append((value >> 8) & 255)
	for word: int in palette: put16.call(word)
	out.append(1) # group mask: bit 0
	out.append(frames.size())
	for index: int in range(frames.size()):
		for value: int in [0, 0, 2, 2]: put16.call(value) # half-open bounds
		put16.call(1) # one reference
		out.append_array(PackedByteArray([0, 0, 0])) # a, b, type
		put16.call(index) # first reference word = block index
	var count := PackedByteArray()
	count.resize(4)
	count.encode_s32(0, frames.size())
	out.append_array(count)
	for _index: int in range(frames.size()):
		out.append_array(PackedByteArray([0, 0, 2]))
		put16.call((2 << 5) | (1 << 10)) # two samples, then next row
		put16.call(2 << 5) # two samples
	for samples: Array in frames:
		for sample: int in samples: out.append(sample)
	return out

func member_spec(member: String, path: String) -> Dictionary:
	return {"member":member,"path":"raw/" + member,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size()}

func manifest(sprites: Array, members: Dictionary, variant: String) -> Dictionary:
	var pictures: Dictionary = {}
	for id: int in sprites:
		pictures["sprite:%d" % id] = {"branch":"client_static_no_action_descriptor","layers":[{"kind":"body","source_sprite_id":id,"group_bit":0,"frame_index":0,"file_sprite_id":id,"member":"Sprite/%d-0.sp2" % id}]}
	return {"schema":1,"kind":"current523_reference_sp2_action_bank","source_snapshot":"patch523","probe_variant":variant,"static_picture_contract":{"branch":"client_static_no_action_descriptor","frame":"direction0_picture0","evidence":"zz_probe synthetic contract"},"static_pictures":pictures,"members":members,"actors":{}}

func image_sha(image: Image) -> String:
	return image.get_data().hex_encode().sha256_text() + ":%dx%d" % [image.get_width(), image.get_height()]

## The unshared reference: a fresh decoder parse and render, exactly as the
## old per-bank/per-preview path made its ImageTexture.
func unshared_hash(raw_path: String, frame: int) -> String:
	var parsed: Dictionary = DECODER.parse(FileAccess.get_file_as_bytes(raw_path))
	var rendered: Dictionary = DECODER.render(parsed, 0, frame)
	return image_sha(ImageTexture.create_from_image(rendered.image).get_image())

## The same converted layer shape load_bank() gives the preview.
func preview_layer(bank: RefCounted, base: Dictionary, frame: int) -> Dictionary:
	var layer: Dictionary = base.duplicate(true)
	layer.frame_index = frame
	var picture: Dictionary = bank.render_layer(layer, false)
	layer.merge({"path":"raw/" + str(layer.member),"texture_key":"%s:%d:%d" % [layer.member, int(layer.group_bit), frame],"offset":[picture.offset.x, picture.offset.y],"layer_id":int(layer.source_sprite_id),"frame_provenance":picture.provenance})
	return layer

func make_preview(bank: RefCounted, base: Dictionary, manifest_path: String) -> Node2D:
	var frames: Array = []
	for frame: int in [0, 1]: frames.append({"duration":0.1,"source_ticks":1,"source_group":0,"source_frame":frame,"layers":[preview_layer(bank, base, frame)],"effect_layers":[]})
	var directions: Array = []
	for _direction: int in range(8): directions.append(frames)
	var track: Dictionary = {"source_action_id":0,"source_action_key":"zz_probe","source_sprite_id":int(base.source_sprite_id),"loop":true,"directions":directions,"static_pending_timing":false,"timing_origin":"zz_probe"}
	var preview: Node2D = PREVIEW.new()
	root.add_child(preview)
	preview._reference_bank = bank
	preview._configure_source_nodes({"source_sprite_id":int(base.source_sprite_id)}, {"idle":track}, 1, manifest_path)
	preview._role = "idle"
	return preview

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var data: String = argument("--data=", "user://zz_probe_sp2_assets")
	ASSETS.reset_for_tests()
	var palette_a: Array = [0xF800, 0x07E0, 0x001F, 0xFFFF]
	var raw_a: String = data.path_join("raw/Sprite/9001-0.sp2")
	write_bytes(raw_a, make_sp2(palette_a, [[0, 1, 2, 3], [3, 2, 1, 0]]))
	var members: Dictionary = {"Sprite/9001-0.sp2":member_spec("Sprite/9001-0.sp2", raw_a)}
	for id: int in [9002, 9003, 9004]:
		var path: String = data.path_join("raw/Sprite/%d-0.sp2" % id)
		write_bytes(path, make_sp2(palette_a, [[id % 4, 1, 1, 0], [0, 0, 0, id % 4]]))
		members["Sprite/%d-0.sp2" % id] = member_spec("Sprite/%d-0.sp2" % id, path)
	check(DECODER.parse(FileAccess.get_file_as_bytes(raw_a)).get("ok", false), "synthetic SP2 member decodes")
	var path_a: String = data.path_join("manifest_a.json")
	var sha_a: String = write_json(path_a, manifest([9001, 9002, 9003, 9004], members, "a"))
	var path_b: String = data.path_join("manifest_b.json")
	var sha_b: String = write_json(path_b, manifest([9001], {"Sprite/9001-0.sp2":members["Sprite/9001-0.sp2"]}, "b"))
	check(sha_a != sha_b, "two distinct verified manifest identities")

	# 1. N banks of one member share one parse; admission stays per bank.
	var banks: Array = []
	var opened: Array = []
	for _index: int in range(N):
		var bank: RefCounted = BANK.new()
		var loaded: Dictionary = bank.load_static(path_a, sha_a, 9001)
		check(loaded.get("ok", false), "bank loads synthetic static picture: " + str(loaded.get("error", "")))
		banks.append(bank)
		opened.append(loaded)
	var stats: Dictionary = ASSETS.stats()
	check(int(stats.parsed.counters.get("created", 0)) == 1 and int(stats.parsed.live_count) == 1 and int(stats.parsed.leases) == N, "N banks hold one shared parse with N leases")
	var member: String = "Sprite/9001-0.sp2"
	var shared_parse: Dictionary = banks[0]._parsed[member]
	var all_same: bool = true
	for bank: RefCounted in banks: all_same = all_same and is_same(bank._parsed[member], shared_parse)
	check(all_same, "every bank sees the same parse object")
	check(shared_parse.is_read_only() and (shared_parse.groups as Array).is_read_only() and (shared_parse.groups[0] as Dictionary).is_read_only() and (shared_parse.groups[0].frames[0] as Dictionary).is_read_only() and (shared_parse.groups[0].frames[0].refs as Array).is_read_only(), "shared parse is deeply read-only")
	check(ASSETS.stats().parsed.pending_count == 0, "no parse reservation left pending")

	# 2. N previews: one texture per shown frame, independent clocks, same pixels.
	var base: Dictionary = opened[0].layers[0]
	var previews: Array = []
	for index: int in range(N): previews.append(make_preview(banks[index], opened[index].layers[0], path_a))
	for index: int in range(N):
		check(previews[index].advance_reference_source(0.15 if index % 2 == 1 else 0.05, "idle", 0), "preview %d advances" % index)
	var clocks: Array = []
	for preview: Node2D in previews: clocks.append(snappedf(preview._clock, 0.001))
	check(is_equal_approx(clocks[0], 0.05) and is_equal_approx(clocks[1], 0.15) and previews[0].last_source_frame == 0 and previews[1].last_source_frame == 1, "clocks and selected frames stay per preview")
	previews[2].advance_reference_source(0.3, "idle", 0)
	check(is_equal_approx(previews[0]._clock, 0.05) and is_equal_approx(previews[1]._clock, 0.15) and is_equal_approx(previews[2]._clock, 0.35), "advancing one preview leaves the others' clocks unchanged")
	var even: Texture2D = previews[0]._layers[0].texture
	var odd: Texture2D = previews[1]._layers[0].texture
	var shared_frames: bool = even != null and odd != null and not is_same(even, odd)
	for index: int in range(N): shared_frames = shared_frames and is_same(previews[index]._layers[0].texture, even if previews[index].last_source_frame == 0 else odd)
	check(shared_frames, "same frame -> same texture object across previews; different frames differ")
	stats = ASSETS.stats()
	# Preview 2 showed frame 0 and then frame 1, so it leases both: N + 1.
	check(int(stats.texture.counters.get("created", 0)) == 2 and int(stats.texture.live_count) == 2 and int(stats.texture.leases) == N + 1, "two unique frames -> two shared textures, one lease per preview per shown frame")
	check(int(stats.parsed.counters.get("created", 0)) == 1, "rendering frames did not re-parse the member")
	check(image_sha(even.get_image()) == unshared_hash(raw_a, 0) and image_sha(odd.get_image()) == unshared_hash(raw_a, 1), "shared texture pixels equal the unshared decoder path")
	var provenance: Dictionary = previews[1].reference_source_frame_status().get("selected_layers", [{}])[0]
	check(provenance.get("member") == member and provenance.get("raw_sha256") == members[member].sha256 and provenance.get("source_stage") == "sha256_pinned_raw_member", "per-preview provenance unchanged")

	# 3. Release: previews then banks drop to lease 0; idle eviction obeys budget.
	for preview: Node2D in previews: preview.free()
	previews.clear()
	stats = ASSETS.stats()
	check(int(stats.texture.leases) == 0 and int(stats.texture.live_count) == 0 and int(stats.texture.idle_count) == 2 and int(stats.texture.idle_bytes) == 32, "freed previews leave two idle 2x2 textures (lease 0)")
	check(ASSETS.trim_idle("texture", 16) == 1 and int(ASSETS.stats().texture.idle_bytes) <= 16, "idle texture eviction respects a byte budget")
	banks.clear()
	opened.clear()
	stats = ASSETS.stats()
	check(int(stats.parsed.leases) == 0 and int(stats.parsed.idle_count) == 1, "released banks leave the parse idle (lease 0)")

	# 4. Idle reuse, live never evicted, bank LRU releases only its own lease.
	var bank_one: RefCounted = BANK.new()
	check(bank_one.load_static(path_a, sha_a, 9001).get("ok", false), "bank reopens member")
	check(int(ASSETS.stats().parsed.counters.get("created", 0)) == 1, "idle parse is reused, not re-decoded")
	ASSETS.trim_idle("parsed", 0)
	check(int(ASSETS.stats().parsed.live_count) == 1, "a leased (live) parse survives a zero idle budget")
	var bank_two: RefCounted = BANK.new()
	check(bank_two.load_static(path_a, sha_a, 9001).get("ok", false), "second bank opens member")
	for id: int in [9002, 9003, 9004]: check(bank_two.load_static(path_a, sha_a, id).get("ok", false), "load_static reopen %d" % id)
	var lru: RefCounted = BANK.new()
	check(lru.load_static(path_a, sha_a, 9001).get("ok", false), "LRU bank opens 9001")
	for id: int in [9002, 9003, 9004]:
		var layer: Dictionary = {"kind":"body","source_sprite_id":id,"group_bit":0,"frame_index":0,"member":"Sprite/%d-0.sp2" % id}
		check(lru.render_layer(layer, false).get("ok", false), "LRU bank verifies member %d" % id)
	check(lru._parsed.size() == 3 and not lru._parsed.has(member), "bank keeps its previous 3-member working set")
	check(int(ASSETS.stats().parsed.live_count) >= 1 and bank_one._parsed.has(member), "another bank's lease is unaffected by this bank's LRU")
	bank_one = null
	bank_two = null
	lru = null

	# 5. Different manifest identity or pixel policy never share.
	var other: RefCounted = BANK.new()
	check(other.load_static(path_b, sha_b, 9001).get("ok", false), "manifest B bank loads")
	var key_a: String = ASSETS.parsed_key(sha_a, member, members[member], raw_a)
	check(other.parsed_asset_key(member) != key_a and not other.parsed_asset_key(member).is_empty(), "manifest B gets its own parsed key")
	var reopened: RefCounted = BANK.new()
	reopened.load_static(path_a, sha_a, 9001)
	check(not is_same(other._parsed[member], reopened._parsed[member]), "manifest A and B parses are separate objects")
	check(ASSETS.rendered_key(key_a, 0, 0) != ASSETS.rendered_key(key_a, 0, 0, "alpha=opaque_samples;rgb=bit_replication;alpha_mode=premultiplied;format=RGBA8;mipmaps=none;compression=none;trim=none"), "PMA policy is a different rendered key")
	check(ASSETS.rendered_key(key_a, 0, 0) != ASSETS.rendered_key(other.parsed_asset_key(member), 0, 0), "different manifests never share a rendered key")
	check(ASSETS.rendered_key(key_a, 0, 0) != ASSETS.rendered_key(key_a, 1, 0) and ASSETS.rendered_key(key_a, 0, 0) != ASSETS.rendered_key(key_a, 0, 1), "direction and frame are part of the rendered key")
	var preview_a: Node2D = make_preview(reopened, reopened.load_static(path_a, sha_a, 9001).layers[0], path_a)
	var preview_b: Node2D = make_preview(other, other.load_static(path_b, sha_b, 9001).layers[0], path_b)
	preview_a.advance_reference_source(0.0, "idle", 0)
	preview_b.advance_reference_source(0.0, "idle", 0)
	var texture_a: Texture2D = preview_a._layers[0].texture
	var texture_b: Texture2D = preview_b._layers[0].texture
	check(texture_a != null and texture_b != null and not is_same(texture_a, texture_b) and image_sha(texture_a.get_image()) == image_sha(texture_b.get_image()), "same bytes under two manifests: separate textures, equal pixels")

	# 6. Received (CRC-only) members keep their domain and are not promoted.
	var received_spec: Dictionary = {"member":member,"path":"raw/" + member,"sha256":null,"bytes":members[member].bytes,"stage":"received_not_additionally_validated","crc32":BANK.crc32(FileAccess.get_file_as_bytes(raw_a)),"source_receipt_id":member,"source_identity":{"source_snapshot":"patch523","basis":"supplied_exact_current523_member_archive_bytes_crc_domain","archive":"zz_probe.zip","source_manifest_reference":"zz_probe","whole_current523_manifest_match":true}}
	var path_c: String = data.path_join("manifest_c.json")
	var sha_c: String = write_json(path_c, manifest([9001], {member:received_spec}, "c"))
	var received: RefCounted = BANK.new()
	var received_open: Dictionary = received.load_static(path_c, sha_c, 9001)
	check(received_open.get("ok", false), "received member bank loads: " + str(received_open.get("error", "")))
	var received_picture: Dictionary = received.render_layer(received_open.get("layers", [{}])[0], true)
	check(received_picture.get("ok", false) and received_picture.provenance.get("source_stage") == "received_not_additionally_validated" and received_picture.provenance.get("raw_sha256") == null, "received member stays CRC/receipt scoped (not SHA-pinned)")
	check(received.parsed_asset_key(member) != ASSETS.parsed_key(sha_c, member, members[member], raw_a), "received key differs from a pinned key for the same bytes")
	check(image_sha(received_picture.image) == unshared_hash(raw_a, 0), "received render pixels equal the unshared path")

	# 7. Shared parse never skips byte verification.
	var original: PackedByteArray = FileAccess.get_file_as_bytes(raw_a)
	var changed: PackedByteArray = original.duplicate()
	changed[changed.size() - 1] = (changed[changed.size() - 1] + 1) % 4
	write_bytes(raw_a, changed)
	var tampered: Dictionary = reopened.render_layer({"kind":"body","source_sprite_id":9001,"group_bit":0,"frame_index":0,"member":member}, false)
	check(not tampered.get("ok", true) and str(tampered.get("error", "")).contains("SHA256 mismatch"), "changed member bytes fail even with a shared parse cached")
	write_bytes(raw_a, original)
	check(reopened.render_layer({"kind":"body","source_sprite_id":9001,"group_bit":0,"frame_index":0,"member":member}, false).get("ok", false), "restored bytes verify again")

	# 8. Reservation/lease contract edges.
	var owner: int = ASSETS.new_owner()
	var reservation: int = ASSETS.reserve("texture", "zz_probe_stale", 4)
	check(int(ASSETS.stats().texture.pending_count) == 1 and int(ASSETS.stats().texture.pending_bytes) == 4, "pending reservation is counted separately")
	ASSETS.invalidate_all()
	ASSETS.complete(reservation, ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)), 4, owner)
	check(not ASSETS.has_entry("texture", "zz_probe_stale") and int(ASSETS.stats().texture.pending_count) == 0, "stale-generation completion is not inserted")
	check(int(ASSETS.stats().texture.stale_live_count) >= 2 and not ASSETS.has_entry("texture", ASSETS.rendered_key(key_a, 0, 0)), "invalidation hides live entries from new acquires, keeps them for lessees")
	check(not ASSETS.release("texture", "zz_probe_missing", owner), "foreign/double release is rejected")
	preview_a.free()
	preview_b.free()
	check(int(ASSETS.stats().texture.stale_live_count) == 0, "stale entries drop when their last lease is released")
	var summary: Dictionary = ASSETS.stats()
	print("REFERENCE_SP2_ASSET_SHARING_PROBE " + JSON.stringify({"checks":checks,"failures":failures,"stats":summary}))
	quit(0 if failures.is_empty() else 1)
