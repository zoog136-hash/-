extends VBoxContainer
## The source catalog is a separate view; legacy purchases keep their policy.
signal back_requested
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
var catalog: RefCounted
var mode: OptionButton
var search: LineEdit
var all_definitions: CheckButton
var listing: ItemList
var detail: RichTextLabel
var page_label: Label
var previous: Button
var next: Button
var purchase: Button
var entries: Array = []
var filtered: Array = []
var page: int = 0
const PAGE_SIZE: int = 80

func configure(source_catalog: RefCounted) -> void:
	catalog = source_catalog
	name = "Source523ShopPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	add_child(heading)
	var back: Button = UI.button("← 기존 상점", func() -> void: back_requested.emit(), Vector2(112, 38))
	back.name = "SourceShopBack"
	heading.add_child(back)
	var title: Label = UI.label("원본 상품 안내 · 523", 17, UI.GOLD)
	heading.add_child(title)
	add_child(UI.label("판매 조건을 확인 중입니다. 결제·보관함 수령·누적 보상은 각각 별도 처리됩니다.", 12, UI.MUTED))
	var filters := HBoxContainer.new()
	add_child(filters)
	mode = OptionButton.new()
	mode.name = "SourceShopMode"
	for title_text: String in ["상품", "NPC 판매", "재화", "누적 보상"]: mode.add_item(title_text)
	mode.item_selected.connect(func(_index: int) -> void: _build_entries())
	filters.add_child(mode)
	search = LineEdit.new()
	search.name = "SourceShopSearch"
	search.placeholder_text = "이름 또는 원본 번호 검색"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value: String) -> void: _filter())
	filters.add_child(search)
	all_definitions = CheckButton.new()
	all_definitions.text = "과거·미진열 포함"
	all_definitions.toggled.connect(func(_value: bool) -> void: _build_entries())
	filters.add_child(all_definitions)
	var browser := Browser.new()
	browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(browser)
	listing = ItemList.new()
	listing.name = "SourceShopItems"
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	browser.add_child(listing)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	browser.add_child(side)
	detail = UI.rich("")
	detail.name = "SourceShopDetail"
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(detail)
	purchase = UI.button("구매 조건 확인 중", func() -> void: pass, Vector2(0, 44))
	purchase.name = "SourceShopBuy"
	purchase.disabled = true
	side.add_child(purchase)
	browser.configure(listing, side, 278)
	browser.enable_item_touch()
	var pagination := HBoxContainer.new()
	add_child(pagination)
	previous = UI.button("이전", func() -> void: page -= 1; _render_page(), Vector2(64, 36))
	previous.name = "SourceShopPrevious"
	pagination.add_child(previous)
	page_label = UI.label("", 12, UI.MUTED)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pagination.add_child(page_label)
	next = UI.button("다음", func() -> void: page += 1; _render_page(), Vector2(64, 36))
	next.name = "SourceShopNext"
	pagination.add_child(next)
	_build_entries()

func _build_entries() -> void:
	entries.clear()
	all_definitions.visible = mode.selected == 0
	var table: String = ["MarketPurchase_Korean", "MerchantGoods", "Currency", "CumulativePurchase"][mode.selected]
	var displayed: Dictionary = {}
	if mode.selected == 0:
		for row: Dictionary in catalog.rows("MarketDisplay"): displayed[int(row.PurchaseID)] = true
	for row: Dictionary in catalog.rows(table):
		var id: int = int(row.ID)
		var title: String = str(row.get("Name", ""))
		if mode.selected == 0:
			if not all_definitions.button_pressed and not displayed.has(id): continue
			title = catalog.label(int(row.get("DescID", 0)))
		elif mode.selected == 1:
			title = _item_name(int(row.ItemClassID)) + " · NPC %d" % int(row.MerchantsID)
		elif mode.selected == 2:
			var translated: String = catalog.label(int(row.get("DescID", 0)))
			if not translated.is_empty(): title = translated
		entries.append({"id":id, "title":title})
	_filter()

func _filter() -> void:
	var query: String = search.text.strip_edges().to_lower()
	filtered.clear()
	for entry: Dictionary in entries:
		if query.is_empty() or (str(entry.title) + " " + str(entry.id)).to_lower().contains(query): filtered.append(entry)
	page = 0
	_render_page()

