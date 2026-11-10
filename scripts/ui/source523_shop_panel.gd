extends VBoxContainer
## The source catalog is a separate view; legacy purchases keep their policy.
signal back_requested
const CashMarket = preload("res://scripts/shop/source523_cash_market.gd")
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Browser = preload("res://scripts/ui/renewal_browser.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var catalog: RefCounted
var hud: Node
var runtime
var quantity: SpinBox
var reward_step: OptionButton
var result_label: Label
var availability_label: Label
var wallet_label: Label
var selected_id: int = -1
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

func configure(source_catalog: RefCounted, controller: Node = null) -> void:
	catalog = source_catalog
	hud = controller
	if hud != null:
		runtime = hud.get_parent().source_shop
		runtime.bind_source(catalog)
	name = "Source523ShopPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	add_child(heading)
	var back: Button = UI.button("← 기존 상점", func() -> void: back_requested.emit(), Vector2(112, 38))
	back.name = "SourceShopBack"
	# The pre-November shop is gone; the original shop is the whole shop.
	back.visible = false
	heading.add_child(back)
	var title: Label = UI.label("원본 상점 · 523", 17, UI.GOLD)
	heading.add_child(title)
	wallet_label = UI.label("구매 후 보관함에서 수령하세요. 누적 보상은 수령 후 별도로 활성화됩니다.", 12, UI.MUTED)
	add_child(wallet_label)
	var filters := HBoxContainer.new()
	add_child(filters)
	mode = OptionButton.new()
	mode.name = "SourceShopMode"
	for title_text: String in ["상품", "NPC 판매", "재화", "누적 보상", "보관함"]: mode.add_item(title_text)
	mode.item_selected.connect(func(_index: int) -> void: result_label.text=""; _build_entries())
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
	quantity = SpinBox.new()
	quantity.name = "SourceShopQuantity"
	quantity.min_value = 1
	quantity.max_value = 1000
	quantity.step = 1
	quantity.value = 1
	quantity.value_changed.connect(func(_value: float) -> void: _refresh_action())
	side.add_child(quantity)
	reward_step = OptionButton.new()
	reward_step.name = "SourceShopRewardStep"
	reward_step.expand_icon = true
	reward_step.add_item("일일 무료 보상", 0)
	for step: int in range(1,7): reward_step.add_item("%d단계 보상" % step, step)
	reward_step.item_selected.connect(func(_value: int) -> void: _refresh_action())
	side.add_child(reward_step)
	result_label = UI.label("", 12, UI.MUTED)
	result_label.name = "SourceShopResult"
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(result_label)
	availability_label = UI.label("", 12, UI.MUTED)
	availability_label.name = "SourceShopAvailability"
	availability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(availability_label)
	purchase = UI.button("상품 선택", _act, Vector2(0, 44))
	purchase.name = "SourceShopBuy"
	purchase.disabled = true
	availability_label.text = ""
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
	quantity.visible = mode.selected in [0,1]
	reward_step.visible = mode.selected == 3
	if mode.selected == 4:
		if runtime != null:
			for order: Dictionary in runtime.orders():
				entries.append({"id":int(order.id),"title":"주문 #%s · %s ×%d" % [order.id,str(order.get("display_name", "상품")),int(order.quantity)],"source_table":"source_shop_order","source_order":order})
		_filter()
		return
	var table: String = ["MarketPurchase_Korean", "MerchantGoods", "Currency", "CumulativePurchase"][mode.selected]
	var displayed: Dictionary = {}
	if mode.selected == 0:
		for row: Dictionary in catalog.rows("MarketDisplay"): displayed[int(row.PurchaseID)] = true
	for row: Dictionary in catalog.rows(table):
		var id: int = int(row.ID)
		var title: String = str(row.get("Name", ""))
		if mode.selected == 0:
			if not all_definitions.button_pressed and not displayed.has(id): continue
			# One row per converted cash offer; other store copies and diamond top-ups stay hidden.
			if not all_definitions.button_pressed and CashMarket.hidden(id, catalog.record("MarketPayment_Korean", int(row.get("MarketPaymentID", 0)))): continue
			title = catalog.label(int(row.get("DescID", 0)))
			if CashMarket.listed(id): title += " · 다이아 %d" % int(CashMarket.entry(id).diamonds)
		elif mode.selected == 1:
			var seller: String=runtime.npc_label(int(row.MerchantsID)) if runtime!=null else ""
			title = _item_name(int(row.ItemClassID)) + " · " + (seller if not seller.is_empty() else "NPC %d" % int(row.MerchantsID))
		elif mode.selected == 2:
			var translated: String = catalog.label(int(row.get("DescID", 0)))
			if not translated.is_empty(): title = translated
		entries.append({"id":id, "title":title,"source_table":table,"source_row":row})
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
	var original_images: Dictionary = {}
	var start: int = page * PAGE_SIZE
	for index: int in range(start, mini(start + PAGE_SIZE, filtered.size())):
		var entry: Dictionary = filtered[index]
		var original: Dictionary = _entry_image(entry) if IMAGES.selected() else {}
		listing.add_item("%s  · #%d" % [entry.title, int(entry.id)],original.get("texture") as Texture2D)
		listing.set_item_metadata(listing.item_count - 1, int(entry.id))
		if not original.is_empty():
			var evidence: Dictionary = original.duplicate(true)
			evidence.erase("texture")
			evidence["source_table"] = str(entry.get("source_table",""))
			original_images[str(entry.id)] = evidence
	listing.set_meta("source523_images",original_images)
	listing.force_update_list_size()
	previous.disabled = page <= 0
	next.disabled = start + PAGE_SIZE >= filtered.size()
	page_label.text = "%d개 · %d / %d 페이지" % [filtered.size(), page + 1, maxi(1, ceili(float(filtered.size()) / PAGE_SIZE))]
	if listing.item_count > 0:
		listing.select(0)
		_select(0)
	else:
		detail.text = "검색 조건에 맞는 항목이 없습니다."
		selected_id = -1
		_refresh_action()

func _entry_image(entry: Dictionary) -> Dictionary:
	var row: Dictionary = entry.get("source_row",{})
	match str(entry.get("source_table","")):
		"MarketPurchase_Korean", "Currency":
			return IMAGES.resolve_asset_value(row.get("AssetID"))
		"MerchantGoods":
			var id: Variant = row.get("ItemClassID")
			if (id is int or id is float) and is_finite(float(id)) and float(id) == floor(float(id)) and float(id) > 0:
				return IMAGES.describe_item_class(int(id))
		"source_shop_order":
			return _order_item_image(entry.get("source_order", {}), str(entry.id))
	return {}

func _typed_item_image(value: Variant) -> Dictionary:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) < 0:
		return IMAGES.describe_item_class(-1)
	return IMAGES.describe_item_class(int(value))

