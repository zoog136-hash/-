extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
const BLEND=preload("res://scripts/ui/original_ui/source_blend.gd")
var errors: Array[String]=[]
var checks: int=0
var refs: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func collect(node: Dictionary) -> void:
	if node.classname=="Sprite":refs.append(node.options.fileNameData)
	for child: Dictionary in node.get("children",[]):collect(child)
func run() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var pack=PACK.new()
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	if not pack.open(args[0],receipt.manifest_sha256).ok:quit(2);return
	for member: String in pack.manifest.entries:
		var tree: Dictionary=pack.scene(member)
		collect(tree.nodeTree)
		for timeline: Dictionary in tree.get("action",{}).get("timeLines",[]):
			if timeline.property=="FileData":
				for frame: Dictionary in timeline.frames:
					if frame.get("textureFrame") is Dictionary:refs.append(frame.textureFrame.textureFile)
	var source: Color
	var converted: Color
	var pixel_texture: ImageTexture
	for ref: Dictionary in refs:
		var raw_texture: Texture2D=pack.texture(ref)
		var pma_texture: Texture2D=pack.texture(ref,true)
		if raw_texture==null or pma_texture==null or not pma_texture.get_meta("cocos_premultiplied",false):continue
		var raw: Image=raw_texture.get_image()
		var pma: Image=pma_texture.get_image()
		for y: int in range(raw.get_height()):
			for x: int in range(raw.get_width()):
				var candidate: Color=raw.get_pixel(x,y)
				if candidate.a>0.2 and candidate.a<0.8 and maxf(candidate.r,maxf(candidate.g,candidate.b))>0.3:
					source=candidate;converted=pma.get_pixel(x,y)
					pixel_texture=ImageTexture.create_from_image(pma.get_region(Rect2i(x,y,1,1)))
					pixel_texture.set_meta("cocos_premultiplied",true)
					break
			if pixel_texture!=null:break
		if pixel_texture!=null:break
	if pixel_texture==null:push_error("No qualifying original semitransparent pixel in supplied pack");quit(2);return

	var viewport:=SubViewport.new()
	viewport.size=Vector2i(2,2)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background:=ColorRect.new()
	background.size=Vector2(2,2)
	viewport.add_child(background)
	var copy:=BackBufferCopy.new()
	copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
	viewport.add_child(copy)
	var sprite:=Sprite2D.new()
	sprite.centered=false;sprite.scale=Vector2(2,2)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture=pixel_texture
	viewport.add_child(sprite)
	for backdrop: Color in [Color(0,0,0,0),Color(0.2,0.4,0.8,0.4),Color(0.6,0.3,0.1,1)]:
		background.color=backdrop
		for pair: String in BLEND.PAIRS:
			for alpha_byte: int in [255,128,1,0]:
				sprite.visible=false
				await process_frame
				await RenderingServer.frame_post_draw
				var destination: Color=viewport.get_texture().get_image().get_pixel(0,0)
				sprite.material=BLEND.material(pixel_texture,pair)
				if sprite.material==null:errors.append("shader unavailable:"+pair);continue
				var opacity: float=float(alpha_byte)/255.0
				sprite.modulate=Color.WHITE
				MATERIAL.bind_display(sprite,Color(1,1,1,opacity))
				sprite.visible=true
				await process_frame
				await RenderingServer.frame_post_draw
				var actual: Color=viewport.get_texture().get_image().get_pixel(0,0)
				var incoming: Color=Color(converted.r*opacity,converted.g*opacity,converted.b*opacity,converted.a*opacity)
				var factors: PackedStringArray=pair.split(":")
				var first: Color=factor(int(factors[0]),incoming,destination)
				var second: Color=factor(int(factors[1]),incoming,destination)
				for channel: int in range(4):
					checks+=1
					var expected: float=clampf(incoming[channel]*first[channel]+destination[channel]*second[channel],0.0,1.0)
					if absf(actual[channel]-expected)>2.0/255.0:errors.append("blend:"+pair+":"+str(channel)+":"+str(actual[channel])+" != "+str(expected))
	print("ORIGINAL_BLEND_FRAMEBUFFER "+JSON.stringify({"checks":checks,"errors":errors,"scope":"15 original GL factor pairs, actual original PNG pixel, RGBA framebuffer with three destination alpha values"}))
	quit(0 if errors.is_empty() and checks==720 else 1)
func factor(value: int, source: Color, destination: Color) -> Color:
	match value:
		0:return Color(0,0,0,0)
		1:return Color(1,1,1,1)
		769:return Color(1-source.r,1-source.g,1-source.b,1-source.a)
		770:return Color(source.a,source.a,source.a,source.a)
		771:return Color(1-source.a,1-source.a,1-source.a,1-source.a)
		772:return Color(destination.a,destination.a,destination.a,destination.a)
		774:return destination
	return Color(-1,-1,-1,-1)
