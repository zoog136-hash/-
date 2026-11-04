extends HBoxContainer

var catalogue: RefCounted
var owned_cards: Array = []
var spot_picker: OptionButton
var card_picker: ItemList
var group_picker: OptionButton
var details: RichTextLabel
var state_label: Label
var start_button: Button
var current_spot: int = 0
var runtime: RefCounted
var hud: Node
var job_label: Label
var result_message: String = ""
var refresh_time: float = 0.0

func configure(source: RefCounted, cards: Array, local_runtime: RefCounted = null, host_hud: Node = null) -> void:
	catalogue = source
	runtime = local_runtime
	hud = host_hud
	owned_cards = cards.duplicate(true)
	name = "ExpeditionSourceView"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.name = "ExpeditionChoicesScroll"
	choices_scroll.custom_minimum_size.x = 300
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(choices_scroll)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 8)
	choices_scroll.add_child(choices)
	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 8)
	add_child(results)
	var intro := Label.new()
	intro.text = "탐험·파견·성령 수집 · 원본 장소와 소유 카드 조건 확인"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(intro)
	if not catalogue.ready():
		intro.text += "\n" + catalogue.error
		return
	spot_picker = OptionButton.new()
	spot_picker.name = "ExpeditionSpotPicker"
	for spot: Dictionary in catalogue.spots():
		spot_picker.add_item("%s · %s" % [_deck_name(int(spot.BuffCardDeckID)), spot.Name], int(spot.ID))
	choices.add_child(spot_picker)
	var hint := Label.new()
	hint.text = "소유 카드 선택 (인형·성물 1장 / 변신 4장). 레벨은 스킬각성 레벨입니다."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(hint)
	card_picker = ItemList.new()
	card_picker.name = "ExpeditionOwnedCards"
	card_picker.select_mode = ItemList.SELECT_MULTI
	card_picker.custom_minimum_size.y = 88
	card_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(card_picker)
	var group_hint := Label.new()
	group_hint.text = "확인할 보상표 그룹 (보상표가 있어도 출발 가능을 뜻하지 않습니다)"
	group_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(group_hint)
	group_picker = OptionButton.new()
	group_picker.name = "ExpeditionRewardGroupPicker"
	choices.add_child(group_picker)
	state_label = Label.new()
	state_label.name = "ExpeditionEligibility"
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results.add_child(state_label)
	start_button = Button.new()
	start_button.name = "ExpeditionStartBlocked"
	start_button.text = "로컬 출발 · 이벤트·정산 미연결"
	start_button.disabled = true
	results.add_child(start_button)
	start_button.pressed.connect(_confirm_start)
	job_label = Label.new()
	job_label.name = "ExpeditionJobStatus"
	job_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results.add_child(job_label)
	details = RichTextLabel.new()
	details.name = "ExpeditionSourceDetails"
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.custom_minimum_size.y = 100
	details.bbcode_enabled = false
	results.add_child(details)
	spot_picker.item_selected.connect(func(_index: int) -> void: _select_spot())
	card_picker.multi_selected.connect(func(_index: int, _selected: bool) -> void: _render())
	group_picker.item_selected.connect(func(_index: int) -> void: _render())
	_select_spot()

func _deck_name(deck: int) -> String:
	return {1: "변신 파견", 2: "인형 탐험", 98: "성령 수집"}.get(deck, str(deck))

func _grade_name(grade: int) -> String:
	return {0: "제한 없음", 1: "일반", 2: "고급", 3: "희귀", 4: "영웅", 5: "전설", 32: "신화", 52: "유일"}.get(grade, "원본 등급 %d" % grade)

