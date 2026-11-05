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

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
