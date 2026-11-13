extends RefCounted
## Pinned, opt-in source-action metadata. No installation, role inference or events.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const PARSE_CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const ORIGINAL_SELECTION = preload("res://scripts/original_client/sprite_selection.gd")
const ORIGINAL_TIMING = preload("res://scripts/original_client/sprite_timing.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const MANIFEST_INDEX = preload("res://scripts/resources/reference_sp2_manifest_index.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const PARSED_PAYLOAD = preload("res://scripts/resources/sp2_parsed_payload.gd")
const PIXEL_RENDERER = preload("res://scripts/resources/current523_sp2_frame_renderer.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const ATTACHMENT_ATTRIBUTES = preload("res://scripts/animation/source_attachment_attributes.gd")
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const MAX_JSON = 16 * 1024 * 1024
# Aggregate bank metadata is larger than an individual action JSON. Keep both
# finite: the pinned cf2677 manifest is 31,361,924 bytes; the complete-client
# 523 bank (63,661 members, 114,758 actions) is 39,481,600 bytes. Actor JSON
# stays 16MiB.
const MAX_MANIFEST_JSON = 64 * 1024 * 1024
const SOURCE_DUMMY_EXCLUSION_POLICY = "source_literal_dummy_declarations_only;project_inactive_dummy_edges;preserve_originals_and_normal_shared_members"
const NATIVE_SELECTOR_POLICY = "native_explicit_actions_and_immediate_alias_owner_v1"
const NATIVE_ACTIVATION_POLICY = "restored525_101_immediate_action_owner_105_original_actor_bounded_projection"
const NATIVE_FILE_REMAP_POLICY = "requested_high16_single_whole_sprite_remap"
const NATIVE_IDENTITY_FIELDS: Array[String] = ["kind","source_sprite_id","requested_sprite_id","metadata_owner_sprite_id","file_remap_policy","native_binding_id","source_reference_index","target_index"]
const SOURCE_REFERENCE_INSTANCE_POLICY = "ordered_literal_edges_shared_frame_bindings_native_draw_multiplicity_unverified"
var _root: String = ""
var _manifest_path: String = ""
var _manifest_sha: String = ""
var _manifest: Dictionary = {} # top-level fields; actors/members via _index
var _index: RefCounted = null
var _excluded_source_actors: Dictionary = {}
var _actor_pins: Dictionary = {}
# This bank's working set: member -> shared read-only parse. Each entry holds
# one lease in ASSETS under _parsed_keys[member]. At most three members are
# retained, bounded by their allocated packed buffers (not total heap/RSS).
var _parsed: Dictionary = {}
var _parse_order: Array[String] = []
var _parsed_keys: Dictionary = {}
var _parsed_costs: Dictionary = {} # member -> the shared entry's measured cost
var _asset_owner: int = ASSETS.new_owner()
static var _crc_table: Array[int] = []
## Member files whose bytes were verified, by path -> [identity, size, mtime].
## Like MANIFEST_INDEX.pinned(): every use still checks that the file exists
## with its declared size and unchanged modification time; the full read and
## SHA-256/CRC32 runs again only when either changed (or nothing is verified
## yet). Every drawn layer of every 523 actor used to read and hash its whole
## SP2 file on every frame. (User decision 2026-11-11: re-verify changed files
## only.)
static var _verified_members: Dictionary = {}

var _prepared_snapshot: RefCounted
var _prepared_members: Dictionary = {}
var _building_shared: bool = false

## C07: an explicit SPR FPS and raw delay become whole stored milliseconds (original-client
## contract adapter). Values outside the plain domain keep the previous exact division.
static func _frame_seconds(raw_ticks: int, source_fps: Variant) -> float:
	var timed: Dictionary = ORIGINAL_TIMING.frame_seconds(raw_ticks, int(source_fps))
	if timed.status == "OK":
		return float(timed.seconds)
	return float(raw_ticks) / float(source_fps)

static func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func integer(value: Variant, minimum: int = 0, maximum: int = 2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func valid_sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true

static func valid_crc(value: Variant) -> bool:
	if not value is String or value.length() != 8: return false
	for character: String in value:
		if not character in "0123456789abcdef": return false
	return true

static func crc32(bytes: PackedByteArray) -> String:
	if _crc_table.is_empty():
		for index: int in range(256):
			var entry: int = index
			for bit: int in range(8): entry = (entry >> 1) ^ (0xedb88320 if (entry & 1) != 0 else 0)
			_crc_table.append(entry)
	var value: int = 0xffffffff
	for byte: int in bytes: value = _crc_table[(value ^ byte) & 255] ^ (value >> 8)
	return "%08x" % ((value ^ 0xffffffff) & 0xffffffff)

func _json(path: String, expected: String, manifest_json: bool = false) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var maximum: int = MAX_MANIFEST_JSON if manifest_json else MAX_JSON
	if file == null or file.get_length() <= 0 or file.get_length() > maximum: return fail("Missing or oversized bank JSON: " + path)
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if not valid_sha(expected) or digest(bytes) != expected: return fail("Bank JSON SHA256 mismatch: " + path)
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return {"ok":true,"value":value} if value is Dictionary else fail("Bank JSON is not an object.")

## Each pinned file still has its SHA256. A file verified earlier in this
## process is re-hashed only when its size or modification time changed, so
## per-frame checks no longer hash the ~40 MB manifest every time.
func _pins_valid() -> bool:
	if not MANIFEST_INDEX.pinned(_manifest_path, _manifest_sha): return false
	for path: String in _actor_pins:
		if not MANIFEST_INDEX.pinned(path, _actor_pins[path]): return false
	return true

func _actor_registry(key: String) -> Variant:
	return _index.lookup("actors", key) if _index != null else null

func source_actor_admission(source_actor_id: int) -> Dictionary:
	# This registry is pinned current523 source evidence. Actor/graph identities
	# are scoped here; shared raw filenames never become a global exclusion.
	var key: String = "sprite:" + str(source_actor_id)
	if not _excluded_source_actors.has(key): return {"ok":true}
	return {"ok":false,"error":"Source-declared dummy actor connection is excluded: " + key,"source_snapshot":"patch523","excluded_source_actor_id":source_actor_id,"source_exclusion":_excluded_source_actors[key].duplicate(true)}

func _install_source_exclusions() -> Dictionary:
	var registry: Variant = _manifest.get("excluded_source_actors",{})
	if not registry is Dictionary: return fail("Invalid source actor exclusion registry.")
	var source_file_pattern := RegEx.new()
	source_file_pattern.compile("^list_[0-9]+\\.spr$")
	for key: Variant in registry:
		if not key is String or not key.begins_with("sprite:") or not key.trim_prefix("sprite:").is_valid_int(): return fail("Invalid source dummy actor registry key.")
		var sprite_id: int = int(key.trim_prefix("sprite:"))
		if sprite_id < 0 or key != "sprite:" + str(sprite_id): return fail("Invalid exact source dummy actor namespace.")
		var exclusion: Variant = registry[key]
		if not exclusion is Dictionary or exclusion.get("source_snapshot") != "patch523" or exclusion.get("reason") != "source_literal_dummy" or exclusion.get("originals_preserved") != true or exclusion.get("raw_member_namespace_excluded") != false: return fail("Unsupported source dummy exclusion evidence.")
		var declarations: Variant = exclusion.get("dummy_declarations")
		if not declarations is Array or declarations.is_empty(): return fail("Missing literal source dummy declarations.")
		for declaration: Variant in declarations:
			if not declaration is Dictionary or declaration.get("sprite_id") != sprite_id or not declaration.get("literal_name") is String or not declaration.get("literal_declaration") is String or not declaration.get("matched_literal") is String or not declaration.get("source_file") is String or source_file_pattern.search(declaration.source_file) == null or not integer(declaration.get("source_line"),1) or not valid_sha(declaration.get("source_sha256")): return fail("Invalid literal source dummy declaration.")
			var marker: String = str(declaration.matched_literal).to_lower()
			if marker not in ["dummy","더미"] or str(declaration.literal_name).findn(marker) < 0 or str(declaration.literal_declaration).findn(str(declaration.literal_name)) < 0: return fail("Source dummy declaration lacks its explicit literal marker.")
		var paths: Variant = exclusion.get("source_graph_paths")
		if not paths is Array or paths.is_empty(): return fail("Missing exact source dummy declaration path.")
		for path: Variant in paths:
			if not path is Dictionary or path.get("kind") != "source_declared_root" or not path.get("sprite_ids") is Array or path.sprite_ids.size() != 1 or path.sprite_ids[0] != sprite_id: return fail("Source dummy registry must name only the actual literal declaration.")
	_excluded_source_actors = registry.duplicate(true)
	return {"ok":true}

func _source_graph_admission(proof: Dictionary) -> Dictionary:
	for item: Variant in proof.get("declarations",[]):
		if not item is Dictionary or not item.get("declaration_path") is Array: return fail("Invalid source graph declaration path.")
		# Inactive dummy-child evidence may be retained for provenance. Active
		# layer alias paths are admitted separately when their frames are bound.
		if item.get("kind") != "body": continue
		for declaration: Variant in item.declaration_path:
			if not declaration is Dictionary or not integer(declaration.get("sprite_id")): return fail("Invalid source graph actor identity.")
			var admitted: Dictionary = source_actor_admission(int(declaration.sprite_id))
			if not admitted.ok: return admitted
	return {"ok":true}

func _source_reference_instances(source: Dictionary) -> Dictionary:
	if not source.has("source_reference_instances") and not source.has("source_reference_instance_policy"): return {"ok":true,"by_id":{}}
	var instances: Variant = source.get("source_reference_instances")
	if source.get("source_reference_instance_policy") != SOURCE_REFERENCE_INSTANCE_POLICY or not instances is Array: return fail("Unsupported literal source reference instance contract.")
	var by_id: Dictionary = {}
	var first_by_binding: Dictionary = {}
	for item: Variant in instances:
		if not item is Dictionary or not item.get("instance_id") is String or str(item.instance_id).is_empty() or by_id.has(item.instance_id) or not item.get("binding_id") is String or str(item.binding_id).is_empty() or item.get("kind") not in ["shadow","clothes"] or not integer(item.get("from_sprite_id")) or not integer(item.get("target_sprite_id")) or not item.get("source_reference") is String or not item.get("source_edge_path") is Array or not integer(item.get("target_index")) or item.get("connection_stage") != "ordered_literal_instance_shared_source_binding" or item.get("native_reference_multiplicity_verified") != false: return fail("Invalid literal source reference instance.")
		var declaration: Variant = item.get("source_declaration")
		if not declaration is Dictionary or not integer(declaration.get("sprite_id")) or not declaration.get("source_file") is String or not integer(declaration.get("source_line"),1) or not valid_sha(declaration.get("source_sha256")) or declaration.get("code") != (101 if item.kind == "shadow" else 105) or declaration.get("body") != item.source_reference or not integer(declaration.get("source_directive_index")) or not integer(declaration.get("source_reference_index")): return fail("Missing exact source reference instance declaration.")
		if not first_by_binding.has(item.binding_id): first_by_binding[item.binding_id] = item.instance_id
		if item.get("canonical_instance_id") != first_by_binding[item.binding_id]: return fail("Literal source binding has no ordered canonical instance.")
		var canonical: Dictionary = item if item.instance_id == item.canonical_instance_id else by_id.get(item.canonical_instance_id,{})
		if canonical.is_empty() or canonical.get("from_sprite_id") != item.from_sprite_id or canonical.get("target_sprite_id") != item.target_sprite_id or canonical.get("kind") != item.kind or canonical.get("source_reference") != item.source_reference: return fail("Nonidentical source reference instances cannot share a frame binding.")
		by_id[item.instance_id] = item.duplicate(true)
	return {"ok":true,"by_id":by_id}

func _reference_binding(source: Dictionary, instances: Dictionary, layer: Dictionary, compact: Dictionary) -> Dictionary:
	if not layer.has("source_binding_id") and not layer.has("reference_instance_ids") and not compact.has("source_binding_id") and not compact.has("reference_instance_ids"): return {"ok":true,"instances":[]}
	var binding: Variant = layer.get("source_binding_id")
	var ids: Variant = layer.get("reference_instance_ids")
	if not binding is String or binding.is_empty() or binding != compact.get("source_binding_id") or not ids is Array or ids.is_empty() or ids != compact.get("reference_instance_ids"): return fail("Literal source reference binding differs from its compact declaration.")
	var native: bool = source.get("native_selector_policy") is String and source.native_selector_policy == NATIVE_SELECTOR_POLICY
	if native and (layer.get("kind") == "body" or binding != layer.get("native_binding_id") or ids.size() != 1): return fail("Native source reference differs from its exact occurrence binding.")
	var targets: Dictionary = {}
	if native:
		targets[int(layer.requested_sprite_id)] = true
	else:
		for evidence: Dictionary in source.get("source_layer_declarations",[]):
			if evidence.get("kind") == layer.get("kind") and evidence.get("source_sprite_id") == layer.get("source_sprite_id"):
				for declaration: Dictionary in evidence.get("declaration_path",[]): targets[int(declaration.get("sprite_id",-1))] = true
	var ordered: Array = []
	for id: Variant in ids:
		if not id is String or not instances.has(id): return fail("Literal source reference instance ID is absent.")
		var instance: Dictionary = instances[id]
		if instance.binding_id != binding or instance.kind != layer.get("kind") or not targets.has(int(instance.target_sprite_id)): return fail("Literal reference instance does not bind this exact source layer.")
		if native:
			var matches: Array = []
			for proof: Variant in source.source_proof.declarations:
				if proof is Dictionary and proof.get("native_binding_id") is String and proof.native_binding_id == binding: matches.append(proof)
			if matches.size() != 1 or not matches[0].get("edge_path") is Array or matches[0].edge_path.size() != 1 or instance.source_edge_path != matches[0].edge_path or instance.get("source_declaration") != matches[0].get("source_declaration") or instance.from_sprite_id != matches[0].edge_path[0].get("from_sprite_id") or instance.target_index != layer.target_index: return fail("Native literal instance differs from its exact active declaration.")
		ordered.append(instance.duplicate(true))
	return {"ok":true,"instances":ordered}

func _member(member: String) -> Dictionary:
	var spec: Variant = _index.lookup("members", member) if _index != null else null
	if not spec is Dictionary or spec.get("member") != member or spec.get("path") != "raw/" + member or not INSTALL.safe_relative(str(spec.get("path", ""))): return fail("Invalid exact raw member path: " + member)
	var supplied_sha: bool = valid_sha(spec.get("sha256"))
	var received: bool = spec.has("sha256") and spec.sha256 == null and spec.get("stage") == "received_not_additionally_validated"
	if not integer(spec.get("bytes"), 1, DECODER.MAX_INPUT_BYTES) or (not supplied_sha and not received): return fail("Invalid raw member identity: " + member)
	if received:
		var identity: Variant = spec.get("source_identity")
		if not valid_crc(spec.get("crc32")) or spec.get("source_receipt_id") != member or not identity is Dictionary or identity.get("source_snapshot") != "patch523" or identity.get("basis") != "supplied_exact_current523_member_archive_bytes_crc_domain": return fail("Missing explicit received current523 identity: " + member)
		var manifest_reference: Variant = identity.get("source_manifest_reference")
		var reference_supplied: bool = (manifest_reference is String and not manifest_reference.is_empty()) or (manifest_reference is Dictionary and not manifest_reference.is_empty())
		if not identity.get("archive") is String or str(identity.archive).is_empty() or not reference_supplied: return fail("Missing supplied source domain: " + member)
		var whole_manifest: Variant = identity.get("whole_current523_manifest_match")
		var container_sha: Variant = identity.get("container_sha256")
		if whole_manifest != null and whole_manifest != true: return fail("Contradictory supplied current523 container identity: " + member)
		if container_sha != null and not valid_sha(container_sha): return fail("Invalid supplied source container identity: " + member)
		var version_basis: Variant = identity.get("version_basis")
		if version_basis == "supplied_current523_container_manifest":
			var container_manifest: Variant = identity.get("container_manifest_identity")
			if not container_manifest is Dictionary or container_manifest.get("archive") != identity.archive or not integer(container_manifest.get("bytes"),1,9007199254740991): return fail("Missing exact supplied current523 container manifest identity: " + member)
			var manifest_sha1: Variant = container_manifest.get("sha1")
			var sha1_supplied: bool = manifest_sha1 is String and manifest_sha1.length() == 40
			if sha1_supplied:
				for character: String in str(manifest_sha1).to_lower():
					if not character in "0123456789abcdef":
						sha1_supplied = false
						break
			var provenance: Variant = container_manifest.get("source_provenance_file")
			if not sha1_supplied or not provenance is String or provenance.is_empty(): return fail("Missing supplied current523 container SHA1/proof pointer: " + member)
		elif whole_manifest != true and version_basis != "retained508_outer_manifest": return fail("Missing exact retained source version basis: " + member)
	var file_path: String = _root.path_join(spec.path)
	if not FileAccess.file_exists(file_path) or int(FileAccess.get_size(file_path)) != int(spec.bytes):
		_verified_members.erase(file_path)
		return fail("Original SP2 missing or changed size: " + member)
	# Every cache use (texture hits, shared parses) rechecks the file's size and
	# modification time; a change re-reads and re-hashes the whole member.
	var identity_key: String = ("sha256:" + str(spec.sha256)) if supplied_sha else ("crc32:" + str(spec.crc32))
	var modified: int = int(FileAccess.get_modified_time(file_path))
	var known: Variant = _verified_members.get(file_path)
	var verified: bool = known is Array and known[0] == identity_key and known[1] == int(spec.bytes) and known[2] == modified
	var bytes := PackedByteArray()
	if not verified:
		bytes = _read_verified(file_path, spec, supplied_sha, received, member)
		if bytes.is_empty(): return fail(str(_last_member_problem))
		_verified_members[file_path] = [identity_key, int(spec.bytes), modified]
	# Shared parse identity: verified manifest SHA + this member's checked
	# identity + decoder version (received members stay CRC/receipt scoped).
	var asset_key: String = ASSETS.parsed_key(_manifest_sha, member, spec, file_path)
	if _parsed.has(member) and _parsed_keys.get(member, "") != asset_key: _drop_parsed(member)
	if not _parsed.has(member):
		var parsed: Variant = ASSETS.acquire("parsed", asset_key, _asset_owner) if not asset_key.is_empty() else null
		var parsed_cost: int = ASSETS.entry_bytes("parsed", asset_key) if parsed != null else -1
		if parsed == null:
			if bytes.is_empty():
				bytes = _read_verified(file_path, spec, supplied_sha, received, member)
				if bytes.is_empty():
					_verified_members.erase(file_path)
					return fail(str(_last_member_problem))
			var reservation: int = ASSETS.reserve("parsed", asset_key, bytes.size())
			# Parsed once per device for these verified bytes (sp2_parse_cache.gd).
			var fresh: Dictionary = PARSE_CACHE.parse(bytes, str(spec.sha256) if supplied_sha else "")
			if not fresh.ok:
				ASSETS.cancel(reservation)
				return fresh
			parsed_cost = _parsed_payload_bytes(fresh)
			parsed = ASSETS.complete(reservation, fresh, parsed_cost, _asset_owner)
			# A completed reservation can reuse an already published payload.
			# Its stored cost is canonical; stale/uncached completions keep ours.
			var published_cost: int = ASSETS.entry_bytes("parsed", asset_key)
			if published_cost >= 0: parsed_cost = published_cost
		var budget: int = parsed_cost
		for cost: int in _parsed_costs.values(): budget += cost
		while not _parse_order.is_empty() and (_parsed.size() >= 3 or budget > 32 * 1024 * 1024):
			var oldest: String = _parse_order[0]
			budget -= int(_parsed_costs[oldest])
			_drop_parsed(oldest)
		_parsed[member] = parsed
		_parsed_keys[member] = asset_key
		_parsed_costs[member] = parsed_cost
		_parse_order.append(member)
	return {"ok":true,"parsed":_parsed[member],"sha256":spec.sha256,"crc32":spec.get("crc32"),"stage":spec.get("stage","sha256_pinned_raw_member"),"source_receipt_id":spec.get("source_receipt_id"),"source_identity":spec.get("source_identity")}

var _last_member_problem: String = ""

## The member's bytes after a full size + SHA-256 (or received CRC32) check,
## or empty with _last_member_problem set.
func _read_verified(file_path: String, spec: Dictionary, supplied_sha: bool, received: bool, member: String) -> PackedByteArray:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() != int(spec.bytes):
		_last_member_problem = "Original SP2 missing or changed size: " + member
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if supplied_sha and digest(bytes) != spec.sha256:
		_last_member_problem = "Original SP2 SHA256 mismatch: " + member
		return PackedByteArray()
	if received and crc32(bytes) != spec.crc32:
		_last_member_problem = "Received original SP2 CRC32 mismatch: " + member
		return PackedByteArray()
	return bytes

## Forget verified member stamps (tests; or after replacing files in place
## within the same second at the same size).
static func forget_verified_members() -> void:
	_verified_members.clear()
	PREPARED.clear()

## Measured once when publishing a parse, then reused from the shared entry
## and this bank's sidecar. Does not change the parsed Dictionary or its keys.
static func _parsed_payload_bytes(parsed: Dictionary) -> int:
	FRAME_HITCH.count("sp2.parsed_payload_measured")
	return PARSED_PAYLOAD.bytes_of(parsed)

func _drop_parsed(member: String) -> void:
	ASSETS.release("parsed", str(_parsed_keys.get(member, "")), _asset_owner)
	_parsed.erase(member)
	_parsed_keys.erase(member)
	_parsed_costs.erase(member)
	_parse_order.erase(member)

func _release_parsed() -> void:
	for member: String in _parsed_keys:
		ASSETS.release("parsed", str(_parsed_keys[member]), _asset_owner)
	_parsed.clear()
	_parsed_keys.clear()
	_parsed_costs.clear()
	_parse_order.clear()

func _notification(what: int) -> void:
	# A RefCounted cannot call its own script methods during predelete, so the
	# leases are released inline (static call into the store only).
	if what == NOTIFICATION_PREDELETE:
		for member: String in _parsed_keys: ASSETS.release("parsed", str(_parsed_keys[member]), _asset_owner)
		_parsed_keys.clear()
		_parsed_costs.clear()

## Shared parsed-asset key of `member` as last verified by this bank, or "".
func parsed_asset_key(member: String) -> String:
	return str(_parsed_keys.get(member, ""))

## Client static branch (no action descriptor): body Sprite/<remapped id>-0.sp2
## direction 0 picture 0, plus its 101 shadow drawn the same way; clothes are
## not collected. Returns layers for render_layer(); nothing is played here.
func load_static(manifest_path: String, expected_sha: String, source_sprite_id: int) -> Dictionary:
	_prepared_snapshot = null
	_prepared_members.clear()
	_root = manifest_path.get_base_dir()
	_manifest_path = manifest_path
	_manifest_sha = expected_sha
	_manifest = {}; _index = null; _excluded_source_actors.clear(); _actor_pins.clear(); _release_parsed()
	# Same shared, storage-backed manifest view as load_bank(); _member() reads it.
	var opened: Dictionary = MANIFEST_INDEX.open(manifest_path, expected_sha, MAX_MANIFEST_JSON, valid_sha(expected_sha))
	if not opened.ok: return opened
	_index = opened.index
	_manifest = _index.top
	if _manifest.get("schema") != 1 or _manifest.get("kind") != "current523_reference_sp2_action_bank" or _manifest.get("source_snapshot") != "patch523": return fail("Not an exact current523 reference source bank.")
	var contract: Variant = _manifest.get("static_picture_contract")
	if not contract is Dictionary or contract.get("branch") != "client_static_no_action_descriptor" or contract.get("frame") != "direction0_picture0" or not contract.get("evidence") is String: return fail("Bank has no client static picture contract.")
	if not _manifest.get("static_pictures") is Dictionary or not _index.registry_is_dictionary("members"): return fail("Missing static picture registry.")
	var exclusions: Dictionary = _install_source_exclusions()
	if not exclusions.ok: return exclusions
	var admitted: Dictionary = source_actor_admission(source_sprite_id)
	if not admitted.ok: return admitted
	var entry: Variant = _manifest.static_pictures.get("sprite:" + str(source_sprite_id))
	if not entry is Dictionary or entry.get("branch") != "client_static_no_action_descriptor" or not entry.get("layers") is Array: return fail("Exact source sprite has no static picture.")
	var layers: Array = []
	for layer: Variant in entry.layers:
		if not layer is Dictionary or layer.get("kind") not in ["body","shadow"] or layer.get("source_sprite_id") != source_sprite_id or int(layer.get("group_bit",-1)) != 0 or int(layer.get("frame_index",-1)) != 0: return fail("Invalid static picture layer.")
		var member: String = "Sprite/%d-0.sp2" % int(layer.get("file_sprite_id",-1))
		if layer.get("member") != member: return fail("Static picture member differs from its file identity.")
		var source: Dictionary = _member(member)
		if not source.ok: return source
		layers.append(layer.duplicate(true))
	if layers.is_empty() or layers[0].kind != "body": return fail("Static picture requires its body first.")
	return {"ok":true,"layers":layers,"source_declaration":entry.get("source_declaration",{}).duplicate(true),"branch":entry.branch,"manifest_sha256":expected_sha}

func render_layer(layer: Dictionary, pixels: bool = true) -> Dictionary:
	if not _pins_valid(): return fail("Pinned source bank metadata changed.")
	if not integer(layer.get("source_sprite_id")): return fail("Missing declared source layer actor identity.")
	var admitted: Dictionary = source_actor_admission(int(layer.source_sprite_id))
	if not admitted.ok: return admitted
	var source: Dictionary = _member(str(layer.get("member", "")))
	if not source.ok: return source
	return _render_verified_layer(layer, source, pixels)

func _render_verified_layer(layer: Dictionary, source: Dictionary, pixels: bool) -> Dictionary:
	var parsed: Dictionary = source.parsed
	var group_index: int = -1
	for index: int in range(parsed.groups.size()):
		if int(parsed.groups[index].bit) == int(layer.get("group_bit", -1)): group_index = index
	if group_index < 0 or not integer(layer.get("frame_index"), 0, 255): return fail("Stored SP2 direction/frame is unavailable.")
	var group: Dictionary = parsed.groups[group_index]
	var frame_index: int = int(layer.frame_index)
	if frame_index >= group.frames.size(): return fail("Stored SP2 frame is out of range.")
	var frame: Dictionary = group.frames[frame_index]
	var result: Dictionary = PIXEL_RENDERER.render(parsed, group_index, frame_index) if pixels else {"ok":true,"offset":frame.bounds.position,"empty":frame.empty}
	if result.ok:
		result["provenance"] = {"member":layer.member,"raw_sha256":source.sha256,"raw_crc32":source.crc32,"source_stage":source.stage,"source_receipt_id":source.source_receipt_id,"source_identity":source.source_identity,"stored_bit":int(layer.group_bit),"frame_index":frame_index,"layer_id":int(layer.source_sprite_id),"kind":layer.kind,"empty":bool(frame.empty)}
		if layer.has("source_binding_id"):
			result.provenance["source_binding_id"] = layer.source_binding_id
			result.provenance["reference_instance_ids"] = layer.get("reference_instance_ids",[]).duplicate()
			result.provenance["source_reference_instances"] = layer.get("source_reference_instances",[]).duplicate(true)
			result.provenance["native_reference_multiplicity_verified"] = false
	return result

## A load is synchronous: every role/direction may address the same member
## hundreds of times. Verify it once for this load, then retain only geometry
## and provenance, not its raw/body/blocks or a lease outside the usual 3-member
## working set. Draw-time render_layer() still checks pins and members each use.
func _load_layer_metadata(layer: Dictionary, memo: Dictionary) -> Dictionary:
	if not integer(layer.get("source_sprite_id")): return fail("Missing declared source layer actor identity.")
	var admitted: Dictionary = source_actor_admission(int(layer.source_sprite_id))
	if not admitted.ok: return admitted
	var member: String = str(layer.get("member", ""))
	if not memo.has(member):
		FRAME_HITCH.count("sp2.member_verify")
		var source: Dictionary = _member(member)
		if not source.ok: return source
		var groups: Array = []
		for group: Dictionary in source.parsed.groups:
			var frames: Array = []
			for frame: Dictionary in group.frames:
				frames.append({"bounds":frame.bounds,"empty":frame.empty})
			groups.append({"bit":group.bit,"frames":frames})
		var compact: Dictionary = source.duplicate()
		compact.parsed = {"groups":groups}
		# A prepared result may freeze its provenance. Do not freeze the shared
		# manifest index's mutable received-member identity as a side effect.
		if _building_shared and (compact.source_identity is Dictionary or compact.source_identity is Array):
			compact.source_identity = compact.source_identity.duplicate(true)
		var file_path: String = _root.path_join("raw/" + member)
		memo[member] = {"source":compact,"path":file_path,"stamp":_verified_members.get(file_path, []).duplicate()}
	return _render_verified_layer(layer, memo[member].source, false)

## Do not accept a file changed during the synchronous build. An unchanged
## stamp costs only stats; a rewrite must pass the normal full verification.
## The memo never survives load_bank(), and metadata pins are checked too.
func _load_members_unchanged(memo: Dictionary) -> Dictionary:
	for member: String in memo:
		var entry: Dictionary = memo[member]
		var stamp: Array = entry.stamp
		if stamp.size() == 3 and FileAccess.file_exists(entry.path) and int(FileAccess.get_size(entry.path)) == int(stamp[1]) and int(FileAccess.get_modified_time(entry.path)) == int(stamp[2]): continue
		var checked: Dictionary = _member(member)
		if not checked.ok: return checked
	return {"ok":true}

## This path has already matched its pinned declaration proof. Normalize only
## a private copy of integral JSON numbers for the pure projection helper; the
## raw all-path attributes/declarations below remain byte-for-value evidence.
func _attribute_projection(record: Dictionary, kind: String, sprite: int, path: Array, proof: Dictionary) -> Dictionary:
	var normalized: Array = path.duplicate(true)
	for index: int in range(normalized.size()):
		var declaration: Dictionary = normalized[index]
		if not integer(declaration.get("sprite_id")): return fail("Invalid metadata owner identity.")
		declaration.sprite_id = int(declaration.sprite_id)
		if not declaration.has("alias_target"):
			# Older direct-path DTOs omitted this redundant terminal field. An
			# alias chain still requires every explicit source link as evidence.
			if normalized.size() != 1: return fail("Metadata alias link was not supplied.")
			declaration["alias_target"] = null
		var target: Variant = declaration.alias_target
		if target != null:
			if not integer(target): return fail("Invalid metadata alias target.")
			declaration.alias_target = int(target)
		if index + 1 < normalized.size():
			if target == null or target != normalized[index+1].get("sprite_id"): return fail("Metadata alias link differs from its declaration path.")
		elif target != null: return fail("Metadata alias declaration path is incomplete.")
		for directive: Dictionary in declaration.literal_attribute_directives:
			directive.code = int(directive.code)
			directive.line = int(directive.line)
	var owner: int = int(normalized[0].sprite_id)
	var basis: String
	if kind == "body":
		var actor: Variant = record.get("actor")
		var root: Variant = record.source_proof.get("root_sprite_id")
		if not actor is Dictionary or not integer(root) or actor.get("source_sprite_id") != root or owner != root: return fail("Body metadata owner differs from its exact role actor.")
		basis = "exact_role_actor_original_sprite"
	elif kind == "clothes":
		basis = "verified_clothes_request_path_first"
		if proof.has("edge_path"):
			var edges: Variant = proof.edge_path
			if not edges is Array or edges.is_empty() or not edges[-1] is Dictionary or edges[-1].get("kind") != "clothes" or edges[-1].get("target_sprite_id") != owner: return fail("Clothes metadata owner differs from its requested105 target.")
		else:
			# Direct-path legacy DTOs identify the request in their pinned path.
			# New compiler DTOs additionally bind that ID to the explicit105 edge.
			basis = "verified_legacy_clothes_request_path_first"
	else:
		# Native101 ignores shadow own104. Parent actor flags and their dynamic
		# modifiers are a separate submission context, resolved by the caller.
		return {"ok":true,"projection":{"ok":false,"flags":0,"present":false,"origin":"shadow_requires_parent_actor_flags","owner_proof":{"kind":"shadow","physical_sprite_id":sprite,"basis":"native101_parent_actor_flags","context":"requires_parent_submission_context"}}}
	var projected: Dictionary = ATTACHMENT_ATTRIBUTES.resolve_own_path(normalized,owner)
	projected["owner_sprite_id"] = owner
	projected["owner_path_index"] = 0
	var own_declaration: Dictionary = path[0].duplicate(true)
	own_declaration.erase("literal_attribute_directives")
	projected["owner_proof"] = {"kind":kind,"requested_sprite_id":owner,"physical_sprite_id":sprite,"owner_path_index":0,"basis":basis,"declaration":own_declaration,"context":"initial_or_reset_static_metadata_only"}
	return {"ok":true,"projection":projected}

func _attributes(record: Dictionary, kind: String, sprite: int) -> Dictionary:
	var evidence: Variant = record.get("source_layer_declarations")
	var source_proof: Variant = record.get("source_proof")
	if not evidence is Array: return fail("Literal source layer attributes were not supplied.")
	if not source_proof is Dictionary or not source_proof.get("declarations") is Array: return fail("Missing source attribute declaration proof.")
	var matches: Array = []
	for item: Variant in evidence:
		if item is Dictionary and item.get("kind") == kind and integer(item.get("source_sprite_id")) and int(item.source_sprite_id) == sprite: matches.append(item)
	if matches.size() != 1: return fail("Missing or ambiguous literal layer declaration.")
	var item: Dictionary = matches[0]
	var path: Variant = item.get("declaration_path")
	if not path is Array or path.is_empty(): return fail("Invalid literal layer declaration path.")
	var matching_proofs: Array = []
	for proof: Variant in source_proof.declarations:
		if not proof is Dictionary or not proof.get("declaration_path") is Array: return fail("Invalid source layer proof.")
		var candidate: Array = proof.declaration_path
		if candidate.is_empty() or not candidate[-1] is Dictionary or not integer(candidate[-1].get("sprite_id")): return fail("Invalid source layer declaration identity.")
		if proof.get("kind") == kind and int(candidate[-1].sprite_id) == sprite: matching_proofs.append(proof)
	if matching_proofs.size() != 1: return fail("Missing or ambiguous source attribute declaration proof.")
	var selected_proof: Dictionary = matching_proofs[0]
	var expected: Array = selected_proof.declaration_path
	if expected.size() != path.size(): return fail("Layer declaration evidence differs from source proof.")
	var attributes: Array = []
	var unresolved: bool = false
	for index: int in range(path.size()):
		if not path[index] is Dictionary: return fail("Invalid literal layer declaration.")
		var declaration: Dictionary = path[index]
		var base: Dictionary = declaration.duplicate(true)
		base.erase("literal_attribute_directives")
		if base != expected[index] or not valid_sha(base.get("source_sha256")): return fail("Layer declaration source identity differs.")
		var admitted: Dictionary = source_actor_admission(int(base.get("sprite_id",-1)))
		if not admitted.ok: return admitted
		var directives: Variant = declaration.get("literal_attribute_directives")
		if not directives is Array: return fail("Missing literal attribute directives.")
		for directive: Variant in directives:
			if not directive is Dictionary or not integer(directive.get("code")) or int(directive.code) != 104 or not directive.get("body") is String or not integer(directive.get("line"), 1): return fail("Invalid literal attribute directive.")
			attributes.append(directive.body)
			if not str(directive.body).is_valid_int(): unresolved = true
	if path.size() > 1 and not attributes.is_empty(): unresolved = true
	var projection: Dictionary = _attribute_projection(record,kind,sprite,path,selected_proof)
	if not projection.ok: return projection
	return {"ok":true,"attributes":attributes,"unresolved":unresolved,"declarations":path,"projection":projection.projection}

## New native DTOs separate requested files, metadata owners and occurrences.
## These checks prove a pinned metadata connection, never native execution.
func _native_markers(source: Dictionary, contract: Dictionary) -> Dictionary:
	var proof: Variant = source.get("source_proof")
	if not proof is Dictionary: return fail("Missing native source proof.")
	var present: bool = false
	for holder: Dictionary in [source,proof,contract]:
		present = present or holder.has("native_selector_policy") or holder.has("native_activation_policy")
	if not present: return {"ok":true,"native":false}
	for holder: Dictionary in [source,proof,contract]:
		if not holder.get("native_selector_policy") is String or not holder.get("native_activation_policy") is String: return fail("Incomplete native selector/activation markers.")
		if holder.native_selector_policy != NATIVE_SELECTOR_POLICY or holder.native_activation_policy != NATIVE_ACTIVATION_POLICY: return fail("Unsupported native selector/activation policy.")
	return {"ok":true,"native":true}

func _native_declaration_valid(value: Variant) -> bool:
	if not value is Dictionary or not integer(value.get("sprite_id"),1) or not value.has("alias_target") or not value.get("source_file") is String or not integer(value.get("source_line"),1) or not valid_sha(value.get("source_sha256")): return false
	var target: Variant = value.alias_target
	if target != null and not integer(target): return false
	var pattern := RegEx.new()
	pattern.compile("^list_[0-9]+\\.spr$")
	return pattern.search(value.source_file) != null

func _native_identity_matches(left: Dictionary, right: Dictionary) -> bool:
	for key: String in NATIVE_IDENTITY_FIELDS:
		if not left.has(key) or not right.has(key): return false
	for value: Dictionary in [left,right]:
		if not value.get("kind") is String or value.kind not in ["body","shadow","clothes"] or not integer(value.get("source_sprite_id"),1) or not integer(value.get("requested_sprite_id"),1) or not integer(value.get("metadata_owner_sprite_id"),1) or not value.get("file_remap_policy") is String or value.file_remap_policy != NATIVE_FILE_REMAP_POLICY or not value.get("native_binding_id") is String or str(value.native_binding_id).is_empty(): return false
		if value.kind == "body":
			if value.source_reference_index != null or value.target_index != null: return false
		elif not integer(value.source_reference_index) or not integer(value.target_index): return false
	for key: String in NATIVE_IDENTITY_FIELDS:
		if left[key] != right[key]: return false
	return true

func _native_literal_path(path: Variant, expected: Variant) -> Dictionary:
	if not path is Array or path.is_empty() or not expected is Array or expected.size() != path.size(): return fail("Native declaration path differs from its source proof.")
	var attributes: Array = []
	var unresolved: bool = false
	for index: int in range(path.size()):
		if not path[index] is Dictionary or not _native_declaration_valid(expected[index]): return fail("Invalid native declaration proof.")
		var literal: Dictionary = path[index]
		var base: Dictionary = literal.duplicate(true)
		base.erase("literal_attribute_directives")
		if base != expected[index]: return fail("Native declaration source identity differs.")
		var admitted: Dictionary = source_actor_admission(int(base.sprite_id))
		if not admitted.ok: return admitted
		var directives: Variant = literal.get("literal_attribute_directives")
		if not directives is Array: return fail("Missing native literal attribute directives.")
		for directive: Variant in directives:
			if not directive is Dictionary or not integer(directive.get("code")) or int(directive.code) != 104 or not directive.get("body") is String or not integer(directive.get("line"),1): return fail("Invalid native literal attribute directive.")
			attributes.append(directive.body)
			if not str(directive.body).is_valid_int(): unresolved = true
	return {"ok":true,"attributes":attributes,"unresolved":unresolved}

func _native_action_identity(source: Dictionary, action: Dictionary, action_id: int, actor_id: int) -> Dictionary:
	var proof: Dictionary = source.source_proof
	var request: Variant = proof.get("native_request_declaration")
	if not _native_declaration_valid(request) or request.sprite_id != actor_id: return fail("Invalid exact native request declaration.")
	var expected_key: String = "%s:B%d:A%d" % [request.source_file,int(request.source_line),action_id]
	if not source.get("action_key") is String or source.action_key != expected_key: return fail("Native action key differs from requested header provenance.")
	if not integer(action.get("native_requested_sprite_id"),1) or action.native_requested_sprite_id != actor_id or not integer(action.get("native_body_request_sprite_id"),1) or not integer(action.get("native_descriptor_origin_sprite_id"),1): return fail("Native descriptor/request owners differ.")
	var candidates: Variant = proof.get("raw_candidate_declarations")
	if not candidates is Array: return fail("Native descriptor origin declaration evidence is absent.")
	var origins: Array = []
	for candidate: Variant in candidates:
		if candidate is Dictionary and integer(candidate.get("sprite_id"),1) and candidate.sprite_id == action.native_descriptor_origin_sprite_id: origins.append(candidate)
	if origins.size() != 1 or not _native_declaration_valid(origins[0]) or origins[0].source_file != action.get("source_file") or origins[0].source_sha256 != action.get("source_sha256"): return fail("Native descriptor origin file pin differs.")
	var chain: Variant = action.get("native_action_alias_chain")
	if not chain is Array or not action.get("native_registration_kind") is String: return fail("Missing native action registration proof.")
	if action.native_registration_kind == "literal":
		if not chain.is_empty() or action.native_body_request_sprite_id != actor_id or action.native_descriptor_origin_sprite_id != actor_id: return fail("Literal native action borrowed another owner.")
	elif action.native_registration_kind == "explicit_action_alias":
		if chain.is_empty(): return fail("Missing explicit native action alias.")
		var owner: int = actor_id
		var alias_pattern := RegEx.new()
		alias_pattern.compile("^([0-9]+)\\s*=\\s*(-?[0-9]+)$")
		for index: int in range(chain.size()):
			var alias: Variant = chain[index]
			if not alias is Dictionary or not alias.get("source_file") is String or not alias.get("registration_status") is String or not alias.get("raw") is String or not integer(alias.get("action_id")) or int(alias.action_id) != action_id or not integer(alias.get("target_sprite_id"),1) or not integer(alias.get("source_line"),1) or not integer(alias.get("source_column")) or alias.registration_status != "registered": return fail("Invalid native action alias source event.")
			var owner_candidates: Array = []
			for candidate: Variant in candidates:
				if candidate is Dictionary and integer(candidate.get("sprite_id"),1) and int(candidate.sprite_id) == owner: owner_candidates.append(candidate)
			if owner_candidates.size() != 1 or not _native_declaration_valid(owner_candidates[0]) or alias.source_file != owner_candidates[0].source_file or int(alias.source_line) < int(owner_candidates[0].source_line): return fail("Native action alias event belongs to another source declaration.")
			var matched: RegExMatch = alias_pattern.search(alias.raw)
			if matched == null or int(matched.get_string(1)) != action_id or int(matched.get_string(2)) != int(alias.target_sprite_id): return fail("Native action alias raw target differs from its event.")
			if index == 0 and int(alias.target_sprite_id) != int(action.native_body_request_sprite_id): return fail("Immediate native action alias differs from its requested owner.")
			owner = int(alias.target_sprite_id)
		if owner != int(action.native_descriptor_origin_sprite_id): return fail("Native action alias chain differs from descriptor origin.")
	else: return fail("Unsupported native action registration.")
	return {"ok":true}

func _native_attributes(source: Dictionary, layer: Dictionary) -> Dictionary:
	var proof: Dictionary = source.source_proof
	var evidence: Variant = source.get("source_layer_declarations")
	if not evidence is Array or not proof.get("declarations") is Array: return fail("Missing native layer declaration evidence.")
	var matching_evidence: Array = []
	var matching_proofs: Array = []
	for item: Variant in evidence:
		if item is Dictionary and item.get("native_binding_id") is String and item.native_binding_id == layer.native_binding_id: matching_evidence.append(item)
	for item: Variant in proof.declarations:
		if item is Dictionary and item.get("native_binding_id") is String and item.native_binding_id == layer.native_binding_id: matching_proofs.append(item)
	if matching_evidence.size() != 1 or matching_proofs.size() != 1: return fail("Missing or ambiguous native occurrence binding proof.")
	var item: Dictionary = matching_evidence[0]
	var selected: Dictionary = matching_proofs[0]
	if not _native_identity_matches(layer,item) or not _native_identity_matches(layer,selected): return fail("Native layer identity differs across compact/proof/evidence.")
	var checked: Dictionary = _native_literal_path(item.get("declaration_path"),selected.get("declaration_path"))
	if not checked.ok: return checked
	var path: Array = item.declaration_path
	if path.size() > 2 or path[0].sprite_id != layer.requested_sprite_id or path[-1].sprite_id != layer.source_sprite_id: return fail("Native request/file owner differs from its one-hop path.")
	var first_target: Variant = path[0].alias_target
	if path.size() == 1:
		if first_target != null and first_target != layer.requested_sprite_id: return fail("Native single-hop file remap is incomplete.")
	elif first_target != layer.source_sprite_id: return fail("Native file remap differs from the requested header.")
	# The mapped file header's own alias is intentionally not followed again.
	var owner_checked: Dictionary = _native_literal_path(item.get("attribute_owner_declaration_path"),selected.get("attribute_owner_declaration_path"))
	if not owner_checked.ok: return owner_checked
	var owner_path: Array = item.attribute_owner_declaration_path
	if owner_path.size() != 1 or owner_path[0].sprite_id != layer.metadata_owner_sprite_id: return fail("Native metadata owner is not its own declaration.")
	var root: int = int(proof.root_sprite_id)
	var owner_base: Dictionary = owner_path[0].duplicate(true)
	owner_base.erase("literal_attribute_directives")
	var edges: Variant = selected.get("edge_path")
	if not edges is Array: return fail("Native active source edge proof is absent.")
	if layer.kind == "body":
		if layer.metadata_owner_sprite_id != root or owner_base != proof.native_request_declaration or not edges.is_empty(): return fail("Native body attributes do not belong to its original actor.")
	else:
		if edges.size() != 1 or not edges[0] is Dictionary or not edges[0].get("kind") is String or edges[0].kind != layer.kind or edges[0].get("target_sprite_id") != layer.requested_sprite_id or edges[0].get("source_reference_index") != layer.source_reference_index or edges[0].get("target_index") != layer.target_index: return fail("Native auxiliary requested target differs from its active edge.")
		if layer.kind == "clothes":
			if layer.metadata_owner_sprite_id != layer.requested_sprite_id or owner_base != selected.declaration_path[0] or edges[0].get("from_sprite_id") != root: return fail("Native clothes attributes do not belong to its original105 request.")
		elif layer.metadata_owner_sprite_id != root or owner_base != proof.native_request_declaration: return fail("Native shadow must retain its parent attribute owner.")
	var projection: Dictionary
	if layer.kind == "shadow":
		projection = {"ok":false,"flags":0,"present":false,"origin":"shadow_requires_parent_actor_flags","owner_proof":{"kind":"shadow","physical_sprite_id":int(layer.source_sprite_id),"requested_sprite_id":int(layer.requested_sprite_id),"parent_actor_sprite_id":root,"basis":"native101_parent_actor_flags","context":"requires_parent_submission_context"}}
	else:
		projection = ATTACHMENT_ATTRIBUTES.resolve(owner_checked.attributes)
		projection["owner_sprite_id"] = int(layer.metadata_owner_sprite_id)
		projection["owner_path_index"] = 0
		projection["owner_proof"] = {"kind":layer.kind,"requested_sprite_id":int(layer.requested_sprite_id),"physical_sprite_id":int(layer.source_sprite_id),"metadata_owner_sprite_id":int(layer.metadata_owner_sprite_id),"owner_path_index":0,"basis":"native_original_actor_own104" if layer.kind == "body" else "native_requested105_own104","declaration":owner_base,"context":"initial_or_reset_static_metadata_only"}
	return {"ok":true,"attributes":checked.attributes,"unresolved":checked.unresolved or (path.size() > 1 and not checked.attributes.is_empty()),"declarations":path,"projection":projection,"owner_declarations":owner_path,"owner_attributes":owner_checked.attributes,"instance_key":layer.native_binding_id}

func _load_native_action_attributes(source: Dictionary, layer: Dictionary, memo: Dictionary) -> Dictionary:
	var key: String = "native:" + str(layer.get("native_binding_id",""))
	if not memo.has(key):
		FRAME_HITCH.count("sp2.attribute_validate")
		var checked: Dictionary = _native_attributes(source,layer)
		if not checked.ok: return checked
		memo[key] = checked
	# The prepared API publishes immutable metadata. Freeze the action-local
	# proof once instead of copying it into every direction/frame occurrence.
	if _building_shared:
		PREPARED.freeze(memo[key])
		return memo[key]
	return (memo[key] as Dictionary).duplicate(true)

func _native_binding_set(source: Dictionary, layer_specs: Array, memo: Dictionary, action: Dictionary, source_role: String) -> Dictionary:
	var proof: Dictionary = source.source_proof
	if not source.get("source_layer_declarations") is Array or not proof.get("declarations") is Array or source.source_layer_declarations.size() != layer_specs.size() or proof.declarations.size() != layer_specs.size(): return fail("Native occurrence declaration count differs from compact layers.")
	var activation_by_role: Variant = proof.get("native_activation_by_role")
	if not activation_by_role is Dictionary or not activation_by_role.get(source_role) is Dictionary: return fail("Missing native per-action activation proof.")
	var activation: Dictionary = activation_by_role[source_role]
	if not activation.get("policy") is String or activation.policy != NATIVE_ACTIVATION_POLICY or activation.get("original_actor_sprite_id") != proof.root_sprite_id or activation.get("body_request_sprite_id") != action.native_body_request_sprite_id or activation.get("shadow_metadata_owner_sprite_id") != action.native_body_request_sprite_id or activation.get("clothes_metadata_owner_sprite_id") != proof.root_sprite_id or activation.get("auxiliary_recursion") != false or activation.get("runtime_activation_verified") != false: return fail("Native activation owner proof differs.")
	var seen: Dictionary = {}
	for spec: Variant in layer_specs:
		if not spec is Dictionary or not _native_identity_matches(spec,spec) or seen.has(spec.native_binding_id): return fail("Duplicate or invalid native occurrence identity.")
		seen[spec.native_binding_id] = true
		var expected_binding: String = "native:%d:A%d:%s:R%d:D%s:T%s" % [int(proof.root_sprite_id),int(action.code),spec.kind,int(spec.requested_sprite_id),"None" if spec.source_reference_index == null else str(int(spec.source_reference_index)),"None" if spec.target_index == null else str(int(spec.target_index))]
		if spec.native_binding_id != expected_binding: return fail("Native occurrence key differs from its verified request and operand identity.")
		if spec.kind == "body" and (spec.has("source_binding_id") or spec.has("reference_instance_ids")): return fail("Native body cannot impersonate an auxiliary occurrence.")
		if spec.kind != "body":
			if not spec.get("source_binding_id") is String or spec.source_binding_id != spec.native_binding_id or not spec.get("reference_instance_ids") is Array or spec.reference_instance_ids != ["native-ref:"+str(spec.native_binding_id)]: return fail("Native auxiliary requires its exact ordered literal occurrence.")
		if spec.kind == "body" and spec.requested_sprite_id != action.native_body_request_sprite_id: return fail("Native body request differs from selected action alias.")
		if spec.kind == "shadow":
			var selected: Array = []
			for item: Variant in proof.declarations:
				if item is Dictionary and item.get("native_binding_id") is String and item.native_binding_id == spec.native_binding_id: selected.append(item)
			if selected.size() != 1 or not selected[0].get("edge_path") is Array or selected[0].edge_path.size() != 1 or not selected[0].edge_path[0] is Dictionary or selected[0].edge_path[0].get("from_sprite_id") != action.native_body_request_sprite_id: return fail("Native shadow metadata owner differs from immediate body request.")
		var checked: Dictionary = _load_native_action_attributes(source,spec,memo)
		if not checked.ok: return checked
	return {"ok":true}

## The action JSON and its declaration proof are fixed during this load.
## Frames still validate their own layer identities, addresses and bindings;
## their identical kind/sprite attribute proof only needs checking once per
## action. Mutable callers still receive independent proof containers.
func _load_action_attributes(record: Dictionary, kind: String, sprite: int, memo: Dictionary) -> Dictionary:
	var key: String = kind + ":" + str(sprite)
	if not memo.has(key):
		FRAME_HITCH.count("sp2.attribute_validate")
		var checked: Dictionary = _attributes(record, kind, sprite)
		if not checked.ok: return checked
		memo[key] = checked
	# The prepared API publishes immutable metadata. Freeze the action-local
	# proof once instead of copying it into every direction/frame occurrence.
	if _building_shared:
		PREPARED.freeze(memo[key])
		return memo[key]
	return (memo[key] as Dictionary).duplicate(true)

## Opt-in immutable result for NPC previews. The normal load_bank API still
## returns independent mutable data and remains the full validation oracle.
## Admission/selection is performed by the caller on every spawn, not here.
func load_shared_bank(manifest_path: String, expected_sha: String, source_actor_id: int, bindings: Dictionary, loop_policy: Dictionary, consumer_scope: String, role_actor_ids: Dictionary = {}) -> Dictionary:
	var started: int = FRAME_HITCH.now()
	var key: String = digest(var_to_bytes([get_script().get_instance_id(),manifest_path,expected_sha,source_actor_id,bindings,loop_policy,consumer_scope,role_actor_ids]))
	var snapshot: RefCounted = PREPARED.lookup(key)
	if snapshot != null and _prepared_valid(snapshot,manifest_path,expected_sha):
		_release_parsed()
		_root = manifest_path.get_base_dir()
		_manifest_path = manifest_path
		_manifest_sha = expected_sha
		_manifest = snapshot.manifest
		_index = snapshot.index
		_excluded_source_actors = snapshot.exclusions.duplicate(true)
		_actor_pins = snapshot.actor_pins.duplicate()
		_prepared_members = snapshot.members.duplicate(true)
		_prepared_snapshot = snapshot
		FRAME_HITCH.count("sp2.prepared_hit")
		FRAME_HITCH.detail("sp2.prepared_lookup",started)
		return snapshot.result
	PREPARED.erase(key)
	FRAME_HITCH.count("sp2.prepared_miss")
	FRAME_HITCH.detail("sp2.prepared_lookup",started)
	_building_shared = true
	var loaded: Dictionary = load_bank(manifest_path,expected_sha,source_actor_id,bindings,loop_policy,consumer_scope,role_actor_ids)
	_building_shared = false
	if not loaded.ok: return loaded
	var frozen_started: int = FRAME_HITCH.now()
	snapshot = PREPARED.new()
	snapshot.result = loaded
	snapshot.manifest = _manifest
	snapshot.index = _index
	snapshot.exclusions = _excluded_source_actors.duplicate(true)
	snapshot.actor_pins = _actor_pins.duplicate()
	snapshot.members = _prepared_members.duplicate(true)
	PREPARED.freeze(snapshot.result)
	_prepared_snapshot = snapshot
	PREPARED.remember(key,snapshot)
	FRAME_HITCH.detail("sp2.prepared_freeze",frozen_started)
	return loaded

func _prepared_valid(snapshot: RefCounted, manifest_path: String, expected_sha: String) -> bool:
	if not MANIFEST_INDEX.pinned(manifest_path,expected_sha): return false
	for path: String in snapshot.actor_pins:
		if not MANIFEST_INDEX.pinned(path,snapshot.actor_pins[path]): return false
	for path: String in snapshot.members:
		var stamp: Array = snapshot.members[path]
		if _verified_members.get(path) != stamp or not FileAccess.file_exists(path) or int(FileAccess.get_size(path)) != int(stamp[1]) or int(FileAccess.get_modified_time(path)) != int(stamp[2]): return false
	return true

func load_bank(manifest_path: String, expected_sha: String, source_actor_id: int, bindings: Dictionary, loop_policy: Dictionary, consumer_scope: String = "", role_actor_ids: Dictionary = {}) -> Dictionary:
	var started: int = FRAME_HITCH.now()
	var result: Dictionary = _load_bank(manifest_path, expected_sha, source_actor_id, bindings, loop_policy, consumer_scope, role_actor_ids)
	FRAME_HITCH.detail("sp2.bank_load", started)
	return result

func _load_bank(manifest_path: String, expected_sha: String, source_actor_id: int, bindings: Dictionary, loop_policy: Dictionary, consumer_scope: String, role_actor_ids: Dictionary) -> Dictionary:
	_prepared_snapshot = null
	_prepared_members.clear()
	_root = manifest_path.get_base_dir()
	_manifest_path = manifest_path
	_manifest_sha = expected_sha
	_manifest = {}; _index = null; _excluded_source_actors.clear(); _actor_pins.clear(); _release_parsed()
	# One shared, storage-backed view of the pinned manifest per process.
	var opened: Dictionary = MANIFEST_INDEX.open(manifest_path, expected_sha, MAX_MANIFEST_JSON, valid_sha(expected_sha))
	if not opened.ok: return opened
	_index = opened.index
	_manifest = _index.top
	var loaded: Dictionary
	if _manifest.get("schema") != 1 or _manifest.get("kind") != "current523_reference_sp2_action_bank" or _manifest.get("source_snapshot") != "patch523": return fail("Not an exact current523 reference source bank.")
	if not consumer_scope.is_empty() and (_manifest.get("source_dummy_exclusion_policy") != SOURCE_DUMMY_EXCLUSION_POLICY or not _manifest.has("excluded_source_actors")): return fail("Production source consumers require the explicit source-declared dummy exclusion contract.")
	var contract: Variant = _manifest.get("consumer_contract")
	if not contract is Dictionary or contract.get("format") != "current523_identity_roles_v1" or contract.get("native_dispatch_verified") != false or contract.get("selection") != "explicit_source_actor_id_and_source_action_id" or contract.get("loop") != "unknown_requires_explicit_caller_policy" or contract.get("timing") not in ["source_explicit_fps_and_duration_ticks_only","source_explicit_or_existing_host_policy","source_explicit_or_client_section_default"]: return fail("Unsupported source bank consumer contract.")
	if contract.get("timing") == "source_explicit_or_client_section_default" and (contract.get("client_section_default_fps") != 24 or not contract.get("client_default_evidence") is String or str(contract.get("client_default_evidence")).is_empty()): return fail("Client section default timing requires the evidenced 24fps contract.")
	if contract.get("timing") == "source_explicit_or_existing_host_policy" and (contract.get("host_timing_opt_in") != true or contract.get("source_fps_policy") != "preserve_literal_value_including_null"): return fail("Host timing requires the explicit literal-FPS preservation contract.")
	var clothes_policy: Variant = contract.get("clothes_collection_policy", "")
	if not clothes_policy is String: return fail("Unsupported clothes collection policy type.")
	var clothes_prefix_policy: bool = clothes_policy == "first_null_asset_retains_successful_clothes_prefix"
	if contract.has("clothes_collection_policy") and not clothes_prefix_policy: return fail("Unsupported clothes collection policy.")
	if clothes_prefix_policy and contract.get("frame_policy") != "client_clamp_frame_null_missing_direction_or_empty_body": return fail("Clothes prefix policy requires the explicit client frame contract.")
	if source_actor_id < 0 or bindings.is_empty() or bindings.size() > 16 or bindings.size() != loop_policy.size(): return fail("Explicit source action bindings and loop policy are required for each role.")
	for role: Variant in role_actor_ids:
		if not bindings.has(role) or not integer(role_actor_ids[role],1): return fail("Each alternate role actor requires an exact existing caller role.")
	if not _index.registry_is_dictionary("actors") or not _index.registry_is_dictionary("members"): return fail("Missing source bank registry.")
	var exclusions: Dictionary = _install_source_exclusions()
	if not exclusions.ok: return exclusions
	var admitted: Dictionary = source_actor_admission(source_actor_id)
	if not admitted.ok: return admitted
	var entries: Variant = _actor_registry("sprite:" + str(source_actor_id))
	if not entries is Dictionary: return fail("Exact source actor ID is absent.")
	var tracks: Dictionary = {}
	var member_metadata: Dictionary = {}
	var record: Dictionary = {"source_sprite_id":source_actor_id,"tracks":tracks,"source_snapshot":"patch523"}
	record["source_dummy_exclusion_policy"] = _manifest.get("source_dummy_exclusion_policy")
	record["map_consumer_contract_dependency"] = "Map placement requires its separate source consumer contract; actor admission does not grant map placement."
	var independent_by_role: Dictionary = {}
	record["independent_source_layers"] = independent_by_role
	record["role_actor_ids"] = {}
	record["role_body_ids"] = {}
	for role: Variant in bindings:
		if not role is String or role.is_empty() or not integer(bindings[role]) or not loop_policy.has(role) or not loop_policy[role] is bool: return fail("Each caller role needs an exact action ID and explicit boolean loop policy.")
		var action_id: int = int(bindings[role])
		var role_actor_id: int = int(role_actor_ids.get(role,source_actor_id))
		admitted = source_actor_admission(role_actor_id)
		if not admitted.ok: return admitted
		var role_entries: Variant = _actor_registry("sprite:" + str(role_actor_id))
		if not role_entries is Dictionary: return fail("Exact source role actor ID is absent.")
		var entry: Variant = role_entries.get(str(action_id))
		if not entry is Dictionary or entry.get("path") != "actors/%d/action-%d.json" % [role_actor_id,action_id] or not valid_sha(entry.get("sha256")): return fail("Exact source action record is absent or unsafe.")
		var actor_path: String = _root.path_join(entry.path)
		loaded = _json(actor_path, entry.sha256)
		if not loaded.ok: return loaded
		_actor_pins[actor_path] = entry.sha256
		var source: Dictionary = loaded.value
		var action_attributes: Dictionary = {}
		if source.get("schema") != 1 or source.get("source_snapshot") != "patch523" or source.get("consumer_contract") != contract: return fail("Source action snapshot/contract mismatch.")
		var reference_instances: Dictionary = _source_reference_instances(source)
		if not reference_instances.ok: return reference_instances
		var actor: Variant = source.get("actor")
		var proof: Variant = source.get("source_proof")
		var source_role: String = "source_action:" + str(action_id)
		if not actor is Dictionary or not proof is Dictionary or actor.get("source_sprite_id") != role_actor_id or proof.get("root_sprite_id") != role_actor_id or not actor.get("roles") is Dictionary or actor.roles.size() != 1: return fail("Source action actor identity mismatch.")
		var native_policy: Dictionary = _native_markers(source,contract)
		if not native_policy.ok: return native_policy
		admitted = _source_graph_admission(proof)
		if not admitted.ok: return admitted
		var track: Variant = actor.roles.get(source_role)
		if not source.get("compact_roles") is Dictionary or not proof.get("roles") is Dictionary: return fail("Missing exact compact action/source roles.")
		var compact: Variant = source.compact_roles.get(source_role)
		var action: Variant = proof.roles.get(source_role)
		if not track is Dictionary or not compact is Dictionary or not action is Dictionary or not proof.get("declarations") is Array: return fail("Missing exact source action proof.")
		var source_fps: Variant = track.get("fps")
		var explicit_timing: bool = integer(source_fps, 1, 10000)
		var pending_timing: bool = source_fps == null and contract.get("timing") == "source_explicit_or_existing_host_policy"
		if track.get("source_action_id") != action_id or compact.get("source_action_id") != action_id or compact.get("source_sprite_id") != role_actor_id or action.get("code") != action_id or (not explicit_timing and not pending_timing) or source_fps != action.get("fps") or source_fps != compact.get("fps") or track.get("loop") != null or compact.get("loop") != null or not valid_sha(action.get("source_sha256")): return fail("Invalid preserved source timing/action identity.")
		var key_pattern := RegEx.new()
		var source_name_pattern := RegEx.new()
		source_name_pattern.compile("^list_[0-9]+\\.spr$")
		if not action.get("source_file") is String or source_name_pattern.search(action.source_file) == null: return fail("Invalid exact SPR source filename.")
		if track.get("source_file") != action.get("source_file") or track.get("source_line") != action.get("source_line"): return fail("Exact source descriptor provenance mismatch.")
		if native_policy.native:
			var native_action: Dictionary = _native_action_identity(source,action,action_id,role_actor_id)
			if not native_action.ok: return native_action
		else:
			key_pattern.compile("^" + str(action.get("source_file", "")).replace(".", "\\.") + ":B[0-9]+:A" + str(action_id) + "$")
			if not source.get("action_key") is String or key_pattern.search(source.action_key) == null: return fail("Exact source action key/provenance mismatch.")
		var tokens: Variant = compact.get("tokens")
		var layer_specs: Variant = compact.get("layers")
		var directions: Variant = track.get("directions")
		if not tokens is Array or tokens.is_empty() or tokens.size() > 4096 or tokens != action.get("tokens") or not layer_specs is Array or layer_specs.is_empty() or layer_specs.size() > 64 or not directions is Array or directions.size() != 8 or not integer(compact.get("declared_flag"),0,1) or compact.declared_flag != action.get("declared_flag"): return fail("Invalid source tokens, layers or directions.")
		var annotations: Variant = action.get("source_annotations",[])
		if not annotations is Array: return fail("Invalid literal source annotations.")
		for annotation: Variant in annotations:
			if not annotation is Dictionary or not integer(annotation.get("token_index"),0,tokens.size()-1) or not annotation.get("raw") is String: return fail("Invalid literal source annotation token.")
		if native_policy.native:
			var native_bindings: Dictionary = _native_binding_set(source,layer_specs,action_attributes,action,source_role)
			if not native_bindings.ok: return native_bindings
			record["native_selector_policy"] = NATIVE_SELECTOR_POLICY
			record["native_activation_policy"] = NATIVE_ACTIVATION_POLICY
		var body_layers: int = 0
		for layer: Variant in layer_specs:
			if not layer is Dictionary: return fail("Invalid compact layer specification.")
			if layer.get("kind") == "body":
				body_layers += 1
				if layer.get("source_sprite_id") != proof.get("body_sprite_id"): return fail("Exact resolved body ID differs from source proof.")
		if body_layers != 1: return fail("Exact source action requires one body layer.")
		var expanded: Array = []
		var total_ticks: int = 0
		for token: Variant in tokens:
			if not token is Array or token.size() != 3 or not integer(token[0]) or not integer(token[1],0,255) or not integer(token[2]): return fail("Invalid literal source frame token.")
			total_ticks += int(token[2])
		if total_ticks <= 0 or total_ticks > 2147483647: return fail("Source duration has no positive bounded total.")
		for direction: int in range(8):
			var frames: Variant = directions[direction]
			if not frames is Array or frames.size() != tokens.size(): return fail("Source direction token count differs.")
			var converted: Array = []
			for index: int in range(frames.size()):
				var frame: Variant = frames[index]
				var token: Array = tokens[index]
				if not frame is Dictionary or frame.get("duration_ticks") != token[2] or not frame.get("layers") is Array or frame.layers.size() != layer_specs.size(): return fail("Source frame timing/layers differ from literal tokens.")
				var shown: Dictionary = {"source_ticks":int(token[2]),"duration":_frame_seconds(int(token[2]),source_fps) if explicit_timing else 0.0,"source_group":int(token[0]),"source_frame":int(token[1]),"layers":[],"effect_layers":[]}
				var clothes_stop_index: int = -1
				# C06 selection depends on this token/direction, never the layer actor.
				var group: Dictionary = ORIGINAL_SELECTION.sp2_group(int(token[0]), int(compact.declared_flag) == 1, direction)
				for layer_index: int in range(frame.layers.size()):
					var layer: Variant = frame.layers[layer_index]
					var spec: Variant = layer_specs[layer_index]
					FRAME_HITCH.count("sp2.layer_validate")
					if not layer is Dictionary or not spec is Dictionary or layer.get("kind") not in ["body","shadow","clothes"] or layer.get("kind") != spec.get("kind") or not integer(layer.get("source_sprite_id")) or layer.source_sprite_id != spec.get("source_sprite_id"): return fail("Invalid literal layer identity.")
					if native_policy.native and not _native_identity_matches(layer,spec): return fail("Native frame occurrence differs from its compact identity.")
					var reference_binding: Dictionary = _reference_binding(source,reference_instances.by_id,layer,spec)
					if not reference_binding.ok: return reference_binding
					var native_attributes: Dictionary = {}
					if native_policy.native:
						native_attributes = _load_native_action_attributes(source,layer,action_attributes)
						if not native_attributes.ok: return native_attributes
						layer = layer.duplicate(true)
						layer.merge({"source_layer_instance_key":native_attributes.instance_key,"source_attributes":native_attributes.attributes,"source_attribute_declarations":native_attributes.declarations,"source_attributes_unresolved":native_attributes.unresolved,"source_attribute_projection":native_attributes.projection,"source_attribute_owner_declarations":native_attributes.owner_declarations,"source_attribute_owner_attributes":native_attributes.owner_attributes})
					var member: String = ORIGINAL_SELECTION.primary_name(int(layer.source_sprite_id), group.file_b)
					var client_frames: bool = contract.get("frame_policy") == "client_clamp_frame_null_missing_direction_or_empty_body"
					var frame_matches: bool = layer.get("frame_index") == token[1]
					if client_frames and not frame_matches and layer.get("clamped_from_frame_index") == token[1] and integer(layer.get("frame_index"),0,255) and int(layer.frame_index) < int(token[1]): frame_matches = true
					if layer.get("member") != member or layer.get("group_bit") != group.direction or not frame_matches: return fail("Literal source address differs from identity contract.")
					if clothes_prefix_policy and layer.kind == "clothes" and clothes_stop_index >= 0:
						if layer.get("client_null", "") == "clothes_prefix_stopped" and (not integer(layer.get("clothes_prefix_stop_layer_index")) or int(layer.clothes_prefix_stop_layer_index) != clothes_stop_index): return fail("Clothes prefix stop provenance differs from the first null.")
						var stopped: Dictionary = layer if native_policy.native else layer.duplicate(true)
						if layer.has("client_null"): stopped["source_client_null"] = layer.client_null
						stopped.merge({"client_null":"clothes_prefix_stopped","clothes_prefix_stop_layer_index":clothes_stop_index,"path":"raw/"+member,"texture_key":"","offset":[0,0],"layer_id":int(layer.source_sprite_id)})
						shown.effect_layers.append(stopped)
						continue
					if layer.has("client_null"):
						# A present empty Graphics/frame vector is not a null asset.
						var allowed_null: bool = layer.client_null in ["direction_absent","empty_body_frame"] or (clothes_prefix_policy and layer.client_null == "empty_frame_set")
						if not client_frames or not allowed_null or (layer.client_null == "empty_body_frame" and layer.kind != "body"): return fail("Unsupported client null layer.")
						if clothes_prefix_policy and layer.kind == "clothes" and layer.client_null == "direction_absent": clothes_stop_index = layer_index
						var null_layer: Dictionary = layer if native_policy.native else layer.duplicate(true)
						null_layer.merge({"path":"raw/"+member,"texture_key":"","offset":[0,0],"layer_id":int(layer.source_sprite_id)})
						if layer.kind == "clothes": shown.effect_layers.append(null_layer)
						else: shown.layers.append(null_layer)
						continue
					var attributes: Dictionary = native_attributes if native_policy.native else _load_action_attributes(source, layer.kind, int(layer.source_sprite_id), action_attributes)
					if not attributes.ok: return attributes
					var picture: Dictionary = _load_layer_metadata(layer, member_metadata)
					if not picture.ok: return picture
					if layer.kind == "body" and bool(picture.empty) and not client_frames: return fail("Exact source action has an empty body frame.")
					# Native input was privately copied before its attribute merge. Reuse
					# that copy so immutable shared proofs retain their ownership too.
					var converted_layer: Dictionary = layer if native_policy.native else layer.duplicate(true)
					converted_layer.merge({"path":"raw/"+member,"texture_key":"%s:%d:%d" % [member,int(layer.group_bit),int(layer.frame_index)],"offset":[picture.offset.x,picture.offset.y],"layer_id":int(layer.source_sprite_id),"source_attributes":attributes.attributes,"source_attribute_declarations":attributes.declarations,"source_attributes_unresolved":attributes.unresolved,"source_attribute_projection":attributes.projection,"blend_status":"source_attributes_preserved_M_equation_unverified","frame_provenance":picture.provenance})
					if not reference_binding.instances.is_empty():
						converted_layer["source_reference_instances"] = reference_binding.instances
						converted_layer.frame_provenance["source_reference_instances"] = reference_binding.instances.duplicate(true)
					if layer.kind == "clothes": shown.effect_layers.append(converted_layer)
					else: shown.layers.append(converted_layer)
				converted.append(shown)
			expanded.append(converted)
		tracks[role] = {"source_action_id":action_id,"source_action_key":source.action_key,"source_sprite_id":role_actor_id,"source_body_id":proof.body_sprite_id,"source_annotations":annotations.duplicate(true),"fps":source_fps,"effective_fps":source_fps if explicit_timing else 0.0,"loop":loop_policy[role],"directions":expanded,"static_pending_timing":not explicit_timing,"timing_origin":"SPR_explicit_section" if explicit_timing else "strict_unresolved"}
		record.role_actor_ids[role] = role_actor_id
		record.role_body_ids[role] = int(proof.body_sprite_id)
		var independent: Variant = source.get("independent_source_layers",[])
		if not independent is Array: return fail("Invalid independent source layer declarations.")
		independent_by_role[role] = []
		for attachment: Variant in independent:
			if not attachment is Dictionary or attachment.get("kind") not in ["clothes","shadow"] or not integer(attachment.get("from_sprite_id")) or not integer(attachment.get("target_sprite_id"),1) or attachment.get("parent_action_id") != action_id or attachment.get("child_action_id") != action_id or attachment.get("dispatch_policy") != "host_parent_role_starts_child_own_source_action_native_dispatch_unverified": return fail("Invalid independent source layer action dispatch.")
			var target_id: int = int(attachment.target_sprite_id)
			admitted = source_actor_admission(target_id)
			if not admitted.ok: return admitted
			admitted = source_actor_admission(int(attachment.from_sprite_id))
			if not admitted.ok: return admitted
			var child_key: String = "sprite:" + str(target_id)
			var child_path: String = "actors/%d/action-%d.json" % [target_id,action_id]
			var child_registry: Variant = _actor_registry(child_key) if _index.contains("actors", child_key) else {}
			if attachment.get("child_actor_key") != child_key or attachment.get("child_action_path") != child_path or not child_registry is Dictionary: return fail("Independent layer has no exact child actor registry.")
			var child_entry: Variant = child_registry.get(str(action_id))
			if not child_entry is Dictionary or child_entry.get("path") != child_path or not valid_sha(child_entry.get("sha256")) or not attachment.get("child_source_action_key") is String: return fail("Independent layer child source action is unavailable.")
			var declaration: Variant = attachment.get("source_declaration")
			var source_code: int = 101 if attachment.kind == "shadow" else 105
			if not declaration is Dictionary or declaration.get("code") != source_code or not integer(declaration.get("sprite_id")) or not declaration.get("body") is String or declaration.get("body") != attachment.get("source_reference") or not valid_sha(declaration.get("source_sha256")) or not integer(declaration.get("source_line"),1) or not declaration.get("source_file") is String or source_name_pattern.search(declaration.source_file) == null: return fail("Independent layer literal source declaration is unavailable.")
			admitted = source_actor_admission(int(declaration.sprite_id))
			if not admitted.ok: return admitted
			var values: PackedStringArray = str(declaration.body).replace("\t"," ").replace("\r"," ").replace("\n"," ").strip_edges().split(" ",false)
			if values.is_empty(): return fail("Independent literal layer target is missing.")
			if source_code == 105 and (values.size() < 2 or not values[0].is_valid_int() or int(values[0]) != values.size()-1): return fail("Invalid independent literal 105 count.")
			var target_values: PackedStringArray = values.slice(1) if source_code == 105 else values
			var declared_target: bool = false
			for value: String in target_values:
				if not value.is_valid_int(): return fail("Invalid independent literal layer target.")
				if int(value) == target_id: declared_target = true
			if not declared_target: return fail("Independent layer target is absent from literal source declaration.")
			var owner_proven: bool = false
			for owner: Dictionary in proof.declarations:
				var effective_owner: bool = false
				var literal_owner: bool = false
				for owner_path: Dictionary in owner.get("declaration_path",[]):
					if owner_path.get("sprite_id") == attachment.from_sprite_id: effective_owner = true
					if owner_path.get("sprite_id") == declaration.sprite_id and owner_path.get("source_file") == declaration.source_file and owner_path.get("source_sha256") == declaration.source_sha256: literal_owner = true
				if effective_owner and literal_owner:
					for active_owner_path: Dictionary in owner.get("declaration_path",[]):
						admitted = source_actor_admission(int(active_owner_path.get("sprite_id",-1)))
						if not admitted.ok: return admitted
					owner_proven = true
			if not owner_proven: return fail("Independent layer declaration owner is absent from source proof.")
			var attachment_record: Dictionary = attachment.duplicate(true)
			if attachment.has("source_binding_id") or attachment.has("reference_instance_ids"):
				var binding_id: Variant = attachment.get("source_binding_id")
				var instance_ids: Variant = attachment.get("reference_instance_ids")
				if not binding_id is String or binding_id.is_empty() or not instance_ids is Array or instance_ids.is_empty(): return fail("Independent source reference binding is incomplete.")
				var ordered_instances: Array = []
				for instance_id: Variant in instance_ids:
					if not instance_id is String or not reference_instances.by_id.has(instance_id): return fail("Independent source reference instance is absent.")
					var instance: Dictionary = reference_instances.by_id[instance_id]
					if instance.binding_id != binding_id or instance.kind != attachment.kind or instance.target_sprite_id != attachment.target_sprite_id or instance.from_sprite_id != attachment.from_sprite_id: return fail("Independent source reference instance has another binding.")
					ordered_instances.append(instance.duplicate(true))
				attachment_record["source_reference_instances"] = ordered_instances
			independent_by_role[role].append(attachment_record)
	var checked_members: Dictionary = _load_members_unchanged(member_metadata)
	if not checked_members.ok: return checked_members
	if not _pins_valid(): return fail("Source metadata changed while loading.")
	if _building_shared:
		for entry: Dictionary in member_metadata.values():
			_prepared_members[entry.path] = (_verified_members[entry.path] as Array).duplicate()
	return {"ok":true,"record":record,"tracks":tracks,"manifest_sha256":expected_sha,"source_actor_id":source_actor_id,"consumer_scope":consumer_scope,"source_dummy_exclusion_policy":record.source_dummy_exclusion_policy,"map_consumer_contract_dependency":record.map_consumer_contract_dependency,"purpose":"diagnostic_reference_preview","installed_in_main_this_run":false}