func _select_spot() -> void:
	current_spot = spot_picker.get_selected_id()
	var spot: Dictionary = catalogue.record("MagicDollExpeditionSpot", current_spot)
	card_picker.clear()
	for card: Dictionary in owned_cards:
		var source: Dictionary = catalogue.record("BuffCard", int(card.source_id))
		if int(source.get("BuffCardDeckID", 0)) != int(spot.BuffCardDeckID):
			continue
		var index := card_picker.add_item("%s · 스킬각성 Lv.%d" % [source.get("Name", str(card.source_id)), int(card.skill_awaken_level)])
		card_picker.set_item_metadata(index, card)
	group_picker.clear()
	for group: Dictionary in catalogue.rows("MagicDollExpeditionGroup"):
		if int(group.BuffCardDeckID) == int(spot.BuffCardDeckID):
			group_picker.add_item(str(group.Name), int(group.ID))
	_render()

func selected_cards() -> Array:
	var result: Array = []
	for index in card_picker.get_selected_items():
		result.append(card_picker.get_item_metadata(index).duplicate(true))
	return result

func selected_identities() -> Array:
	var result: Array = []
	for card: Dictionary in selected_cards():
		result.append(str(card.get("identity", "")))
	return result

func _process(delta: float) -> void:
	if runtime == null or not is_instance_valid(job_label): return
	refresh_time += delta
	if refresh_time >= 1.0:
		refresh_time = 0.0
		_refresh_jobs()

func _refresh_jobs() -> void:
	if runtime == null: return
	job_label.text = result_message
	for job: Dictionary in runtime.jobs_view():
		var spot: Dictionary = catalogue.record("MagicDollExpeditionSpot", int(job.spot_id))
		job_label.text += "\n%s · %s" % [spot.get("Name", str(job.spot_id)), ("남은 접속 시간 %d초" % int(job.remaining)) if job.status == "running" else "시간 종료 · 성공·실패 판정 및 보상 정산 대기"]

func _confirm_start() -> void:
	if runtime == null or hud == null: return
	var ids := selected_identities()
	var spot_id := current_spot
	var prepared: Dictionary = runtime.prepare(spot_id, ids)
	if not prepared.ok:
		result_message = str(prepared.error)
		_refresh_jobs()
		return
	hud.confirm_action("탐험 로컬 출발", "아데나 %d 소모 · 접속 중 8시간 진행\n이벤트 추첨·성공/실패·보상 정산은 미연결입니다. 시간이 끝나도 상자는 지급되지 않고 판정 대기로 남습니다. 오프라인 시간과 일일 초기화는 적용하지 않습니다." % int(prepared.cost), "출발", func(_count: int = 1) -> void:
		var result: Dictionary = runtime.start(spot_id, ids)
		result_message = str(result.get("message", result.get("error", "")))
		_render())

