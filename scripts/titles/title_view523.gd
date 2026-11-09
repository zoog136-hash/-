extends ScrollContainer
const UI=preload("res://scripts/ui/renewal_theme.gd")
const IMAGES=preload("res://scripts/ui/source523_image_assets.gd")
var runtime
var hud
var column: VBoxContainer
var status: Label
var outcome: Label
var picker: OptionButton
var confirm: PanelContainer
var confirm_text: Label
var confirm_ok: Button
var confirm_cancel: Button
var details: VBoxContainer
var reviewed_route: String=""
var reviewed_revision: int=-1
var refresh_clock: float=0.0
var personal_open: bool=false
var personal_box: VBoxContainer
var personal_slot: OptionButton
var personal_text: LineEdit
var personal_color: OptionButton
var personal_preview: Label
var personal_notice: Label

func configure(owner_hud: Node) -> void:
	hud=owner_hud; runtime=hud.get_parent().titles
	name="Title523View"
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",10); add_child(column)
	confirm=PanelContainer.new(); confirm.name="TitleReviewPanel"; column.add_child(confirm)
	var review_box:=VBoxContainer.new(); confirm.add_child(review_box)
	confirm_text=Label.new(); confirm_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; review_box.add_child(confirm_text)
	confirm_ok=Button.new(); confirm_ok.text="확인 · 심사"; confirm_ok.custom_minimum_size=Vector2(0,44); confirm_ok.name="TitleConfirm"
	confirm_cancel=Button.new(); confirm_cancel.text="취소"; confirm_cancel.custom_minimum_size=Vector2(0,44); confirm_cancel.name="TitleCancel"
	for control: Button in [confirm_ok,confirm_cancel]:
		control.set_script(preload("res://scripts/growth/growth_touch_button.gd")); control.scroll_host=hud.workspace; control.scroll_area=self; review_box.add_child(control)
	confirm_ok.pressed.connect(_confirmed)
	confirm_cancel.pressed.connect(_cancelled)
	confirm.hide()
	build()

func label(text: String) -> Label:
	var item:=Label.new(); item.text=text; item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(item); return item

func button(text: String, action: Callable, id: String) -> Button:
	var item:=Button.new(); item.text=text; item.name=id; item.custom_minimum_size=Vector2(0,44); item.pressed.connect(action)
	item.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
	item.scroll_host=hud.workspace; item.scroll_area=self
	column.add_child(item)
	return item

func _bind_donation_icon(control: Button, enabled: bool = true) -> void:
	control.icon=null
	for key: String in ["source523_image","source523_image_provenance","source523_image_status"]:
		if control.has_meta(key): control.remove_meta(key)
	if not enabled or not IMAGES.selected(): return
	# The existing donation service consumes this exact source ItemClass
	# record. SubTitle, quest and Currency IDs do not become item identities.
	var record: Dictionary=runtime.source.powder_record
	var source_row: Dictionary=record.get("source_item_row",{})
	var image_info: Dictionary={}
	if not source_row.is_empty(): image_info=IMAGES.describe_item_class_row(source_row)
	elif IMAGES.recognized_item(record): image_info=IMAGES.describe_item_class(IMAGES.item_class_id(record))
	if image_info.is_empty(): return
	control.icon=image_info.get("texture") as Texture2D
	control.expand_icon=true
	var evidence: Dictionary=image_info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_role"]="donation_item_cost"
	control.set_meta("source523_image",evidence)
	control.set_meta("source523_image_provenance",image_info.get("provenance",{}).duplicate(true))
	control.set_meta("source523_image_status",str(image_info.get("source_status",image_info.get("reason",""))))

