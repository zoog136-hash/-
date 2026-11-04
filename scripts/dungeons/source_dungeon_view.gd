extends VBoxContainer
## Game menu view for verified dungeon declarations; actions expose actual readiness.
var world: Node
var family: OptionButton
var listing: ItemList
var details: RichTextLabel
var condition_button: Button
var import_dialog: FileDialog
var notice: Label
var reward_mode: OptionButton
var rows: Array = []
var selected: int = -1
var execution_buttons: Dictionary = {}
const FAMILIES: Array = [["tower",false],["tower",true],["orim",false],["orim",true],["special",false],["rechargers",false]]

func configure(controller: Node) -> void:
	world = controller
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tools := HBoxContainer.new()
	add_child(tools)
	family = OptionButton.new()
	family.name = "DungeonFamily"
	family.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for caption: String in ["시련의 탑 · 일반","시련의 탑 · 하드","오림의 흔적 · 일반","오림의 흔적 · 하드","특수던전","시간 충전석"]:
		family.add_item(caption)
	family.item_selected.connect(func(_index: int) -> void: _refresh())
	tools.add_child(family)
	var load_button := Button.new()
	load_button.name = "DungeonLoadPack"
	load_button.text = "자료 불러오기"
	load_button.custom_minimum_size.y = 42
	load_button.pressed.connect(_choose_pack)
	tools.add_child(load_button)
	notice = Label.new()
	notice.name = "DungeonNotice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	listing = preload("res://scripts/ui/native_touch_list.gd").new()
	listing.name = "DungeonEntries"
	listing.custom_minimum_size.y = 100
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.size_flags_stretch_ratio = 0.8
	listing.item_selected.connect(_select)
	add_child(listing)
	reward_mode = OptionButton.new()
	reward_mode.name = "DungeonRewardMode"
	reward_mode.add_item("도전 완료 보상")
	reward_mode.add_item("즉시 완료 보상")
	reward_mode.item_selected.connect(func(_index: int) -> void: _select(selected))
	add_child(reward_mode)
	details = RichTextLabel.new()
	details.name = "DungeonDetails"
	details.bbcode_enabled = false
	details.custom_minimum_size.y = 120
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 1.5
	add_child(details)
	condition_button = preload("res://scripts/ui/native_touch_button.gd").new()
	condition_button.name = "DungeonCheckEntry"
	condition_button.text = "입장 조건 확인"
	condition_button.custom_minimum_size.y = 42
	condition_button.pressed.connect(_check_entry)
	add_child(condition_button)
	var actions := HBoxContainer.new()
	actions.name = "DungeonExecutionActions"
	add_child(actions)
	for pair: Array in [["begin","도전 시작"],["immediate","즉시 완료"],["purchase","추가 횟수 구매"],["claim","보상 받기"],["leave","도전 포기"],["retry","저장 재시도"]]:
		var action: String = str(pair[0])
		var button := preload("res://scripts/ui/native_touch_button.gd").new()
		button.name = "DungeonAction_" + action
		button.text = str(pair[1])
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_perform.bind(action))
		execution_buttons[action] = button
		actions.add_child(button)
	_refresh()

func _choose_pack() -> void:
	if not is_instance_valid(import_dialog):
		import_dialog = FileDialog.new()
		import_dialog.name = "DungeonPackPicker"
		import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		import_dialog.title = "던전 자료 안내 파일 선택"
		import_dialog.filters = PackedStringArray(["manifest.json ; 던전 자료"])
		import_dialog.file_selected.connect(_install_pack)
		add_child(import_dialog)
	import_dialog.popup_centered_ratio(0.8)

func _install_pack(path: String) -> void:
	var result: Dictionary = world.install_source_dungeon_pack(path)
	_refresh()
	notice.text = "던전 자료를 불러왔습니다. 입장·전투 연결은 준비 중입니다." if bool(result.get("ok",false)) else str(result.get("reason","자료를 불러오지 못했습니다."))

func _kind() -> String:
	return str(FAMILIES[family.selected][0])

