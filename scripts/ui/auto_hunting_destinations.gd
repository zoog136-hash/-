extends VBoxContainer
## Destination selection is separate from the existing combat AUTO toggle.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const SourceImages = preload("res://scripts/ui/source523_image_assets.gd")
const SourceSchedule = preload("res://scripts/auto_hunting/source_schedule.gd")
var world: Node
var entries: Array = []
var regions: OptionButton
var landings: OptionButton
var details: Label
var status: Label
var local_enabled: CheckBox
var gem_enabled: CheckBox
var entry_area_enabled: CheckBox
var end_rule: OptionButton
var search_order: OptionButton
var move_button: Button
var owner_scroll: ScrollContainer
var selected_id: int = -1
var detail_summary: String = ""

func configure(owner_world: Node) -> void:
	world = owner_world
	name = "AutoHuntingDestinations"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(HSeparator.new())
	add_child(UI.label("자동사냥 지역", 18, UI.GOLD))
	if not world.has_method("auto_hunting_destinations"):
		return
	var catalog: Dictionary = world.call("auto_hunting_destinations")
	entries = catalog.get("entries", [])
	if entries.is_empty():
		add_child(UI.label(str(catalog.get("reason", "자동사냥 지역 자료를 설치해 주세요")), 13))
		return
	regions = OptionButton.new()
	regions.name = "AutoHuntingRegion"
	regions.custom_minimum_size.y = 42
	regions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regions.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for entry: Dictionary in entries:
		var title: String = str(entry.hunting_territory.Name) if entry.hunting_territory is Dictionary else str(entry.destinations[0].territory.Name)
		regions.add_item("%s · 권장 Lv.%d" % [title, int(entry.schedule.RecommendLevel)])
	add_child(regions)
	landings = OptionButton.new()
	landings.name = "AutoHuntingLanding"
	landings.custom_minimum_size.y = 42
	landings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	landings.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(landings)
	details = UI.label("", 13)
	details.name = "AutoHuntingDestinationDetails"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	status = UI.label("", 13)
	status.name = "AutoHuntingMovementStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var policy_note: Label = UI.label("TWILIGHT 자체 착지 · 원문 소스 필드에서는 현재와 같은 Land의 명시 도착 영역만 사용\n원본 비용·전제조건과 현재 지형·점유·지역 조건을 적용합니다. 원작 활성 규칙 확인을 뜻하지 않습니다. 구형 대응 지형은 기존 자체 정책을 유지합니다.", 13)
	policy_note.name = "AutoHuntingLocalPolicyNote"
	policy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(policy_note)
	local_enabled = CheckBox.new()
	local_enabled.name = "AutoHuntingLocalEnabled"
	local_enabled.text = "TWILIGHT 자체 이동 사용"
	add_child(local_enabled)
	gem_enabled = CheckBox.new()
	gem_enabled.name = "AutoHuntingGemWalletEnabled"
	gem_enabled.text = "인벤토리 다이아를 Gem ID4 잔액으로 사용 (TWILIGHT 정책)"
	gem_enabled.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(gem_enabled)
	entry_area_enabled = CheckBox.new()
	entry_area_enabled.name = "AutoHuntingEntryAreaEnabled"
	entry_area_enabled.text = "입장점 주변 착지 허용 (자체 정책 · 지형/NPC/포탈 검사 유지)"
	entry_area_enabled.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(entry_area_enabled)
	var rules := HBoxContainer.new()
	end_rule = OptionButton.new()
	end_rule.name = "AutoHuntingEndRule"
	end_rule.add_item("끝 셀 포함 (자체 해석)")
	end_rule.add_item("끝 셀 제외 (자체 해석)")
	end_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.add_child(end_rule)
	search_order = OptionButton.new()
	search_order.name = "AutoHuntingSearchOrder"
	search_order.add_item("중앙 가까운 셀부터")
	search_order.add_item("좌표 순서대로")
	search_order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.add_child(search_order)
	add_child(rules)
	var actions := HBoxContainer.new()
	move_button = UI.button("선택 지역으로 이동", _move)
	move_button.name = "AutoHuntingMove"
	move_button.custom_minimum_size.y = 42
	move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(move_button)
	var refresh_button: Button = UI.button("조건 확인", _refresh_assessment)
	actions.add_child(refresh_button)
	add_child(actions)
	# Keep the charged action visible beside its selection/result before the
	# explanatory settings. The existing container can scroll the rest.
	move_child(actions, get_children().find(status) + 1)
	owner_scroll = get_parent().get_parent() as ScrollContainer
	if owner_scroll != null:
		world.hud.workspace.register_scroll_drag(owner_scroll, move_button)
		world.hud.workspace.register_scroll_drag(owner_scroll, local_enabled)
		world.hud.workspace.register_scroll_drag(owner_scroll, gem_enabled)
		world.hud.workspace.register_scroll_drag(owner_scroll, entry_area_enabled)
		world.hud.workspace.register_scroll_drag(owner_scroll, end_rule)
		world.hud.workspace.register_scroll_drag(owner_scroll, search_order)
	_sync_settings()
	local_enabled.toggled.connect(func(_enabled: bool) -> void: _settings_changed())
	gem_enabled.toggled.connect(func(_enabled: bool) -> void: _settings_changed())
	entry_area_enabled.toggled.connect(func(_enabled: bool) -> void: _settings_changed())
	end_rule.item_selected.connect(func(_index: int) -> void: _settings_changed())
	search_order.item_selected.connect(func(_index: int) -> void: _settings_changed())
	regions.item_selected.connect(_select_region)
	landings.item_selected.connect(_select_landing)
	_select_region(0)

