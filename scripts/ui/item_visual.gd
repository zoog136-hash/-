extends Node
## Reusable presentation attached once to an existing TextureRect. Texture pixels
## alone receive the shader; slot chrome, badges, labels and input stay untouched.
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const FOREGROUND = preload("res://scripts/ui/item_icon_foreground.gd")
const SCHEDULER = preload("res://scripts/ui/item_visual_scheduler.gd")
const SHADER = preload("res://scripts/ui/item_rarity.gdshader")
const SOURCE523 = preload("res://scripts/ui/source523_image_assets.gd")
const GRADES: Array[String] = ["일반","고급","희귀","영웅","전설","신화","유일"]
const COLORS: Array[Color] = [Color("ddd6c5"),Color("79bf83"),Color("73b4ee"),Color("e97772"),Color("bc89e3"),Color("e5be60"),Color("66dfc2")]
static var materials: Dictionary = {}
static var scheduler_ref: WeakRef
static var reduced_motion: bool = false
## Original animated (CSB) icon scenes that could not be attached, by reason:
## the slot would otherwise stay silently empty (no static original exists for
## these icons). Reported once per reason to the log for the player's report.
static var scene_failures: Dictionary = {}
var target: TextureRect
var rank: int = 0
var phase_group: int = 0
var context: String = "slot"
var scheduler: Node
var substitute_mark: Label
var foreground_ready: bool = true
var source_presentation: bool = false

static func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	var active_scheduler: Node = scheduler_ref.get_ref() if scheduler_ref != null else null
	if is_instance_valid(active_scheduler):
		active_scheduler.motion_enabled = not enabled
		active_scheduler.refresh_all()

static func is_blessed_scroll(record: Dictionary, item_name: String = "") -> bool:
	# Presentation identity only: never infer a scroll from an equipment's
	# blessing flag, and never change the authoritative item grade.
	if str(record.get("slot", "")) not in ["", "consumable"]: return false
	var title: String = str(record.get("name", "")).strip_edges()
	if title.is_empty(): title = item_name.get_slice("@@@", 0)
	for space: String in [" ", "\t", "\r", "\n", "　"]:
		title = title.replace(space, "")
	title = title.replace("(각인)", "")
	return title == "축복부여주문서" or (title.begins_with("축복받은") and title.ends_with("주문서"))

static func animation_rank(record: Dictionary, item_name: String = "") -> int:
	if is_blessed_scroll(record, item_name): return GRADES.find("영웅")
	return maxi(0, GRADES.find(str(record.get("grade", "일반"))))

static func apply(view: TextureRect, record: Dictionary, item_name: String, images: Dictionary = {}, usage: String = "slot", original_ui_bindings: Dictionary = {}) -> void:
	var effect: Node = view.get_node_or_null("ItemVisual")
	if effect == null:
		effect = new()
		effect.name = "ItemVisual"
		view.add_child(effect)
	effect.configure(view, record, item_name, images, usage, original_ui_bindings)

static func apply_source_item_reference(view: TextureRect, data_reference: Dictionary, title: String, usage: String = "slot", original_ui_bindings: Dictionary = {}) -> void:
	var effect: Node = view.get_node_or_null("ItemVisual")
	if effect == null:
		effect = new()
		effect.name = "ItemVisual"
		view.add_child(effect)
	effect.configure_source_item_reference(view,data_reference,title,usage,original_ui_bindings)

static func apply_item_class_icon(view: TextureRect, item_class_id: int, title: String, usage: String = "slot", original_ui_bindings: Dictionary = {}) -> void:
	var effect: Node = view.get_node_or_null("ItemVisual")
	if effect == null:
		effect = new()
		effect.name = "ItemVisual"
		view.add_child(effect)
	effect.configure_item_class_icon(view,item_class_id,title,usage,original_ui_bindings)

static func clear(view: TextureRect) -> void:
	if view == null: return
	_detach_source_scene(view)
	view.material = null
	SOURCE523.bind_metadata(view,{})
	if view.has_meta("item_visual"): view.remove_meta("item_visual")
	var effect: Node = view.get_node_or_null("ItemVisual")
	if effect != null: effect.deactivate()

