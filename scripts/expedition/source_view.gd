extends HBoxContainer

const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")

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
var job_toolbar: HBoxContainer
var job_picker: OptionButton
var claim_button: Button
var revive_button: Button
var abort_button: Button
var storage_picker: OptionButton
var storage_rows: Array = []
var diamond_title:Label
var diamond_amount:SpinBox
var buff_choices: VBoxContainer
var buff_checks: Array[CheckButton] = []
var storage_title: Label
var open_button: Button
var withdraw_button: Button

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
	intro.text = "탐험 · 원본 수치 우선 / 부족한 규칙은 TWILIGHT 추정 설정"
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
	hint.text = "소유 카드 선택 (인형·성물 1장 / 변신 4장). 다시 누르면 선택 해제. 레벨은 스킬각성 레벨입니다."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(hint)
	card_picker = ItemList.new()
	card_picker.name = "ExpeditionOwnedCards"
	card_picker.select_mode = ItemList.SELECT_TOGGLE
	card_picker.custom_minimum_size.y = 88
	card_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(card_picker)
	var buff_hint := Label.new()
	buff_hint.text = "선택 버프 · 이번 탐험에만 적용 (원본 비용)"
	buff_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(buff_hint)
	diamond_title=Label.new();diamond_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;choices.add_child(diamond_title)
	var exchange_row:=HBoxContainer.new();choices.add_child(exchange_row)
	diamond_amount=SpinBox.new();diamond_amount.name="ExpeditionDiamondAmount";diamond_amount.min_value=1;diamond_amount.max_value=1000;diamond_amount.value=10;exchange_row.add_child(diamond_amount)
	var exchange_button:=Button.new();exchange_button.name="ExpeditionExchangeDiamonds";exchange_button.text="로컬다이아 교환";exchange_row.add_child(exchange_button)
	exchange_button.pressed.connect(func()->void:
		var amount:int=int(diamond_amount.value);var cost:int=amount*int(runtime.rules_view().local_diamond_adena_price)
		hud.confirm_action("TWILIGHT 탐험 로컬다이아","아데나%d → 로컬다이아%d\nTWILIGHT 자체 교환비입니다. 게임 내부 탐험에만 사용합니다. 원본의 유료 구매나 운영 서버 재화와 연결되지 않습니다."%[cost,amount],"교환",func(_count:int=1)->void:
			var result:Dictionary=runtime.exchange_diamonds(amount);result_message=str(result.get("message",result.get("error","")));_render()))
	buff_choices = VBoxContainer.new()
	choices.add_child(buff_choices)
	var group_hint := Label.new()
	group_hint.text = "확인할 보상표 그룹 (보상표가 있어도 출발 가능을 뜻하지 않습니다)"
	group_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(group_hint)
	group_picker = OptionButton.new()
	group_picker.name = "ExpeditionRewardGroupPicker"
	choices.add_child(group_picker)
	var rules_button := Button.new()
	rules_button.name = "ExpeditionRules"
	rules_button.text = "원본·추정 규칙 안내"
	rules_button.pressed.connect(_show_rules)
	choices.add_child(rules_button)
	choices.add_child(HSeparator.new())
	storage_title = Label.new()
	choices.add_child(storage_title)
	storage_picker = OptionButton.new()
	storage_picker.name = "ExpeditionStoragePicker"
	choices.add_child(storage_picker)
	storage_picker.item_selected.connect(func(_i: int) -> void: _refresh_storage_buttons())
	var storage_actions := HBoxContainer.new()
	choices.add_child(storage_actions)
	open_button = Button.new(); open_button.text = "상자1개 열기"; open_button.name = "ExpeditionOpenBox"
	withdraw_button = Button.new(); withdraw_button.text = "인벤토리로"; withdraw_button.name = "ExpeditionWithdraw"
	storage_actions.add_child(open_button); storage_actions.add_child(withdraw_button)
	open_button.pressed.connect(func() -> void: _storage_action(true))
	withdraw_button.pressed.connect(func() -> void: _storage_action(false))
	state_label = Label.new()
	state_label.name = "ExpeditionEligibility"
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results.add_child(state_label)
	start_button = Button.new()
	start_button.name = "ExpeditionStartBlocked"
	start_button.text = "탐험 출발 · 추정 규칙 적용"
	start_button.disabled = true
	results.add_child(start_button)
	start_button.pressed.connect(_confirm_start)
	job_label = Label.new()
	job_label.name = "ExpeditionJobStatus"
	job_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results.add_child(job_label)
	job_toolbar = HBoxContainer.new()
	job_toolbar.name = "ExpeditionSettlementToolbar"
	results.add_child(job_toolbar)
	job_picker = OptionButton.new()
	job_picker.name = "ExpeditionJobPicker"
	job_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	job_toolbar.add_child(job_picker)
	job_picker.item_selected.connect(func(_index: int) -> void:
		_refresh_jobs()
		_show_settlement())
	var inspect_button := Button.new()
	inspect_button.name = "ExpeditionSettlementInspect"
	inspect_button.text = "정산 내역"
	inspect_button.pressed.connect(_show_settlement)
	job_toolbar.add_child(inspect_button)
	job_toolbar.hide()
	var actions := HBoxContainer.new()
	results.add_child(actions)
	claim_button = Button.new(); claim_button.text = "보상 받기"; claim_button.name = "ExpeditionClaim"
	revive_button = Button.new(); revive_button.text = "부활"; revive_button.name = "ExpeditionResurrect"
	abort_button = Button.new(); abort_button.text = "중단·일부 수령"; abort_button.name = "ExpeditionAbort"
	for button: Button in [claim_button, revive_button, abort_button]: actions.add_child(button)
	claim_button.pressed.connect(func() -> void: _job_action("claim"))
	revive_button.pressed.connect(func() -> void: _job_action("revive"))
	abort_button.pressed.connect(func() -> void: _job_action("abort"))
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

