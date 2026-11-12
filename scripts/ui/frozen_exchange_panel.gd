extends VBoxContainer
## Offline exchange UI. Selection is read-only; every purchase needs a review.
const Runtime = preload("res://scripts/exchange/frozen_exchange.gd")
const Catalog = preload("res://scripts/exchange/frozen_catalog.gd")
var runtime = Runtime.new()
var hud: Node
var status: Label
var search: LineEdit
var servers: OptionButton
var categories: OptionButton
var listing: ItemList
var detail: Label
var bundles: SpinBox
var review: Button
var confirm: Button
var cancel: Button
var result: Label
var filtered: Array = []
var selected_id: String = ""
var reviewed_id: String = ""
var reviewed_bundles: int = 0
var refresh_elapsed: float = 0.0
const PAGE_SIZE: int = 80
var page: int = 0
var page_label: Label
var previous_page: Button
var next_page: Button

func configure(controller: Node, path: String = Catalog.PATH) -> void:
	hud = controller
	runtime.configure(hud.get_parent(),path)
	name = "FrozenExchangePanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	var filters := HBoxContainer.new(); add_child(filters)
	servers = OptionButton.new(); servers.name = "ExchangeServer"
	var coverage: Dictionary = runtime.catalog.snapshot.get("coverage",{})
	var representative: bool = coverage.get("scope") == "representative_server"
	servers.add_item("수집한 전체 상품" if representative else "전체 서버"); servers.set_item_metadata(0,""); filters.add_child(servers)
	var scope_ids: Array = coverage.get("expected_server_ids",[]).duplicate()
	if representative:
		var shared_world: String = str(coverage.get("scope_proof",{}).get("world_id",""))
		if not shared_world.is_empty() and not scope_ids.has(shared_world): scope_ids.append(shared_world)
	for server: Variant in scope_ids:
		var label: String = str(server)
		if representative:
			if str(server).begins_with("server:"): label = str(coverage.get("server_name",server)) + " · 서버 거래소"
			else: label = str(coverage.get("world_name",server)) + " · 월드 거래소"
		servers.add_item(label); servers.set_item_metadata(servers.item_count-1,str(server))
	servers.item_selected.connect(func(_index: int) -> void: _filter())
	categories = OptionButton.new(); categories.name = "ExchangeCategory"; categories.add_item("전체 분류"); categories.set_item_metadata(0,0); filters.add_child(categories)
	var selected_categories: Variant = coverage.get("selected_categories",[])
	if selected_categories is Array:
		for category: Variant in selected_categories:
			if not category is Dictionary or not Catalog.integer(category.get("id"),1) or not category.get("name") is String or str(category.name).is_empty(): continue
			categories.add_item(str(category.name)); categories.set_item_metadata(categories.item_count-1,int(category.id))
	categories.disabled = categories.item_count == 1
	categories.item_selected.connect(func(_index: int) -> void: _filter())
	search = LineEdit.new(); search.name = "ExchangeSearch"; search.placeholder_text = "실측 상품명 검색"; search.size_flags_horizontal = Control.SIZE_EXPAND_FILL; filters.add_child(search)
	search.text_changed.connect(func(_value: String) -> void: _filter())
	listing = ItemList.new(); listing.name = "ExchangeListings"; listing.size_flags_vertical = Control.SIZE_EXPAND_FILL; listing.custom_minimum_size.y = 120; add_child(listing)
	listing.item_selected.connect(_select)
	var pages := HBoxContainer.new(); add_child(pages)
	previous_page = Button.new(); previous_page.text = "이전"; previous_page.pressed.connect(func() -> void: page -= 1; _show_page()); pages.add_child(previous_page)
	page_label = Label.new(); pages.add_child(page_label)
	next_page = Button.new(); next_page.text = "다음"; next_page.pressed.connect(func() -> void: page += 1; _show_page()); pages.add_child(next_page)
	detail = Label.new(); detail.name = "ExchangeDetail"; detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(detail)
	var actions := HBoxContainer.new(); add_child(actions)
	var label := Label.new(); label.text = "구매 묶음 수"; actions.add_child(label)
	bundles = SpinBox.new(); bundles.name = "ExchangeBundleCount"; bundles.min_value = 1; bundles.max_value = 1000; bundles.step = 1; bundles.value = 1; actions.add_child(bundles)
	bundles.value_changed.connect(func(_value: float) -> void: _clear_review(); _refresh())
	review = Button.new(); review.name = "ExchangeReview"; review.text = "구매 내용 확인"; review.pressed.connect(_review); actions.add_child(review)
	confirm = Button.new(); confirm.name = "ExchangeConfirm"; confirm.text = "다이아 차감 후 구매"; confirm.visible = false; confirm.pressed.connect(_buy); actions.add_child(confirm)
	cancel = Button.new(); cancel.name = "ExchangeCancel"; cancel.text = "취소"; cancel.visible = false; cancel.pressed.connect(func() -> void: _clear_review(); _refresh()); actions.add_child(cancel)
	result = Label.new(); result.name = "ExchangeResult"; result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(result)
	tree_exiting.connect(func() -> void:
		if runtime.shop != null: runtime.shop.release_catalog())
	_filter()

func _clear_review() -> void:
	reviewed_id = ""; reviewed_bundles = 0
	confirm.visible = false; cancel.visible = false