static func _detach_source_scene(view: TextureRect, immediate: bool = true) -> void:
	SOURCE523.ORIGINAL_UI_ICONS.detach(view,immediate)
	var previous: Variant = view.get_meta("item_visual",{})
	if previous is Dictionary and previous.get("route","") == "source523_images" and previous.has("scene_result"):
		view.remove_meta("item_visual")
		SOURCE523.bind_metadata(view,{})

static func shared_material(grade_rank: int, group: int) -> ShaderMaterial:
	var key: String = "%d:%d" % [grade_rank,group]
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("rank",float(grade_rank))
	result.set_shader_parameter("phase",float(group)*0.67)
	result.set_shader_parameter("accent",COLORS[grade_rank])
	materials[key] = result
	return result

func configure(view: TextureRect, record: Dictionary, item_name: String, images: Dictionary, usage: String, original_ui_bindings: Dictionary = {}) -> void:
	_configure_presentation(view,record,item_name,images,usage,original_ui_bindings,RESOLVER.describe(record,item_name,images,usage == "ground"))

func configure_source_item_reference(view: TextureRect, data_reference: Dictionary, title: String, usage: String, original_ui_bindings: Dictionary = {}) -> void:
	var info: Dictionary = SOURCE523.describe_item_reference(data_reference,title)
	_configure_presentation(view,{},title,{},usage,original_ui_bindings,info,true)

func configure_item_class_icon(view: TextureRect, item_class_id: int, title: String, usage: String, original_ui_bindings: Dictionary = {}) -> void:
	var info: Dictionary = SOURCE523.describe_item_class(item_class_id,title)
	_configure_presentation(view,{},title,{},usage,original_ui_bindings,info,true)

func _configure_presentation(view: TextureRect, record: Dictionary, item_name: String, images: Dictionary, usage: String, original_ui_bindings: Dictionary, info: Dictionary, reference_presentation: bool = false) -> void:
	var next_source_presentation: bool = reference_presentation or info.get("route","") == "source523_images"
	var source_scene_requested: bool = next_source_presentation and info.get("reason","") == "unsupported_csb" and usage != "ground"
	if is_instance_valid(target) and target != view: _detach_source_scene(target)
	if not source_scene_requested: _detach_source_scene(view)
	target = view
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_presentation = next_source_presentation
	target.texture = info.get("texture") as Texture2D if source_presentation else RESOLVER.texture(record,item_name,images,usage == "ground")
	if source_scene_requested:
		var attached: Dictionary = SOURCE523.attach_original_icon(view,info,original_ui_bindings,{"usage":usage,"trigger":"existing_item_visual_bind"})
		info["scene_result"] = attached
		info["source_status"] = str(attached.get("status","unavailable"))
		if attached.get("ok",false):
			info["status"] = "source_scene_estimate" if attached.get("origin","") == "estimated_single_pass_icon_host" else "verified_source_scene"
			info["reason"] = ""
		else:
			_detach_source_scene(view)
			info["status"] = "original_icon_not_installed"
			info["reason"] = str(attached.get("error","source_scene_unavailable"))
			_report_scene_failure(info)
	rank = 0 if reference_presentation else animation_rank(record, item_name)
	phase_group = 0 if reference_presentation else posmod((str(record.get("sourceId",""))+item_name).hash(),8)
	context = usage
	foreground_ready = true
	# Only turning surfaces need a cutout. Static list/quickslot/drag/ground
	# art and every hero/legend source image remain exactly as they were.
	if not source_presentation and rank >= 5 and context not in ["quickslot","list","drag","ground"]:
		var foreground: Dictionary = FOREGROUND.prepare(target.texture)
		target.texture = foreground.texture
		foreground_ready = bool(foreground.ready)
		info["foreground_ready"] = foreground_ready
		info["foreground_reason"] = foreground.reason
		info["foreground_removed_pixels"] = foreground.removed_pixels
	target.set_meta("item_visual",info)
	SOURCE523.bind_metadata(target,info)
	if substitute_mark == null:
		substitute_mark = Label.new()
		substitute_mark.name = "SubstituteIconMark"
		substitute_mark.text = "◇"
		substitute_mark.tooltip_text = "TWILIGHT 자체 대체 아이콘"
		substitute_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		substitute_mark.add_theme_font_size_override("font_size",10)
		substitute_mark.add_theme_color_override("font_color",Color("b7c9d1"))
		target.add_child(substitute_mark)
		substitute_mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		substitute_mark.offset_left = -12
	var missing_original: bool=info.status=="original_icon_not_installed"
	substitute_mark.text="효과 미연결" if missing_original and source_scene_requested else SOURCE523.missing_label(info) if missing_original and source_presentation else "원본 미설치" if missing_original else "◇"
	substitute_mark.tooltip_text=str(info.get("reason","원본 아이콘 미설치")) if missing_original and source_presentation else "원본 아이콘 미설치" if missing_original else "TWILIGHT 자체 대체 아이콘"
	substitute_mark.offset_left=-62 if missing_original else -12
	# An empty slot carries no substitute or "not installed" badge. An item whose
	# original animated icon scene failed shows "효과 미연결" (reason in the
	# tooltip) instead of an unexplained blank slot; no image is substituted.
	substitute_mark.visible = missing_original and source_scene_requested and item_name.strip_edges() != ""
	if not target.visibility_changed.is_connected(refresh_visibility): target.visibility_changed.connect(refresh_visibility)
	if is_inside_tree(): _register()
	refresh_visibility()

