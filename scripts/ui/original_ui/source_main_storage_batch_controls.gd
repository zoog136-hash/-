extends RefCounted
## Original All controls consume only the explicit live host-reviewed cart.
## No whole-inventory/displayed-list interpretation or transaction loop.
const MEMBER="UI/Storage/Storage_All.csb"
const SHA="eb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328"
const CART="res://scripts/ui/warehouse_reviewed_cart.gd"
const SOURCE={43992:{"direction":"withdraw","label":44324,"text":"모두 찾기"},42648:{"direction":"deposit","label":42980,"text":"모두 맡기기"}}
const OFFSETS: Array[int]=[43992,44324,42648,42980]
var _owner: WeakRef
var _cart: WeakRef
var _scene: WeakRef
var _states: Dictionary={}

func configure(pack: RefCounted, owner: Control) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256")!=SHA:return _fail("source_storage_batch_original_identity_required")
	if not is_instance_valid(owner) or owner.get_script()==null or owner.get_script().resource_path!="res://scripts/ui/renewal_warehouse.gd" or not owner.has_method("review_original_warehouse_batch"):return _fail("source_storage_batch_actual_owner_required")
	var cart: Variant=owner.get("reviewed_batch")
	if not cart is RefCounted or not is_instance_valid(cart) or cart.get_script()==null or cart.get_script().resource_path!=CART:return _fail("source_storage_batch_actual_reviewed_cart_required")
	var tree: Dictionary=pack.scene(MEMBER)
	for offset: int in SOURCE:
		var button: Dictionary=_find(tree.get("nodeTree",{}),offset)
		var label: Dictionary=_find(button,int(SOURCE[offset].label))
		if button.get("classname")!="Button" or label.get("classname")!="Text" or label.get("options",{}).get("text")!=SOURCE[offset].text:return _fail("source_storage_batch_original_controls_not_admitted")
	_owner=weakref(owner);_cart=weakref(cart)
	var bindings: Dictionary={}
	for offset: int in SOURCE:
		var state: Dictionary=_state(str(SOURCE[offset].direction))
		bindings[offset]={"role":"button","visible":state.visible,"displaystate":state.enabled,"activate":Callable(self,"request_review").bind(str(SOURCE[offset].direction))}
		bindings[int(SOURCE[offset].label)]={"role":"static_source_text"}
		_states[offset]=state
	return {"ok":true,"source_node_offsets":OFFSETS.duplicate(),"bindings":bindings,"original_controller_recovered":false,"all_scope":"only explicit player-staged cart entries","transaction_owner":"World.quote_warehouse_batch/confirm_warehouse_batch; one save after review/confirmation","source_activation_fx_connected":false,"partial_source_scene":true}

func bind_scene(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or scene.source_member!=MEMBER:return _fail("source_storage_batch_actual_scene_required")
	for offset: int in OFFSETS:
		if not scene.source_nodes.has(offset):return _fail("source_storage_batch_presented_controls_required")
	_scene=weakref(scene);return {"ok":true}

func refresh() -> Dictionary:
	var scene: Object=_scene.get_ref() if _scene!=null else null
	if not is_instance_valid(scene) or scene.is_queued_for_deletion() or not scene.is_inside_tree():return _fail("source_storage_batch_live_scene_required")
	for offset: int in SOURCE:
		var state: Dictionary=_state(str(SOURCE[offset].direction))
		if state==_states[offset]:continue
		var result: Dictionary=scene.set_bound_visible(offset,state.visible)
		if result.get("ok",false):result=scene.set_bound_displaystate(offset,state.enabled)
		if not result.get("ok",false):return result
		_states[offset]=state
	return {"ok":true,"states":_states.duplicate(true),"saved_by_ui_adapter":false}

func request_review(direction: String) -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	var scene: Object=_scene.get_ref() if _scene!=null else null
	var state: Dictionary=_state(direction)
	if not state.visible or not state.enabled or not is_instance_valid(scene) or not scene.is_inside_tree() or not scene.is_visible_in_tree() or scene.is_queued_for_deletion():return _fail("source_storage_batch_current_presented_reviewed_cart_required")
	return owner.call("review_original_warehouse_batch",direction)

func _state(direction: String) -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	var cart: Object=_cart.get_ref() if _cart!=null else null
	if not is_instance_valid(owner) or not is_instance_valid(cart) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree() or owner.get("reviewed_batch")!=cart or not owner.get("mode") is OptionButton:return {"visible":false,"enabled":false}
	var selected: int=owner.mode.selected
	var visible: bool=(selected==0 and direction=="deposit") or (selected==1 and direction=="withdraw")
	return {"visible":visible,"enabled":visible and cart.available(direction)}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_find(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"saved_by_ui_adapter":false}
