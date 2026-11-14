extends VBoxContainer
## This screen reads service snapshots. Only the explicit review confirmation
## calls the authoritative service; closing or cancelling discards the quote.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const TouchButton = preload("res://scripts/ui/native_touch_button.gd")
const ScrollButton = preload("res://scripts/growth/growth_touch_button.gd")

var hud
var runtime
var snapshot: Dictionary = {}
var pending: Dictionary = {}
var selected_collection: String = ""
var tab: String = "rewards"
var submitting: bool = false
var policy_choices: bool = false
var effects_choices: bool = false
var summary: Label
var result: Label
var tabs: HBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var source_picker: FileDialog

func configure(owner_hud: Node, service) -> void:
	hud = owner_hud
	runtime = service
	name = "Growth96View"
	theme = UI.make_theme()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)
	summary = _label("", self, 13, UI.GOLD)
	summary.name = "Growth96Summary"
	result = _label("", self, 12, UI.TEXT)
	result.name = "Growth96Status"
	result.hide()
	tabs = HBoxContainer.new()
	tabs.name = "Growth96Tabs"
	add_child(tabs)
	_button("레벨 보상", "Growth96RewardsTab", func() -> void: _select_tab("rewards"), tabs)
	_button("증표 컬렉션", "Growth96CollectionsTab", func() -> void: _select_tab("collections"), tabs)
	scroll = ScrollContainer.new()
	scroll.name = "Growth96Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_deadzone = 8
	add_child(scroll)
	body = VBoxContainer.new()
	body.name = "Growth96Content"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_register_drag(body)
	_refresh()

func _label(text: String, parent: Node, font_size: int = 13, color: Color = UI.TEXT) -> Label:
	var label: Label = UI.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(text: String, node_name: String, action: Callable, parent: Node) -> Button:
	var button: Button
	if is_instance_valid(scroll) and (parent == body or body.is_ancestor_of(parent)):
		button = ScrollButton.new()
		button.scroll_host = hud.workspace if is_instance_valid(hud) else null
		button.scroll_area = scroll
	else:
		button = TouchButton.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.tooltip_text = text
	button.pressed.connect(func() -> void:
		if submitting: return
		if is_instance_valid(scroll) and (parent == body or body.is_ancestor_of(parent)) and _was_dragged(): return
		action.call())
	parent.add_child(button)
	if is_instance_valid(scroll) and (parent == body or body.is_ancestor_of(parent)): _register_drag(button)
	return button

func _register_drag(control: Control) -> void:
	if is_instance_valid(hud) and is_instance_valid(hud.workspace):
		hud.workspace.register_scroll_drag(scroll, control)

func _was_dragged() -> bool:
	return is_instance_valid(hud) and is_instance_valid(hud.workspace) and hud.workspace.was_scroll_dragged(scroll)

func _clear_body() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	snapshot = runtime.snapshot() if runtime != null else {"ready": false, "problem": "96레벨 보상 서비스가 연결되지 않았습니다."}
	_update_summary()
	_render()

func _update_summary() -> void:
	summary.text = "%d레벨 · 경험치 %.2f%% · %s %d개" % [int(snapshot.get("level", 1)), float(snapshot.get("percent", 0)), _token_name(), int(snapshot.get("token_count", 0))]