static func _report_scene_failure(info: Dictionary) -> void:
	var reason: String = str(info.get("reason",""))
	var provenance: Variant = info.get("provenance",{})
	var icon: String = str(provenance.get("icon_id","")) if provenance is Dictionary else ""
	if not scene_failures.has(reason):
		scene_failures[reason] = {"count":0,"icons":[]}
		push_warning("ITEM_ICON_SCENE_UNAVAILABLE reason=%s icon=%s" % [reason,icon])
		print("ITEM_ICON_SCENE_UNAVAILABLE reason=%s icon=%s" % [reason,icon])
	scene_failures[reason].count = int(scene_failures[reason].count)+1
	if icon != "" and not scene_failures[reason].icons.has(icon) and scene_failures[reason].icons.size() < 16: scene_failures[reason].icons.append(icon)

func _ready() -> void:
	set_process(false)
	if target != null: _register()

func _register() -> void:
	if source_presentation:
		if is_instance_valid(scheduler): scheduler.unregister(self)
		return
	if scheduler == null:
		scheduler = scheduler_ref.get_ref() if scheduler_ref != null else null
		if scheduler == null:
			scheduler = SCHEDULER.new()
			scheduler.name = "ItemVisualScheduler"
			scheduler.motion_enabled = not reduced_motion
			scheduler_ref = weakref(scheduler)
			get_tree().root.add_child.call_deferred(scheduler)
	if rank >= 3 and context not in ["quickslot","list","drag","ground"]:
		scheduler.register(self)
	else:
		scheduler.unregister(self)

func refresh_visibility() -> bool:
	if target == null or not is_instance_valid(target): return false
	if source_presentation:
		target.material = null
		return false
	var animate: bool = not reduced_motion and rank >= 3 and context not in ["quickslot","list","drag","ground"] and target.is_inside_tree() and SCHEDULER.visible_area(target)
	# An unsupported opaque frame may retain a non-rotating sheen, but must
	# never be fed to rank 5/6's UV turn. Shared material count remains <= 32.
	var shader_rank: int = 4 if rank >= 5 and not foreground_ready else rank
	target.material = shared_material(shader_rank,phase_group) if animate else null
	return animate

func deactivate() -> void:
	if is_instance_valid(target): _detach_source_scene(target)
	rank = 0
	source_presentation = false
	foreground_ready = true
	if target != null: target.material = null
	if substitute_mark != null: substitute_mark.hide()
	if is_instance_valid(scheduler): scheduler.unregister(self)

func _exit_tree() -> void:
	if is_instance_valid(target): _detach_source_scene(target,false)
	if is_instance_valid(scheduler): scheduler.unregister(self)