func _render_page() -> void:
	listing.clear()
	var start: int = page * PAGE_SIZE
	for index: int in range(start, mini(start + PAGE_SIZE, filtered.size())):
		var entry: Dictionary = filtered[index]
		listing.add_item("%s  · #%d" % [entry.title, int(entry.id)])
		listing.set_item_metadata(listing.item_count - 1, int(entry.id))
	listing.force_update_list_size()
	previous.disabled = page <= 0
	next.disabled = start + PAGE_SIZE >= filtered.size()
	page_label.text = "%d개 · %d / %d 페이지" % [filtered.size(), page + 1, maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))]
	if listing.item_count > 0:
		listing.select(0)
		_select(0)
	else:
		detail.text = "검색 조건에 맞는 항목이 없습니다."

func _item_name(id: int) -> String:
	var item: Dictionary = catalog.record("ItemClass", id)
	var title: String = catalog.label(int(item.get("DescID", 0)))
	return title if not title.is_empty() else str(item.get("Name", "아이템 #%d" % id))

func _value_name(unit: int, id: int) -> String:
	if unit == 4: return _item_name(id)
	if unit == 201:
		var currency: Dictionary = catalog.record("Currency", id)
		var title: String = catalog.label(int(currency.get("DescID", 0)))
		return title if not title.is_empty() else str(currency.get("Name", "재화 #%d" % id))
	if unit == 34: return str(catalog.record("IntangibleItemClass", id).get("Name", "재화 #%d" % id))
	return "%s #%d" % [catalog.unit_name(unit), id]

func _date_text(row: Dictionary) -> String:
	if row.is_empty(): return "미확인"
	return "%04d-%02d-%02d %02d:%02d" % [int(row.Year), int(row.Month), int(row.Day), int(row.Hour), int(row.Minute)]

func _select(index: int) -> void:
	if index < 0 or index >= listing.item_count: return
	var id: int = int(listing.get_item_metadata(index))
	var lines: Array[String] = []
	match mode.selected:
		0: lines = _market_detail(id)
		1: lines = _merchant_detail(id)
		2: lines = _currency_detail(id)
		3: lines = _cumulative_detail(id)
	# Source descriptions may contain BBCode-like text. Never interpret it.
	detail.text = UI.safe("\n".join(lines))
	purchase.disabled = true
	purchase.text = ["구매 조건 확인 중", "가격·구매 조건 확인 중", "재화 원천 안내", "보상 수령 조건 확인 중"][mode.selected]

func _market_detail(id: int) -> Array[String]:
	var offer: Dictionary = catalog.market_offer(id)
	var result: Array[String] = [str(offer.name), "", str(offer.description), "", "상품 번호: %d" % id]
	var payment: Dictionary = offer.payment
	if payment.is_empty():
		result.append("결제 정보 미확인")
	else:
		if int(payment.UnitID) == 37:
			result.append("외부 결제 상품 · 실제 금액은 스토어 확인 필요")
		elif int(payment.MarketPaymentTypeID) == 4:
			result.append("결제 금액: %d · %s" % [int(payment.Amount), _value_name(int(payment.UnitID), int(payment.ClassID))])
		else:
			result.append("무료·쿠폰·시스템 지급 자격 확인 필요")
		if payment.get("ClassChangeDiscount") == true: result.append("클래스체인지 할인: 조건 확인 필요")
	result.append("\n지급 상품 (1회 구매 기준)")
	for link: Dictionary in offer.products:
		var product: Dictionary = link.product.definition
		if product.is_empty(): result.append("지급 대상 연결 누락"); continue
		result.append("%s ×%d" % [_value_name(int(product.UnitID), int(product.ClassID)), int(product.Amount)])
		if not link.product.additional.is_empty(): result.append("클래스체인지 대상 조건 %d개 · 추가 아이템 지급과 구분" % link.product.additional.size())
	if not offer.bonuses.is_empty(): result.append("별도 구매 보너스: %d개 정의 · 지급 조건 확인 필요" % offer.bonuses.size())
	result.append("\n기간: %s ~ %s\n원본 판매 플래그: %s" % [_date_text(offer.effective_from), _date_text(offer.effective_to), "켜짐" if offer.purchase.OnSale else "꺼짐"])
	result.append("기간의 시간 기준과 서버 활성 여부는 별도 확인합니다.")
	for limit: Dictionary in offer.server_limits: result.append("서버 조건: Set %d" % int(limit.ServerLimitSetID))
	result.append("\n구매 제한: %d개" % offer.restrictions.size())
	for restriction: Dictionary in offer.restrictions:
		result.append("유형 %d · %s %d · %s %d" % [int(restriction.MarketRestrictionTypeId), catalog.unit_name(int(restriction.ValueUnitId)), int(restriction.Value), catalog.unit_name(int(restriction.DurationUnitId)), int(restriction.DurationValue)])
	result.append("\n" + "\n".join(catalog.activation(id).reasons))
	return result

