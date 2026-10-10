extends Control
## Run this scene manually. It is never launched by Main.tscn.
const BRIDGE_SCRIPT = preload("res://addons/twilight_l1j/twilight_selective_bridge.gd")
var bridge: RefCounted = BRIDGE_SCRIPT.new()
var _image: TextureRect
var _status: Label
var _candidate: LineEdit
var _sprite: LineEdit
var _sprite_origin: OptionButton
var _map: LineEdit
var _map_origin: OptionButton
var _frames: SpriteFrames = null
var _frame_index: int = 0
var _clock: float = 0.0

func _ready() -> void:
    var outer := VBoxContainer.new()
    outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    outer.add_theme_constant_override("separation", 10)
    add_child(outer)

    var heading := Label.new()
    heading.text = "TWILIGHT L1J 리소스 미리보기 (원본 게임과 분리됨)"
    outer.add_child(heading)
    var info := Label.new()
    info.text = "기본값은 전부 꺼짐. 해당 기능을 체크해야 미리볼 수 있습니다."
    outer.add_child(info)

    var flags := HFlowContainer.new()
    outer.add_child(flags)
    _feature_checkbox(flags, "item_icon", "아이템")
    _feature_checkbox(flags, "ground_icon", "바닥")
    _feature_checkbox(flags, "npc_portrait", "몬스터")
    _feature_checkbox(flags, "sprite_frames", "애니메이션")
    _feature_checkbox(flags, "map_attributes", "맵 속성")

    var row1 := HBoxContainer.new()
    outer.add_child(row1)
    _candidate = LineEdit.new()
    _candidate.text = "ext:a3:weapon:1"
    _candidate.custom_minimum_size.x = 250
    row1.add_child(_candidate)
    _button(row1, "아이템 보기", _show_item)
    _button(row1, "바닥 보기", _show_ground)
    _button(row1, "몬스터 보기", _show_portrait)

    var row2 := HBoxContainer.new()
    outer.add_child(row2)
    _sprite = LineEdit.new()
    _sprite.text = "19521-0"
    _sprite.custom_minimum_size.x = 140
    row2.add_child(_sprite)
    _sprite_origin = OptionButton.new()
    _sprite_origin.add_item("SPX")
    _sprite_origin.add_item("SPR")
    row2.add_child(_sprite_origin)
    _button(row2, "애니메이션 보기", _show_frames)

    var row3 := HBoxContainer.new()
    outer.add_child(row3)
    _map = LineEdit.new()
    _map.text = "101"
    _map.custom_minimum_size.x = 140
    row3.add_child(_map)
    _map_origin = OptionButton.new()
    _map_origin.add_item("a3")
    _map_origin.add_item("jp")
    row3.add_child(_map_origin)
    _button(row3, "맵 속성 보기", _show_map)

    _image = TextureRect.new()
    _image.custom_minimum_size = Vector2(500, 350)
    _image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _image.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    outer.add_child(_image)
    _status = Label.new()
    _status.text = "아직 불러온 리소스 없음"
    outer.add_child(_status)

func _feature_checkbox(parent: Control, kind: String, caption: String) -> void:
    var check := CheckBox.new()
    check.text = caption
    check.button_pressed = false
    parent.add_child(check)
    check.toggled.connect(_toggle.bind(kind))

func _toggle(pressed: bool, kind: String) -> void:
    bridge.call("set_feature_enabled", kind, pressed)
    _clear_preview()
    _status.text = "%s %s" % [kind, "켜짐" if pressed else "꺼짐"]

func _button(parent: Control, caption: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.pressed.connect(callback)
    parent.add_child(b)

func _clear_preview() -> void:
    _frames = null
    _image.texture = null

func _show_texture(texture: Texture2D, label: String) -> void:
    _clear_preview()
    _image.texture = texture
    _status.text = label if texture != null else "없음 / 기능 비활성 / 변환팩 미설치"

func _show_item() -> void:
    _show_texture(bridge.call("item_icon", _candidate.text) as Texture2D, "인벤토리 아이콘: " + _candidate.text)

func _show_ground() -> void:
    _show_texture(bridge.call("ground_icon", _candidate.text) as Texture2D, "바닥 아이콘: " + _candidate.text)

func _show_portrait() -> void:
    _show_texture(bridge.call("npc_portrait", _candidate.text) as Texture2D, "몬스터 초상화: " + _candidate.text)

func _show_frames() -> void:
    _clear_preview()
    var origin: String = "spx" if _sprite_origin.selected == 0 else "spr"
    _frames = bridge.call("sprite_frames", _sprite.text, origin) as SpriteFrames
    _frame_index = 0
    _clock = 0.0
    if _frames != null and _frames.has_animation("default") and _frames.get_frame_count("default") > 0:
        _image.texture = _frames.get_frame_texture("default", 0)
        _status.text = "%s %s : %d프레임" % [origin, _sprite.text, _frames.get_frame_count("default")]
    else:
        _frames = null
        _status.text = "애니메이션 없음 / 기능 비활성 / 변환팩 미설치"

func _show_map() -> void:
    if not _map.text.is_valid_int():
        _show_texture(null, "")
        return
    var origin: String = "a3" if _map_origin.selected == 0 else "jp"
    _show_texture(bridge.call("map_attribute", int(_map.text), origin) as Texture2D, "%s 맵 %s 속성도 (지형 텍스처 아님)" % [origin, _map.text])

func _process(delta: float) -> void:
    if _frames == null or not _frames.has_animation("default"):
        return
    var count: int = _frames.get_frame_count("default")
    if count < 1:
        return
    var rate: float = maxf(0.1, _frames.get_animation_speed("default"))
    _clock += delta
    if _clock < 1.0 / rate:
        return
    _clock = 0.0
    _frame_index = (_frame_index + 1) % count
    _image.texture = _frames.get_frame_texture("default", _frame_index)
