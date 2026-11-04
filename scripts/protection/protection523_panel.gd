extends VBoxContainer
const Source = preload("res://scripts/protection/protection523_source.gd")
var hud: Node
var runtime: RefCounted
var rows: Dictionary = {}
var status: Label
var summary: Label
var cards: VBoxContainer
var refresh_elapsed := 0.0
var scroll_host: ScrollContainer

func label_text(text: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func button(text: String, node_name: String, parent: Node, callback: Callable) -> Button:
	var value := Button.new()
	value.name = node_name
	value.text = text
	value.custom_minimum_size.y = 42
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.pressed.connect(func() -> void:
		if scroll_host == null or not hud.workspace.was_scroll_dragged(scroll_host): callback.call())
	parent.add_child(value)
	if scroll_host != null: hud.workspace.register_scroll_drag(scroll_host,value)
	return value

func configure(owner_hud: Node) -> void:
	hud = owner_hud
	runtime = hud.get_parent().protection523
	scroll_host = get_parent() as ScrollContainer
	name = "Protection523Panel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	label_text("원본523 · 보유 효과 / 명예 코인 사용 버프 / 제작 영구 호칭",self)
	label_text("TWILIGHT 시간 정책: 게임 종료 중에도 버프·재사용 시간이 흐릅니다." if bool(runtime.policy.get("elapsed_while_closed",true)) else "TWILIGHT 시간 정책: 실행 중에만 버프·재사용 시간이 흐릅니다.",self)
	if bool(runtime.policy.get("legacy_honor_wallet",true)): label_text("명예 코인: 검증한 기존 TWILIGHT 지갑 호환을 사용합니다. 원본3631과 수량을 합치지 않습니다.",self)
	status = label_text("",self)
	status.name = "ProtectionStatus"
	button("원본523 ZIP 설치·교체","ProtectionInstall",self,open_file)
	summary = label_text("",self)
	summary.name = "ProtectionSummary"
	var settings := HBoxContainer.new()
	add_child(settings)
	var projection := CheckButton.new()
	projection.name = "ProtectionPveProjection"
	projection.text = "TWILIGHT 전투에 PvP 수치 적용"
	projection.button_pressed = bool(runtime.state.policy.project_pvp_to_pve)
	settings.add_child(projection)
	projection.toggled.connect(func(enabled: bool) -> void:
		projection.set_pressed_no_signal(bool(runtime.state.policy.project_pvp_to_pve))
		hud.confirm_action("가호 전투 설정","원본 PvP 수치를 현재 단독 전투에 적용하는 TWILIGHT 호환 설정입니다. 원본 수치와 무관한 대상 투영만 변경합니다.","저장",func(_count: int = 1) -> void:
			show_result(runtime.set_policy(enabled,str(runtime.state.policy.same_group)))
			projection.set_pressed_no_signal(bool(runtime.state.policy.project_pvp_to_pve))))
	var group := OptionButton.new()
	group.name = "ProtectionGroupPolicy"
	group.add_item("교체: 더 강한 버프만")
	group.add_item("교체: 마지막 사용 우선")
	group.select(0 if str(runtime.state.policy.same_group) == "keep_stronger" else 1)
	add_child(group)
	group.item_selected.connect(func(index: int) -> void:
		group.select(0 if str(runtime.state.policy.same_group) == "keep_stronger" else 1)
		hud.confirm_action("가호 버프 교체","원본 Group604 비중첩을 유지합니다. 같은 그룹의 교체 순서는 TWILIGHT 설정이며, 새로 사용하면 명예 코인 10개와 해당 아이템의 1시간 재사용을 적용합니다.","저장",func(_count: int = 1) -> void:
			show_result(runtime.set_policy(bool(runtime.state.policy.project_pvp_to_pve),"keep_stronger" if index == 0 else "replace"))
			group.select(0 if str(runtime.state.policy.same_group) == "keep_stronger" else 1)))
	cards = VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation",12)
	add_child(cards)
	rebuild()
	refresh()

func rebuild() -> void:
	for child: Node in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	rows.clear()
	if runtime.source.is_empty(): return
	for item_id: int in Source.IDS:
		var d: Dictionary = runtime.source.definitions[str(item_id)]
		var card := VBoxContainer.new()
		card.name = "ProtectionCard_%d" % item_id
		cards.add_child(card)
		label_text(str(d.name),card).add_theme_font_size_override("font_size",20)
		label_text("보유: PvP 리덕션 +%d · PvP 감소 +%.2f%%\n사용: PvP 리덕션 +%d · %d분 · 재사용 %d분\n명예 코인 %d개 소모 · 가호 본체 유지" % [
			int(d.possession_flat),float(d.possession_percent_raw)/10000.0,int(d.buff_flat),int(d.duration)/60,int(d.cooldown)/60,int(d.material_amount)],card)
		var detail := label_text("",card)
		var use := button("명예 코인으로 가호 사용","ProtectionUse_%d" % item_id,card,func() -> void: request_use(item_id))
		var craft := button("원본 재료로 확정 제작","ProtectionCraft_%d" % item_id,card,func() -> void: request_craft(item_id))
		rows[str(item_id)] = {"detail":detail,"use":use,"craft":craft}
	label_text("보유 여러 단계의 합산 여부는 원문에 별도 규칙이 없어 TWILIGHT 기본값 ‘최고 단계 1개’를 사용합니다. 호칭 Group841도 하나만 적용합니다. 제작 재료는 공급 경로에서 실제로 획득해야 하며, 이 화면에서 무료 지급하지 않습니다.",cards)

func open_file() -> void:
	var picker := FileDialog.new()
	picker.name = "ProtectionSourcePicker"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.zip ; 검증된 최신523 원본"])
	picker.size = Vector2i(700,460)
	picker.file_selected.connect(func(path: String) -> void:
		var result: Dictionary = runtime.install(path)
		show_result(result)
		if bool(result.get("ok",false)): rebuild()
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	hud.get_node("Root").add_child(picker)
	picker.popup_centered()

func show_result(result: Dictionary) -> void:
	status.text = str(result.get("message","원본523 가호 설치 완료")) if bool(result.get("ok",false)) else str(result.get("error","가호 처리 실패"))
	refresh()

func request_use(item_id: int) -> void:
	var key: String = runtime.owned_key(item_id,hud.get_parent().inventory)
	var quote: Dictionary = runtime.quote_use(key)
	if not bool(quote.get("ok",false)):
		show_result(quote)
		return
	var d: Dictionary = quote.definition
	hud.confirm_action(str(d.name),"명예 코인 10개를 소모해 %d분 동안 PvP 리덕션 +%d를 얻습니다.\n가호 본체는 남고, 해당 가호는 1시간 후 다시 사용할 수 있습니다.\nGroup604의 다른 가호 버프는 교체됩니다." % [int(d.duration)/60,int(d.buff_flat)],"가호 사용",
		func(_count: int = 1) -> void: show_result(runtime.use(key)))

func request_craft(item_id: int) -> void:
	var quote: Dictionary = runtime.quote_craft(item_id)
	if not bool(quote.get("ok",false)):
		show_result(quote)
		return
	var d: Dictionary = quote.definition
	hud.confirm_action("가호 확정 제작","%s\n→ %s 1개\n캐릭터당 1회 · 이전 가호와 두루마리를 소비합니다.\n영구 호칭 일반 리덕션 +%d를 획득합니다.\n기존 일반 제작과 같은 원본 레시피 #%d입니다." % [
		" + ".join(quote.input_keys),str(d.name),int(d.title_flat),int(d.recipe.ItemCraftID)],"확정 제작",
		func(_count: int = 1) -> void: show_result(runtime.craft(item_id)))

func refresh() -> void:
	var effect: Dictionary = runtime.effects()
	summary.text = "적용: 보유 PvP 리덕션 +%d / PvP 감소 +%.2f%% · 사용 버프 +%d (%d초) · 영구 호칭 일반 리덕션 +%d" % [
		int(effect.possession_flat),float(effect.possession_percent_raw)/10000.0,int(effect.active_flat),int(effect.remaining),int(effect.title_flat)]
	if runtime.source.is_empty():
		status.text = runtime.problem
		return
	for key: String in rows:
		var item_id := int(key)
		var d: Dictionary = runtime.source.definitions[key]
		var owned: String = runtime.owned_key(item_id,hud.get_parent().inventory)
		var use: Dictionary = runtime.quote_use(owned)
		var craft: Dictionary = runtime.quote_craft(item_id)
		rows[key].use.disabled = not bool(use.get("ok",false))
		rows[key].craft.disabled = not bool(craft.get("ok",false))
		var ingredients: Array[String] = []
		for input: Dictionary in d.inputs:
			var item: Dictionary = runtime.source.items.get(str(int(input.ItemClassID)),{})
			var description: Dictionary = runtime.source.descriptions.get(str(int(item.get("IdentifiedDescID",0))),{})
			ingredients.append("%s #%d ×%d" % [description.get("Description","원본 재료"),int(input.ItemClassID),int(input.Amount)])
		rows[key].detail.text = "소지: %s · 호칭: %s\n재료: %s\n사용: %s\n제작: %s" % [
			"1개" if not owned.is_empty() else "없음·정체 확인 필요","획득" if runtime.state.titles.has(int(d.title.ID)) else "미획득",
			" + ".join(ingredients),"가능" if bool(use.get("ok",false)) else use.get("error",""),
			"가능" if bool(craft.get("ok",false)) else craft.get("error","")]

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 1.0 and is_instance_valid(hud):
		refresh_elapsed = 0.0
		refresh()
