extends Node2D
## Opt-in host sample beside the player; never NPC identity, collision or source origin.
const PLAYBACK = preload("res://scripts/resources/current523_playback.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
var _revision: int = -1
var _options: Dictionary = {}
var _parsed: Dictionary = {}
var _group: int = -1
var _clock: float = 0.0
var frame_index: int = -1
var _textures: Dictionary = {}
var sprite: Sprite2D
var label: Label
var problem: String = ""
var _overriding_host: bool = false

func _ready() -> void:
	name = "Current523EstimatedWorldPreview"
	process_priority = 100 # Apply visibility after host movement/attack presentation.
	z_index = 200
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	label = Label.new()
	label.position = Vector2(0,24)
	label.z_as_relative = false
	label.z_index = 4000 # Keep the estimate annotation above world foreground art.
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color(1.0,0.8,0.35))
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",2)
	add_child(label)
	_reload()

func _reload() -> void:
	_restore_host()
	_revision = PLAYBACK.revision
	_options = PLAYBACK.options()
	visible = bool(_options.enabled) and bool(_options.world_enabled)
	_parsed = {}
	_group = -1
	_clock = 0.0
	frame_index = -1
	_textures.clear()
	sprite.texture = null
	problem = ""
	if not visible: return
	position = Vector2(float(_options.world_x),float(_options.world_y))
	sprite.scale = Vector2.ONE * float(_options.zoom)
	sprite.modulate.a = float(_options.opacity)
	var material_value := CanvasItemMaterial.new()
	material_value.blend_mode = {"mix":CanvasItemMaterial.BLEND_MODE_MIX,"add":CanvasItemMaterial.BLEND_MODE_ADD,"multiply":CanvasItemMaterial.BLEND_MODE_MUL}[_options.blend]
	sprite.material = material_value
	var loaded: Dictionary = PLAYBACK.load_member(str(_options.member))
	if not loaded.ok:
		problem = str(loaded.error)
		label.text = "523 추정 샘플 중단 · " + problem
		return
	_parsed = loaded.parsed
	for index: int in range(_parsed.groups.size()):
		if int(_parsed.groups[index].bit) == int(_options.group_bit): _group = index
	if _group < 0 or _parsed.groups[_group].frames.is_empty():
		problem = "저장 그룹에 프레임이 없습니다."
		label.text = "523 추정 샘플 중단 · " + problem
		return
	_show_frame(0)

func _process(delta: float) -> void:
	if _revision != PLAYBACK.revision: _reload()
	if not visible or _group < 0 or not problem.is_empty():
		_restore_host()
		return
	_clock += delta
	var count: int = _parsed.groups[_group].frames.size()
	var index: int = int(floor(_clock * float(_options.fps)))
	index = index % count if bool(_options.loop) else mini(index,count-1)
	if index != frame_index: _show_frame(index)
	_sync_host()

func _sync_host() -> void:
	if str(_options.get("world_target","sample")) != "player" or sprite.texture == null:
		_restore_host()
		return
	_overriding_host = true
	var host: Node = get_parent()
	if host != null and host.has_method("_refresh_visual_visibility"): host._refresh_visual_visibility()

func is_player_override_active() -> bool:
	return _overriding_host

func _restore_host() -> void:
	if not _overriding_host: return
	_overriding_host = false
	var host: Node = get_parent()
	if host != null and host.is_inside_tree() and not host.is_queued_for_deletion() and host.has_method("_refresh_visual_visibility"): host._refresh_visual_visibility()

func _exit_tree() -> void:
	_restore_host()

func _show_frame(index: int) -> void:
	if not _textures.has(index):
		var rendered: Dictionary = DECODER.render(_parsed,_group,index,_options)
		if not rendered.ok:
			problem = str(rendered.error)
			sprite.texture = null
			_restore_host()
			label.text = "523 추정 샘플 중단 · " + problem
			return
		if _textures.size() >= 8: _textures.erase(_textures.keys()[0])
		_textures[index] = {"texture":ImageTexture.create_from_image(rendered.image),"offset":rendered.offset}
	frame_index = index
	sprite.texture = _textures[index].texture
	sprite.position = Vector2(_textures[index].offset) * float(_options.zoom)
	var target_text: String = "플레이어 외형 추정" if str(_options.get("world_target","sample")) == "player" else "추정 샘플"
	label.text = "523 %s · %s · 저장 %d / %d\n표시·순서·속도·배치 추정 / 게임 판정 없음" % [target_text,str(_options.member).trim_prefix("Sprite/"),index+1,_parsed.groups[_group].frames.size()]
