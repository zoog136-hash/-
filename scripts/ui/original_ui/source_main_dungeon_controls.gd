extends RefCounted
## Original dungeon outside-close input only. Existing content and service
## own selection, entry, rewards, pending saves and every dungeon rule.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const OWNER_SCRIPT="res://scripts/dungeons/source_dungeon_view.gd"
const PARENT="UI/MissionScene.csb"
const PARENT_SHA="dd8ecf3272d9ef3484bdd7eea2336abc54923553d3019c6888706872a5b76142"
const MEMBER="UI/Mission/Mission_Dungeon_All.csb"
const SHA256="d95b96227ea95d38e95b4d351977f6b3794cc237f4ef194457959e8626ba2be3"
const PROJECT=2384
const CLOSE=5540
var _pack: RefCounted
var _hud: WeakRef
var _scene: Node2D
var _owner: WeakRef
var _attempted_owner: WeakRef
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> void:
	_pack=pack
	_hud=weakref(hud)

func refresh(parent: Node) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var owner: Control=_current_owner(hud)
	if owner==null:
		close()
		_attempted_owner=null
		return {"ok":true,"handled":false}
	if is_instance_valid(_scene) and _owner!=null and _owner.get_ref()==owner:return last_result.duplicate(true)
	close()
	if _attempted_owner!=null and _attempted_owner.get_ref()==owner:return last_result.duplicate(true)
	_attempted_owner=weakref(owner)
	if not is_instance_valid(parent):return _fail("source_dungeon_close_actual_mount_required")
	for spec: Array in [[PARENT,PARENT_SHA],[MEMBER,SHA256]]:
		if _pack==null or _pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1]:return _fail("source_dungeon_close_original_identity_required")
	var source: Dictionary=_pack.layout_source(PARENT)
	if source.get("_source_sha256")!=PARENT_SHA:return _fail("source_dungeon_close_original_parent_required")
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_project(_pack,PARENT,PROJECT,{CLOSE:{"role":"button","activate":Callable(self,"_close_requested")}},[CLOSE])
	if not result.get("ok",false):scene.free();last_result=result;return result
	parent.add_child(scene)
	_scene=scene
	_owner=weakref(owner)
	last_result={"ok":true,"handled":true,"outside_close_connected":true,"member":MEMBER,"offset":CLOSE,"partial_source_scene":true,"complete_screen_contract":false,"entry_or_reward_actions_connected":false,"game_state_written":false}
	return last_result.duplicate(true)

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_owner=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():previous.hide();previous.queue_free()

func blocks_point(point: Vector2) -> bool:
	if not point.is_finite() or not is_instance_valid(_scene) or _scene.is_queued_for_deletion():return false
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if _owner==null or _owner.get_ref()!=_current_owner(hud):return false
	var node: Variant=_scene.source_nodes.get(CLOSE)
	var button: Variant=(node.get_meta("source_button") if node.has_meta("source_button") else null) if is_instance_valid(node) else null
	var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if not control is Control or not control.is_visible_in_tree():return false
	return Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)

func _close_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var owner: Control=_current_owner(hud)
	if owner==null or _owner==null or _owner.get_ref()!=owner:return _fail("source_dungeon_close_current_owner_changed")
	# No leave/stop/cancel service call is added by dismissing a menu.
	hud.call("_close_workspace")
	close()
	return {"ok":true,"dispatched":true,"method":"existing HUD._close_workspace","game_state_written":false}

static func _current_owner(hud: Object) -> Control:
	if not is_instance_valid(hud) or not hud.has_method("_close_workspace") or hud.get("active_section")!="source_dungeons":return null
	var workspace: Variant=hud.get("workspace")
	if not workspace is Control or not is_instance_valid(workspace) or not workspace.is_visible_in_tree():return null
	var owner: Node=workspace.find_child("SourceDungeonView",true,false)
	if not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner is Control or not owner.is_visible_in_tree():return null
	var script: Script=owner.get_script()
	if script==null or script.resource_path!=OWNER_SCRIPT:return null
	return owner as Control

func _fail(code: String) -> Dictionary:
	last_result={"ok":false,"handled":false,"code":code}
	return last_result.duplicate(true)
