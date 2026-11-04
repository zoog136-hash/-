extends Window
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Native=preload("res://scripts/cards/native_collection_rules.gd")
const Policy=preload("res://scripts/cards/collection_policy.gd")
var runtime
var controls: Dictionary={}
var status: Label
var server_profile: OptionButton
var ok_button: Button
var cancel_button: Button
func configure(value) -> void:
	runtime=value;name="CollectionPolicyDialog";title="컬렉션 적용 규칙 · 로컬 추정";theme=UI.make_theme()
	wrap_controls=false;min_size=Vector2i(480,320);exclusive=true;transient=true
	var panel:=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins:=MarginContainer.new();panel.add_child(margins)
	for edge: String in ["left","top","right","bottom"]:margins.add_theme_constant_override("margin_"+edge,12)
	var box:=VBoxContainer.new();margins.add_child(box)
	var note:=UI.label("원본 수치·단위와 기존 PvP→PvE 규칙을 우선합니다. 아래는 확인되지 않은 실행 방식의 로컬 설정입니다. 원본 카드·비용·확률·소유 기록은 변경하지 않습니다.",13,UI.GOLD)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.custom_minimum_size.x=440;box.add_child(note)
	var scroll:=ScrollContainer.new();scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(grid)
	var profile_label:=UI.label("원본 서버조건 평가 프로필 (오프라인 선택 · 계정 정보 아님)",12);profile_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;profile_label.custom_minimum_size.x=310;grid.add_child(profile_label)
	server_profile=OptionButton.new();server_profile.name="PolicySourceProfile";server_profile.add_item("미설정");server_profile.set_item_metadata(0,{})
	server_profile.custom_minimum_size=Vector2(120,44);grid.add_child(server_profile);server_profile.get_popup().max_size.y=300
	var profiles: Dictionary={}
	if runtime.core is Native:
		for group: Array in runtime.core.conditions.profiles.values():
			for row: Dictionary in group:
				var context: Dictionary={"source_snapshot":"base508","ServiceRegionCode":row.ServiceRegionCode,"WorldNo":row.WorldNo}
				if preload("res://scripts/cards/source_collection_conditions.gd").valid_context(context):profiles[str(row.ServiceRegionCode)+" · "+str(int(row.WorldNo))]=context
	var labels: Array=profiles.keys();labels.sort()
	var selected: Dictionary=runtime.source_server_context()
	for label: String in labels:
		var at: int=server_profile.item_count;server_profile.add_item(label);server_profile.set_item_metadata(at,profiles[label])
		if profiles[label]==selected:server_profile.select(at)
	for spec: Dictionary in Policy.SPECS:
		var label:=UI.label(str(spec.label),12);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=310;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(label)
		var control: Control
		if spec.get("bool",false):
			var toggle:=CheckButton.new();toggle.button_pressed=bool(runtime.policy_values[spec.key]);toggle.set_script(preload("res://scripts/ui/native_touch_button.gd"));control=toggle
		else:
			var spin:=SpinBox.new();spin.min_value=spec.min;spin.max_value=spec.max;spin.step=spec.step;spin.value=float(runtime.policy_values[spec.key]);control=spin
		control.name="Policy_"+str(spec.key);control.custom_minimum_size=Vector2(120,44);controls[spec.key]=control;grid.add_child(control)
	status=UI.label(runtime.policy_problem if not runtime.policy_problem.is_empty() else "현재 설정 · 원본과 별도로 저장",12,UI.MUTED);box.add_child(status)
	var actions:=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_END;box.add_child(actions)
	cancel_button=UI.button("취소",queue_free,Vector2(100,44));actions.add_child(cancel_button)
	ok_button=UI.button("적용 · 저장",_apply,Vector2(130,44));actions.add_child(ok_button)
	for button: Button in [cancel_button,ok_button]:button.set_script(preload("res://scripts/ui/native_touch_button.gd"))
	close_requested.connect(queue_free)
	popup_centered(Vector2i(mini(680,get_tree().root.size.x-20),mini(560,get_tree().root.size.y-60)))
func _apply() -> void:
	var values: Dictionary={}
	for key: String in controls:
		var control: Control=controls[key]
		values[key]=control.button_pressed if control is BaseButton else control.value
	var result: Dictionary=runtime.apply_policy(values,server_profile.get_item_metadata(server_profile.selected))
	if result.ok:queue_free()
	else:
		status.text=str(result.error);show()

func get_ok_button() -> Button:return ok_button
func get_cancel_button() -> Button:return cancel_button
