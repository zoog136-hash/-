extends BackBufferCopy
## Preserve destination copies unless this exact active shader was generated
## without screen sampling. Material duplicates share the same shader; changed
## or deep-copied shaders become unknown and conservatively keep their copy.
const COPY_FREE := &"source_destination_copy_free"
const SHADER_ID := &"source_destination_copy_shader_id"
var _target: WeakRef
var _automatic_sync: bool = true

static func mark_copy_free(shader: Shader) -> void:
	shader.set_meta(COPY_FREE,true)
	shader.set_meta(SHADER_ID,shader.get_instance_id())
	shader.changed.connect(_invalidate.bind(weakref(shader)),CONNECT_ONE_SHOT)

static func _invalidate(reference: WeakRef) -> void:
	var shader: Shader = reference.get_ref() as Shader
	if shader != null: shader.set_meta(COPY_FREE,false)

static func requires_copy(item: CanvasItem) -> bool:
	# An inherited or unknown material may still sample the destination.
	if item == null or item.use_parent_material or not item.material is ShaderMaterial: return true
	var shader: Shader = (item.material as ShaderMaterial).shader
	return shader == null or int(shader.get_meta(SHADER_ID,0)) != shader.get_instance_id() or not bool(shader.get_meta(COPY_FREE,false))

func _init(automatic_sync: bool = true) -> void:
	_automatic_sync = automatic_sync
	copy_mode = COPY_MODE_VIEWPORT

func track(item: CanvasItem) -> void:
	_target = weakref(item) if item != null else null
	if is_inside_tree(): _sync_copy()

func _enter_tree() -> void:
	if _automatic_sync and not RenderingServer.frame_pre_draw.is_connected(_sync_copy):
		RenderingServer.frame_pre_draw.connect(_sync_copy)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_copy):
		RenderingServer.frame_pre_draw.disconnect(_sync_copy)

func _sync_copy() -> void:
	var item: CanvasItem = _target.get_ref() as CanvasItem if _target != null else null
	var needed: bool = item == null or (item.is_visible_in_tree() and requires_copy(item))
	var wanted: int = COPY_MODE_VIEWPORT if needed else COPY_MODE_DISABLED
	if copy_mode != wanted: copy_mode = wanted
