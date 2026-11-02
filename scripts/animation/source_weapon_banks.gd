extends RefCounted
## Select existing source action banks. This never draws or resizes a weapon.
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
const PATH="res://data/lineagem_base508/source_weapon_actions.json"
static var _data:Dictionary={}
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:_data=parsed
	return _data
static func local_type(value:String) -> int:
	return int(data().get("local_weapon_type_to_source",{}).get(value,-1))
static func select(record:Dictionary,root:String,context:Dictionary,consumer:String) -> Dictionary:
	var weapon:int=int(context.get("source_weapon_type",0))
	var status:Dictionary={"requested_weapon_type":weapon,"local_weapon_type":str(context.get("local_weapon_type","")),"state":"generic_source_unarmed_or_unspecified","M_client_equivalence_verified":false}
	var result:Dictionary={"record":record,"status":status}
	if consumer not in ["transform","sprite"] or weapon==0:return result
	if weapon<0:status.state="unsupported_local_weapon_type_generic_source_fallback";return result
	var actor:int=int(record.get("source_sprite_id",-1))
	var path:String=INSTALL.resolve_file(root,"weapon_banks/manifest.json")
	if not FileAccess.file_exists(path):status.state="weapon_bank_pack_not_installed_generic_source_fallback";return result
	var index:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not index is Dictionary or index.get("source_snapshot","")!="base508" or index.get("source_ListSprAction_sha256","")!=data().get("source_ListSprAction_sha256",""):status.state="weapon_bank_snapshot_mismatch_generic_source_fallback";return result
	var entry:Dictionary=index.get("records",{}).get(str(actor)+":"+str(weapon),{})
	if entry.is_empty():status.state="weapon_bank_not_supplied_generic_source_fallback";return result
	var relative:String=str(entry.get("path",""))
	if not INSTALL.safe_relative(relative):status.state="invalid_weapon_bank_path_generic_source_fallback";return result
	var patch_path:String=INSTALL.resolve_file(root,relative)
	if not FileAccess.file_exists(patch_path):status.state="weapon_bank_pixels_pending_generic_source_fallback";return result
	var patch:Variant=JSON.parse_string(FileAccess.get_file_as_string(patch_path))
	if not patch is Dictionary or patch.get("source_snapshot","")!="base508" or int(patch.get("source_sprite_id",-1))!=actor or int(patch.get("body_id",-1))!=int(record.get("body_id",-2)) or int(patch.get("source_weapon_type",-1))!=weapon:
		status.state="weapon_bank_identity_mismatch_generic_source_fallback";return result
	for code:String in patch.get("source_action_guards",{}):
		if str(record.get("source_actions",{}).get(code,{}).get("raw_body","")).sha256_text()!=str(patch.source_action_guards[code]):status.state="weapon_bank_raw_action_mismatch_generic_source_fallback";return result
	for role:String in ["idle","walk","attack"]:
		var track:Dictionary=patch.get("tracks",{}).get(role,{})
		var row:Dictionary=patch.get("source_action_rows",{}).get(role,{})
		var canonical_row:Dictionary=data().get("source_action_rows",{}).get(str(int(row.get("ID",-1))),{})
		var raw_action:Dictionary=record.get("source_actions",{}).get(str(int(row.get("ID",-1))),{})
		if canonical_row!=row or raw_action.is_empty() or str(raw_action.get("raw_body","")).sha256_text()!=str(track.get("source_raw_body","")).sha256_text():
			status.state="weapon_bank_source_row_mismatch_generic_source_fallback";return result
		if track.is_empty() or row.is_empty() or int(track.get("source_action_id",-1))!=int(row.get("ID",-2)) or int(row.get("WeaponType",-1))!=weapon:
			status.state="weapon_bank_action_mismatch_generic_source_fallback";return result
	var selected:Dictionary=record.duplicate(true)
	selected["tracks"]=patch.tracks.duplicate(true)
	selected["source_weapon_type"]=weapon
	status.state="selected_source_weapon_actions"
	status["source_actions"]={}
	for role:String in patch.tracks:status.source_actions[role]=int(patch.tracks[role].source_action_id)
	status["run_status"]="native_run_alias_selected" if patch.tracks.has("run") else "no_declared_weapon_run_alias; native_walk_is_not_a_run_track"
	result.record=selected
	return result
