extends VBoxContainer
## Production menu. Confirmation carries the exact quoted revision and nonce.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var hud
var runtime
var content: VBoxContainer
var result: Label
var confirmation: VBoxContainer
var pending: Dictionary = {}
var submitting: bool = false

func configure(owner_hud: Node) -> void:
	hud = owner_hud; runtime = hud.get_parent().half_elixir
	name = "HalfElixirView"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	result = UI.label("", 13, UI.GOLD); result.name = "HalfElixirResult"; result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result)
	var scroll := ScrollContainer.new(); scroll.name = "HalfElixirScroll"; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)
	refresh()

func text(value: String) -> void:
	var label := UI.label(value, 13, UI.TEXT); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(label)

func button(id: String, caption: String, callback: Callable, disabled: bool = false) -> Button:
	var control: Button = UI.button(caption, callback, Vector2(120, 34)); control.name = id; control.disabled = disabled; content.add_child(control)
	return control

func _action_item_identity(action: String, id: String) -> Dictionary:
	var source = runtime.source
	if source == null: return {}
	if action in ["charge", "reset"]:
		var entries: Dictionary = source.charges if action == "charge" else source.resets
		var entry: Dictionary = entries.get(id, {})
		if entry.is_empty(): return {}
		return {"row":entry.get("raw", {}), "item_class_id":int(id), "presentation_role":"half_elixir_" + action}
	if action != "extend": return {}
	var cost: Dictionary = source.costs.get(int(runtime.state.extension), {})
	if cost.is_empty(): return {}
	var currency: Dictionary = source.currencies.get(int(cost.CurrencyID), {})
	# Currency.ID is not an ItemClass. This is only the item component already
	# selected by the source provider and consumed by the existing runtime.
	if str(currency.get("raw", {}).get("Name", "")) == "Adena": return {}
	var item_class_id: int = -1
	for member: Dictionary in currency.get("members", []):
		if int(member.get("UnitID", 0)) != 4 or bool(member.get("ForGive", false)): continue
		var declared_id: int = int(member.get("ClassID", -1))
		if declared_id < 0 or (item_class_id >= 0 and item_class_id != declared_id): return {}
		item_class_id = declared_id
	if item_class_id < 0: return {}
	return {"row":source.items.get(str(item_class_id), {}), "item_class_id":item_class_id, "presentation_role":"half_elixir_extension_item_component", "source_currency_id":int(cost.CurrencyID)}

func _bind_action_icon(control: Button, action: String, id: String = "") -> void:
	control.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if control.has_meta(key): control.remove_meta(key)
	if not IMAGES.selected(): return
	var identity: Dictionary = _action_item_identity(action, id)
	if identity.is_empty(): return
	var source_row: Dictionary = identity.row
	var info: Dictionary = IMAGES.describe_item_class_row(source_row) if not source_row.is_empty() else IMAGES.describe_item_class(int(identity.item_class_id))
	control.icon = info.get("texture") as Texture2D
	control.expand_icon = true
	var evidence: Dictionary = info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_role"] = identity.presentation_role
	if identity.has("source_currency_id"): evidence["source_currency_id"] = identity.source_currency_id
	control.set_meta("source523_image", evidence)
	control.set_meta("source523_image_provenance", info.get("provenance", {}).duplicate(true))
	control.set_meta("source523_image_status", str(info.get("source_status", info.get("reason", ""))))

