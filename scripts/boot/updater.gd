extends Node
## Over-the-air updates for the playtest APK (first autoload).
##
## Each main build publishes an update pack (scripts, scenes, data and small
## art; never the private 523 resources) and `update.json` to the public
## GitHub release "playtest-latest". At start this node mounts a downloaded
## pack newer than the APK, before any other script or scene loads. After the
## game starts it checks the feed once and downloads a newer pack in the
## background; it applies at the next start.
##
## A pack only fits the APK it was built with the same compat key (engine,
## project settings, global class list and this script). Anything else needs a
## new APK, which installs over the old one (same signing key) and keeps the
## installed resource pack and saves.
const BUILD_INFO := "res://build_info.json"
const DIR := "user://update"
const ACTIVE := "user://update/active.json"
const INCOMING := "user://update/incoming.pck"
const FEED := "https://github.com/zoog136-hash/-/releases/download/playtest-latest/update.json"
const RELEASE_PAGE := "https://github.com/zoog136-hash/-/releases/tag/playtest-latest"
const STYLE_PATH := "res://scripts/boot/boot_style.gd"
const MAX_FEED_BYTES := 64 * 1024

## The APK's own build (read before any pack is mounted).
var builtin: Dictionary = {}
## The mounted update pack, or {} when running the APK as installed.
var active: Dictionary = {}
var feed_url: String = FEED
var state: String = "idle"
var problem: String = ""
var _feed: Dictionary = {}
var _http: HTTPRequest
var _layer: CanvasLayer
var _label: Label
var _bar: ProgressBar

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func code(info: Dictionary) -> int:
	var value: Variant = info.get("version_code", 0)
	return int(value) if (value is int or value is float) and float(value) >= 0.0 else 0

## True when `pack` (an active.json record) is newer than and built for `apk`.
static func fits(pack: Dictionary, apk: Dictionary) -> bool:
	return code(pack) > code(apk) and code(apk) > 0 and not str(apk.get("compat_key", "")).is_empty() \
		and str(pack.get("compat_key", "")) == str(apk.get("compat_key", "")) \
		and str(pack.get("file", "")).is_valid_filename() and str(pack.get("file", "")).ends_with(".pck")

## What to do with a feed record: "none", "download" or "apk".
static func decide(record: Dictionary, apk: Dictionary, mounted: Dictionary) -> String:
	var current: int = maxi(code(apk), code(mounted))
	if code(apk) <= 0 or code(record) <= current: return "none"
	if str(record.get("compat_key", "")) != str(apk.get("compat_key", "")): return "apk"
	var url: String = str(record.get("url", ""))
	var sha: String = str(record.get("sha256", ""))
	if not url.begins_with("https://") or sha.length() != 64 or int(record.get("size", 0)) <= 0 or not str(record.get("file", "")).is_valid_filename(): return "none"
	return "download"

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	builtin = read_json(BUILD_INFO)
	mount()

## Mounts the recorded pack over the APK when it fits; else forgets it.
func mount() -> void:
	var mounted: Dictionary = read_json(ACTIVE)
	if mounted.is_empty(): return
	var path: String = DIR.path_join(str(mounted.get("file", "")))
	if fits(mounted, builtin) and FileAccess.file_exists(path) and FileAccess.get_size(path) == int(mounted.get("size", -1)) \
			and ProjectSettings.load_resource_pack(path, true):
		active = mounted
	else:
		# An APK at least as new as the pack, or a damaged pack: run the APK.
		DirAccess.remove_absolute(ACTIVE)
	_remove_stale()

func _remove_stale() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null: return
	for name: String in dir.get_files():
		if name.ends_with(".pck") and name != str(active.get("file", "")): dir.remove(name)

func version_name() -> String:
	return str((active if not active.is_empty() else builtin).get("version_name", ""))

func _ready() -> void:
	if code(builtin) <= 0 or OS.has_feature("editor") or DisplayServer.get_name() == "headless": return
	check.call_deferred()

## Asks the feed once for a newer build.
func check() -> void:
	if state != "idle": return
	state = "checking"
	_http = HTTPRequest.new()
	# On its own thread: a main thread blocked by loading or a map change must
	# not count against the request (it used to time out behind long stalls).
	_http.use_threads = true
	_http.timeout = 60.0
	_http.body_size_limit = MAX_FEED_BYTES
	add_child(_http)
	_http.request_completed.connect(_on_feed, CONNECT_ONE_SHOT)
	if _http.request(feed_url) != OK: _finish("idle", "업데이트 확인 실패")

