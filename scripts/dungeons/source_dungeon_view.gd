extends VBoxContainer
## Game menu view for verified dungeon declarations; actions expose actual readiness.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
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
var local_toggle: CheckButton
var local_time_scale: SpinBox
var play_panel: VBoxContainer
var play_status: Label
var play_buttons: Dictionary = {}
var play_settings_dialog: AcceptDialog
var play_settings_text: TextEdit
const FAMILIES: Array = [["tower",false],["tower",true],["orim",false],["orim",true],["special",false],["rechargers",false]]
const SourceResultRoles=preload("res://scripts/ui/original_ui/source_result_role_contract.gd")
var source_ui_pack: RefCounted

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
	var adaptation := HBoxContainer.new()
	add_child(adaptation)
	local_toggle = CheckButton.new()
	local_toggle.name = "DungeonLocalAdaptation"
	local_toggle.text = "TWILIGHT 현재 지역 도전 · 자체 규칙"
	local_toggle.tooltip_text = "현재 지역에서 처치·수집합니다. 원본 전용 맵·시즌·서버·상자 배치의 복원이 아닙니다. 보상은 인벤토리로 지급하며 일일 기준은 기존 게임의 한국시간 05시입니다."
	local_toggle.button_pressed = bool(world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).enabled)
	adaptation.add_child(local_toggle)
	var scale_label := Label.new()
	scale_label.text = "제한시간 배율(자체)"
	adaptation.add_child(scale_label)
	local_time_scale = SpinBox.new()
	local_time_scale.name = "DungeonLocalTimeScale"
	local_time_scale.min_value = 1; local_time_scale.max_value = 10; local_time_scale.step = 1
	local_time_scale.value = int(world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).time_scale)
	adaptation.add_child(local_time_scale)
	local_toggle.toggled.connect(func(_value: bool) -> void: _save_local_settings())
	local_time_scale.value_changed.connect(func(_value: float) -> void: _save_local_settings())
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
	_build_play_panel()
	_refresh()

func select_existing_family(kind: String, hard: bool=false) -> Dictionary:
	# A source UI shortcut selects an existing filter only. The current
	# refresh retains its own row-default policy; no run/settings/save here.
	var index: int=FAMILIES.find([kind,hard])
	if index<0:return {"ok":false,"code":"source_dungeon_existing_family_required"}
	if not is_instance_valid(world) or not is_instance_valid(family) or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree() or family.item_count!=FAMILIES.size():return {"ok":false,"code":"source_dungeon_live_family_selector_required"}
	if family.selected!=index:
		family.select(index)
		family.emit_signal("item_selected",index)
	return {"ok":true,"family":kind,"hard":hard,"existing_filter_selected":true,"entry_requested":false,"game_state_written":false}

func original_selected_special_entrance() -> Dictionary:
	if not is_instance_valid(world) or not is_inside_tree() or is_queued_for_deletion() or not is_visible_in_tree() or not is_instance_valid(family) or family.selected<0 or family.selected>=FAMILIES.size() or family.item_count!=FAMILIES.size() or _kind()!="special" or selected<0 or selected>=rows.size():return {"ok":false,"code":"source_special_actual_visible_selection_required"}
	var entry: Variant=rows[selected]
	var raw: Variant=entry.get("row") if entry is Dictionary else null
	if not raw is Dictionary or not SourceResultRoles._positive(raw.get("ID")) or not SourceResultRoles._positive(raw.get("EntranceAssetID")):return {"ok":false,"code":"source_special_selected_original_row_required"}
	var matches: Array=[]
	for current: Dictionary in world.source_dungeon_entries("special",false):
		if current.get("row",{}).get("ID")==raw.ID:matches.append(current)
	if matches.size()!=1 or matches[0].get("row")!=raw:return {"ok":false,"code":"source_special_selected_original_row_changed"}
	return {"ok":true,"special_dungeon_id":int(raw.ID),"entrance_asset_id":int(raw.EntranceAssetID),"actual_selected_entry":entry.duplicate(true),"selected_index":selected,"role":"SpecialDungeon.EntranceAssetID","original_ui_target":SourceResultRoles.special_entrance_target(source_ui_pack),"selection_basis":"existing rows[selected] and unique current world.source_dungeon_entries(special,false) row","first_entry_chosen":false,"game_state_written":false,"pixels_assigned":false}

