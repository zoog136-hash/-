extends SceneTree
## Production dispatch under unavailable destination-copy capability.
## Tiny test texels only. No original asset, native523 or Android parity claim.
const BASE = preload("res://tests/source_attachment_render_projection_test.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
class Preview:
	extends BASE.Preview
	var black: Texture2D
	func _source_texture(layer: Dictionary) -> Texture2D:
		if layer.get("kind","") == "shadow" or _reference_attachment_parent.get("kind","") == "shadow":
			if black == null:
				var image := Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
				image.fill(Color.BLACK)
				black = ImageTexture.create_from_image(image)
			return black
		return super._source_texture(layer)
var checks: int = 0
var failures: Array[String] = []
var render_checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func texture(color: Color) -> Texture2D:
	var image := Image.create_empty(2,2,false,Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
func _initialize() -> void: call_deferred("run")
func configured(parent: Node, flags: int, shadow: String):
	var p := Preview.new()
	p.fixture_texture = texture(Color.BLACK if shadow.is_empty() else Color(0,0,0,0))
	parent.add_child(p)
	p._playback_mode = "compatible"
	p._configure_reference_bank("","",10,{"idle":0},{"idle":true},"idle","")
	var frame: Dictionary = p._playback_tracks.idle.directions[0][0]
	frame.layers[0].source_attributes = [str(flags)]
	frame.layers[0].source_attribute_projection = {"ok":true,"present":flags != 0,"flags":flags}
	frame.layers[0].offset = [0,0]
	if shadow == "inline":
		frame.layers.append({"kind":"shadow","source_attributes":[],"source_attributes_unresolved":false,"source_attribute_projection":{"ok":false,"origin":"shadow_requires_parent_actor_flags"},"layer_id":11,"offset":[0,0],"frame_provenance":{}})
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.z_index = -1
		p.add_child(sprite)
		p._layers.append(sprite)
	elif shadow == "independent":
		p._record.independent_source_layers = {"idle":[{"kind":"shadow","from_sprite_id":10,"target_sprite_id":11,"child_action_id":0,"child_source_action_key":"fixture-action","source_declaration":{},"dispatch_policy":"legacy_host_policy"}]}
		p._reference_card_context = {"consumer":"transform","ancestor_actor_ids":[]}
	check(p.advance_reference_source(0,"idle",0),"production copy-free dispatch "+str(flags)+"/"+shadow)
	return p
func no_copies(node: Node) -> bool:
	if node is BackBufferCopy and node.copy_mode != BackBufferCopy.COPY_MODE_DISABLED:return false
	for child: Node in node.get_children():
		if not no_copies(child):return false
	return true
func close_color(a: Color,b: Color) -> bool:
	return absf(a.r-b.r)<0.012 and absf(a.g-b.g)<0.012 and absf(a.b-b.b)<0.012
func run() -> void:
	var previous: bool = COMPOSITOR.screen_copy_available
	var render: bool = "--render" in OS.get_cmdline_user_args()
	if render and DisplayServer.get_name() == "headless":
		check(false,"--render requires an actual renderer")
		render = false
	COMPOSITOR.screen_copy_available = false
	for flags: int in [1,8,128]:
		var p = configured(root,flags,"")
		var body: Sprite2D = p._layers[0]
		check(body.visible and body.material is CanvasItemMaterial,"copy-free body retains drawable canvas material "+str(flags))
		check(body.material.blend_mode == (CanvasItemMaterial.BLEND_MODE_ADD if flags == 8 else CanvasItemMaterial.BLEND_MODE_MIX),"body uses copy-free blend "+str(flags))
		check(is_equal_approx(body.modulate.a,1.0 if flags == 8 else 0.5),"body uses copy-free opacity "+str(flags))
		check(not body.material is ShaderMaterial and no_copies(p),"body never samples destination "+str(flags))
		check(body.texture == p.fixture_texture and body.position == Vector2.ZERO,"body texels and source offset unchanged")
		p.free()
	for flags: int in [0,8,128]:
		for kind: String in ["inline","independent"]:
			var p = configured(root,flags,kind)
			var sprite: Sprite2D = p._layers[1] if kind == "inline" else p._reference_source_children.values()[0]._layers[0]
			check(sprite.visible and sprite.material is CanvasItemMaterial,"shadow remains linked and visible "+kind)
			check(sprite.material.blend_mode == (CanvasItemMaterial.BLEND_MODE_ADD if flags == 8 else CanvasItemMaterial.BLEND_MODE_MIX),"shadow uses parent flags, not own file "+str(flags))
			check(is_equal_approx(sprite.modulate.a,1.0 if flags == 8 else 0.5),"shadow is never opaque MIX after copy fallback")
			check(no_copies(p),"no shadow copy remains active")
			p.free()
	check(COMPOSITOR.fallback_style({"kind":"shadow"},[],true,"compatible").is_empty(),"unresolved parent is not repaired by fallback")
	check(COMPOSITOR.fallback_style({"kind":"shadow"},[],false,"strict").is_empty(),"strict policy unchanged")
	for flags: int in [8,128]:
		check(COMPOSITOR.fallback_style({"kind":"shadow"},[str(flags)],false,"compatible",false).is_empty(),"unverified mixed shadow flags retain old policy "+str(flags))
	check(COMPOSITOR.fallback_style({"kind":"body","source_attribute_projection":{"ok":false}},[],false,"compatible",true).is_empty(),"invalid own projection is not promoted")
	var conflicting: Dictionary = COMPOSITOR.fallback_style({"kind":"shadow","source_attributes":["128"]},["0"],false,"compatible",true)
	check(conflicting.get("flags",-1) == 1 and is_equal_approx(conflicting.get("alpha",0.0),0.5),"shadow own104 never replaces parent draw flags")
	if render:
		for background: Color in [Color.WHITE,Color(0.2,0.4,0.6,1)]:
			for flags: int in [0,8,128]:
				for kind: String in ["inline","independent"]:
					var viewport := SubViewport.new()
					viewport.size = Vector2i(32,32)
					viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
					root.add_child(viewport)
					var bg := ColorRect.new()
					bg.color = background
					bg.size = Vector2(32,32)
					bg.z_index = -10
					viewport.add_child(bg)
					var p = configured(viewport,flags,kind)
					# The legacy child fixture's original offset is [-7,9].
					if kind == "independent":p._reference_source_children.values()[0]._layers[0].position = Vector2.ZERO
					await process_frame
					await RenderingServer.frame_post_draw
					var actual: Color = viewport.get_texture().get_image().get_pixel(0,0)
					var expected: Color = background if flags == 8 else Color(background.r*0.5,background.g*0.5,background.b*0.5,1)
					render_checks += 1
					check(close_color(actual,expected),"GPU copy-free parent shadow "+str(flags)+"/"+kind+": "+str(actual)+" != "+str(expected))
					viewport.free()
	COMPOSITOR.screen_copy_available = previous
	print("SOURCE_PREVIEW_COPY_FREE_RESULT "+JSON.stringify({"checks":checks,"render_checks":render_checks,"failures":failures,"scope":"production preview with forced no-copy capability and synthetic texels; not Android GPU"}))
	quit(0 if failures.is_empty() else 1)
