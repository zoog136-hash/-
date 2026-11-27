extends SceneTree
## The original 523 합성 결과 window (source_main_fusion_result_window.gd) for
## a fusion the existing rule already rolled. Without arguments (no
## original files): ten results a page, the full-screen tap turns pages then
## closes, a card names itself (the pity reward marked), the HUD guard runs
## once on close, and present_card_reveal uses the window only for fusions
## through the overlay path. Real input: -- --pack=<private original main UI
## pack directory>: Change_Fusion_All mounts the result cards.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_fusion_result_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const STAGE=preload("res://scripts/ui/card_reveal_stage.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

class CellScene extends Node2D:
	var source_nodes: Dictionary = {}

class EffectWindow extends WINDOW:
	var settled: Array[String] = []
	func _node_size(_out: Dictionary, _suffix: String) -> Vector2:
		return Vector2(90, 120)
	func _scene_of(_member: String, _spec: Dictionary, out: Dictionary, _list_key: String = "") -> Dictionary:
		var scene := CellScene.new()
		for index: int in range(PER_PAGE):
			var panel := Node2D.new()
			scene.add_child(panel)
			var origin := Node2D.new()
			origin.name = "SourceContentOrigin"
			panel.add_child(origin)
			scene.source_nodes[index] = panel
			out["Root/Panel/Card_%02d/Panel" % index] = {"chain":[], "offset":index, "member":"fixture"}
		return {"ok":true, "scene":scene}
	func _reveal(_scene: Node2D, _out: Dictionary, cell: String, _grade: String) -> bool:
		settled.append(cell)
		return true

func _check_effect_dispatch() -> void:
	var window := EffectWindow.new()
	window.results = _views(12)
	# The fixture exercises the authored cell attachment without loading pack art.
	for card: Dictionary in window.results: card.grade = ""
	var requested: Array[Dictionary] = []
	var callbacks: Array[Callable] = []
	window.reveal_effect = func(_host: Node2D, _area: Rect2, result: Dictionary, done: Callable) -> bool:
		requested.append(result)
		callbacks.append(done)
		return true
	var page := Node2D.new()
	root.add_child(page)
	check(window._fill(page, {}).shown == 10 and requested.is_empty() and window.settled.is_empty(),
		"fusion mounts all ten sealed and starts no reel")
	window._card(0)
	check(requested.size()==1 and requested[0].id=="source:0" and not window.is_revealed(0),"touch starts only one exact result")
	check(not window._card(0).opened and window._next().waiting,"repeat taps and background presses cannot advance the reel or page")
	callbacks[0].call()
	check(window.settled == ["Panel/Card_00"] and window.is_revealed(0) and not window.is_revealed(1), "only the tapped result settles")
	var redraw := Node2D.new()
	root.add_child(redraw)
	window._fill(redraw, {})
	check(requested.size() == 1 and window.is_revealed(0), "rebuilding the same page does not replay its reels")
	window.page = 1
	window._fill(redraw, {})
	window._card(11)
	check(requested.size() == 2 and requested[-1].pity_reward, "the next page has its own sealed cells and preserves the last pity reward")
	window.close()
	callbacks.clear()
	page.free()
	redraw.free()

func _check_open_all_dispatch() -> void:
	var window := EffectWindow.new()
	window.results = _views(4)
	var order: Array[String] = []
	var frames: Dictionary = {}
	var callbacks: Array[Callable] = []
	window.reveal_effect = func(_host: Node2D, _area: Rect2, card: Dictionary, done: Callable) -> bool:
		order.append(card.id)
		frames[Engine.get_process_frames()] = true
		callbacks.append(done)
		return true
	var page := Node2D.new()
	root.add_child(page)
	window._fill(page, {})
	window._open_all()
	window._open_all()
	check(order.is_empty(), "Open All returns before preparing cards")
	for i: int in range(7): await process_frame
	check(order == ["source:0", "source:1", "source:2", "source:3"] and frames.size() == 4,
		"repeat Open All touches start exactly one result per frame in card order")
	for done: Callable in callbacks: done.call()
	check(window._page_revealed(), "the page becomes ready after every scheduled result settles")
	window.close()
	callbacks.clear()
	page.free()

	var replaced := Node2D.new()
	root.add_child(replaced)
	window._revealed.clear()
	window._fill(replaced, {})
	window.reveal_effect = func(_host: Node2D, _area: Rect2, card: Dictionary, _done: Callable) -> bool:
		order.append(card.id)
		return true
	window._open_all()
	window.close()
	for i: int in range(3): await process_frame
	check(order.size() == 4, "closing the result cancels unopened card jobs")
	replaced.free()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _views(count: int) -> Array:
	var views: Array=[]
	for i: int in range(count):views.append({"id":"source:%d" % i,"name":"카드 %d" % i,"grade":"영웅" if i%2==0 else "희귀"})
	views[-1]["pity_reward"]=true
	return views

