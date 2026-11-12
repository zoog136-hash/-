extends BackBufferCopy
## Keep the original framebuffer shader and draw order. Only limit its copy
## to the Sprite's screen pixels on the exact Compatibility build checked by
## the GL differential test. This does not shrink the viewport backbuffer.
##
## Godot 4.7.2 GLES3 consumes CopyBackBuffer.rect directly, unlike the canvas
## culler's transformed screen_rect. Supply viewport pixels only on that
## verified engine; other engines/renderers keep the original full copy.
const VERIFIED_ENGINE_HASH := "ed1daf0bf001b61586d9930840f2f1394092c079"
const SCREEN_PADDING := 1.0
var _sprite: WeakRef
var _runtime_supported: bool = false

static func supports_runtime(version: Dictionary, renderer: String) -> bool:
	return renderer == "gl_compatibility" and int(version.get("major", 0)) == 4 and int(version.get("minor", 0)) == 7 and int(version.get("patch", 0)) == 2 and str(version.get("hash", "")) == VERIFIED_ENGINE_HASH

## Sprite AABB in the viewport's render-target pixels, the space that both
## CopyBackBuffer.rect and the blend shader's SCREEN_UV address.
## get_viewport_transform includes viewport stretch and CanvasLayer/camera
## transforms (get_global_transform_with_canvas alone omits stretch). On the
## root Window with stretch aspect keep/expand the final transform also carries
## the letterbox margin as its origin, e.g. (200, 0) for a 1280x720 base on a
## 2000x900 phone screen. That margin only places the finished render target on
## the screen; it is not inside it. Copying with it moved every copy that far
## off its Sprite, so transparent pixels blended with an uncopied (black) or
## unrelated destination: item icons, buff icons and AUTO/SELF on phones showed
## as black boxes while opaque skill icons looked right. SubViewports have no
## such origin, so their result is unchanged.
static func render_target_bounds(viewport_transform: Transform2D, final_transform: Transform2D, global_transform: Transform2D, local_rect: Rect2) -> Rect2:
	var bounds: Rect2 = (viewport_transform * global_transform) * local_rect
	bounds.position -= final_transform.origin
	return bounds

func _init() -> void:
	copy_mode = COPY_MODE_VIEWPORT
	_runtime_supported = supports_runtime(Engine.get_version_info(), RenderingServer.get_current_rendering_method())

func track(sprite: Sprite2D) -> void:
	_sprite = weakref(sprite) if sprite != null else null
	if is_inside_tree(): _sync_copy()

func _enter_tree() -> void:
	# One callback per live copy node, no process-wide registry or strong owner
	# of the Sprite. The final draw hook observes layout, camera and scroll
	# changes made after ordinary _process callbacks, including the first draw.
	if not RenderingServer.frame_pre_draw.is_connected(_sync_copy):
		RenderingServer.frame_pre_draw.connect(_sync_copy)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_copy):
		RenderingServer.frame_pre_draw.disconnect(_sync_copy)

func _set_mode(value: int) -> void:
	if copy_mode != value: copy_mode = value

func _sync_copy() -> void:
	if not is_inside_tree(): return
	var sprite: Sprite2D = _sprite.get_ref() as Sprite2D if _sprite != null else null
	if sprite == null or not sprite.is_inside_tree():
		_set_mode(COPY_MODE_VIEWPORT)
		return
	if sprite.texture == null or not sprite.is_visible_in_tree():
		_set_mode(COPY_MODE_DISABLED)
		return
	if not _runtime_supported or get_tree().is_physics_interpolation_enabled():
		_set_mode(COPY_MODE_VIEWPORT)
		return
	var ancestor: Node = sprite
	while ancestor != null and not ancestor is Viewport:
		if ancestor is CanvasGroup or ancestor.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON or (ancestor is CanvasItem and ancestor.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED):
			_set_mode(COPY_MODE_VIEWPORT)
			return
		ancestor = ancestor.get_parent()
	var viewport_transform: Transform2D = sprite.get_viewport_transform()
	var global_transform: Transform2D = sprite.get_global_transform()
	var final_transform: Transform2D = sprite.get_viewport().get_final_transform()
	if not viewport_transform.is_finite() or not global_transform.is_finite() or not final_transform.is_finite():
		_set_mode(COPY_MODE_VIEWPORT)
		return
	var bounds: Rect2 = render_target_bounds(viewport_transform, final_transform, global_transform, sprite.get_rect())
	if not bounds.is_finite() or not bounds.has_area():
		_set_mode(COPY_MODE_VIEWPORT)
		return
	var first: Vector2 = bounds.position.floor() - Vector2.ONE * SCREEN_PADDING
	var last: Vector2 = bounds.end.ceil() + Vector2.ONE * SCREEN_PADDING
	var screen_rect := Rect2(first, last - first)
	# Never use Rect2() to mean disabled: Godot interprets it as a full copy.
	if rect != screen_rect: rect = screen_rect
	_set_mode(COPY_MODE_RECT)
