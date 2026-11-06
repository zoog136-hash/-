extends Control
var service

func configure(value) -> void:
	service = value
	name = "Death523Overlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 4000
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03,0.02,0.02,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330,260)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "사망 · 부활"
	title.add_theme_font_size_override("font_size",26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := Label.new()
	info.name = "Death523Summary"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 310
	if not service.pending.is_empty():
		info.text = "사망 내역 저장 실패\n경험치·아이템 손실을 추가 적용하지 않았습니다.\n저장을 재시도해 주세요."
	else:
		var entry: Dictionary = service._entry(str(service.state.dead_id))
		var item: Dictionary = entry.get("item",{})
		info.text = "경험치 손실 %d\n아이템 손실: %s\n부활 후 메뉴 → 사망 복구에서 복구할 수 있습니다.\n시작 지점 부활은 무료입니다.\n회복량: TWILIGHT 자체 정책" % [int(entry.get("exp",0)),"없음" if item.is_empty() else str(item.physical.name)+" (원래 장비 보관)"]
	var source_entry: Dictionary=service._entry(str(service.state.dead_id))
	if not service.pending.is_empty():source_entry=service._staged_entry(service.pending.state,str(service.pending.state.dead_id))
	var origin: String=service.source_location_text(source_entry)
	if not origin.is_empty():info.text+="\n사망 위치: "+origin
	box.add_child(info)
	var result := Label.new()
	result.name = "Death523Result"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result)
	var action := Button.new()
	action.name = "Death523Restart"
	action.custom_minimum_size.y = 54
	action.text = "저장 재시도" if not service.pending.is_empty() else "현재 지역 시작 지점에서 부활"
	box.add_child(action)
	action.pressed.connect(func() -> void:
		if not service.pending.is_empty(): service.begin_death("사망 저장 재시도")
		else:
			var response: Dictionary = service.resurrect()
			result.text = str(response.message)
			if response.ok:
				service.world.hud.show_message(str(response.message))
				service.open_ui())
	action.grab_focus()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch: accept_event()
