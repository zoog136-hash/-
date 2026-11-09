extends RefCounted
## C01 / P0. DESIGN_NOT_RECOVERED_API. Pins which original build the contracts
## describe. Code origin 524 and data snapshot 525 are different facts and are not
## a guarantee that one runnable build exists. No original binary is executed,
## loaded or emulated; the hashes only identify a build.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const LOCK_PATH := "res://data/original_client/source_lock.json"
const CODE_ORIGIN := 524
const DATA_SNAPSHOT := 525
const EXE_NAME := "LineageM_1.10.22.0.exe"
const EXE_SHA256 := "9f9c3b9c9a49fb598899b3da308b4776cbbc47cbb98dbe4b4aa368cce519019d"
const DLL_NAME := "libcocos2d.dll"
const DLL_SHA256 := "36857a2a13f46c4f24ebe8bce6626edfdd0c39b582a947ab03a6d43c551d185a"

static func make(module: String, sha256: String, package_id: String, source_member: String, rva: String, evidence_status: String) -> Dictionary:
	return {
		"record": "SourceIdentity",
		"design_status": VOCAB.EVIDENCE_DESIGN,
		"module": module,
		"sha256": sha256.to_lower(),
		"code_origin": CODE_ORIGIN,
		"data_snapshot": DATA_SNAPSHOT,
		"package_id": package_id,
		"source_member": source_member,
		"rva": rva,
		"evidence_status": evidence_status,
	}

static func pinned_hash(module: String) -> String:
	if module == EXE_NAME:
		return EXE_SHA256
	if module == DLL_NAME:
		return DLL_SHA256
	return ""

## C01-T01: a different binary hash separates the build and stops adapter entry.
static func gate_adapter_entry(module: String, observed_sha256: String) -> Dictionary:
	var pinned: String = pinned_hash(module)
	if pinned.is_empty():
		return {"accepted": false, "status": "UNKNOWN_MODULE", "module": module, "reason": "module is not part of the pinned source lock"}
	if observed_sha256.strip_edges().to_lower() != pinned:
		return {"accepted": false, "status": "DIFFERENT_BUILD_SEPARATED", "module": module,
			"reason": "SHA-256 differs from the pinned build; adapter entry stopped (DESIGN protection)"}
	return {"accepted": true, "status": "SAME_BUILD_IDENTITY_ONLY", "module": module,
		"reason": "hash matches the pinned build; this identifies the build and proves nothing about execution"}

## C01-T02: a manifest name hit is not a decode success and not a render success.
static func payload_state(manifest_hit: bool, payload_verified: bool, render_observed: bool = false) -> Dictionary:
	return {
		"manifest_hit": manifest_hit,
		"payload_status": "VERIFIED" if (manifest_hit and payload_verified) else VOCAB.PAYLOAD_UNVERIFIED,
		"render_status": "OBSERVED" if (manifest_hit and payload_verified and render_observed) else VOCAB.RENDER_NOT_OBSERVED,
	}

static func load_lock() -> Dictionary:
	var file := FileAccess.open(LOCK_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

## Returns the SourceIdentity for an approved source id (S001...), or {} when the
## id is not in the lock. Never invents a source.
static func from_source_id(lock: Dictionary, source_id: String) -> Dictionary:
	for entry: Variant in lock.get("sources", []):
		if entry is Dictionary and entry.get("source_id") == source_id:
			return make("approved_report_or_artifact", str(entry.get("sha256", "")), str(entry.get("package_id", "")),
				str(entry.get("member", "")), "", VOCAB.EVIDENCE_CONFIRMED)
	return {}
