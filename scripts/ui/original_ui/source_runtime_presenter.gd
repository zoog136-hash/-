extends Node
## Nonvisual bridge from runtime.bind_presentation to the original CSB player.
## The UI owner supplies exact source root/node contracts and an existing game
## mount. A menu component or a guessed filename cannot become a content root.
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const SESSION=preload("res://scripts/ui/original_ui/source_service_session.gd")
var _runtime: WeakRef
var _pack: RefCounted
var _routes: Dictionary={}
var _scene: Node2D
var _session: RefCounted

func attach(runtime: Object, pack: RefCounted) -> Dictionary:
	if not is_instance_valid(runtime) or not runtime.has_method("bind_presentation"):return {"ok":false,"code":"source_runtime_unavailable"}
	if pack==null or pack.manifest.is_empty():return {"ok":false,"code":"source_pack_unavailable"}
	_release_local()
	_runtime=weakref(runtime)
	_pack=pack
	runtime.call("bind_presentation",Callable(self,"present"))
	return {"ok":true}

func register_content(section: String, focus_kind: String, member: String, source_sha256: String, mount: Node2D, binding_factory: Callable) -> Dictionary:
	if _pack==null or not is_instance_valid(mount) or not binding_factory.is_valid():return {"ok":false,"code":"source_content_contract_missing"}
	if source_sha256.length()!=64 or _pack.manifest.get("files",{}).get(member,{}).get("sha256","")!=source_sha256:return {"ok":false,"code":"source_content_identity_mismatch"}
	if member in ["UI/CsbFile/MainMenu/MainMenu_Attendance.csb","UI/CsbFile/MainMenu/MainMenu_Pass.csb"]:return {"ok":false,"code":"source_menu_is_not_content_root"}
	if not _routes.has(section):_routes[section]={}
	_routes[section][focus_kind]={"member":member,"sha256":source_sha256,"mount":weakref(mount),"bindings":binding_factory}
	return {"ok":true}

func present(section: String) -> Dictionary:
	var runtime: Object=_runtime.get_ref() if _runtime!=null else null
	if runtime==null:return {"ok":false,"code":"source_runtime_unavailable"}
	var service: Object=runtime.get("source_ui")
	if not is_instance_valid(service):return {"ok":false,"code":"source_service_unavailable"}
	var model: Dictionary=service.call("snapshot")
	if str(model.get("section",""))!=section:return {"ok":false,"code":"source_model_not_prepared"}
	var focus: String=str(model.get("focus",{}).get("kind",""))
	var route: Dictionary=_routes.get(section,{}).get(focus,{})
	if route.is_empty():return {"ok":false,"code":"presentation_unavailable","reason":"original_content_contract_missing"}
	var mount: Node2D=route.mount.get_ref()
	if not is_instance_valid(mount) or not mount.is_inside_tree():return {"ok":false,"code":"source_mount_unavailable"}
	if _pack.manifest.get("files",{}).get(route.member,{}).get("sha256","")!=route.sha256:return {"ok":false,"code":"source_content_identity_mismatch"}
	var session=SESSION.new()
	var bound: Dictionary=session.bind_prepared(service,model)
	if not bound.ok:return bound
	var bindings: Variant=route.bindings.call(model.duplicate(true),session)
	if not bindings is Dictionary:
		session.invalidate();return {"ok":false,"code":"source_node_contract_missing"}
	var scene=SCENE.new()
	var configured: Dictionary=scene.configure(_pack,str(route.member),false,bindings)
	if not configured.ok:
		scene.free();session.invalidate();return configured
	_release_local()
	_scene=scene
	_session=session
	mount.add_child(scene)
	return {"ok":true,"source":str(route.member),"transaction_performed":false}

func close_content() -> Dictionary:
	var result: Dictionary=_session.close() if _session!=null else {"ok":true,"closed":true}
	_release_local()
	return result

func _release_local() -> void:
	if _session!=null:_session.invalidate()
	_session=null
	if is_instance_valid(_scene):_scene.queue_free()
	_scene=null

func _exit_tree() -> void:
	# A freed Callable becomes unavailable to the runtime. Do not overwrite a
	# replacement presenter's binding or alter gameplay state during teardown.
	_release_local()
