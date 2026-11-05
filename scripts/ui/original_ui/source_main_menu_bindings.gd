extends RefCounted
## Exact original main-menu controls route into existing HUD/World entry points.
## No new menu layout, inventory ownership, skills or shop logic is implemented.
const MEMBER="UI/Main/Hud_TopMenu.csb"
const SHA256="0b0fd7d02b604924dfb1a16f9ef35d71c0e1cfd19e634028b72837499a75ae85"
const INVENTORY=31392
const SKILL=29848
const STORE=35008
const ALL=37304
const QUEST=27996
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
	if include_quest:
		roots.append(QUEST)
		roots.append(27336)
	var matches: Dictionary={}
	var selected: Array[int]=[]
	_collect_offsets(tree.nodeTree,roots,matches,selected,false)
	for offset: int in roots:
		if int(matches.get(offset,0))!=1:return {"ok":false,"code":"source_main_menu_core_node_not_unique","offset":offset}
	return {"ok":true,"source_node_offsets":selected,"partial_source_scene":true,"complete_screen_contract":false}

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
	for offset: int in [34596,29528]:bindings[offset]={"role":"static_source_text"}
	var buttons: Array[int]=[ALL,INVENTORY,SKILL,STORE]
	if include_quest:
		bindings[QUEST]={"role":"button","activate":Callable(self,"open_quests")}
		bindings[27336]={"role":"static_source_text"}
		buttons.append(QUEST)
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":scope.source_node_offsets,"bindings":bindings,"bound_button_offsets":buttons,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original_remaining_top_menu_modes_and_controls_excluded_from_scope","original_weight_penalty_post_paid_restart_contracts"]}

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
