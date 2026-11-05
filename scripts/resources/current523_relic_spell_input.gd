extends RefCounted
## Optional input hand-off to PR269's existing owner. This module never builds
## profiles, installs an archive, changes spell levels or touches saved ownership.
const CommonSource=preload("res://scripts/resources/current523_definition_rows.gd")
const OWNER_PATH: String="res://scripts/cards/relic_spell_levels.gd"
const INSTALLED: String="user://source_rules/relic-patch523.zip"

static func adopt(accepted_archive_identity: Dictionary) -> Dictionary:
	# The caller supplies the archive identity only after accepting original
	# player profiles. It is not their in-memory/compiled profile fingerprint.
	if accepted_archive_identity.get("source_snapshot")!="patch523" or accepted_archive_identity.get("source_sha256")!=CommonSource.SOURCE_SHA or accepted_archive_identity.get("source_bytes")!=CommonSource.SOURCE_BYTES:
		return _status("held","accepted_original_profile_identity_required")
	if not ResourceLoader.exists(OWNER_PATH):return _status("unavailable","owner_module_unavailable")
	var owner: Resource=load(OWNER_PATH)
	var owner_script: Script=owner as Script
	if owner_script==null:return _status("held","owner_script_unavailable")
	for method: String in ["load_source","ensure_loaded"]:
		if not owner.has_method(method):return _status("held","owner_method_unavailable:"+method)
	var constants: Dictionary=owner_script.get_script_constant_map()
	if constants.get("SOURCE_SHA256")!=CommonSource.SOURCE_SHA or constants.get("SOURCE_BYTES")!=CommonSource.SOURCE_BYTES or constants.get("INSTALLED")!=INSTALLED:
		return _status("held","owner_source_contract_mismatch")
	# This is the owner's load/ensure selection flag. Rejected install candidates
	# retain the previous selection and do not commit a replacement input.
	# A missing/unsupported static-property read is never interpreted as false.
	var checked: Variant=owner.get("_default_checked")
	if not checked is bool:return _status("held","owner_selection_flag_unreadable")
	if checked:return _ensure(owner,"owner_selection_already_checked")
	var installed: FileAccess=FileAccess.open(INSTALLED,FileAccess.READ)
	if installed!=null:
		installed.close()
		return _ensure(owner,"owner_installed_archive")
	var open_error: Error=FileAccess.get_open_error()
	if open_error!=ERR_FILE_NOT_FOUND:return _ensure(owner,"owner_installed_access_failure")
	# No committed/default load selection exists, and its dedicated file is
	# absent. Read the approved held original through the existing owner parser.
	# No install method, selection-flag write or archive copy is performed here.
	var path: String=CommonSource.archive_path()
	if path.is_empty():return _status("unavailable","common_archive_unavailable",{"error":CommonSource.problem()})
	var result: Variant=owner.call("load_source",path)
	if not result is Dictionary or not result.get("ok") is bool:
		return _status("held","owner_load_result_unsupported",{"called":"load_source","selection":"held_current523_archive"})
	return _status("loaded" if result.ok else "rejected","owner_source_result",{"called":"load_source","selection":"held_current523_archive","archive_identity":accepted_archive_identity.duplicate(true),"owner_result":result.duplicate(true)})

static func _ensure(owner: Resource,selection: String) -> Dictionary:
	var result: Variant=owner.call("ensure_loaded")
	if not result is bool:return _status("held","owner_ensure_result_unsupported",{"called":"ensure_loaded","selection":selection})
	return _status("ready" if result else "rejected","owner_existing_selection",{"called":"ensure_loaded","selection":selection,"owner_loaded":result})

static func _status(state: String,reason: String,details: Dictionary={}) -> Dictionary:
	var result: Dictionary={"state":state,"reason":reason,"owner_module":OWNER_PATH}
	result.merge(details,true)
	return result
