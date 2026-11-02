extends RefCounted
## Resolve before legacy level variants/portrait loading. Never rescale native HP.
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
const VIEW = preload("res://scripts/monsters/base508_monster_view.gd")
static func apply(record: Dictionary, host_map_id: String) -> Dictionary:
	var candidate: Dictionary = BINDINGS.apply(record, host_map_id)
	if not candidate.has("source_m_asset_manifest_path"): return record
	var view := VIEW.new()
	var ready: bool = view.configure(candidate, str(candidate.source_m_asset_manifest_path))
	view.free()
	if ready: return candidate
	# A new source ID has no fabricated legacy counterpart to fall back to.
	return {} if record.get("source", "") == "lineagem_base508" else record
static func native(record: Dictionary) -> bool:
	return record.get("source", "") == "lineagem_base508" and record.has("source_m_asset_manifest_path")
