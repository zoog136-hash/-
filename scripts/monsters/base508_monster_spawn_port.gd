extends RefCounted
## Current source admission before actor setup. Pixels remain Sprite272-owned.
const BINDINGS=preload("res://scripts/monsters/base508_monster_bindings.gd")
const CONTEXT=preload("res://scripts/monsters/base508_monster_context.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const POLICY=preload("res://scripts/monsters/patch523_spawn_policy.gd")
const SELECTOR="res://scripts/monsters/current523_source_bank_selection.gd"
static var problem: String=""
static func apply(record: Dictionary,host_map_id: String) -> Dictionary:
	problem=""
	if not POLICY.marked(record):return record
	# Refresh an already explicit encounter tuple from the current original.
	# The stable encounter ID/host slot remains unchanged; no new spawn is made.
	if record.get("source_m_current523_final")!=true:
		var npc_id: int=int(record.get("source_m_npc_id",0));var view_id: int=int(record.get("source_m_spawn_view_id",0));var link_id: int=int(record.get("source_m_territory_link_id",0))
		var key: String="lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id,view_id,link_id]
		if record.get("sourceId")!=key:problem="current523_exact_encounter_tuple_required";return {}
		var refreshed: Dictionary=CONTEXT.record(npc_id,view_id,link_id,record)
		if refreshed.is_empty():problem="current523_source_context_unavailable";return {}
		refreshed["catalog_only"]=record.get("catalog_only",true)
		refreshed["source_m_host_placement"]=record.get("source_m_host_placement","")
		refreshed["source_m_asset_manifest_path"]=""
		record=refreshed
	# Missing current origin cannot re-enter old PACK.actor/VIEW.configure.
	if record.get("source_m_current523_final")!=true or record.get("source_m_definition_archive_sha256")!=SOURCE.SOURCE_SHA:
		problem="current523_source_roster_required";return {}
	var original: Dictionary=SOURCE.row("NpcClass",int(record.get("source_m_npc_id",0)))
	var held: Variant=record.get("source_m_original")
	if original.is_empty() or not held is Dictionary:return {}
	for field: String in original:
		if held.get(field)!=original[field]:problem="current523_npc_original_changed";return {}
	var admission: Dictionary=POLICY.admit(record,host_map_id)
	if not admission.get("ok",false) or not admission.get("applied",false):problem=str(admission.get("reason","current523_map_admission_required"));return {}
	if not ResourceLoader.exists(SELECTOR):problem="Sprite272 current523_source_bank_selection not integrated";return {}
	var selector: Resource=load(SELECTOR)
	if selector==null or not selector.has_method("select"):problem="Sprite272 source selection contract missing";return {}
	var selected: Variant=selector.call("select",admission.record,admission)
	if not selected is Dictionary or not selected.get("ok",false):problem=str(selected.get("reason","current523_source_bank_unavailable")) if selected is Dictionary else "current523_source_bank_result_invalid";return {}
	# Actual bank loading, frame access and actor clock belong to Sprite272.
	return admission.record
static func native(record: Dictionary) -> bool:
	return record.get("source")=="lineagem_base508" and record.get("source_m_current523_final")==true and record.get("source_m_definition_archive_sha256")==SOURCE.SOURCE_SHA
