extends VBoxContainer
## Editable host fallbacks; native HP percentages/costs/durations stay read-only.
const UI=preload("res://scripts/ui/renewal_theme.gd")
var source: RefCounted
var selector: OptionButton
var origin: Label
var result: Label
var cooldown: SpinBox
var heal: SpinBox
var cap: SpinBox
var average: CheckButton
var heal_row: HBoxContainer
var cap_row: HBoxContainer
var ids: Array=[]

func configure(hud: Node) -> void:
	name="SkillRecovery523Settings"
	source=hud.get_parent().original_skills.catalog.source523
	add_child(UI.label("복합 회복 스킬 · 원본 + TWILIGHT 설정",18,UI.GOLD))
	add_child(UI.section("확인된 회복 비율·비용·지속은 원본을 사용합니다. 정의가 없는 회복량과 게임 재사용/보호막 상한만 조절합니다. 다음 시전부터 적용되며 진행 저장과 분리됩니다.",12))
	selector=OptionButton.new();selector.name="Recovery523Skill"
	for id: String in source.recovery_rules.rules:
		ids.append(id);selector.add_item(str(source.recovery_rules.rules[id].name))
	add_child(selector)
	origin=UI.label("",12,UI.TEXT);origin.name="Recovery523Origin";origin.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(origin)
	cooldown=spin("추정 재사용 (초)",.1,3600,.1,"Recovery523Cooldown").get_child(1)
	heal_row=spin("추정 HP 회복량",0,100000,1,"Recovery523Heal");heal=heal_row.get_child(1)
	cap_row=spin("추정 보호막 상한 (최대HP %)",1,100,1,"Recovery523ShieldCap");cap=cap_row.get_child(1)
	average=CheckButton.new();average.name="Recovery523AverageDice";average.text="주사위 평균값 사용 (계수는 원본 · 조합 산식은 TWILIGHT)";add_child(average)
	result=UI.label("",12,UI.MUTED);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.name="Recovery523Result";add_child(result)
	selector.item_selected.connect(func(_index: int) -> void: refresh())
	cooldown.value_changed.connect(change.bind("cooldown"))
	heal.value_changed.connect(change.bind("heal"))
	cap.value_changed.connect(change.bind("shield_cap_percent"))
	average.toggled.connect(func(enabled: bool) -> void:change(1.0 if enabled else 0.0,"average_dice"))
	refresh()

func spin(label: String, minimum: float, maximum: float, step: float, control_name: String) -> HBoxContainer:
	var row:=HBoxContainer.new();add_child(row)
	var title:=UI.label(label,13);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
	var control:=SpinBox.new();control.name=control_name;control.min_value=minimum;control.max_value=maximum;control.step=step;control.custom_minimum_size.x=120;row.add_child(control)
	return row

func refresh() -> void:
	var id: String=ids[selector.selected]
	var rule: Dictionary=source.recovery_rules.rules[id]
	var spec: Dictionary=source.recovery_rules.spec_for(id,source.profiles.get(id,{})) if source.profiles.has(id) else {}
	cooldown.set_value_no_signal(source.recovery_rules.value_for(id,"cooldown"))
	heal_row.visible=rule.defaults.has("heal");cap_row.visible=rule.defaults.has("shield_cap_percent")
	average.visible=rule.defaults.has("average_dice")
	if average.visible:average.set_pressed_no_signal(source.recovery_rules.value_for(id,"average_dice")>=.5)
	if heal_row.visible:heal.set_value_no_signal(source.recovery_rules.value_for(id,"heal"))
	if cap_row.visible:cap.set_value_no_signal(source.recovery_rules.value_for(id,"shield_cap_percent"))
	origin.text="추가 원본 구성 팩을 설치하면 적용됩니다. 기존8종 추정 규칙은 유지됩니다." if spec.is_empty() else str(spec.meta.summary)
	result.text=source.recovery_rules.last_error

func change(value: float, key: String) -> void:
	var id: String=ids[selector.selected]
	if source.set_recovery_setting(id,key,value):
		refresh();result.text="TWILIGHT 설정 저장됨 · 다음 시전에 적용 · 원본 수치는 유지"
	else:result.text=source.recovery_rules.last_error
