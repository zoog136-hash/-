extends RefCounted
## Original Quest_All presenter. Existing quest_service and the existing World
## claim handler retain all eligibility, reward, ownership and save operations.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const MEMBER="UI/Quest/Quest_All.csb"
const SHA256="3991dae23f1aafb97a7cea17a7eeecc554ec7e0e9eba46c6ba35806e9b6ef2a8"
const CLOSE=2412
const TABS={26500:"main",25048:"main",18928:"achievement",17520:"achievement"}
const PROJECTS={1728:"UI/Quest/Quest_Tab_Main.csb",1512:"",1256:"UI/Quest/Quest_Tab_Achievement.csb",1000:"UI/Quest/Quest_Tab_Mission.csb",712:"UI/Quest/Quest_Tab_Guild.csb",460:"UI/Quest/Quest_Tab_Daily.csb"}
const LITERALS=[26952,25100,23148,21340,19380,17572,15620,13816,11532,9732,7428,6024,3772,3176]
signal model_changed(model: Dictionary)
signal claim_emitted(quest_id: String)
var _pack: RefCounted
var _world: WeakRef
var _scene: WeakRef
var _claim_handler: Callable
var _remaining_factory: Callable
var _category: String="main"
var _selected_id: String=""
var _selected_source_id: int=0

func configure(pack: RefCounted, world: Node, claim_handler: Callable, remaining_factory: Callable=Callable()) -> Dictionary:
	if not is_instance_valid(world):return _fail("source_quest_world_unavailable")
	if not claim_handler.is_valid():return _fail("source_quest_existing_claim_handler_required")
	if pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_quest_identity_mismatch")
	_pack=pack
	_world=weakref(world)
	_claim_handler=claim_handler
	_remaining_factory=remaining_factory
	_selected_id=""
	_selected_source_id=0
	return projection()

func projection() -> Dictionary:
	var current: Dictionary=_current_entries()
	if not current.get("ok",false):return current
	var shown: Array=[]
	for row: Dictionary in current.rows:
		# Native source rows are separate from retired demo completion history.
		# Unavailable/excluded rows remain inspectable, never actionable.
		if row.has("source_id") and row.get("category")==_category:shown.append(row.duplicate(true))
	return {"ok":true,"rows":current.rows,"category_rows":shown,"category":_category,"selected_id":_selected_id,"selected_source_id":_selected_source_id,"complete_screen_contract":false,"unresolved_fields":["original_quest_list_row_template_and_placement","original_button_list_receive_template","original_goal_story_and_reward_slot_roles","sub_mission_guild_event_category_contracts","original_tab_variant_visibility"]}

func select_quest(source_id: int) -> Dictionary:
	var current: Dictionary=_current_entries()
	if not current.get("ok",false):return current
	var matches: Array=[]
	for row: Dictionary in current.rows:
		if row.has("source_id") and row.get("source_id")==source_id and row.get("category")==_category:matches.append(row)
	if source_id<=0 or matches.size()!=1:return _fail("source_quest_native_selection_not_unique")
	var selected: Dictionary=matches[0]
	if not selected.get("id") is String or str(selected.id).is_empty():return _fail("source_quest_canonical_id_missing")
	_selected_id=selected.id
	_selected_source_id=source_id
	var model: Dictionary=projection()
	if model.get("ok",false):model_changed.emit(model.duplicate(true))
	return model

func select_category(category: String) -> Dictionary:
	# Only 메 인/업 적 categories proven by the original labels are used.
	# Sub, mission, guild and event are not guessed as common/other buckets.
	if category not in ["main","achievement"]:return _fail("source_quest_category_contract_missing")
	_category=category
	_selected_id=""
	_selected_source_id=0
	var model: Dictionary=projection()
	if model.get("ok",false):model_changed.emit(model.duplicate(true))
	return model

