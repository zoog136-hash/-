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
	_ui_audit_2026_11_21(hud)
	print("RELEASE_SCREEN_TEXT_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

## 2026-11-21 UI audit (every menu, HUD button and feature window touched in
## the real Main): developer words left outside the scrubbed workspace -
## the field coordinates, the 아인하사드 panel, confirmation dialogs, HUD
## messages and the 질서의 연금 notice.
func _ui_audit_2026_11_21(hud: String) -> void:
	var release := preload("res://scripts/ui/release_text.gd")
	check(release.line("TWILIGHT 추가 비용 500 아데나", false) == "추가 비용 500 아데나", "a needed line keeps its sentence without TWILIGHT")
	check(release.line("원본 파견 비용 50다이아 · HP 50%로 부활합니다.", false) == "파견 비용 50다이아 · HP 50%로 부활합니다.", "원본 is dropped inside a cost line")
	check(release.line("원본 수치를 우선하며, 부족한 규칙은 TWILIGHT 추정 설정으로 진행합니다", false) == "", "a policy note line disappears")
	check(release.line("원본523 정의 미등록", false) == "", "a developer-only line disappears")
	check(release.line("탐험 출발", false) == "탐험 출발" and release.line("TWILIGHT 근사", true) == "TWILIGHT 근사", "plain lines stay; debug keeps everything")
	check(release.body("아데나 100 소모 · 8시간\n원본 수치를 우선하며 TWILIGHT 추정 설정", false) == "아데나 100 소모 · 8시간", "a dialog body keeps its cost lines only")
	check(release.line("TWILIGHT 탐험 로컬다이아", false) == "탐험 로컬다이아", "a dialog title loses TWILIGHT")
	var confirmation: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_confirmation.gd")
	check(confirmation.contains("RELEASE_TEXT.line(title)") and confirmation.contains("description = RELEASE_TEXT.body(description)"), "confirmation dialogs pass the release line filter")
	var base_hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	check(base_hud.contains("release_text.gd\").body(text)"), "HUD messages drop developer words line by line before the notice")
	check(not hud.contains("\"원본 좌표  %d, %d\"") and hud.contains("coordinates_readout.text = \"좌표  %d, %d\" % [source_cell.x,source_cell.y]"), "the field coordinates read 좌표, not 원본 좌표")
	var v20: String = FileAccess.get_file_as_string("res://scripts/hud_v20.gd")
	check(v20.contains("\"\\n※ 기본 축복 소모량은 TWILIGHT 조정값\" if preload(\"res://scripts/boot/build_flags.gd\").developer_ui() else \"\""), "the 아인하사드 tuning note is debug-only")
	var refine: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_refine_window.gd")
	check(refine.contains("refine_contents_enabled\")==false and preload(\"res://scripts/boot/build_flags.gd\").developer_ui()") and refine.contains("_mode.begins_with(\"amount:\") and preload(\"res://scripts/boot/build_flags.gd\").developer_ui()"), "질서의 연금 developer notes are debug-only")