func _select_region(index: int) -> void:
	if index < 0 or index >= entries.size(): return
	selected_id = index
	var entry: Dictionary = entries[index]
	landings.clear()
	for landing: Dictionary in entry.destinations:
		landings.add_item(str(landing.territory.Name))
	landings.visible = entry.destinations.size() > 1
	var minimum: int = 0
	for condition: Dictionary in entry.prerequisites:
		if str(condition.type.Name) == "MinLevel": minimum = maxi(minimum, int(condition.definition.Value))
	var cost: String = "%d 아데나" % int(entry.teleport.TeleportCost) if entry.currency.Name == "Adena" else "%d 다이아 (Gem ID4)" % int(entry.teleport.TeleportCost)
	detail_summary = "이동 비용 %s\n%s\n%s" % [cost,
		"입장 Lv.%d 이상" % minimum if minimum > 0 else "별도 레벨 입장 조건 없음",
		"사냥 영역 미지정 · 도착 지역만 제공" if entry.hunting_territory == null else "사냥 영역과 도착 지역은 별도 지정"]
	_select_landing(0)

func _select_landing(index: int) -> void:
	_clear_currency_image()
	if selected_id < 0: return
	var entry: Dictionary = entries[selected_id]
	if index < 0 or index >= entry.destinations.size(): return
	_bind_currency_image(entry, entry.destinations[index])
	var assessment: Dictionary = world.call("auto_hunting_movement_assessment", int(entry.schedule.ID), int(entry.destinations[index].link.ID))
	details.text = detail_summary
	if int(entry.currency.ID) == 4 and world.has_method("auto_hunting_gem_wallet"):
		var wallet: Dictionary = world.call("auto_hunting_gem_wallet")
		details.text += "\n보유 다이아 %d" % int(wallet.balance) if bool(wallet.ok) else "\n" + str(wallet.reason)
	status.text = str(assessment.get("reason", "이동 조건 확인 중"))
	move_button.disabled = not bool(assessment.get("ok", false))

func _clear_currency_image() -> void:
	if not is_instance_valid(move_button): return
	move_button.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if move_button.has_meta(key): move_button.remove_meta(key)

func _bind_currency_image(entry: Dictionary, landing: Dictionary) -> void:
	if not SourceImages.selected(): return
	# request_definition uses this same original Currency.AssetID. Currency.ID
	# remains the payment identity and is never an image or ItemClass key.
	var image: Dictionary = SourceImages.resolve_asset_value(entry.currency.get("AssetID"))
	move_button.icon = image.get("texture") as Texture2D
	move_button.expand_icon = true
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	evidence["payment_source"] = {"source_field":"Currency.AssetID",
		"schedule":entry.schedule.duplicate(true),"currency":entry.currency.duplicate(true),"teleport":entry.teleport.duplicate(true),
		"landing_link_id":landing.link.get("ID"),"provider":"scripts/auto_hunting/source_schedule.gd",
		"pack_sha256":SourceSchedule.PACK_SHA256,"source_zip_sha256":SourceSchedule.SOURCE_SHA256}
	move_button.set_meta("source523_image", evidence)
	move_button.set_meta("source523_image_provenance", image.get("provenance", {}).duplicate(true))
	move_button.set_meta("source523_image_status", str(image.get("status", image.get("error", "source_image_unavailable"))))

func _sync_settings() -> void:
	var value: Dictionary = world.call("auto_hunting_local_settings")
	local_enabled.set_pressed_no_signal(bool(value.enabled))
	gem_enabled.set_pressed_no_signal(bool(value.get("gem_wallet_enabled", false)))
	entry_area_enabled.set_pressed_no_signal(bool(value.get("allow_entry_area", false)))
	end_rule.select(0 if bool(value.end_inclusive) else 1)
	search_order.select(0 if value.search_order == "center_first" else 1)

func _settings_changed() -> void:
	if owner_scroll != null and world.hud.workspace.was_scroll_dragged(owner_scroll):
		_sync_settings()
		return
	var result: Dictionary = world.call("auto_hunting_set_local_settings", {"enabled": local_enabled.button_pressed,
		"end_inclusive": end_rule.selected == 0, "search_order": "center_first" if search_order.selected == 0 else "coordinate_order", "gem_wallet_enabled": gem_enabled.button_pressed, "allow_entry_area": entry_area_enabled.button_pressed})
	_sync_settings()
	_refresh_assessment()
	if not bool(result.ok): status.text = str(result.reason)

func _refresh_assessment() -> void:
	_select_landing(landings.selected)

func _move() -> void:
	if owner_scroll != null and world.hud.workspace.was_scroll_dragged(owner_scroll): return
	if selected_id < 0: return
	var entry: Dictionary = entries[selected_id]
	var index: int = landings.selected
	if index < 0 or index >= entry.destinations.size(): return
	# The world repeats all checks at activation, including occupancy and save.
	var result: Dictionary = world.call("auto_hunting_move", int(entry.schedule.ID), int(entry.destinations[index].link.ID))
	_refresh_assessment()
	status.text = str(result.get("reason", "이동 결과 확인 실패"))
