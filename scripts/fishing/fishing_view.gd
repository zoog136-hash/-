extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var hud
var runtime
var body: VBoxContainer
var status_label: Label
var live_label: Label
var gauge: ProgressBar
var tracking_meter: Control
var tab: String = "fish"
var territories: OptionButton
var rods: OptionButton
var equipment_list: ItemList
var selected_ids: Array = []
var finishing: bool = false

func configure(owner_hud: Node) -> void:
	hud = owner_hud
	runtime = hud.get_parent().fishing523
	name = "Fishing523View"
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): runtime.leave())
	tree_exiting.connect(func() -> void:
		runtime.leave()
		runtime.release_rules())
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for pair: Array in [["fish", "낚시"], ["exchange", "장비 교환"], ["bag", "낚시 보관함"], ["contest", "대회"]]:
		var value: String = str(pair[0])
		tabs.add_child(UI.button(str(pair[1]), func() -> void: tab = value; refresh(), Vector2(100, 38)))
	status_label = UI.label("", 13)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	refresh()

func label(text_value: String) -> void:
	var node := UI.label(text_value, 13)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(node)

func action(text_value: String, callback: Callable) -> Button:
	var button := UI.button(text_value, callback, Vector2(200, 38))
	body.add_child(button)
	return button

func _item_image(item_key: String, declared_item_class: bool = false) -> Dictionary:
	if not IMAGES.selected(): return {}
	# rules.items is indexed directly from the source ItemClass table. A
	# fishing location, Fish ID or host equipment key cannot supply this row.
	var source_row: Dictionary = runtime.rules.items.get(item_key, {})
	if source_row.is_empty() and declared_item_class and item_key.is_valid_int():
		return IMAGES.describe_item_class(int(item_key))
	return IMAGES.describe_item_class_row(source_row)

func _bind_item_button(button: Button, item_key: String, declared_item_class: bool = false) -> void:
	button.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if button.has_meta(key): button.remove_meta(key)
	var image_info: Dictionary = _item_image(item_key, declared_item_class)
	if image_info.is_empty(): return
	button.icon = image_info.get("texture") as Texture2D
	button.expand_icon = true
	var evidence: Dictionary = image_info.duplicate(true)
	evidence.erase("texture")
	button.set_meta("source523_image", evidence)
	button.set_meta("source523_image_provenance", image_info.get("provenance", {}).duplicate(true))
	button.set_meta("source523_image_status", str(image_info.get("source_status", image_info.get("reason", ""))))

func _bind_item_entry(list, index: int, item_key: String, declared_item_class: bool = false) -> void:
	list.set_item_icon(index, null)
	var images: Dictionary = list.get_meta("source523_item_images", {})
	images.erase(index)
	var image_info: Dictionary = _item_image(item_key, declared_item_class)
	if not image_info.is_empty():
		list.set_item_icon(index, image_info.get("texture") as Texture2D)
		var evidence: Dictionary = image_info.duplicate(true)
		evidence.erase("texture")
		images[index] = evidence
	if images.is_empty():
		if list.has_meta("source523_item_images"): list.remove_meta("source523_item_images")
	else: list.set_meta("source523_item_images", images)

func show_result(result: Dictionary) -> void:
	status_label.text = str(result.get("message", ""))
	refresh()

func confirm(title: String, detail: String, callback: Callable) -> void:
	hud.confirm_action(title, detail, "확인", func(_count: int) -> void: show_result(callback.call()))

func refresh() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	live_label = null
	gauge = null
	tracking_meter = null
	if not runtime.rules.failure.is_empty():
		label(runtime.rules.failure)
		return
	label("낚시 주화: %d · 원본 523 데이터 · 실행 공간과 대회는 TWILIGHT 자체 모드" % int(runtime.state.items.get("303031", 0)))
	match tab:
		"fish": build_fish()
		"exchange": build_exchange()
		"bag": build_bag()
		"contest": build_contest()