func _render() -> void:
	_clear_body()
	for button: Button in tabs.get_children():
		button.disabled = not pending.is_empty()
		button.toggle_mode = true
		button.set_pressed_no_signal((button.name == "Growth96RewardsTab") == (tab == "rewards"))
	if not pending.is_empty():
		_render_review()
		return
	if not bool(snapshot.get("ready", false)):
		_label("523 정의가 준비되지 않았습니다", body, 17, UI.GOLD)
		_label(str(snapshot.get("problem", "로컬 523 정의 ZIP을 설치하세요.")), body, 13, UI.MUTED)
		_label("개인 보관 중인 523 정의 ZIP을 선택하면 로컬에서 검사합니다. 보상 수령과 증표 등록은 설치 후 직접 확인해야 합니다.", body)
		_button("523 정의 ZIP 선택", "Growth96Install", _choose_source, body).disabled = runtime == null
		return
	_label("TWILIGHT 보상 정책: " + _policy_name(str(snapshot.get("policy", "latest_available"))), body, 13, UI.GOLD)
	_label("버전 상한을 선택하면 각 지점에서 상한 이하의 최신 선언을 사용합니다. Version 2 이하도 96레벨의 Version 0 선언을 포함합니다.", body, 12, UI.MUTED)
	_button("적용 정책 선택", "Growth96Policy", func() -> void: policy_choices = not policy_choices; _render(), body)
	if policy_choices:
		_button("지점별 최신 가용 정의", "Growth96Policy_latest_available", func() -> void: _prepare("policy", "latest_available"), body)
		for version: int in range(3):
			var policy_id: String = "cap%d" % version
			_button("이전 소스 정의 · Version %d 이하" % version, "Growth96Policy_" + policy_id, func() -> void: _prepare("policy", policy_id), body)
		_button("보상 수령 보류", "Growth96Policy_hold", func() -> void: _prepare("policy", "hold"), body)
	_label("효과 해석: " + _effects_policy_name(str(snapshot.get("effects_policy", "source_only"))), body, 13, UI.GOLD)
	_button("효과 해석 선택", "Growth96EffectsPolicy", func() -> void: effects_choices = not effects_choices; _render(), body)
	if effects_choices:
		_label(_effects_warning(), body, 12, Color("edb49b"))
		_button("원본 수치·지원 효과", "Growth96EffectsPolicy_source_only", func() -> void: _prepare("effects_policy", "source_only"), body)
		_button("TWILIGHT 자체 추정 추가", "Growth96EffectsPolicy_twilight_estimates", func() -> void: _prepare("effects_policy", "twilight_estimates"), body)
	if tab == "rewards": _render_rewards()
	else: _render_collections()

func _select_tab(value: String) -> void:
	if not pending.is_empty(): return
	# 증표 컬렉션 is the original 523 아이템 컬렉션 window when it is handled.
	if value == "collections" and hud != null and hud.has_method("item_book_available") and hud.call("item_book_available") and hud.call("open_item_book"): return
	tab = value
	policy_choices = false
	effects_choices = false
	_refresh()
	scroll.scroll_vertical = 0

func _token_name() -> String:
	var value: String = str(snapshot.get("token_name", "증표"))
	return "증표" if value.is_empty() else value

func _policy_name(value: String) -> String:
	match value:
		"latest_available": return "지점별 최신 가용 정의"
		"cap0": return "이전 소스 정의 · Version 0 이하"
		"cap1": return "이전 소스 정의 · Version 1 이하"
		"cap2": return "이전 소스 정의 · Version 2 이하"
	return "보상 수령 보류"

func _effects_policy_name(value: String) -> String:
	return "TWILIGHT 자체 추정 추가" if value == "twilight_estimates" else "원본 수치·지원 효과"

func _effects_warning() -> String:
	return "원본 수치·지원 효과는 직접 지원하는 고정 보너스와 기존 오프라인 PVP→PVE 처리를 적용합니다. 자체 추정은 미복원 비율 무시 효과를 기존 문양 전투식으로 계산하고, 대상 14를 TWILIGHT 상태 이상 4종의 명중 배율로 해석합니다. 원본 14번 대상군 판정이나 원본 전투 공식의 복원이 아닙니다."

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.DEEP, UI.BRONZE, 8))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	return column

func _render_rewards() -> void:
	_label("레벨·경험치 도달 보상", body, 17, UI.GOLD)
	_label("각 도달 지점을 선택한 뒤 지급 품목과 수량을 확인하세요. 이미 받은 보상은 다시 받을 수 없습니다.", body, 12, UI.MUTED)
	var points: Array = snapshot.get("points", [])
	if points.is_empty(): _label("설치된 정의에 표시할 보상 지점이 없습니다.", body, 13, UI.MUTED)
	for point: Dictionary in points:
		var point_id: String = str(point.get("id", ""))
		var claimed: bool = bool(point.get("claimed", false))
		var reached: bool = bool(point.get("reached", false))
		var column: VBoxContainer = _panel(body)
		_label("%d레벨 · %d%%  —  %s" % [int(point.get("level", 0)), int(point.get("percent", 0)), "수령 완료" if claimed else "수령 가능" if reached else "미도달"], column, 14, UI.GOLD if reached else UI.MUTED)
		_label(_reward_text(point), column)
		var claim: Button = _button("수령 완료" if claimed else "보상 선택 · 수령 확인", "Growth96Claim_" + point_id, func() -> void: _prepare("claim", point_id), column)
		_bind_item_icon(claim, _reward_icon_identity(point))
		claim.disabled = claimed or not reached