func _card_label(card:Dictionary, image_evidence: Dictionary = {})->String:
	var source:Dictionary=catalogue.record("BuffCard",int(card.source_id))
	var pending: bool=bool(card.get("visual_pending",false))
	if not image_evidence.is_empty():pending=not bool(image_evidence.get("source_image_loaded",false))
	return "%s · 스킬각성 Lv.%d"%[source.get("Name",str(card.source_id)),int(card.skill_awaken_level)]+(" · 원본 이미지 미설치" if pending else "")

func _card_image(card: Dictionary, source: Dictionary, deck_id: int) -> Dictionary:
	if not IMAGES.selected():return {}
	var image: Dictionary={"ok":false,"status":"source_buff_card_identity_required","texture":null,"provenance":{},"actual_game_consumption_observed":false}
	var card_id: Variant=card.get("source_id")
	# This exact row comes from the separately pinned current expedition
	# catalogue. BuffCard.ID never substitutes for its declared AssetView ID.
	if catalogue.ready() and IMAGES.PACK._integer(card_id) and int(card_id)>0 and source.get("ID")==card_id and source.get("BuffCardDeckID")==deck_id:
		image=IMAGES.resolve_asset_value(source.get("DisplayBaseAssetID"))
	var provenance: Dictionary=image.get("provenance",{}).duplicate(true)
	provenance["card_source_relation"]={"source_table":"BuffCard","source_id":source.get("ID"),"source_field":"DisplayBaseAssetID","source_asset_value":source.get("DisplayBaseAssetID"),"source_deck_id":source.get("BuffCardDeckID"),"caller_source_id":card_id,"caller_card_identity":str(card.get("identity","")),"source_archive_sha256":catalogue.SOURCE_SHA256,"catalogue_pack_sha256":catalogue.pack_sha256}
	image["provenance"]=provenance
	image["source_image_loaded"]=image.get("ok",false) and image.get("texture") is Texture2D
	return image

func _bind_card_image(index: int, card: Dictionary, source: Dictionary, deck_id: int) -> void:
	var image: Dictionary=_card_image(card,source,deck_id)
	card_picker.set_item_icon(index,image.get("texture") as Texture2D)
	var evidence: Dictionary=image.duplicate(true);evidence.erase("texture")
	var images: Dictionary=card_picker.get_meta("source523_card_images",{})
	if evidence.is_empty():images.erase(index)
	else:images[index]=evidence
	card_picker.set_meta("source523_card_images",images)
	card_picker.set_item_text(index,_card_label(card,evidence))

