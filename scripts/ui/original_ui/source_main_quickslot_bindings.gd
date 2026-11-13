extends RefCounted
## Existing HUD's ten visible slots projected into two original five-slot sets.
## World/HUD retain page selection, item counts, cooldown and AUTO policy.
const SET_MEMBER="UI/Main/Hud_QuickSlotSet.csb"
const SET_SHA256="4c82afdae16a34a618b63e70b3793abf4b4a42465215f4221a4835b666523134"
const SLOT_MEMBER="UI/MainFloating/Slot_Skill.csb"
const SLOT_SHA256="a2ef732cf9cee265b9dab0cee379ffab47fab6c2cc3b520d4d0cfd3eb3ad2c81"
const PANEL=124
const SLOT_PROJECT_OFFSETS: Array[int]=[1628,1360,1104,848,592]
const BUTTON=20348
const BACKGROUND=19808
const SLOT_BACKGROUND=18816
const ICON=18488
const AMOUNT=18112
const COOLDOWN=16968
const AUTO_ICON=13684
const SLOT_SOURCE_OFFSETS: Array[int]=[20348,19808,18816,18488,18112,16968,13684]
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const ORIGINAL_COUNT=preload("res://scripts/original_client/oc_m100_m102_quickslot.gd")
var _pack: RefCounted
var _hud: WeakRef
var _image_provider: Callable

func configure(pack: RefCounted, hud: Node, image_provider: Callable) -> Dictionary:
	if not is_instance_valid(hud) or not hud.has_method("quickslot_index") or not hud.has_method("_emit_quickslot"):return _fail("source_quickslot_existing_hud_api_missing")
	_pack=pack
	_hud=weakref(hud)
	_image_provider=image_provider
	var identity: Dictionary=_identities()
	if not identity.get("ok",false):return identity
	return {"ok":true,"configured":true,"image_provider_available":image_provider.is_valid(),"partial_source_scene":true,"complete_screen_contract":false}

func snapshot() -> Dictionary:
	return _snapshot()

func _snapshot(only_visible: int=-1) -> Dictionary:
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=_snapshot_model(only_visible)
	FRAME_HITCH.detail("ui.quickslot_snapshot",started)
	return result

func _snapshot_model(only_visible: int) -> Dictionary:
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_quickslot_hud_unavailable")
	var world: Node=hud.get_parent()
	if not is_instance_valid(world) or not world.has_method("_quickslot_pages"):return _fail("source_quickslot_existing_world_pages_missing")
	var pages: Variant=world.call("_quickslot_pages")
	var entries: Variant=hud.get("quickslot_entries")
	var captions: Variant=hud.get("quickslot_captions")
	var cooldowns: Variant=hud.get("quickslot_cooldown_labels")
	if not pages is Array or pages.size()!=2:return _fail("source_quickslot_existing_page_model_invalid")
	for page: Variant in pages:
		if typeof(page)!=TYPE_INT or int(page)<0:return _fail("source_quickslot_existing_page_index_invalid")
	if not entries is Array or not captions is Array or not cooldowns is Array or captions.size()<10 or cooldowns.size()<10:return _fail("source_quickslot_existing_visible_model_missing")
	var rows: Array=[]
	for visible: int in range(10):
		var absolute: Variant=hud.call("quickslot_index",visible)
		if typeof(absolute)!=TYPE_INT or int(absolute)<0:return _fail("source_quickslot_existing_index_invalid")
		var caption: Variant=captions[visible]
		var cooldown: Variant=cooldowns[visible]
		if not is_instance_valid(caption) or not caption is Label or not is_instance_valid(cooldown) or not cooldown is Label:return _fail("source_quickslot_existing_text_label_missing")
		# A single-slot refresh still validates every live index/label, but does
		# not project/copy the nine rows that its caller will never consume.
		# No cross-call cache: the requested row is read again for each refresh.
		if only_visible>=0 and visible!=only_visible:
			rows.append({})
			continue
		# This is the same out-of-range/non-dictionary empty case the HUD
		# presents. No 50-slot count, page modulus or game filter is reproduced.
		var entry: Dictionary=entries[absolute].duplicate(true) if absolute<entries.size() and entries[absolute] is Dictionary else {}
		var group: int=visible/5
		# M100: an ammo-using skill shows the ammo count by the original setter; every
		# other row keeps the existing HUD caption (the game has no spell counter store).
		var ammo: Dictionary=world.call("_quickslot_ammo_source",entry) if world.has_method("_quickslot_ammo_source") and not entry.is_empty() else {}
		var amount: Dictionary=amount_presentation(not entry.is_empty(),caption.text,ammo)
		rows.append({"visible_index":visible,"absolute_index":absolute,"group":group,"page_index":pages[group],"entry":entry,"filled":not entry.is_empty(),"amount_text":amount.text,"amount_visible":amount.visible,"amount_basis":amount.basis,"cooldown_text":cooldown.text,"auto":bool(entry.get("auto",false))})
	return {"ok":true,"rows":rows,"pages":pages.duplicate(true),"model_basis":"existing HUD quickslot_index/entries/captions/cooldown_labels and World._quickslot_pages","partial_source_scene":true,"complete_screen_contract":false}