func _order_item_image(order: Dictionary, order_id: String = "") -> Dictionary:
	# The order provider resolves unit 4 as ItemClass. A bundle never borrows
	# one member's icon as its representative image.
	var goods: Variant = order.get("goods")
	if not goods is Array or goods.size() != 1 or not goods[0] is Dictionary: return {}
	var token: Dictionary = goods[0]
	if token.get("unit_id") != 4: return {}
	var image: Dictionary = _typed_item_image(token.get("class_id"))
	image["presentation_relation"] = {"namespace":"source_shop_order.goods","order_id":str(order.get("id", order_id)),"unit_id":4,"field":"class_id"}
	return image

func _missing_reward_image(reason: String, relation: Dictionary) -> Dictionary:
	return {"route":"source523_images","status":"original_icon_not_installed","source_status":reason,"reason":reason,"texture":null,"provenance":{},"presentation_relation":relation,"actual_game_consumption_observed":false}

func _cumulative_reward_image(event: Dictionary, step: int) -> Dictionary:
	var reward_id: int = int(event.get("DailyRewardID", 0)) if step == 0 else 0
	var relation: Dictionary = {"source_table":"CumulativePurchase","source_id":event.get("ID"),"source_field":"DailyRewardID"}
	if step > 0:
		var found: bool = false
		for row: Dictionary in catalog.rows("CumulativePurchaseStep"):
			if row.get("CumulativePurchaseID") != selected_id or row.get("Step") != step: continue
			if found: return _missing_reward_image("ambiguous_cumulative_reward_step", relation)
			found = true
			reward_id = int(row.get("RewardID", 0))
			relation = {"source_table":"CumulativePurchaseStep","source_id":row.get("ID"),"source_field":"RewardID"}
		if not found: return _missing_reward_image("missing_cumulative_reward_step", relation)
	relation["reward_id"] = reward_id
	if reward_id == 0: return _missing_reward_image("zero_sentinel", relation)
	var reward: Dictionary = catalog.record("Reward", reward_id)
	if reward.is_empty(): return _missing_reward_image("missing_source_reward", relation)
	var type: Dictionary = catalog.record("RewardType", int(reward.get("RewardTypeID", 0)))
	if type.get("Name") != "Item": return _missing_reward_image("unsupported_reward_icon_role", relation)
	# RewardClassID belongs to ItemClass only after the source RewardType join.
	var image: Dictionary = _typed_item_image(reward.get("RewardClassID"))
	relation["reward_field"] = "RewardClassID"
	image["presentation_relation"] = relation
	return image

