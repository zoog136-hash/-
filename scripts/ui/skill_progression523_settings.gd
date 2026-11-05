extends VBoxContainer
const UI=preload("res://scripts/ui/renewal_theme.gd")
const SourceImages=preload("res://scripts/ui/source523_skill_buff_images.gd")
const LABELS={"light_radius":"조명 표시 반경(px)","radius":"호스트 반경(px)","interval":"호스트 발동/갱신 간격(초)","power":"추정 기본 위력","range":"호스트 사거리(px)","cooldown":"호스트 재사용(초)","cast_time":"호스트 시전 시간(초)","hits":"추정 연사 수","average_dice":"주사위 평균값 사용(0/1)"}
var source: RefCounted
var selector: OptionButton
var info: Label
var inputs: VBoxContainer
var result: Label
var ids: Array=[]

func configure(hud: Node) -> void:
	name="SkillProgression523Settings"
	source=hud.get_parent().original_skills.catalog.source523
	add_child(UI.label("기존 스킬 전환 · 원본 + TWILIGHT 설정",18,UI.GOLD))
	add_child(UI.section("원본 패시브/ON·OFF/발사 비용을 우선합니다. 아래는 조명 환산·발사 위력/시간 등 호스트 정책이며 다음 실행부터 적용됩니다. 진행 저장과 분리됩니다.",12))
	selector=OptionButton.new();selector.name="Progression523Skill"
	selector.expand_icon=true
	var original_images: Dictionary={}
	for id: String in source.progression_rules.rules:
		ids.append(id);selector.add_item(str(source.progression_rules.rules[id].name))
		# These rule keys are the existing host skill IDs used by the pinned
		# SpellClass binding. They are not native spell or icon numbers.
		var original: Dictionary=SourceImages.describe_skill({"id":id},"IconID")
		if original.get("handled",false):
			selector.set_item_icon(selector.item_count-1,original.get("texture") as Texture2D)
			original_images[id]=SourceImages.evidence(original)
	selector.set_meta("source523_images",original_images)
	add_child(selector)
	info=UI.label("",12);info.name="Progression523Origin";info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(info)
	inputs=VBoxContainer.new();add_child(inputs)
	result=UI.label("",12,UI.MUTED);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(result)
	selector.item_selected.connect(func(_i: int) -> void:refresh())
	refresh()

func refresh() -> void:
	for child: Node in inputs.get_children():inputs.remove_child(child);child.queue_free()
	var id: String=ids[selector.selected]
	var profile: Dictionary=source.profiles.get(id,{})
	var spec: Dictionary=source.progression_rules.spec_for(id,profile,source.recovery_rules.percent_denominator) if not profile.is_empty() else {}
	info.text="추가 실행 구성 팩이 필요합니다. 설정만으로 스킬/재료를 지급하지 않습니다." if spec.is_empty() else str(spec.meta.summary)
	for key: String in source.progression_rules.rules[id].defaults:
		var row:=HBoxContainer.new();inputs.add_child(row)
		var label:=UI.label(str(LABELS.get(key,key)),13);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var control:=SpinBox.new();control.name="Progression523_"+key;control.custom_minimum_size.x=120
		control.min_value=0;control.max_value=100000;control.step=.01 if key=="cast_time" else .1 if key in ["interval","cooldown"] else 1
		if key in ["hits","average_dice"]:control.max_value=12 if key=="hits" else 1
		control.value=source.progression_rules.value(id,key);row.add_child(control)
		control.value_changed.connect(func(value: float) -> void:
			if source.set_progression_setting(id,key,value):
				var current: Dictionary=source.profiles.get(id,{})
				var projected: Dictionary=source.progression_rules.spec_for(id,current,source.recovery_rules.percent_denominator) if not current.is_empty() else {}
				if not projected.is_empty():info.text=str(projected.meta.summary)
				result.text="TWILIGHT 설정 저장됨 · 다음 실행에 적용 · 원본 수치는 유지"
			else:result.text=source.progression_rules.policy.last_error)
	if source.progression_rules.rules[id].defaults.is_empty():inputs.add_child(UI.label("원본 확정값 · 편집할 추정 계수 없음",12,UI.MUTED))
	result.text=source.progression_rules.policy.last_error
