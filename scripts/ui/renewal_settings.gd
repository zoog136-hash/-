extends VBoxContainer

# Presentation options only. No gameplay/save/schema changes.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Dialog = preload("res://scripts/ui/renewal_dialog.gd")
const SETTINGS_PATH = "user://twilight_ui_settings.cfg"
var hud: Node
var config: ConfigFile = ConfigFile.new()
var volume: HSlider
var mute: CheckButton

static func apply_saved(controller: Node) -> void:
	var saved := ConfigFile.new()
	if saved.load(SETTINGS_PATH) != OK: return
	if controller.log_label != null:
		controller.log_label.visible = bool(saved.get_value("interface","combat_log",true))
	if controller.coordinates_readout != null:
		controller.coordinates_readout.visible = bool(saved.get_value("interface","coordinates",true))
	if AudioServer.get_bus_count() > 0:
		var level := clampf(float(saved.get_value("audio","volume",100.0)),0.0,100.0)
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,level/100.0)))
		AudioServer.set_bus_mute(0,bool(saved.get_value("audio","muted",false)) or level <= 0.0)

func configure(controller: Node) -> void:
	hud = controller
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config.load(SETTINGS_PATH)
	var scroller := ScrollContainer.new()
	scroller.name = "SettingsScroll"
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroller)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",12)
	scroller.add_child(stack)
	stack.add_child(UI.section("환경 설정",17))
	stack.add_child(UI.section("게임 화면 · 오디오 · 저장",12))
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("오디오",18,UI.GOLD))
	var audio := HBoxContainer.new()
	stack.add_child(audio)
	audio.add_child(UI.label("전체 음량",14))
	volume = HSlider.new()
	volume.name = "MasterVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.x = 120
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value = float(config.get_value("audio","volume",100.0))
	volume.value_changed.connect(_volume_changed)
	audio.add_child(volume)
	mute = CheckButton.new()
	mute.text = "음소거"
	mute.button_pressed = bool(config.get_value("audio","muted",false))
	mute.toggled.connect(_mute_changed)
	audio.add_child(mute)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("HUD 표시",18,UI.GOLD))
	var log_toggle := CheckButton.new()
	log_toggle.name = "CombatLogToggle"
	log_toggle.text = "전투 로그 표시"
	log_toggle.button_pressed = hud.log_label.visible
	log_toggle.toggled.connect(func(enabled: bool) -> void:
		hud.log_label.visible = enabled
		_store("interface","combat_log",enabled))
	stack.add_child(log_toggle)
	var coord_toggle := CheckButton.new()
	coord_toggle.name = "CoordinateToggle"
	coord_toggle.text = "좌표 표시"
	coord_toggle.button_pressed = hud.coordinates_readout != null and hud.coordinates_readout.visible
	coord_toggle.toggled.connect(func(enabled: bool) -> void:
		if hud.coordinates_readout != null: hud.coordinates_readout.visible = enabled
		_store("interface","coordinates",enabled))
	stack.add_child(coord_toggle)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("게임 데이터",18,UI.GOLD))
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	actions.add_child(UI.button("지금 저장",func() -> void: hud.save_pressed.emit(),Vector2(180,48)))
	actions.add_child(UI.button("저장본 불러오기",_confirm_load,Vector2(190,48)))
	stack.add_child(UI.section("불러오기 전, 현재 진행도를 저장하세요.",12))
	var nav := HBoxContainer.new()
	stack.add_child(nav)
	nav.add_child(UI.button("월드맵",func() -> void: hud._navigate("map")))
	nav.add_child(UI.button("캐릭터 · 장비",func() -> void: hud._navigate("character")))

func _store(section: String,key: String,value: Variant) -> void:
	config.set_value(section,key,value)
	var error := config.save(SETTINGS_PATH)
	if error != OK: push_warning("Could not save UI preferences: %d" % error)

func _volume_changed(value: float) -> void:
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value/100.0)))
		AudioServer.set_bus_mute(0,mute.button_pressed or value <= 0.0)
	_store("audio","volume",value)

func _mute_changed(value: bool) -> void:
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0,value or volume.value <= 0.0)
	_store("audio","muted",value)

func _confirm_load() -> void:
	var dialog := Dialog.new()
	dialog.title_text = "저장된 게임 불러오기"
	dialog.message_text = "현재 미저장 진행도가 사라질 수 있습니다. 저장본을 불러올까요?"
	hud.get_node("Root").add_child(dialog)
	dialog.confirmed.connect(func() -> void: hud.load_pressed.emit())
