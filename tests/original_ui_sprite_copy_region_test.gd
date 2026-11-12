extends SceneTree
## GL-only synthetic differential: actual SpriteScene against its original
## full-copy nodes. No original pack, native-client, or Android latency claim.
const SCENE = preload("res://scripts/ui/original_ui/sprite_scene.gd")
const COPY = preload("res://scripts/ui/original_ui/source_sprite_back_buffer.gd")
const BLEND = preload("res://scripts/ui/original_ui/source_blend.gd")
const MEMBER = "UI/CopyRegionSynthetic.csb"
var checks: int = 0
var failures: Array[String] = []
var pixel_comparisons: int = 0

class FakePack extends RefCounted:
	var manifest: Dictionary = {"externally_bound_texture_nodes": {"UI/CopyRegionSynthetic.csb": [1003]}}
	var manifest_sha256: String = "synthetic-only"
	var tree: Dictionary = {}
	var textures: Array[Texture2D] = []
	func scene(_member: String) -> Dictionary: return tree.duplicate(true)
	func texture(reference: Dictionary, _cocos: bool = false) -> Texture2D:
		return textures[int(reference.get("path", "0")) % textures.size()]

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

static func widget(name_value: String, index: int) -> Dictionary:
	return {"name": name_value, "actionTag": index + 1, "rotationSkew": [0.0,0.0], "zOrder": 0, "visible": 1, "alpha": 177, "position": [5.3+index*7.1,-35.2-index*3.1], "scale": [1.0,1.0], "anchorPoint": [0.0,0.0], "color": [255,191,233,157], "size": [24.0,24.0], "flipX": 0, "flipY": 0, "ignoreSize": 0, "touchEnabled": 0, "frameEvent": "", "customProperty": "", "callBackType": null, "callBackName": null}

