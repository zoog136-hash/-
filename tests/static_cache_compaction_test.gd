extends SceneTree
## Standalone synthetic checks of the static cache reductions (no Main, no
## original data, no asset files): card record sharing, animation profile
## compaction + frame reserve trim, monster art plate release, visual manifest
## sharing, item resolver field/provenance reduction, catalog name index.
##   godot --headless --path <repo> --script res://tests/static_cache_compaction_test.gd
const BASE508 = preload("res://scripts/lineagem_base508.gd")
const ANIM = preload("res://scripts/animation/animation_catalog.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const LOOKUP = preload("res://scripts/catalog_item_lookup.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("STATIC_CACHE_COMPACTION_FAIL: " + label)

func tex(size: int = 4) -> Texture2D:
	return ImageTexture.create_from_image(Image.create(size, size, false, Image.FORMAT_RGBA8))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_card_sharing()
	_animation_profiles()
	_frame_reserve()
	_monster_plates()
	_manifest_sharing()
	_resolver_fields()
	_lookup_index()
	print("STATIC_CACHE_COMPACTION_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _card(id: int) -> Dictionary:
	var identity: Dictionary = {"source_sha256":"ab", "tables":{"BuffCard":{"sha256":"cd"}}}
	return {"sourceId":"m508:%d" % id, "name":"card%d" % id, "source_definition_archive":identity.duplicate(true),
		"source_grade":{"ID":4, "Name":"Hero"}, "source_bonuses":[{"bonus_type":{"Name":"Strength"}, "unit":{"ID":1}, "bonus":{"Value":id}}],
		"source_original":{"card_id":id, "source_definition_archive":identity.duplicate(true)}, "sourceOptions":["STR +%d" % id]}

func _card_sharing() -> void:
	var value: Dictionary = {"catalog":{"변신":[_card(1), _card(2)], "마법인형":[_card(3)], "성물":[]}, "classes":[{"name":"기사", "source_original":{"ID":1}}]}
	var before: PackedByteArray = var_to_bytes(value)
	var first: Dictionary = value.catalog["변신"][0]
	BASE508._share_values(value)
	check(var_to_bytes(value) == before, "card values are byte-identical after sharing")
	check(is_same(value.catalog["변신"][0], first), "record identity (what _by_id holds) is unchanged")
	var a: Dictionary = value.catalog["변신"][0]
	var b: Dictionary = value.catalog["마법인형"][0]
	check(is_same(a.source_definition_archive, b.source_definition_archive) and is_same(a.source_definition_archive, a.source_original.source_definition_archive), "equal archive identities share one instance")
	check(is_same(a.source_grade, b.source_grade), "equal grade rows share one instance")
	check(not is_same(a.source_bonuses, b.source_bonuses) and a.source_bonuses[0].bonus.Value == 1 and b.source_bonuses[0].bonus.Value == 3, "different values stay separate")
	check(is_same(a.source_bonuses[0].unit, b.source_bonuses[0].unit), "equal nested unit rows share one instance")

func _animation_profiles() -> void:
	var source: Dictionary = {
		"monster:a":{"name":"A", "layout":"directional8", "frames_path":"res://x/a.tres", "sprite_offset":[0, -40], "action_hit_frames":{"attack":3}, "prior_visual_profile":{"layout":"still", "big":[1, 2, 3]}, "authoring_reference":"res://ref.png", "body_kind":"beast"},
		"monster:b":{"name":"B", "layout":"directional8", "frames_path":"res://x/b.tres", "sprite_offset":[0, -40], "action_hit_frames":{"attack":3}, "shared_visual_source":"monster:a", "color_tint":"ffffff"}}
	var compact: Dictionary = ANIM.compact_profiles(source)
	check(compact.size() == 2 and compact.keys() == source.keys(), "every profile key is kept in order")
	var exact: bool = true
	for key: String in source:
		for field: String in ANIM.PROFILE_FIELDS:
			if source[key].has(field) != compact[key].has(field) or (source[key].has(field) and source[key][field] != compact[key][field]): exact = false
	check(exact, "every reader field keeps its exact value")
	check(not compact["monster:a"].has("prior_visual_profile") and not compact["monster:a"].has("authoring_reference") and not compact["monster:b"].has("shared_visual_source") and not compact["monster:a"].has("name"), "authoring provenance is not kept resident")
	check(is_same(compact["monster:a"].sprite_offset, compact["monster:b"].sprite_offset) and is_same(compact["monster:a"].action_hit_frames, compact["monster:b"].action_hit_frames), "equal offsets and hit-frame maps share one instance")
	var saved: Dictionary = ANIM.records
	ANIM.records = compact
	var profile: TwilightAnimationProfile = ANIM.for_record("monster", {"sourceId":"a"})
	profile.action_hit_frames["attack"] = 99
	check(int(compact["monster:b"].action_hit_frames.attack) == 3 and int(compact["monster:a"].action_hit_frames.attack) == 3, "a profile editing its dictionary never edits the shared catalog value")
	check(profile.body_kind == "beast" and profile.layout == "directional8", "profile reads compacted settings")
	ANIM.records = saved

func _frame_reserve() -> void:
	ANIM.trim_frames(0)
	var live: Array = []
	var budget_ok: bool = true
	for index: int in 6:
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", tex(512)) # 1 MB estimate each
		live.append(frames)
		ANIM._cache_frames("res://zz/f%d.tres:native8" % index, frames)
		if ANIM.frame_cache_bytes > ANIM.MAX_FRAME_CACHE_BYTES: budget_ok = false
	check(budget_ok and ANIM.MAX_FRAME_CACHE_BYTES <= 24 * 1024 * 1024, "strong frame reserve stays within its lowered budget")
	ANIM.trim_frames(2 * 1024 * 1024)
	check(ANIM.frame_cache_bytes <= 2 * 1024 * 1024 and ANIM.frame_cache.size() == 2 and ANIM.frame_cache.has("res://zz/f5.tres:native8"), "trim keeps the most recent reserve")
	check(ANIM.frame_order.size() == ANIM.frame_cache.size() and ANIM.frame_costs.size() == ANIM.frame_cache.size(), "trim keeps bookkeeping consistent")
	check(is_same(ANIM.frames("res://zz/f0.tres", "native8"), live[0]), "a trimmed but live frame set is reused, not reloaded")
	ANIM.release_region_frames()
	check(ANIM.frame_cache_bytes <= ANIM.MAP_CHANGE_RESERVE_BYTES, "map change trims to the reserve")
	ANIM.trim_frames(0)
	live.clear()
	ANIM.trim_frames(0)
	check(ANIM.frame_cache.is_empty() and ANIM.frame_weak.is_empty() and ANIM.frame_cache_bytes == 0, "released frame sets leave no strong or dead weak entries")

func _monster_plates() -> void:
	var held: Texture2D = tex(8)
	var dropped: Texture2D = tex(8)
	ART.plates.store(900, held, 256)
	ART.plates.store(901, dropped, 256)
	var view := AtlasTexture.new()
	view.atlas = held
	ART.textures.store("900:0", view)
	check(ART.plates.strong_size() <= ART.PLATE_RESERVE, "plate reserve is bounded")
	dropped = null
	ART.release_unused()
	check(ART.plates.strong_size() == 0, "map change drops the cache's own plate references")
	check(is_same(ART.plates.lookup(900), held) and is_same(ART.textures.lookup("900:0"), view), "plates and views still shown elsewhere are the same instances")
	check(ART.plates.lookup(901) == null, "a plate no live owner holds is released")
	ART.plates.clear(true)
	ART.textures.clear(true)

func _manifest_sharing() -> void:
	var tracks: Array = [{"name":"idle_down", "row":0, "count":6, "fps":7, "loop":true}, {"name":"walk_down", "row":1, "count":6, "fps":10, "loop":true}]
	var parsed: Dictionary = {"schema":1, "catalog":{
		"transform:1":{"atlas":"res://assets/a1.webp", "cell":[144, 160], "tracks":tracks.duplicate(true), "directions":4},
		"transform:2":{"atlas":"res://assets/a2.webp", "cell":[144, 160], "tracks":tracks.duplicate(true), "directions":4}},
		"monsters":{"m":{"path":"res://assets/m.png", "source_npc_ids":["1"]}}, "items":{"5":{"name":"검", "path":"res://assets/i.png"}}, "item_names":{"검":"5"}}
	var before: PackedByteArray = var_to_bytes(parsed)
	var compact: Dictionary = VISUALS.compact(parsed)
	check(var_to_bytes(compact) == before, "manifest values are byte-identical after sharing")
	check(is_same(compact.catalog["transform:1"].tracks, compact.catalog["transform:2"].tracks) and is_same(compact.catalog["transform:1"].cell, compact.catalog["transform:2"].cell), "equal track lists and cells share one instance")
	check(compact.catalog["transform:1"].atlas != compact.catalog["transform:2"].atlas, "different atlases stay separate")

func _resolver_fields() -> void:
	var record: Dictionary = {"name":"검", "grade":"영웅", "type":"한손검", "source":"inven", "sourceId":"7", "sourceUrl":"https://x", "imageKey":"k", "sourceOptions":["STR +1"], "desc":"STR +1", "atk":3, "slot":"weapon", "image_path":"res://assets/catalog/k.png"}
	var kept: Dictionary = RESOLVER.source_fields(record)
	check(kept == {"sourceId":"7", "name":"검", "image_path":"res://assets/catalog/k.png", "type":"한손검", "slot":"weapon"}, "resolver keeps only identity/routing fields with their values")
	check(RESOLVER.source_fields({"name":"x", "crafting_scroll":true}).crafting_scroll == true, "ground category flags are kept when present")
	var proofs: Dictionary = {"7":{"path":"res://assets/catalog/k.png", "sha256":"00", "identity":"source_id_name_image_bytes_verified", "rights":"r"},
		"8":{"path":"res://assets/catalog/q.png", "identity":"other"}, "9":{"identity":"source_id_name_image_bytes_verified"}, "10":"bad"}
	var verified: Dictionary = RESOLVER.verified_paths(proofs)
	check(verified == {"7":"res://assets/catalog/k.png"}, "only verified identities with a path remain")
	check(RESOLVER.verified_paths(null).is_empty(), "missing provenance stays empty")

func _linear(rows: Array, item_name: String) -> Dictionary:
	for value: Variant in rows:
		if value is Dictionary and str(value.get("name", "")) == item_name: return value
	return {}

func _collision() -> PackedStringArray:
	# String.hash() is djb2: "Ez" and "FY" both add 69*33+122 == 70*33+89.
	if ("item-Ez".hash() & 0xFFFFFFFF) == ("item-FY".hash() & 0xFFFFFFFF): return PackedStringArray(["item-Ez", "item-FY"])
	# Any other hash: search random names (birthday bound, ~80k expected).
	var random := RandomNumberGenerator.new()
	random.seed = 523
	var seen: Dictionary = {}
	for index: int in 400000:
		var text: String = "r%08x%08x" % [random.randi(), random.randi()]
		var digest: int = text.hash() & 0xFFFFFFFF
		if seen.has(digest) and seen[digest] != text: return PackedStringArray([seen[digest], text])
		seen[digest] = text
	return PackedStringArray()

func _lookup_index() -> void:
	var pair: PackedStringArray = _collision()
	check(pair.size() == 2 and pair[0] != pair[1] and (pair[0].hash() & 0xFFFFFFFF) == (pair[1].hash() & 0xFFFFFFFF), "found two names with one 32-bit hash")
	if pair.size() != 2: return
	var rows: Array = []
	for index: int in 40: rows.append({"name":"n%d" % (index % 30), "n":index})
	rows.insert(5, {"name":pair[1], "n":-5})
	rows.insert(9, {"name":pair[0], "n":-9})
	rows.append({"name":pair[1], "n":-50})
	var exact: bool = true
	for probe: String in [pair[0], pair[1], "n3", "n29", "absent", ""]:
		if not is_same(LOOKUP.first_by_name(rows, probe), _linear(rows, probe)) and not (_linear(rows, probe).is_empty() and LOOKUP.first_by_name(rows, probe).is_empty()): exact = false
	check(exact, "colliding names each return their own first record")
	var builds: int = LOOKUP.index_builds
	rows.append({"name":"tail-new", "n":100})
	check(is_same(LOOKUP.first_by_name(rows, "tail-new"), rows[-1]) and is_same(LOOKUP.first_by_name(rows, pair[0]), rows[9]) and LOOKUP.index_builds == builds, "appended names resolve without a rebuild")
	rows[9] = {"name":"renamed", "n":-99}
	check(LOOKUP.first_by_name(rows, pair[0]).is_empty() and is_same(LOOKUP.first_by_name(rows, pair[1]), rows[5]) and is_same(LOOKUP.first_by_name(rows, "renamed"), rows[9]), "an in-place rename of a colliding name stays exact")
	var metrics: Dictionary = LOOKUP.index_metrics()
	check(int(metrics.key_bytes) == int(metrics.keys) * 8 and int(metrics.sources) <= LOOKUP.MAX_INDEXED_SOURCES, "index is 8 bytes per distinct name within the source bound")
