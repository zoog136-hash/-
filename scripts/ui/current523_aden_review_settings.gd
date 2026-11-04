extends VBoxContainer
## Folder preferences belong to this panel, never to the game save.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const CONFIG_PATH: String = "user://current523_aden_review_paths.cfg"
const RAW_ENV: String = "TWILIGHT_CURRENT523_ADEN_PACK"
const TILE_ENV: String = "TWILIGHT_CURRENT523_ADEN_TILES"

var raw_path_edit: LineEdit
var tile_path_edit: LineEdit
var raw_browse_button: Button
var tile_browse_button: Button
var open_button: Button
var status_label: Label
var folder_dialog: FileDialog
var _world_ref: WeakRef
var _built: bool = false
var _folder_target: String = ""


func configure(world: Node) -> void:
	_disconnect_world()
	_world_ref = weakref(world) if is_instance_valid(world) else null
	name = "Current523AdenReviewSettings"
	if not _built:
		_build()
		_load_paths()
	var current: Node = _world()
	if current != null and current.has_signal("current523_aden_review_closed"):
		current.connect("current523_aden_review_closed", _on_review_closed)
	_update_open_button()


func _build() -> void:
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	add_child(UI.section("아덴 원문 검토", 18))
	var note: Label = UI.label("좌표와 표시 방식은 검토 중입니다. 캐릭터 보행은 아직 구현되지 않았습니다.", 13, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	add_child(UI.label("아덴 원문 팩 폴더", 13))
	var raw_row := HBoxContainer.new()
	add_child(raw_row)
	raw_path_edit = _path_edit("RawPathEdit")
	raw_row.add_child(raw_path_edit)
	raw_browse_button = UI.button("폴더 선택", _browse.bind("raw"), Vector2(100, 40))
	raw_browse_button.name = "RawBrowseButton"
	raw_row.add_child(raw_browse_button)
	add_child(UI.label("타일 검토 팩 폴더", 13))
	var tile_row := HBoxContainer.new()
	add_child(tile_row)
	tile_path_edit = _path_edit("TilePathEdit")
	tile_row.add_child(tile_path_edit)
	tile_browse_button = UI.button("폴더 선택", _browse.bind("tiles"), Vector2(100, 40))
	tile_browse_button.name = "TileBrowseButton"
	tile_row.add_child(tile_browse_button)
	open_button = UI.button("아덴 원문 보기", _open_review, Vector2(0, 44))
	open_button.name = "OpenAdenReviewButton"
	UI.primary_button(open_button)
	add_child(open_button)
	status_label = UI.label("팩 폴더 두 곳을 선택해 주세요.", 13, UI.MUTED)
	status_label.name = "ReviewStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)
	folder_dialog = FileDialog.new()
	folder_dialog.name = "AdenReviewFolderDialog"
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.use_native_dialog = false
	folder_dialog.dir_selected.connect(_folder_selected)
	folder_dialog.canceled.connect(_folder_cancelled)
	add_child(folder_dialog)
	visibility_changed.connect(_visibility_changed)


func _path_edit(node_name: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = "폴더를 선택하거나 경로를 입력하세요."
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(80, 40)
	edit.text_changed.connect(_path_changed)
	return edit


func _load_paths() -> void:
	var preferences := ConfigFile.new()
	preferences.load(CONFIG_PATH)
	var raw: Variant = preferences.get_value("paths", "raw", "")
	var tiles: Variant = preferences.get_value("paths", "tiles", "")
	raw_path_edit.text = raw.strip_edges() if raw is String else ""
	tile_path_edit.text = tiles.strip_edges() if tiles is String else ""
	if raw_path_edit.text.is_empty():
		raw_path_edit.text = OS.get_environment(RAW_ENV).strip_edges()
	if tile_path_edit.text.is_empty():
		tile_path_edit.text = OS.get_environment(TILE_ENV).strip_edges()


func _world() -> Node:
	if _world_ref == null:
		return null
	var value: Variant = _world_ref.get_ref()
	return value as Node if is_instance_valid(value) else null


func _disconnect_world() -> void:
	var current: Node = _world()
	if current != null and current.has_signal("current523_aden_review_closed") and current.is_connected("current523_aden_review_closed", _on_review_closed):
		current.disconnect("current523_aden_review_closed", _on_review_closed)


func _path_changed(_text: String) -> void:
	_update_open_button()
	_refresh_path_status()


func _refresh_path_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = "선택한 팩은 '아덴 원문 보기'를 눌러 확인하세요." if not raw_path_edit.text.strip_edges().is_empty() and not tile_path_edit.text.strip_edges().is_empty() else "팩 폴더 두 곳을 선택해 주세요."


func _update_open_button() -> void:
	if not is_instance_valid(open_button):
		return
	var current: Node = _world()
	open_button.disabled = current == null or not current.has_method("open_current523_aden_review_ui") or raw_path_edit.text.strip_edges().is_empty() or tile_path_edit.text.strip_edges().is_empty()


func _browse(target: String) -> void:
	_folder_target = target
	folder_dialog.title = "아덴 원문 팩 폴더 선택" if target == "raw" else "타일 검토 팩 폴더 선택"
	var path: String = raw_path_edit.text if target == "raw" else tile_path_edit.text
	path = ProjectSettings.globalize_path(path.strip_edges())
	if not path.is_empty() and DirAccess.dir_exists_absolute(path):
		folder_dialog.current_dir = path
	folder_dialog.popup_centered_ratio(0.8)


func _folder_selected(path: String) -> void:
	if _folder_target == "raw":
		raw_path_edit.text = path
	elif _folder_target == "tiles":
		tile_path_edit.text = path
	_folder_target = ""
	_update_open_button()
	_refresh_path_status()


func _folder_cancelled() -> void:
	_folder_target = ""


func _open_review() -> void:
	var current: Node = _world()
	if current == null or not current.has_method("open_current523_aden_review_ui"):
		status_label.text = "현재 게임에서 원문 검토를 열 수 없습니다."
		_update_open_button()
		return
	var raw: String = raw_path_edit.text.strip_edges()
	var tiles: String = tile_path_edit.text.strip_edges()
	if raw.is_empty() or tiles.is_empty():
		status_label.text = "팩 폴더 두 곳을 선택해 주세요."
		_update_open_button()
		return
	open_button.disabled = true
	var opened: bool = bool(current.call("open_current523_aden_review_ui", raw, tiles))
	if opened:
		var preferences := ConfigFile.new()
		preferences.set_value("paths", "raw", raw)
		preferences.set_value("paths", "tiles", tiles)
		var saved: Error = preferences.save(CONFIG_PATH)
		if is_instance_valid(status_label) and not is_queued_for_deletion():
			status_label.text = "아덴 원문 검토를 열었습니다." if saved == OK else "아덴 원문 검토를 열었습니다. 폴더 경로는 기억하지 못했습니다."
	else:
		var detail: Variant = current.get("current523_aden_problem")
		if is_instance_valid(status_label) and not is_queued_for_deletion():
			status_label.text = "팩을 열지 못했습니다: " + detail if detail is String and not detail.is_empty() else "원문 검토를 열지 못했습니다."
	if not is_queued_for_deletion():
		_update_open_button()


func _on_review_closed() -> void:
	if is_instance_valid(status_label):
		status_label.text = "이전 게임 화면으로 돌아왔습니다."
	_update_open_button()


func _visibility_changed() -> void:
	if not is_visible_in_tree() and is_instance_valid(folder_dialog):
		folder_dialog.hide()
		_folder_target = ""
	_update_open_button()


func _exit_tree() -> void:
	_disconnect_world()
	_world_ref = null
	_folder_target = ""
	if is_instance_valid(folder_dialog):
		folder_dialog.hide()