func build_fish() -> void:
	label("원본 지도의 물 셀은 미검증입니다. 자체 낚시 공간에서는 배경 월드를 일시 정지합니다. 창을 닫으면 낚시를 종료하고 원래 월드로 돌아갑니다.")
	territories = OptionButton.new()
	for entry: Dictionary in runtime.rules.rows("FishTerritory"):
		territories.add_item(str(entry.Name), int(entry.ID))
	body.add_child(territories)
	action("자체 낚시 공간 입장", func() -> void: show_result(runtime.enter(territories.get_selected_id())))
	var hour := SpinBox.new()
	hour.min_value = 0
	hour.max_value = 23
	hour.value = int(runtime.policy.game_hour)
	hour.value_changed.connect(func(value: float) -> void: status_label.text = str(runtime.set_option("game_hour", int(value)).message))
	label("자체 게임 시간 (운영체제 시각은 변경하지 않습니다.)")
	body.add_child(hour)
	rods = OptionButton.new()
	rods.expand_icon = true
	for id: String in runtime.rules.rods:
		rods.add_item("%s ×%d" % [runtime.rules.item_name(id), int(runtime.state.items.get(id, 0))], int(id))
		_bind_item_entry(rods, rods.item_count - 1, id)
	body.add_child(rods)
	action("낚싯대 %d개로 시작" % int(runtime.policy.cast_cost), func() -> void:
		var rod: int = rods.get_selected_id()
		confirm("낚시 시작", "낚싯대 %d개를 소모합니다. 취소·실패·재접속 시 이미 쓴 낚싯대는 돌아오지 않습니다." % int(runtime.policy.cast_cost), func() -> Dictionary: return runtime.cast(rod)))
	live_label = UI.label("", 13)
	live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(live_label)
	label("청록색 선을 금색 구간에 맞추세요. 릴링을 누르면 오른쪽, 놓으면 왼쪽으로 이동합니다.")
	tracking_meter = preload("res://scripts/fishing/fishing_meter.gd").new()
	tracking_meter.session = runtime.session
	body.add_child(tracking_meter)
	gauge = ProgressBar.new()
	gauge.max_value = 1000
	body.add_child(gauge)
	var controls := HBoxContainer.new()
	body.add_child(controls)
	controls.add_child(UI.button("입질 시 챔질", func() -> void: runtime.session.hook(), Vector2(140, 42)))
	var reel := UI.button("릴링 누르기", func() -> void: pass, Vector2(180, 42))
	reel.button_down.connect(func() -> void: runtime.session.held = true)
	reel.button_up.connect(func() -> void: runtime.session.held = false)
	controls.add_child(reel)
	controls.add_child(UI.button("강력한 챔질", func() -> void: runtime.session.power(), Vector2(140, 42)))
	var auto_mode := CheckButton.new()
	auto_mode.text = "입질 시 자동 판정 (원본 상·하한을 사용하는 자체 보간식)"
	auto_mode.button_pressed = runtime.session.auto_catch
	auto_mode.toggled.connect(func(enabled: bool) -> void: runtime.session.auto_catch = enabled)
	body.add_child(auto_mode)
	action("완료 저장 재시도", func() -> void:
		var result: Dictionary = runtime.finish()
		runtime.finish_error = not bool(result.ok)
		show_result(result))
	action("낚시 중지", func() -> void:
		if runtime.session.phase in ["waiting", "bite", "playing"]:
			runtime.session.phase = "failed"
			show_result(runtime.finish()))
	for goods: Dictionary in runtime.rules.rows("MerchantGoods"):
		var goods_id: int = int(goods.ID)
		var item: String = str(int(goods.ItemClassID))
		var cost: int = int(runtime.rules.items[item].Cost) * int(goods.Percentage) / 100
		var purchase: Button = action("%s %d개 구매 · 주화 %d · 레벨 %d" % [runtime.rules.item_name(item), int(goods.Amount), cost, int(goods.LimitMinLevel)], func() -> void:
			var token: String = runtime.request_id()
			var revision: int = int(runtime.state.revision)
			confirm("낚싯대 구매", "표시된 낚시 주화를 지불합니다.", func() -> Dictionary: return runtime.buy_rod(goods_id, token, revision)))
		_bind_item_button(purchase, item, true)

