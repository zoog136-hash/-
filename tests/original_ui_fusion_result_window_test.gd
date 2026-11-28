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
const BLEND=preload("res://scripts/ui/original_ui/source_blend.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

class OutlinePack extends SOURCE_PACK:
	var unused_outline_requests: int=0
	func texture(reference: Dictionary,cocos_pixels: bool=false) -> Texture2D:
		# The unplayed Fx_Unique_Loop uses this sheet. Refuse it to ensure it
		# cannot block an unrelated 전설 result.
		if str(reference.get("path","")).begins_with("Fx_Unique_"):
			unused_outline_requests+=1
			return null
		return super.texture(reference,cocos_pixels)

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

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:failures.append(label)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func _views(count: int) -> Array:
	var views: Array=[]
	for i: int in range(count):views.append({"id":"source:%d" % i,"name":"카드 %d" % i,"grade":"영웅" if i%2==0 else "희귀"})
	views[-1]["pity_reward"]=true
	return views

func _run() -> void:
	_check_effect_dispatch()
	_check_outline_entry_key()
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
		if value=="--fixed-blend":BLEND.screen_copy_available=false
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	hud.queue_free()
	print("ORIGINAL_UI_FUSION_RESULT_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _check_outline_entry_key() -> void:
	var keys: Array=[]
	for at: int in [25,10,25,50]:keys.append({"textureFrame":{"_type":"TextureFrame","frameIndex":at}})
	var scene=WINDOW.GradeFx.Scene
	check(scene._texture_key_at(keys,0)==1,"an entry before any key uses the earliest key")
	check(scene._texture_key_at(keys,30)==2,"an entry between keys uses the last matching predecessor")
	check(scene._texture_key_at([],30)==-1,"an empty track uses its serialized sprite texture")

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack:=OutlinePack.new()
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
	var other_grades: Array=_views(12)
	for card: Dictionary in other_grades:
		if card.grade=="희귀":card.grade="고급"
	var opened: Dictionary=window.open(parent,other_grades,"변신",true,func() -> void:released[0]+=1)
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
	check(pack.unused_outline_requests==0,"non-rare results do not request the rare sheet")
	var rare_pack:=SOURCE_PACK.new()
	check(rare_pack.open(pack_dir,str(receipt.manifest_sha256)).get("ok",false),"the original rare outline pack opens")
	check(window.configure(rare_pack,hud).get("ok",false),"the result window uses that pack")
	var rare_results: Array=[{"id":"rare","name":"희귀 카드","grade":"희귀","fusion_success":true},
		{"id":"other","name":"희귀 카드","grade":"희귀","fusion_success":false}]
	var rare_effect: Callable=STAGE.play_result_cell.bind("변신",true,true,[],{},rare_pack)
	var rare_opened: bool=window.open(parent,rare_results,"변신",true,Callable(),rare_effect).get("handled",false)
	check(rare_opened,"the window mounts a real rare result")
	if rare_opened:
		var path: String="Panel/Card_00/Fx_Outline_Front"
		check(WINDOW.GradeFx.project(window,window._cells,window._cell_out,path)==null,"a sealed rare result does not instantiate its outline")
		await _tap_button(window._cells,window._cell_out,"Panel/Card_00/Btn_Card")
		var reel: Control=window._scene.find_child("CardRevealEffect",true,false)
		if not check(reel!=null,"opening the rare card mounts its result reel"):
			window.close()
			viewport.queue_free()
			host.queue_free()
			return
		var bolt: AnimatedSprite2D=reel.find_child("SourceCardLightning",true,false) as AnimatedSprite2D
		if check(bolt!=null and not bolt.visible and bolt.get_parent().clip_contents,"opening one successful rare card prepares its clipped blue discharge"):
			check(bolt.sprite_frames.get_frame_count(WINDOW.GradeFx.CLIP)==WINDOW.GradeFx.RARE_LIGHTNING_FRAMES,"all original rare discharge frames are used")
			await create_timer(maxf(0.05,reel.lightning_at()-reel.clock+0.22)).timeout
			check(bolt.is_visible_in_tree() and bolt.is_playing() and bolt.frame>0 and not window.is_revealed(0),"the original blue discharge plays before the rare result settles")
			if DisplayServer.get_name()!="headless":await _check_lightning_pixels(bolt,true)
		await create_timer(maxf(0.05,reel.reveal_at()-reel.clock+0.15)).timeout
		var outline: Node2D=WINDOW.GradeFx.project(window,window._cells,window._cell_out,path)
		check(outline!=null and outline.is_visible_in_tree() and outline.playback_status().clip==WINDOW.GradeFx.RARE_OUTLINE_CLIP,"only the opened rare card plays the authored blue outline")
		check(window.is_revealed(0) and not window.is_revealed(1),"the adjacent result remains face down")
		await _tap_button(window._cells,window._cell_out,"Panel/Card_01/Btn_Card")
		check(window._scene.find_child("SourceCardLightning",true,false)==null,"the adjacent failed rare result does not borrow the successful card's discharge")
		window.close()
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
			check(is_equal_approx(reel.lightning_at(),2.4) and is_equal_approx(reel.reveal_at()-reel.lightning_at(),2.0),
				"success cues the discharge at 2.4 s and keeps the two-second reveal beat")
			var first_shown: Array[float]=[]
			bolt.visibility_changed.connect(func() -> void:first_shown.append(reel.clock),CONNECT_ONE_SHOT)
			await create_timer(maxf(0.05,reel.lightning_at()-reel.clock-0.3)).timeout
			check(not bolt.visible and not face.visible,"the reel stays sealed before the success cue")
			await create_timer(maxf(0.05,reel.lightning_at()-reel.clock+0.25)).timeout
			var sprite_node: Node2D=bolt.source_nodes.get(WINDOW.GradeFx.LIGHTNING_SPRITES["전설"])
			var sprite: Sprite2D=sprite_node.get_meta("source_sprite") if sprite_node!=null and sprite_node.has_meta("source_sprite") else null
			check(bolt.is_visible_in_tree() and bolt.playback_status().playing and sprite!=null and sprite.texture!=null and not face.visible,"verified atlas pixels play during the success reel")
			check(first_shown.size()==1 and first_shown[0]>=2.4 and first_shown[0]<2.7,"the playing reel dispatches the earlier cue")
			print("FUSION_LIGHTNING_TIMING ",JSON.stringify({"first_shown":first_shown,"reveal_at":reel.reveal_at()}))
			if DisplayServer.get_name()!="headless":await _check_lightning_pixels(bolt)
		else:
			check(is_equal_approx(reel.reveal_at(),4.9),"the failed fusion keeps its result timing")
		await create_timer(maxf(0.05,reel.reveal_at()-reel.clock+0.15)).timeout
		check(not is_instance_valid(reel) and face.is_visible_in_tree(),"settled result has its grade face")
		var settled_outline: Node2D=WINDOW.GradeFx.project(window,window._cells,window._cell_out,"Panel/Card_00/Fx_Outline_Front")
		check(settled_outline!=null and settled_outline.is_visible_in_tree() and settled_outline.playback_status().playing,
			"the original grade outline mounts and plays after settling")
		if settled_outline!=null:
			check(is_equal_approx(settled_outline.modulate.a,0.55),"the settled outline alone uses the lower opacity")
			check(settled_outline.playback_status().clip=="Fx_Epic_Loop" and
				not settled_outline.play("Fx_Unique_Loop",true).get("ok",false),"the loaded outline permits only the selected grade clip")
			if upgraded and DisplayServer.get_name()!="headless":await _check_outline_pixels(settled_outline)
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
func _check_lightning_pixels(bolt: Node2D, require_blue: bool=false) -> void:
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
	var blue: int=0
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			var after: Color=lit.get_pixel(x,y)
			var before: Color=hidden.get_pixel(x,y)
			if after!=before:changed+=1
			if require_blue and after.b-before.b>0.06 and after.b-before.b>after.r-before.r+0.03:blue+=1
	check(changed>0,"the original success discharge changes rendered pixels inside the card")
	if require_blue:check(blue>20,"the rare discharge adds visible blue inside the card")
	lit.fill_rect(area,Color.TRANSPARENT)
	hidden.fill_rect(area,Color.TRANSPARENT)
	var same_outside: bool=lit.get_data()==hidden.get_data()
	check(same_outside,"hiding the bolt leaves all pixels outside the card identical")
	print("FUSION_LIGHTNING_PIXELS ",JSON.stringify({"inside_changed":changed,"outside_identical":same_outside,"blue_changed":blue}))

func _check_outline_pixels(outline: Node2D) -> void:
	paused=true
	var viewport:=outline.get_viewport()
	outline.seek_frame(24.0) # Inside the authored Fx_Epic_Loop (2–47).
	await RenderingServer.frame_post_draw
	var dim:=viewport.get_texture().get_image()
	var opacity: float=outline.modulate.a
	outline.modulate.a=1.0
	await RenderingServer.frame_post_draw
	var full:=viewport.get_texture().get_image()
	outline.hide()
	await RenderingServer.frame_post_draw
	var base:=viewport.get_texture().get_image()
	outline.modulate.a=opacity
	outline.show()
	paused=false
	var dim_light: float=0.0
	var full_light: float=0.0
	for y: int in range(0,base.get_height(),2):
		for x: int in range(0,base.get_width(),2):
			var unlit: float=base.get_pixel(x,y).get_luminance()
			dim_light+=maxf(0.0,dim.get_pixel(x,y).get_luminance()-unlit)
			full_light+=maxf(0.0,full.get_pixel(x,y).get_luminance()-unlit)
	check(full_light>0.0 and dim_light>0.0 and dim_light<full_light*0.8,
		"the original settled outline remains visible with less additive light")
	print("FUSION_OUTLINE_PIXELS ",JSON.stringify({"fixed_blend":not BLEND.screen_copy_available,"full_light":full_light,"dim_light":dim_light}))