func _on_feed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		# Nothing to act on: no popup over the game; the next start checks again.
		problem = "업데이트 서버에 연결하지 못했습니다 (%d/%d)" % [result, status]
		push_warning(problem)
		state = "idle"
		return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	_feed = value if value is Dictionary else {}
	match decide(_feed, builtin, active):
		"download": _download()
		"apk":
			state = "apk"
			_show("새 APK가 필요한 업데이트가 있습니다 (%s). 받은 APK를 설치하면 리소스 팩과 저장은 그대로 남습니다." % str(_feed.get("version_name", "")), true)
		_: _finish("current", "")

func _download() -> void:
	state = "downloading"
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.remove_absolute(INCOMING)
	_http.use_threads = true
	_http.body_size_limit = int(_feed.size) + 1024
	_http.timeout = 0.0
	_http.download_file = INCOMING
	_http.request_completed.connect(_on_pack, CONNECT_ONE_SHOT)
	_show("업데이트 %s 받는 중…" % str(_feed.get("version_name", "")), false)
	if _http.request(str(_feed.url)) != OK: _finish("idle", "업데이트 다운로드를 시작하지 못했습니다")

func _process(_delta: float) -> void:
	if state == "downloading" and _bar != null and int(_feed.get("size", 0)) > 0:
		_bar.value = 100.0 * float(_http.get_downloaded_bytes()) / float(_feed.size)

func _on_pack(result: int, status: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or status != 200 or FileAccess.get_size(INCOMING) != int(_feed.size) or FileAccess.get_sha256(INCOMING) != str(_feed.sha256):
		DirAccess.remove_absolute(INCOMING)
		_finish("idle", "업데이트 파일이 올바르지 않아 버렸습니다. 다음 실행 때 다시 받습니다.")
		return
	var applied: String = install(INCOMING, _feed)
	if not applied.is_empty():
		_finish("idle", applied)
		return
	_finish("ready", "업데이트 %s 준비 완료 — 앱을 완전히 닫았다가 다시 열면 적용됩니다." % str(_feed.get("version_name", "")))

## Moves a verified pack into place and records it for the next start.
## Returns "" or a problem.
func install(downloaded: String, record: Dictionary) -> String:
	var file: String = str(record.file)
	var target: String = DIR.path_join(file)
	if FileAccess.file_exists(target): DirAccess.remove_absolute(target)
	if DirAccess.rename_absolute(downloaded, target) != OK: return "업데이트 파일을 저장하지 못했습니다"
	var info: Dictionary = {"version_code":code(record),"version_name":str(record.get("version_name","")),"compat_key":str(record.compat_key),"file":file,"size":int(record.size),"sha256":str(record.sha256)}
	var pending: String = ACTIVE + ".pending"
	var out := FileAccess.open(pending, FileAccess.WRITE)
	if out == null: return "업데이트 기록을 저장하지 못했습니다"
	out.store_string(JSON.stringify(info))
	out.close()
	if DirAccess.rename_absolute(pending, ACTIVE) != OK: return "업데이트 기록을 저장하지 못했습니다"
	return ""

func _finish(next: String, message: String) -> void:
	state = next
	problem = message if next == "idle" else ""
	if message.is_empty():
		if _layer != null: _layer.queue_free()
		_layer = null
		return
	_show(message, false, true)

func _show(message: String, offer_apk: bool, closable: bool = false) -> void:
	var style: GDScript = load(STYLE_PATH) as GDScript
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 120
		add_child(_layer)
		var holder := MarginContainer.new()
		holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		holder.add_theme_constant_override("margin_left", 180)
		holder.add_theme_constant_override("margin_right", 180)
		holder.add_theme_constant_override("margin_top", 8)
		_layer.add_child(holder)
		var panel: PanelContainer = style.panel()
		holder.add_child(panel)
		var row := VBoxContainer.new()
		row.name = "Row"
		row.add_theme_constant_override("separation", 6)
		panel.add_child(row)
		_label = style.label("", 18)
		row.add_child(_label)
		_bar = style.progress_bar()
		_bar.custom_minimum_size = Vector2(0, 12)
		row.add_child(_bar)
	_label.text = message
	_bar.visible = state == "downloading"
	var row: VBoxContainer = _label.get_parent() as VBoxContainer
	for child: Node in row.get_children():
		if child is HBoxContainer: child.queue_free()
	if offer_apk or closable:
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 12)
		row.add_child(buttons)
		if offer_apk:
			var get_apk: Button = style.button("APK 받기", true, 48)
			get_apk.custom_minimum_size.x = 200
			get_apk.pressed.connect(func() -> void: OS.shell_open(str(_feed.get("apk_url", RELEASE_PAGE))))
			buttons.add_child(get_apk)
		var close: Button = style.button("닫기", false, 48)
		close.custom_minimum_size.x = 160
		close.pressed.connect(func() -> void:
			if _layer != null: _layer.queue_free()
			_layer = null)
		buttons.add_child(close)