func _refresh_payout_images() -> void:
	if purchase.has_meta("source523_payout_image"):
		purchase.icon = null
		for key: String in ["source523_payout_image", "source523_image", "source523_image_provenance", "source523_image_status"]:
			if purchase.has_meta(key): purchase.remove_meta(key)
	for index: int in range(reward_step.item_count): reward_step.set_item_icon(index, null)
	if reward_step.has_meta("source523_reward_images"): reward_step.remove_meta("source523_reward_images")
	if not IMAGES.selected() or selected_id < 0: return
	var selected_image: Dictionary = {}
	if mode.selected in [0, 1]:
		# The selected row already resolved its explicit Market/ItemClass role.
		# Preserve that same image result, including missing and owner exclusion.
		var originals: Dictionary = listing.get_meta("source523_images", {})
		for index: int in listing.item_count:
			if listing.get_item_metadata(index) != selected_id: continue
			var evidence: Variant = originals.get(str(selected_id))
			if evidence is Dictionary:
				selected_image = evidence.duplicate(true)
				selected_image["texture"] = listing.get_item_icon(index)
			break
	elif mode.selected == 3:
		var event: Dictionary = catalog.record("CumulativePurchase", selected_id)
		if event.is_empty(): return
		var images: Dictionary = {}
		for index: int in range(reward_step.item_count):
			var image: Dictionary = _cumulative_reward_image(event, reward_step.get_item_id(index))
			reward_step.set_item_icon(index, image.get("texture") as Texture2D)
			var step_evidence: Dictionary = image.duplicate(true)
			step_evidence.erase("texture")
			images[index] = step_evidence
			if index == reward_step.selected: selected_image = image
		reward_step.set_meta("source523_reward_images", images)
	elif mode.selected == 4 and runtime != null:
		selected_image = _order_item_image(runtime.state.orders.get(str(selected_id), {}), str(selected_id))
	if selected_image.is_empty(): return
	purchase.icon = selected_image.get("texture") as Texture2D
	purchase.expand_icon = true
	var action_evidence: Dictionary = selected_image.duplicate(true)
	action_evidence.erase("texture")
	purchase.set_meta("source523_payout_image", true)
	purchase.set_meta("source523_image", action_evidence)
	purchase.set_meta("source523_image_provenance", selected_image.get("provenance", {}).duplicate(true))
	purchase.set_meta("source523_image_status", str(selected_image.get("source_status", selected_image.get("status", selected_image.get("reason", "")))))

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
	if unit == 34:
		if id==1:return "마일리지"
		if id==2:return "다이아"
		return str(catalog.record("IntangibleItemClass", id).get("Name", "재화 #%d" % id))
	return "%s #%d" % [catalog.unit_name(unit), id]