func _build_play_panel() -> void:
	play_panel=VBoxContainer.new();play_panel.name="DungeonExtendedPlay";add_child(play_panel)
	play_status=Label.new();play_status.name="DungeonPlayStatus";play_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;play_panel.add_child(play_status)
	var row:=HBoxContainer.new();play_panel.add_child(row)
	for pair: Array in [["settings","자체 실행 설정"],["begin","현재 지역에서 시작"],["claim","보상 받기"],["stop","종료 / 정산 폐기"],["recharge","충전석 사용"],["buy_charge","자체 충전석 구입"],["retry","저장 재시도"],["cancel","미실행 저장 취소"]]:
		var action:=str(pair[0]);var button:=Button.new();button.text=str(pair[1]);button.name="DungeonPlay_"+action;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(_play_action.bind(action));row.add_child(button);play_buttons[action]=button
	var buffs:=HBoxContainer.new();buffs.name="OrimPreparation";play_panel.add_child(buffs)
	for pair: Array in [[71672,"가속 20만"],[71682,"용기 30만"],[71692,"진주 50만"],[72362,"증표 강화 20다이아"],[0,"자체 능력 재선택"]]:
		var button:=Button.new();button.text=str(pair[1]);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.set_meta("source_orim_buff_id",int(pair[0]));button.expand_icon=true
		button.pressed.connect(func()->void:
			var result: Dictionary=world.dungeon_play.reroll() if int(pair[0])==0 else world.dungeon_play.buy_buff(int(pair[0]))
			_update_play();notice.text="강화를 저장했습니다." if result.get("ok",false) else str(result.get("reason","실패")))
		buffs.add_child(button)

func _update_play() -> void:
	play_panel.visible=_kind() in ["orim","special","rechargers"]
	if not play_panel.visible:return
	var service: RefCounted=world.dungeon_play
	play_status.text="TWILIGHT 자체 규칙 · 원본 시즌/지도 미복원 · "+service.status_text()
	play_buttons.begin.visible=_kind() in ["orim","special"]
	play_buttons.recharge.visible=_kind()=="rechargers"
	play_buttons.buy_charge.visible=_kind()=="rechargers"
	play_buttons.buy_charge.text="자체 충전석 %d아데나" % int(service.state.settings.recharger_price)
	play_buttons.buy_charge.disabled=not service.check_idle().is_empty() or rows.is_empty()
	play_buttons.begin.disabled=not service.check_idle().is_empty() or rows.is_empty()
	play_buttons.recharge.disabled=not service.check_idle().is_empty() or rows.is_empty()
	play_buttons.claim.disabled=service.state.active.is_empty() or service.state.active.get("status","")!="cleared" or service.save_blocked
	play_buttons.stop.disabled=service.state.active.is_empty() or service.save_blocked
	play_buttons.retry.disabled=service.pending.is_empty() or service.save_blocked
	play_buttons.cancel.visible=not service.pending.is_empty();play_buttons.cancel.disabled=service.save_blocked
	play_panel.get_node("OrimPreparation").visible=_kind()=="orim"
	for button: Button in play_panel.get_node("OrimPreparation").get_children():
		button.disabled=service.state.active.is_empty() or service.state.active.get("kind","")!="orim" or service.state.active.get("status","")!="active"
		_set_orim_buff_icon(button,service)
	if _kind()=="special" and selected>=0:
		for target: Dictionary in rows[selected].destinations:
			for group: Dictionary in target.place.time_groups:
				var p: Dictionary=service.pool(int(group.row.ID),int(Time.get_unix_time_from_system()))
				play_status.text+=" · %s 기본%d/충전%d초" % [str(group.name),int(p.base),int(p.bonus)]