static func image_texture(size_value: Vector2i, pma: bool, seed_value: int) -> Texture2D:
	var bytes := PackedByteArray()
	bytes.resize(size_value.x * size_value.y * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for at: int in range(0,bytes.size(),4):
		var alpha: int = rng.randi_range(0,255)
		bytes[at+3] = alpha
		for channel: int in 3:
			var value: int = rng.randi_range(0,255)
			bytes[at+channel] = (value*(alpha+1)) >> 8 if pma else value
	var texture := ImageTexture.create_from_image(Image.create_from_data(size_value.x,size_value.y,false,Image.FORMAT_RGBA8,bytes))
	texture.set_meta("cocos_premultiplied",pma)
	return texture

func pack_for(pair: int, variant: int) -> RefCounted:
	var pack := FakePack.new()
	for index: int in 3:
		pack.textures.append(image_texture([Vector2i(24,24),Vector2i(37,11),Vector2i(11,33)][index],variant%2==1,411+index*31))
	var children: Array = []
	var timelines: Array = []
	for index: int in 4:
		var options: Dictionary = widget("Sprite%d" % index,index)
		options.flipX = variant%2
		options.flipY = int(index==1)
		if variant==1: options.rotationSkew=[14.0,14.0]; options.scale=[1.2,0.75]
		if variant==2: options.scale=[-0.85,1.1]; options.position[0]+=26.0
		if variant==3: options.rotationSkew=[-5.0,18.0]; options.zOrder=[2,0,1,3][index]
		if variant==6: options.position[0]=-18.3+index*29.7
		if variant==8: options.position=[500.0,-500.0]
		var factors: PackedStringArray = BLEND.PAIRS[(pair+index*5)%BLEND.PAIRS.size()].split(":")
		children.append({"_offset":1000+index,"classname":"Sprite","children":[],"options":{"nodeOptions":options,"blendFunc":[int(factors[0]),int(factors[1])],"fileNameData":{"path":"0","plist":"","type":0}}})
		if index==3: continue # This slot changes only through its real owner API.
		var texture_frames: Array = []
		var blend_frames: Array = []
		for phase: int in 3:
			var next: PackedStringArray = BLEND.PAIRS[(pair+index*5+phase)%BLEND.PAIRS.size()].split(":")
			texture_frames.append({"textureFrame":{"_type":"TextureFrame","frameIndex":phase,"textureFile":{"path":str(phase),"plist":"","type":0}}})
			blend_frames.append({"blendFrame":{"_type":"BlendFrame","frameIndex":phase,"blendFunc":[int(next[0]),int(next[1])]}})
		timelines.append({"actionTag":index+1,"property":"FileData","frames":texture_frames})
		timelines.append({"actionTag":index+1,"property":"BlendFunc","frames":blend_frames})
	var root_options: Dictionary = widget("Root",10)
	root_options.position=[0.0,0.0]
	root_options.actionTag=0
	pack.tree={"nodeTree":{"_offset":1,"classname":"Node","children":children,"options":{"nodeOptions":root_options}},"action":{"timeLines":timelines}}
	return pack

func make_view(pack: RefCounted, oracle: bool, transparent: bool, variant: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(72,64)
	viewport.transparent_bg=transparent
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if variant==5: viewport.size_2d_override=Vector2i(48,40); viewport.size_2d_override_stretch=true
	root.add_child(viewport)
	if variant==4: viewport.canvas_transform=Transform2D(0,Vector2(1.4,0.8),0,Vector2(-7.2,5.4))
	var background := ColorRect.new()
	background.size=Vector2(100,100)
	background.color=Color(0.2,0.4,0.6,0.63)
	var shader := Shader.new()
	shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;void fragment(){COLOR=COLOR;}"
	var material := ShaderMaterial.new()
	material.shader=shader
	background.material=material
	viewport.add_child(background)
	var container: Node = viewport
	if variant==7:
		var canvas := CanvasLayer.new()
		canvas.layer=2
		canvas.transform=Transform2D(0.13,Vector2(0.9,1.1),0,Vector2(5,1))
		viewport.add_child(canvas)
		container=canvas
	var clip := Control.new()
	clip.position=Vector2(6.25,3.75)
	clip.size=Vector2(49,44)
	clip.clip_contents=variant in [2,3,6,7]
	container.add_child(clip)
	var scene := SCENE.new()
	var result: Dictionary=scene.configure(pack,MEMBER,false,{1003:{"role":"source_asset_slot","visible":false}})
	check(result.get("ok",false),"actual scene config: "+str(result))
	clip.add_child(scene)
	viewport.set_meta("scene",scene)
	if oracle:
		for node: Node2D in scene.source_nodes.values():
			if not node.has_meta("source_sprite"): continue
			var sprite: Sprite2D=node.get_meta("source_sprite")
			var origin: Node=sprite.get_parent()
			var old: Node=origin.get_child(sprite.get_index()-1)
			var index: int=old.get_index()
			old.free()
			var full := BackBufferCopy.new()
			full.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
			origin.add_child(full)
			origin.move_child(full,index)
	return viewport

func apply_phase(viewport: SubViewport, pack: RefCounted, phase: int, variant: int) -> void:
	var scene: Node2D=viewport.get_meta("scene")
	scene.seek_frame(mini(phase,2))
	var owner: Dictionary={"ok":true,"texture":pack.textures[phase%3],"provenance":{"member":{"format":"PNG","sha256":"synthetic"}}}
	if phase==2: owner={"ok":false,"status":"synthetic_owner_rejected"}
	var consumed: Dictionary=scene.set_bound_source_asset_result(1003,owner)
	if phase!=2:
		check(consumed.get("ok",false),"owner texture replacement is accepted")
		check(scene.set_bound_visible(1003,true).get("ok",false),"restored owner slot is visible")
	else: check(not consumed.get("ok",true),"owner rejection remains rejected")
	if phase>0:
		scene.position+=Vector2(1.37,-0.8)
		if variant==1: scene.rotation+=0.1
		if variant==4: viewport.canvas_transform=Transform2D(0,Vector2(1.4+phase*0.1,0.8),0,Vector2(-7.2+phase*3,5.4))

func pixels(viewport: SubViewport) -> PackedByteArray:
	var image: Image=viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_data()

func guards_and_lifetime() -> void:
	var version: Dictionary=Engine.get_version_info()
	check(COPY.supports_runtime(version,"gl_compatibility"),"exact tested Compatibility engine is supported")
	check(not COPY.supports_runtime(version,"mobile"),"other renderer falls back")
	version=version.duplicate();version.patch=3
	check(not COPY.supports_runtime(version,"gl_compatibility"),"other engine patch falls back")
	version.patch=2;version.hash="different-build"
	check(not COPY.supports_runtime(version,"gl_compatibility"),"other engine implementation falls back")
	var pack: RefCounted=pack_for(0,0)
	var view: SubViewport=make_view(pack,false,true,0)
	var scene: Node2D=view.get_meta("scene")
	var sprite: Sprite2D=scene.source_nodes[1000].get_meta("source_sprite")
	var copy: BackBufferCopy=sprite.get_parent().get_child(sprite.get_index()-1)
	copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_RECT,"ordinary Sprite uses bounded copy")
	var before: int=RenderingServer.frame_pre_draw.get_connections().size()
	var weak_copy: WeakRef=weakref(copy)
	var weak_sprite: WeakRef=weakref(sprite)
	scene.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT,"item interpolation uses full copy")
	scene.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	set_physics_interpolation_enabled(true);copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT,"global interpolation uses full copy")
	set_physics_interpolation_enabled(false)
	var group:=CanvasGroup.new()
	view.add_child(group)
	scene.reparent(group)
	copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT,"CanvasGroup ancestor uses full copy")
	scene.reparent(view)
	scene.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
	copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT,"implicit clip-children group uses full copy")
	scene.clip_children=CanvasItem.CLIP_CHILDREN_DISABLED
	copy._runtime_supported=false;copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_VIEWPORT,"unsupported runtime executes full-copy fallback")
	copy._runtime_supported=true
	sprite.texture=null;copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_DISABLED,"null Sprite disables its copy")
	sprite.texture=pack.textures[1];copy._sync_copy()
	check(copy.copy_mode==BackBufferCopy.COPY_MODE_RECT,"restoring a different size resumes bounded copy")
	view.free()
	check(weak_copy.get_ref()==null and weak_sprite.get_ref()==null,"callbacks do not retain freed scene nodes")
	check(RenderingServer.frame_pre_draw.get_connections().size()==before-4,"freeing scene disconnects all four copy callbacks")

