extends RefCounted
## Presentation math matches renewal_hud.update_player; no progression or
## reward processing. Original LoadingBar applies its own native clipping.
const EXP_MEMBER="UI/Main/Hud_ExpBar.csb"
const EXP_SHA256="af872f74f183897d2704723811378c39434a78d2bde0a9f98fba4ddbab1e3c8e"
const EXP_BAR=2572
const EXP_PERCENT_TEXT=2160
const EXP_TITLE=1804
const EXP_REWARD_PANEL=1408
const EXP_REWARD_BUTTON=164
const CHAR_MEMBER="UI/Main/Hud_CharInfo.csb"
const CHAR_SHA256="9532ebdf565004332c1a566ee9f7fbf839aaa580b2db3600a187633820c7d805"
const POISON_BAR=39796
const CLASS_MEMBER="UI/Main/Hud_CharInfo_Class.csb"
const CLASS_SHA256="5aeced078ab2c0323d3eeacf354856f85d95027c818d68924c68c1528c48e316"
const CLASS_PROJECT=34940
const CLASS_LEVEL=7528
const CLASS_LEVEL_OFFSETS: Array[int]=[8304,7528]
# Ancestors are retained automatically. Selected bars do not pull in trail,
# poison or other children. MP's actual text is selected independently.
const CHAR_NODE_OFFSETS: Array[int]=[46576,40620,37172,35464,35528,20552,20060]

class HudInput extends RefCounted:
	var host: WeakRef
	func open_character() -> Dictionary:
		var hud: Object=host.get_ref() if host!=null else null
		if hud==null or not hud.has_method("open_character"):return {"ok":false,"code":"source_main_hud_unavailable"}
		hud.call("open_character")
		return {"ok":true,"dispatched":true,"method":"open_character","action_result_known":false}
	func open_inventory() -> Dictionary:
		var hud: Object=host.get_ref() if host!=null else null
		if hud==null or not hud.has_signal("inventory_pressed"):return {"ok":false,"code":"source_main_hud_unavailable"}
		hud.emit_signal("inventory_pressed")
		return {"ok":true,"emitted":true,"signal":"inventory_pressed","action_result_known":false}

static func build_exp(pack: RefCounted, experience_value: int, exp_need: int) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(EXP_MEMBER,{}).get("sha256","")!=EXP_SHA256:return _fail("source_main_exp_identity_mismatch")
	var percent: float=float(experience_value)*100/maxi(1,exp_need)
	var bindings: Dictionary={
		EXP_BAR:{"role":"source_percent","percent":percent},
		EXP_PERCENT_TEXT:{"role":"source_text","text":"%.2f%%" % percent},
		EXP_TITLE:{"role":"static_source_text"},
		# Serialized touch-enabled reward background consumes its own touch;
		# there is no existing game action to dispatch from this source panel.
		EXP_REWARD_PANEL:{"role":"consume"},
		EXP_REWARD_BUTTON:{"role":"button","displaystate":false,"visible":false,"activate":Callable()}
	}
	return {"ok":true,"member":EXP_MEMBER,"sha256":EXP_SHA256,"bindings":bindings,"percent":percent,"unavailable_actions":[{"offset":EXP_REWARD_BUTTON,"code":"existing_exp_reward_action_unavailable","source_visible":false}],"complete_component_contract":true,"complete_screen_contract":false}

static func refresh_exp(scene: Node2D, experience_value: int, exp_need: int) -> Dictionary:
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=EXP_MEMBER:return _fail("source_main_exp_scene_mismatch")
	if not scene.has_method("set_bound_percent") or not scene.has_method("set_bound_text"):return _fail("source_main_exp_scene_binding_api_missing")
	var pack: Variant=scene.get("source_pack")
	if pack==null or pack.manifest.get("files",{}).get(EXP_MEMBER,{}).get("sha256","")!=EXP_SHA256:return _fail("source_main_exp_identity_mismatch")
	var percent: float=float(experience_value)*100/maxi(1,exp_need)
	var result: Dictionary=scene.set_bound_text(EXP_PERCENT_TEXT,"%.2f%%" % percent)
	if not result.get("ok",false):return result
	result=scene.set_bound_percent(EXP_BAR,percent)
	if not result.get("ok",false):return result
	return {"ok":true,"percent":percent,"game_state_written":false}