func _set_orim_buff_icon(button: Button, service: RefCounted) -> void:
	button.icon=null
	for key: String in ["source523_image","source523_image_provenance","source523_image_status"]:
		if button.has_meta(key):button.remove_meta(key)
	var buff_id: int=int(button.get_meta("source_orim_buff_id",0))
	# Zero is the existing host reroll action, not a source buff or icon.
	if buff_id<=0 or not IMAGES.selected():return
	var matches: Array=[]
	var declarations: Variant=service.rules.data.get("declarations",{}).get("OrimsTrailBuff",[])
	if declarations is Array:
		for row: Variant in declarations:
			if row is Dictionary and row.get("BuffClassID")==buff_id:matches.append(row)
	var reason: String="source_orim_buff_declaration_missing" if matches.is_empty() else "source_orim_buff_declaration_ambiguous"
	var image: Dictionary={"ok":false,"status":reason,"reason":reason,"texture":null,"provenance":{},"actual_game_consumption_observed":false}
	if matches.size()==1:
		# buy_buff consumes this exact declaration field in BuffClass space.
		# Resolve the canonical BuffClass ON role without manufacturing a row.
		image=IMAGES.resolve_consumer("BuffClass",buff_id,"OnIconID")
	var source_rows: Array=[]
	for row: Dictionary in matches:
		source_rows.append({"source_table":"OrimsTrailBuff","source_id":row.get("ID"),"source_field":"BuffClassID","source_value":row.get("BuffClassID")})
	var provenance: Dictionary=image.get("provenance",{}).duplicate(true)
	provenance["orim_preparation_relation"]={"source_archive_sha256":service.rules.SOURCE_SHA256,"dungeon_payload_sha256":service.rules.PAYLOAD_SHA256,"requested_buff_class_id":buff_id,"source_rows":source_rows}
	image["provenance"]=provenance
	button.icon=image.get("texture") as Texture2D
	var evidence: Dictionary=image.duplicate(true);evidence.erase("texture")
	button.set_meta("source523_image",evidence)
	button.set_meta("source523_image_provenance",provenance)
	button.set_meta("source523_image_status",str(image.get("status",image.get("reason",""))))

