extends RefCounted
## User-authorized host placement, NOT an original filename/selector rule.
## Raw member, source bytes and all existing chunk positions remain unchanged.
const MEMBER="Map/Aden/800f7ff3e.s32"
const SOURCE_SHA256="bc79ea23c3ba0443f57f45bff55cce72390d9011c3db50b79c8c21359e143e11"
const ORIGIN=Vector2i(33472,32128)
const POLICY="TWILIGHT_INFERRED_ADEN_FRONTIER_V1"
const OPTION="aden_inferred_placement_enabled"

static func record() -> Dictionary:
	return {"member":MEMBER,"source_sha256":SOURCE_SHA256,"source_bytes":147158,"origin":[ORIGIN.x,ORIGIN.y],"policy":POLICY,"native_placement_verified":false,"selector":"one vacant 64x64 Aden slot; no suffix interpretation","evidence":"highest categorical edge-family agreement among 126 vacant adjacent slots: 27/128; weak, not pixel continuity","neighbor":"Map/Aden/800b7ff7.s32","native_portals_relocated":false}

static func candidate(member: String, metadata: Dictionary, enabled: bool) -> Variant:
	if not enabled or member!=MEMBER: return null
	if metadata.get("sha256")!=SOURCE_SHA256 or metadata.get("bytes")!=147158: return null
	return ORIGIN
