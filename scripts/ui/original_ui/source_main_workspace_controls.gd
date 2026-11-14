extends RefCounted
## Authored close controls for existing main-game workspace owners. This is
## not a replacement form, transaction interpreter or generic source layout.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Search=preload("res://scripts/ui/original_ui/source_main_inventory_search.gd")
const SPECS={
	"warehouse":{"owner":"res://scripts/ui/renewal_warehouse.gd","parent":"UI/StorageScene.csb","parent_sha":"0df424e7ed29a314e112ef618d40f89806c9df6ad6ce56df7dedd5e08e9ebde7","project":132,"member":"UI/Storage/Storage_All.csb","sha":"eb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328","close":47160},
	"crafting":{"owner":"res://scripts/ui/renewal_crafting.gd","parent":"UI/ProductionScene.csb","parent_sha":"cae6672733b914c0143fe376574e73012b0cd628113002693f0639c877f47328","project":132,"member":"UI/Production/Production_All.csb","sha":"328546745405eac58203853570d76e07d9cc95477ac4ecd701d786651e3786ec","close":41600},
	"shop":{"owner":"res://scripts/ui/renewal_shop.gd","parent":"UI/ShopScene.csb","parent_sha":"4cea51464273a19104c10a90a0be317f6502af5928c614b126305ffc793ed7e1","project":788,"member":"UI/Shop/Shop_All.csb","sha":"42b0701448ae9b2485818dce05fb33961b997e5621064964330d6f5bea9991c8","close":324},
	"npc_shop":{"owner":"res://scripts/ui/renewal_shop.gd","parent":"UI/StoreScene.csb","parent_sha":"8e414c1d179d395048f8fb963c08ccbde12dfcc125f3b0bc1cc4c5fa8b999a68","project":148,"member":"UI/Store/Store_All.csb","sha":"fb2a67543f60e42caa675d8e0b9f1d3834f78c1e2a85645f424da3ef5cbf7c05","close":67396}
}
var _pack: RefCounted
var _hud: WeakRef
var _owner: WeakRef
var _attempted_owner: WeakRef
var _section: String=""
var _attempted_section: String=""
var _scene: Node2D
var _texts: Dictionary={}
var _search: RefCounted
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> void:
	_pack=pack
	_hud=weakref(hud)

func refresh(parent: Node) -> Dictionary:
	var current: Dictionary=_current()
	if not current.get("ok",false):
		close();_attempted_owner=null;_attempted_section=""
		return {"ok":true,"handled":false}
	if is_instance_valid(_scene) and _owner!=null and _owner.get_ref()==current.owner and _section==current.section:
		var texts: Dictionary=_current_texts(current.owner,current.section)
		for offset: int in _texts:
			if not texts.has(offset):close();return _fail("source_workspace_current_text_owner_unavailable")
			if texts[offset]==_texts[offset]:continue
			var result: Dictionary=_scene.set_bound_text(offset,texts[offset])
			if not result.get("ok",false):close();last_result=result;return result
			_texts[offset]=texts[offset]
		return last_result.duplicate(true)
	close()
	if _attempted_owner!=null and _attempted_owner.get_ref()==current.owner and _attempted_section==current.section:return last_result.duplicate(true)
	_attempted_owner=weakref(current.owner);_attempted_section=current.section
	var spec: Dictionary=SPECS[current.section]
	if not is_instance_valid(parent):return _fail("source_workspace_actual_mount_required")
	if _pack.manifest.get("files",{}).get(spec.parent,{}).get("sha256")!=spec.parent_sha or _pack.manifest.get("files",{}).get(spec.member,{}).get("sha256")!=spec.sha:return _fail("source_workspace_original_identity_unavailable")
	if _pack.layout_source(spec.parent).get("_source_sha256")!=spec.parent_sha:return _fail("source_workspace_original_parent_required")
	var scope: Array[int]=[int(spec.close)]
	var bindings: Dictionary={int(spec.close):{"role":"button","activate":Callable(self,"_close_requested")}}
	var texts: Dictionary=_current_texts(current.owner,current.section)
	var allowed: Variant=_pack.manifest.get("node_scopes",{}).get(spec.member)
	if current.section=="warehouse":
		if not allowed is Array or allowed.has(48640):scope.append(48640);bindings[48640]={"role":"static_source_text"}
		if texts.has(47920) and (not allowed is Array or allowed.has(47920)):
			scope.append(47920);bindings[47920]={"role":"source_text","text":texts[47920]}
			_texts[47920]=texts[47920]
	if current.section=="crafting" and _pack.manifest.get("scenes",{}).has("UI/Production/Production_Popup_Keypad.csb") and (not allowed is Array or (allowed.has(964) and allowed.has(2252))):
		scope.append_array([964,2252])
		bindings[964]={"role":"button","activate":Callable(self,"open_search")}
		bindings[2252]={"role":"static_source_text"}
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_project(_pack,spec.parent,int(spec.project),bindings,scope)
	if not result.get("ok",false):scene.free();last_result=result;return result
	# The current owner has explicitly opened this screen. Retain parent
	# geometry and use the child component's authored active root opacity;
	# do not make its visible close icon an invisible editor-preview hit area.
	result=scene.activate_authored_component_opacity()
	if not result.get("ok",false):scene.free();last_result=result;return result
	parent.add_child(scene)
	_scene=scene;_owner=weakref(current.owner);_section=current.section
	last_result={"ok":true,"handled":true,"section":_section,"member":spec.member,"close_offset":spec.close,"close_connected":true,"bound_text_offsets":_texts.keys(),"partial_source_scene":true,"complete_screen_contract":false,"transactions_connected":false,"game_state_written":false}
	return last_result.duplicate(true)

