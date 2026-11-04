extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Rules = preload("res://scripts/cards/native_halphas_star_enchant.gd")
var world: Node
var category: String
var identity: String
var status_label: Label
var attempt_button: Button

func configure(host: Node, category_value: String, identity_value: String) -> void:
	world = host
	category = category_value
	identity = identity_value
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var state: Dictionary = Rules.from_world(world, category, identity)
	if not state.ok:
		add_child(UI.label(str(state.get("error", "성급 강화 정보를 확인할 수 없습니다")), 15, UI.MUTED))
		return
	var ownership: String = "보유" if state.owned else "미보유"
	add_child(UI.label(ownership + " · 강화 이력 연결 대기", 14, UI.MUTED))
	var note: Label = UI.label("외형 선택은 강화 단계로 계산하지 않습니다.", 14, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	for row: Dictionary in state.stages:
		var line: Label = UI.label("%d단계 · 유일 등급 카드 %d장 · 아데나 %s" % [int(row.Enchant), int(row.SourceAmount), str(int(row.CurrencyCost))], 16, UI.TEXT)
		line.name = "HalphasStage" + str(int(row.Enchant))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(line)
		var pending: Label = UI.label("재료 종류·성공 확률·단계 효과 확인 중", 13, UI.MUTED)
		pending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(pending)
	status_label = UI.label(str(state.blocked_reason), 14, UI.MUTED)
	status_label.name = "HalphasStarEnchantStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	var check_button: Button = UI.button("강화 조건 다시 확인", _attempt, Vector2(0, 48))
	check_button.name = "HalphasStarEnchantCheck"
	check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(check_button)
	attempt_button = UI.button("성급 강화 · 원본 비활성" if state.problems.has("source_feature_disabled") else "성급 강화 · 조건 확인 중", _attempt, Vector2(0, 48))
	attempt_button.name = "HalphasStarEnchantAttempt"
	attempt_button.disabled = not bool(state.can_attempt)
	attempt_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(attempt_button)

func _attempt() -> void:
	var result: Dictionary = Rules.from_world(world, category, identity, true)
	status_label.text = "확인 결과 · " + str(result.get("error", "강화 조건을 확인 중입니다"))
