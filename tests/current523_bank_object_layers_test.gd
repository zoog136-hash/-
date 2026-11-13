extends SceneTree
## Differential against the former _show allocation path, using synthetic texels.
## Default: node/lifetime checks. --render (or a GL display): full RGBA comparisons.
const OBJECTS = preload("res://scripts/maps/current523_bank_objects.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
class FakeBank extends BANK:
	var offsets: Array[String] = []
	func render_layer(layer: Dictionary, _pixels: bool = true) -> Dictionary:
		offsets.append(str(layer.get("member", "")))
		return {"ok":true,"offset":Vector2(7,9)} if layer.get("member")=="offset-ok" else {"ok":false}
class Fixture extends OBJECTS:
	var texture_calls: int = 0
	func _texture(layer: Dictionary) -> Texture2D:
		texture_calls += 1
		return layer.get("fixture_texture") as Texture2D
class Baseline extends Fixture:
	# Exact prior visible-layer construction; queued children are allowed to
	# finish deletion before comparisons, just as at the engine frame boundary.
	func _show(node: Node2D, sprite: Dictionary, index: int) -> void:
		if int(node.get_meta("frame")) == index: return
		node.set_meta("frame", index)
		for child: Node in node.get_children(): child.queue_free()
		var frame: Dictionary = sprite.frames[index]
		var order: int = 0
		for layer: Dictionary in frame.get("layers", []):
			if layer.has("client_null"): continue
			var attributes: Array = layer.get("source_attributes", [])
			var style: Dictionary = {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_MIX,"alpha":1.0}
			if not attributes.is_empty() or bool(layer.get("source_attributes_unresolved", false)):
				style = POLICY.effect(attributes, _mode)
				if bool(layer.get("source_attributes_unresolved", false)) or not bool(style.get("enabled", false)): continue
			var texture: Texture2D = _texture(layer)
			if texture == null: continue
			var picture := Sprite2D.new()
			picture.centered = false
			picture.texture = texture
			var offset: Variant = layer.get("offset", [0, 0])
			if offset is Array and offset.size() == 2: picture.position = Vector2(float(offset[0]), float(offset[1]))
			elif layer.has("member"):
				var rendered: Dictionary = _bank.render_layer(layer, false)
				if rendered.get("ok", false): picture.position = Vector2(rendered.offset)
			picture.z_index = -1 if layer.get("kind") == "shadow" else order
			if int(style.blend_mode) != CanvasItemMaterial.BLEND_MODE_MIX:
				var material := CanvasItemMaterial.new()
				material.blend_mode = int(style.blend_mode)
				picture.material = material
			picture.modulate.a = float(style.alpha)
			node.add_child(picture)
			order += 1
var checks: int = 0
var failures: Array[String] = []
var pixel_comparisons: int = 0
var render: bool = false
var allocation_result: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("MAP_OBJECT_LAYERS_FAIL: "+message)
func texture(seed: int) -> Texture2D:
	var image := Image.create_empty(16,16,false,Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16:
			image.set_pixel(x,y,Color(float((x*19+seed)%255)/255.0,float((y*23+seed*7)%255)/255.0,0.6,float((x*13+y*17+seed)%255)/255.0))
	return ImageTexture.create_from_image(image)
func layer(tex: Texture2D, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary={"fixture_texture":tex,"offset":[0,0]}
	result.merge(extra,true)
	return result
func view(baseline: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(64,64);viewport.disable_3d=true;viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size=Vector2(64,64);background.color=Color(0.18,0.31,0.53,0.67)
	viewport.add_child(background)
	var owner: Fixture = Baseline.new() if baseline else Fixture.new()
	owner._bank=FakeBank.new();owner._mode="compatible"
	owner.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(owner);owner.set_process(false)
	var holder:=Node2D.new();holder.position=Vector2(20,20);holder.set_meta("frame",-1)
	owner.add_child(holder)
	return {"viewport":viewport,"owner":owner,"holder":holder}
func describe(holder: Node2D) -> Array:
	var result: Array=[]
	for child: Sprite2D in holder.get_children():
		result.append([child.texture.get_instance_id(),child.position,child.z_index,child.centered,child.modulate,-1 if child.material==null else (child.material as CanvasItemMaterial).blend_mode])
	return result
func pixels(viewport: SubViewport) -> PackedByteArray:
	var image: Image=viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_data()
func settle_and_compare(old: Dictionary, current: Dictionary, label: String) -> void:
	await process_frame
	await process_frame
	if render: await RenderingServer.frame_post_draw
	check(describe(old.holder)==describe(current.holder),label+" nodes/order/style/offset match")
	check(old.owner.texture_calls==current.owner.texture_calls,label+" texture resolution calls preserved")
	check((old.owner._bank as FakeBank).offsets==(current.owner._bank as FakeBank).offsets,label+" offset fallback calls preserved")
	if render:
		pixel_comparisons+=1
		check(pixels(old.viewport)==pixels(current.viewport),label+" complete RGBA equal")
func run() -> void:
	render="--render" in OS.get_cmdline_user_args() or DisplayServer.get_name()!="headless"
	if render and (DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility"):
		printerr("MAP_OBJECT_LAYERS_REQUIRES_COMPATIBILITY_GL");quit(2);return
	var a: Texture2D=texture(19)
	var b: Texture2D=texture(113)
	var old: Dictionary=view(true)
	var current: Dictionary=view(false)
	var stable: Dictionary={"frames":[
		{"layers":[layer(a,{"kind":"shadow"}),layer(b,{"offset":[3,2]}),layer(a,{"source_attributes":[8],"offset":[1,4]})]},
		{"layers":[layer(b,{"kind":"shadow","offset":[1,1]}),layer(a,{"offset":[4,3]}),layer(b,{"source_attributes":[8],"offset":[2,5]})]}]}
	var old_nodes: Dictionary={};var new_nodes: Dictionary={};var old_materials: Dictionary={};var new_materials: Dictionary={}
	for frame: int in 20:
		old.owner._show(old.holder,stable,frame%2);current.owner._show(current.holder,stable,frame%2)
		await settle_and_compare(old,current,"stable frame %d"%frame)
		for node: Sprite2D in old.holder.get_children():
			old_nodes[node.get_instance_id()]=true
			if node.material!=null:old_materials[node.material.get_instance_id()]=true
		for node: Sprite2D in current.holder.get_children():
			new_nodes[node.get_instance_id()]=true
			if node.material!=null:new_materials[node.material.get_instance_id()]=true
	allocation_result={"engine_updates":20,"baseline_sprite_instances":old_nodes.size(),"reused_sprite_instances":new_nodes.size(),"baseline_material_instances":old_materials.size(),"reused_material_instances":new_materials.size()}
	check(old_nodes.size()==60 and new_nodes.size()==3,"steady animation allocates three sprites instead of sixty")
	check(old_materials.size()==20 and new_materials.size()==1,"steady additive layer retains one private material")
	# A second placement may share textures, but never nodes or mutable materials.
	var second := Node2D.new();second.set_meta("frame",-1)
	current.owner._show(second,stable,1)
	check(second.get_child(2)!=current.holder.get_child(2),"placements own distinct layer nodes")
	check(second.get_child(2).material!=current.holder.get_child(2).material,"placements own distinct mutable materials")
	check(second.get_child(2).texture==current.holder.get_child(2).texture,"texture sharing remains intact")
	(second.get_child(2).material as CanvasItemMaterial).blend_mode=CanvasItemMaterial.BLEND_MODE_SUB
	check((current.holder.get_child(2).material as CanvasItemMaterial).blend_mode==CanvasItemMaterial.BLEND_MODE_ADD,"one placement cannot mutate another blend")
	second.free()
	var old_second := Node2D.new();old_second.set_meta("frame",-1)
	old.owner._show(old_second,stable,1)
	old_second.free()
	var edges: Dictionary={"frames":[
		{"layers":[layer(b,{"source_attributes":[8]}),layer(a,{"source_attributes":[128]}),layer(a)]},
		{"layers":[layer(a,{"offset":"invalid","member":"offset-ok"})]},
		{"layers":[layer(b,{"offset":"invalid","member":"offset-failed"})]},
		{"layers":[{"fixture_texture":a,"member":"no-offset-default"}]},
		{"layers":[layer(a,{"client_null":true}),layer(a,{"source_attributes":[512]}),layer(a,{"source_attributes_unresolved":true}),{"fixture_texture":null},layer(b,{"kind":"shadow"})]},
		{"layers":[]},
		{"layers":[layer(a,{"kind":"shadow"}),layer(b,{"kind":"shadow"}),layer(a,{"kind":"shadow","source_attributes":[128]})]}]}
	for mode: String in ["compatible","strict"]:
		old.owner._mode=mode;current.owner._mode=mode
		old.holder.set_meta("frame",-1);current.holder.set_meta("frame",-1)
		for index: int in edges.frames.size():
			old.owner._show(old.holder,edges,index);current.owner._show(current.holder,edges,index)
			await settle_and_compare(old,current,mode+" edge %d"%index)
	# Same-index is still a no-op, including texture resolution and children.
	var calls: int=current.owner.texture_calls
	var ids: Array=[]
	for node: Node in current.holder.get_children():ids.append(node.get_instance_id())
	current.owner._show(current.holder,edges,edges.frames.size()-1)
	check(current.owner.texture_calls==calls,"same index skips work")
	var repeated_ids: Array=[]
	for node: Node in current.holder.get_children():repeated_ids.append(node.get_instance_id())
	check(ids==repeated_ids,"same index retains instance identities")
	# Multiple updates before engine deletion must not reuse queued surplus.
	old.owner._mode="compatible";current.owner._mode="compatible"
	old.owner._show(old.holder,edges,0);current.owner._show(current.holder,edges,0)
	var surplus: WeakRef=weakref(current.holder.get_child(2))
	var discarded_material: WeakRef=weakref(current.holder.get_child(0).material)
	old.owner._show(old.holder,edges,1);current.owner._show(current.holder,edges,1)
	check(current.holder.get_child_count()==1,"trim detaches surplus immediately")
	check(current.holder.get_child(0).material==null,"mix releases previous additive material")
	old.owner._show(old.holder,edges,6);current.owner._show(current.holder,edges,6)
	await settle_and_compare(old,current,"multiple changes before deferred deletion")
	check(surplus.get_ref()==null,"discarded layer is freed after frame boundary")
	check(discarded_material.get_ref()==null,"unused material ownership released")
	old.owner._show(old.holder,edges,5);current.owner._show(current.holder,edges,5)
	await settle_and_compare(old,current,"empty final frame")
	check(current.holder.get_child_count()==0,"empty frame retains no layer nodes or textures")
	var weak_holder: WeakRef=weakref(current.holder)
	old.viewport.queue_free();current.viewport.queue_free()
	await process_frame;await process_frame
	check(weak_holder.get_ref()==null,"placement lifetime owns reused children")
	print("CURRENT523_BANK_OBJECT_LAYERS_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"allocations":allocation_result,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
