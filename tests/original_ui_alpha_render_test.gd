extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
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
	var channels: Array[int]=[source.r8,source.g8,source.b8]
	for channel: int in range(3):
		checks+=1
		var expected: float=float((channels[channel]*(source.a8+1))>>8)/255.0
		if absf(converted[channel]-expected)>0.00001:errors.append("PNG premultiplication differs from CCImage macro")
	RenderingServer.set_default_clear_color(Color.BLACK)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(2,2)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sprite:=Sprite2D.new()
	sprite.centered=false;sprite.scale=Vector2(2,2)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture=pixel_texture
	viewport.add_child(sprite)
	for blend: String in ["1:771","770:771","770:1"]:
		sprite.material=MATERIAL.for_blend(pixel_texture,blend)
		if sprite.material==null:errors.append("original shader unavailable");continue
		for alpha_byte: int in [255,128,0]:
			var opacity: float=float(alpha_byte)/255.0
			sprite.modulate=Color(1,1,1,opacity)
			await process_frame
			await RenderingServer.frame_post_draw
			var actual: Color=viewport.get_texture().get_image().get_pixel(0,0)
			for channel: int in range(3):
				checks+=1
				var expected: float=converted[channel]*opacity
				if blend!="1:771":expected*=source.a*opacity
				if absf(actual[channel]-expected)>2.0/255.0:errors.append("source alpha composite differs: "+blend+":"+str(alpha_byte))
	print("ORIGINAL_ALPHA_RENDER ",JSON.stringify({"checks":checks,"errors":errors,"scope":"original PNG pixel, source opacityModifyRGB and three blend pairs over opaque black"}))
	quit(0 if errors.is_empty() and checks==30 else 1)
