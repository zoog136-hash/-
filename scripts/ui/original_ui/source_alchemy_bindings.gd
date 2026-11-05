extends RefCounted
## Exact supplied Alchemy_All nodes. Remaining source controls/child bindings
## must come from their original callers; no guessed quantity behavior.
const MEMBER="UI/Alchemy/Alchemy_All.csb"
const SHA256="67fff32178fbc37e4be6388faff8a4f777648e04d4029b275d13fee9ed46e833"
const CLOSE=19568
const ALCHEMY=4084
const CHILDREN={3828:"UI/Alchemy/Alchemy_Item.csb",3564:"UI/Alchemy/Alchemy_Inventory.csb",3292:"UI/Alchemy/Fx_Alchemy_MagicBall.csb",3016:"UI/Alchemy/Fx_Alchemy_MagicBall.csb",2720:"UI/Alchemy/Alchemy_Roulette.csb"}

static func build(pack: RefCounted, adapter: Object, remaining: Dictionary) -> Dictionary:
	if pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return {"ok":false,"code":"source_alchemy_identity_mismatch"}
	if not is_instance_valid(adapter) or not adapter.has_method("request_preview_for") or not adapter.has_method("close"):return {"ok":false,"code":"source_equipment_adapter_unavailable"}
	var bindings: Dictionary=remaining.duplicate(true)
	bindings[CLOSE]={"role":"button","activate":Callable(adapter,"close")}
	# This enters the existing quote/confirmation protocol. It does not
	# execute a purchase, choose materials or invent the unknown batch count.
	bindings[ALCHEMY]={"role":"button","activate":Callable(adapter,"request_preview_for").bind("alchemy")}
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"bindings":bindings,"complete_screen_contract":false}
