extends RefCounted
## Read-only original default MD/AC values. World owns every calculation.
## No attack/defense mode selection, fallback value or button action is inferred.
const MEMBER="UI/Main/Hud_CharInfo.csb"
const SHA256="9532ebdf565004332c1a566ee9f7fbf839aaa580b2db3600a187633820c7d805"
const SOURCE_OFFSETS: Array[int]=[18508,18556,15324,15372]
const MD_TEXT=18556
const AC_TEXT=15372
const ATTACK_BUTTON=16680
const DEFENSE_BUTTON=12856

static func snapshot(hud: Object) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_primary_stats_existing_hud_required")
	var state: Variant=hud.get("character_state")
	if not state is Dictionary:return _fail("source_primary_stats_owner_state_missing")
	for key: String in ["melee_damage","ac"]:
		if typeof(state.get(key))!=TYPE_INT:return {"ok":false,"code":"source_primary_stats_actual_integer_required","field":key,"presentation_requires_hide":true}
	return {"ok":true,"melee_damage":state.melee_damage,"ac":state.ac}

static func build(pack: RefCounted, hud: Object) -> Dictionary:
	var source: Dictionary=_active_source(pack)
	if not source.get("ok",false):return source
	var values: Dictionary=snapshot(hud)
	if not values.get("ok",false):return values
	var bindings: Dictionary={
		MD_TEXT:{"role":"source_text","text":str(values.melee_damage)},
		AC_TEXT:{"role":"source_text","text":str(values.ac)},
		ATTACK_BUTTON:{"role":"button","displaystate":false,"activate":Callable()},
		DEFENSE_BUTTON:{"role":"button","displaystate":false,"activate":Callable()}
	}
	# The four actual default-visible source nodes and their existing button
	# ancestors only. RD/SP/MR/DR/PDR remain outside this explicit scope.
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":bindings,"values":values,"value_basis":"existing hud.character_state.melee_damage/ac integers","partial_source_scene":true,"complete_screen_contract":false,"read_only":true,"button_actions_connected":false,"unconnected_controls":[{"offset":ATTACK_BUTTON,"field":"original_attack_button_action_and_mode_selection"},{"offset":DEFENSE_BUTTON,"field":"original_defense_button_action_and_mode_selection"}],"unresolved_fields":["original_RD_SP_MR_DR_PDR_selection_contracts"]}

static func refresh(scene: Node2D, hud: Object) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MEMBER or not scene.has_method("set_bound_text"):return _fail("source_primary_stats_original_scene_required")
	var pack: Variant=scene.get("source_pack")
	if not pack is RefCounted:return _fail("source_primary_stats_original_pack_required")
	var source: Dictionary=_active_source(pack)
	if not source.get("ok",false):return source
	var nodes: Variant=scene.get("source_nodes")
	if not nodes is Dictionary or not nodes.has(MD_TEXT) or not nodes.has(AC_TEXT):return _fail("source_primary_stats_text_not_in_presented_scope")
	var values: Dictionary=snapshot(hud)
	if not values.get("ok",false):return values
	var result: Dictionary=scene.set_bound_text(MD_TEXT,str(values.melee_damage))
	if not result.get("ok",false):return result
	result=scene.set_bound_text(AC_TEXT,str(values.ac))
	if not result.get("ok",false):return result
	return {"ok":true,"values":values,"read_only":true,"button_actions_connected":false,"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}

static func _active_source(pack: RefCounted) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_primary_stats_original_identity_mismatch")
	# scene() is the activated permitted scope. A full layout_source record
	# does not authorize widening the existing smaller v6 runtime scene.
	var tree: Dictionary=pack.scene(MEMBER)
	var missing: Array[int]=[]
	for offset: int in SOURCE_OFFSETS:
		if _find(tree.get("nodeTree",{}),offset).is_empty():missing.append(offset)
	if not missing.is_empty():return {"ok":false,"code":"source_primary_stats_nodes_not_in_active_pack_scope","missing_source_offsets":missing,"presentation_requires_hide":true}
	return {"ok":true}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_find(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"presentation_requires_hide":true}