func _play_action(action: String) -> void:
	if action=="settings":
		if not is_instance_valid(play_settings_dialog):
			play_settings_dialog=AcceptDialog.new();play_settings_dialog.title="TWILIGHT 자체 던전 규칙 · 원본값과 별도";play_settings_dialog.min_size=Vector2i(680,520);add_child(play_settings_dialog)
			var content:=VBoxContainer.new();play_settings_dialog.add_child(content)
			var label:=Label.new();label.text="enabled 실행 허용 / entry_* 입장재화(1아데나,4다이아,174아인)·비용\ncare: timeout/always/off · replacement 복원추첨 · preserve_items 자체 만료 보존\ncarry_bonus 충전시간 이월 · zero_cap 0상한 자체값 · specific_daily 미확인주기 일일대체\nduration 실행초 / live_limit 대체형 상한 / group_size 그룹 자체크기\nspeed_percent·pearl_percent 자체 속도 / token_chance 자체 증표 드랍률\nreroll_currency·reroll_percent 자체 재선택 · 기존 게임 한국시간05시 유지\n맵 이동 없음. 특수 시간은 접속종료 중에도 차감. 설정 변경은 실행 종료 후.";content.add_child(label)
			play_settings_text=TextEdit.new();play_settings_text.custom_minimum_size=Vector2(650,300);play_settings_text.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(play_settings_text)
			play_settings_dialog.confirmed.connect(func()->void:
				var parser:=JSON.new();var result: Dictionary={"ok":false,"reason":"설정 JSON 형식 오류"}
				if parser.parse(play_settings_text.text)==OK and parser.data is Dictionary:result=world.dungeon_play.configure_settings(parser.data)
				_update_play();notice.text="자체 설정을 저장했습니다." if result.get("ok",false) else str(result.get("reason","저장 실패")))
		play_settings_text.text=JSON.stringify(world.dungeon_play.state.settings,"\t")
		play_settings_dialog.popup_centered();return
	if selected<0 or selected>=rows.size():return
	var service: RefCounted=world.dungeon_play;var result: Dictionary
	match action:
		"begin":result=service.begin(_kind(),int(rows[selected].stage.ID) if _kind()=="orim" else int(rows[selected].row.ID))
		"claim":result=service.claim()
		"stop":result=service.stop()
		"recharge":result=service.recharge(int(rows[selected].item.row.ID))
		"buy_charge":result=service.buy_recharger(int(rows[selected].item.row.ID))
		"retry":service.tick(1.0);result={"ok":service.pending.is_empty(),"reason":service.problem if not str(service.problem).is_empty() else "저장 실패 · 기존 상태 보존"}
		"cancel":result=service.cancel_pending()
		_:result={"ok":false,"reason":"알 수 없는 작업"}
	_update_play();notice.text="처리를 저장했습니다." if result.get("ok",false) else str(result.get("reason","실패"))

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
	local_toggle.get_parent().visible=_kind()=="tower"
	listing.clear()
	_set_recharger_icons({})
	details.text = ""
	rows = world.source_dungeon_entries(_kind(),bool(FAMILIES[family.selected][1]))
	reward_mode.visible = _kind() == "tower"
	condition_button.visible = _kind() != "rechargers"
	condition_button.disabled = rows.is_empty()
	for button: Button in execution_buttons.values(): button.visible = _kind() == "tower"; button.disabled = true
	if rows.is_empty():
		notice.text = "던전 자료를 불러오면 입장 조건과 보상을 확인할 수 있습니다."
		if not str(world.source_dungeons.last_error).is_empty(): notice.text += " " + str(world.source_dungeons.last_error)
		_update_play();return
	notice.text = "%d개 항목 · %s" % [rows.size(),"시간 충전 연결 준비 중" if _kind() == "rechargers" else "입장·전투 연결 준비 중"]
	for entry: Dictionary in rows:
		if _kind() == "special":
			var names: Array[String] = []
			for destination: Dictionary in entry.destinations: names.append(str(destination.place.name))
			listing.add_item(" / ".join(names) if not names.is_empty() else "목적지 확인 필요")
		elif _kind() == "rechargers":
			var visual: Dictionary = IMAGES.describe_item_class_row(entry.item.row,str(entry.item.name))
			var icon: Texture2D = visual.get("texture") as Texture2D
			var index: int = listing.add_item(str(entry.item.name),icon)
			if IMAGES.selected():
				var evidence: Dictionary = visual.duplicate(true)
				evidence.erase("texture")
				listing.set_item_metadata(index,{"source523_image":evidence})
		else:
			listing.add_item("%d%s · %s" % [int(entry.stage.StageIndex),"층" if _kind() == "tower" else "단계",str(entry.place.name)])
	listing.select(0)
	_select(0)