func _merchant_detail(id: int) -> Array[String]:
	var offer: Dictionary = catalog.merchant_offer(id)
	var goods: Dictionary = offer.goods
	var result: Array[String] = [_item_name(int(goods.ItemClassID)), "", "NPC 상점 번호: %d · 판매행 #%d" % [int(goods.MerchantsID), id],
		"1회 상품 수량: %d · 강화: +%d" % [int(goods.Amount), int(goods.Enchant)],
		"최종 가격: 계산식 확인 중", "", "구매 횟수 한도: %d · 계정 기준: %s" % [int(goods.LimitCount), str(goods.LimitCountPerAccount)],
		"서버 한도: %d · 갱신 유형: %d" % [int(goods.LimitServerCount), int(goods.LimitCountRefreshTypeID)],
		"레벨: %d ~ %d" % [int(goods.LimitMinLevel), int(goods.LimitMaxLevel)],
		"혈맹 레벨 (원문 조건별): %d / %d" % [int(goods.ClanLevelMin), int(goods.LimitMinClanLevel)],
		"공성 이용 / 공성 중 제한: %s / %s" % [str(goods.AvailableSiegeTime), str(goods.LimitNotInSiegeTime)],
		"가입 후 일수 (원문 조건별): %d / %d" % [int(goods.DaysAfterClanJoin), int(goods.LimitDaysAfterClanJoin)],
		"카드 조건: %d · 반복구매 카드 조건: %d" % [int(goods.LimitBuffCardID), int(goods.LimitRepeatedBuyCardID)],
		"판매 시각: %d ~ %d · 시간: %d ~ %d" % [int(goods.LimitStartTime), int(goods.LimitEndTime), int(goods.LimitStartHour), int(goods.LimitEndHour)],
		"\n수량·구매횟수·조건을 개별 보존합니다. 최종 가격과 제한 판정은 검증 중입니다."]
	return result

func _currency_detail(id: int) -> Array[String]:
	var data: Dictionary = catalog.currency(id)
	var result: Array[String] = [_value_name(201, id), "재화 번호: %d" % id, "", "지급 대상: %d개" % data.for_give.size()]
	for source: Dictionary in data.for_give: result.append(_value_name(int(source.UnitID), int(source.ClassID)))
	if data.for_give.is_empty(): result.append("원본에 지급용 원천 없음 · 소비 후보를 임의 지급하지 않습니다.")
	result.append("\n소비 후보: %d개 (순서 판정 별도)" % data.sources.size())
	for source: Dictionary in data.sources:
		result.append("%s · 우선순위 원문값 %d · 지급용 %s" % [_value_name(int(source.UnitID), int(source.ClassID)), int(source.ConsumePriority), str(source.ForGive)])
	result.append("\n이동 재화 할인은 상점 가격에 적용하지 않습니다.")
	return result

func _cumulative_detail(id: int) -> Array[String]:
	var data: Dictionary = catalog.record("CumulativePurchase", id)
	var result: Array[String] = [str(data.Name), "", "기간: %s ~ %s" % [_date_text(catalog.record("DateTimes_Korean", int(data.StartTimeID))), _date_text(catalog.record("DateTimes_Korean", int(data.EndTimeID)))],
		"서버 조건: Set %d" % int(data.ServerLimitsetID), "", "결제 → 보관함 수령 → 일일 활성화 → 보상 수령을 구분합니다.",
		"원본 안내: 일일 05시 / 주간 수요일 05시. 현재 게임의 시간 기준은 변경하지 않습니다.", "현재 행사 활성화·대상 상품 분류·수령 처리는 미연결입니다."]
	var steps: Array = []
	for row: Dictionary in catalog.rows("CumulativePurchaseStep"):
		if int(row.CumulativePurchaseID) == id: steps.append(row)
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.Step) < int(b.Step))
	result.append("\n일일 보상: " + _reward_text(int(data.DailyRewardID)))
	for step: Dictionary in steps: result.append("%d단계 · %s" % [int(step.Step), _reward_text(int(step.RewardID))])
	return result

func _reward_text(id: int) -> String:
	var reward: Dictionary = catalog.record("Reward", id)
	if reward.is_empty(): return "보상 연결 미확인 · #%d" % id
	var type: Dictionary = catalog.record("RewardType", int(reward.get("RewardTypeID", 0)))
	if type.get("Name") == "Item":
		return "%s ×%d" % [_item_name(int(reward.get("RewardClassID", 0))), int(reward.get("Amount", 0))]
	return "%s #%d ×%d" % [str(type.get("Name", "보상")), int(reward.get("RewardClassID", 0)), int(reward.get("Amount", 0))]
