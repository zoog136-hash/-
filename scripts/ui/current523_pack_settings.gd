extends VBoxContainer
const PACK = preload("res://scripts/resources/current523_pack.gd")
var installer: Node
var picker: FileDialog
var choose: Button
var cancel: Button
var status: Label
var previews: HBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "Current523PackSettings"
	installer = PACK.new()
	add_child(installer)
	var title := Label.new()
	title.text = "현행523 표준 이미지 · 원문"
	add_child(title)
	status = Label.new()
	status.name = "Current523PackStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "미설치 · 표준 PNG 2종과 SP2 원문 989개 묶음을 선택하세요."
	add_child(status)
	previews = HBoxContainer.new()
	previews.name = "Current523ImagePreviews"
	add_child(previews)
	if not PACK.info().is_empty(): _show_images(PACK.root_path(), false)
	elif not PACK.latest_root().is_empty(): _show_images(PACK.latest_root(), true)
	choose = Button.new()
	choose.name = "InstallCurrent523Pack"
	choose.text = "523 원문·PNG ZIP 선택"
	choose.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(choose)
	cancel = Button.new()
	cancel.text = "523 설치 중단"
	cancel.visible = false
	cancel.pressed.connect(func() -> void: installer.cancelled = true)
	add_child(cancel)
	picker = FileDialog.new()
	picker.title = "현행523 원문·표준 PNG 묶음"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.zip;현행523 원문·PNG 묶음;application/zip"])
	picker.file_selected.connect(_selected)
	add_child(picker)
	installer.progress.connect(func(done: int,total: int) -> void:
		status.text = "523 원문·이미지 검사 중 %d / %d · 이전 팩 유지" % [done,total])

func _show_images(path: String, newly_installed: bool) -> void:
	for child: Node in previews.get_children():
		previews.remove_child(child)
		child.queue_free()
	var loaded: int = 0
	for key: String in PACK.IMAGES:
		var texture: Texture2D = PACK.texture(key,path)
		if texture == null: continue
		var preview := TextureRect.new()
		preview.name = "Current523_" + key
		preview.custom_minimum_size = Vector2(64,64)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = texture
		previews.add_child(preview)
		loaded += 1
	status.text = "523 PNG %d/2 표시 · SP2 원문 989개 검증 보관 · 캐릭터 재생 미연결" % loaded
	if loaded != 2: status.text = "523 이미지 누락·변경 · 다른 버전 이미지로 대체하지 않습니다."
	elif newly_installed: status.text += " · 설치 완료, 재실행 후 사용"

func _selected(path: String) -> void:
	choose.disabled = true
	cancel.visible = true
	status.text = "523 ZIP 확인 중…"
	var result: Dictionary = await installer.install_zip(path)
	choose.disabled = false
	cancel.visible = false
	if result.ok: _show_images(str(result.root),true)
	else: status.text = str(result.error)