func build_group(group: int) -> Dictionary:
	var identity: Dictionary=_identities()
	if not identity.get("ok",false):return identity
	if group not in [0,1]:return _fail("source_quickslot_visible_group_unknown")
	var model: Dictionary=snapshot()
	if not model.get("ok",false):return model
	var bindings: Dictionary={PANEL:{"role":"consume"}}
	var rows: Array=[]
	var owners: Dictionary={}
	for local_index: int in range(5):
		var visible: int=group*5+local_index
		var row: Dictionary=model.rows[visible].duplicate(true)
		var project: int=SLOT_PROJECT_OFFSETS[local_index]
		row["slot_project_offset"]=project
		if row.filled:
			if not _image_provider.is_valid():return {"ok":false,"code":"source_quickslot_existing_image_provider_required","visible_index":visible,"absolute_index":row.absolute_index}
			var supplied: Variant=_image_provider.call(row.duplicate(true),{"member":SLOT_MEMBER,"node_offset":ICON,"slot_project_offset":project,"visible_index":visible,"absolute_index":row.absolute_index,"group":group,"page_index":row.page_index})
			if not supplied is Dictionary:return _fail("source_quickslot_existing_owner_result_invalid")
			if not supplied.get("ok",false) or (not supplied.get("texture") is Texture2D and not supplied.get("source_scene_descriptor") is Dictionary):return {"ok":false,"code":"source_quickslot_actual_owner_visual_unavailable","visible_index":visible,"absolute_index":row.absolute_index,"owner_result":supplied}
			owners[project]=supplied
		var slot_bindings: Dictionary={
			# Empty clicks remain the existing HUD action, never disabled here.
			BUTTON:{"role":"button","activate":Callable(self,"activate_presented").bind(visible,_presented_identity(row))},
			ICON:{"role":"source_asset_slot","visible":false},
			AMOUNT:{"role":"source_text","text":row.amount_text,"visible":bool(row.amount_visible)},
			COOLDOWN:{"role":"source_text","text":row.cooldown_text,"visible":row.filled and not str(row.cooldown_text).is_empty()},
			AUTO_ICON:{"visible":row.filled and bool(row.auto)}
		}
		bindings[project]={"role":"project","source_node_offsets":SLOT_SOURCE_OFFSETS.duplicate(),"bindings":slot_bindings}
		rows.append(row)
	# Project scopes retain original Panel124 ancestry and five positions.
	# PageView registration/layout is the caller's independent engine adapter.
	return {"ok":true,"member":SET_MEMBER,"sha256":SET_SHA256,"source_node_offsets":SLOT_PROJECT_OFFSETS.duplicate(),"bindings":bindings,"rows":rows,"owner_results":owners,"slot_project_offsets":SLOT_PROJECT_OFFSETS.duplicate(),"group":group,"page_index":model.pages[group],"pages":model.pages,"panel_offset":PANEL,"panel_extent":Vector2(360,124),"slot_member":SLOT_MEMBER,"slot_sha256":SLOT_SHA256,"slot_source_node_offsets":SLOT_SOURCE_OFFSETS.duplicate(),"external_texture_node":ICON,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original_slot_number_charge_and_other_effect_roles_excluded_from_scope"]}

func activate(visible: int) -> Dictionary:
	if visible<0 or visible>=10:return _fail("source_quickslot_visible_index_unknown")
	var model: Dictionary=snapshot()
	if not model.get("ok",false):return model
	var hud: Object=_live_hud()
	if hud==null:return _fail("source_quickslot_hud_unavailable")
	# _emit_quickslot owns PointerTransfer.suppress_click and the current
	# game index. A void dispatch is not a claim that a use/action succeeded.
	hud.call("_emit_quickslot",visible)
	return {"ok":true,"dispatched":true,"method":"_emit_quickslot","visible_index":visible,"absolute_index":model.rows[visible].absolute_index,"action_result_known":false}

func activate_presented(visible: int, presented: Dictionary) -> Dictionary:
	if visible<0 or visible>=10:return _fail("source_quickslot_visible_index_unknown")
	var current: Dictionary=snapshot()
	if not current.get("ok",false):return current
	# A release from an old source node must not use a new item/skill that
	# occupies the same visible position after page/edit changes. Amount,
	# cooldown and AUTO refreshes do not change the registered entry identity.
	if presented!=_presented_identity(current.rows[visible]):return {"ok":false,"code":"source_quickslot_presented_entry_changed","rebuild_required":true,"dispatched":false}
	return activate(visible)

func refresh_slot(scene: Node2D, row: Dictionary) -> Dictionary:
	var identity: Dictionary=_identities()
	if not identity.get("ok",false):return identity
	if not is_instance_valid(scene) or scene.get("source_member")!=SLOT_MEMBER:return _fail("source_quickslot_original_slot_scene_required")
	var visible: Variant=row.get("visible_index")
	if typeof(visible)!=TYPE_INT or int(visible)<0 or int(visible)>=10:return _fail("source_quickslot_row_visible_index_missing")
	var model: Dictionary=_snapshot(int(visible))
	if not model.get("ok",false):return model
	var current: Dictionary=model.rows[visible]
	if not row.get("entry") is Dictionary or row.get("absolute_index")!=current.absolute_index or _entry_identity(row.entry)!=_entry_identity(current.entry) or row.get("page_index")!=current.page_index:return {"ok":false,"code":"source_quickslot_row_identity_changed","rebuild_required":true}
	var previous: Variant=scene.get_meta("source_quickslot_identity",{})
	var current_identity: Dictionary={"visible_index":visible,"absolute_index":current.absolute_index,"page_index":current.page_index,"entry":_entry_identity(current.entry)}
	if previous is Dictionary and not previous.is_empty() and previous!=current_identity:return {"ok":false,"code":"source_quickslot_presented_identity_changed","rebuild_required":true}
	for pair: Array in [[AMOUNT,"amount_text"],[COOLDOWN,"cooldown_text"]]:
		var value: String=current[pair[1]]
		var result: Dictionary=scene.set_bound_text(int(pair[0]),value)
		if not result.get("ok",false):return result
		var shown_now: bool=bool(current.amount_visible) if int(pair[0])==AMOUNT else current.filled and not value.is_empty()
		result=scene.set_bound_visible(int(pair[0]),shown_now)
		if not result.get("ok",false):return result
	var shown: Dictionary=scene.set_bound_visible(AUTO_ICON,current.filled and bool(current.auto))
	if not shown.get("ok",false):return shown
	if not current.filled:
		shown=scene.set_bound_visible(ICON,false)
		if not shown.get("ok",false):return shown
	# No image provider/relookup is invoked by refresh. Initial owner upload
	# and a real entry/page change are handled by the caller's staged rebuild.
	scene.set_meta("source_quickslot_identity",current_identity)
	return {"ok":true,"row":current,"image_lookup_performed":false,"game_state_written":false}

## Amount node text/visibility. `ammo` is empty unless the slot is a skill that consumes ammo:
## {"ammo_count": int, "can_use_without_ammo": bool}. Then the game data is projected onto the
## original refresh: one spell slot whose raw key hits a BulletID mapping row, a loaded row
## whose CanUseSpellWithoutAmmo byte is the game rule, and the ammo store holding the count.
## Everything else (items, skills without ammo) is the existing caption, unchanged.
static func amount_presentation(filled: bool,existing_text: String,ammo: Dictionary) -> Dictionary:
	if not filled or ammo.is_empty():
		return {"text":existing_text,"visible":filled and not existing_text.is_empty(),"basis":"existing_caption"}
	var mapping:=PackedByteArray()
	mapping.resize(0x30)
	mapping.encode_s32(ORIGINAL_COUNT.MAPPING_ROW_BULLET_ID,1)
	var loaded:=PackedByteArray()
	loaded.resize(0x30)
	loaded[ORIGINAL_COUNT.LOADED_ROW_WITHOUT_AMMO]=1 if bool(ammo.get("can_use_without_ammo",false)) else 0
	# Game skills carry no stack counter (the original SpellManager+188 store is absent).
	var never_stackable:=func(_id: int) -> bool: return false
	var no_stack:=func(_id: int) -> int: return 0
	var model: Dictionary={"slots":{0:{"metadata_id":1,"dword10":1,"is_spell":true}},
		"stackable":never_stackable,"stack_count":no_stack,
		"mapping_rows":{1:mapping},"loaded_rows":{1:loaded},"service_c0":{1:int(ammo.get("ammo_count",0))},"reload_90":{},"reads":[]}
	var result: Dictionary=ORIGINAL_COUNT.refresh(model,{"bucket":0,"index":0})
	var visible: bool=filled
	for op: Array in result.get("ops",[]):
		if op[0]=="Nd_Count.visible":visible=bool(op[1])
	return {"text":str(int(result.count)),"visible":visible,"basis":"original_ammo_count","flag34":int(result.flag34),"flag35":int(result.flag35)}

static func _entry_identity(entry: Dictionary) -> Dictionary:
	var identity: Dictionary=entry.duplicate(true)
	# AUTO is a separately supplied live marker, not a different item/skill.
	identity.erase("auto")
	return identity

static func _presented_identity(row: Dictionary) -> Dictionary:
	return {"visible_index":row.visible_index,"absolute_index":row.absolute_index,"page_index":row.page_index,"entry":_entry_identity(row.entry)}

func _live_hud() -> Object:
	return _hud.get_ref() if _hud!=null else null

func _identities() -> Dictionary:
	if _pack==null:return _fail("source_quickslot_original_pack_required")
	for expected: Array in [[SET_MEMBER,SET_SHA256],[SLOT_MEMBER,SLOT_SHA256]]:
		if _pack.manifest.get("files",{}).get(expected[0],{}).get("sha256","")!=expected[1]:return {"ok":false,"code":"source_quickslot_original_identity_mismatch","member":expected[0]}
	return {"ok":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