func _date_text(row: Dictionary) -> String:
	if row.is_empty(): return "미확인"
	return "%04d-%02d-%02d %02d:%02d" % [int(row.Year), int(row.Month), int(row.Day), int(row.Hour), int(row.Minute)]

func _select(index: int) -> void:
	if index < 0 or index >= listing.item_count: return
	var id: int = int(listing.get_item_metadata(index))
	selected_id = id
	var lines: Array[String] = []
	match mode.selected:
		0: lines = _market_detail(id)
		1: lines = _merchant_detail(id)
		2: lines = _currency_detail(id)
		3: lines = _cumulative_detail(id)
		4: lines = _order_detail(str(id))
	# Source descriptions may contain BBCode-like text. Never interpret it.
	detail.text = UI.safe("\n".join(lines))
	_refresh_action()

func _refresh_action() -> void:
	_refresh_payout_images()
	purchase.disabled = true
	availability_label.text = ""
	if runtime == null:
		purchase.text = "실제 게임에서 이용할 수 있습니다"
		return
	var world: Node = hud.get_parent()
	wallet_label.text = "보유 아데나 %d · 다이아 %d · 마일리지 %d · 미수령 주문 %d" % [int(world.gold),int(world.inventory.get("다이아",0)),int(world.inventory.get("마일리지",0)),runtime.orders().size()]
	if selected_id < 0:
		purchase.text = "항목 선택"
		return
	match mode.selected:
		0:
			var quote: Dictionary = runtime.quote(selected_id, int(quantity.value))
			purchase.disabled = not quote.ok
			purchase.text = "%d회 구매 · 보관함 지급" % int(quantity.value) if quote.ok else "구매 불가"
			availability_label.text = "구매 후 보관함에서 수령하세요" if quote.ok else str(quote.reason)
			purchase.tooltip_text = availability_label.text
		1:
			var quote: Dictionary=runtime.quote_merchant(selected_id,int(quantity.value))
			_apply_quoted_item_image(quote)
			purchase.disabled=not quote.ok
			purchase.text="%d회 구매 · 보관함 지급" % int(quantity.value) if quote.ok else "구매 불가"
			if quote.ok:
				var provenance: String="TWILIGHT 자체 가격 · 오프라인 가정" if quote.has("rule_origin") else ("TWILIGHT 자체 가격" if str(quote.price_origin).contains("TWILIGHT") else "가격 출처: 상세 내용")
				availability_label.text="%d회 · %d %s\n%s" % [int(quantity.value),int(quote.payment.amount),_value_name(int(quote.payment.unit_id),int(quote.payment.class_id)),provenance]
			else:availability_label.text=str(quote.reason)
			purchase.tooltip_text=str(quote.get("quota_text",availability_label.text))
		2: purchase.text = "재화 원천 안내"
		3:
			var view: Dictionary = runtime.cumulative_quote(selected_id, reward_step.selected)
			purchase.disabled = not view.ok
			purchase.text = "보상 수령" if view.ok else "수령 불가"
			availability_label.text = "" if view.ok else str(view.reason)
		4:
			purchase.disabled = false
			purchase.text = "선택 주문 수령"

