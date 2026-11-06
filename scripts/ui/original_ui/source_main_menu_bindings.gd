extends RefCounted
## Exact original main-menu controls route into existing HUD/World entry points.
## No new menu layout, inventory ownership, skills or shop logic is implemented.
const MEMBER="UI/Main/Hud_TopMenu.csb"
const SHA256="0b0fd7d02b604924dfb1a16f9ef35d71c0e1cfd19e634028b72837499a75ae85"
const INVENTORY=31392
const SKILL=29848
const STORE=35008
const ALL=37304
const ALL_OFF=36572
const QUEST=27996
const WEIGHT_TEXT=32360
const WEIGHT_BACKGROUND=33104
const CORE_ROOT_OFFSETS: Array[int]=[37304,31392,29848,35008,34596,29528]
var _pack: RefCounted
var _hud: WeakRef

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_main_menu_hud_unavailable")
	if not hud.has_signal("inventory_pressed") or not hud.has_method("open_skills") or not hud.has_method("open_shop"):return _fail("source_main_menu_existing_hud_api_missing")
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_menu_identity_mismatch")
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true}

func build(remaining: Dictionary={}) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_menu_identity_mismatch")
	if _live_hud()==null:return _fail("source_main_menu_hud_unavailable")
	var bindings: Dictionary=remaining.duplicate(true)
	bindings[INVENTORY]={"role":"button","activate":Callable(self,"open_inventory")}
	bindings[SKILL]={"role":"button","activate":Callable(self,"open_skills")}
	bindings[STORE]={"role":"button","activate":Callable(self,"open_shop")}
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"bindings":bindings,"bound_button_offsets":[INVENTORY,SKILL,STORE],"unresolved_fields":["remaining_original_top_menu_controls_and_display_roles"],"complete_screen_contract":false}

func core_source_offsets(include_quest: bool=true) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_menu_identity_mismatch")
	var tree: Dictionary=_pack.call("layout_source",MEMBER) if _pack.has_method("layout_source") else _pack.scene(MEMBER)
	if tree.is_empty():tree=_pack.scene(MEMBER)
	if not tree.get("nodeTree") is Dictionary:return _fail("source_main_menu_original_layout_missing")
	var roots: Array[int]=CORE_ROOT_OFFSETS.duplicate()
	var menu_variant: Dictionary=menu_variant_state() if _active_source_node(ALL_OFF) else {"ok":false}
	if menu_variant.get("ok",false):roots.append(ALL_OFF)
	if include_quest:
		roots.append(QUEST)
		roots.append(27336)
	# An older partial pack has no weight text in its activated source scope.
	# It must continue to build the same functioning core buttons unchanged.
	var weight: Dictionary={"ok":false,"code":"source_main_menu_weight_not_in_pack_scope"}
	if _active_source_node(WEIGHT_TEXT):
		weight=_weight_display()
		if weight.get("ok",false):
			roots.append(WEIGHT_TEXT)
			if _active_source_node(WEIGHT_BACKGROUND):roots.append(WEIGHT_BACKGROUND)
	var matches: Dictionary={}
	var selected: Array[int]=[]
	_collect_offsets(tree.nodeTree,roots,matches,selected,false)
	for offset: int in roots:
		if int(matches.get(offset,0))!=1:return {"ok":false,"code":"source_main_menu_core_node_not_unique","offset":offset}
	return {"ok":true,"source_node_offsets":selected,"optional_weight":weight,"menu_variant":menu_variant,"partial_source_scene":true,"complete_screen_contract":false}