func run() -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":
		printerr("SPRITE_COPY_REGION_REQUIRES_COMPATIBILITY_GL: headless pixels are not a framebuffer test")
		quit(2);return
	guards_and_lifetime()
	for transparent: bool in [true,false]:
		for pair: int in BLEND.PAIRS.size():
			for variant: int in 9:
				var pack: RefCounted=pack_for(pair,variant)
				var full: SubViewport=make_view(pack,true,transparent,variant)
				var region: SubViewport=make_view(pack,false,transparent,variant)
				for phase: int in 4:
					apply_phase(full,pack,phase,variant)
					apply_phase(region,pack,phase,variant)
					await process_frame
					await RenderingServer.frame_post_draw
					pixel_comparisons+=1
					check(pixels(full)==pixels(region),"exact RGBA pair=%s variant=%d phase=%d transparent=%s"%[BLEND.PAIRS[pair],variant,phase,transparent])
					var scene: Node2D=region.get_meta("scene")
					var slot: Sprite2D=scene.source_nodes[1003].get_meta("source_sprite")
					var slot_copy: BackBufferCopy=slot.get_parent().get_child(slot.get_index()-1)
					check(slot_copy.copy_mode==(BackBufferCopy.COPY_MODE_DISABLED if phase==2 else BackBufferCopy.COPY_MODE_RECT),"draw hook tracks owner null/restore on first frame")
				full.free();region.free()
	print("ORIGINAL_UI_SPRITE_COPY_REGION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