func _run() -> void:
	_check_effect_dispatch()
	await _check_open_all_dispatch()
	var hud:=FakeHud.new()
	root.add_child(hud)
	var window=WINDOW.new()
	window._hud=weakref(hud)
	var released: Array=[0]
	window.results=_views(12)
	window.on_closed=func() -> void:released[0]+=1
	check(window.pages()==2,"ten results a page")
	check(not window._card(11).ok,"a card outside the current page cannot be opened")
	window.close()
	check(released[0]==1,"the guard runs once")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("try_open_overlay_window(\"fusion_result\",[views,category,success,release,effect])"),
		"fusion retains the native overlay and passes the stage's result effect")
	var controller: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(controller.contains("func try_open_overlay_window("),"the overlay path keeps the other windows open")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	hud.queue_free()
	print("ORIGINAL_UI_FUSION_RESULT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host:=Node.new()
	var hud:=FakeHud.new()
	host.add_child(hud)
	root.add_child(host)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1200,676)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var parent:=Node2D.new()
	parent.position=Vector2(0,675)
	viewport.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var released: Array=[0]
	var opened: Dictionary=window.open(parent,_views(12),"변신",true,func() -> void:released[0]+=1)
	check(opened.get("handled",false) and int(opened.filled.shown)==10 and int(opened.filled.pages)==2,"Change_Fusion_All mounts the first ten results: "+str(opened).left(300))
	if not opened.get("handled",false):
		viewport.queue_free()
		host.queue_free()
		return
	var original_root: Node2D=window._scene
	var original_page: Node2D=window._cells
	check(window._next().waiting,"a background touch does not open any card")
	await _tap_button(window._scene,window._out,"Nd_ButtonSet/Btn_Open")
	for i: int in range(WINDOW.PER_PAGE+2): await process_frame
	check(window._page_revealed(),"the original Open All button opens the ten results")
	await _tap_button(window._scene,window._out,"Btn_Close")
	var second: Dictionary=window.last_result
	check(second.get("handled",false) and int(second.filled.shown)==2 and window._scene==original_root and not is_instance_valid(original_page),
		"the second page replaces only the cards and preserves the original outer window")
	await _tap_button(window._scene,window._out,"Nd_ButtonSet/Btn_Open")
	for i: int in range(4): await process_frame
	await _tap_button(window._scene,window._out,"Btn_Close")
	check(not window.is_open() and released[0]==1,"the last tap closes")
	await process_frame
	await _check_authored_phases(window,parent,pack)
	viewport.queue_free()
	host.queue_free()

func _tap_button(scene: Node2D, out: Dictionary, path: String) -> void:
	var target: Dictionary=WINDOW._locate(scene,out,path)
	check(target.get("ok",false),"original touch button is bound: "+path)
	if not target.get("ok",false):return
	var hit: Control=target.player.source_nodes[target.offset].get_meta("source_button")._input_area
	for held: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=4
		event.pressed=held
		event.position=hit.get_global_transform_with_canvas()*(hit.size*0.5)
		scene.get_viewport().push_input(event,true)
		await process_frame

