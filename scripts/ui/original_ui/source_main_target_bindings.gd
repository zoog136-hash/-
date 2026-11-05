extends RefCounted
## The existing World selection supplies the displayed target name. This
## never picks a target, changes combat, or interprets social/PK controls.
const MEMBER="UI/Main/Set_T_Cen_TargetLayout.csb"
const SHA256="bf0da029e6bc3ce8fd4d4a89ff65c47b5c906b5b75776e8581414f2a2961f9ad"
const SOURCE_OFFSETS: Array[int]=[12300,8876]
const ROOT=392
const NAME_CONTAINER=8100
const NAME_TEXT=8876

static func selected_name(world: Node) -> Dictionary:
	if not is_instance_valid(world):return _fail("source_main_target_world_unavailable")
	var selected: Variant=world.get("selected_monster")
	if not is_instance_valid(selected):return {"ok":true,"visible":false,"name":""}
	if selected.get("dead")==true:return {"ok":true,"visible":false,"name":""}
	var target_name: Variant=selected.get("monster_name")
	if not target_name is String:return _fail("source_main_target_existing_name_unavailable")
	return {"ok":true,"visible":true,"name":target_name}

static func build(pack: RefCounted, model: Dictionary) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_target_identity_mismatch")
	if not model.get("ok",false) or not model.get("visible") is bool or not model.get("name") is String:return _fail("source_main_target_existing_selection_required")
	# Preview-hidden containers receive the host's actual target visibility.
	# Source position/size/anchor/color stay unchanged; no target mode or
	# original-client open animation is inferred from selection existence.
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":{ROOT:{"visible":true},NAME_CONTAINER:{"visible":model.visible},NAME_TEXT:{"role":"source_text","text":model.name}},"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":["original_target_type_mode_switches","original_social_clan_party_pk_alignment_actions","original_target_open_close_animation_policy"]}

static func refresh(scene: Node2D, model: Dictionary) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MEMBER:return _fail("source_main_target_scene_mismatch")
	if not model.get("ok",false):return model
	var result: Dictionary=scene.set_bound_text(NAME_TEXT,model.name)
	if not result.get("ok",false):return result
	return scene.set_bound_visible(NAME_CONTAINER,model.visible)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