func build_exchange() -> void:
	var host_policy := CheckButton.new()
	host_policy.text = "기존 TWILIGHT 장비 교환 허용 (원본 ID 연결이 아닌 호스트 판매 규칙)"
	host_policy.button_pressed = bool(runtime.policy.host_equipment_exchange)
	host_policy.toggled.connect(func(enabled: bool) -> void:
		confirm("호스트 장비 정책 변경", "기존 호스트의 판매 허용과 등급 규칙을 적용합니다. Inven ID를 원본 ItemClassID로 변환하지 않습니다.", func() -> Dictionary: return runtime.set_host_equipment_policy(enabled)))
	body.add_child(host_policy)
	label("거래 가능한 비각인 고급~영웅 실물 장비를 최대 10개 소모합니다. 강화 수치는 보상에 영향을 주지 않지만 선택된 강화 장비 자체는 사라집니다. 잠금·장착·축복·기간·ID 미확정 장비는 보호합니다.")
	label("확정 주화와 추가 확률 보상은 별개입니다. 자체 정책: 분모 %d, 독립 추가 판정 %s." % [int(runtime.policy.exchange_denominator), str(runtime.policy.independent_extras)])
	equipment_list = ItemList.new()
	equipment_list.select_mode = ItemList.SELECT_MULTI
	equipment_list.custom_minimum_size.y = 220
	body.add_child(equipment_list)
	for id: String in runtime.world.item_instances:
		var item: Dictionary = runtime.world.item_instances[id]
		var reason: String = runtime.equipment_reason(id)
		var index: int = equipment_list.add_item("+%d %s · 실물 %s%s" % [int(item.get("level", 0)), str(item.get("name", "")), id, " · " + reason if not reason.is_empty() else ""])
		equipment_list.set_item_metadata(index, id)
		equipment_list.set_item_disabled(index, not reason.is_empty())
		var source_record: Dictionary = item.get("record", {})
		if IMAGES.recognized_item(source_record):
			_bind_item_entry(equipment_list, index, str(IMAGES.item_class_id(source_record)), true)
	action("선택한 실물 장비 교환", func() -> void:
		var ids: Array = []
		for index: int in equipment_list.get_selected_items(): ids.append(str(equipment_list.get_item_metadata(index)))
		var token: String = runtime.request_id()
		var revision: int = int(runtime.state.revision)
		var lines: PackedStringArray = []
		var coins: int = 0
		for id: String in ids:
			var physical: Dictionary = runtime.world.item_instances[id]
			lines.append("+%d %s · 실물 %s" % [int(physical.get("level", 0)), str(physical.name), id])
			var rule: Dictionary = runtime.rules.exchange_rule(int(runtime.equipment_identity(physical).get("grade", 0)))
			for output: Dictionary in runtime.rules.exchange_outputs(1, int(rule.get("ID", 0))):
				if bool(output.IsGuaranteed): coins += int(output.AmountGuaranteed)
		confirm("장비 영구 소모 확인", "%s\n확정 낚시 주화: %d개. 추가 보상은 별도 확률로 판정합니다.\n위 장비를 소모합니다. 취소하면 변경하지 않습니다." % ["\n".join(lines), coins], func() -> Dictionary: return runtime.exchange(ids, token, revision)))

