extends RefCounted
class_name TwilightMythicGenderFilter

# PR122: gameplay-only exclusions. Original catalog files, sprites and
# animation source assets remain intact for provenance and rollback.
const EXCLUDED_SOURCE_IDS := {
    "131": true, "410": true, "132": true, "134": true,
    "136": true, "138": true, "140": true, "142": true,
    "161": true, "345": true, "258": true, "283": true,
}
const EXCLUDED_NAMES := {
    "신화-기사(여)": true, "신화-광전사(여)": true,
    "신화-군주(남)": true, "신화-요정(남)": true,
    "신화-마법사(남)": true, "신화-다크엘프(남)": true,
    "신화-총사(남)": true, "신화-투사(남)": true,
    "신화-암흑기사(남)": true, "신화-신성검사(남)": true,
    "신화-사신(남)": true, "신화-뇌신(남)": true,
}

static func is_excluded(record: Dictionary) -> bool:
    var name := str(record.get("name", ""))
    var source_id := str(record.get("sourceId", ""))
    # Name must be a mythic variant to avoid unrelated reused IDs.
    return EXCLUDED_NAMES.has(name) or (name.begins_with("신화-") and EXCLUDED_SOURCE_IDS.has(source_id))

static func filter_catalog(catalog: Dictionary) -> void:
    var value: Variant = catalog.get("변신", [])
    if not (value is Array):
        return
    var selected: Array = []
    for raw: Variant in value as Array:
        if raw is Dictionary and is_excluded(raw as Dictionary):
            continue
        selected.append(raw)
    catalog["변신"] = selected