func _set_recharger_icons(item_row: Dictionary, title: String = "") -> void:
	var visual: Dictionary = IMAGES.describe_item_class_row(item_row,title) if not item_row.is_empty() and IMAGES.selected() else {}
	var icon: Texture2D = visual.get("texture") as Texture2D
	for action: String in ["recharge","buy_charge"]:
		var button: Button = play_buttons[action]
		button.icon = icon
		button.expand_icon = true
		if not visual.is_empty():
			var evidence: Dictionary = visual.duplicate(true)
			evidence.erase("texture")
			button.set_meta("source523_image",evidence)
		elif button.has_meta("source523_image"):
			button.remove_meta("source523_image")

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
		_set_recharger_icons(preview.item.row,str(preview.item.name))
		lines.append(str(preview.item.name))
		lines.append("대상: %s · 사용 시 1시간 충전" % str(preview.group.name))
		lines.append("필요 레벨: %d" % int(preview.item.row.LevelLimitMin))
		lines.append(str(preview.use_text))
		lines.append_array(_deletion_lines(preview.item))
		lines.append(str(preview.reason))
		if world.dungeon_play.state.settings.enabled:
			var pool: Dictionary=world.dungeon_play.pool(int(preview.group.row.ID),int(Time.get_unix_time_from_system()))
			lines.append("TWILIGHT 자체 풀 적용 · 기본 %d초 / 충전 %d초 · 별도 상한·이월 설정 사용" % [int(pool.base),int(pool.bonus)])
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
		lines.append("원본 전용 실행 규칙과 TWILIGHT 자체 실행은 구분됩니다.")
		if _kind() == "tower":
			if bool(world.LOCAL_TOWER.settings(world.source_dungeon_runs.state).enabled):
				lines.append("TWILIGHT 자체 도전 · 현재 지역의 몬스터/보스 사용 · 원본 맵 이동 없음")
				lines.append("층 선택 자유 · 시즌 제한 없음 · 인벤토리 정산 · 한국시간 05시 일일 기준")
				lines.append("수집층: 처치 시 목표물 1개 바닥 생성 · 원본 상자 배치 미복원")
				lines.append("제한 시간: %d초 · 자체 배율 %d · 종료 시각은 재접속 중에도 경과" % [int(entry.stage.TimeLimit)*int(local_time_scale.value),int(local_time_scale.value)])
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
		lines.append("원본 전용 던전의 이동·전투와 별도로 자체 실행을 사용할 수 있습니다.")
	if _kind() == "tower":
		var run: Dictionary = world.source_dungeon_runs.state.active
		if not run.is_empty():
			if run.get("host_kind","") == "twilight_local" and run.status == "active": lines.append("현재 지역 도전 남은 시간: %d초" % maxi(0,int(run.local_deadline)-int(Time.get_unix_time_from_system())))
			lines.append("도전 상태: " + str({"active":"진행 중","cleared":"클리어 · 보상 수령 가능","failed":"실패 · 입장 비용 미환급"}.get(run.status,run.status)))
			for goal: Dictionary in entry.goals:
				lines.append("목표 진행: %d / %d" % [int(run.counts.get(str(int(goal.row.ID)),0)),int(goal.row.Amount)])
		_update_actions(entry)
	if _kind()=="orim":
		var run: Dictionary=world.dungeon_play.state.active
		if not run.is_empty() and run.get("kind","")=="orim" and run.get("status","")=="cleared" and int(run.stage_id)==int(entry.stage.ID):
			var payout: Array[String]=["TWILIGHT 확정 정산 목록 · 원본 날짜와 별도 보존 여부는 자체 설정에 따름"]
			for reward: Dictionary in run.rewards:
				var id:=int(reward.row.RewardClassID)
				var caption: String=("" if id in [3631,3252,3242,246058] else "TWILIGHT · ")+str(reward.item.name)+(" (축복)" if int(reward.row.ItemBlessCodeID)==2 else "")
				payout.append("%s × %d" % [caption,int(reward.row.Amount)])
			lines=payout+["원본 선언 참고"]+lines
	details.text = "\n".join(lines)
	_update_play()

func _save_local_settings() -> void:
	var result: Dictionary = world.configure_source_dungeon_local(local_toggle.button_pressed,int(local_time_scale.value))
	var stored: Dictionary = world.LOCAL_TOWER.settings(world.source_dungeon_runs.state)
	local_toggle.set_pressed_no_signal(bool(stored.enabled))
	local_time_scale.set_value_no_signal(float(stored.time_scale))
	if selected >= 0: _select(selected)
	notice.text = "현재 지역 도전 설정을 저장했습니다." if result.get("ok",false) else str(result.get("reason","설정 저장 실패"))

func _check_entry() -> void:
	if selected < 0 or selected >= rows.size(): return
	var entry: Dictionary = rows[selected]
	var identifier := int(entry.row.ID) if _kind() == "special" else int(entry.stage.ID)
	var result: Dictionary = world.source_dungeon_entry_check(_kind(),identifier)
	notice.text = " ".join(result.get("reasons",[]))


func _update_actions(entry: Dictionary) -> void:
	var local_settings: Dictionary = world.LOCAL_TOWER.settings(world.source_dungeon_runs.state)
	local_toggle.set_pressed_no_signal(bool(local_settings.enabled))
	local_time_scale.set_value_no_signal(float(local_settings.time_scale))
	var active: Dictionary = world.source_dungeon_runs.state.active
	var locked: bool = not active.is_empty() and active.get("status","") in ["active","cleared"]
	local_toggle.disabled = locked
	local_time_scale.editable = not locked
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
