extends RefCounted
## Source class/gender artwork for an explicitly named existing display role.
## ClassAssets has a composite key, not an ID or an implicit gender/first row.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const DEFINITIONS_PATH = "res://scripts/resources/current523_definition_rows.gd"
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const ROLES = ["HUD","BigHUD","MainHUDPortraitID","Icon"]

static func selected() -> bool:
	return IMAGES.selected()

static func _missing(context: Dictionary, role: String, reason: String) -> Dictionary:
	return {"ok":false,"route":"source523_images","status":"original_icon_not_installed",
		"source_status":reason,"reason":reason,"role":"ClassAssets." + role,
		"class_id":context.get("class_id"),"gender_id":context.get("gender_id"),
		"texture":null,"provenance":{},"original_bytes_unchanged":false,
		"actual_game_consumption_observed":false}

static func resolve(context: Dictionary, role: String = "MainHUDPortraitID") -> Dictionary:
	if not selected(): return _missing(context,role,"source523_image_pack_not_selected")
	if not role in ROLES: return _missing(context,role,"source_class_image_role_required")
	var class_id: Variant = context.get("class_id")
	var gender_id: Variant = context.get("gender_id")
	if not class_id is int or class_id <= 0: return _missing(context,role,"source_native_class_identity_required")
	if not gender_id is int or gender_id <= 0: return _missing(context,role,"source_explicit_gender_required")
	if not ResourceLoader.exists(DEFINITIONS_PATH): return _missing(context,role,"source_class_definition_reader_not_installed")
	var api: Script = load(DEFINITIONS_PATH) as Script
	if api == null: return _missing(context,role,"source_class_definition_reader_not_installed")
	var methods: Dictionary = {}
	for method: Dictionary in api.get_script_method_list(): methods[str(method.get("name",""))] = true
	for required: String in ["identity","row","related","problem"]:
		if not methods.has(required): return _missing(context,role,"source_class_definition_reader_contract_required")
	var identity: Variant = api.identity()
	if not identity is Dictionary or identity.get("kind") != "twilight.current523.original-definitions.v1" or identity.get("source_snapshot") != "patch523" or identity.get("source_sha256") != SOURCE_SHA or identity.get("source_bytes") != 25031173:
		var missing: Dictionary = _missing(context,role,"source_class_original_definitions_not_available")
		missing["source_definition_problem"] = str(api.problem())
		return missing
	var source_class: Variant = api.row("Class",class_id)
	var source_gender: Variant = api.row("Gender",gender_id)
	if not source_class is Dictionary or not source_gender is Dictionary or not IMAGES.PACK._integer(source_class.get("ID")) or int(source_class.ID) != class_id or not IMAGES.PACK._integer(source_gender.get("ID")) or int(source_gender.ID) != gender_id:
		return _missing(context,role,"source_class_gender_row_required")
	var candidates: Variant = api.related("ClassAssets","ClassID",class_id)
	if not candidates is Array: return _missing(context,role,"source_class_assets_rows_required")
	var matches: Array = []
	for candidate: Variant in candidates:
		if not candidate is Dictionary or not IMAGES.PACK._integer(candidate.get("ClassID")) or not IMAGES.PACK._integer(candidate.get("GenderID")): continue
		if int(candidate.ClassID) == class_id and int(candidate.GenderID) == gender_id: matches.append(candidate)
	if matches.size() != 1:
		return _missing(context,role,"source_class_assets_composite_key_missing" if matches.is_empty() else "source_class_assets_composite_key_ambiguous")
	var row: Dictionary = matches[0]
	var image: Dictionary = IMAGES.resolve_asset_value(row.get(role))
	var provenance: Dictionary = image.get("provenance",{}).duplicate(true)
	var source_status: String = str(image.get("status","source_class_image_unavailable"))
	var texture: Variant = image.get("texture")
	var original: bool = image.get("ok",false) == true and texture is Texture2D and not texture is AnimatedTexture and image.get("original_bytes_unchanged") == true and not provenance.is_empty()
	if image.get("ok",false) == true and not original: source_status = "source_class_static_original_texture_required"
	provenance["class_assets_relation"] = {"source_table":"ClassAssets",
		"composite_key":{"ClassID":class_id,"GenderID":gender_id},"source_field":role,
		"source_asset_value":row.get(role),"source_snapshot":identity.source_snapshot,
		"source_archive_sha256":identity.source_sha256,"source_archive_bytes":identity.source_bytes,
		"source_reader_kind":identity.kind,"source_reader":DEFINITIONS_PATH,
		"identity_basis":"existing_native_class_explicit_gender_and_unique_original_ClassAssets_pair",
		"image_pack_canonical_class_row_check":false}
	image["ok"] = original
	image["class_id"] = class_id
	image["gender_id"] = gender_id
	image["route"] = "source523_images"
	image["role"] = "ClassAssets." + role
	image["status"] = "original_linked" if original else "original_icon_not_installed"
	image["source_status"] = source_status
	image["reason"] = "" if original else source_status
	image["texture"] = texture if original else null
	image["provenance"] = provenance
	image["actual_game_consumption_observed"] = false
	return image

static func evidence(image: Dictionary) -> Dictionary:
	var result: Dictionary = image.duplicate(true)
	result.erase("texture")
	return result