func build(message: String="") -> void:
	for child: Node in column.get_children():
		if child==confirm: continue
		column.remove_child(child)
		child.queue_free()
	confirm.hide()
	_bind_donation_icon(confirm_ok,false)
	label("아덴 왕실 · 작위")
	status=label("")
	outcome=label(message)
	if not runtime.source.problem.is_empty():
		label(runtime.source.problem); button("원본523 ZIP 설치",_choose_source,"InstallTitle523"); return
	label("85레벨부터 · 목표 24시간 · 일반 심사 하루 10회")
	var stage: Dictionary=runtime.next_stage()
	if not stage.is_empty():
		label("다음 작위: %s · 기부 가루 %d개"%[stage.name,stage.cost])
		label("성공률: 기부 %.1f%% · 일반 %.1f%% (TWILIGHT 자체 정책)"%[float(stage.probability_raw)*100.0/float(runtime.policy.donation_denominator),float(runtime.policy.quest_success_percent)])
		picker=OptionButton.new(); picker.name="TitleTrialPicker"; picker.custom_minimum_size=Vector2(0,44); picker.clip_text=true; column.add_child(picker)
		for id: int in stage.quests:
			var q: Dictionary=runtime.source.quests[id]
			var access: String=runtime.trial_access(id,runtime.now())
			picker.add_item("%s · 직접 막타 %d회%s"%[q.name,q.amount,"" if access.is_empty() else " · "+access],id)
			picker.set_item_disabled(picker.item_count-1,not access.is_empty())
		var revision:=int(runtime.state.revision)
		button("선택 목표 시작",func() -> void: show_result(runtime.start_trial(picker.get_selected_id(),revision)),"StartTitleTrial")
		button("현재 목표 포기",func() -> void: show_result(runtime.abandon(revision)),"AbandonTitleTrial")
		button("일반 심사 검토",func() -> void: review("quest"),"ReviewTitleQuest")
		var donation_review: Button=button("기부 심사 검토",func() -> void: review("donation"),"ReviewTitleDonation")
		_bind_donation_icon(donation_review)
	if not runtime.state.achieved.is_empty():
		var revision:=int(runtime.state.revision)
		button("호칭 표시: "+("켜짐" if runtime.state.display else "꺼짐"),func() -> void: show_result(runtime.toggle_display(revision)),"ToggleTitleDisplay")
	build_personal()
	var benefits: Dictionary=runtime.totals()
	label("달성 누적 혜택")
	if benefits.is_empty(): label("아직 달성한 작위가 없습니다.")
	for kind: String in benefits:
		var connected:=kind in ["ArmorClass","MagicResist","MeleeDamage","RangeDamage","MagicDamage","MeleeHit","RangeHit","MagicHit","SpecialResistance","HitSpecialResistance"]
		label("%s: %s · %s"%[runtime.effect_label(kind),str(benefits[kind]),"실제 전투 반영" if connected else "자체 전투 정책으로 실행 · 원본 값 보존"])
	button("규칙과 자체 정책 보기",func() -> void: details.visible=not details.visible,"TitleRules")
	details=VBoxContainer.new(); column.add_child(details); details.hide()
	var notes: Array[String]=[
		"원본: 순차 승급 ·85레벨 ·선택 목표24시간 ·일반10회/일 ·기부 횟수 제한 없음. 가루의 창고 보관·거래 불가와 최대 스택을 유지합니다.",
		"TWILIGHT 정책: 캐릭터별 저장 ·모든 후보 중1개 선택 ·직접 막타만 집계 ·한국 %02d시 초기화. 원본 기부 Probability의 자체 분모%d, 일반 심사 자체 성공률%.1f%%. 실행 정책은 원본 확정값이 아닙니다."%[(int(runtime.policy.reset_hour_utc)+9)%24,int(runtime.policy.donation_denominator),float(runtime.policy.quest_success_percent)],
		"전투 자체 정책: PvP 혜택의 NPC 적용 %s ·무기 막기 물리 피해 잔여%.0f%% ·결정타 기본%.2f배+원본 추가 배율. 원본 무기 성분·결정타 기본 공식은 미확정입니다."%[str(runtime.policy.pvp_bonus_in_pve),float(runtime.policy.weapon_block_remaining_damage_scale)*100.0,float(runtime.policy.final_blow_base_multiplier)],
		"가루 원본 드롭%d행: 정확한 NPC·일반 축복·퀘스트0만 연결 ·자체%.1f%%/1개 ·바닥 습득을 거칩니다."%[runtime.source.powder_drop_rows.size(),float(runtime.policy.powder_drop_percent)],
		"원본 일정·서버 제한도 검사합니다. 오프라인 자체 신원 %s/%d, 일정 자체 시간대 UTC%+.1f시간 ·마지막 분 포함."%[runtime.policy.offline_source_service_region,int(runtime.policy.offline_source_world_no),float(runtime.policy.source_calendar_utc_offset_seconds)/3600.0],
		"일반 퀘스트·혈맹·공성을 요구하지 않습니다. 원본 대상 NPC와 가루의 실제 공급이 없으면 진행되지 않습니다. 개인 호칭은 캐릭터별 저장이며 네트워크 계정 공유는 없습니다."
	]
	for note: String in notes:
		var line:=Label.new(); line.text=note; line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.add_child(line)
	if not runtime.state.last_result.is_empty():
		var result: Dictionary=runtime.state.last_result
		var last_text:=Label.new(); last_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		last_text.text="마지막 심사 원본 안내 · 문구 순환과 모험가 호칭은 자체 표시 정책\n"+runtime.source.result_text(int(result.get("stage",0)),bool(result.get("success",false)),int(runtime.state.revision))
		details.add_child(last_text)
	button("원본523 ZIP 다시 설치",_choose_source,"InstallTitle523").reparent(details)
	scroll_vertical=0
	refresh_status()

