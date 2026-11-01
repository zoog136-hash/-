extends RefCounted
## Author-selected source replacements for exact legacy slots. This is an explicit
## host placement adaptation, not an assertion that old PC/M NPC IDs are identical.
const CONTEXT = preload("res://scripts/monsters/base508_monster_context.gd")
const PATH = "res://data/lineagem_base508/monster_bindings.json"
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary: _data = value
	return _data
static func pack_manifest() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lineagem-monster-pack="): return argument.trim_prefix("--lineagem-monster-pack=")
	var path: String = preload("res://scripts/lineagem_pack_install.gd").active_root().path_join("monsters/manifest.json")
	if FileAccess.file_exists(path): return path
	return "user://lineagem_base508_monsters/manifest.json"
static func apply(record: Dictionary, map_id: String, explicit_manifest: String = "") -> Dictionary:
	var manifest_path: String = explicit_manifest if not explicit_manifest.is_empty() else pack_manifest()
	if not FileAccess.file_exists(manifest_path): return record
	var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not pack is Dictionary or pack.get("kind", "") != "base508_monster_pack" or pack.get("source_snapshot", "") != "base508": return record
	for binding: Dictionary in data().get("bindings", []):
		if str(binding.host_map_id) != map_id: continue
		# Full declared slot signature + exact source context; never a display-name join.
		var matches: bool = true
		for key: String in binding.legacy_signature:
			if record.get(key) != binding.legacy_signature[key]: matches = false
		if not matches: continue
		var actor: Dictionary = pack.get("records", {}).get(str(int(binding.npc_id)), {})
		if int(actor.get("sprite_id", -1)) != int(binding.sprite_id) or int(actor.get("spawn_view_id", -1)) != int(binding.spawn_view_id) or int(actor.get("territory_link_id", -1)) != int(binding.territory_link_id): continue
		var replacement: Dictionary = CONTEXT.record(int(binding.npc_id), int(binding.spawn_view_id), int(binding.territory_link_id), record)
		if replacement.is_empty(): return record
		if int(replacement.source_m_context.land.ID) != int(binding.land_id): return record
		replacement["catalog_only"] = false
		replacement["source_m_asset_manifest_path"] = manifest_path
		replacement["source_m_pixel_status"] = "private_manifest_selected; renderer_verifies_all_pixel_hashes"
		replacement["source_m_host_placement"] = binding.placement_contract
		replacement["source_m_bound_legacy_slot"] = int(binding.legacy_game_db_index)
		return replacement
	return record
