extends SceneTree
## 2026-11-20: developer wording ("검증", "원본#", "523", "source", "미설치",
## "연결 대기", "TWILIGHT 근사") reached release (phone) screens. Messages and
## logs become the original notice, version tags are dropped from ordinary
## sentences, window subtitles/notes disappear, the loading screen speaks of
## "준비", icon status words and the 고급/개발 settings are debug-only.
##   godot --headless --path <repo> --script res://tests/release_screen_text_test.gd
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("RELEASE_SCREEN_TEXT_FAIL: " + label)

func _initialize() -> void:
	var notice: String = IDENTITY.screen_text("검증된 장비 수치 입력 미설치", false)
	check(IDENTITY.screen_text("원본523 제작 · 장검", false) == "제작 · 장검", "a version tag is dropped, the sentence stays")
	check(IDENTITY.screen_text("고블린에게 523 피해", false) == "고블린에게 523 피해", "numbers such as damage 523 stay")
	check(IDENTITY.screen_text("임시 퀘스트는 종료되었습니다 · 최신523 원본 팩을 설치하세요", false) == notice, "pack instructions become the notice")
	check(IDENTITY.screen_text("523 아덴 지도를 열 수 없습니다: x", false) == notice, "523 as the data version becomes the notice")
	check(IDENTITY.screen_text("공성 포인트 · 원본#195371 ×1 습득", false) == "공성 포인트 ×1 습득", "internal IDs are removed")
	check(IDENTITY.screen_text("원본 탄약 발사 연결 대기", false) == notice and IDENTITY.screen_text("source missing", false) == notice, "연결 대기/source become the notice")
	check(IDENTITY.screen_text("원본523 제작 · 장검", true) == "원본523 제작 · 장검", "debug builds keep the full text")
	check(IDENTITY.screen_note("원본 523 혈맹 표 · 로컬 1인 혈맹", false) == "혈맹 표 · 로컬 1인 혈맹", "subtitle loses its version tag")
	check(IDENTITY.screen_note("원본 장비 가공 UI 연결 대기", false) == "" and IDENTITY.screen_note("TWILIGHT 근사", false) == "", "developer subtitles disappear")
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud.contains("description = preload(\"res://scripts/ui/source523_item_identity.gd\").screen_note(description)"), "window subtitles pass the release filter")
	check(not hud.contains("UI.label(\"현황판은 원본 523 UI 팩"), "UI-pack notes pass the release filter")
	var loading: String = FileAccess.get_file_as_string("res://scripts/boot/loading_screen.gd")
	check(not loading.contains("\"원본 %s 검증·정리 중…\"") and not loading.contains("\"검증 완료\"") and loading.contains("\"%s 준비 중…\""), "the loading screen says 준비, not 검증")
	var settings: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_settings.gd")
	check(settings.contains("if preload(\"res://scripts/boot/build_flags.gd\").developer_ui(): _lazy_section(stack,\"advanced\""), "고급/개발 settings are debug-only")
	check(not settings.contains("드랍 · 523\"") and not settings.contains("전환 · 523\""), "settings titles carry no version tag")
	var visual: String = FileAccess.get_file_as_string("res://scripts/ui/item_visual.gd")
	check(visual.contains("item_name.strip_edges() != \"\" and preload(\"res://scripts/boot/build_flags.gd\").developer_ui()"), "icon status words are debug-only")
	print("RELEASE_SCREEN_TEXT_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
