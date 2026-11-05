extends RefCounted
## Exact original MainMenu components; content roots belong to the host adapter.
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const ROUTES={
 106:{"member":"UI/CsbFile/MainMenu/MainMenu_Attendance.csb","sha256":"d9c7c70da67462220b5309e1df6defed1d03dc9cb011c340e82aec89efc6bed2","button":1856,"panel":140,"text":996,"disabled":204},
 116:{"member":"UI/CsbFile/MainMenu/MainMenu_Pass.csb","sha256":"17003c4674e2198cccdc2a195ad601e956e454a0fd45a8502820ffcca0662154","button":1488,"panel":136,"text":1048,"disabled":196}
}
static func create(pack: RefCounted, button_id: int, source_ui: Object) -> Dictionary:
	if not ROUTES.has(button_id):return {"ok":false,"error":"unsupported_original_menu"}
	if not is_instance_valid(source_ui) or not source_ui.has_method("request_menu"):return {"ok":false,"error":"source_menu_service_unavailable"}
	var route: Dictionary=ROUTES[button_id]
	if pack.manifest.get("files",{}).get(route.member,{}).get("sha256","")!=route.sha256:return {"ok":false,"error":"original_menu_identity_mismatch"}
	var bindings: Dictionary={}
	bindings[route.button]={"role":"button","activate":Callable(source_ui,"request_menu").bind(button_id)}
	bindings[route.panel]={"role":"consume"}
	bindings[route.disabled]={"role":"consume"}
	bindings[route.text]={"role":"static_source_text"}
	var scene=SCENE.new()
	var result: Dictionary=scene.configure(pack,route.member,false,bindings)
	if not result.ok:scene.free();return result
	return {"ok":true,"scene":scene,"menu_button_id":button_id,"content_presented":false}
