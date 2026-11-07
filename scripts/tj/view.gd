extends VBoxContainer
const Source = preload("res://scripts/tj/source523.gd")
const SourceImages = preload("res://scripts/ui/source523_image_assets.gd")
var world
var coupons: OptionButton
var events: OptionButton
var success: ItemList
var failure: ItemList
var status: Label
var use_button: Button
var selected_revision := -1
var event_rows: Array=[]
var confirmation: ConfirmationDialog

func _row_image(list, index: int, image: Dictionary, table: String, row_id: Variant, field: String, deck: Variant = null) -> void:
	list.set_item_icon(index, image.get("texture") as Texture2D)
	var loader: Dictionary = image.duplicate(true)
	loader.erase("texture")
	var evidence: Dictionary = {"source_table":table,"source_row_id":row_id,"source_field":field,"producer_source_zip_sha256":Source.SHA,"image":loader}
	if deck != null: evidence["source_deck_id"] = deck
	var images: Dictionary = list.get_meta("source523_images", {})
	images[index] = evidence
	list.set_meta("source523_images", images)

func _clear_image_metadata(list) -> void:
	if list.has_meta("source523_images"): list.remove_meta("source523_images")

func _selected_coupon_image() -> void:
	use_button.icon = null
	for key: String in ["source523_image", "source523_image_status"]:
		if use_button.has_meta(key): use_button.remove_meta(key)
	if not SourceImages.selected():
		for index: int in range(coupons.item_count): coupons.set_item_icon(index, null)
		_clear_image_metadata(coupons)
		return
	if coupons.selected < 0: return
	var images: Dictionary = coupons.get_meta("source523_images", {})
	if not images.has(coupons.selected): return
	var evidence: Dictionary = images[coupons.selected].duplicate(true)
	use_button.icon = coupons.get_item_icon(coupons.selected)
	use_button.set_meta("source523_image", evidence)
	use_button.set_meta("source523_image_status", str(evidence.image.get("source_status", evidence.image.get("status", evidence.image.get("reason", "")))))

func _missing_image(reason: String) -> Dictionary:
	return {"ok":false,"status":reason,"error":reason,"texture":null,"provenance":{}}

func _card_image(id: String, card: Dictionary, event: Dictionary) -> Dictionary:
	# The verified TJ producer supplies BuffCard rows. The image pack resolves
	# their declared asset; it does not provide a BuffCard canonical-row check.
	if not id.is_valid_int() or str(int(id)) != id or int(id) <= 0:
		return _missing_image("source_candidate_identity_required")
	var row_id: Variant = card.get("ID")
	if not (row_id is int or row_id is float) or row_id != int(id):
		return _missing_image("source_candidate_identity_mismatch")
	var deck: Variant = event.get("deck")
	var row_deck: Variant = card.get("BuffCardDeckID")
	if not (deck is int or deck is float) or not is_finite(float(deck)) or float(deck) != floor(float(deck)) or float(deck) <= 0 or not (row_deck is int or row_deck is float) or row_deck != deck:
		return _missing_image("source_candidate_deck_mismatch")
	if not card.has("DisplayBaseAssetID"):
		return _missing_image("source_display_base_asset_field_missing")
	return SourceImages.resolve_asset_value(card.DisplayBaseAssetID)