func build_personal() -> void:
	personal_text=null
	button("개인 호칭 편집 · 남작I부터",func() -> void:
		personal_open=not personal_open; personal_box.visible=personal_open
		if personal_open: reveal_personal(),"OpenPersonalTitle")
	personal_box=VBoxContainer.new(); personal_box.name="PersonalTitleEditor"; column.add_child(personal_box); personal_box.visible=personal_open
	var note:=Label.new(); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.text="원본: 남작I부터 보관5개 ·색상8개는 각각 추가 작위 조건 ·표시 변경2초 대기. 영문·숫자2~16자, 한글·특수1~8자. 혼합은 자체 정책1~8 Unicode 문자입니다. 계정 공유는 없습니다."
	personal_box.add_child(note)
	if not runtime.personal.unlocked(runtime.state):
		var locked:=Label.new(); locked.text="남작I를 달성하면 편집할 수 있습니다."; personal_box.add_child(locked); return
	var saved: Dictionary=runtime.personal.data(runtime.state)
	personal_slot=OptionButton.new(); personal_slot.name="PersonalSlot"; personal_slot.custom_minimum_size.y=44; personal_box.add_child(personal_slot)
	for i: int in saved.names.size(): personal_slot.add_item("%d · %s"%[i+1,saved.names[i]],i)
	if saved.names.size()<int(runtime.source.personal.max_names): personal_slot.add_item("새 호칭 보관",saved.names.size())
	personal_text=LineEdit.new(); personal_text.name="PersonalName"; personal_text.placeholder_text="개인 호칭"; personal_text.custom_minimum_size.y=44; personal_box.add_child(personal_text)
	personal_color=OptionButton.new(); personal_color.name="PersonalColor"; personal_color.custom_minimum_size.y=44; personal_box.add_child(personal_color)
	for color: Dictionary in runtime.source.personal.colors:
		var stage_name: String=""
		for stage: Dictionary in runtime.source.stages:
			if int(stage.id)==int(color.stage): stage_name=str(stage.name)
		var enabled: bool=runtime.personal.owned(runtime.state,int(color.stage))
		personal_color.add_item("#%s · %s%s"%[color.hex,stage_name,"" if enabled else " 필요"],int(color.id))
		personal_color.set_item_disabled(personal_color.item_count-1,not enabled)
	personal_preview=Label.new(); personal_preview.name="PersonalPreview"; personal_box.add_child(personal_preview)
	personal_notice=Label.new(); personal_notice.name="PersonalNotice"; personal_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; personal_box.add_child(personal_notice)
	var revision:=int(runtime.state.revision)
	button("이름 보관 / 수정",func() -> void: personal_result(runtime.personal.edit(personal_slot.get_selected_id(),personal_text.text,revision)),"SavePersonalName").reparent(personal_box)
	button("보관한 이름 · 선택 색상 표시",func() -> void: personal_result(runtime.personal.activate(personal_slot.get_selected_id(),personal_color.get_selected_id(),revision)),"ApplyPersonalName").reparent(personal_box)
	button("선택 호칭 삭제",func() -> void: personal_result(runtime.personal.remove(personal_slot.get_selected_id(),revision)),"DeletePersonalName").reparent(personal_box)
	button("최고 작위 호칭으로 표시",func() -> void: personal_result(runtime.personal.use_highest(revision)),"UseHighestTitle").reparent(personal_box)
	personal_slot.item_selected.connect(func(_index: int) -> void: select_personal_name())
	personal_text.text_changed.connect(func(_text: String) -> void: preview_personal())
	personal_color.item_selected.connect(func(_index: int) -> void: preview_personal())
	if int(saved.active)>=0: personal_slot.select(int(saved.active))
	for i: int in personal_color.item_count:
		if personal_color.get_item_id(i)==int(saved.color_rule): personal_color.select(i)
	select_personal_name()