func _reward_icon_identity(point: Dictionary, reward_ids: Array = []) -> Dictionary:
	# A claim can contain several items. Only an unambiguous ItemClass may
	# provide the existing button's single icon; never choose a representative.
	if runtime == null: return {}
	var item_class_id: int = -1
	var source_reward_ids: Array[String] = []
	for reward: Dictionary in point.get("rewards", []):
		var reward_id: String = str(reward.get("id", ""))
		if not reward_ids.is_empty() and not reward_ids.has(reward_id): continue
		var source_reward: Dictionary = runtime.source.rewards.get(reward_id, {})
		# The source provider resolves item rewards through this exact foreign
		# key. Reward.ID itself is never an ItemClass identifier.
		if source_reward.is_empty() or int(source_reward.get("RewardTypeID", 0)) != 2 or str(source_reward.get("point_id", "")) != str(point.get("id", "")): return {}
		var declared_item_id: int = int(source_reward.get("RewardClassID", 0))
		if declared_item_id <= 0 or (item_class_id > 0 and item_class_id != declared_item_id): return {}
		item_class_id = declared_item_id
		source_reward_ids.append(reward_id)
	if item_class_id <= 0: return {}
	return {"item_class_id":item_class_id,"relation":{"source_table":"Reward","source_field":"RewardClassID","source_reward_ids":source_reward_ids,"presentation_role":"growth_reward_item"}}

func _registration_icon_identity(card_id: String) -> Dictionary:
	if runtime == null: return {}
	var card: Dictionary = runtime.source.cards.get(card_id, {})
	var requirement: Dictionary = card.get("item", {})
	if not requirement.has("ItemClassID"): return {}
	return {"item_class_id":int(requirement.ItemClassID),"relation":{"source_table":"ItemBookItem","source_id":requirement.get("ID"),"source_field":"ItemClassID","presentation_role":"registration_item_cost"}}

func _bind_item_icon(button: Button, identity: Dictionary) -> void:
	if identity.is_empty() or not IMAGES.selected(): return
	var item_class_id: int = int(identity.item_class_id)
	var source_row: Dictionary = runtime.source.items.get(str(item_class_id), {})
	var image_info: Dictionary = IMAGES.describe_item_class_row(source_row) if not source_row.is_empty() else IMAGES.describe_item_class(item_class_id)
	button.icon = image_info.get("texture") as Texture2D
	button.expand_icon = true
	var evidence: Dictionary = image_info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_relation"] = identity.relation.duplicate(true)
	button.set_meta("source523_image", evidence)
	button.set_meta("source523_image_provenance", image_info.get("provenance", {}).duplicate(true))
	button.set_meta("source523_image_status", str(image_info.get("source_status", image_info.get("reason", ""))))

func _reward_text(point: Dictionary, reward_ids: Array = []) -> String:
	var lines: Array[String] = []
	for reward: Dictionary in point.get("rewards", []):
		if not reward_ids.is_empty() and not reward_ids.has(str(reward.get("id", ""))): continue
		lines.append("%s × %d" % [str(reward.get("name", "보상")), int(reward.get("amount", 0))])
	return "\n".join(lines) if not lines.is_empty() else "지급 품목 없음"