func configure(host) -> void:
	world=host
	var title := Label.new();title.text="TJ 재도전 · 복구";add_child(title)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
	var notice := Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.text="TWILIGHT 로컬 어댑터: 실제 실패 기록만 사용합니다. 성공 후보 1개와 실패 후보를 선택해 결과 1개를 받습니다. 추가 신비 보상은 지원하지 않습니다. 카드 카탈로그에서 실패 기록을 만들지 않습니다. 옵션 각성은 기존 엔진의 경험치와 비용 조건을 유지합니다. 장비·스킬 합성의 미연결 경로는 쿠폰을 소모하지 않습니다. 서버 정보는 기존 카드 컬렉션 설정을 사용합니다. 시간대는 로컬 정책 UTC+09:00입니다."
	add_child(notice)
	var server_form := HBoxContainer.new();add_child(server_form)
	var region := LineEdit.new();region.placeholder_text="실제 서비스 지역 코드";server_form.add_child(region)
	var world_no := LineEdit.new();world_no.placeholder_text="실제 월드 번호";server_form.add_child(world_no)
	var apply := Button.new();apply.text="입력한 서버 문맥 저장";server_form.add_child(apply)
	apply.pressed.connect(func():
		var result: Dictionary=world.tj_coupons.set_context(region.text,world_no.text)
		refresh_events();status.text=str(result.get("error","")))
	var choose := Button.new();choose.text="최신 523 원본 ZIP 설치";add_child(choose)
	var picker := FileDialog.new();picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.use_native_dialog=true;picker.filters=PackedStringArray(["*.zip;최신 523 데이터 ZIP;application/zip"]);add_child(picker)
	choose.pressed.connect(func():picker.popup_centered_ratio(0.8))
	picker.file_selected.connect(func(path: String):
		choose.disabled=true;status.text="최신 원본을 백그라운드에서 검증하고 있습니다."
		var loaded: bool=await world.tj_coupons.install_async(path)
		if not is_instance_valid(self):return
		choose.disabled=false;refresh()
		status.text="원본 설치 완료" if loaded else "원본 SHA 또는 1065표 검증 실패")
	coupons=OptionButton.new();coupons.expand_icon=true;add_child(coupons);coupons.item_selected.connect(func(_index: int):refresh_events())
	events=OptionButton.new();add_child(events);events.item_selected.connect(func(_index: int):refresh_choices())
	var caption := Label.new();caption.text="성공 후보 한 개 / 실패 후보 (스페셜 합성은 중복 없이 5개)";add_child(caption)
	success=ItemList.new();success.custom_minimum_size.y=100;add_child(success)
	failure=ItemList.new();failure.select_mode=ItemList.SELECT_MULTI;failure.custom_minimum_size.y=100;add_child(failure)
	use_button=Button.new();use_button.text="선택 확인";use_button.expand_icon=true;add_child(use_button);use_button.pressed.connect(confirm)
	var reload_button := Button.new();reload_button.text="소유 쿠폰과 실패 기록 새로고침";add_child(reload_button);reload_button.pressed.connect(refresh)
	if OS.is_debug_build():
		var grant := Button.new();grant.text="개발 도구: 선택 쿠폰 한 장 지급 (실패 기록 지급 없음)";add_child(grant)
		grant.pressed.connect(func():
			if coupons.selected<0:return
			var result: Dictionary=world.tj_coupons.grant_for_test(str(coupons.get_item_metadata(coupons.selected)))
			status.text=str(result.get("error","테스트 쿠폰 지급 저장 완료"));refresh())
	refresh()
	if world.tj_coupons.core.definitions.is_empty():
		choose.disabled=true;status.text="보유한 최신 원본을 읽고 있습니다."
		var loaded: bool=world.tj_coupons.load_default_source()
		choose.disabled=false;refresh()
		if not loaded:status.text=world.tj_coupons.source_problem
func refresh() -> void:
	coupons.clear()
	_clear_image_metadata(coupons)
	var service=world.tj_coupons.core
	for id: String in service.definitions.get("coupons",{}):
		var row: Dictionary=service.definitions.coupons[id]
		coupons.add_item("%s · 보유 %d" % [str(row.item.Name),int(service.state.coupons.get(id,0))])
		coupons.set_item_metadata(coupons.item_count-1,id)
		if SourceImages.selected():
			_row_image(coupons, coupons.item_count - 1, SourceImages.describe_item_class_row(row.item), "ItemClass", row.item.get("ID"), "IconID")
	if coupons.item_count==0:status.text="최신 523 원본이 없습니다. 기존 저장과 게임 기능은 유지됩니다."
	refresh_events()