func _select_spot() -> void:
	if runtime != null and runtime.world != null: owned_cards = runtime.world.expedition_owned_cards()
	current_spot = spot_picker.get_selected_id()
	var spot: Dictionary = catalogue.record("MagicDollExpeditionSpot", current_spot)
	card_picker.clear()
	card_picker.set_meta("source523_card_images",{})
	for child in buff_choices.get_children(): buff_choices.remove_child(child); child.queue_free()
	buff_checks.clear()
	if runtime != null:
		for option: Dictionary in runtime.buff_options(int(spot.BuffCardDeckID)):
			var button := CheckButton.new()
			var type := int(option.bonus.MagicDollExpeditionBonusTypeID)
			button.text = ("HP +%d" % int(option.bonus.Value) if type == 1 else ("회복제 +%d / 900초" % int(option.bonus.Value) if type == 11 else "행운"))+" · "+("아데나 " if int(option.buff.CostCurrencyID)==1 else "로컬다이아 ")+str(int(option.buff.Cost))
			button.name = "ExpeditionBuff_"+str(int(option.buff.ID))
			button.disabled = not option.supported
			button.tooltip_text = "출발과 함께 원본 비용을 소모합니다. 로컬다이아는 TWILIGHT 탐험 전용 내부 재화입니다. HP·회복량·60초 행운은 원본이며, 동시 효과 순서와 중첩은 TWILIGHT 설정입니다."
			button.set_meta("buff_id",int(option.buff.ID)); buff_choices.add_child(button); buff_checks.append(button)
			button.toggled.connect(func(_on: bool) -> void: _render())
	for card: Dictionary in owned_cards:
		var source: Dictionary = catalogue.record("BuffCard", int(card.source_id))
		if int(source.get("BuffCardDeckID", 0)) != int(spot.BuffCardDeckID):
			continue
		var index := card_picker.add_item(_card_label(card))
		card_picker.set_item_metadata(index, card)
		_bind_card_image(index,card,source,int(spot.BuffCardDeckID))
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

func selected_buffs() -> Array:
	var result: Array = []
	for button in buff_checks:
		if button.button_pressed: result.append(int(button.get_meta("buff_id")))
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
	diamond_title.text="TWILIGHT 탐험 로컬다이아 %d · 자체 교환비1개=아데나%d"%[runtime.diamond_balance(),int(runtime.rules_view().local_diamond_adena_price)]
	var selected_job := 0
	if job_picker.selected >= 0:
		selected_job = int(job_picker.get_item_metadata(job_picker.selected))
	job_picker.clear()
	var selected_status := ""
	var selected_record: Dictionary = {}
	for job: Dictionary in runtime.jobs_view():
		var spot: Dictionary = catalogue.record("MagicDollExpeditionSpot", int(job.spot_id))
		var index := job_picker.item_count
		if index == 0 or int(job.id) == selected_job:
			selected_record = job
			selected_status = "%s · %s · HP %d/%d · 남은 %d초" % [spot.get("Name", str(job.spot_id)), {"running":"진행", "dead":"사망", "completed":"완주"}.get(job.status, job.status), int(job.get("sim", {}).get("hp", 0)), int(job.get("sim", {}).get("max_hp", 0)), int(job.remaining)]
		job_picker.add_item(str(spot.get("Name", job.spot_id)))
		job_picker.set_item_metadata(index, int(job.id))
		if int(job.id) == selected_job: job_picker.select(index)
	if not selected_status.is_empty(): job_label.text += "\n"+selected_status
	job_toolbar.visible = job_picker.item_count > 0
	claim_button.disabled = selected_record.get("status") != "completed"
	revive_button.disabled = selected_record.get("status") != "dead" or int(selected_record.get("sim", {}).get("resurrections", 3)) >= 3
	abort_button.disabled = selected_record.is_empty() or selected_record.get("status") == "completed"
	var completion_item: Dictionary = {}
	if not selected_record.is_empty():
		var completion: Dictionary = runtime.settlement_view(int(selected_record.id))
		if completion.get("ok",false): completion_item = completion.item
	_apply_item_icon(claim_button,completion_item)
	_refresh_storage()

