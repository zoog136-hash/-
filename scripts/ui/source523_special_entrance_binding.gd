extends RefCounted
## Image-owner adapter for a UI-owner mounted original ImageView.
## This creates no node and establishes no source parent/list registration.
const IMAGES = preload("res://scripts/ui/source523_dungeon_images.gd")
const MEMBER = "UI/Mission/Mission_DungeonSpecial_Btn.csb"
const SHA = "289353c38b5f8efb7c3caf4913640819864f72c2868c327c71d97a5d4231462d"
const OFFSET = 28700
var _owner: WeakRef
var _player: WeakRef
var last_result: Dictionary = {}

func bind(owner: Node, registered_player: Node) -> Dictionary:
	close()
	if not is_instance_valid(owner) or not is_instance_valid(registered_player):return _result(false,"source_special_live_receiver_required")
	var script: Variant=owner.get_script()
	if not script is Script or script.resource_path!="res://scripts/dungeons/source_dungeon_view.gd" or not owner.has_method("original_selected_special_entrance") or not owner.has_signal("original_special_selection_changed"):return _result(false,"source_special_selection_owner_api_required")
	var renderer: Variant=registered_player.get_script()
	if not renderer is Script or renderer.resource_path!="res://scripts/ui/original_ui/sprite_scene.gd" or not registered_player.has_method("clear_bound_source_image"):return _result(false,"source_special_image_view_receiver_api_required")
	if not _receiver_identity(registered_player):return _result(false,"source_special_exact_original_receiver_required")
	if not owner.is_inside_tree() or not registered_player.is_inside_tree() or not owner.is_ancestor_of(registered_player):return _result(false,"source_special_owner_mounted_receiver_required")
	_owner=weakref(owner)
	_player=weakref(registered_player)
	owner.connect("original_special_selection_changed",_selection_changed)
	owner.tree_exiting.connect(_owner_exiting)
	registered_player.tree_exiting.connect(_receiver_exiting)
	return refresh()

func refresh() -> Dictionary:
	var owner: Node=_owner.get_ref() if _owner!=null else null
	var player: Node=_player.get_ref() if _player!=null else null
	if not is_instance_valid(owner) or not is_instance_valid(player):return _result(false,"source_special_binding_closed")
	if owner.is_queued_for_deletion() or player.is_queued_for_deletion() or not owner.is_inside_tree() or not player.is_inside_tree() or not owner.is_ancestor_of(player):
		_clear()
		return _result(false,"source_special_owner_mounted_receiver_required")
	var selected: Variant=owner.call("original_selected_special_entrance")
	if not selected is Dictionary or not selected.get("ok",false):
		_clear()
		return _result(false,"source_special_current_selection_unavailable")
	var target: Dictionary=selected.get("original_ui_target",{}).get("original_target",{})
	if not _matches_receiver(player,target):
		_clear()
		return _result(false,"source_special_exact_original_receiver_required")
	# Resolve only after the actual selected owner and its original receiver
	# agree. The provider rechecks the full current row and original asset join.
	var image: Dictionary=IMAGES.describe_selected_special(owner)
	if not image.get("ok",false) or image.get("special_dungeon_id")!=selected.get("special_dungeon_id") or image.get("selected_index")!=selected.get("selected_index"):
		_clear()
		return _result(false,str(image.get("reason","source_special_current_selection_changed")))
	var assigned: Dictionary=player.call("set_bound_source_asset_result",OFFSET,image)
	if not assigned.get("ok",false) or not assigned.get("texture_assigned",false):
		_clear()
		return _result(false,str(assigned.get("error","source_special_image_assignment_failed")))
	var shown: Dictionary=player.call("set_bound_visible",OFFSET,true)
	if not shown.get("ok",false):
		_clear()
		return _result(false,str(shown.get("error","source_special_image_visibility_failed")))
	var result: Dictionary=_result(true,"original_selected_entrance_assigned")
	result["pixels_assigned"]=true
	result["special_dungeon_id"]=image.special_dungeon_id
	result["selected_index"]=image.selected_index
	result["provenance"]=image.provenance.duplicate(true)
	result["original_node_transform_retained"]=assigned.get("original_node_transform_retained",false)
	return result

func _matches_receiver(player: Node, target: Dictionary) -> bool:
	if not _receiver_identity(player):return false
	if not target.get("ok",false) or target.get("member")!=MEMBER or target.get("source_sha256")!=SHA or target.get("node_offset")!=OFFSET or target.get("node_type")!="ImageView" or target.get("node_name")!="Img_Special":return false
	if player.get("inspection_only")!=false or player.get("source_member")!=MEMBER or player.get("source_pack")!=target.get("pack"):return false
	var pack: Variant=target.get("pack")
	if pack==null or pack.manifest_sha256!=target.get("manifest_sha256") or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256")!=SHA:return false
	var nodes: Variant=player.get("source_nodes")
	if not nodes is Dictionary:return false
	var node: Variant=nodes.get(OFFSET)
	if not is_instance_valid(node) or not node is Node2D or not node.is_inside_tree() or node.is_queued_for_deletion():return false
	var identity: Dictionary=node.get_meta("original_ui_source",{})
	return identity.get("scene")==MEMBER and identity.get("node_offset")==OFFSET and identity.get("manifest_sha256")==pack.manifest_sha256 and node.get_meta("source_asset_slot",false)==true and node.has_meta("source_image_options") and node.get_meta("source_image_widget",{})==target.get("authored_widget")

func _receiver_identity(player: Node) -> bool:
	if player.get("source_member")!=MEMBER or player.get("inspection_only")!=false:return false
	var pack: Variant=player.get("source_pack")
	return pack!=null and pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256")==SHA

func _selection_changed(selection: Dictionary) -> void:
	# A rebuild invalidates before replacing the old rows. Clear immediately
	# rather than querying an old selection during that invalidation callback.
	if not selection.get("ok",false):
		_clear()
		_result(false,"source_special_selection_invalidated")
		return
	# A positive notice is a wakeup, never identity authority: requery the owner.
	refresh()

func _clear() -> void:
	var player: Node=_player.get_ref() if _player!=null else null
	if is_instance_valid(player) and _receiver_identity(player):player.call("clear_bound_source_image",OFFSET)

func _owner_exiting() -> void:
	close()

func _receiver_exiting() -> void:
	close()

func close() -> void:
	_clear()
	var owner: Node=_owner.get_ref() if _owner!=null else null
	var player: Node=_player.get_ref() if _player!=null else null
	if is_instance_valid(owner):
		if owner.is_connected("original_special_selection_changed",_selection_changed):owner.disconnect("original_special_selection_changed",_selection_changed)
		if owner.tree_exiting.is_connected(_owner_exiting):owner.tree_exiting.disconnect(_owner_exiting)
	if is_instance_valid(player) and player.tree_exiting.is_connected(_receiver_exiting):player.tree_exiting.disconnect(_receiver_exiting)
	_owner=null
	_player=null
	_result(false,"source_special_binding_closed")

func _result(ok: bool, status: String) -> Dictionary:
	last_result={"ok":ok,"status":status,"role":IMAGES.ROLE,"pixels_assigned":false,
		"source_parent_registration_established":false,"actual_game_consumption_observed":false,
		"missing_registration":"UI owner: Panel392 to ListView_Daily2560 insertion"}
	return last_result