func _apply_quoted_item_image(quote: Dictionary) -> void:
	if not IMAGES.selected(): return
	var source: Variant=quote.get("source_reference")
	if not source is Dictionary: return
	var reference: Variant=source.get("item")
	if not reference is Dictionary or reference.get("kind")!="twilight.current523.item-data.v1": return
	var goods: Variant=source.get("goods")
	var image: Dictionary
	if not goods is Dictionary or goods.get("ID")!=selected_id or goods.get("ItemClassID")!=reference.get("item_class_id"):
		image={"status":"source_reference_item_identity_mismatch","texture":null,"provenance":{},"actual_game_consumption_observed":false}
	else:
		image=IMAGES.describe_item_reference(reference)
	# Keep the purchase state with the existing quote. This is only its row icon.
	for index: int in listing.item_count:
		if listing.get_item_metadata(index)!=selected_id: continue
		listing.set_item_icon(index,image.get("texture") as Texture2D)
		var evidence: Dictionary=image.duplicate(true)
		evidence.erase("texture")
		evidence["source_table"]="MerchantGoods"
		var originals: Dictionary=listing.get_meta("source523_images",{}).duplicate(true)
		originals[str(selected_id)]=evidence
		listing.set_meta("source523_images",originals)
		_refresh_payout_images()
		break

func _act() -> void:
	if runtime == null or purchase.disabled or selected_id < 0: return
	var id: int = selected_id
	var current_mode: int = mode.selected
	var count: int = int(quantity.value)
	var step: int = reward_step.selected
	var action: String = "구매" if current_mode in [0,1] else "수령"
	var body: String = "구매 재화를 차감하고 보관함 주문으로 저장합니다. 인벤토리 지급은 보관함 수령 시 처리됩니다." if current_mode in [0,1] else "선택한 지급품과 수령 기록을 함께 저장합니다."
	if current_mode in [0,1]:
		var quote: Dictionary = runtime.quote(id, count) if current_mode==0 else runtime.quote_merchant(id,count)
		if not quote.ok: _refresh_action(); return
		body = "%s ×%d회\n차감: %s ×%d\n\n%s" % [str(quote.name),count,_value_name(int(quote.payment.unit_id),int(quote.payment.class_id)),int(quote.payment.amount),body]
		if quote.has("price_origin"):body+="\n"+str(quote.price_origin)
		if quote.has("rule_origin"):body+="\n"+str(quote.npc_label)+"\n"+str(quote.rule_origin)
		if quote.has("use_origin"):body+="\n"+str(quote.use_origin)
		if quote.has("quota_text"):body+="\n"+str(quote.quota_text)
	var confirmation: Control = hud.confirm_action("원본 상점 · " + action, body, action, func(_unused: int) -> void:
		var result: Dictionary
		match current_mode:
			0: result = runtime.buy(id, count)
			1: result = runtime.buy_merchant(id,count)
			3: result = runtime.claim_cumulative(id, step)
			4: result = runtime.claim(str(id))
			_: return
		result_label.text = str(result.get("reason", "거래를 완료했습니다"))
		if result.ok:
			hud.get_parent()._update_hud()
			hud.refresh_inventory(hud.get_parent().inventory)
			if result.has("order_id"):
				mode.select(4)
				search.set_block_signals(true)
				search.text = ""
				search.set_block_signals(false)
			_build_entries()
		else: _refresh_action())
	if confirmation == null: return
	var confirm_button: Variant = confirmation.get("confirm_button")
	if not confirm_button is Button: return
	confirm_button.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if confirm_button.has_meta(key): confirm_button.remove_meta(key)
	if current_mode not in [0, 1] or not IMAGES.selected() or not purchase.has_meta("source523_payout_image"): return
	# This confirmation performs the same selected action; its icon is not a
	# representative chosen from the order or product contents.
	confirm_button.icon = purchase.icon
	confirm_button.expand_icon = true
	confirm_button.set_meta("source523_image", purchase.get_meta("source523_image", {}).duplicate(true))
	confirm_button.set_meta("source523_image_provenance", purchase.get_meta("source523_image_provenance", {}).duplicate(true))
	confirm_button.set_meta("source523_image_status", purchase.get_meta("source523_image_status", ""))

