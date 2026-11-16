extends Node
class_name TwilightWorldRenderScale
## Android GPU fill-rate saver: draw the game world at RENDER_SCALE of the
## native render target while every CanvasLayer (HUD, original UI, loot
## buttons, loading/update screens) stays at native resolution.
##
## Viewport.scaling_3d_scale does not touch 2D and Godot 4.7.2 has no 2D
## equivalent, so the world canvas is drawn a second way instead of moved:
## a SubViewport shares the root World2D, copies the root camera/stretch
## transforms just before every draw (scaled by RENDER_SCALE) and its texture
## is shown full-size, linearly filtered, on a CanvasLayer below every other
## layer. The root viewport stops drawing the World subtree through
## canvas_cull_mask (World.visibility_layer = WORLD_VISIBILITY_BIT only;
## "an item renders if it and all its parents share a layer with the mask").
##
## No node is reparented and the root viewport keeps its canvas transform,
## camera, GUI and physics picking, so touch -> world positions, monster
## picking, minimap and ground-loot buttons use exactly the same math as
## before. Only Android turns this on; desktop, CI and pixel tests are
## unchanged unless a test sets force_mode.
##
## Known limit: world BackBufferCopy rects computed from the root viewport
## (source_sp2_compositor screen copies) do not follow the SubViewport; that
## copy is already disabled on Android (screen_copy_available).
const RENDER_SCALE: float = 0.9
## Visibility layer 20. Nothing else in TWILIGHT uses layers above 1.
const WORLD_VISIBILITY_BIT: int = 1 << 19
## Below every CanvasLayer in the project (all are >= 1).
const DISPLAY_LAYER: int = -100
## Test hook: -1 automatic (Android only), 0 force off, 1 force on.
static var force_mode: int = -1
static var _active_world: WeakRef = null

var world: CanvasItem
var active: bool = false
var viewport: SubViewport
var layer: CanvasLayer
var display: TextureRect
var _root: Viewport
var _saved_world_layer: int = 1
var _saved_root_mask: int = 0

static func wanted() -> bool:
	if force_mode >= 0: return force_mode == 1
	return OS.has_feature("android")

## Top-level CanvasItems are parented to the canvas, not to their scene
## parent, so they would skip the World's visibility layer and be drawn by
## the root viewport over the scaled world. Call after set_as_top_level(true)
## on world nodes; it does nothing while the scale is off or outside World.
static func follow_world(item: CanvasItem) -> void:
	if item == null or _active_world == null: return
	var target: CanvasItem = _active_world.get_ref() as CanvasItem
	if target == null or not target.is_ancestor_of(item): return
	item.visibility_layer = WORLD_VISIBILITY_BIT

static func render_target_size(root: Viewport) -> Vector2:
	# Stretch transform carries only the content scale; the letterbox margin
	# places the finished target on screen and is not part of it.
	return (root.get_visible_rect().size * root.get_stretch_transform().get_scale()).round()

static func scaled_size(target: Vector2) -> Vector2i:
	return Vector2i(maxi(1, roundi(target.x * RENDER_SCALE)), maxi(1, roundi(target.y * RENDER_SCALE)))

func _init() -> void:
	name = "WorldRenderScale"

func _ready() -> void:
	world = get_parent() as CanvasItem
	if wanted(): enable()

func _exit_tree() -> void:
	disable()

func enable() -> void:
	if active or world == null: return
	_root = get_viewport()
	if _root == null: return
	active = true
	_saved_root_mask = _root.canvas_cull_mask
	_saved_world_layer = world.visibility_layer
	viewport = SubViewport.new()
	viewport.name = "WorldRenderScaleViewport"
	viewport.world_2d = _root.world_2d
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	viewport.physics_object_picking = false
	viewport.audio_listener_enable_2d = false
	viewport.canvas_item_default_texture_filter = _root.canvas_item_default_texture_filter
	viewport.canvas_item_default_texture_repeat = _root.canvas_item_default_texture_repeat
	viewport.snap_2d_transforms_to_pixel = _root.snap_2d_transforms_to_pixel
	viewport.snap_2d_vertices_to_pixel = _root.snap_2d_vertices_to_pixel
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	layer = CanvasLayer.new()
	layer.name = "WorldRenderScaleDisplay"
	layer.layer = DISPLAY_LAYER
	add_child(layer)
	display = TextureRect.new()
	display.name = "WorldTexture"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.texture = viewport.get_texture()
	layer.add_child(display)
	world.visibility_layer = WORLD_VISIBILITY_BIT
	_root.canvas_cull_mask = _saved_root_mask & ~WORLD_VISIBILITY_BIT
	_active_world = weakref(world)
	sync()
	if not RenderingServer.frame_pre_draw.is_connected(sync):
		RenderingServer.frame_pre_draw.connect(sync)

func disable() -> void:
	if not active: return
	active = false
	if RenderingServer.frame_pre_draw.is_connected(sync):
		RenderingServer.frame_pre_draw.disconnect(sync)
	if is_instance_valid(world): world.visibility_layer = _saved_world_layer
	if is_instance_valid(_root): _root.canvas_cull_mask = _saved_root_mask
	if _active_world != null and _active_world.get_ref() == world: _active_world = null
	for node: Node in [display, layer, viewport]:
		if is_instance_valid(node): node.queue_free()
	display = null
	layer = null
	viewport = null

## Runs on RenderingServer.frame_pre_draw: after every _process/camera update
## of the frame, so the scaled world never lags the root camera by a frame.
func sync() -> void:
	if not active or not is_instance_valid(_root) or viewport == null: return
	var target: Vector2 = render_target_size(_root)
	var size: Vector2i = scaled_size(target)
	if viewport.size != size: viewport.size = size
	var factor := Vector2(size) / target
	viewport.canvas_transform = _root.canvas_transform
	viewport.global_canvas_transform = Transform2D().scaled(factor) * _root.get_stretch_transform() * _root.global_canvas_transform
	var visible: Rect2 = _root.get_visible_rect()
	layer.transform = _root.global_canvas_transform.affine_inverse()
	if display.position != visible.position: display.position = visible.position
	if display.size != visible.size: display.size = visible.size

## World point -> root render-target pixel through the scaled path
## (SubViewport pixel, then the display's 1/RENDER_SCALE upscale). Equals the
## root viewport's own mapping; used by tests.
func scaled_world_to_target(world_point: Vector2) -> Vector2:
	var sub_pixel: Vector2 = viewport.global_canvas_transform * (viewport.canvas_transform * world_point)
	return sub_pixel * (render_target_size(_root) / Vector2(viewport.size))
