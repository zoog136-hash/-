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
		20552:{"role":"button","activate":Callable(inputs,"open_character")},
		20060:{"role":"button","activate":Callable(inputs,"open_inventory")}
	}
	return {"ok":true,"member":CHAR_MEMBER,"sha256":CHAR_SHA256,"source_node_offsets":CHAR_NODE_OFFSETS.duplicate(),"bindings":bindings,"values":presented,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":[{"offset":37544,"field":"original_clipping_custom_property","source_property":"clipping","source_value":0.5,"included_in_scope":false},"original_hp_delta_trail_timing","original_poison_weight_lawful_and_other_stat_roles"]}

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
	return {"ok":true,"values":presented,"partial_source_scene":true,"game_state_written":false}

static func _char_values(values: Dictionary) -> Dictionary:
	for key: String in ["hp","max_hp","mp","max_mp"]:
		if not values.has(key) or typeof(values[key])!=TYPE_INT:return {"ok":false,"code":"source_main_char_info_raw_value_required","field":key}
	return {"ok":true,"hp_percent":float(values.hp)*100/maxi(1,int(values.max_hp)),"mp_percent":float(values.mp)*100/maxi(1,int(values.max_mp)),"hp_text":"%d / %d" % [int(values.hp),int(values.max_hp)],"mp_text":"%d / %d" % [int(values.mp),int(values.max_mp)]}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
