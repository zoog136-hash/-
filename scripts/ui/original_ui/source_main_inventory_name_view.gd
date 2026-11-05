extends RefCounted
## Only the current bag owner's timed name hint, in an original header scope.
## This does not open item details or render a substitute detail body.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Bindings=preload("res://scripts/ui/original_ui/source_main_inventory_name_bindings.gd")
var _pack: RefCounted
var _bag: WeakRef
var _scene: Node2D
var _child: Node2D
var _model: Dictionary={}

func configure(pack: RefCounted, bag: Control) -> Dictionary:
	var source: Dictionary=Bindings.source_contract(pack)
	if not source.get("ok",false):return source
	_pack=pack
	_bag=weakref(bag)
	return {"ok":true,"partial_source_scene":true,"full_detail_connected":false}

func refresh(parent: Node) -> Dictionary:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if bag==null or not is_instance_valid(parent):close();return {"ok":false,"code":"source_inventory_name_owner_or_mount_unavailable"}
	var model: Dictionary=Bindings.snapshot(bag)
	if not model.get("ok",false):close();return model
	var reference: Variant=bag.get("item_name_reference")
	if not model.visible or not reference is String or reference.is_empty() or bag.get("selected_item")!=reference or bag.get("detail_active")==true:
		close()
		return {"ok":true,"handled":false,"owner_name_not_visible":true}
	model["reference"]=reference
	if is_open():
		if model!=_model:
			var updated: Dictionary=Bindings.refresh(_child,bag)
			if not updated.get("ok",false):close();return updated
			_model=model
		return {"ok":true,"handled":true,"reference":reference,"partial_source_scene":true,"full_detail_connected":false}
	var contract: Dictionary=Bindings.build(_pack,bag,Callable(self,"_hide_name"))
	if not contract.get("ok",false):return contract
	var scope: Array[int]=[]
	scope.assign(contract.source_node_offsets)
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,Bindings.PARENT_MEMBER,[Bindings.PARENT_PROJECT],{Bindings.PARENT_PROJECT:{"role":"project","visible":true,"source_node_offsets":scope,"bindings":contract.bindings}})
	if not result.get("ok",false):next.free();return result
	var child: Dictionary=next.project_player([Bindings.PARENT_PROJECT])
	if not child.get("ok",false):next.free();return child
	# The owner explicitly shows its timed name. Activate the existing
	# Inventory_ToolTip_Layout at its authored parent position; no fit/offset,
	# full detail pane, preview icon or opening animation is substituted.
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_child=child.player
	_model=model
	return {"ok":true,"handled":true,"reference":reference,"partial_source_scene":true,"full_detail_connected":false,"owner_timer_retained":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func presentation() -> Dictionary:
	return {"scene":_scene,"partial_source_scene":true,"full_detail_connected":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_child=null
	_model.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _hide_name() -> Dictionary:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if bag!=null and bag.has_method("_hide_item_name"):bag.call("_hide_item_name")
	close()
	return {"ok":true,"name_hidden":true,"selection_cleared":false,"game_state_written":false}