static func build_char_info(pack: RefCounted, hud: Node, values: Dictionary) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(CHAR_MEMBER,{}).get("sha256","")!=CHAR_SHA256:return _fail("source_main_char_info_identity_mismatch")
	if not is_instance_valid(hud) or not hud.has_method("open_character") or not hud.has_signal("inventory_pressed"):return _fail("source_main_char_info_existing_hud_api_missing")
	var presented: Dictionary=_char_values(values)
	if not presented.get("ok",false):return presented
	var inputs=HudInput.new()
	inputs.host=weakref(hud)
	var bindings: Dictionary={
		40620:{"role":"source_percent","percent":presented.hp_percent},
		37172:{"role":"source_text","text":presented.hp_text},
		35464:{"role":"source_percent","percent":presented.mp_percent},
		35528:{"role":"source_text","text":presented.mp_text},
		# A Callable does not keep its RefCounted target alive: the lambdas
		# hold `inputs` for as long as the mounted buttons hold them.
		20552:{"role":"button","activate":func() -> Dictionary: return inputs.open_character()},
		20060:{"role":"button","activate":func() -> Dictionary: return inputs.open_inventory()}
	}
	var offsets: Array[int]=CHAR_NODE_OFFSETS.duplicate()
	if pack.manifest.get("node_scopes",{}).get(CHAR_MEMBER,[]).has(POISON_BAR):
		var poison: Dictionary=_poison_state(hud)
		if poison.get("ok",false):
			offsets.append(POISON_BAR)
			bindings[POISON_BAR]={"role":"source_percent","percent":presented.hp_percent,"visible":poison.active,"stock_custom_property_metadata":" Red:#D80900 Sky:#29D6FF gray:#7F7F7F"}
	# Older, smaller explicit packs remain usable. A supplied native level
	# subset uses the original serialized normal branch; no class portrait or
	# myth/sole state is inferred from the level value.
	if pack.manifest.get("files",{}).get(CLASS_MEMBER,{}).get("sha256","")==CLASS_SHA256 and pack.manifest.get("node_scopes",{}).get(CHAR_MEMBER,[]).has(CLASS_PROJECT):
		if typeof(values.get("level"))!=TYPE_INT:return _fail("source_main_raw_level_required")
		offsets.append(CLASS_PROJECT)
		bindings[CLASS_PROJECT]={"role":"project","source_node_offsets":CLASS_LEVEL_OFFSETS.duplicate(),"bindings":{CLASS_LEVEL:{"role":"source_text","text":str(values.level)}}}
	return {"ok":true,"member":CHAR_MEMBER,"sha256":CHAR_SHA256,"source_node_offsets":offsets,"bindings":bindings,"values":presented,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":[{"offset":37544,"field":"original_clipping_custom_property","source_property":"clipping","source_value":0.5,"included_in_scope":false},"original_hp_delta_trail_timing","original_poison_weight_lawful_and_other_stat_roles","class_portrait_and_rank_branch_selection"]}

static func refresh_char_info(scene: Node2D, values: Dictionary) -> Dictionary:
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=CHAR_MEMBER:return _fail("source_main_char_info_scene_mismatch")
	if not scene.has_method("set_bound_percent") or not scene.has_method("set_bound_text"):return _fail("source_main_char_info_scene_binding_api_missing")
	var pack: Variant=scene.get("source_pack")
	if pack==null or pack.manifest.get("files",{}).get(CHAR_MEMBER,{}).get("sha256","")!=CHAR_SHA256:return _fail("source_main_char_info_identity_mismatch")
	var presented: Dictionary=_char_values(values)
	if not presented.get("ok",false):return presented
	for offset: int in [37172,35528]:
		var result: Dictionary=scene.set_bound_text(offset,presented.hp_text if offset==37172 else presented.mp_text)
		if not result.get("ok",false):return result
	for offset: int in [40620,35464]:
		var result: Dictionary=scene.set_bound_percent(offset,presented.hp_percent if offset==40620 else presented.mp_percent)
		if not result.get("ok",false):return result
	if scene.get("source_nodes").has(POISON_BAR):
		var poison_percent: Dictionary=scene.set_bound_percent(POISON_BAR,presented.hp_percent)
		if not poison_percent.get("ok",false):return poison_percent
	if scene.get("source_nodes").has(CLASS_PROJECT):
		if typeof(values.get("level"))!=TYPE_INT:return _fail("source_main_raw_level_required")
		var child: Dictionary=scene.project_player([CLASS_PROJECT])
		if not child.get("ok",false):return child
		var result: Dictionary=child.player.set_bound_text(CLASS_LEVEL,str(values.level))
		if not result.get("ok",false):return result
	return {"ok":true,"values":presented,"partial_source_scene":true,"game_state_written":false}

static func _char_values(values: Dictionary) -> Dictionary:
	for key: String in ["hp","max_hp","mp","max_mp"]:
		if not values.has(key) or typeof(values[key])!=TYPE_INT:return {"ok":false,"code":"source_main_char_info_raw_value_required","field":key}
	return {"ok":true,"hp_percent":float(values.hp)*100/maxi(1,int(values.max_hp)),"mp_percent":float(values.mp)*100/maxi(1,int(values.max_mp)),"hp_text":"%d / %d" % [int(values.hp),int(values.max_hp)],"mp_text":"%d / %d" % [int(values.mp),int(values.max_mp)]}

static func refresh_poison(scene: Node2D, hud: Node) -> Dictionary:
	if not is_instance_valid(scene) or not scene.get("source_nodes").has(POISON_BAR):return {"ok":true,"handled":false}
	var state: Dictionary=_poison_state(hud)
	if not state.get("ok",false):
		scene.set_bound_visible(POISON_BAR,false)
		if scene.has_meta("source_poison_active"):scene.remove_meta("source_poison_active")
		return state
	if scene.has_meta("source_poison_active") and scene.get_meta("source_poison_active")==state.active:return {"ok":true,"handled":true,"active":state.active}
	var result: Dictionary=scene.set_bound_visible(POISON_BAR,state.active)
	if result.get("ok",false):scene.set_meta("source_poison_active",state.active)
	return result

static func _poison_state(hud: Node) -> Dictionary:
	var world: Node=hud.get_parent() if is_instance_valid(hud) else null
	var player: Variant=world.get("player") if is_instance_valid(world) else null
	if not is_instance_valid(player) or not player.has_method("is_poisoned"):return _fail("source_main_actual_poison_owner_required")
	var active: Variant=player.call("is_poisoned")
	if not active is bool:return _fail("source_main_actual_poison_boolean_required")
	return {"ok":true,"active":active}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