func _refresh() -> void:
	selected = -1
	listing.clear()
	details.text = ""
	rows = world.source_dungeon_entries(_kind(),bool(FAMILIES[family.selected][1]))
	reward_mode.visible = _kind() == "tower"
	condition_button.visible = _kind() != "rechargers"
	condition_button.disabled = rows.is_empty()
	for button: Button in execution_buttons.values(): button.visible = _kind() == "tower"; button.disabled = true
	if rows.is_empty():
		notice.text = "던전 자료를 불러오면 입장 조건과 보상을 확인할 수 있습니다."
		if not str(world.source_dungeons.last_error).is_empty(): notice.text += " " + str(world.source_dungeons.last_error)
		return
	notice.text = "%d개 항목 · %s" % [rows.size(),"시간 충전 연결 준비 중" if _kind() == "rechargers" else "입장·전투 연결 준비 중"]
	for entry: Dictionary in rows:
		if _kind() == "special":
			var names: Array[String] = []
			for destination: Dictionary in entry.destinations: names.append(str(destination.place.name))
			listing.add_item(" / ".join(names) if not names.is_empty() else "목적지 확인 필요")
		elif _kind() == "rechargers":
			listing.add_item(str(entry.item.name))
		else:
			listing.add_item("%d%s · %s" % [int(entry.stage.StageIndex),"층" if _kind() == "tower" else "단계",str(entry.place.name)])
	listing.select(0)
	_select(0)

func _reward_lines(rewards: Array) -> Array[String]:
	var result: Array[String] = []
	for reward: Dictionary in rewards:
		var caption := "경험치" if reward.type == "Exp" else str(reward.item.name) if reward.item is Dictionary else str(reward.type)
		if int(reward.row.ItemBlessCodeID) == 2: caption += " (축복)"
		result.append("%s × %d" % [caption,int(reward.row.Amount)])
		if reward.item is Dictionary:
			result.append_array(_deletion_lines(reward.item))
	return result