func _render_collections() -> void:
	_label("증표 컬렉션", body, 17, UI.GOLD)
	_label("선택한 요구 카드 1개를 등록할 때마다 %s 1개를 소모합니다. 컬렉션을 완성하면 표시된 정책에 따라 효과를 적용합니다." % _token_name(), body, 12, UI.MUTED)
	var collections: Array = snapshot.get("collections", [])
	if collections.is_empty():
		_label("설치된 정의에 표시할 증표 컬렉션이 없습니다.", body, 13, UI.MUTED)
		return
	var chosen: Dictionary = {}
	for collection: Dictionary in collections:
		if str(collection.get("id", "")) == selected_collection: chosen = collection
	if chosen.is_empty():
		chosen = collections[0]
		selected_collection = str(chosen.get("id", ""))
	var selector := OptionButton.new()
	selector.name = "Growth96CollectionSelect"
	selector.custom_minimum_size.y = 44
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.clip_text = true
	body.add_child(selector)
	for collection: Dictionary in collections:
		selector.add_item("%s · %d/%d" % [str(collection.get("name", "컬렉션")), int(collection.get("registered", 0)), int(collection.get("required", 0))])
		var index: int = selector.item_count - 1
		selector.set_item_metadata(index, str(collection.get("id", "")))
		if str(collection.get("id", "")) == selected_collection: selector.select(index)
	selector.item_selected.connect(func(index: int) -> void:
		selected_collection = str(selector.get_item_metadata(index))
		_render())
	var detail: VBoxContainer = _panel(body)
	detail.name = "Growth96CollectionDetail"
	_label(str(chosen.get("name", "컬렉션")), detail, 16, UI.GOLD)
	_label("%d레벨 · 등록 %d / %d · %s" % [int(chosen.get("level", 0)), int(chosen.get("registered", 0)), int(chosen.get("required", 0)), "완성" if bool(chosen.get("complete", false)) else "미완성"], detail)
	_render_effects(chosen, detail)
	_label("요구 카드 선택 · 보유 %s %d개" % [_token_name(), int(snapshot.get("token_count", 0))], detail, 13, UI.GOLD)
	var cards: Array = chosen.get("cards", [])
	for index: int in range(cards.size()):
		var card: Dictionary = cards[index]
		var card_id: String = str(card.get("id", ""))
		var registered: bool = bool(card.get("registered", false))
		var card_name: String = str(card.get("name", "요구 카드 %d" % (index + 1)))
		var register: Button = _button("%s · %s" % [card_name, "등록 완료" if registered else "%s 1개 소모 · 등록 확인" % _token_name()], "Growth96Register_" + card_id, func() -> void: _prepare("register", card_id), detail)
		_bind_item_icon(register, _registration_icon_identity(card_id))
		register.disabled = registered or int(snapshot.get("token_count", 0)) < 1 or int(snapshot.get("level", 0)) < int(chosen.get("level", 0))
	if int(snapshot.get("token_count", 0)) < 1: _label("등록할 증표가 부족합니다.", detail, 12, UI.MUTED)
	if int(snapshot.get("level", 0)) < int(chosen.get("level", 0)): _label("이 컬렉션의 요구 레벨에 도달해야 등록할 수 있습니다.", detail, 12, UI.MUTED)

func _render_effects(collection: Dictionary, parent: Node) -> void:
	_label("완성 효과", parent, 13, UI.GOLD)
	var effects: Array = collection.get("effects", [])
	if effects.is_empty(): _label("표시된 효과 없음", parent, 12, UI.MUTED)
	for effect: Dictionary in effects:
		var estimated: bool = int((effect.get("type", {}) as Dictionary).get("UnitID",0)) == 3
		var status: String = "원문 보존 · 실행 보류" if estimated and str(snapshot.get("effects_policy","source_only")) != "twilight_estimates" else "미완성" if not bool(collection.get("complete",false)) else "96레벨 미달" if int(snapshot.get("level",0)) < 96 else "자체 추정 적용" if estimated else "적용"
		_label(str(effect.get("display", effect.get("name", "효과"))) + " · " + status, parent)
		var note: String = str(effect.get("policy_note", ""))
		if not note.is_empty(): _label(note, parent, 12, UI.MUTED)

func _prepare(action: String, id: String) -> void:
	if submitting or runtime == null or not pending.is_empty(): return
	snapshot = runtime.snapshot()
	_update_summary()
	var offer: Dictionary = runtime.quote(action, id)
	if not bool(offer.get("ok", false)):
		_set_result(str(offer.get("message", "요청을 확인할 수 없습니다.")), false)
		_render()
		return
	_set_result("",true)
	pending = {"action": action, "id": id, "revision": int(offer.get("revision", -1)), "message": str(offer.get("message", ""))}
	if action == "claim": pending["reward_ids"] = offer.get("ids", []).duplicate()
	# Preserve the exact displayed offer until confirm/cancel. A newer service
	# revision must be rejected by execute rather than silently re-quoted.
	_render()
	scroll.scroll_vertical = 0

