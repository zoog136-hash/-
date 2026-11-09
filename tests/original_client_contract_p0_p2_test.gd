extends SceneTree
## Original-client contract adapter, phases P0-P2 (handoff package 01-46).
## Runs the acceptance tests C01-T01 .. C08-T04 against the DESIGN modules in
## res://scripts/original_client/. It reads no original binary and no original
## payload; passing means the DESIGN modules follow the written contract, not that
## any native behaviour or on-screen result was observed.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const IDENTITY = preload("res://scripts/original_client/source_identity.gd")
const ENV = preload("res://scripts/original_client/resource_environment.gd")
const READER = preload("res://scripts/original_client/resource_reader.gd")
const RECORD = preload("res://scripts/original_client/resource_record.gd")
const ASSETS = preload("res://scripts/original_client/asset_resolver.gd")
const SELECT = preload("res://scripts/original_client/sprite_selection.gd")
const TIMING = preload("res://scripts/original_client/sprite_timing.gd")
const FIXTURE_PATH := "res://data/original_client/fixtures/p0_p2_first_fixture.json"

var results: Dictionary = {}
var fixture: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(test_id: String, condition: bool, detail: String = "") -> void:
	var entry: Dictionary = results.get(test_id, {"pass": true, "details": []})
	if not condition:
		entry["pass"] = false
		(entry["details"] as Array).append(detail)
	results[test_id] = entry