func _refresh_storage() -> void:
	if runtime == null or not is_instance_valid(storage_picker): return
	var selected := ""
	if storage_picker.selected >= 0: selected = str(storage_picker.get_item_metadata(storage_picker.selected))
	storage_rows = runtime.storage_view()
	storage_title.text = "탐험 보상 보관함 · %d/75칸" % storage_rows.size()
	storage_picker.clear()
	var icons: Dictionary = {}
	for row: Dictionary in storage_rows:
		var index := storage_picker.item_count
		storage_picker.add_item("%s ×%d" % [row.item.get("Name", row.key), int(row.amount)])
		var info: Dictionary = IMAGES.describe_item_class_row(row.item)
		var texture: Texture2D = info.get("texture") as Texture2D
		storage_picker.set_item_icon(index,texture)
		if IMAGES.selected():
			var evidence: Dictionary = info.duplicate(true)
			evidence.erase("texture")
			icons[str(row.key)] = evidence
		storage_picker.set_item_metadata(index, str(row.key))
		if row.key == selected: storage_picker.select(index)
	if icons.is_empty():
		if storage_picker.has_meta("source523_item_icons"): storage_picker.remove_meta("source523_item_icons")
	else: storage_picker.set_meta("source523_item_icons",icons)
	_refresh_storage_buttons()

func _refresh_storage_buttons() -> void:
	var has_item := storage_picker.selected >= 0 and storage_picker.selected < storage_rows.size()
	withdraw_button.disabled = not has_item
	open_button.disabled = not bool(storage_rows[storage_picker.selected].box) if has_item else true
	var item: Dictionary = storage_rows[storage_picker.selected].item if has_item else {}
	_apply_item_icon(withdraw_button,item)
	_apply_item_icon(open_button,item if has_item and storage_rows[storage_picker.selected].box else {})

func _apply_item_icon(button: Button, item: Dictionary) -> void:
	button.icon = null
	if button.has_meta("source523_item_icon"): button.remove_meta("source523_item_icon")
	if item.is_empty() or not IMAGES.selected(): return
	var info: Dictionary = IMAGES.describe_item_class_row(item)
	button.icon = info.get("texture") as Texture2D
	button.expand_icon = true
	var evidence: Dictionary = info.duplicate(true)
	evidence.erase("texture")
	button.set_meta("source523_item_icon",evidence)

func _storage_action(open: bool) -> void:
	if runtime == null or hud == null or storage_picker.selected < 0: return
	var row: Dictionary = storage_rows[storage_picker.selected].duplicate(true)
	var contents_before: Dictionary = runtime.state.storage.duplicate(true)
	var accept: Callable=func(_count: int = 1) -> void:
		# Timer progress alone must not invalidate a box confirmation.
		if runtime.state.storage != contents_before:
			result_message = "보관함 상태가 변경되었습니다. 다시 선택하세요."
			_render()
			return
		var result: Dictionary = runtime.open_box(str(row.key)) if open else runtime.withdraw(str(row.key), int(row.amount))
		result_message = str(result.get("message", result.get("error", "")))
		_render()
	var dialog: Control=hud.confirm_action("탐험 보상", "상자1개를 소모해 원본 가중치로%d회 추첨합니다. 개봉 횟수는 TWILIGHT 자체 규칙입니다." % int(runtime.rules_view().completion_box_draws) if open else "선택한 보상 %d개를 원본 ID를 보존해 인벤토리로 옮깁니다." % int(row.amount), "상자 열기" if open else "수령", accept)
	if dialog!=null and dialog.get("callback")==accept:
		var button: Variant=dialog.get("confirm_button")
		if button is Button:_apply_item_icon(button,row.item)

