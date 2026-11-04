extends VBoxContainer
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
var picker: FileDialog
var status: Label

func _ready() -> void:
	name = "Patch523DropSettings"
	var title := Label.new()
	title.text = "몬스터 드랍 자료 · 523"
	add_child(title)
	status = Label.new()
	status.name = "Patch523DropStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "설치됨 · 아이템 도감에서 드랍원 확인" if not DROPS.data().is_empty() else "미설치 · 드랍 자료 ZIP을 선택하세요."
	add_child(status)
	var choose := Button.new()
	choose.name = "InstallPatch523DropPack"
	choose.text = "523 드랍 자료 ZIP 설치"
	choose.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(choose)
	picker = FileDialog.new()
	picker.title = "523 드랍 자료 선택"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.zip;TWILIGHT 523 드랍 자료;application/zip"])
	picker.file_selected.connect(_selected)
	add_child(picker)

func _selected(path: String) -> void:
	var result: Dictionary = DROPS.install_zip(path)
	status.text = "드랍 자료 설치 완료 · 아이템 도감에서 드랍원 확인" if result.ok else str(result.error)
