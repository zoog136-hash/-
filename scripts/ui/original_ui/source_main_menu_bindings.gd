extends RefCounted
## Exact original main-menu controls route into existing HUD/World entry points.
## No new menu layout, inventory ownership, skills or shop logic is implemented.
const MEMBER="UI/Main/Hud_TopMenu.csb"
const SHA256="0b0fd7d02b604924dfb1a16f9ef35d71c0e1cfd19e634028b72837499a75ae85"
const INVENTORY=31392
const SKILL=29848
const STORE=35008
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
