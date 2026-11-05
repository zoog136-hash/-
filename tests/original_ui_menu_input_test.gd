extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const ADAPTER=preload("res://scripts/ui/original_ui/source_menu_adapter.gd")
class ServiceProbe extends RefCounted:
	var calls: Array=[]
	func request_menu(id: int) -> Dictionary:
		calls.append(id)
		return {"ok":false,"code":"presentation_unavailable"}
var errors: Array[String]=[]
var checks: int=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:call_deferred("run")
func click(viewport: SubViewport, at: Vector2, down: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=down
	event.position=at
	viewport.push_input(event,true)
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var pack=PACK.new()
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	check(pack.open(args[0],receipt.manifest_sha256).ok,"pack")
	var probe:=ServiceProbe.new()
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(320,240)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	check(not ADAPTER.create(pack,999,probe).ok,"unknown route rejected")
	for id: int in [106,116]:
		var result: Dictionary=ADAPTER.create(pack,id,probe)
		check(result.ok,"configure "+str(result))
		if not result.ok:continue
		var scene: Node2D=result.scene
		viewport.add_child(scene)
		scene.position=Vector2(100,150)
		await process_frame
		await RenderingServer.frame_post_draw
		var button=scene.source_nodes[ADAPTER.ROUTES[id].button].get_meta("source_button")
		var responses: Array=[]
		button.activation_result.connect(func(r: Dictionary):responses.append(r))
		var at: Vector2=button._input_area.get_global_rect().get_center()
		check(scene.unresolved_bindings.is_empty(),"all menu roles bound")
		var before: int=probe.calls.size()
		click(viewport,at,true)
		check(button.current_state=="pressed","pressed visual")
		check(probe.calls.size()==before,"press does not call")
		click(viewport,at,false)
		check(button.current_state=="normal","release visual")
		check(probe.calls.size()==before+1 and probe.calls.back()==id,"exact menu dispatch")
		check(responses.size()==1 and responses[0].get("code")=="presentation_unavailable","service failure preserved")
		click(viewport,at,true)
		scene.visible=false
		click(viewport,at,false)
		scene.visible=true
		check(probe.calls.size()==before+1 and not button._armed,"hidden press cancels")
		button.set_source_state("disabled")
		click(viewport,at,true);click(viewport,at,false)
		check(probe.calls.size()==before+1,"disabled no call")
		button.set_source_state("normal")
		scene.source_nodes[ADAPTER.ROUTES[id].disabled].visible=true
		click(viewport,at,true);click(viewport,at,false)
		check(probe.calls.size()==before+1,"original disabled overlay blocks input")
		scene.queue_free()
		await process_frame
	print("ORIGINAL_MENU_INPUT "+JSON.stringify({"checks":checks,"errors":errors,"scope":"original CSB and viewport input with service probe; no real claim/save or game integration"}))
	quit(0 if errors.is_empty() else 1)
