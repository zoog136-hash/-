extends RefCounted
## Original controls emit the existing HUD input signals. World retains attack
## timing, target selection, auto AI, restrictions and all game-state writes.
const ROOTS={
 "UI/Main/Set_R_Bot_Btn_Attack.csb":{"sha256":"fa7b08ed9b08cb4f67e2374ad113e1b086671b6b5ea0e8bfc00836b2e8d87088","attack":1624,"auto":868,"auto_effect":180},
 "UI/Main/Set_R_Bot_Btn_AutoAttack.csb":{"sha256":"34e54e853bdf38b8f7d1982eafb90b0825d5daa938e383463bbe597b1f1dd445","attack":1892,"auto":1124,"auto_effect":180},
 "UI/Main/Hud_AttackPad.csb":{"sha256":"6bdfa6c16b65f1b7f76b440aa6c8c3459686616238e4634941d7b7a10e48903a","attack":31780,"auto":29032,"auto_effect":12660}
}
const PAD="UI/Main/Hud_AttackPad.csb"
const MAIN="UI/MainScene.csb"
const MAIN_SHA="80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f"
const CLICK_PROJECTS=[9912,9640,9368,9096,8824,8552,8276,8004]
var _pack: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _core_availability: Dictionary={}

func configure(pack: RefCounted, hud: Node, world: Node) -> Dictionary:
	if not is_instance_valid(hud) or not is_instance_valid(world):return _fail("source_main_combat_host_unavailable")
	for signal_name: String in ["attack_pressed","auto_pressed","target_pressed","self_mode_changed"]:
		if not hud.has_signal(signal_name):return {"ok":false,"code":"source_main_combat_hud_signal_missing","signal":signal_name}
	_pack=pack
	_hud=weakref(hud)
	_world=weakref(world)
	return snapshot()

func snapshot() -> Dictionary:
	var world: Object=_world.get_ref() if _world!=null else null
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if world==null or hud==null:return _fail("source_main_combat_host_unavailable")
	var player: Variant=world.get("player")
	if not is_instance_valid(player) or not player.get("auto_enabled") is bool or not world.get("self_mode_enabled") is bool:return _fail("source_main_combat_state_unavailable")
	return {"ok":true,"auto_enabled":player.get("auto_enabled"),"self_mode_enabled":world.get("self_mode_enabled")}

func build(member: String, remaining: Dictionary={}) -> Dictionary:
	if not ROOTS.has(member):return _fail("source_main_combat_member_unknown")
	var root: Dictionary=ROOTS[member]
	if _pack==null or _pack.manifest.get("files",{}).get(member,{}).get("sha256","")!=root.sha256:return _fail("source_main_combat_identity_mismatch")
	var state: Dictionary=snapshot()
	if not state.get("ok",false):return state
	var bindings: Dictionary=remaining.duplicate(true)
	bindings[root.attack]={"role":"button","activate":Callable(self,"attack")}
	bindings[root.auto]={"role":"button","activate":Callable(self,"toggle_auto")}
	_set_visible_binding(bindings,int(root.auto_effect),state.auto_enabled)
	var unresolved: Array=[]
	if member==PAD:
		# Actual source controls. TrueTarget/Enemy/Link are separate original
		# actions and must not be silently treated as ordinary target selection.
		bindings[24560]={"role":"button","activate":Callable(self,"select_target")}
		bindings[22536]={"role":"button","activate":Callable(self,"toggle_self")}
		_set_visible_binding(bindings,23168,state.self_mode_enabled)
		for offset: int in CLICK_PROJECTS:
			if not bindings.has(offset):bindings[offset]={"role":"project","bindings":{}}
		for offset: int in [16156,15084]:
			if not bindings.has(offset):bindings[offset]={"role":"static_source_text"}
		unresolved=[
			{"field":"original_auto_and_target_control_container_visibility","offsets":[28976,24496]},
			{"field":"existing_manual_pickup_requires_selected_ground_drop","offset":30208,"existing_handler":"World._on_ground_drop_clicked(drop:Button)","missing_contract":"original_pickup_button_to_exact_ground_drop_selection"},
			{"field":"original_dungeon_enemy_true_target_link_actions","offsets":[27844,26368,20068,17556,16108,15036,13856]},
			{"field":"original_attack_style_and_click_effect_lifecycle"}
		]
	return {"ok":true,"member":member,"sha256":root.sha256,"bindings":bindings,"state":state,"unresolved_fields":unresolved,"complete_screen_contract":false}

func core_source_offsets() -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(PAD,{}).get("sha256","")!=ROOTS[PAD].sha256:return _fail("source_main_combat_identity_mismatch")
	var tree: Dictionary=_pack.call("layout_source",PAD) if _pack.has_method("layout_source") else _pack.scene(PAD)
	if not tree.get("nodeTree") is Dictionary:return _fail("source_main_combat_original_layout_missing")
	var roots: Array[int]=[31780,29032,24560,22536,12660,23168]
	var matches: Dictionary={}
	var selected: Array[int]=[]
	_collect_core_offsets(tree.nodeTree,roots,matches,selected,false)
	for offset: int in roots:
		if int(matches.get(offset,0))!=1:return {"ok":false,"code":"source_main_combat_core_node_not_unique","offset":offset}
	return {"ok":true,"source_node_offsets":selected,"core_root_offsets":roots,"partial_source_scene":true,"complete_screen_contract":false}