func _order_detail(id: String) -> Array[String]:
	if runtime == null: return ["보관함을 확인할 수 없습니다"]
	var order: Dictionary = runtime.state.orders.get(id, {})
	if order.is_empty(): return ["주문 없음"]
	var lines: Array[String] = ["보관함 주문 #" + id, "결제 완료 · 미수령", ""]
	for token: Dictionary in order.goods:
		lines.append("%s ×%d" % [_value_name(int(token.unit_id),int(token.class_id)),int(token.amount)])
	if order.has("rule_origin"):lines.append("\n"+str(order.rule_origin))
	lines.append("\n수령 시 구매 재화가 다시 차감되지 않습니다.")
	return lines

func _market_detail(id: int) -> Array[String]:
	var offer: Dictionary = catalog.market_offer(id)
	var result: Array[String] = [str(offer.name), "", str(offer.description), "", "상품 번호: %d" % id]
	var payment: Dictionary = offer.payment
	if payment.is_empty():
		result.append("결제 정보 미확인")
	else:
		if int(payment.UnitID) == 37 and CashMarket.listed(id):
			result.append(CashMarket.describe(id))
		elif int(payment.UnitID) == 37:
			result.append("외부 결제 상품 · TWILIGHT 다이아 환산가 미등록")
		elif int(payment.MarketPaymentTypeID) == 4:
			result.append("결제 금액: %d · %s" % [int(payment.Amount), _value_name(int(payment.UnitID), int(payment.ClassID))])
		else:
			result.append("무료·쿠폰·시스템 지급 자격 확인 필요")
		if payment.get("ClassChangeDiscount") == true: result.append("클래스체인지 할인: 조건 확인 필요")
	result.append("\n지급 상품 (1회 구매 기준)")
	for link: Dictionary in offer.products:
		var product: Dictionary = link.product.definition
		if product.is_empty(): result.append("지급 대상 연결 누락"); continue
		if CashMarket.strip(id, product): continue
		result.append("%s ×%d" % [_value_name(int(product.UnitID), int(product.ClassID)), int(product.Amount)])
		if int(product.UnitID) == 4 and CashPackages.is_package(int(product.ClassID)): result.append(CashPackages._summary(int(product.ClassID)))
		if not link.product.additional.is_empty(): result.append("클래스체인지 대상 조건 %d개 · 추가 아이템 지급과 구분" % link.product.additional.size())
	if not offer.bonuses.is_empty(): result.append("별도 구매 보너스: %d개 정의 · 지급 조건 확인 필요" % offer.bonuses.size())
	result.append("\n기간: %s ~ %s\n원본 판매 플래그: %s" % [_date_text(offer.effective_from), _date_text(offer.effective_to), "켜짐" if offer.purchase.OnSale else "꺼짐"])
	result.append("기간의 시간 기준과 서버 활성 여부는 별도 확인합니다.")
	for limit: Dictionary in offer.server_limits: result.append("서버 조건: Set %d" % int(limit.ServerLimitSetID))
	result.append("\n구매 제한: %d개" % offer.restrictions.size())
	for restriction: Dictionary in offer.restrictions:
		result.append("유형 %d · %s %d · %s %d" % [int(restriction.MarketRestrictionTypeId), catalog.unit_name(int(restriction.ValueUnitId)), int(restriction.Value), catalog.unit_name(int(restriction.DurationUnitId)), int(restriction.DurationValue)])
	if runtime != null:
		var quote: Dictionary = runtime.quote(id, int(quantity.value))
		result.append("\n" + ("실제 구매 가능 · 보관함 지급" if quote.ok else str(quote.reason)))
	else: result.append("\n" + "\n".join(catalog.activation(id).reasons))
	return result

