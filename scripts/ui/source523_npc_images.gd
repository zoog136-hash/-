extends RefCounted
## Original NPC illustration consumer. UI267 owns targets, transforms and input;
## integration269 owns the authoritative current-dialogue/mobile-NPC relation.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const NPC_CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
const NPC_CATALOG_PATH = "res://scripts/monsters/patch523_npc_catalog.gd"
const DEFINITIONS_PATH = "res://scripts/resources/current523_definition_rows.gd"
const ROLE = "NpcClass.IllustAssetID"
const TARGET_MEMBER = "UI/NpcDialogue/NpcDialogue_All.csb"
const TARGET_SHA256 = "f27872592f0f7f6b74b81308bc64f98f4bc337beff60c030f4f1ac060aed4ccf"
const TARGET_OFFSET: int = 4912

static func _missing(npc_id: int, reason: String) -> Dictionary:
	return {"ok":false,"npc_class_id":npc_id,"role":ROLE,"route":"source523_images",
		"status":"original_icon_not_installed","source_status":reason,"reason":reason,
		"original_bytes_unchanged":false,"texture":null,"provenance":{},
		"actual_game_consumption_observed":false}

static func _source_catalog(catalog: Object) -> bool:
	if not is_instance_valid(catalog) or not catalog is RefCounted or not catalog.has_method("row"): return false
	var script: Variant = catalog.get_script()
	return script is Script and script.resource_path == NPC_CATALOG_PATH

static func resolve(catalog: Object, npc_id: int) -> Dictionary:
	if not IMAGES.selected(): return _missing(npc_id,"source523_image_pack_not_selected")
	if npc_id <= 0 or not _source_catalog(catalog): return _missing(npc_id,"source_npc_catalog_required")
	var content: Variant = catalog.get("content")
	if not content is Dictionary or content.get("kind") != "patch523_npc_spell_catalog" or content.get("schema") != 1 or content.get("source_snapshot") != "patch523" or content.get("source_archive_sha256") != NPC_CATALOG.SOURCE_SHA:
		return _missing(npc_id,"source_npc_catalog_not_loaded")
	var row: Variant = catalog.call("row","NpcClass",npc_id)
	var entry: Variant = content.get("tables",{}).get("NpcClass",{}).get(str(npc_id))
	if not row is Dictionary or not entry is Dictionary or entry.get("row") != row or not IMAGES.PACK._integer(row.get("ID")) or int(row.ID) != npc_id or not IMAGES.PACK._integer(entry.get("source_row_1based")) or int(entry.source_row_1based) <= 0:
		return _missing(npc_id,"source_npc_row_not_installed")
	var relation: Dictionary = {"source_table":"NpcClass","source_id":npc_id,
		"source_field":"IllustAssetID","source_asset_value":row.get("IllustAssetID"),
		"source_row_1based":int(entry.source_row_1based),"source_snapshot":content.source_snapshot,
		"source_archive_sha256":content.source_archive_sha256,
		"identity_basis":"existing_pinned_npc_catalog_row_and_declared_illustration_asset",
		"image_pack_canonical_npc_row_check":false}
	return _resolve_row(row,npc_id,relation)

static func resolve_definition(npc_id: int) -> Dictionary:
	if not IMAGES.selected(): return _missing(npc_id,"source523_image_pack_not_selected")
	if npc_id <= 0: return _missing(npc_id,"source_npc_identity_required")
	# Reuse Data271's exact original-archive reader for town NPCs as well.
	# It is an integration dependency, not another table importer or pack.
	if not ResourceLoader.exists(DEFINITIONS_PATH): return _missing(npc_id,"source_npc_definition_reader_not_installed")
	var api: Script = load(DEFINITIONS_PATH) as Script
	if api == null: return _missing(npc_id,"source_npc_definition_reader_not_installed")
	var methods: Dictionary = {}
	for method: Dictionary in api.get_script_method_list(): methods[str(method.get("name",""))] = true
	if not methods.has("identity") or not methods.has("row") or not methods.has("problem"):
		return _missing(npc_id,"source_npc_definition_reader_contract_required")
	var identity: Variant = api.identity()
	if not identity is Dictionary or identity.get("kind") != "twilight.current523.original-definitions.v1" or identity.get("source_snapshot") != "patch523" or identity.get("source_sha256") != NPC_CATALOG.SOURCE_SHA or identity.get("source_bytes") != 25031173:
		var unavailable: Dictionary = _missing(npc_id,"source_npc_original_definitions_not_available")
		unavailable["source_definition_problem"] = str(api.problem())
		return unavailable
	var row: Variant = api.row("NpcClass",npc_id)
	if not row is Dictionary or row.is_empty() or not IMAGES.PACK._integer(row.get("ID")) or int(row.ID) != npc_id:
		var unavailable: Dictionary = _missing(npc_id,"source_npc_definition_row_not_available")
		unavailable["source_definition_problem"] = str(api.problem())
		return unavailable
	var relation: Dictionary = {"source_table":"NpcClass","source_id":npc_id,"source_field":"IllustAssetID",
		"source_asset_value":row.get("IllustAssetID"),"source_snapshot":identity.source_snapshot,
		"source_archive_sha256":identity.source_sha256,"source_archive_bytes":identity.source_bytes,
		"source_reader_kind":identity.kind,"source_reader":DEFINITIONS_PATH,
		"identity_basis":"current523_definition_rows_exact_source_archive_and_unique_original_ID",
		"image_pack_canonical_npc_row_check":false}
	# This reader does not supply row positions or table/row hashes. Do not
	# fabricate those fields or a compiled-catalog entry for its original row.
	return _resolve_row(row,npc_id,relation)

