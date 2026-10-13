extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const POLICY = preload("res://scripts/consumable_auto_policy.gd")
var hud: Node
var settings: Dictionary = {}
var toggles: Dictionary = {}
var sliders: Dictionary = {}
var readouts: Dictionary = {}

func configure(controller: Node) -> void:
	name = "ConsumableAutoSettings"
	hud = controller
	var world: Node = hud.get_parent()
	settings = POLICY.normalize(world.call("get_consumable_auto_settings") if world != null and world.has_method("get_consumable_auto_settings") else {})
	add_theme_constant_override("separation", 10)
	add_child(UI.label("소모품 자동 사용", 18, UI.GOLD))
	add_child(UI.section("AUTO로 등록한 퀵슬롯에만 적용됩니다. HP 회복을 먼저 사용하며 수동 사용 조건은 바꾸지 않습니다.", 12))
	_add_control("hp", "HP 회복제", "AutoHP")
	_add_control("mp", "즉시 MP 회복제", "AutoMP")
	_add_control("long_mp", "긴 재사용 MP 회복제 · 마녀의 마력 회복제", "AutoLongMP")
	add_child(UI.section("표시 비율 이하에서 사용 · 긴 재사용 회복제는 별도 허용 필요 · 지속 회복 물약은 기존 버프가 없을 때 유지합니다.", 12))
	if hud.has_signal("consumable_auto_settings_updated"):
		hud.connect("consumable_auto_settings_updated", _sync)

func _add_control(key: String, caption: String, node_prefix: String) -> void:
	var toggle := CheckButton.new()
	toggle.name = node_prefix + "Enabled"
	toggle.text = caption
	toggle.button_pressed = bool(settings[key + "_enabled"])
	toggle.toggled.connect(_toggle_changed.bind(key))
	toggles[key] = toggle
	add_child(toggle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var slider := HSlider.new()
	slider.name = node_prefix + "Percent"
	slider.min_value = 5
	slider.max_value = 95
	slider.step = 5
	slider.custom_minimum_size = Vector2(120, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = int(settings[key + "_percent"])
	slider.value_changed.connect(_percent_changed.bind(key))
	sliders[key] = slider
	row.add_child(slider)
	var readout: Label = UI.label("%d%% 이하" % int(slider.value), 14)
	readout.custom_minimum_size.x = 80
	readouts[key] = readout
	row.add_child(readout)

func _toggle_changed(value: bool, key: String) -> void:
	settings[key + "_enabled"] = value
	_send()

func _percent_changed(value: float, key: String) -> void:
	settings[key + "_percent"] = int(value)
	(readouts[key] as Label).text = "%d%% 이하" % int(value)
	_send()

func _send() -> void:
	if is_instance_valid(hud) and hud.has_signal("consumable_auto_settings_changed"):
		hud.emit_signal("consumable_auto_settings_changed", settings.duplicate(true))

func _sync(value: Dictionary) -> void:
	settings = POLICY.normalize(value)
	for key: String in toggles.keys():
		(toggles[key] as CheckButton).set_pressed_no_signal(bool(settings[key + "_enabled"]))
		(sliders[key] as HSlider).set_value_no_signal(int(settings[key + "_percent"]))
		(readouts[key] as Label).text = "%d%% 이하" % int(settings[key + "_percent"])