func _check_authored_phases(window: RefCounted, parent: Node2D, pack: RefCounted) -> void:
	var record: Dictionary={"id":"fixture-legend","name":"결과","grade":"전설"}
	var effect: Callable=STAGE.play_result_cell.bind("변신",true,true,[],{},pack)
	for upgraded: bool in [false,true]:
		record["fusion_success"]=upgraded # individual outcome in a successful batch
		var response: Dictionary=window.open(parent,[record],"변신",true,Callable(),effect)
		if not response.get("handled",false):
			check(false,"mount exact UI with a single fusion result")
			return
		var result_scene: Node2D=window._scene
		check(result_scene.find_child("CardRevealEffect",true,false)==null and response.filled.backs==1,"one authored back at rest before input")
		check(result_scene.find_child("SourceAwardFace",true,false)==null and
			WINDOW.GradeFx.project(window,window._cells,window._cell_out,"Panel/Card_00/Fx_Outline_Front")==null,
			"the sealed card starts with neither a face nor an instantiated grade outline")
		await _tap_button(window._cells,window._cell_out,"Panel/Card_00/Btn_Card")
		var face: Node2D=result_scene.find_child("SourceAwardFace",true,false)
		var reel: Control=result_scene.find_child("CardRevealEffect",true,false)
		if not is_instance_valid(face) or not is_instance_valid(reel):
			check(false,"mount authored face and separate reel")
			return
		var panel: Node2D=face.get_parent()
		var center: Vector2=result_scene.to_local(panel.global_position)
		check(center.length()<0.5,"one result uses the existing page center")
		var cell: Node2D=panel.get_parent()
		var outline: Node2D=cell.find_child("Fx_Outline_Front*",true,false)
		check(not face.visible and (outline==null or not outline.is_visible_in_tree()),"spinner has no final grade face or outline")
		var bolt: Node2D=reel.find_child("SourceCardLightning",true,false)
		check(reel.get_node_or_null("MetalRim")==null,"native reel contains no fixed gold frame")
		check((bolt!=null)==upgraded,"only a successful fusion builds the original discharge")
		if bolt!=null:
			check(not bolt.visible and bolt.source_member==WINDOW.GradeFx.ACTIVE_GRADE["전설"],"exact lightning is initially hidden")
			check(bolt.get_parent().clip_contents,"native discharge stays inside the card clip")
			await create_timer(reel.lightning_at()+0.25).timeout
			var sprite_node: Node2D=bolt.source_nodes.get(WINDOW.GradeFx.LIGHTNING_SPRITES["전설"])
			var sprite: Sprite2D=sprite_node.get_meta("source_sprite") if sprite_node!=null and sprite_node.has_meta("source_sprite") else null
			check(bolt.is_visible_in_tree() and bolt.playback_status().playing and sprite!=null and sprite.texture!=null and not face.visible,"verified atlas pixels play during the success reel")
			if DisplayServer.get_name()!="headless":await _check_lightning_pixels(bolt)
		await create_timer(maxf(0.05,reel.reveal_at()-reel.clock+0.15)).timeout
		check(not is_instance_valid(reel) and face.is_visible_in_tree(),"settled result has its grade face")
		var settled_outline: Node2D=WINDOW.GradeFx.project(window,window._cells,window._cell_out,"Panel/Card_00/Fx_Outline_Front")
		check(settled_outline!=null and settled_outline.is_visible_in_tree() and settled_outline.playback_status().playing,
			"the original grade outline mounts and plays after settling")
		window.close()
		await process_frame
	var batch: Array=[]
	for result: Dictionary in [{"fusion_success":true},{"fusion_success":false},{"fusion_success":true,"pity_reward":true}]:
		var entry:=record.duplicate()
		entry.merge(result,true)
		batch.append(entry)
	window.open(parent,batch,"변신",true,Callable(),effect)
	window._card(1)
	var reels: Array=window._scene.find_children("CardRevealEffect","Control",true,false)
	check(reels.size()==1 and not reels[0].record.fusion_success,"one result tap leaves the others sealed")
	window._open_all()
	for i: int in range(5): await process_frame
	reels=window._scene.find_children("CardRevealEffect","Control",true,false)
	check(reels.size()==3,"one native reel per result in the mixed batch")
	for reel: Control in reels:
		var upgraded: bool=reel.record.fusion_success and not reel.record.get("pity_reward",false)
		check((reel.find_child("SourceCardLightning",true,false)!=null)==upgraded,"the mixed batch uses each card's own success and pity flags")
	window.close()
	await process_frame

## Compare two draws of the same paused game frame. Toggling only the
## original CSB player isolates its pixels from the card's own illumination.
func _check_lightning_pixels(bolt: Node2D) -> void:
	paused=true
	var clip:=bolt.get_parent() as Control
	var viewport:=bolt.get_viewport()
	await RenderingServer.frame_post_draw
	var lit:=viewport.get_texture().get_image()
	bolt.hide()
	await RenderingServer.frame_post_draw
	var hidden:=viewport.get_texture().get_image()
	bolt.show()
	paused=false
	var bounds:=clip.get_global_rect()
	var first:=Vector2i(bounds.position.floor())
	var area:=Rect2i(first,Vector2i(bounds.end.ceil())-first).intersection(Rect2i(Vector2i.ZERO,lit.get_size()))
	var changed: int=0
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			if lit.get_pixel(x,y)!=hidden.get_pixel(x,y):changed+=1
	check(changed>0,"the original success discharge changes rendered pixels inside the card")
	lit.fill_rect(area,Color.TRANSPARENT)
	hidden.fill_rect(area,Color.TRANSPARENT)
	var same_outside: bool=lit.get_data()==hidden.get_data()
	check(same_outside,"hiding the bolt leaves all pixels outside the card identical")
	print("FUSION_LIGHTNING_PIXELS ",JSON.stringify({"inside_changed":changed,"outside_identical":same_outside}))
