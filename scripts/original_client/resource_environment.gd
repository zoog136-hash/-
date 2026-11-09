extends RefCounted
## C02 / P1. DESIGN_NOT_RECOVERED_API. Resource root and initial search path
## contract. Initialization and delegate replacement are separate operations.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const DEFAULT_PACKING_VALUE := "true"

## Windows normal path: EXE drive+directory with separators turned into '/', then
## "../Client/" appended. '..' is NOT collapsed. The input must be drive+directory
## including its trailing separator, as splitpath yields it.
static func asset_path_from_exe_dir(drive_and_dir: String) -> Dictionary:
	var normalized: String = drive_and_dir.replace("\\", "/")
	if not normalized.ends_with("/"):
		return {"status": "INPUT_REJECTED_NO_TRAILING_SEPARATOR", "asset_path": ""}
	return {"status": "OK", "asset_path": normalized + "../Client/"}

## NetworkConfig.use_packing_resource (field 301, STRING, default "true").
## Only the exact strings "false" and "0" after byte-wise lowercase select mode 0.
## No trimming. A JSON boolean is not a string and fails conversion.
static func parse_packing_mode(value: Variant) -> Dictionary:
	if value == null:
		return {"status": "ABSENT_OR_NULL_KEEPS_DESTINATION", "mode": -1}
	if value is String:
		var lowered: String = VOCAB.lower_ascii(value)
		var mode: int = 0 if (lowered == "false" or lowered == "0") else 1
		return {"status": "OK", "mode": mode, "raw": value}
	return {"status": "STRING_CONVERSION_FAILED", "mode": -1, "raw_type": typeof(value)}

## Merge: absent/null keeps the destination value. The initial destination is the
## default string "true", so a first null still means effective mode 1.
static func merge_packing_value(destination: String, incoming: Variant) -> String:
	if incoming == null:
		return destination
	if incoming is String:
		return incoming
	return destination

static func effective_mode(destination: String) -> int:
	var parsed: Dictionary = parse_packing_mode(destination)
	return int(parsed.get("mode", 1)) if parsed.status == "OK" else 1

## Search order for: mode 1, new delegate init succeeded, new LayoutManager, no
## extra registration. A = AssetPath, D = Cocos EXE directory. Any other
## combination is outside the confirmed contract and reports UNVERIFIED.
static func search_paths(asset_path: String, cocos_root: String, mode: int, delegate_init_ok: bool, new_layout_manager: bool, extra_registration: bool) -> Dictionary:
	if mode == 1 and delegate_init_ok and new_layout_manager and not extra_registration:
		return {"status": VOCAB.EVIDENCE_CONFIRMED, "paths": [asset_path + "UI/", cocos_root, cocos_root + "Resources/", asset_path]}
	return {"status": VOCAB.EVIDENCE_UNVERIFIED, "paths": [], "reason": "combination not covered by the confirmed contract"}

## C02-T03: replacing the delegate does not copy paths, cache, remap or writable
## state, and does not guarantee an existing LayoutManager re-registers UI paths.
static func replace_delegate(previous_paths: Array, layout_manager_exists: bool) -> Dictionary:
	return {
		"previous_search_paths_copied": false,
		"cache_copied": false,
		"remap_copied": false,
		"writable_state_copied": false,
		"layout_manager_ui_paths": "NOT_GUARANTEED_REREGISTERED" if layout_manager_exists else "NEW_LAYOUT_MANAGER_REGISTERS",
		"search_paths_after": [],
		"discarded_path_count": previous_paths.size(),
	}