func _render() -> void:
	var inspection: Dictionary = catalogue.inspect(current_spot, selected_cards())
	var spot: Dictionary = inspection.spot
	var currency: Dictionary = catalogue.record("Currency", int(spot.ExpeditionCostCurrencyID))
	var min_grade: Dictionary = catalogue.record("Grade", int(spot.MinGrade))
	state_label.text = "카드 선택의 정적 조건: " + ("충족" if inspection.static_conditions_met else "미충족")
	for reason in inspection.reasons:
		state_label.text += "\n" + str(reason)
	for boundary in inspection.unknown:
		state_label.text += "\n" + str(boundary)
	if runtime != null:
		var availability: Dictionary = runtime.prepare(current_spot, selected_identities())
		start_button.disabled = not availability.ok
		state_label.text += "\n" + ("로컬 출발 가능 · 이벤트·정산은 대기" if availability.ok else str(availability.error))
	_refresh_jobs()
	var currency_name := "아데나" if currency.get("Name") == "Adena" else str(currency.get("Name", spot.ExpeditionCostCurrencyID))
	var text := "%s\n시간 %d시간 (%d초) · 비용 %s %d · 필요 카드 %d장\n최소 등급 %s (원본 ID %d, 순위 %d)\n위치 원값 (%d, %d) · 서버 제한 %d · 부활 한도 %d\n" % [spot.Name, int(spot.TimeLimitSecond) / 3600, int(spot.TimeLimitSecond), currency_name, int(spot.ExpeditionCost), int(spot.CardCount), _grade_name(int(spot.MinGrade)), int(spot.MinGrade), int(min_grade.get("GradeValue", -1)), int(spot.CoordinateX), int(spot.CoordinateY), int(spot.ServerLimitsetID), int(spot.ResurrectionLimit)]
	text += "좌표는 탐험 장소 표의 원값이며 월드 이동 위치로 사용하지 않습니다.\n"
	var group_id := group_picker.get_selected_id()
	var evidence: Dictionary = catalogue.group_detail(current_spot, group_id)
	text += "\n완주 상자 (이벤트 보상과 별도):\n"
	for entry: Dictionary in evidence.completion:
		text += "%s ×%d · Reward %d\n" % [entry.item.get("Name", str(entry.reward.get("RewardClassID", 0))), int(entry.reward.get("Amount", 0)), int(entry.reward.get("ID", 0))]
		text += "상자 후보 원가중치 (원합 10,000,000; 실제 추첨은 미연결):\n"
		for candidate: Dictionary in entry.box_candidates:
			var item: Dictionary = catalogue.record("ItemClass", int(candidate.ItemClassID))
			text += "  %s ×%d · %d · 후보행 %d\n" % [item.get("Name", str(candidate.ItemClassID)), int(candidate.ItemAmount), int(candidate.Probability), int(candidate.ID)]
	text += "\n이벤트 보상 후보 원가중치 (특수 여부·타입을 유지, 실제 확률 미확정):\n"
	if evidence.event_rewards.is_empty():
		text += "이 장소·그룹의 이벤트 보상 풀이 없습니다.\n"
	for reward_row: Dictionary in evidence.event_rewards:
		var reward: Dictionary = catalogue.record("Reward", int(reward_row.RewardID))
		var item: Dictionary = catalogue.record("ItemClass", int(reward.get("RewardClassID", 0)))
		text += "%s ×%d · 원가중치 %d · 특수 %s · 타입 %d\n" % [item.get("Name", "Reward %d" % int(reward_row.RewardID)), int(reward.get("Amount", 0)), int(reward_row.Probability), str(reward_row.IsSpecial), int(reward_row.MagicDollExpeditionSpotRewardTypeID)]
	text += "\n장소 이벤트 제한 (발생률 미확정):\n"
	for event_entry: Dictionary in evidence.events:
		var event: Dictionary = event_entry.event
		text += "이벤트 %d · 최소 등급 ID %d · 스킬각성 Lv.%d · 보너스타입 %d · 원값 %d\n" % [int(event.ID), int(event.MinGradeID), int(event.MinLevel), int(event_entry.bonus.get("MagicDollExpeditionBonusTypeID", 0)), int(event_entry.bonus.get("Value", 0))]
	if int(spot.BuffCardDeckID) == 1:
		text += "\n시너지 원본 구성 (활성·효과 계산 미확정):\n"
		for synergy: Dictionary in catalogue.synergy_evidence():
			text += "%s · 서버 제한 %d\n" % [synergy.synergy.Name, int(synergy.synergy.ServerLimitsetID)]
			for member: Dictionary in synergy.members:
				text += "  카드 %d · 서버 제한 %d\n" % [int(member.BuffCardID), int(member.ServerLimitsetID)]
			for effect: Dictionary in synergy.effects:
				text += "  효과타입 %d · 원값 %d\n" % [int(effect.effect.get("MagicDollExpeditionBonusTypeID", 0)), int(effect.effect.get("Value", 0))]
	text += "\n횟수·주기 상수 원값 (일일 초기화 시간대·오프라인 진행 미확정):\n"
	for constant: Dictionary in catalogue.rows("ConstantData"):
		text += "%s = %s\n" % [constant.Name, str(constant.Value)]
	details.text = text