func _render_review() -> void:
	_label("선택 내용 확인", body, 18, UI.GOLD)
	var action: String = str(pending.get("action", ""))
	var item_icon_identity: Dictionary = {}
	if action == "claim":
		for point: Dictionary in snapshot.get("points", []):
			if str(point.get("id", "")) == str(pending.id):
				item_icon_identity = _reward_icon_identity(point, pending.get("reward_ids", []))
				_label("%d레벨 · %d%% 보상 수령" % [int(point.get("level", 0)), int(point.get("percent", 0))], body, 15, UI.GOLD)
				_label("지급 품목\n" + _reward_text(point, pending.get("reward_ids", [])), body)
				_label("소모 비용 없음 · 수령 기록은 저장됩니다.", body, 12, UI.MUTED)
				_label("카드 상자는 개봉하지 않은 아이템으로 보관합니다.", body, 12, UI.MUTED)
	elif action == "register":
		for collection: Dictionary in snapshot.get("collections", []):
			for index: int in range((collection.get("cards", []) as Array).size()):
				var card: Dictionary = collection.cards[index]
				if str(card.get("id", "")) != str(pending.id): continue
				item_icon_identity = _registration_icon_identity(str(card.get("id", "")))
				_label("%s · %s" % [str(collection.get("name", "컬렉션")), str(card.get("name", "요구 카드 %d" % (index + 1)))], body, 15, UI.GOLD)
				_label("소모: %s × 1\n보유: %d개\n등록한 증표는 되돌릴 수 없습니다." % [_token_name(), int(snapshot.get("token_count", 0))], body)
				_render_effects(collection, body)
	elif action == "policy":
		_label("TWILIGHT 보상 정책\n현재: %s\n선택: %s" % [_policy_name(str(snapshot.get("policy", "latest_available"))), _policy_name(str(pending.id))], body, 14, UI.GOLD)
		_label("각 지점의 최신 가용 보상을 선택하거나, 지정한 Version 상한 이하에서 지점별 최신 선언을 선택하거나, 수령을 보류합니다. Version 2 이하도 96레벨의 Version 0을 포함합니다. 기존 지점의 수령 버전과 수령 기록은 유지됩니다.", body)
	elif action == "effects_policy":
		_label("효과 해석 선택\n현재: %s\n선택: %s" % [_effects_policy_name(str(snapshot.get("effects_policy", "source_only"))), _effects_policy_name(str(pending.id))], body, 14, UI.GOLD)
		_label(_effects_warning(), body, 13, Color("edb49b"))
		_label("두 선택 모두 컬렉션의 원본 효과 수치를 표시합니다. 자체 추정은 원본 전투 공식 복원으로 간주하지 않습니다.", body)
	elif action == "install":
		_label("523 정의 ZIP 설치", body, 15, UI.GOLD)
		_label("선택 파일: %s\n선택한 로컬 ZIP을 검증하고 개인 실행 환경에 설치합니다. 보상 수령이나 증표 등록을 자동으로 실행하지 않습니다." % str(pending.get("path", "")).get_file(), body)
	_label("이 내용으로 진행하시겠습니까?", body, 14, UI.GOLD)
	var confirm: Button = _button("확인 · 선택 내용 실행", "Growth96Confirm", _confirm, body)
	_bind_item_icon(confirm, item_icon_identity)
	_button("취소", "Growth96Cancel", func() -> void: cancel_review(), body)

func cancel_review() -> bool:
	if is_instance_valid(source_picker) and source_picker.visible:
		source_picker.hide()
		return true
	if pending.is_empty(): return false
	pending.clear()
	_set_result("취소했습니다. 선택한 내용은 실행하지 않았습니다.", true)
	_refresh()
	scroll.scroll_vertical = 0
	return true

func _confirm() -> void:
	if submitting or pending.is_empty() or runtime == null: return
	submitting = true
	var request: Dictionary = pending.duplicate(true)
	pending.clear()
	policy_choices = false
	effects_choices = false
	var response: Dictionary
	if str(request.action) == "install": response = runtime.install_source(str(request.path))
	else: response = runtime.execute(str(request.action), str(request.id), int(request.revision))
	_refresh()
	_set_result(str(response.get("message", "완료" if bool(response.get("ok", false)) else "실행 실패")), bool(response.get("ok", false)))
	call_deferred("_release_submit")

func _release_submit() -> void:
	submitting = false

func _set_result(message: String, ok: bool) -> void:
	result.text = message
	result.add_theme_color_override("font_color", UI.GOLD if ok else Color("edb49b"))
	result.visible = not message.is_empty()

func _choose_source() -> void:
	if runtime == null or not pending.is_empty(): return
	if not is_instance_valid(source_picker):
		source_picker = FileDialog.new()
		source_picker.name = "Growth96SourcePicker"
		source_picker.title = "개인 523 정의 ZIP 선택"
		source_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		source_picker.access = FileDialog.ACCESS_FILESYSTEM
		source_picker.filters = PackedStringArray(["*.zip ; ZIP 파일"])
		add_child(source_picker)
		source_picker.file_selected.connect(_source_selected)
	source_picker.popup_centered_clamped(Vector2i(680, 420), 0.9)

func _source_selected(path: String) -> void:
	if submitting or not pending.is_empty(): return
	pending = {"action": "install", "path": path, "message": "설치 결과는 로컬 ZIP 검사 후 표시됩니다."}
	_render()
	scroll.scroll_vertical = 0
