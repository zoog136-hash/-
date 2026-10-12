extends Node
## Reusable presentation attached once to an existing TextureRect. Texture pixels
## alone receive the shader; slot chrome, badges, labels and input stay untouched.
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const SCHEDULER = preload("res://scripts/ui/item_visual_scheduler.gd")
const SHADER = preload("res://scripts/ui/item_rarity.gdshader")
const GRADES: Array[String] = ["일반","고급","희귀","영웅","전설","신화","유일"]
const COLORS: Array[Color] = [Color("ddd6c5"),Color("79bf83"),Color("73b4ee"),Color("e97772"),Color("bc89e3"),Color("e5be60"),Color("66dfc2")]
static var materials: Dictionary = {}
static var scheduler_ref: WeakRef
var target: TextureRect
var rank: int = 0
var phase_group: int = 0
var context: String = "slot"
var scheduler: Node
var substitute_mark: Label

static func apply(view: TextureRect, record: Dictionary, item_name: String, images: Dictionary = {}, usage: String = "slot") -> void:
	var effect: Node = view.get_node_or_null("ItemVisual")
	if effect == null:
		effect = new()
		effect.name = "ItemVisual"
		view.add_child(effect)
	effect.configure(view, record, item_name, images, usage)

static func clear(view: TextureRect) -> void:
	if view == null: return
	view.material = null
	var effect: Node = view.get_node_or_null("ItemVisual")
	if effect != null: effect.deactivate()

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

func configure(view: TextureRect, record: Dictionary, item_name: String, images: Dictionary, usage: String) -> void:
	target = view
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	target.texture = RESOLVER.texture(record,item_name,images)
	rank = maxi(0,GRADES.find(str(record.get("grade","일반"))))
	phase_group = posmod((str(record.get("sourceId",""))+item_name).hash(),8)
	context = usage
	var info: Dictionary = RESOLVER.describe(record,item_name,images)
	target.set_meta("item_visual",info)
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
	substitute_mark.visible = info.status == "self_authored_substitute"
	if not target.visibility_changed.is_connected(refresh_visibility): target.visibility_changed.connect(refresh_visibility)
	if is_inside_tree(): _register()
	refresh_visibility()

func _ready() -> void:
	set_process(false)
	if target != null: _register()

func _register() -> void:
	if scheduler == null:
		scheduler = scheduler_ref.get_ref() if scheduler_ref != null else null
		if scheduler == null:
			scheduler = SCHEDULER.new()
			scheduler.name = "ItemVisualScheduler"
			scheduler_ref = weakref(scheduler)
			get_tree().root.add_child.call_deferred(scheduler)
	if rank >= 3 and context not in ["quickslot","list","drag","ground"]:
		scheduler.register(self)
	else:
		scheduler.unregister(self)

func refresh_visibility() -> bool:
	if target == null or not is_instance_valid(target): return false
	var animate: bool = rank >= 3 and context not in ["quickslot","list","drag","ground"] and target.is_inside_tree() and SCHEDULER.visible_area(target)
	target.material = shared_material(rank,phase_group) if animate else null
	return animate

func deactivate() -> void:
	rank = 0
	if target != null: target.material = null
	if substitute_mark != null: substitute_mark.hide()
	if is_instance_valid(scheduler): scheduler.unregister(self)

func _exit_tree() -> void:
	if is_instance_valid(scheduler): scheduler.unregister(self)
