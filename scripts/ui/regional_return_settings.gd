extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
var world: Node
var toggle: CheckButton
var status: Label

func configure(hud: Node) -> void:
	name = "RegionalReturnSettings"
	world = hud.get_parent()
	add_child(UI.label("퀵슬롯 귀환 주문서", 18, UI.GOLD))
	toggle = CheckButton.new()
	toggle.name = "RegionalReturnEnabled"
	toggle.text = "지역별 귀환 주문서 자동 변경"
	toggle.button_pressed = world.get_regional_return_enabled()
	toggle.toggled.connect(func(value: bool) -> void: world.set_regional_return_enabled(value))
	add_child(toggle)
	add_child(UI.section("잊혀진 섬에서 귀환 슬롯을 지역 전용 주문서로 전환합니다. 원래 슬롯은 보존되며 전용 주문서가 없으면 사용할 수 없습니다.", 12))
	add_child(UI.section("기존 잊혀진 섬 지도는 TWILIGHT 대응: 지역 시작 지점으로 귀환합니다.", 12))
	status = UI.section("", 12)
	status.name = "RegionalReturnStatus"
	add_child(status)
	world.regional_return_settings_updated.connect(_sync)
	_sync()

func _sync() -> void:
	toggle.set_pressed_no_signal(world.get_regional_return_enabled())
	status.text = world.regional_return_status()