func _deletion_lines(item: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for deletion: Dictionary in item.get("deletion",[]):
		if deletion.date is Dictionary:
			var date: Dictionary = deletion.date
			result.append("  자료상 삭제 일시: %04d-%02d-%02d %02d:%02d (시간대 확인 필요)" % [int(date.Year),int(date.Month),int(date.Day),int(date.Hour),int(date.Minute)])
	return result

func _select(index: int) -> void:
	if index < 0 or index >= rows.size(): return
	selected = index
	var entry: Dictionary = rows[index]
	var lines: Array[String] = []
	if _kind() == "rechargers":
		var preview: Dictionary = world.source_dungeon_recharge_preview(int(entry.item.row.ID))
		lines.append(str(preview.item.name))
		lines.append("대상: %s · 사용 시 1시간 충전" % str(preview.group.name))
		lines.append("필요 레벨: %d" % int(preview.item.row.LevelLimitMin))
		lines.append(str(preview.use_text))
		lines.append_array(_deletion_lines(preview.item))
		lines.append(str(preview.reason))
		if bool(preview.item.row.TestItem): lines.append("테스트 아이템 정의입니다.")
	elif _kind() == "special":
		lines.append("이동 비용: %d %s" % [int(entry.teleport.TeleportCost),str(entry.currency.name)])
		for condition: Dictionary in entry.prerequisites:
			if condition.type == "MinLevel": lines.append("필요 레벨: %d" % int(condition.row.Value))
			if condition.type == "MaxLevel": lines.append("최대 레벨: %d" % int(condition.row.Value))
		for destination: Dictionary in entry.destinations:
			lines.append("목적지: " + str(destination.place.name))
			for group: Dictionary in destination.place.time_groups:
				lines.append("이용시간 그룹: " + str(group.name))
		lines.append("서버·기간·추가 입장 조건과 이동 연결을 확인 중입니다.")
	else:
		lines.append("%d%s · %s" % [int(entry.stage.StageIndex),"층" if _kind() == "tower" else "단계",str(entry.place.name)])
		lines.append("제한 시간의 실행 규칙은 확인 중입니다.")
		if _kind() == "tower":
			lines.append("필요 레벨: %d" % int(entry.stage.MinLevel))
			for goal: Dictionary in entry.goals:
				if goal.type == "AnyNpcKill": lines.append("목표: 몬스터 %d마리 처치" % int(goal.row.Amount))
				elif goal.type == "ItemCollect": lines.append("목표: %s %d개 수집" % [str(goal.item.name),int(goal.row.Amount)])
			var costs: Dictionary = world.source_dungeon_tower_cost(bool(entry.stage.IsHard))
			lines.append("입장 비용: 아인하사드 %d · 추가 도전 비용: 아인하사드 %d" % [int(costs.BaseTryCurrencyCost),int(costs.TryCurrencyCost)])
			var immediate := reward_mode.selected == 1
			if immediate:
				lines.append("즉시 완료 비용: %d %s" % [int(entry.immediate.payment.Amount),str(entry.immediate.currency.name)])
				lines.append("클리어한 층은 다음날부터 즉시 완료 가능 · 도전 중 이용 불가")
			else: lines.append("도전 중 이탈하면 실패하며 입장 비용은 환급되지 않습니다.")
			lines.append("즉시 완료 보상" if immediate else "도전 완료 보상")
			lines.append_array(_reward_lines(entry.immediate_rewards if immediate else entry.normal_rewards))
		else:
			lines.append("현재 자료에서 닫힘 상태입니다.")
			lines.append("기본 완료 보상")
			lines.append_array(_reward_lines(entry.normal_rewards))
			lines.append("행운 보상 후보 (당첨 횟수·추첨 방식 확인 중)")
			for reward: Dictionary in entry.lucky_rewards:
				lines.append_array(_reward_lines([reward]))
				lines.append("  후보 가중치: %d" % int(reward.link.Weight))
			lines.append("남은 시간별 보상 구간 · 경계와 동시 지급 조건 확인 중")
			for section: Dictionary in entry.sections:
				lines.append("%d~%d초 · 행운 횟수 %d~%d" % [int(section.row.MinRemainTimeSecond),int(section.row.MaxRemainTimeSecond),int(section.row.MinLuckyRewardCount),int(section.row.MaxLuckyRewardCount)])
				lines.append_array(_reward_lines(section.care_rewards))
			lines.append("등장 계획 · 위치·전투 연결 확인 중")
			for spawn: Dictionary in entry.spawns:
				lines.append("%d초 · 수량 설정 %d%s" % [int(spawn.Second),int(spawn.Count)," · 그룹 구성 확인 중" if int(spawn.NpcGroupID) != 0 else ""])
		lines.append("입장·전투·보상 지급 연결 준비 중입니다.")
	if _kind() == "tower":
		var run: Dictionary = world.source_dungeon_runs.state.active
		if not run.is_empty():
			lines.append("도전 상태: " + str({"active":"진행 중","cleared":"클리어 · 보상 수령 가능","failed":"실패 · 입장 비용 미환급"}.get(run.status,run.status)))
			for goal: Dictionary in entry.goals:
				lines.append("목표 진행: %d / %d" % [int(run.counts.get(str(int(goal.row.ID)),0)),int(goal.row.Amount)])
		_update_actions(entry)
	details.text = "\n".join(lines)

func _check_entry() -> void:
	if selected < 0 or selected >= rows.size(): return
	var entry: Dictionary = rows[selected]
	var identifier := int(entry.row.ID) if _kind() == "special" else int(entry.stage.ID)
	var result: Dictionary = world.source_dungeon_entry_check(_kind(),identifier)
	notice.text = " ".join(result.get("reasons",[]))


func _update_actions(entry: Dictionary) -> void:
	if world.source_dungeon_runs.busy or world.source_dungeon_runs.save_blocked:
		for button: Button in execution_buttons.values():
			button.disabled = true
			button.tooltip_text = str(world.source_dungeon_runs.problem)
		return
	var stage_id := int(entry.stage.ID)
	var normal: Dictionary = world.source_dungeon_runs.check(stage_id)
	var immediate: Dictionary = world.source_dungeon_runs.check(stage_id,true)
	execution_buttons.begin.disabled = not normal.ok
	execution_buttons.begin.tooltip_text = " ".join(normal.reasons)
	execution_buttons.immediate.disabled = not immediate.ok
	execution_buttons.immediate.tooltip_text = " ".join(immediate.reasons)
	var run: Dictionary = world.source_dungeon_runs.state.active
	execution_buttons.claim.disabled = run.is_empty() or run.get("status","") != "cleared" or int(run.get("stage_id",0)) != stage_id
	execution_buttons.leave.disabled = run.is_empty() or run.get("status","") != "active"
	execution_buttons.retry.disabled = world.pending_dungeon_events.is_empty()
	execution_buttons.purchase.disabled = world.source_dungeon_runs.context(stage_id).is_empty()

func _perform(action: String) -> void:
	if selected < 0 or selected >= rows.size() or _kind() != "tower": return
	var result: Dictionary = world.source_dungeon_action(action,int(rows[selected].stage.ID))
	_select(selected)
	notice.text = "처리를 저장했습니다." if result.get("ok",false) else str(result.get("reason"," ".join(result.get("reasons",[]))))