## JSON object keys are strings; the original tables are integer keyed.
func int_keys(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			var converted: Variant = int(key) if (key is String and (key as String).is_valid_int()) else key
			out[converted] = int_keys(value[key])
		return out
	return value

func vector(id: String) -> Dictionary:
	for v: Variant in fixture.get("vectors", []):
		if v is Dictionary and v.get("id") == id:
			return v
	return {}

func run() -> void:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	fixture = parsed if parsed is Dictionary else {}
	check("FIXTURE", not fixture.is_empty(), "first fixture could not be read")
	run_c01()
	run_c02()
	run_c03()
	run_c04()
	run_c05()
	run_c06()
	run_c07()
	run_c08()
	var failures: Array = []
	for id: String in results:
		if not results[id].pass:
			failures.append({"test": id, "details": results[id].details})
	var report := {
		"fixture_id": fixture.get("fixture_id", ""),
		"fixture_sha256": FileAccess.get_sha256(FIXTURE_PATH),
		"source_lock_sha256": FileAccess.get_sha256(IDENTITY.LOCK_PATH),
		"target_binary_executed": false,
		"executed": results.size(),
		"failures": failures,
		"tests": results,
	}
	print("ORIGINAL_CLIENT_P0_P2_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func run_c01() -> void:
	var wrong: Dictionary = IDENTITY.gate_adapter_entry(IDENTITY.EXE_NAME, "00".repeat(32))
	check("C01-T01", wrong.accepted == false and wrong.status == "DIFFERENT_BUILD_SEPARATED", "different EXE hash must stop adapter entry")
	var same: Dictionary = IDENTITY.gate_adapter_entry(IDENTITY.EXE_NAME, IDENTITY.EXE_SHA256.to_upper())
	check("C01-T01", same.accepted == true and same.status == "SAME_BUILD_IDENTITY_ONLY", "pinned hash must be recognised only as identity")
	check("C01-T01", IDENTITY.gate_adapter_entry("other.exe", IDENTITY.EXE_SHA256).accepted == false, "unknown module must be refused")
	var state: Dictionary = IDENTITY.payload_state(true, false)
	check("C01-T02", state.payload_status == "UNVERIFIED" and state.render_status == "NOT_OBSERVED", "manifest hit alone must stay UNVERIFIED/NOT_OBSERVED")
	var lock: Dictionary = IDENTITY.load_lock()
	check("C01-T02", lock.get("source_identity", {}).get("exe", {}).get("sha256") == IDENTITY.EXE_SHA256, "source lock EXE hash must equal the pinned constant")
	check("C01-T02", (lock.get("sources", []) as Array).size() == 45, "source lock must list the 45 approved members")
	var identity: Dictionary = IDENTITY.from_source_id(lock, "S009")
	check("C01-T02", identity.get("code_origin") == 524 and identity.get("data_snapshot") == 525 and not str(identity.get("sha256")).is_empty(), "SourceIdentity keeps 524/525 apart")
	check("C01-T02", IDENTITY.from_source_id(lock, "S999").is_empty(), "unknown source id must not be invented")

func run_c02() -> void:
	check("C02-T01", ENV.parse_packing_mode("FALSE").mode == 0, "FALSE -> mode 0")
	check("C02-T01", ENV.parse_packing_mode("0").mode == 0, "'0' -> mode 0")
	check("C02-T01", ENV.parse_packing_mode(" false ").mode == 1, "no trim: ' false ' -> mode 1")
	check("C02-T01", ENV.parse_packing_mode("no").mode == 1, "other strings -> mode 1")
	check("C02-T01", ENV.parse_packing_mode(false).status == "STRING_CONVERSION_FAILED", "JSON boolean false is not the string false")
	check("C02-T02", ENV.merge_packing_value("true", null) == "true", "null keeps destination")
	check("C02-T02", ENV.effective_mode(ENV.DEFAULT_PACKING_VALUE) == 1, "first null is effective true")
	check("C02-T02", ENV.merge_packing_value("false", null) == "false", "absent keeps an earlier false")
	check("C02-T02", ENV.merge_packing_value("true", "0") == "0", "a string replaces the destination")
	var swap: Dictionary = ENV.replace_delegate(["a/", "b/"], true)
	check("C02-T03", swap.previous_search_paths_copied == false and swap.layout_manager_ui_paths == "NOT_GUARANTEED_REREGISTERED", "no copied search paths, no UI re-registration guarantee")
	var asset: Dictionary = ENV.asset_path_from_exe_dir("C:\\Game\\Bin\\")
	check("C02-T03", asset.asset_path == "C:/Game/Bin/../Client/", "'..' must not be collapsed")
	check("C02-T03", ENV.asset_path_from_exe_dir("C:\\Game\\Bin").status == "INPUT_REJECTED_NO_TRAILING_SEPARATOR", "missing separator is rejected (DESIGN)")
	var ordered: Dictionary = ENV.search_paths("A/", "D/", 1, true, true, false)
	check("C02-T03", ordered.paths == ["A/UI/", "D/", "D/Resources/", "A/"], "mode-1 search order A+UI/, D, D+Resources/, A")
	check("C02-T03", ENV.search_paths("A/", "D/", 0, true, true, false).status == "UNVERIFIED", "uncovered combination is UNVERIFIED")

func make_reader() -> Array:
	var calls: Dictionary = {"dat": [], "loose": [], "stream": 0}
	var reader := READER.new()
	reader.key_provider_ref = "approved_local_key_provider"
	reader.manifest = {
		"content/itemclass.json": {"canonical": "content/ItemClass.json", "container": "content8.dat", "container_version": "8", "backend": "dat_type1"},
		"content/empty.json": {"canonical": "content/Empty.json", "container": "content8.dat", "container_version": "8", "backend": "dat_type1"},
		"data/bundle.bin": {"canonical": "data/Bundle.bin", "container": "bundle.dat", "container_version": "1", "backend": READER.BUNDLE_BACKEND},
		"content/brotli.json": {"canonical": "content/Brotli.json", "container": "content8.dat", "container_version": "8", "backend": "dat_type1"},
		"content/broken.json": {"canonical": "content/Broken.json", "container": "content8.dat", "container_version": "8", "backend": "dat_type1"},
	}
	reader.dat_backend = func(container: String, canonical: String) -> Dictionary:
		(calls.dat as Array).append([container, canonical])
		if canonical == "content/ItemClass.json" or canonical == "data/Bundle.bin":
			return {"ok": true, "bytes": PackedByteArray([1, 2, 3]), "decode": "ok"}
		if canonical == "content/Empty.json":
			return {"ok": true, "bytes": PackedByteArray(), "decode": "ok"}
		if canonical == "content/Brotli.json":
			return {"ok": true, "bytes": PackedByteArray([9, 9]), "decode": "probe_failed"}
		return {"ok": false, "bytes": PackedByteArray()}
	reader.loose_backend = func(logical: String) -> Dictionary:
		(calls.loose as Array).append(logical)
		if logical == "loose/only.txt":
			return {"ok": true, "bytes": PackedByteArray([7])}
		return {"ok": false, "bytes": PackedByteArray()}
	return [reader, calls]

func run_c03() -> void:
	var pair: Array = make_reader()
	var reader: Object = pair[0]
	var calls: Dictionary = pair[1]
	var hit: Dictionary = reader.read_bytes("Content/ItemClass.JSON")
	check("C03-T01", hit.status == "Decoded" and hit.container == "content8.dat" and hit.canonical_name == "content/ItemClass.json", "manifest must connect ItemClass to content8.dat with its canonical member")
	check("C03-T01", (calls.dat as Array)[0] == ["content8.dat", "content/ItemClass.json"], "backend must receive the canonical name, not the caller spelling")
	check("C03-T01", not str(hit.provenance).contains("secret") and str(hit.provenance).contains("approved_local_key_provider"), "only a key provider reference is recorded")
	check("C03-T01", READER.strip_root("aabb", "ab") == "", "root removal is repeated replacement")
	var loose_before: int = (calls.loose as Array).size()
	var empty: Dictionary = reader.read_bytes("content/empty.json")
	check("C03-T02", empty.status == "EmptySuccess", "DAT success with length 0 -> EmptySuccess")
	check("C03-T02", (calls.loose as Array).size() == loose_before, "loose must not be called inside this reader layer")
	check("C03-T03", reader.read_bytes("data/bundle.bin").status == "Decoded", "bytes read still succeeds")
	check("C03-T03", reader.open_stream("data/bundle.bin").status == "STREAM_UNAVAILABLE", "Bundle stream-open is a separate unavailable result")
	var bad: Dictionary = reader.read_bytes("content/brotli.json")
	check("C03-T04", bad.status == "DecodeFailed" and (bad.bytes as PackedByteArray).is_empty(), "failed probe without fallback is DecodeFailed, never plain-text success")
	reader.streaming_fallback = func(_container: String, _canonical: String) -> Dictionary:
		return {"ok": true, "bytes": PackedByteArray([5, 5, 5])}
	var streamed: Dictionary = reader.read_bytes("content/brotli.json")
	check("C03-T04", streamed.status == "Decoded" and str(streamed.backend).ends_with("+streaming"), "approved streaming fallback is reported as such")
	check("C03-T04", reader.read_bytes("content/broken.json").status == "ReadFailed", "manifest hit, DAT and loose both failing -> ReadFailed")
	check("C03-T04", reader.read_bytes("not/in/manifest.bin").status == "Missing", "no manifest member and no loose file -> Missing")
	check("C03-T04", reader.read_bytes("loose/only.txt").backend == "loose", "manifest miss falls to the loose layer")

func run_c04() -> void:
	check("C04-T01", RECORD.join_guard("lineage.Land", "lineage.resource.Land").allowed == false, "network Land must not join resource Land")
	check("C04-T01", RECORD.join_guard("lineage.resource.Land", "lineage.resource.Land").allowed == true, "same qualified name may join")
	var layouts: Dictionary = RECORD.approved_layouts()
	var land: Dictionary = layouts["lineage.resource.Land"]
	check("C04-T02", land.row_stride == 72 and land.payload_bias == 8 and land.payload_offsets.AssetPath == 0x18 and land.payload_offsets.ID == 0x20, "Land layout from the contract")
	check("C04-T02", layouts["lineage.resource.DescData"].row_stride == 40 and layouts["lineage.resource.SpellClass"].row_stride == 256, "DescData/SpellClass strides")
	var unknown: Dictionary = RECORD.entry_relative_offset(0x18, 8, "unknown")
	check("C04-T02", unknown.status == "UNRESOLVED_POINTER_BASIS" and unknown.entry_offset == null, "unknown pointer basis must not be converted")
	check("C04-T02", RECORD.entry_relative_offset(0x18, 8, "payload").entry_offset == 0x20, "payload pointer + bias")
	check("C04-T02", RECORD.entry_relative_offset(0x1C, 8, "payload").entry_offset == 0x24 and RECORD.entry_relative_offset(0x90, 8, "payload").entry_offset == 0x98, "SpellClass DescID/EffectDescID entry offsets")
	var enum_wire: Dictionary = RECORD.wire_type_for_descriptor(14)
	check("C04-T03", enum_wire.wire_type == 0, "descriptor type 14 (enum) has wire type 0")
	check("C04-T03", RECORD.is_valid_wire_type(14) == false, "14 is never a wire type")

func run_c05() -> void:
	var chain: Dictionary = fixture.get("item26_icon_chain", {})
	var tables: Dictionary = int_keys(chain.get("tables", {}))
	var resolved: Dictionary = ASSETS.resolve_item_icon(tables, int(chain.get("item_class_id", 0)))
	check("C05-T01", resolved.path == chain.get("expected_path") and resolved.path != "26.png", "ItemClass 26 -> icon/Item/adena_3.png")
	check("C05-T01", resolved.chain == ["ItemClass:26", "Icon:2932", "Asset:30962", "icon/Item/adena_3.png"], "ID chain must stay visible")
	check("C05-T01", ASSETS.resolve_icon(tables, ASSETS.asset_id(2932)).status == "WRONG_ID_KIND", "an AssetID is not an IconID")
	check("C05-T01", ASSETS.resolve_asset_path(tables, ASSETS.icon_id(30962)).status == "WRONG_ID_KIND", "an IconID is not an AssetID")
	var simple := {"AssetView": {5: {"AssetId": 5, "AssetTypeId": 1, "FilePath": "Item/x.png"}}, "AssetType": {1: {"ID": 1, "Path": "icon/"}}}
	check("C05-T02", ASSETS.resolve_asset_path(simple, ASSETS.asset_id(5)).path == "icon/Item/x.png", "Path + FilePath")
	simple["AssetType"][1]["Path"] = ""
	check("C05-T02", ASSETS.resolve_asset_path(simple, ASSETS.asset_id(5)).path == "", "empty prefix -> empty")
	simple["AssetType"][1]["Path"] = "icon"
	check("C05-T02", ASSETS.resolve_asset_path(simple, ASSETS.asset_id(5)).path == "iconItem/x.png", "the resolver adds no slash")
	check("C05-T02", ASSETS.resolve_asset_path(simple, ASSETS.asset_id(99)).status == "ASSET_VIEW_ROW_ABSENT", "absent row -> empty")
	var plan: Dictionary = ASSETS.animation_plan(101, 0)
	check("C05-T03", plan.frame_repetition_fallback and plan.csb_timeline_possible, "frame repetition fallback keeps the CSB timeline possibility")
	check("C05-T03", ASSETS.ui_frame_delay_seconds(250) == 0.25, "UI delay is milliseconds / 1000")
	var spell := {"ID": 10, "IconID": 1, "ActivateIconID": 2}
	var overrides: Array = [{"SpellClassID": 10, "WeaponTypeID": 3, "IconID": 8, "ActivateIconID": 9}]
	check("C05-T03", ASSETS.spell_icon_pair(spell, overrides, 3).source == "SpellIconByWeapon" and ASSETS.spell_icon_pair(spell, overrides, 4).IconID == 1, "override applies on a hit and the base pair is kept on a miss")

func run_c06() -> void:
	var v01: Dictionary = vector("V01")
	var remap: Dictionary = SELECT.apply_whole_remap(int(v01.input.request_id), int_keys(v01.input.map))
	check("C06-T01", remap.mapped_id == int(v01.expected.mapped_id) and remap.mapped_id != 19678 and remap.recursion == "NOT_FOLLOWED", "27255 -> 23095 once, never 19678")
	var v02: Dictionary = vector("V02")
	var group: Dictionary = SELECT.sp2_group(int(v02.input.word0), bool(v02.input.directional), int(v02.input.direction))
	check("C06-T02", group.low16 == 8 and group.file_b == 8 and group.direction == 0, "word0=7 + direction 1 changes the file group")
	check("C06-T02", SELECT.sp2_group(7, false, 1).file_b == 0 and SELECT.sp2_group(7, false, 1).direction == 7, "non-directional ignores direction")
	check("C06-T02", SELECT.action_key(27255, 0) == 27255 * 173 and SELECT.action_key(65535, 0) == 0xFFFFFF53, "action key = low32(int16(sprite)*173+action)")
	var table: Dictionary = {}
	var absent: Dictionary = SELECT.alias_descriptor(table, 100, 200, 4)
	check("C06-T03", absent.created == false and absent.diagnostic == "SOURCE_ALIAS_NOT_YET_DEFINED" and table.is_empty(), "alias to a not-yet-defined source creates nothing")
	table[SELECT.action_key(200, 4)] = {"word0": 7}
	check("C06-T03", SELECT.alias_descriptor(table, 100, 200, 4).created == true, "alias is created once the source exists")
	table[SELECT.action_key(100, 5)] = {"word0": 1}
	table[SELECT.action_key(200, 5)] = {"word0": 2}
	check("C06-T03", SELECT.alias_descriptor(table, 100, 200, 5).diagnostic == "FIRST_DEFINITION_KEPT" and table[SELECT.action_key(100, 5)].word0 == 1, "first definition wins")
	var fallback: Dictionary = SELECT.resolve_selection({"actor_sprite": 27255, "action": 0, "direction": 1, "body_request": 27255, "word0": 0xFFFF, "directional": true, "remap": {}})
	check("C06-T04", fallback.status == "FALLBACK_HELPER_PATH" and fallback.mapped_file_u16 == null and fallback.payload_status == "UNVERIFIED", "word0 FFFF is the fallback helper path, not file 65535")
	check("C06-T05", SELECT.simple_path_direction(8) == 0 and SELECT.simple_path_direction(-1) == 0 and SELECT.simple_path_direction(5) == 5, "simple helper clamps to 0")
	var actor_eight: Dictionary = SELECT.sp2_group(7, true, 8)
	check("C06-T05", actor_eight.low16 == 15 and actor_eight.file_b == 8 and actor_eight.direction == 7, "actor path adds no clamp: direction 8 flows into low16")
	check("C06-T05", SELECT.actor_path_direction_domain(8) == "OUTSIDE_NORMAL_DOMAIN_NO_ORIGINAL_CLAMP", "outside-domain input is flagged, not clamped")
	var spec: Dictionary = fixture.get("actor_selection", {})
	var input: Dictionary = spec.duplicate(true)
	input["remap"] = int_keys(spec.get("remap", {}))
	var selected: Dictionary = SELECT.resolve_selection(input)
	var expected: Dictionary = spec.get("expected", {})
	check("C06-T01", selected.mapped_file_u16 == int(expected.mapped_file_u16) and selected.file_b_u16 == int(expected.file_b_u16) and selected.asset_direction == int(expected.asset_direction) and selected.primary_name == expected.primary_name, "first fixture: 27255 -> 23095, word0 7 + direction 1")
	check("C06-T01", selected.status == "FILE_SELECTED" and selected.render_status == "NOT_OBSERVED" and selected.fallback_name == null and not (selected.provenance as Array).is_empty(), "provenance is returned, render is not claimed, the 2500 fallback rule stays open")

func run_c07() -> void:
	var v03: Dictionary = vector("V03")
	check("C07-T01", TIMING.stored_delay(int(v03.input.raw), int(v03.input.fps)).delay_u16_ms == int(v03.expected.delay_u16_ms), "raw 4 at FPS 36 -> 111 ms")
	var delays: Array = TIMING.store_delays([{"raw": 4}, {"code110_fps": 36}, {"raw": 4}])
	check("C07-T01", delays[0].delay_u16_ms == 166 and delays[1].delay_u16_ms == 111, "code 110 changes only later frames")
	check("C07-T01", TIMING.stored_delay(4, 0).status == "FPS_ZERO_REJECTED", "FPS 0 is rejected by the DESIGN layer")
	var v04: Dictionary = vector("V04")
	var effective: Dictionary = TIMING.effective_delay(int(v04.input.stored_delay_ms), int(v04.input.rate), int(v04.input.bucket))
	check("C07-T02", effective.status == "OK" and effective.delay_ms == int(v04.expected.delay_ms), "delay 100, rate 2000000 -> 50 ms")
	check("C07-T02", TIMING.effective_delay(100, 1000000, 0).delay_ms == 100, "rate 1000000 is 1x")
	check("C07-T02", TIMING.effective_delay(100, 0, 0).status == "RATE_ZERO_REJECTED" and TIMING.effective_delay(100, 1000000, 2).status == "BUCKET_SHIFT_UNVERIFIED", "rate 0 rejected, bucket shift stays unverified")
	check("C07-T03", TIMING.descriptor_plus8_meaning({"origin": "auto_46_49"}).fps_derivable == false and TIMING.descriptor_plus8_meaning({"origin": "auto_46_49"}).meaning == "SPRITE_ID", "automatic descriptor +8 is a sprite id")
	check("C07-T03", TIMING.auto_source_action(46) == 4 and TIMING.auto_source_action(49) == 7 and TIMING.auto_source_action(50) == 4 and TIMING.auto_source_action(53) == 7 and TIMING.auto_source_action(45) == -1, "automatic actions 46..53 take 4..7")
	var mid: Dictionary = TIMING.advance_ordinal(0, 3, 1)
	check("C07-T04", mid.ordinal == 1 and mid.continues == true, "mid-sequence advance keeps going")
	var ended: Dictionary = TIMING.advance_ordinal(2, 3, 1)
	check("C07-T04", ended.ordinal == 0 and ended.continues == false and ended.at_end == true, "end of a normal action returns to ordinal 0 and stops")
	var held: Dictionary = TIMING.advance_ordinal(2, 3, 96)
	check("C07-T04", held.ordinal == 2 and held.continues == false, "action 96 keeps the last frame and stops")
	check("C07-T04", TIMING.advance_ordinal(0, 0, 96).ordinal == 0, "action 96 with no frames -> max(count-1,0) = 0")

func run_c08() -> void:
	var v05: Dictionary = vector("V05")
	var p5: Dictionary = SELECT.picture_selection(int(v05.input.dot_after_word), int(v05.input.frame_count))
	check("C08-T01", p5.picture_u8 == 0 and p5.picture_i8 == 0 and p5.chosen_frame == 0, "WORD 256 -> picture 0")
	var v06: Dictionary = vector("V06")
	var p6: Dictionary = SELECT.picture_selection(int(v06.input.dot_after_word), int(v06.input.frame_count))
	check("C08-T01", p6.picture_u8 == 128 and p6.picture_i8 == -128 and p6.chosen_frame == 7 and p6.status == "CLAMPED_TO_LAST", "WORD 128 -> signed -128 -> unsigned out of range -> last frame")
	check("C08-T01", SELECT.picture_selection(3, 0).status == "EMPTY_FRAMES_DEFAULT_FRAME", "empty vector -> default frame")
	var past: Dictionary = SELECT.spr_ordinal_lookup(8, 8)
	check("C08-T02", past.status == "InvalidOrdinal" and past.ordinal == null, "ordinal == count is null, not the last frame")
	check("C08-T02", SELECT.spr_ordinal_lookup(8, 7).ordinal == 7 and SELECT.spr_ordinal_lookup(8, -1).status == "InvalidOrdinal", "last valid ordinal and negative ordinal")
	var manifest_only: Dictionary = SELECT.resolve_selection({"actor_sprite": 27255, "action": 0, "direction": 0, "body_request": 27255, "word0": 7, "directional": true, "remap": {}})
	check("C08-T03", manifest_only.frame_count == null and manifest_only.payload_status == "UNVERIFIED" and manifest_only.source_frame_id == null, "no payload evidence -> frame_count null, UNVERIFIED")
	var sparse: Dictionary = SELECT.packed_direction_index(0x08, 3)
	check("C08-T04", sparse.status == "OK" and sparse.packed_index == 0, "mask 0x08: direction 3 is packed index 0")
	var missing: Dictionary = SELECT.packed_direction_index(0x08, 0)
	check("C08-T04", missing.status == "MissingDirection" and missing.packed_index == null, "direction 0 is missing and does not fall back")
	check("C08-T04", SELECT.packed_direction_index(0x29, 5).packed_index == 2 and SELECT.packed_direction_index(0x29, 8).status == "MissingDirection", "mask 0x29: direction 5 is index 2; direction 8 is out of range")
