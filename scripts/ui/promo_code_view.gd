extends VBoxContainer
## Promotion code entry: one text field, a redeem button and a result line.

var world
var code_input: LineEdit
var redeem_button: Button
var status: Label

func configure(target_world) -> void:
	world = target_world
	add_theme_constant_override("separation", 12)
	var hint := Label.new()
	hint.text = "쿠폰 코드를 입력하면 보상이 바로 지급됩니다."
	hint.add_theme_font_size_override("font_size", 16)
	add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	code_input = LineEdit.new()
	code_input.name = "PromoCodeInput"
	code_input.placeholder_text = "코드 입력"
	code_input.max_length = 32
	code_input.custom_minimum_size = Vector2(260, 52)
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_input.add_theme_font_size_override("font_size", 20)
	code_input.text_submitted.connect(func(_text: String) -> void: _redeem())
	row.add_child(code_input)
	redeem_button = Button.new()
	redeem_button.name = "PromoCodeRedeem"
	redeem_button.text = "사용"
	redeem_button.custom_minimum_size = Vector2(110, 52)
	redeem_button.add_theme_font_size_override("font_size", 18)
	redeem_button.pressed.connect(_redeem)
	row.add_child(redeem_button)
	status = Label.new()
	status.name = "PromoCodeStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 16)
	add_child(status)

func _redeem() -> void:
	if world == null or not world.has_method("redeem_promo_code"):
		status.text = "지금은 코드를 사용할 수 없습니다"
		return
	var result: Dictionary = world.redeem_promo_code(code_input.text)
	if bool(result.get("ok", false)):
		status.text = "지급 완료 · 다이아 %d · 아데나 %d" % [int(result.diamond_gain), int(result.gold_gain)]
		code_input.clear()
	else:
		status.text = str(result.get("reason", "코드를 사용할 수 없습니다"))
	if code_input.is_inside_tree() and code_input.is_visible_in_tree():
		code_input.grab_focus()