static func _resolve_row(row: Dictionary, npc_id: int, relation: Dictionary) -> Dictionary:
	if row.get("TestNPC",false) == true:
		var excluded: Dictionary = _missing(npc_id,"source_test_npc_excluded")
		excluded["excluded_from_connection"] = true
		excluded["npc_source_relation"] = relation.duplicate(true)
		excluded["provenance"] = {"npc_source_relation":relation.duplicate(true)}
		return excluded
	# IllustAssetID is the declared AssetView key; retain its actual type/path.
	var image: Dictionary = IMAGES.resolve_asset_value(row.get("IllustAssetID"))
	var source_status: String = str(image.get("status","source_npc_illustration_unavailable"))
	var texture: Variant = image.get("texture")
	var provenance: Dictionary = image.get("provenance",{}).duplicate(true)
	var original: bool = image.get("ok",false) == true and texture is Texture2D and not texture is AnimatedTexture and image.get("original_bytes_unchanged") == true and not provenance.is_empty()
	if image.get("ok",false) == true and not original: source_status = "source_npc_static_original_texture_required"
	provenance["npc_source_relation"] = relation.duplicate(true)
	image["ok"] = original
	image["npc_class_id"] = npc_id
	image["role"] = ROLE
	image["route"] = "source523_images"
	image["source_status"] = source_status
	image["status"] = "original_linked" if original else "original_icon_not_installed"
	image["reason"] = "" if original else source_status
	image["texture"] = texture if original else null
	image["provenance"] = provenance
	image["npc_source_relation"] = relation
	image["actual_game_consumption_observed"] = false
	return image

static func _texture_free_basis(value: Variant, depth: int = 0) -> bool:
	if depth > 12: return false
	if value is Object or value is Callable or value is Signal: return false
	if value is float: return is_finite(value)
	if value is Array:
		for item: Variant in value:
			if not _texture_free_basis(item,depth + 1): return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not _texture_free_basis(key,depth + 1) or not _texture_free_basis(value[key],depth + 1): return false
		return true
	return true

static func dialogue_image(context: Dictionary, target: Dictionary, catalog: Object = null) -> Dictionary:
	var npc_id: Variant = context.get("npc_class_id")
	if not npc_id is int or npc_id <= 0: return _missing(0,"source_npc_dialogue_mobile_identity_required")
	var basis: Variant = context.get("source_basis")
	if context.get("ok") != true or not context.get("npc_id") is String or context.npc_id.is_empty() or not context.get("node_id") is String or not basis is Dictionary or basis.is_empty() or not _texture_free_basis(basis):
		return _missing(npc_id,"source_npc_dialogue_context_required")
	if target.get("ok") != true or target.get("schema") != "twilight-native-icon-scene-slot-v1" or target.get("member") != TARGET_MEMBER or target.get("source_sha256") != TARGET_SHA256 or target.get("node_offset") != TARGET_OFFSET or not target.get("manifest_sha256") is String or target.manifest_sha256.length() != 64:
		return _missing(npc_id,"source_npc_dialogue_original_target_required")
	# The default full definition reader covers original town NPCs without
	# the combat catalog's category/attackability restrictions. An explicitly
	# supplied NPC catalog keeps its own source-row extent and never falls back.
	var image: Dictionary = resolve_definition(npc_id) if catalog == null else resolve(catalog,npc_id)
	image["provenance"]["dialogue_context"] = {"npc_id":context.npc_id,"node_id":context.node_id,
		"npc_class_id":npc_id,"source_basis":basis.duplicate(true)}
	image["provenance"]["original_target"] = {"member":target.member,"source_sha256":target.source_sha256,
		"manifest_sha256":target.manifest_sha256,"node_offset":TARGET_OFFSET}
	# The receiver uploads static original pixels into its own authored Sprite.
	# This supplies no CSB scene descriptor, new transform or playback policy.
	return image

static func bind_dialogue(hud: Node, context_provider: Callable, catalog: Object = null) -> Dictionary:
	if not is_instance_valid(hud) or not hud.has_method("bind_original_npc_dialogue_portrait"):
		return {"ok":false,"error":"source_npc_dialogue_receiver_not_installed"}
	if not context_provider.is_valid(): return {"ok":false,"error":"source_npc_dialogue_context_provider_required"}
	if catalog != null and not _source_catalog(catalog): return {"ok":false,"error":"source_npc_catalog_required"}
	var image_provider: Callable = dialogue_image
	var result: Variant = hud.call("bind_original_npc_dialogue_portrait",context_provider,image_provider.bind(catalog))
	return result if result is Dictionary else {"ok":false,"error":"source_npc_dialogue_receiver_contract_required"}

static func evidence(image: Dictionary) -> Dictionary:
	var result: Dictionary = image.duplicate(true)
	result.erase("texture")
	return result
