extends RefCounted
## C05 / P2. DESIGN_NOT_RECOVERED_API. IconID, AssetID and file ids are different
## types. Chain: ItemClass.IconID -> Icon.AssetId -> AssetView(AssetTypeId,FilePath)
## -> AssetType.Path + FilePath. The resolver adds no slash of its own; the texture
## wrapper's '//' normalisation is a later stage that is not modelled here.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const TEXTURE_FAILURE_ICON_ID := 683 # wrapper contract, applies only after a texture failure
const CSB_ASSET_TYPE := 101

static func icon_id(value: int) -> Dictionary:
	return {"kind": "IconID", "value": value}

static func asset_id(value: int) -> Dictionary:
	return {"kind": "AssetID", "value": value}

## tables: {"ItemClass": {id: row}, "Icon": {id: row}, "AssetView": {id: row}, "AssetType": {id: row}}
## Row field names follow the rows already used by this repository:
## AssetView{AssetId,AssetTypeId,FilePath}, AssetType{ID,Path}.
static func resolve_asset_path(tables: Dictionary, asset: Dictionary) -> Dictionary:
	if asset.get("kind") != "AssetID":
		return {"status": "WRONG_ID_KIND", "path": "", "reason": "an " + str(asset.get("kind")) + " is not an AssetID"}
	var view: Variant = (tables.get("AssetView", {}) as Dictionary).get(asset.value)
	if not view is Dictionary:
		return {"status": "ASSET_VIEW_ROW_ABSENT", "path": ""}
	# JSON numbers arrive as floats; tables are integer keyed, so whole numbers are
	# normalised before lookup. A non-integer id never matches a row.
	if not VOCAB.is_whole_number(view.get("AssetTypeId")):
		return {"status": "ASSET_TYPE_ID_NOT_INTEGER", "path": ""}
	var type_row: Variant = (tables.get("AssetType", {}) as Dictionary).get(int(view.get("AssetTypeId")))
	if not type_row is Dictionary:
		return {"status": "ASSET_TYPE_ROW_ABSENT", "path": ""}
	var prefix: String = str(type_row.get("Path", ""))
	var file_path: String = str(view.get("FilePath", ""))
	if prefix.is_empty():
		return {"status": "EMPTY_PREFIX", "path": ""}
	if file_path.is_empty():
		return {"status": "EMPTY_FILE_PATH", "path": ""}
	return {"status": "OK", "path": prefix + file_path, "asset_type_id": view.get("AssetTypeId")}

static func resolve_icon(tables: Dictionary, icon: Dictionary) -> Dictionary:
	if icon.get("kind") != "IconID":
		return {"status": "WRONG_ID_KIND", "path": "", "reason": "an " + str(icon.get("kind")) + " is not an IconID"}
	var row: Variant = (tables.get("Icon", {}) as Dictionary).get(icon.value)
	if not row is Dictionary:
		return {"status": "ICON_ROW_ABSENT", "path": ""}
	if not VOCAB.is_whole_number(row.get("AssetId")):
		return {"status": "ASSET_ID_NOT_INTEGER", "path": "", "icon_id": icon.value}
	var asset: Dictionary = asset_id(int(row.get("AssetId")))
	var resolved: Dictionary = resolve_asset_path(tables, asset)
	resolved["icon_id"] = icon.value
	resolved["asset_id"] = asset.value
	return resolved

## C05-T01: ItemClass 26 -> Icon 2932 -> Asset 30962 -> icon/Item/adena_3.png,
## never "26.png".
static func resolve_item_icon(tables: Dictionary, item_class_id: int) -> Dictionary:
	var item: Variant = (tables.get("ItemClass", {}) as Dictionary).get(item_class_id)
	if not item is Dictionary:
		return {"status": "ITEM_CLASS_ROW_ABSENT", "path": ""}
	if not VOCAB.is_whole_number(item.get("IconID")):
		return {"status": "ICON_ID_NOT_INTEGER", "path": "", "item_class_id": item_class_id}
	var resolved: Dictionary = resolve_icon(tables, icon_id(int(item.get("IconID"))))
	resolved["item_class_id"] = item_class_id
	resolved["chain"] = ["ItemClass:%d" % item_class_id, "Icon:%s" % str(resolved.get("icon_id")), "Asset:%s" % str(resolved.get("asset_id")), str(resolved.get("path"))]
	resolved["texture_failure_icon_id"] = TEXTURE_FAILURE_ICON_ID
	return resolved

## Spell icons: the base IconID/ActivateIconID pair first, then a SpellIconByWeapon
## override. Physical key is (WeaponTypeID, SpellClassID) but the lookup compares
## SpellClassID first. An override miss keeps the base pair.
static func spell_icon_pair(spell_class_row: Dictionary, overrides: Array, weapon_type_id: int) -> Dictionary:
	var pair := {"IconID": spell_class_row.get("IconID"), "ActivateIconID": spell_class_row.get("ActivateIconID"), "source": "base"}
	for row: Variant in overrides:
		if row is Dictionary and row.get("SpellClassID") == spell_class_row.get("ID") and row.get("WeaponTypeID") == weapon_type_id:
			return {"IconID": row.get("IconID"), "ActivateIconID": row.get("ActivateIconID"), "source": "SpellIconByWeapon"}
	return pair

## C05-T03: a SpriteAnimation with frame count 0 and AssetType 101 may fall back to
## frame repetition and still keep the CSB timeline possibility. UI delay is /1000 s.
static func animation_plan(asset_type_id: int, frame_count: int) -> Dictionary:
	return {"frame_repetition_fallback": frame_count <= 0, "csb_timeline_possible": asset_type_id == CSB_ASSET_TYPE}

static func ui_frame_delay_seconds(delay_ms: int) -> float:
	return float(delay_ms) / 1000.0
