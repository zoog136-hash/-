extends VBoxContainer

## A new quest-only view; the world owns claim, currency and saving authority.
signal claim_requested(quest_id: String)

const UI = preload("res://scripts/ui/renewal_theme.gd")
const CATEGORIES = {"main":"메인", "daily":"일일", "achievement":"업적"}
var world: Node
var selected: String = "main"
var tab_buttons: Dictionary = {}
var listing: VBoxContainer
var summary: Label

func configure(owner_world: Node) -> void:
	world = owner_world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var heading := UI.section("퀘스트 · 즉시 완료", 20)
	add_child(heading)
	var hint := UI.label("퀘스트를 획득하는 즉시 보상을 수령할 수 있습니다. 목표 수행·NPC 재방문 불필요.", 12, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	add_child(tabs)
	for category: String in ["main", "daily", "achievement"]:
		var button := Button.new()
		button.text = CATEGORIES[category]
		button.custom_minimum_size = Vector2(86, 38)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_select.bind(category))
		tabs.add_child(button)
		tab_buttons[category] = button
	summary = UI.label("", 12, UI.GOLD)
	add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listing.add_theme_constant_override("separation", 7)
	scroll.add_child(listing)
	refresh()

func _select(category: String) -> void:
	selected = category
	refresh()

func _objective_text(quest: Dictionary) -> String:
	var objective: Dictionary = quest.get("objective", {})
	var target: String = str(objective.get("target", ""))
	var required: int = int(objective.get("count", 1))
	match str(objective.get("kind", "")):
		"kill": return "%s 처치 %d회" % ["보스" if target == "@boss" else ("몬스터" if target == "*" else target), required]
		"collect": return "%s 습득 %d개" % [target, required]
		"level": return "레벨 %d 달성" % required
		_: return "목표 정보 없음"

func _reward_text(quest: Dictionary) -> String:
	var reward: Dictionary = quest.get("rewards", {})
	var parts: PackedStringArray = PackedStringArray()
	if int(reward.get("adena", 0)) > 0:
		parts.append("아데나 %d" % int(reward["adena"]))
	if int(reward.get("exp", 0)) > 0:
		parts.append("EXP %d" % int(reward["exp"]))
	for raw: Variant in reward.get("items", []):
		if raw is Dictionary:
			var item: Dictionary = raw as Dictionary
			parts.append("%s ×%d" % [str(item.get("name", "")), int(item.get("quantity", 0))])
	return " · ".join(parts)

func refresh() -> void:
	if listing == null or world == null or not is_instance_valid(world):
		return
	for child: Node in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	var service: Variant = world.get("quest_service")
	if service == null:
		return
	var displayed: int = 0
	var finished: int = 0
	var entries: Array[Dictionary] = service.entries(int(world.get("level")), world.get("inventory"))
	for quest: Dictionary in entries:
		if str(quest.get("category", "")) != selected:
			continue
		displayed += 1
		if bool(quest.get("completed", false)):
			finished += 1
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.chrome_panel(Color("14130f"), UI.BRONZE, 10))
		listing.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 5)
		panel.add_child(body)
		var title := UI.section(str(quest.get("title", "")), 15)
		body.add_child(title)
		var goal: Dictionary = quest.get("objective", {})
		var objective_label := UI.label("목표  %s   ·   진행 %d/%d" % [
			_objective_text(quest), int(quest.get("progress", 0)), int(goal.get("count", 1))], 12, UI.MUTED)
		body.add_child(objective_label)
		var reward_label := UI.label("보상  " + _reward_text(quest), 12, UI.TEXT)
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(reward_label)
		var complete := Button.new()
		complete.custom_minimum_size.y = 41
		complete.add_theme_font_size_override("font_size", 13)
		var available: bool = bool(quest.get("available", false))
		var done: bool = bool(quest.get("completed", false))
		complete.disabled = done or not available
		complete.text = "완료 · 보상 수령됨" if done else ("즉시 완료 · 보상 받기" if available else "레벨 %d부터 이용" % int(quest.get("min_level", 1)))
		if not complete.disabled:
			UI.primary_button(complete)
			complete.pressed.connect(_emit_claim.bind(str(quest.get("id", ""))))
		body.add_child(complete)
	summary.text = "%s  %d/%d 완료" % [CATEGORIES[selected], finished, displayed]
	for category: String in tab_buttons:
		(tab_buttons[category] as Button).add_theme_stylebox_override("normal", UI.tab_frame(category == selected))
	if selected == "daily":
		summary.text += "  ·  매일 기기 로컬 시간 오전 %d시 초기화" % int(service.DAILY_RESET_HOUR)

func _emit_claim(quest_id: String) -> void:
	claim_requested.emit(quest_id)
