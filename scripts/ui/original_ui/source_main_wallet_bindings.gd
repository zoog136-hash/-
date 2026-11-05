extends RefCounted
## Read-only presentation of the existing game's gold/diamond balances.
## The original currency icons, text geometry and parent hierarchy are kept.
const MEMBER="UI/Main/Hud_PayLayout.csb"
const SHA256="74289dc69d7c3a53d9f48206f16d8ff0b9b30ce13b8b69153165663d844f61bf"
const SOURCE_OFFSETS: Array[int]=[6244,5808,5264,4880]
const GOLD_TEXT=4880
const JEWEL_TEXT=5808

static func build(pack: RefCounted, gold: int, balances: Dictionary) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_wallet_identity_mismatch")
	if typeof(balances.get("다이아"))!=TYPE_INT:return _fail("source_main_wallet_existing_diamond_balance_required")
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":{GOLD_TEXT:{"role":"source_text","text":str(gold)},JEWEL_TEXT:{"role":"source_text","text":str(balances["다이아"])}},"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original_info_button_action","original_autoslot_and_blesspoint_services","additional_game_currency_display_roles"]}

static func refresh(scene: Node2D, gold: int, balances: Dictionary) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MEMBER:return _fail("source_main_wallet_scene_mismatch")
	if typeof(balances.get("다이아"))!=TYPE_INT:return _fail("source_main_wallet_existing_diamond_balance_required")
	var result: Dictionary=scene.set_bound_text(GOLD_TEXT,str(gold))
	if not result.get("ok",false):return result
	result=scene.set_bound_text(JEWEL_TEXT,str(balances["다이아"]))
	if not result.get("ok",false):return result
	return {"ok":true,"gold":gold,"diamonds":balances["다이아"],"game_state_written":false,"complete_screen_contract":false}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