func _filter() -> void:
	filtered.clear(); page = 0
	var server: String = str(servers.get_item_metadata(servers.selected))
	var category: int = int(categories.get_item_metadata(categories.selected))
	# Reference-only filter results; do not deep-copy a whole all-server snapshot.
	for row: Dictionary in runtime.catalog.snapshot.get("listings",[]):
		if not server.is_empty() and row.server_id != server: continue
		if category > 0:
			var row_categories: Variant = row.get("category1_ids",[])
			if not row_categories is Array: continue
			var matches_category: bool = false
			for row_category: Variant in row_categories:
				if Catalog.integer(row_category,1) and int(row_category) == category: matches_category = true; break
			if not matches_category: continue
		if not search.text.is_empty() and not str(row.item_name).containsn(search.text) and not str(row.get("observed_item_name",row.item_name)).containsn(search.text): continue
		filtered.append(row)
	_show_page()

func _show_page() -> void:
	_clear_review(); selected_id = ""; listing.clear()
	page = clampi(page,0,maxi(0,ceili(float(filtered.size()) / PAGE_SIZE)-1))
	for index: int in range(page * PAGE_SIZE,mini(filtered.size(),(page + 1) * PAGE_SIZE)):
		var row: Dictionary = filtered[index]
		listing.add_item("[%s] %s · %d개/묶음 · %d 다이아/묶음" % [row.server_id,row.get("observed_item_name",row.item_name),row.bundle_size,row.bundle_price])
	page_label.text = "%d / %d · %d상품" % [page+1,maxi(1,ceili(float(filtered.size()) / PAGE_SIZE)),filtered.size()]
	previous_page.disabled = page == 0
	next_page.disabled = (page+1) * PAGE_SIZE >= filtered.size()
	_refresh()

func _select(index: int) -> void:
	_clear_review()
	var row_index: int = page * PAGE_SIZE + index
	selected_id = Catalog.key(filtered[row_index]) if index >= 0 and index < listing.item_count and row_index < filtered.size() else ""
	_refresh()

func _refresh() -> void:
	if not runtime.catalog.problem.is_empty(): status.text = runtime.catalog.problem
	elif not runtime.catalog.captured(): status.text = "전 서버 현재 매물 수집 대기 · 임의 상품·가격 없음"
	elif runtime.catalog.snapshot.coverage.get("scope") == "representative_server":
		var coverage: Dictionary = runtime.catalog.snapshot.coverage
		status.text = "%s 대표 서버 · 장비·소모품 중심 부분 수집\n수집: %s · 가격 고정 · 재고만 매일 한국 05:00 초기화" % [str(coverage.get("server_name",coverage.expected_server_ids[0])),runtime.catalog.snapshot.captured_at]
	else: status.text = "수집: %s · %d서버 · 가격 고정 · 잔량만 매일 한국 05:00 초기화" % [runtime.catalog.snapshot.captured_at,runtime.catalog.snapshot.coverage.expected_server_ids.size()]
	var row: Dictionary = runtime.catalog.listing(selected_id)
	review.disabled = true
	if row.is_empty(): detail.text = "상품을 선택하세요. 실시간 갱신은 하지 않습니다."; return
	var quote: Dictionary = runtime.quote(selected_id,int(bundles.value))
	var blessing: String = "종류 확인 필요"
	if Catalog.integer(row.attributes.get("blessed_type"),1,1): blessing = "일반"
	elif Catalog.integer(row.attributes.get("blessed_type"),2,2): blessing = "축복"
	elif Catalog.integer(row.attributes.get("blessed_type"),3,3): blessing = "저주"
	var extra: String = " · 추가 옵션 확인 필요" if row.attributes.size() > (1 if row.attributes.has("blessed_type") else 0) else ""
	detail.text = "%s\n%d개 × %d묶음 · 묶음당 %d 다이아 · 남은 %d/%d묶음\n강화 +%d · %s · 속성 %s %d%s\n%s" % [row.get("observed_item_name",row.item_name),row.bundle_size,int(bundles.value),row.bundle_price,runtime.available(row),row.initial_bundles,row.enchant,blessing,"-" if row.element.is_empty() else row.element,row.element_level,extra,"합계 %d 다이아" % quote.total if quote.ok else quote.reason]
	review.disabled = not quote.ok
	if not quote.ok: _clear_review()

func _review() -> void:
	var quote: Dictionary = runtime.quote(selected_id,int(bundles.value))
	if not quote.ok: result.text = quote.reason; _clear_review(); return
	reviewed_id = selected_id; reviewed_bundles = int(bundles.value)
	confirm.visible = true; cancel.visible = true
	result.text = "%s · %d개/묶음 × %d묶음 = %d개, %d 다이아를 차감합니다." % [quote.row.item_name,quote.row.bundle_size,reviewed_bundles,quote.quantity,quote.total]

func _buy() -> void:
	if reviewed_id.is_empty() or reviewed_id != selected_id or reviewed_bundles != int(bundles.value): return
	var id: String = reviewed_id
	var count: int = reviewed_bundles
	_clear_review() # Repeated confirmation signals cannot spend twice.
	var outcome: Dictionary = runtime.buy(id,count)
	result.text = str(outcome.get("reason",""))
	if outcome.ok:
		hud.refresh_inventory(hud.get_parent().inventory)
		hud.get_parent()._update_hud()
	_refresh()

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 1.0 and is_instance_valid(status): refresh_elapsed = 0.0; _refresh()
