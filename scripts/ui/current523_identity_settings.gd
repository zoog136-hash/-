extends VBoxContainer
const PACK = preload("res://scripts/resources/current523_identity_pack.gd")
var installer: Node
var picker: FileDialog
var enabled_toggle: CheckBox
var fps_input: SpinBox
var alpha_picker: OptionButton
var rgb_picker: OptionButton
var blend_picker: OptionButton
var opacity_input: SpinBox
var zoom_input: SpinBox
var choose: Button
var status: Label
var actor_status: Label
var identities: Label
var selected_root: String = ""
var _poll: float = 0.0

func _ready() -> void:
	name = "Current523IdentitySettings"
	process_mode = Node.PROCESS_MODE_ALWAYS
	installer = PACK.new()
	add_child(installer)
	var title := Label.new()
	title.text = "523 정체 확인 변신 · 픽셀/합성 추정"
	add_child(title)
	var description := Label.new()
	description.text = "검증된 카드 ID와 SPR의 몸체·그림자·의상을 연결합니다. 기존 변신 메뉴의 장착/해제로 표시합니다. 무기별 기본 액션 선택은 TWILIGHT 정책이며 특수·변형 무기 동작은 제외합니다. 미확인 ID·무기는 이전 표시를 유지합니다. 원작 픽셀 동등성은 미검증입니다."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	choose = Button.new()
	choose.name = "Install523IdentityPack"
	choose.text = "523 정체 연결 ZIP 선택"
	choose.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(choose)
	picker = FileDialog.new()
	picker.title = "523 정확한 정체 · 추정 픽셀 팩"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.zip;523 정체 연결 묶음;application/zip"])
	picker.file_selected.connect(_selected)
	add_child(picker)
	status = Label.new()
	status.name = "Current523IdentitySaveStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	enabled_toggle = CheckBox.new()
	enabled_toggle.text = "확인된 변신 ID를 자동 표시 (픽셀·합성 추정)"
	add_child(enabled_toggle)
	fps_input = _number("SPR FPS가 없을 때만 자체 FPS",1.0,60.0,1.0)
	alpha_picker = _choice("추정 알파",["원문 샘플 유지","색인0 투명"])
	rgb_picker = _choice("추정 RGB565",["비트 확장","선형 확장"])
	blend_picker = _choice("추정 합성",["일반","가산","곱셈"])
	opacity_input = _number("추정 불투명도",0.0,1.0,0.05)
	zoom_input = _number("표시 배율",0.25,8.0,0.25)
	var apply := Button.new()
	apply.name = "Apply523IdentitySettings"
	apply.text = "정체 표시 설정 저장·적용"
	apply.pressed.connect(_apply)
	add_child(apply)
	var restore := Button.new()
	restore.name = "Restore523PreviousAppearance"
	restore.text = "이전 팩·기본 외형으로 복귀"
	restore.pressed.connect(func() -> void:
		var previous: Dictionary = PACK.options()
		previous.enabled = false
		var result: Dictionary = PACK.save_options(previous)
		status.text = "정체 추정 표시 해제 · 현재 변신/클래스의 이전 표시 복구" if result.ok else str(result.error)
		if result.ok: _restore_values())
	add_child(restore)
	identities = Label.new()
	identities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(identities)
	actor_status = Label.new()
	actor_status.name = "Current523IdentityActorStatus"
	actor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(actor_status)
	installer.progress.connect(func(done: int,total: int) -> void: status.text = "정체 팩 검사 %d/%d · 활성 외형 유지" % [done,total])
	_restore_values()
	status.text = PACK.settings_problem

func _number(caption: String,minimum: float,maximum: float,step: float) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.custom_minimum_size.x = 110
	row.add_child(input)
	add_child(row)
	return input

func _choice(caption: String,values: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var input := OptionButton.new()
	for text: String in values: input.add_item(text)
	row.add_child(input)
	add_child(row)
	return input

func _restore_values() -> void:
	var values: Dictionary = PACK.options()
	selected_root = str(values.root)
	if selected_root.is_empty(): selected_root = PACK.latest_root()
	enabled_toggle.button_pressed = bool(values.enabled)
	fps_input.value = float(values.fps)
	alpha_picker.select(["opaque_samples","index0_transparent"].find(values.alpha_policy))
	rgb_picker.select(["bit_replication","linear"].find(values.rgb_policy))
	blend_picker.select(["mix","add","multiply"].find(values.blend))
	opacity_input.value = float(values.opacity)
	zoom_input.value = float(values.zoom)
	_show_identities()

func _show_identities() -> void:
	var manifest: Dictionary = PACK.manifest_at(selected_root)
	var keys: Array = manifest.get("cards",{}).keys()
	keys.sort()
	var labels := PackedStringArray()
	for key: String in keys:
		var record: Dictionary = preload("res://scripts/lineagem_base508.gd").canonical({"source":"lineagem_base508","sourceId":key.trim_prefix("transform:")})
		labels.append(str(record.get("name",key.trim_prefix("transform:"))))
	identities.text = "미설치 · 정체 팩 설치 후 설정을 저장하세요." if keys.is_empty() else "연결된 변신 %d종 · %s" % [keys.size(),", ".join(labels)]
	identities.tooltip_text = ", ".join(keys)

func _selected(path: String) -> void:
	choose.disabled = true
	var result: Dictionary = await installer.install_zip(path)
	choose.disabled = false
	if result.ok:
		selected_root = str(result.root)
		status.text = "검증·설치 완료 · 설정 저장 후 현재 변신부터 적용"
		_show_identities()
	else: status.text = str(result.error)

func _apply() -> Dictionary:
	var values: Dictionary = {"enabled":enabled_toggle.button_pressed,"root":selected_root,"fps":fps_input.value,"alpha_policy":["opaque_samples","index0_transparent"][alpha_picker.selected],"rgb_policy":["bit_replication","linear"][rgb_picker.selected],"blend":["mix","add","multiply"][blend_picker.selected],"opacity":opacity_input.value,"zoom":zoom_input.value}
	var result: Dictionary = PACK.save_options(values)
	status.text = "정체 표시 설정 적용 · 기존 변신 메뉴에서 확인" if result.ok else str(result.error)
	return result

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.25: return
	_poll = 0.0
	var actor: Node = get_tree().root.find_child("Current523IdentityActor",true,false)
	if actor != null and actor.has_method("status_details"):
		var details: Dictionary = actor.status_details()
		if bool(details.get("native_pack_preferred",false)):
			actor_status.text = "기존 원본 팩 재생 유지 · 비교 표시보다 우선"
			return
		actor_status.text = "sprite %d · %s · %s" % [int(details.get("source_sprite_id",-1)),str(details.get("role","")),str(details.get("error",""))] if bool(details.get("active",false)) else str(details.get("error","정체 표시 대기"))