func _job_action(action: String) -> void:
	if runtime == null or hud == null or job_picker.selected < 0: return
	var id := int(job_picker.get_item_metadata(job_picker.selected))
	var view: Dictionary = runtime.settlement_view(id)
	if not view.ok: return
	var body := "완주 보상과 카드 경험치를1회 수령합니다."
	if action == "revive": body = "아데나 %d 소모 · HP50%%로 부활합니다. 비용은 TWILIGHT 추정 설정입니다." % (int(view.job.cost)*int(view.job.sim.policy.resurrection_cost_multiplier_permyriad)/10000)
	if action=="revive" and int(view.job.deck_id)==1:body="원본 파견 비용50다이아 · HP50%로 부활합니다. TWILIGHT 탐험 로컬다이아 잔액에서 소모합니다."
	if action == "abort": body = "탐험을 중단하고 발견한 아이템·경험치의%.1f%%를 수령합니다. 회수율은 추정 설정이며 완료 상자는 없습니다." % (float(view.job.sim.policy.abort_recovery_permyriad)/100.0)
	hud.confirm_action("탐험 처리", body, {"claim":"보상 받기", "revive":"부활", "abort":"중단"}.get(action, action), func(_count: int = 1) -> void:
		var result: Dictionary = runtime.resurrect(id) if action == "revive" else runtime.claim(id, action == "abort")
		result_message = str(result.get("message", result.get("error", "")))
		_render())

func _show_rules() -> void:
	var p: Dictionary = runtime.rules_view()
	details.text = "원본 유지: 장소·카드 조건·입장비·8시간·HP·경험치·보상 후보와 가중치·부활 상한3회·부활HP50%%.\n\nTWILIGHT 추정 설정:\n%d초마다 일반 이벤트를 선택합니다.\n상대 비중: 발견%d / 없음%d / 경험치%d / 몬스터%d / 넘어짐%d / 휴식%d\n몬스터 Lv.5 기본 승률%.1f%%, 이후 레벨당+%.1f%%p, 상한%.1f%%. 패배 피해는 원본 일반 몬스터 HPDecrease 중앙값입니다.\n부활 비용=입장비×%.2f. 중단 회수율%.1f%%.\n생존해8시간을 채우면 원본 완료 상자를 받습니다. 상자1개는 원본 후보 가중치로%d회 개봉합니다.\n오프라인 진행:%s · 초기화:UTC %.1f 기준05시\n공식 서버 수식이 아니며 별도 설정 파일에서 조정할 수 있습니다.\n서버·기간 제한은 해제하지 않습니다. 변신4장 파견은 대표 그룹·합산 HP·경험치 분배·시너지 조합을 별도 TWILIGHT 규칙으로 처리합니다. 원본50다이아 부활과10다이아 행운 구매는 TWILIGHT 탐험 로컬다이아에서 소모합니다. 교환비는 자체 설정입니다." % [int(p.event_interval_seconds), int(p.normal_event_weights["61"]), int(p.normal_event_weights["71"]), int(p.normal_event_weights["81"]), int(p.normal_event_weights["91"]), int(p.normal_event_weights["101"]), int(p.normal_event_weights["111"]), float(p.monster_win_permyriad)/100.0, float(p.win_bonus_per_level)/100.0, float(p.maximum_win_permyriad)/100.0, float(p.resurrection_cost_multiplier_permyriad)/10000.0, float(p.abort_recovery_permyriad)/100.0, int(p.completion_box_draws), "사용" if p.offline_progress else "미사용", float(p.daily_reset_utc_offset_minutes)/60.0]

func _show_settlement() -> void:
	if runtime == null or job_picker.selected < 0: return
	var contract: Dictionary = runtime.settlement_view(int(job_picker.get_item_metadata(job_picker.selected)))
	if not contract.ok:
		details.text = str(contract.error)
		return
	var text := "탐험 기록의 완료 보상 연결\n%s\n" % str(contract.reason)
	text += "%s ×%d · Reward %d\n출발 시 기록한 그룹 %d와 연결된 보상이며, 다른 그룹의 보상으로 교체하지 않습니다.\n" % [contract.item.get("Name", str(contract.reward.RewardClassID)), int(contract.reward.Amount), int(contract.reward.ID), int(contract.job.group_id)]
	for box: Dictionary in contract.boxes:
		text += "\n상자 후보 원가중치 합 %d · 후보 %d행\n원본 AbleMultiple=%s · TWILIGHT 개봉 규칙:1개당%d회\n" % [int(box.raw_weight_sum), box.candidates.size(), str(box.bag.get("AbleMultiple", false)), int(runtime.rules_view().completion_box_draws)]
		for candidate: Dictionary in box.candidates:
			var item: Dictionary = catalogue.record("ItemClass", int(candidate.ItemClassID))
			text += "%s ×%d · 원가중치 %d · 후보행 %d\n" % [item.get("Name", str(candidate.ItemClassID)), int(candidate.ItemAmount), int(candidate.Probability), int(candidate.ID)]
	text += "\n상자 획득과 상자 개봉은 별도 단계입니다. 연결구매/카드 후보가 있어도 즉시 카드를 지급하지 않습니다.\n조회는 아이템·보유 카드·아데나·난수·세이브를 변경하지 않습니다."
	details.text = text