func _merchant_detail(id: int) -> Array[String]:
	var offer: Dictionary = catalog.merchant_offer(id)
	var goods: Dictionary = offer.goods
	var result: Array[String] = [_item_name(int(goods.ItemClassID)), "", "NPC 상점 번호: %d · 판매행 #%d" % [int(goods.MerchantsID), id],
		"1회 상품 수량: %d · 강화: +%d" % [int(goods.Amount), int(goods.Enchant)],
		"", "구매 횟수 한도: %d · 계정 기준: %s" % [int(goods.LimitCount), str(goods.LimitCountPerAccount)],
		"서버 한도: %d · 갱신 유형: %d" % [int(goods.LimitServerCount), int(goods.LimitCountRefreshTypeID)],
		"레벨: %d ~ %d" % [int(goods.LimitMinLevel), int(goods.LimitMaxLevel)],
		"혈맹 레벨 (원문 조건별): %d / %d" % [int(goods.ClanLevelMin), int(goods.LimitMinClanLevel)],
		"공성 이용 / 공성 중 제한: %s / %s" % [str(goods.AvailableSiegeTime), str(goods.LimitNotInSiegeTime)],
		"가입 후 일수 (원문 조건별): %d / %d" % [int(goods.DaysAfterClanJoin), int(goods.LimitDaysAfterClanJoin)],
		"카드 조건: %d · 반복구매 카드 조건: %d" % [int(goods.LimitBuffCardID), int(goods.LimitRepeatedBuyCardID)],
		"판매 시각: %d ~ %d · 시간: %d ~ %d" % [int(goods.LimitStartTime), int(goods.LimitEndTime), int(goods.LimitStartHour), int(goods.LimitEndHour)],
		"\n수량·구매횟수·조건을 개별 보존합니다."]
	if runtime!=null:
		var price: Dictionary=runtime.merchant_price(id)
		if price.ok:
			result.insert(4,"1회 가격: %d · %s\n%s\n" % [int(price.amount),_value_name(int(price.unit_id),int(price.class_id)),str(price.origin)])
			if not str(price.get("reference_url","")).is_empty():result.append("기본가 참고: "+str(price.reference_url))
		else:result.append(str(price.reason))
		var quote: Dictionary=runtime.quote_merchant(id,int(quantity.value))
		if quote.has("rule_origin"):result.insert(5,str(quote.npc_label)+"\n"+str(quote.rule_origin)+"\n")
		if quote.has("use_origin"):result.append(str(quote.use_origin))
		if quote.has("quota_text"):result.append(str(quote.quota_text))
		result.append("\n"+("구매 가능 · 보관함 지급" if quote.ok else str(quote.reason)))
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
		"원본 안내: 일일 05시 / 주간 수요일 05시. 현재 게임의 시간 기준은 변경하지 않습니다.", "행사 기간·활성 일수·지급 조건을 충족하면 수령할 수 있습니다."]
	var steps: Array = []
	for row: Dictionary in catalog.rows("CumulativePurchaseStep"):
		if int(row.CumulativePurchaseID) == id: steps.append(row)
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.Step) < int(b.Step))
	result.append("\n일일 보상: " + _reward_text(int(data.DailyRewardID)))
	for step: Dictionary in steps: result.append("%d단계 · %s" % [int(step.Step), _reward_text(int(step.RewardID))])
	if runtime!=null:
		var view: Dictionary=runtime.cumulative_view(id)
		result.append("\n현재 활성 일수: %d" % int(view.get("activated_days",0)) if view.ok else "\n"+str(view.reason))
	return result

func _reward_text(id: int) -> String:
	var reward: Dictionary = catalog.record("Reward", id)
	if reward.is_empty(): return "보상 연결 미확인 · #%d" % id
	var type: Dictionary = catalog.record("RewardType", int(reward.get("RewardTypeID", 0)))
	if type.get("Name") == "Item":
		return "%s ×%d" % [_item_name(int(reward.get("RewardClassID", 0))), int(reward.get("Amount", 0))]
	return "%s #%d ×%d" % [str(type.get("Name", "보상")), int(reward.get("RewardClassID", 0)), int(reward.get("Amount", 0))]
