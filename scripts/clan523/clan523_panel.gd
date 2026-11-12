extends VBoxContainer
## The local 혈맹 window (world.clan523). Plain controls: the original Clan_All /
## Clan_Popup_Benefit / Clan_Popup_Join_Donate CSB windows are not in the 523
## UI add-on. Level buff icons are the original UIClanBenefit.BuffIconAssetID
## pictures when the image pack resolves them; otherwise nothing is drawn.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const Clan = preload("res://scripts/clan523/clan523.gd")
const MERCHANT_LABEL := "기란 혈맹 상인"
var hud: Node
var scroll_host: ScrollContainer
var status: Label
var body: VBoxContainer
var name_edit: LineEdit
var last_result: Dictionary = {}

func configure(owner: Node, host: ScrollContainer = null) -> void:
	hud = owner
	scroll_host = host
	name = "Clan523Panel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = UI.label("",14,UI.GOLD)
	status.name = "Clan523Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	refresh()

func world() -> Node:
	return hud.get_parent() if hud != null else null

func _label(text: String, parent: Node, size: int = 14, color: Color = UI.TEXT) -> Label:
	var label: Label = UI.label(text,size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(text: String, node_name: String, parent: Node, callback: Callable, enabled: bool = true) -> Button:
	var value: Button = UI.button(text,func() -> void:
		if scroll_host == null or hud == null or not hud.workspace.was_scroll_dragged(scroll_host): callback.call(),Vector2(0,42))
	value.name = node_name
	value.disabled = not enabled
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(value)
	if scroll_host != null and hud != null: hud.workspace.register_scroll_drag(scroll_host,value)
	return value

func _effects_text(buff: Dictionary) -> String:
	var parts: Array[String] = []
	var effects: Dictionary = buff.get("effects",{})
	for key: String in effects: parts.append("%s %+d" % [str(Clan.LABELS.get(key,key)),int(effects[key])])
	for held: Dictionary in buff.get("held",[]): parts.append("%s %d(미반영)" % [str(held.type),int(held.value)])
	return ", ".join(parts)

func _done(result: Dictionary) -> void:
	last_result = result
	if hud != null and hud.has_method("show_message"): hud.show_message(str(result.get("reason","")))
	refresh()
	status.text = str(result.get("reason",""))

func refresh() -> void:
	for child: Node in body.get_children():
		body.remove_child(child); child.queue_free()
	var host: Node = world()
	if host == null or host.get("clan523") == null:
		status.text = "게임 연결 없음"; return
	var runtime = host.clan523
	var data: Dictionary = Clan.definition()
	if not data.get("ok",false):
		status.text = "원본 혈맹 표를 읽을 수 없습니다 · "+str(data.get("problem","")); return
	var snap: Dictionary = runtime.snapshot(host)
	if not snap.has_clan:
		status.text = "혈맹 없음"
		_label("창설 조건 (원본 표): %s · %d레벨 이상 · 아데나 %d" % ["/".join(data.create_class_names),int(data.policies.CreateLevelCondition.value),int(data.policies.CreateCommission.value)],body)
		name_edit = LineEdit.new()
		name_edit.name = "Clan523Name"
		name_edit.placeholder_text = "혈맹 이름"
		name_edit.max_length = Clan.NAME_MAX
		name_edit.custom_minimum_size.y = 42
		body.add_child(name_edit)
		var quote: Dictionary = snap.create
		_button("혈맹 창설" if quote.get("ok",false) else "창설 불가 · "+str(quote.get("reason","")),"Clan523Create",body,func() -> void: _done(runtime.create(host,name_edit.text)),quote.get("ok",false))
	else:
		var next_text: String = " / 다음 레벨 %d" % int(snap.next_experience) if int(snap.next_experience) > 0 else " (최고 레벨)"
		status.text = "%s · 혈맹 레벨 %d · %s" % [str(snap.name),int(snap.level),str(data.owner_rank)]
		_label("혈맹 경험치 %d%s" % [int(snap.experience),next_text],body)
		_label("현재 혈맹 버프: %s · %s" % [str(snap.buff.get("name","")),_effects_text(snap.buff)],body,13,UI.MUTED)
		_label("혈맹 기부 (오늘 %d/%d회)" % [_count(snap.state),int(data.policies.MaxDonateCount.value)],body,15,UI.GOLD)
		for entry: Dictionary in data.donates:
			var rewards: Array[String] = []
			for reward: Dictionary in entry.rewards:
				rewards.append("%s %d" % [str(reward.name) if not str(reward.name).is_empty() else _unit_label(str(reward.unit)),int(reward.amount)])
			var quote: Dictionary = runtime.donate_quote(host,int(entry.id))
			var wallet: String = Clan.payment_wallet(entry.payment)
			_button("%s 기부 · %s %d → %s%s" % [str(entry.name),wallet,int(entry.payment.amount),", ".join(rewards),"" if quote.ok else " · "+str(quote.reason)],"Clan523Donate_%d" % int(entry.id),body,func() -> void: _done(runtime.donate(host,int(entry.id))),quote.ok)
		_label("주간 기부 보상 (기부 포인트 %d/%d)" % [int(snap.state.get("week_points",0)),int(data.policies.WeeklyMaxDonatePoint.value)],body,15,UI.GOLD)
		for row: Dictionary in data.weekly:
			var quote: Dictionary = runtime.weekly_quote(host,int(row.id))
			_button("%d 포인트 · %s %d%s" % [int(row.points),str(row.name),int(row.amount),"" if quote.ok else " · "+str(quote.reason)],"Clan523Weekly_%d" % int(row.id),body,func() -> void: _done(runtime.claim_weekly(host,int(row.id))),quote.ok)
		_button("혈맹 상인 (린 · 기란)","Clan523Merchant",body,_open_merchant)
		_button("혈맹 문장","Clan523Emblem",body,func() -> void: hud.call("_navigate","clan_emblem523"))
	_label("혈맹 레벨 혜택 (UIClanBenefit · ClanReward)",body,15,UI.GOLD)
	for level: int in range(1,int(data.max_level)+1):
		var row := HBoxContainer.new()
		body.add_child(row)
		var benefit: Dictionary = data.benefits.get(level,{})
		var image: Dictionary = IMAGES.resolve_asset_value(int(benefit.get("icon_asset_id",0))) if IMAGES.selected() and int(benefit.get("icon_asset_id",0)) > 0 else {}
		if image.get("texture") is Texture2D:
			var icon := TextureRect.new()
			icon.texture = image.texture
			icon.custom_minimum_size = Vector2(36,36)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		var text: String = "Lv.%d %s · %s" % [level,str(benefit.get("text","")),_effects_text(data.buffs.get(level,{}))]
		_label(text,row,13,UI.TEXT if level == int(snap.level) else UI.MUTED)
	_label("혈맹원·가입·전쟁·동맹·레이드·순위·혈맹 퀘스트는 온라인 전용입니다. 표에 없는 규칙은 docs/clan523_missing_rules.md",body,12,UI.MUTED)

func _count(view: Dictionary) -> int:
	var total: int = 0
	for id: Variant in view.get("donations",{}): total += int(view.donations[id])
	return total

func _unit_label(unit: String) -> String:
	return {"ClanExperience":"혈맹 경험치","ClanDonatePoint":"기부 포인트","Einasad":"아인하사드"}.get(unit,unit)

func _open_merchant() -> void:
	if hud == null: return
	hud.call("open_shop")
	var shop: Variant = hud.get("shop_view")
	if not shop is Object or not is_instance_valid(shop): return
	if shop.has_method("_open_source523") and not (shop.get("source523_panel") is Control and is_instance_valid(shop.get("source523_panel"))): shop.call("_open_source523")
	var panel: Variant = shop.get("source523_panel")
	if panel is Object and is_instance_valid(panel) and panel.has_method("focus_npc"): panel.call("focus_npc",MERCHANT_LABEL)
