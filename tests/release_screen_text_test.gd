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
	var panel := VBoxContainer.new()
	var dev_label := Label.new(); dev_label.text = "523 원본 폴더를 선택하고, 원하는 구역의 기본값을 적용할 수 있습니다."; panel.add_child(dev_label)
	var plain := Label.new(); plain.text = "지도 좌표·충돌·몬스터 배치를 변경하지 않는 시각 설정입니다."; panel.add_child(plain)
	var tagged := Button.new(); tagged.text = "원본523 장비 강화 정보"; panel.add_child(tagged)
	check(preload("res://scripts/ui/release_text.gd").scrub(panel, true) == 0, "debug builds keep panel text")
	preload("res://scripts/ui/release_text.gd").scrub(panel, false)
	check(not dev_label.visible and plain.visible and plain.text.begins_with("지도 좌표") and tagged.text == "장비 강화 정보", "release panels hide developer notes and drop version tags")
	panel.free()
	var settings_src: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_settings.gd")
	check(settings_src.contains("release_text.gd\").scrub(entry.body)") and hud.contains("release_text.gd\").scrub(workspace)"), "settings sections and workspace windows are scrubbed")
	print("RELEASE_SCREEN_TEXT_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