func refresh() -> void:
	for child: Node in content.get_children(): content.remove_child(child); child.queue_free()
	confirmation = null
	pending = {}
	button("HalfSourceInstall", "사용자 소유 523 원본 ZIP 설치", pick_source)
	runtime.source = runtime.source_for(runtime.state)
	if runtime.source == null:
		text("원본은 게임 코드에 포함되지 않습니다. 설치한 원본은 사용자 로컬에만 보관됩니다. 기존 포인트 저장은 그대로 유지됩니다.")
		return
	var source = runtime.source
	var state: Dictionary = runtime.state
	text("사용 포인트 %d · 미사용 %d · 확장 %d · 아데나 %d" % [state.points, state.points - runtime.points_used(), state.extension, hud.get_parent().gold])
	text("TWILIGHT 실행 정책: 투자 1회당 원문 보너스 1단위, 현재 확장 좌표의 상한만 적용합니다. 확률 분모와 실패 차감은 자체 설정이며 원작 확정 공식이 아닙니다.")
	var contexts := OptionButton.new(); contexts.name = "HalfContext"; contexts.add_item("지역·월드를 명시적으로 선택하세요.")
	for pair: String in source.pairs: contexts.add_item(pair)
	if source.pairs.has(state.context): contexts.select(source.pairs.find(state.context) + 1)
	content.add_child(contexts)
	contexts.item_selected.connect(func(index: int) -> void:
		if index > 0: quote(runtime.request("context", source.pairs[index - 1]), "지역·월드 문맥을 " + source.pairs[index - 1] + "로 선택합니다. 투자 중에는 초기화가 먼저 필요합니다."))
	if not source.pairs.has(state.context): return
	for id: String in source.charges:
		var item: Dictionary = source.charges[id]
		var charge: Button = button("HalfCharge_" + id, "%s 사용 · 소유 %d" % [item.name, int(hud.get_parent().inventory.get(item.name, 0))], func() -> void:
			quote(runtime.request("charge", id), "%s 1개를 소모해 원문 사용 포인트를 충전합니다. 투자 효과는 별도로 선택합니다." % item.name))
		_bind_action_icon(charge, "charge", id)
	var next: Dictionary = source.costs.get(int(state.extension), {})
	if not next.is_empty():
		var currency: Dictionary = source.currencies[int(next.CurrencyID)]
		var currency_name: String = "아데나" if str(currency.raw.get("Name", "")) == "Adena" else "퓨어 엘릭서"
		var extend: Button = button("HalfExtend", "확장 %d → %d · %s %d" % [state.extension, next.AfterExtendPoint, currency_name, next.Cost], func() -> void:
			quote(runtime.request("extend"), "확장을 시도합니다. %s %d · 자체 확률 %.2f%% · 실패 차감 %s" % [currency_name, next.Cost, 100.0 * float(next.Probability) / float(runtime.policy.probability_divisor), "있음" if runtime.policy.failure_consumes_cost else "없음"]), not source.enabled("ElixirExtend", state.context))
		_bind_action_icon(extend, "extend")
	else: text("원문 비용표의 마지막 확장 단계입니다. 이후 비용을 외삽하지 않습니다.")
	for id: String in source.resets:
		var item: Dictionary = source.resets[id]
		var reset: Button = button("HalfReset_" + id, item.name + " 사용 · 투자 초기화", func() -> void:
			quote(runtime.request("reset", id), item.name + " 1개로 투자 포인트를 돌려받습니다. 물약·확장 비용·확장 단계는 반환하거나 초기화하지 않습니다."), bool(item.get("blocked", false)))
		_bind_action_icon(reset, "reset", id)
	var selected: Dictionary = source.profile(state.context)
	var ids: Array = selected.keys(); ids.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for id: String in ids:
		var rule: Dictionary = selected[id]
		var count: int = int(state.allocations.get(id, 0))
		var effect: Dictionary = source.effect(id, 1)
		var target: String = " · " + str(rule.target) if not str(rule.target).is_empty() else ""
		var label: String = "%s%s · +%s · 비용 %d · 투자 %d/%d" % [rule.label, target, effect.value, rule.raw.Cost, count * int(rule.raw.Cost), source.cap(id, int(state.extension))]
		text(label)
		button("HalfInvest_" + id, "이 능력치에 투자 · %d포인트" % rule.raw.Cost, func() -> void: quote(runtime.request("invest", id), label + "\n미사용 포인트를 차감하고 능력치 1회분을 투자합니다."))
	text("제작·케플리샤의 다섯 결과와 실패 마일리지는 별도 제작 기능 소유입니다. 이 화면은 아이템이나 재화를 무료로 지급하지 않습니다.")
	text("PvP 전용 보너스, 암흑 상태와 마법 보호막 관통은 해당 전투 문맥이 있을 때만 계산합니다. 현재 기본 PvE 전투에 없는 대상을 임의로 만들지 않습니다.")

func quote(command: Dictionary, description: String) -> void:
	if submitting: return
	if is_instance_valid(confirmation): confirmation.queue_free()
	pending = command.duplicate(true)
	confirmation = VBoxContainer.new(); confirmation.name = "HalfConfirmation"; add_child(confirmation)
	var label := UI.label(description, 13, UI.GOLD); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; confirmation.add_child(label)
	var row := HBoxContainer.new(); confirmation.add_child(row)
	var confirm: Button = UI.button("확인", submit, Vector2(100, 36)); confirm.name = "HalfConfirm"; row.add_child(confirm)
	_bind_action_icon(confirm, str(command.get("action", "")), str(command.get("id", "")))
	var cancel: Button = UI.button("취소", func() -> void: pending.clear(); confirmation.queue_free(), Vector2(100, 36)); cancel.name = "HalfCancel"; row.add_child(cancel)

func submit() -> void:
	if submitting or pending.is_empty(): return
	submitting = true
	var command: Dictionary = pending.duplicate(true)
	var outcome: Dictionary = runtime.execute(command)
	refresh()
	result.text = str(outcome.message)
	hud.show_message(result.text)
	submitting = false
	# Choosing the context is what the original 하프 엘릭서 window needs to
	# open (it has no context picker of its own): hand back to it.
	if outcome.get("ok", false) and str(command.get("action", "")) == "context" and hud.has_method("open_half_elixir"):
		hud.call_deferred("open_half_elixir")

func pick_source() -> void:
	var dialog := FileDialog.new(); dialog.name = "HalfSourcePicker"; dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.filters = PackedStringArray(["*.zip ; 사용자 소유 523 Content ZIP"]); dialog.use_native_dialog = true
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		var outcome: Dictionary = runtime.install(path)
		refresh(); result.text = str(outcome.message); hud.show_message(result.text); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func offer_item(name_value: String) -> void:
	var action: Dictionary = runtime.item_action(name_value)
	if not action.is_empty(): quote(runtime.request(action.action, action.id), name_value + " 1개를 사용합니다. 실제 소유권과 원본 레벨 조건을 다시 확인합니다.")
