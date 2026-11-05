extends RefCounted
## Dedicated original automatic-combat status, unrelated to show_message's
## transient text/timer. No animation, gameplay or presentation timing policy.
const MEMBER="UI/Main/Hud_AutoMessage.csb"
const SHA256="84d976b87d030d8fdd8edee3bffe17d697486eb7f991e096257c26f9dc3993a1"
const MAIN_PROJECT=14564
const ROOT=76
const TEXT=124
const SOURCE_OFFSETS: Array[int]=[TEXT]
var _pack: RefCounted
var _hud: WeakRef

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_auto_message_existing_hud_required")
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_auto_message_original_identity_mismatch")
	_pack=pack
	_hud=weakref(hud)
	return snapshot()

func snapshot() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_auto_message_existing_hud_unavailable")
	var world: Node=hud.get_parent()
	if not is_instance_valid(world):return _fail("source_auto_message_existing_world_unavailable")
	var player: Variant=world.get("player")
	if not is_instance_valid(player):return _fail("source_auto_message_existing_player_unavailable")
	var enabled: Variant=player.get("auto_enabled")
	if not enabled is bool:return _fail("source_auto_message_actual_auto_boolean_required")
	return {"ok":true,"auto_enabled":enabled,"basis":"existing hud.get_parent().player.auto_enabled"}

func build() -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_auto_message_original_identity_mismatch")
	var state: Dictionary=snapshot()
	if not state.get("ok",false):return state
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"main_project_offset":MAIN_PROJECT,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":{ROOT:{"visible":state.auto_enabled},TEXT:{"role":"static_source_text"}},"state":state,"original_clip":{"name":"Fx_Loop","start_frame":5,"end_frame":95},"playback_policy_declared":false,"playback_requested":false,"partial_source_scene":true,"complete_screen_contract":false,"general_message_connected":false}

func refresh(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MEMBER or not scene.has_method("set_bound_visible"):return _fail("source_auto_message_original_scene_required")
	var state: Dictionary=snapshot()
	if not state.get("ok",false):return state
	var result: Dictionary=scene.set_bound_visible(ROOT,state.auto_enabled)
	if not result.get("ok",false):return result
	return {"ok":true,"state":state,"playback_requested":false,"game_state_written":false}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