func claim_selected() -> Dictionary:
	# Bind this only to an actually supplied receive control. Quest_All and
	# its Main/Achievement panels serialize empty button lists, not a claim.
	var current: Dictionary=_current_entries()
	if not current.get("ok",false):return current
	if _selected_id.is_empty() or not _claim_handler.is_valid():return _fail("source_quest_claim_selection_required")
	var matches: Array=[]
	for row: Dictionary in current.rows:
		if row.get("id")==_selected_id and row.get("source_id")==_selected_source_id:matches.append(row)
	if matches.size()!=1:return _fail("source_quest_claim_row_not_unique")
	var selected: Dictionary=matches[0]
	if selected.get("category")!=_category or not bool(selected.get("available",false)) or bool(selected.get("completed",false)) or not selected.get("excluded_reasons",[]).is_empty() or not selected.get("blockers",[]).is_empty():return _fail("source_quest_claim_not_offered")
	# The injected existing HUD signal wrapper/World handler owns execution.
	# Emission acknowledges delivery only, never successful rewards or saves.
	var id: String=_selected_id
	_claim_handler.call(id)
	claim_emitted.emit(id)
	return {"ok":true,"emitted":true,"quest_id":id,"action_result_known":false}

func build_bindings(remaining: Dictionary={}) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_quest_identity_mismatch")
	var model: Dictionary=projection()
	if not model.get("ok",false):return model
	var bindings: Dictionary=remaining.duplicate(true)
	bindings[CLOSE]={"role":"button","activate":Callable(self,"close")}
	for offset: int in TABS:bindings[offset]={"role":"button","activate":Callable(self,"select_category").bind(TABS[offset])}
	for offset: int in PROJECTS:
		if not bindings.has(offset):bindings[offset]={"role":"project","bindings":{}}
	for offset: int in LITERALS:
		if not bindings.has(offset):bindings[offset]={"role":"static_source_text"}
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"bindings":bindings,"model":model,"project_members":PROJECTS.duplicate(true),"unresolved_fields":model.unresolved_fields,"unmapped_root_buttons":[22696,21288,15168,13764,11080,9680,7376,5572,3724],"complete_screen_contract":false}

func open(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_quest_scene_parent_unavailable")
	var model: Dictionary=projection()
	if not model.get("ok",false):return model
	if not _remaining_factory.is_valid():return {"ok":false,"code":"source_quest_remaining_original_bindings_required","model":model,"complete_screen_contract":false}
	var supplied: Variant=_remaining_factory.call(model.duplicate(true),self)
	if not supplied is Dictionary:return _fail("source_quest_remaining_binding_factory_failed")
	var remaining: Dictionary=supplied
	if supplied.has("ok"):
		if not supplied.get("ok",false):return supplied
		if not supplied.get("bindings") is Dictionary:return _fail("source_quest_remaining_binding_factory_failed")
		remaining=supplied.bindings
	var contract: Dictionary=build_bindings(remaining)
	if not contract.get("ok",false):return contract
	var scene:=Scene.new()
	var result: Dictionary=scene.configure(_pack,MEMBER,false,contract.bindings)
	if not result.get("ok",false):
		scene.free()
		return result
	close()
	parent.add_child(scene)
	_scene=weakref(scene)
	return {"ok":true,"scene":scene,"controller":self,"model":model,"complete_screen_contract":false}

func close() -> Dictionary:
	var scene: Object=_scene.get_ref() if _scene!=null else null
	_scene=null
	if is_instance_valid(scene):scene.queue_free()
	return {"ok":true,"closed":true,"game_state_written":false}

func _current_entries() -> Dictionary:
	var world: Object=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_quest_world_unavailable")
	var service: Variant=world.get("quest_service")
	if service==null or not service.has_method("entries"):return _fail("source_quest_service_unavailable")
	var auto: Variant=world.get("quest_auto")
	if auto!=null and auto.has_method("refresh_context"):auto.refresh_context(world)
	var rows: Variant=service.entries(int(world.get("level")),world.get("inventory"))
	if not rows is Array:return _fail("source_quest_service_rows_invalid")
	return {"ok":true,"rows":rows.duplicate(true)}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