func refresh_events() -> void:
	events.clear();event_rows=[];success.clear();failure.clear();use_button.disabled=true
	_clear_image_metadata(success);_clear_image_metadata(failure);_selected_coupon_image()
	if coupons.selected<0:return
	var service=world.tj_coupons.core
	var view: Dictionary=service.candidates(str(coupons.get_item_metadata(coupons.selected)),world.tj_coupons.context(),service.clock())
	selected_revision=int(service.state.revision)
	status.text=str(view.get("error","소유 쿠폰과 실제 실패 이력을 확인하세요"))
	if not view.ok:return
	event_rows=view.get("events",[])
	for event: Dictionary in event_rows:events.add_item("%s · 종류 %s · 원본 등급 %s" % [str(event.id),str(event.history_type),str(event.grade)])
	refresh_choices()
func refresh_choices() -> void:
	success.clear();failure.clear();use_button.disabled=true
	_clear_image_metadata(success);_clear_image_metadata(failure);_selected_coupon_image()
	if events.selected<0 or events.selected>=event_rows.size():return
	var event: Dictionary=event_rows[events.selected]
	failure.visible=str(event.get("adapter",""))!="awakening"
	for pair: Array in [[success,event.success_candidates],[failure,event.fail_candidates]]:
		for id: String in pair[1]:
			var card: Dictionary=world.tj_coupons.core.definitions.cards.get(id,{})
			pair[0].add_item(str(card.get("Name",id)));pair[0].set_item_metadata(pair[0].item_count-1,id)
			if SourceImages.selected():
				_row_image(pair[0], pair[0].item_count - 1, _card_image(id, card, event), "BuffCard", card.get("ID"), "DisplayBaseAssetID", event.get("deck"))
	if str(event.get("adapter",""))=="awakening" and success.item_count==1 and failure.item_count==1:
		success.select(0);failure.select(0)
	use_button.disabled=false
func confirm() -> void:
	if is_instance_valid(confirmation):return
	if events.selected<0 or coupons.selected<0:return
	var item: String=str(coupons.get_item_metadata(coupons.selected))
	var event: String=str(event_rows[events.selected].id)
	var revision: int=selected_revision
	var good: Array=[];var bad: Array=[]
	for index: int in success.get_selected_items():good.append(str(success.get_item_metadata(index)))
	for index: int in failure.get_selected_items():bad.append(str(failure.get_item_metadata(index)))
	var popup := ConfirmationDialog.new();confirmation=popup;popup.name="TJSpendConfirmation";popup.title="TJ 재도전 확인";popup.dialog_text="선택한 쿠폰 1장과 실패 이력을 사용합니다. TWILIGHT 추가 비용은 %d 아데나이며, 옵션 각성은 기존 각성 비용도 필요합니다. 원자 저장에 성공한 결과만 지급합니다. 취소하면 변경하지 않습니다." % int(world.tj_coupons.core.settings.retry_gold_cost);add_child(popup)
	# This dialog spends the exact selected coupon, not a representative card
	# from its potentially multiple success/failure candidates.
	var coupon_row: Dictionary=world.tj_coupons.core.definitions.get("coupons",{}).get(item,{}).get("item",{})
	if SourceImages.selected() and not coupon_row.is_empty():
		var image: Dictionary=SourceImages.describe_item_class_row(coupon_row)
		var button: Button=popup.get_ok_button()
		button.icon=image.get("texture") as Texture2D
		button.expand_icon=true
		var evidence: Dictionary=image.duplicate(true)
		evidence.erase("texture")
		button.set_meta("source523_coupon_image",evidence)
	popup.confirmed.connect(func():
		var result: Dictionary=world.tj_coupons.redeem(item,event,revision,good,bad)
		refresh();status.text=str(result.get("error","완료"));popup.hide();popup.queue_free())
	popup.canceled.connect(func():popup.hide();popup.queue_free())
	popup.popup_centered(Vector2i(540,180))
