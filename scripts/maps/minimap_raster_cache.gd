extends RefCounted

## Cache the existing static draw commands at their actual display-pixel scale.
## No source texture, geometry, boss dot, input coordinate or actor is removed.
## The dynamic overlays remain on the original Control and refresh as before.
var viewport: SubViewport
var painter: Control
var owner_control: Control
var signature: Array = []
var logical_extent := Vector2.ZERO
var logical_origin := Vector2.ZERO
var ready: bool = false
var generation: int = 0
var builds: int = 0

func invalidate() -> void:
	signature.clear()
	ready = false
	generation += 1
	# A hidden minimap must not retain the previous map's textures/data.
	if is_instance_valid(painter):
		painter.field = null
		painter.source_overview = null
		painter.geography_cache = null

func texture() -> Texture2D:
	return viewport.get_texture() if is_instance_valid(viewport) else null

func prepare(owner: Control) -> void:
	if DisplayServer.get_name() == "headless" or owner.size.x <= 0 or owner.size.y <= 0: return
	var display: Transform2D = owner.get_viewport().get_final_transform() * owner.get_global_transform_with_canvas()
	var scale_value := Vector2(display.x.length(), display.y.length())
	if scale_value.x <= 0 or scale_value.y <= 0: return
	# Rasterize at the same fractional pixel phase as the original canvas, then
	# place the texture on whole display pixels. Otherwise small viewports filter
	# the same edge twice and blur/shift the boss dots and thin outlines.
	var phase: Vector2 = display.origin - display.origin.floor()
	var pixels := Vector2i(ceili(owner.size.x * scale_value.x + phase.x), ceili(owner.size.y * scale_value.y + phase.y))
	var request: Array = [owner.size, scale_value, phase, owner.field, owner.bounds, owner.area, owner.source_overview]
	if signature == request: return
	owner_control = owner
	if not is_instance_valid(viewport):
		viewport = SubViewport.new()
		viewport.name = "StaticMinimapRaster"
		viewport.disable_3d = true
		viewport.gui_disable_input = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		owner.add_child(viewport)
		painter = owner.get_script().new()
		painter.static_only = true
		painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport.add_child(painter)
	viewport.size = pixels
	viewport.canvas_transform = Transform2D(Vector2(scale_value.x, 0), Vector2(0, scale_value.y), phase)
	logical_extent = Vector2(pixels) / scale_value
	logical_origin = -phase / scale_value
	painter.size = owner.size
	painter.world = owner.world
	painter.field = owner.field
	painter.bounds = owner.bounds
	painter.area = owner.area
	painter.source_overview = owner.source_overview
	painter.geography_cache = owner.geography_cache
	painter.queue_redraw()
	signature = request
	ready = false
	generation += 1
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_completed.bind(generation), CONNECT_ONE_SHOT)

func _completed(request_generation: int) -> void:
	if request_generation != generation or not is_instance_valid(owner_control): return
	ready = true
	builds += 1
	owner_control.queue_redraw()
