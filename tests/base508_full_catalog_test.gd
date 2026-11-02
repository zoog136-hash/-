extends SceneTree
const CATALOG = preload("res://scripts/monsters/base508_authoritative_catalog.gd")
const ROSTER = preload("res://scripts/monsters/base508_source_roster.gd")
const VIEW = preload("res://scripts/monsters/base508_monster_view.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var data: Dictionary = CATALOG.data()
	var errors: Array = []
	if data.rows.size() != 9470 or data.models.size() != 2596: errors.append("Incomplete source-ID catalog")
	var ids: Dictionary = {}
	var contexts: int = 0
	for row: Dictionary in data.rows:
		if ids.has(int(row.npc_id)): errors.append("Duplicate source identity")
		ids[int(row.npc_id)] = true
		if bool(row.source_TestNPC) and CATALOG.enemy_eligible(int(row.npc_id), true): errors.append("Test actor enabled as enemy")
		if row.source_kind == "source_noncombat_npc_or_component" and CATALOG.enemy_eligible(int(row.npc_id), true): errors.append("Noncombat actor enabled as enemy")
		contexts += int(row.source_world_context_count)
	if not CATALOG.parse_key("lineagem_base508:npc:90:spawn:762:territory:558").has("npc_id"): errors.append("Exact source context key rejected")
	if not CATALOG.source_record("lineagem_base508:npc:90:spawn:762:territory:558").has("source_m_npc_id"): errors.append("Native context record unavailable")
	if not CATALOG.source_record("lineagem_base508:npc:90:spawn:762:territory:999999").is_empty(): errors.append("Foreign spawn link accepted")
	var manifest: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lineagem-monster-pack="): manifest = argument.trim_prefix("--lineagem-monster-pack=")
	var all_models: bool = "--all-source-models" in OS.get_cmdline_user_args()
	var loaded: int = 0
	if not manifest.is_empty():
		var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		var sampled: Dictionary = {}
		for row: Dictionary in data.rows:
			if row.literal_context_evidence.is_empty() or not pack.records.has(str(int(row.npc_id))): continue
			var variant: Dictionary = pack.records[str(int(row.npc_id))]
			var pair: Dictionary = variant.source_contexts[0]
			var variant_key: String = CATALOG.context_key(int(row.npc_id), int(pair.spawn_view_id), int(pair.territory_link_id))
			if not ROSTER.record(variant_key, manifest).is_empty(): errors.append("Contextual actor enabled without explicit opt-in")
			if ROSTER.record(variant_key, manifest, {"source_m_allow_contextual":true}).is_empty(): errors.append("Explicit contextual source record unavailable")
			break
		for key: String in pack.records:
			if not all_models and loaded >= 12: break
			var actor: Dictionary = pack.records[key]
			if not CATALOG.enemy_eligible(int(key)) or sampled.has(int(actor.sprite_id)): continue
			var pair: Dictionary = actor.source_contexts[0]
			var record: Dictionary = ROSTER.record(CATALOG.context_key(int(key), int(pair.spawn_view_id), int(pair.territory_link_id)), manifest)
			if record.is_empty(): errors.append("Source-ID factory failed: " + key); continue
			var view := VIEW.new()
			if not view.configure(record, manifest): errors.append("Source model failed: " + key)
			else:
				view.advance(0.1, "walk", 0, 0, false, false)
				view.advance(0.1, "attack", 7, 1, true, false)
				view.advance(0.1, "death", 2, 1, false, true)
				loaded += 1
			view.free()
			sampled[int(actor.sprite_id)] = true
	print("BASE508_FULL_CATALOG ", JSON.stringify({"registered":ids.size(),"models":data.models.size(),"exact_contexts":contexts,"loaded_monster_models":loaded,"errors":errors}))
	quit(0 if errors.is_empty() else 1)