func build_bag() -> void:
	label("누적 낚시 경험치: %d (자체 기록이며 캐릭터 경험치와 구분합니다.)" % int(runtime.state.get("fishing_experience", 0)))
	label("이 보관함은 실제 획득한 원본 ID별 물고기·주화·보상입니다. 기존 이름 기반 가방과 별도로 같은 세이브에 원자적으로 저장합니다.")
	for id: String in runtime.state.items:
		if int(runtime.state.items[id]) <= 0: continue
		label("%s (#%s) ×%d" % [runtime.rules.item_name(id), id, int(runtime.state.items[id])])
		if runtime.CARD_ITEMS.has(id):
			var use_card: Button = action("해당 폴 변신 카드 사용", func() -> void:
				var token: String = runtime.request_id()
				var revision: int = int(runtime.state.revision)
				confirm("변신 카드 사용", "아이템 1개를 사용해 정확한 원본 ID의 변신을 획득합니다.", func() -> Dictionary: return runtime.use_card(id, token, revision)))
			use_card.name = "FishingCard_" + id
			_bind_item_button(use_card, id)
		elif runtime.has_bag(id):
			var open_bag: Button = action("%s 열기" % runtime.rules.item_name(id), func() -> void:
				var token: String = runtime.request_id()
				var revision: int = int(runtime.state.revision)
				confirm("보물 상자 사용", "아이템 1개를 사용합니다. 원본 확정 보상은 그대로 지급하고 확률 보상은 별도로 1종 판정합니다.", func() -> Dictionary: return runtime.open_treasure(id, token, revision)))
			open_bag.name = "FishingBag_" + id
			_bind_item_button(open_bag, id)
		elif id != "303031" and not runtime.rules.rods.has(id):
			var transfer: Button = action("기존 가방으로 1개 이동", func() -> void:
				var token: String = runtime.request_id()
				var revision: int = int(runtime.state.revision)
				confirm("가방으로 이동", "정확한 원본 ID를 확인한 경우에만 기존 가방으로 이동합니다.", func() -> Dictionary: return runtime.transfer_to_inventory(id, token, revision)))
			_bind_item_button(transfer, id)
	for id: String in runtime.state.journal:
		var entry: Dictionary = runtime.state.journal[id]
		label("수첩: %s · %d마리 · 최대 길이 %d (원본 단위)" % [str(runtime.rules.row("Fish", int(id)).get("Name", id)), int(entry.count), int(entry.max_length)])

func build_contest() -> void:
	label("TWILIGHT 자체 대회: 실제 서버 순위나 운영 일정을 재현하지 않습니다. 가상 참가자 점수와 비교해 원본 순위 구간별 보상을 지급합니다. 가상 참가자 생성은 설정으로 끌 수 있습니다. 유효 기록이 없으면 보상을 지급하지 않습니다.")
	var duration := SpinBox.new()
	duration.min_value = 60
	duration.max_value = 86400
	duration.value = int(runtime.policy.contest_seconds)
	duration.value_changed.connect(func(value: float) -> void: status_label.text = str(runtime.set_option("contest_seconds", int(value)).message))
	label("자체 대회 시간 (초)")
	body.add_child(duration)
	for contest: Dictionary in runtime.rules.rows("FishContest"):
		var id: int = int(contest.ID)
		action(str(contest.Name) + " 자체 대회 시작", func() -> void:
			confirm("자체 대회 참가", "입장한 낚시터에서 대상 물고기의 최대 길이를 기록합니다.", func() -> Dictionary: return runtime.start_contest(id)))
	if not runtime.state.contest.is_empty():
		var contest: Dictionary = runtime.state.contest
		label("대상: %s · 기록: %d · 남은 시간: %d초 · 정산: %s" % [str(runtime.rules.row("Fish", int(contest.fish_id)).get("Name", "")), int(contest.score), maxi(0, int(contest.ends_at) - int(Time.get_unix_time_from_system())), str(contest.claimed)])
		action("종료된 대회 정산", func() -> void: confirm("대회 정산", "유효 기록의 보상을 한 번만 지급합니다.", func() -> Dictionary: return runtime.claim_contest()))

func _process(delta: float) -> void:
	if runtime == null: return
	runtime.tick(delta)
	if is_instance_valid(tracking_meter):
		tracking_meter.session = runtime.session
		tracking_meter.queue_redraw()
	if is_instance_valid(live_label):
		live_label.text = "상태: %s · 내 위치 %.0f · 물고기 %.0f · 강력한 챔질 %.1f초" % [str({"idle":"대기", "waiting":"입질 기다림", "bite":"지금 챔질하세요", "playing":"릴링 중", "caught":"획득 저장 중", "failed":"실패"}.get(runtime.session.phase, runtime.session.phase)), runtime.session.cursor, runtime.session.target, runtime.session.power_cooldown]
	if is_instance_valid(gauge): gauge.value = runtime.session.progress

func _exit_tree() -> void:
	if runtime != null:
		runtime.session.held = false
		runtime.leave()