func _confirm_start() -> void:
	if runtime == null or hud == null: return
	var ids := selected_identities()
	var spot_id := current_spot
	var buffs := selected_buffs()
	var prepared: Dictionary = runtime.prepare(spot_id, ids, buffs)
	if not prepared.ok:
		result_message = str(prepared.error)
		_refresh_jobs()
		return
	hud.confirm_action("탐험 출발", "아데나 %d 소모 (입장 %d + 버프 %d) + 로컬다이아 %d ·8시간\n원본 수치를 우선하며, 부족한 전투·이벤트 규칙은 TWILIGHT 추정 설정으로 진행합니다.\n사망 시 부활하거나 중단할 수 있고, 생존 완주하면 완료 상자를 받습니다.\n상세 수치는 '원본·추정 규칙 안내'에서 확인하세요." % [int(prepared.cost),int(prepared.entry_cost),int(prepared.buffs.cost),int(prepared.buffs.diamonds)], "출발", func(_count: int = 1) -> void:
		var result: Dictionary = runtime.start(spot_id, ids, buffs)
		result_message = str(result.get("message", result.get("error", "")))
		_render())

func _render() -> void:
	if runtime != null and runtime.world != null:
		owned_cards = runtime.world.expedition_owned_cards()
		for index in range(card_picker.item_count):
			var previous: Dictionary = card_picker.get_item_metadata(index)
			for current: Dictionary in owned_cards:
				if current.identity != previous.identity: continue
				card_picker.set_item_metadata(index, current)
				var source: Dictionary=catalogue.record("BuffCard",int(current.source_id))
				var image_deck: int=int(catalogue.record("MagicDollExpeditionSpot",current_spot).get("BuffCardDeckID",0))
				_bind_card_image(index,current,source,image_deck)
	var inspection: Dictionary = catalogue.inspect(current_spot, selected_cards())
	var spot: Dictionary = inspection.spot
	var currency: Dictionary = catalogue.record("Currency", int(spot.ExpeditionCostCurrencyID))
	var min_grade: Dictionary = catalogue.record("Grade", int(spot.MinGrade))
	state_label.text = "카드 선택의 정적 조건: " + ("충족" if inspection.static_conditions_met else "미충족")
	for reason in inspection.reasons:
		state_label.text += "\n" + str(reason)
	if runtime != null:
		var availability: Dictionary = runtime.prepare(current_spot, selected_identities(),selected_buffs())
		start_button.disabled = not availability.ok
		state_label.text += "\n" + ("출발 가능 · 원본 수치 + TWILIGHT 추정 규칙" if availability.ok else str(availability.error))
		if availability.ok and availability.inspection.has("party"):
			var representative:Dictionary=catalogue.record("BuffCard",int(availability.inspection.party.representative.source_id))
			var synergy_names:PackedStringArray=[]
			for id in availability.inspection.party.synergy_ids:synergy_names.append(str(catalogue.record("BuffCardExpeditionSynergy",int(id)).get("Name",id)))
			state_label.text += "\nTWILIGHT 추정 파견 규칙: 대표 %s · 팀HP %s · 경험치 %s\n활성 시너지: %s" % [str(representative.get("Name","")),"합산" if runtime.rules_view().get("dispatch_hp","sum")=="sum" else "최저값","균등 분배" if runtime.rules_view().get("dispatch_experience","split_total")=="split_total" else "각 카드 전량"," / ".join(synergy_names) if not synergy_names.is_empty() else "없음"]
	_refresh_jobs()
	var currency_name := "아데나" if currency.get("Name") == "Adena" else str(currency.get("Name", spot.ExpeditionCostCurrencyID))
	var text := "%s\n시간 %d시간 (%d초) · 비용 %s %d · 필요 카드 %d장\n최소 등급 %s (원본 ID %d, 순위 %d)\n위치 원값 (%d, %d) · 서버 제한 %d · 부활 한도 %d\n" % [spot.Name, int(spot.TimeLimitSecond) / 3600, int(spot.TimeLimitSecond), currency_name, int(spot.ExpeditionCost), int(spot.CardCount), _grade_name(int(spot.MinGrade)), int(spot.MinGrade), int(min_grade.get("GradeValue", -1)), int(spot.CoordinateX), int(spot.CoordinateY), int(spot.ServerLimitsetID), int(spot.ResurrectionLimit)]
	text += "좌표는 탐험 장소 표의 원값이며 월드 이동 위치로 사용하지 않습니다.\n"
	var group_id := group_picker.get_selected_id()
	var evidence: Dictionary = catalogue.group_detail(current_spot, group_id)
	text += "\n완주 상자 (이벤트 보상과 별도):\n"
	for entry: Dictionary in evidence.completion:
		text += "%s ×%d · Reward %d\n" % [entry.item.get("Name", str(entry.reward.get("RewardClassID", 0))), int(entry.reward.get("Amount", 0)), int(entry.reward.get("ID", 0))]
		text += "상자 후보 원가중치 (원합 10,000,000; 개봉은 별도 TWILIGHT 규칙):\n"
		for candidate: Dictionary in entry.box_candidates:
			var item: Dictionary = catalogue.record("ItemClass", int(candidate.ItemClassID))
			text += "  %s ×%d · %d · 후보행 %d\n" % [item.get("Name", str(candidate.ItemClassID)), int(candidate.ItemAmount), int(candidate.Probability), int(candidate.ID)]
	text += "\n이벤트 보상 후보 원가중치 (특수 여부·타입을 유지, 원본 가중치 적용 / 발생 규칙은 추정):\n"
	if evidence.event_rewards.is_empty():
		text += "이 장소·그룹의 이벤트 보상 풀이 없습니다.\n"
	for reward_row: Dictionary in evidence.event_rewards:
		var reward: Dictionary = catalogue.record("Reward", int(reward_row.RewardID))
		var item: Dictionary = catalogue.record("ItemClass", int(reward.get("RewardClassID", 0)))
		text += "%s ×%d · 원가중치 %d · 특수 %s · 타입 %d\n" % [item.get("Name", "Reward %d" % int(reward_row.RewardID)), int(reward.get("Amount", 0)), int(reward_row.Probability), str(reward_row.IsSpecial), int(reward_row.MagicDollExpeditionSpotRewardTypeID)]
	text += "\n장소 이벤트 제한 (로컬 발생 비중은 추정 설정):\n"
	for event_entry: Dictionary in evidence.events:
		var event: Dictionary = event_entry.event
		text += "이벤트 %d · 최소 등급 ID %d · 스킬각성 Lv.%d · 보너스타입 %d · 원값 %d\n" % [int(event.ID), int(event.MinGradeID), int(event.MinLevel), int(event_entry.bonus.get("MagicDollExpeditionBonusTypeID", 0)), int(event_entry.bonus.get("Value", 0))]
	if int(spot.BuffCardDeckID) == 1:
		text += "\n시너지 원본 구성 (조합 조건은 TWILIGHT 설정, 효과 수치는 원본):\n"
		for synergy: Dictionary in catalogue.synergy_evidence():
			text += "%s · 서버 제한 %d\n" % [synergy.synergy.Name, int(synergy.synergy.ServerLimitsetID)]
			for member: Dictionary in synergy.members:
				text += "  카드 %d · 서버 제한 %d\n" % [int(member.BuffCardID), int(member.ServerLimitsetID)]
			for effect: Dictionary in synergy.effects:
				text += "  효과타입 %d · 원값 %d\n" % [int(effect.effect.get("MagicDollExpeditionBonusTypeID", 0)), int(effect.effect.get("Value", 0))]
	text += "\n횟수·주기 상수 원값 (시간대·오프라인 정책은 로컬 설정):\n"
	for constant: Dictionary in catalogue.rows("ConstantData"):
		text += "%s = %s\n" % [constant.Name, str(constant.Value)]
	details.text = text