func build_core(include_quest: bool=true, remaining: Dictionary={}) -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_main_menu_hud_unavailable")
	if not hud.has_signal("menu_pressed"):return _fail("source_main_menu_existing_menu_signal_missing")
	if include_quest and not hud.has_method("open_quests"):return _fail("source_main_menu_existing_quest_method_missing")
	var scope: Dictionary=core_source_offsets(include_quest)
	if not scope.get("ok",false):return scope
	var built: Dictionary=build(remaining)
	if not built.get("ok",false):return built
	var bindings: Dictionary={}
	for offset: int in scope.source_node_offsets:
		if built.bindings.has(offset):bindings[offset]=built.bindings[offset].duplicate(true)
	bindings[ALL]={"role":"button","activate":Callable(self,"open_menu")}
	if scope.menu_variant.get("ok",false):
		bindings[ALL]={"role":"button","activate":Callable(self,"toggle_presented_menu").bind(false),"visible":not scope.menu_variant.open}
		bindings[ALL_OFF]={"role":"button","activate":Callable(self,"toggle_presented_menu").bind(true),"visible":scope.menu_variant.open}
	for offset: int in [34596,29528]:bindings[offset]={"role":"static_source_text"}
	if scope.optional_weight.get("ok",false):bindings[WEIGHT_TEXT]={"role":"source_text","text":scope.optional_weight.text,"visible":true}
	var buttons: Array[int]=[ALL,INVENTORY,SKILL,STORE]
	if scope.menu_variant.get("ok",false):buttons.append(ALL_OFF)
	if include_quest:
		bindings[QUEST]={"role":"button","activate":Callable(self,"open_quests")}
		bindings[27336]={"role":"static_source_text"}
		buttons.append(QUEST)
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":scope.source_node_offsets,"bindings":bindings,"bound_button_offsets":buttons,"optional_weight":scope.optional_weight,"weight_connected":scope.optional_weight.get("ok",false),"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original_remaining_top_menu_modes_and_controls_excluded_from_scope","original_weight_gauge_fill_penalty_post_paid_restart_contracts"]}