func presentation() -> Dictionary:
	return {"scene":_scene,"handled":is_instance_valid(_scene),"partial_source_scene":true}

func blocks_point(point: Vector2) -> bool:
	if not point.is_finite() or not is_instance_valid(_scene) or _scene.is_queued_for_deletion():return false
	var current: Dictionary=_current()
	if not current.get("ok",false) or _owner==null or _owner.get_ref()!=current.owner or _section!=current.section:return false
	var node: Variant=_scene.source_nodes.get(int(SPECS[_section].close))
	var button: Variant=(node.get_meta("source_button") if node.has_meta("source_button") else null) if is_instance_valid(node) else null
	var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
	return control is Control and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)

func close() -> void:
	close_search()
	var previous: Node2D=_scene
	_scene=null;_owner=null;_section=""
	_texts.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():previous.hide();previous.queue_free()

func open_search() -> Dictionary:
	var current: Dictionary=_current()
	if not current.get("ok",false) or current.section!="crafting" or _owner==null or _owner.get_ref()!=current.owner or _section!="crafting":return _fail("source_craft_search_current_workspace_owner_required")
	if _search==null:
		_search=Search.new()
		var result: Dictionary=_search.configure_crafting(_pack,current.owner)
		if not result.get("ok",false):_search=null;return result
	return _search.open(_scene.get_parent())

func search_is_open() -> bool:
	return _search!=null and _search.is_open()

func search_presentation() -> Dictionary:
	return _search.presentation() if _search!=null else {}

func focus_search_at(point: Vector2) -> bool:
	return _search!=null and _search.focus_input_at(point)

func close_search() -> void:
	if _search!=null:_search.close()
	_search=null

func _close_requested() -> Dictionary:
	var current: Dictionary=_current()
	if not current.get("ok",false) or _owner==null or _owner.get_ref()!=current.owner or _section!=current.section:return _fail("source_workspace_presented_owner_changed")
	var hud: Object=_hud.get_ref()
	hud.call("_close_workspace")
	close()
	return {"ok":true,"dispatched":true,"method":"existing HUD._close_workspace","transaction_requested":false,"game_state_written":false}

func _current() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if not is_instance_valid(hud) or not hud.has_method("_close_workspace"):return {"ok":false}
	var section: Variant=hud.get("active_section")
	var workspace: Variant=hud.get("workspace")
	if not section is String or not SPECS.has(section) or not workspace is Control or not is_instance_valid(workspace) or not workspace.is_visible_in_tree():return {"ok":false}
	if _pack==null or not _pack.manifest.get("scenes",{}).has(SPECS[section].member):return {"ok":false}
	var previous: Object=_owner.get_ref() if _owner!=null else null
	if previous is Control and is_instance_valid(previous) and not previous.is_queued_for_deletion() and _section==section and previous.is_visible_in_tree() and workspace.is_ancestor_of(previous) and previous.get("hud")==hud:return {"ok":true,"section":section,"owner":previous}
	var owners: Array[Control]=[]
	_find_owners(workspace,str(SPECS[section].owner),owners)
	if owners.size()!=1 or owners[0].get("hud")!=hud:return {"ok":false}
	if section in ["shop","npc_shop"] and owners[0].get("npc_mode")!=(section=="npc_shop"):return {"ok":false}
	return {"ok":true,"section":section,"owner":owners[0]}

static func _find_owners(node: Node, script_path: String, found: Array[Control]) -> void:
	if node.is_queued_for_deletion():return
	var script: Script=node.get_script()
	if node is Control and node.is_visible_in_tree() and script!=null and script.resource_path==script_path:found.append(node)
	for child: Node in node.get_children():_find_owners(child,script_path,found)

static func _current_texts(owner: Control, section: String) -> Dictionary:
	if section!="warehouse":return {}
	var mode: Variant=owner.get("mode")
	if not mode is OptionButton or not is_instance_valid(mode) or mode.selected<0 or mode.selected>=mode.item_count:return {}
	# Original Label_Title is the deposit/withdraw heading. The actual
	# existing selector owns its text and selected direction; no transfer,
	# all-items interpretation or new mode is introduced here.
	return {47920:mode.get_item_text(mode.selected)}

func _fail(code: String) -> Dictionary:
	last_result={"ok":false,"handled":false,"code":code}
	return last_result.duplicate(true)
