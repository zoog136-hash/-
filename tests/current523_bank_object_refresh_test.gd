extends SceneTree
## Refresh-only differential against the prior holder rebuilding path.
## Synthetic textures/records; --render (or GL display) compares full RGBA.
const OBJECTS=preload("res://scripts/maps/current523_bank_objects.gd")
const LAYERS=preload("res://tests/current523_bank_object_layers_test.gd")
const BANK=preload("res://scripts/resources/reference_sp2_bank.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
class Mapping extends RefCounted:
	var shift:=Vector2.ZERO
	func to_world(raw: Vector2, _wrap: bool) -> Vector2: return raw+shift
class Fixture extends LAYERS.Fixture:
	var catalog: Dictionary={}
	var loads: Array[int]=[]
	func _load_sprite(id: int) -> Dictionary:
		loads.append(id)
		return catalog.get(id,{"ok":false,"error":"fixture_absent"})
class Baseline extends Fixture:
	func refresh(records: Array[Dictionary], malformed: int=0) -> void:
		_records=records
		for node: Node2D in _nodes: node.queue_free()
		_nodes.clear()
		var drawn: int=0
		var unresolved: Dictionary={}
		for row: Dictionary in records:
			if drawn>=MAX_DRAWN:break
			var sprite: Dictionary=_sprite(int(row.sprite_id))
			if not sprite.ok:
				unresolved[str(row.sprite_id)]=sprite.get("error","unresolved")
				continue
			var node:=Node2D.new()
			node.position=coordinates.to_world(Vector2(row.raw_x,row.raw_y),false)
			node.set_meta("sprite_id",int(row.sprite_id));node.set_meta("frame",-1)
			add_child(node);_nodes.append(node)
			_show(node,sprite,0);drawn+=1
		_stats={"policy":"OWN_BANK_ACTION3_DIRECTION0_LOOP_V1","raw_records":records.size(),"malformed_tails":malformed,"drawn_records":drawn,"unresolved_records":records.size()-drawn,"unresolved_source_ids":unresolved,"cached_sprites":_sprites.size(),"texture_bytes":_texture_bytes,"playback_mode":_mode,"native_M_placement_action_timing_verified":false}
class ImageBank extends BANK:
	var calls: int=0
	func render_layer(_layer: Dictionary, _pixels: bool=true) -> Dictionary:
		calls+=1
		var image:=Image.create_empty(4,4,false,Image.FORMAT_RGBA8)
		image.fill(Color(0.2,0.4,0.7,0.5))
		return {"ok":true,"image":image}
var checks: int=0
var failures: Array[String]=[]
var pixel_comparisons: int=0
var render: bool=false
var allocation_result: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MAP_REFRESH_FAIL: "+label)
func make_texture(seed: int) -> Texture2D:
	var image:=Image.create_empty(16,16,false,Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16:image.set_pixel(x,y,Color(float((x*17+seed)%255)/255.0,float((y*23+seed)%255)/255.0,0.65,float((x*19+y*13+seed)%255)/255.0))
	return ImageTexture.create_from_image(image)
func catalog(a: Texture2D,b: Texture2D) -> Dictionary:
	return {
		1:{"ok":true,"static":false,"total":1.0,"frames":[{"duration":0.5,"layers":[{"fixture_texture":a,"offset":[0,0]}]},{"duration":0.5,"layers":[{"fixture_texture":b,"offset":[2,3]}]}]},
		2:{"ok":true,"static":true,"frames":[{"layers":[{"fixture_texture":b,"offset":[1,2],"source_attributes":[8]}]}]},
		3:{"ok":true,"static":true,"frames":[{"layers":[{"fixture_texture":a,"offset":[0,0],"source_attributes":[128],"kind":"shadow"}]}]},
		4:{"ok":true,"static":true,"frames":[{"layers":[]}]}}
func rows(ids: Array, shift: float=0.0) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for i: int in ids.size():result.append({"sprite_id":ids[i],"raw_x":float(i*4)+shift,"raw_y":float(i%3)*3.0})
	return result
func view(baseline: bool,a: Texture2D,b: Texture2D) -> Dictionary:
	var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);viewport.disable_3d=true;viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var background:=ColorRect.new();background.size=Vector2(64,64);background.color=Color(0.18,0.31,0.53,0.67);viewport.add_child(background)
	var owner: Fixture=Baseline.new() if baseline else Fixture.new()
	owner.catalog=catalog(a,b);owner.coordinates=Mapping.new();owner._mode="compatible";owner.position=Vector2(16,16)
	owner.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;viewport.add_child(owner);owner.set_process(false)
	return {"viewport":viewport,"owner":owner}
func snapshot(owner: Fixture) -> Array:
	var result: Array=[]
	for holder: Node2D in owner._nodes:
		var layers: Array=[]
		for child: Sprite2D in holder.get_children():layers.append([child.texture.get_instance_id(),child.position,child.z_index,child.centered,child.modulate,-1 if child.material==null else (child.material as CanvasItemMaterial).blend_mode])
		result.append([holder.position,holder.get_meta("sprite_id"),holder.get_meta("frame"),layers])
	return result
func pixels(viewport: SubViewport) -> PackedByteArray:
	var image: Image=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image.get_data()
func compare(old: Dictionary,current: Dictionary,label: String) -> void:
	await process_frame;await process_frame
	if render:await RenderingServer.frame_post_draw
	check(snapshot(old.owner)==snapshot(current.owner),label+" ordered holders/layers/frame/coordinates match")
	check(old.owner.metrics()==current.owner.metrics(),label+" metrics unchanged")
	check(old.owner.loads==current.owner.loads,label+" exact cold source requests preserved")
	check(old.owner.texture_calls==current.owner.texture_calls,label+" texture path calls preserved")
	check(current.owner.get_children()==current.owner._nodes,label+" current child order is dense source order")
	check(old.owner.get_child_count()==old.owner._nodes.size(),label+" baseline deletion completed before comparison")
	if render:pixel_comparisons+=1;check(pixels(old.viewport)==pixels(current.viewport),label+" complete RGBA equal")
func refresh_pair(old: Dictionary,current: Dictionary,records: Array[Dictionary],malformed: int=0) -> void:
	old.owner.refresh(records,malformed);current.owner.refresh(records,malformed)
func collect(owner: Fixture,holders: Dictionary,layers: Dictionary,materials: Dictionary) -> void:
	for holder: Node2D in owner._nodes:
		holders[holder.get_instance_id()]=true
		for child: Sprite2D in holder.get_children():
			layers[child.get_instance_id()]=true
			if child.material!=null:materials[child.material.get_instance_id()]=true
func run() -> void:
	render="--render" in OS.get_cmdline_user_args() or DisplayServer.get_name()!="headless"
	if render and (DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility"):
		printerr("MAP_REFRESH_REQUIRES_COMPATIBILITY_GL");quit(2);return
	var a: Texture2D=make_texture(11);var b: Texture2D=make_texture(97)
	var old: Dictionary=view(true,a,b);var current: Dictionary=view(false,a,b)
	var oh: Dictionary={};var nh: Dictionary={};var ol: Dictionary={};var nl: Dictionary={};var om: Dictionary={};var nm: Dictionary={}
	for i: int in 10:
		refresh_pair(old,current,rows([1,2,1],float(i%2)))
		await compare(old,current,"steady refresh %d"%i)
		collect(old.owner,oh,ol,om);collect(current.owner,nh,nl,nm)
	allocation_result={"engine_refreshes":10,"baseline_holders":oh.size(),"reused_holders":nh.size(),"baseline_layers":ol.size(),"reused_layers":nl.size(),"baseline_materials":om.size(),"reused_materials":nm.size()}
	check(oh.size()==30 and nh.size()==3,"ten refreshes reuse three holders instead of thirty")
	check(ol.size()==30 and nl.size()==3,"layer reuse survives holder refresh")
	check(om.size()==10 and nm.size()==1,"private material reused across steady refreshes")
	for ids: Array in [[2,1,2],[5,1,5,3,1],[4,3],[],[5,5],[1,1,2,3]]:
		refresh_pair(old,current,rows(ids),7)
		await compare(old,current,"reorder/duplicate/empty/invalid "+str(ids))
		check(current.owner._records==rows(ids),"input records retained without normalization")
	# Existing shared animation clock advances, but refresh always starts display at zero.
	old.owner._process_step(0.6);current.owner._process_step(0.6)
	check(int(current.owner._nodes[0].get_meta("frame"))==1,"fixture advanced before refresh")
	refresh_pair(old,current,rows([1,1,2,3]))
	await compare(old,current,"refresh resets display to zero")
	check(int(current.owner._nodes[0].get_meta("frame"))==0 and current.owner._clock==0.6,"refresh preserves clock but forces frame zero")
	(old.owner.coordinates as Mapping).shift=Vector2(-4,6);(current.owner.coordinates as Mapping).shift=Vector2(-4,6)
	refresh_pair(old,current,rows([1,2,3]))
	await compare(old,current,"coordinate mapping changed")
	check(current.owner._nodes[0].position==Vector2(-4,6),"reused slot gets current coordinate mapping")
	# Same-ID static frame-zero replacement must refresh texture/style/offset too.
	for owner: Fixture in [old.owner,current.owner]:owner._sprites[2].frames[0].layers=[{"fixture_texture":a,"offset":[5,1],"source_attributes":[128]}]
	refresh_pair(old,current,rows([2,1]))
	await compare(old,current,"same-ID static record replaced at frame zero")
	check(current.owner._nodes[0].get_child(0).texture==a and current.owner._nodes[0].get_child(0).material==null,"static replacement clears previous additive material")
	old.owner._mode="strict";current.owner._mode="strict"
	refresh_pair(old,current,rows([2,1]))
	await compare(old,current,"strict mode keeps valid empty holder")
	check(current.owner._nodes.size()==2 and current.owner._nodes[0].get_child_count()==0,"valid hidden frame still counts as drawn record")
	old.owner._mode="compatible";current.owner._mode="compatible"
	refresh_pair(old,current,rows([1,2,1]))
	var discarded: WeakRef=weakref(current.owner._nodes[2])
	refresh_pair(old,current,rows([3]))
	check(current.owner.get_child_count()==1 and current.owner._nodes.size()==1,"surplus detached immediately")
	refresh_pair(old,current,rows([2,1]))
	await compare(old,current,"multiple refreshes before deferred free")
	check(discarded.get_ref()==null,"trimmed holder and private layers freed at boundary")
	# MAX_DRAWN counts resolved records, not inputs; do not inspect trailing records.
	var cap_ids: Array=[]
	for i: int in OBJECTS.MAX_DRAWN:
		cap_ids.append(5);cap_ids.append(1)
	cap_ids.append(999)
	refresh_pair(old,current,rows(cap_ids),13)
	await compare(old,current,"cap with unresolved interleaving")
	check(current.owner._nodes.size()==OBJECTS.MAX_DRAWN,"resolved placement cap unchanged")
	check(not current.owner.loads.has(999) and not current.owner.metrics().unresolved_source_ids.has("999"),"post-cap records never resolved")
	var cap_last: WeakRef=weakref(current.owner._nodes.back())
	refresh_pair(old,current,rows([]))
	check(current.owner._nodes.is_empty() and current.owner.get_child_count()==0,"empty refresh retains no holder pool")
	await compare(old,current,"empty after cap")
	check(cap_last.get_ref()==null,"cap allocation released after shrink")
	# Cache full keeps the same rejection and does not call the loader.
	for owner: Fixture in [old.owner,current.owner]:
		owner._sprites.clear()
		for i: int in OBJECTS.MAX_SPRITES:owner._sprites[1000+i]={"ok":false,"error":"fixture_reserved"}
	var old_calls: int=current.owner.loads.size()
	refresh_pair(old,current,rows([1]))
	await compare(old,current,"full sprite cache")
	check(current.owner.loads.size()==old_calls and current.owner.metrics().unresolved_source_ids["1"]=="map_object_sprite_cache_full","full cache rejection unchanged")
	old.viewport.queue_free();current.viewport.queue_free();await process_frame;await process_frame
	# Diagnostic counts have bounded keys; cold loads are a subset of refresh.
	HITCH.reset_for_test("user://map_refresh_hitch_fixture");HITCH.frame("fixture")
	var probe:=Fixture.new();probe.catalog=catalog(a,b);probe.coordinates=Mapping.new();probe._mode="compatible"
	probe.refresh(rows([1,2,1]));probe.refresh(rows([2,1]));probe.free()
	var texture_probe:=OBJECTS.new();var bank:=ImageBank.new();texture_probe._bank=bank
	var key: Dictionary={"member":"synthetic","group_bit":0,"frame_index":0}
	var first: Texture2D=texture_probe._texture(key)
	check(first!=null and texture_probe._texture(key)==first and bank.calls==1,"cold texture creation and cache hit behavior preserved")
	texture_probe.free()
	# Tiny synthetic operations may be omitted by the persisted millisecond filter.
	var raw_details: Dictionary=HITCH._details.duplicate(true)
	HITCH.backdate_frame_for_test(200000);HITCH.frame("fixture")
	var worst: Dictionary=HITCH.summary().worst[0]
	var counters: Dictionary=worst.get("counters",{})
	check(counters.get("map.object_holders_created")==3 and counters.get("map.object_holders_reused")==2 and counters.get("map.object_holders_trimmed")==1,"bounded refresh allocation counters")
	check(counters.get("map.object_sprite_loads")==2,"only actual cold loads counted")
	check(raw_details["map.object_refresh"][1]==2 and raw_details["map.object_sprite_load"][1]==2 and raw_details["map.object_texture_create"][1]==1,"inclusive refresh/cold load/texture call counts separate")
	print("CURRENT523_BANK_OBJECT_REFRESH_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"allocations":allocation_result,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