func refresh_presented(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MEMBER:return _fail("source_main_menu_scene_mismatch")
	var variant: Dictionary=refresh_menu_variant(scene)
	if not variant.get("ok",false):return variant
	var nodes: Variant=scene.get("source_nodes")
	if not nodes is Dictionary or not nodes.has(WEIGHT_TEXT):return {"ok":true,"weight_connected":false,"code":"source_main_menu_weight_not_in_presented_scope"}
	var weight: Dictionary=_weight_display()
	if not weight.get("ok",false):
		# Do not leave a last value or serialized 88% as current information.
		if scene.has_method("set_bound_visible"):scene.set_bound_visible(WEIGHT_TEXT,false)
		return {"ok":true,"weight_connected":false,"unresolved_weight":weight}
	var updated: Dictionary=scene.set_bound_text(WEIGHT_TEXT,weight.text)
	if not updated.get("ok",false):return updated
	updated=scene.set_bound_visible(WEIGHT_TEXT,true)
	if not updated.get("ok",false):return updated
	return {"ok":true,"weight_connected":true,"weight_display":weight,"complete_screen_contract":false}

func menu_variant_state() -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_main_menu_hud_unavailable")
	var workspace: Variant=hud.get("workspace")
	var section: Variant=hud.get("active_section")
	if not workspace is Control or not is_instance_valid(workspace) or not section is String:return _fail("source_main_menu_existing_workspace_state_required")
	return {"ok":true,"open":section=="menu" and workspace.visible}

func refresh_menu_variant(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MEMBER:return _fail("source_main_menu_scene_mismatch")
	if not scene.get("source_nodes").has(ALL_OFF):return {"ok":true,"menu_variant_connected":false}
	var state: Dictionary=menu_variant_state()
	for offset: int in [ALL,ALL_OFF]:
		var visible: bool=state.get("ok",false) and (bool(state.get("open",false)) if offset==ALL_OFF else not bool(state.get("open",false)))
		var node: Variant=scene.get("source_nodes").get(offset)
		if not is_instance_valid(node):return _fail("source_main_menu_original_variant_node_required")
		if node.visible==visible:continue
		var changed: Dictionary=scene.set_bound_visible(offset,visible)
		if not changed.get("ok",false):return changed
	return {"ok":state.get("ok",false),"menu_variant_connected":state.get("ok",false),"state":state}

func toggle_presented_menu(expected_open: bool) -> Dictionary:
	var state: Dictionary=menu_variant_state()
	if not state.get("ok",false) or state.open!=expected_open:return _fail("source_main_menu_presented_variant_changed")
	return open_menu()

func presented_close_button(scene: Node2D) -> Variant:
	var state: Dictionary=menu_variant_state()
	if not state.get("ok",false) or not state.open or not is_instance_valid(scene) or scene.get("source_member")!=MEMBER:return null
	var node: Variant=scene.get("source_nodes").get(ALL_OFF)
	return node.get_meta("source_button",null) if is_instance_valid(node) and node.is_visible_in_tree() else null

func _weight_display() -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_main_menu_hud_unavailable")
	var bag: Variant=hud.get("lineage_inventory_ui")
	if not is_instance_valid(bag) or not bag.has_method("_refresh_weight"):return _fail("source_main_menu_existing_weight_formatter_missing")
	var state: Variant=bag.get("character_state")
	if not state is Dictionary or not _actual_number(state.get("current_weight")):return _fail("source_main_menu_current_weight_not_supplied")
	var capacity: Variant=state.get("max_weight",state.get("carrying_capacity"))
	if not _actual_number(capacity):return _fail("source_main_menu_weight_capacity_not_supplied")
	var readout: Variant=bag.get("weight_readout")
	var label: Variant=bag.get("capacity_label")
	if not is_instance_valid(readout) or not readout is Label or not is_instance_valid(label) or not label is Label:return _fail("source_main_menu_existing_weight_display_missing")
	# This is the existing owner's actual formatter and rounded percentage.
	# Its capacity label contract is '%d%% · <existing slot capacity>'. No
	# UI-owned ratio, clamp, weight units or penalty thresholds are added.
	bag.call("_refresh_weight")
	var text: String=label.text.get_slice(" · ",0)
	if not text.ends_with("%") or not text.trim_suffix("%").is_valid_int():return _fail("source_main_menu_existing_weight_percent_not_formatted")
	return {"ok":true,"text":text,"basis":"lineage_inventory_ui._refresh_weight capacity_label rounded-percent prefix","existing_readout":readout.text,"source_offset":WEIGHT_TEXT,"penalty_connected":false,"gauge_fill_connected":false}

func _active_source_node(offset: int) -> bool:
	# scene(), unlike layout_source(), is the actual permitted partial scope.
	var active: Dictionary=_pack.scene(MEMBER)
	return not _source_node(active.get("nodeTree",{}),offset).is_empty()

static func _source_node(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_source_node(child,offset)
		if not found.is_empty():return found
	return {}

static func _actual_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _collect_offsets(node: Dictionary, roots: Array[int], matches: Dictionary, selected: Array[int], inside: bool) -> void:
	var offset: int=int(node.get("_offset",-1))
	if offset in roots:matches[offset]=int(matches.get(offset,0))+1
	var retain: bool=inside or offset in roots
	if retain and offset not in selected:selected.append(offset)
	for child: Dictionary in node.get("children",[]):_collect_offsets(child,roots,matches,selected,retain)

func open_menu() -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null or not hud.has_signal("menu_pressed"):return _fail("source_main_menu_existing_menu_signal_missing")
	hud.emit_signal("menu_pressed")
	return {"ok":true,"emitted":true,"signal":"menu_pressed","action_result_known":false}

func open_quests() -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null or not hud.has_method("open_quests"):return _fail("source_main_menu_existing_quest_method_missing")
	return _open_existing("open_quests")

func open_inventory() -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_main_menu_hud_unavailable")
	# Existing World inventory_pressed connection owns its normal entry flow.
	hud.emit_signal("inventory_pressed")
	return {"ok":true,"emitted":true,"signal":"inventory_pressed","action_result_known":false}

func open_skills() -> Dictionary:
	return _open_existing("open_skills")

func open_shop() -> Dictionary:
	return _open_existing("open_shop")

func _open_existing(method: String) -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_main_menu_hud_unavailable")
	hud.call(method)
	return {"ok":true,"dispatched":true,"method":method,"action_result_known":false}

func _live_hud() -> Object:
	return _hud.get_ref() if _hud!=null else null

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
