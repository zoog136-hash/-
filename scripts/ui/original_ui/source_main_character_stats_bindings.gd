extends RefCounted
## Existing owner totals in six original StatInfo pairs and optional DTH.
## Caller selects the original stats tab and owns its parent presentation.
const MEMBER = "UI/FloatingUi/CharacterInfo_StatInfo.csb"
const SHA256 = "75e7ad019977077a5e447bba55a5b6f7d15794ad0bca8807143dc275abba620c"
const FIELDS = ["str", "dex", "con", "int", "wis", "cha"]
const TITLES = [41968, 38220, 34444, 26948, 23200, 19460]
const VALUES = [41648, 37900, 34124, 26628, 22880, 19140]
const SOURCE_OFFSETS: Array[int] = [41968,41648,38220,37900,34444,34124,26948,26628,23200,22880,19460,19140]
const DTH_GROUP=15320
const DTH_TITLE=15712
const DTH_VALUE=15392

static func snapshot(owner: Object) -> Dictionary:
	if not is_instance_valid(owner): return _fail("source_character_stats_owner_required")
	# Both the existing side UI and HUD expose the actual character_state.
	var state: Variant = owner.get("character_state")
	if not state is Dictionary: return _fail("source_character_stats_owner_state_missing")
	var values: Dictionary = {}
	for field: String in FIELDS:
		if typeof(state.get(field)) != TYPE_INT:
			return {"ok":false,"code":"source_character_stats_actual_integer_required","field":field,"presentation_requires_hide":true}
		values[field] = state[field]
	# This exact current host field is produced by _effective_attribute("DTH").
	# Missing data is not zero, and LFE/elixir are not inferred from it.
	if typeof(state.get("combination_death_stat"))==TYPE_INT:values["dth"]=state.combination_death_stat
	return {"ok":true,"values":values,"value_basis":"existing owner.character_state integer totals"}

static func build(pack: RefCounted, owner: Object) -> Dictionary:
	var source: Dictionary = _active_source(pack)
	if not source.get("ok",false): return source
	var current: Dictionary = snapshot(owner)
	if not current.get("ok",false): return current
	var bindings: Dictionary = {}
	var scope: Array[int]=SOURCE_OFFSETS.duplicate()
	for index: int in range(FIELDS.size()):
		bindings[TITLES[index]] = {"role":"static_source_text"}
		bindings[VALUES[index]] = {"role":"source_text","text":str(current["values"][FIELDS[index]])}
	var dth_in_scope: bool=_dth_in_scope(pack)
	if dth_in_scope:
		scope.append_array([DTH_TITLE,DTH_VALUE])
		bindings[DTH_GROUP]={"visible":current["values"].has("dth")}
		bindings[DTH_TITLE]={"role":"static_source_text"}
		bindings[DTH_VALUE]={"role":"source_text","text":str(current["values"].get("dth",""))}
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":scope,"bindings":bindings,"values":current["values"],"value_basis":current.value_basis,"dth_source_connected":dth_in_scope and current["values"].has("dth"),"dth_value_basis":"existing owner.character_state.combination_death_stat from World._effective_attribute(DTH)","read_only":true,"partial_source_scene":true,"complete_screen_contract":false,"tab_selection_inferred":false,"unresolved_fields":["original_stats_tab_parent_selection_owned_by_caller","LFE_Elixir_detail_contracts","DTH omitted when original active scope or actual integer is unavailable"]}

static func refresh(scene: Node2D, owner: Object) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member") != MEMBER or not scene.has_method("set_bound_text"):
		return _fail("source_character_stats_original_scene_required")
	var pack: Variant = scene.get("source_pack")
	if not pack is RefCounted: return _fail("source_character_stats_original_pack_required")
	var source: Dictionary = _active_source(pack)
	if not source.get("ok",false): return source
	var nodes: Variant = scene.get("source_nodes")
	if not nodes is Dictionary: return _fail("source_character_stats_presented_nodes_missing")
	for offset: int in SOURCE_OFFSETS:
		if not nodes.has(offset): return _fail("source_character_stats_text_not_in_presented_scope")
	# Read all six before changing any text; absent values never display defaults.
	var current: Dictionary = snapshot(owner)
	if not current.get("ok",false): return current
	for index: int in range(FIELDS.size()):
		var result: Dictionary = scene.set_bound_text(VALUES[index],str(current["values"][FIELDS[index]]))
		if not result.get("ok",false): return result
	if _dth_in_scope(pack):
		var updated: Dictionary=scene.set_bound_text(DTH_VALUE,str(current["values"].get("dth","")))
		if updated.get("ok",false):updated=scene.set_bound_visible(DTH_GROUP,current["values"].has("dth"))
		if not updated.get("ok",false):return updated
	return {"ok":true,"values":current["values"],"read_only":true,"game_state_written":false,"partial_source_scene":true,"complete_screen_contract":false}

static func _active_source(pack: RefCounted) -> Dictionary:
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256:
		return _fail("source_character_stats_original_identity_mismatch")
	var tree: Dictionary = pack.scene(MEMBER)
	var missing: Array[int] = []
	for offset: int in SOURCE_OFFSETS:
		if _find(tree.get("nodeTree",{}),offset).is_empty(): missing.append(offset)
	if not missing.is_empty():
		return {"ok":false,"code":"source_character_stats_nodes_not_in_active_pack_scope","missing_source_offsets":missing,"presentation_requires_hide":true}
	for index: int in range(FIELDS.size()):
		var title: Dictionary = _find(tree.get("nodeTree",{}),TITLES[index])
		var value: Dictionary = _find(tree.get("nodeTree",{}),VALUES[index])
		if title.get("classname") != "Text" or title.get("options",{}).get("text") != FIELDS[index].to_upper() or value.get("classname") != "Text":
			return _fail("source_character_stats_original_text_role_mismatch")
	return {"ok":true}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset") == offset: return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary = _find(child,offset)
		if not found.is_empty(): return found
	return {}

static func _dth_in_scope(pack: RefCounted) -> bool:
	var tree: Dictionary=pack.scene(MEMBER)
	var group: Dictionary=_find(tree.get("nodeTree",{}),DTH_GROUP)
	var title: Dictionary=_find(group,DTH_TITLE)
	var value: Dictionary=_find(group,DTH_VALUE)
	return group.get("options",{}).get("nodeOptions",{}).get("name")=="Nd_Stat_Dth" and title.get("classname")=="Text" and title.get("options",{}).get("text")=="DTH" and value.get("classname")=="Text"

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"presentation_requires_hide":true}
