extends RefCounted
## Actual existing Ainhasad owner -> original count and information entry.
## Icon stages, infinity, caution and recharge rules are not inferred.
const WALLET="UI/Main/Hud_PayLayout.csb"
const WALLET_SHA="74289dc69d7c3a53d9f48206f16d8ff0b9b30ce13b8b69153165663d844f61bf"
const MEMBER="UI/Main/Hud_BlessPoint.csb"
const SHA256="97c33507483cdb6517a9d6b671ffad92b757a62e79c3269b590316722dafd2a1"
const SLOT="UI/Main/Hud_EinSlot.csb"
const SLOT_SHA="8b8e324d39da49f2ff9d2fc23dfd3e7953eccd2dea8b2caec57b18b0be0df168"
const PROJECT=184
const SLOT_PROJECT=9056
const BUTTON=9336
const AMOUNT=792
const INFO: Array[int]=[8312,7924,6656,6324,5992,4560,4232]

class BlessingInput extends RefCounted:
	var host: WeakRef
	func activate() -> Dictionary:
		var hud: Object=host.get_ref() if host!=null else null
		if not is_instance_valid(hud) or not hud.has_method("_toggle_ain_window"):return {"ok":false,"code":"source_blessing_existing_information_owner_required"}
		var button: Variant=hud.get("v20_leaf_button")
		if not button is BaseButton or not is_instance_valid(button) or button.disabled:return {"ok":false,"code":"source_blessing_existing_entry_disabled"}
		hud.call("_toggle_ain_window")
		return {"ok":true,"dispatched":true,"method":"existing HUD._toggle_ain_window","game_state_written":false}

static func source_state(hud: Object) -> Dictionary:
	if not is_instance_valid(hud) or not hud.has_method("_toggle_ain_window"):return {"ok":false,"code":"source_blessing_existing_information_owner_required"}
	var state: Variant=hud.get("v20_ain_state")
	var button: Variant=hud.get("v20_leaf_button")
	var panel: Variant=hud.get("v20_ain_panel")
	if not state is Dictionary or typeof(state.get("blessing"))!=TYPE_INT or state.blessing<0:return {"ok":false,"code":"source_blessing_actual_integer_required"}
	if not button is BaseButton or not is_instance_valid(button) or not panel is Control or not is_instance_valid(panel):return {"ok":false,"code":"source_blessing_existing_information_control_required"}
	var info: Dictionary={}
	var exp_rate: Variant=state.get("exp_rate")
	var adena_rate: Variant=state.get("adena_rate")
	if typeof(exp_rate) in [TYPE_INT,TYPE_FLOAT] and typeof(adena_rate) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(exp_rate)) and is_finite(float(adena_rate)) and exp_rate>=0 and adena_rate>=0:
		# This is the existing hud_v20.set_ain_state display conversion. Rates
		# come from the owner; no source preview700% or drop/EXP rule is used.
		info={"exp_text":"%d%%" % int(float(exp_rate)*100.0),"adena_text":"%d%%" % int(float(adena_rate)*100.0)}
	return {"ok":true,"amount":state.blessing,"disabled":button.disabled,"info":info,"info_visible":panel.visible and not info.is_empty()}

static func build(pack: RefCounted, hud: Object) -> Dictionary:
	for spec: Array in [[WALLET,WALLET_SHA,[PROJECT]],[MEMBER,SHA256,[BUTTON,SLOT_PROJECT]],[SLOT,SLOT_SHA,[3496,AMOUNT]]]:
		if pack==null or pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1]:return {"ok":false,"code":"source_blessing_original_identity_unavailable","member":spec[0]}
		var allowed: Variant=pack.manifest.get("node_scopes",{}).get(spec[0])
		for offset: int in spec[2]:
			if allowed is Array and not allowed.has(offset):return {"ok":false,"code":"source_blessing_original_scope_unavailable","member":spec[0],"offset":offset}
	var state: Dictionary=source_state(hud)
	if not state.get("ok",false):return state
	var input=BlessingInput.new()
	input.host=weakref(hud)
	# The lambda below holds `input`; a Callable(input, ...) would not.
	var scope: Array[int]=[BUTTON,SLOT_PROJECT]
	var bindings: Dictionary={BUTTON:{"role":"button","activate":func() -> Dictionary: return input.activate(),"displaystate":not state.disabled},SLOT_PROJECT:{"role":"project","source_node_offsets":[3496,AMOUNT],"bindings":{AMOUNT:{"role":"source_text","text":str(state.amount)}}}}
	var info_in_scope: bool=true
	var allowed: Variant=pack.manifest.get("node_scopes",{}).get(MEMBER)
	if allowed is Array:
		for offset: int in INFO:
			if not allowed.has(offset):info_in_scope=false
	if info_in_scope:
		scope.append_array(INFO)
		bindings[172]={"visible":state.info_visible}
		for offset: int in [6656,6324,5992]:bindings[offset]={"role":"static_source_text"}
		bindings[4560]={"role":"source_text","text":str(state.info.get("exp_text",""))}
		bindings[4232]={"role":"source_text","text":str(state.info.get("adena_text",""))}
	return {"ok":true,"state":state,"info_in_scope":info_in_scope,"source_node_offsets":[PROJECT],"bindings":{PROJECT:{"role":"project","source_node_offsets":scope,"bindings":bindings}},"partial_source_scene":true,"complete_screen_contract":false}

static func refresh(scene: Node2D, state: Dictionary, info_in_scope: bool) -> Dictionary:
	var slot: Dictionary=scene.project_player([PROJECT,SLOT_PROJECT])
	var parent: Dictionary=scene.project_player([PROJECT])
	if not slot.get("ok",false):return slot
	if not parent.get("ok",false):return parent
	var result: Dictionary=slot.player.set_bound_text(AMOUNT,str(state.amount))
	if not result.get("ok",false):return result
	var node: Variant=parent.player.source_nodes.get(BUTTON)
	var button: Variant=(node.get_meta("source_button") if node.has_meta("source_button") else null) if is_instance_valid(node) else null
	if not is_instance_valid(button):return {"ok":false,"code":"source_blessing_original_button_unavailable"}
	if (button.get("current_state")=="disabled")!=state.disabled:
		result=parent.player.set_bound_displaystate(BUTTON,not state.disabled)
		if not result.get("ok",false):return result
	if info_in_scope:
		for pair: Array in [[4560,"exp_text"],[4232,"adena_text"]]:
			result=parent.player.set_bound_text(pair[0],str(state.info.get(pair[1],"")))
			if not result.get("ok",false):return result
		result=parent.player.set_bound_visible(172,state.info_visible)
	return result
