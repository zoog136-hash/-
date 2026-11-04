extends VBoxContainer
## Paginated original quest view; only the world may grant/save rewards.
signal claim_requested(quest_id: String)
const UI = preload("res://scripts/ui/renewal_theme.gd")
const CATEGORIES = {"main":"메인", "daily":"일일", "achievement":"업적", "other":"기타"}
const PAGE_SIZE = 30
var world: Node
var selected: String = "main"
var tab_buttons: Dictionary = {}
var listing: VBoxContainer
var summary: Label
var pack_status: Label
var search: LineEdit
var page: int = 0
var page_label: Label
var previous: Button
var next: Button
var picker: FileDialog
var state_filter: OptionButton

func configure(owner_world: Node) -> void:
	world = owner_world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	add_child(UI.section("퀘스트 · 획득 즉시 자동 완료",18))
	var hint := UI.label("레벨·직업·선행 조건을 충족하면 자동 완료합니다. 목표 수행·NPC 복귀는 생략합니다.",12,UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	pack_status = UI.label("",12,UI.GOLD)
	pack_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(pack_status)
	var install := Button.new()
	install.text = "최신523 퀘스트 팩 설치"
	install.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(install)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.zip;TWILIGHT 퀘스트 팩;application/zip"])
	picker.file_selected.connect(_install)
	add_child(picker)
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for category: String in CATEGORIES:
		var button := Button.new()
		button.text = CATEGORIES[category]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 35
		button.pressed.connect(_select.bind(category))
		tabs.add_child(button)
		tab_buttons[category] = button
	search = LineEdit.new()
	search.placeholder_text = "퀘스트 이름 · 원본 ID 검색"
	search.text_changed.connect(func(_value: String) -> void: page=0;refresh())
	add_child(search)
	state_filter = OptionButton.new()
	for label: String in ["전체 상태","완료","자동 처리 대기","잠김·보류·제외"]: state_filter.add_item(label)
	state_filter.item_selected.connect(func(_value: int) -> void: page=0;refresh())
	add_child(state_filter)
	summary = UI.label("",12,UI.GOLD)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	listing = VBoxContainer.new()
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(listing)
	var pages := HBoxContainer.new()
	add_child(pages)
	previous = Button.new()
	previous.text = "이전"
	previous.pressed.connect(func() -> void: page-=1;refresh())
	pages.add_child(previous)
	page_label = UI.label("",12,UI.MUTED)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(page_label)
	next = Button.new()
	next.text = "다음"
	next.pressed.connect(func() -> void: page+=1;refresh())
	pages.add_child(next)
	refresh()

func _install(path: String) -> void:
	var result: Dictionary = preload("res://scripts/quests/source_quest523.gd").install_zip(path)
	pack_status.text = "설치 완료 · 게임을 완전히 종료한 뒤 다시 실행하세요" if result.ok else str(result.error)

func _select(category: String) -> void:
	selected = category
	page = 0
	refresh()

func _reward_text(quest: Dictionary) -> String:
	var parts: PackedStringArray = []
	var alternatives: int = 0
	for reward: Dictionary in quest.get("source_rewards",[]):
		if int(reward.get("RewardEnhancementTypeID",1)) != 1:
			alternatives += 1
			continue
		var label: String = str(reward.get("source_item",{}).get("Name",reward.get("type_name","보상")))
		if reward.get("type_name") == "Exp": label = "EXP"
		if int(reward.get("CharacterClassID",0)) != 0: label += " (직업별)"
		parts.append("%s ×%d" % [label,int(reward.get("Amount",0))])
	if alternatives>0: parts.append("선택 강화 보상 %d종 · 재료 자동 사용 안 함" % alternatives)
	return " · ".join(parts) if not parts.is_empty() else "보상 없음"

func refresh() -> void:
	if listing == null or world == null or not is_instance_valid(world): return
	for child: Node in listing.get_children():
		listing.remove_child(child)
		child.queue_free()
	var service: Variant = world.get("quest_service")
	if service == null: return
	if world.get("quest_auto") != null: world.quest_auto.refresh_context(world)
	pack_status.text = "최신523 원본 %d개 · 저장된 기존 완료 이력 보존" % service.source.quests.size() if not service.source.quests.is_empty() else service.source.problem
	var rows: Array[Dictionary] = []
	var total: int = 0
	var finished: int = 0
	var available: int = 0
	var query: String = search.text.strip_edges().to_lower()
	for quest: Dictionary in service.entries(int(world.level),world.inventory):
		if not quest.has("source_id"):
			if not quest.completed: continue
			quest["status_reason"] = "기존 임시 퀘스트 완료 이력"
		if str(quest.category) != selected: continue
		total += 1
		if quest.completed: finished += 1
		elif quest.available: available += 1
		if state_filter.selected==1 and not quest.completed: continue
		if state_filter.selected==2 and (quest.completed or not quest.available): continue
		if state_filter.selected==3 and (quest.completed or quest.available): continue
		if not query.is_empty() and not (str(quest.title)+" "+str(quest.get("source_id",""))).to_lower().contains(query): continue
		rows.append(quest)
	var pages: int = maxi(1,ceili(float(rows.size())/PAGE_SIZE))
	page = clampi(page,0,pages-1)
	for index: int in range(page*PAGE_SIZE,mini(rows.size(),(page+1)*PAGE_SIZE)):
		var quest: Dictionary = rows[index]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color("14130f"),UI.BRONZE,10))
		listing.add_child(panel)
		var body := VBoxContainer.new()
		panel.add_child(body)
		var title := UI.label(str(quest.title),15,UI.GOLD)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(title)
		var description: String = "원본 ID %s · %s" % [str(quest.get("source_id","기존")),str(quest.get("type_name","이력"))]
		for goal: Dictionary in quest.get("goals",[]): description += "\n"+str(goal.get("description",goal.get("type_name","")))
		var text := UI.label(description,12,UI.MUTED)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(text)
		var reward := UI.label("보상  "+_reward_text(quest),12,UI.TEXT)
		reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(reward)
		var status_text: String = "완료 · 보상 저장됨" if quest.completed else str(quest.get("status_reason","획득 대기"))
		if quest.completed and not quest.get("rewards",{}).get("pending_use",[]).is_empty(): status_text = "완료 · 원본 보상 보관 / 일부 사용 기능 연결 대기"
		if not quest.completed and world.get("quest_auto") != null and world.quest_auto.failures.has(str(quest.id)) and quest.available: status_text = str(world.quest_auto.failures[str(quest.id)])
		var status := UI.label(status_text,12,UI.GOLD if quest.completed else UI.MUTED)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(status)
	summary.text = "%s %d개 · 완료 %d · 자동 대기 %d · 잠김/보류 %d" % [CATEGORIES[selected],total,finished,available,total-finished-available]
	page_label.text = "%d / %d 페이지 · 검색 결과 %d개" % [page+1,pages,rows.size()]
	previous.disabled = page==0
	next.disabled = page==pages-1
	for category: String in tab_buttons: tab_buttons[category].add_theme_stylebox_override("normal",UI.tab_frame(category==selected))