func build_core(availability: Dictionary, remaining: Dictionary={}) -> Dictionary:
	for key: String in ["attack","auto","target","self"]:
		if not availability.get(key) is bool:return {"ok":false,"code":"source_main_combat_host_availability_required","field":key}
	var scope: Dictionary=core_source_offsets()
	if not scope.get("ok",false):return scope
	var built: Dictionary=build(PAD,remaining)
	if not built.get("ok",false):return built
	var bindings: Dictionary={}
	# Only bindings within the chosen native subtree roots survive. Ancestor
	# transforms remain original; caller supplies availability, not client modes.
	for offset: int in scope.source_node_offsets:
		if built.bindings.has(offset):bindings[offset]=built.bindings[offset].duplicate(true)
	for pair: Array in [[31376,"attack"],[28976,"auto"],[24496,"target"],[22476,"self"]]:
		_set_visible_binding(bindings,int(pair[0]),availability[pair[1]])
	_set_visible_binding(bindings,12660,built.state.auto_enabled and availability.auto)
	_set_visible_binding(bindings,23168,built.state.self_mode_enabled and availability.self)
	_core_availability=availability.duplicate(true)
	return {"ok":true,"member":PAD,"sha256":ROOTS[PAD].sha256,"source_node_offsets":scope.source_node_offsets,"bindings":bindings,"state":built.state,"host_control_availability":availability.duplicate(true),"availability_basis":"existing_game_host_control_visibility","partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original_client_mode_switch_contracts","pickup_and_special_actions_excluded_from_scope","original_effect_animation_start_stop_contract"]}

static func _collect_core_offsets(node: Dictionary, roots: Array[int], matches: Dictionary, selected: Array[int], inside: bool) -> void:
	var offset: int=int(node.get("_offset",-1))
	if offset in roots:matches[offset]=int(matches.get(offset,0))+1
	var retain: bool=inside or offset in roots
	if retain and offset not in selected:selected.append(offset)
	for child: Dictionary in node.get("children",[]):_collect_core_offsets(child,roots,matches,selected,retain)

func main_project_binding(remaining_pad: Dictionary={}) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MAIN,{}).get("sha256","")!=MAIN_SHA:return _fail("source_main_scene_identity_mismatch")
	var pad: Dictionary=build(PAD,remaining_pad)
	if not pad.get("ok",false):return pad
	# Root ProjectNode 19912 owns original placement, transform and child scope.
	# Hud_AttackPad references click effects, not the two Set button components.
	return {"ok":true,"offset":19912,"binding":{"role":"project","bindings":pad.bindings},"child_contract":pad,"complete_screen_contract":false}

func refresh_presented(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or not scene.has_method("set_bound_visible"):return _fail("source_main_combat_scene_unavailable")
	var member: String=str(scene.get("source_member"))
	if not ROOTS.has(member):return _fail("source_main_combat_member_unknown")
	var state: Dictionary=snapshot()
	if not state.get("ok",false):return state
	var auto_visible: bool=state.auto_enabled
	var self_visible: bool=state.self_mode_enabled
	if member==PAD and not _core_availability.is_empty():
		auto_visible=auto_visible and bool(_core_availability.auto)
		self_visible=self_visible and bool(_core_availability.self)
	var result: Dictionary=scene.set_bound_visible(int(ROOTS[member].auto_effect),auto_visible)
	if not result.get("ok",false):return result
	if member==PAD:
		result=scene.set_bound_visible(23168,self_visible)
		if not result.get("ok",false):return result
	return {"ok":true,"state":state}

func attack() -> Dictionary:
	return _emit_input("attack_pressed")

func toggle_auto() -> Dictionary:
	# World's existing signal connection performs set_auto_enabled(!current).
	return _emit_input("auto_pressed")

func select_target() -> Dictionary:
	return _emit_input("target_pressed")

func toggle_self() -> Dictionary:
	var state: Dictionary=snapshot()
	if not state.get("ok",false):return state
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_main_combat_host_unavailable")
	hud.emit_signal("self_mode_changed",not state.self_mode_enabled)
	return {"ok":true,"emitted":true,"signal":"self_mode_changed","action_result_known":false}

func _emit_input(signal_name: String) -> Dictionary:
	var state: Dictionary=snapshot()
	if not state.get("ok",false):return state
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_main_combat_host_unavailable")
	hud.emit_signal(signal_name)
	return {"ok":true,"emitted":true,"signal":signal_name,"action_result_known":false}

static func _set_visible_binding(bindings: Dictionary, offset: int, value: bool) -> void:
	var binding: Dictionary=bindings.get(offset,{}).duplicate(true)
	binding.visible=value
	bindings[offset]=binding

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