func select_personal_name() -> void:
	var names: Array=runtime.personal.data(runtime.state).names
	var slot:=personal_slot.get_selected_id()
	personal_text.text=str(names[slot]) if slot>=0 and slot<names.size() else ""
	preview_personal()

func preview_personal() -> void:
	personal_preview.text="미리보기: "+personal_text.text
	for color: Dictionary in runtime.source.personal.colors:
		if int(color.id)==personal_color.get_selected_id(): personal_preview.add_theme_color_override("font_color",Color("#"+str(color.hex)))

func personal_result(result: Dictionary) -> void:
	if not result.ok:
		personal_notice.text=str(result.message); return # retain unsaved draft on failure
	personal_open=true; build(str(result.message)); reveal_personal()

func reveal_personal() -> void:
	# Container sizes settle after rebuilding. Reveal the name control rather
	# than the whole editor, which can be taller than the viewport.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(personal_box) and personal_box.visible:
		ensure_control_visible(personal_text if is_instance_valid(personal_text) else personal_box)

func refresh_status() -> void:
	if not is_instance_valid(status): return
	var text: String="현재 작위: %s · 검증된 가루 %d개"%[runtime.current_name(),runtime.powder_count()]
	if not runtime.state.active.is_empty():
		var q: Dictionary=runtime.source.quests.get(int(runtime.state.active.quest),{})
		text+="\n%s: %d / %d · 남은 %d초"%[q.get("name","원본 누락"),int(runtime.state.active.count),int(q.get("amount",0)),maxi(0,int(runtime.state.active.expires)-runtime.now())]
	var used:=int(runtime.state.attempts) if int(runtime.state.day)==runtime.day(runtime.now()) else 0
	text+="\n오늘 일반 심사 %d / %d"%[used,runtime.source.daily_limit]
	status.text=text

func _process(delta: float) -> void:
	refresh_clock+=delta
	if refresh_clock>=0.5: refresh_clock=0.0; refresh_status()

func show_result(result: Dictionary) -> void:
	build(str(result.get("message","")))

func review(route: String) -> void:
	reviewed_revision=int(runtime.state.revision)
	var result: Dictionary=runtime.review(route,reviewed_revision)
	if not result.ok: outcome.text=result.message; scroll_vertical=0; return
	reviewed_route=route
	_bind_donation_icon(confirm_ok,route=="donation")
	confirm_text.text=str(result.message)
	confirm.show()
	column.move_child(confirm,0)
	for child: Node in column.get_children():
		if child is Button: child.disabled=true
	scroll_vertical=0

func _confirmed() -> void:
	var route:=reviewed_route; var revision:=reviewed_revision
	reviewed_route=""; reviewed_revision=-1
	_bind_donation_icon(confirm_ok,false)
	confirm.hide()
	if route.is_empty(): return
	show_result(runtime.attempt(route,revision))

func _cancelled() -> void:
	reviewed_route=""; reviewed_revision=-1
	_bind_donation_icon(confirm_ok,false)
	confirm.hide()
	for child: Node in column.get_children():
		if child is Button: child.disabled=false
	outcome.text="심사를 취소했습니다."
	scroll_vertical=0

func _choose_source() -> void:
	var dialog:=FileDialog.new(); dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE; dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.filters=PackedStringArray(["*.zip ; 원본523 ZIP"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		var message: String=runtime.source.install(path)
		if message.is_empty(): runtime.bind_material()
		build("원본 설치 완료 · 저장을 다시 불러오면 보호된 진행도를 복원할 수 있습니다." if message.is_empty() else message)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)
