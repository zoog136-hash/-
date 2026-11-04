extends VBoxContainer
## Passive information belongs beside the existing summon/equip controls.
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var status: Label
var values: Label
var import_button: Button
var picker: FileDialog
var snapshot: Dictionary = {}
var _state_signature: int = 0

func configure(controller: Node) -> void:
	hud = controller
	name = "RelicSpellLevelPanel"
	add_child(UI.label("등급별 스킬 레벨 보너스", 13, UI.GOLD))
	values = UI.label("", 12)
	values.name = "RelicSpellLevelValues"
	values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(values)
	status = UI.label("", 11, UI.MUTED)
	status.name = "RelicSpellLevelStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	import_button = UI.button("원본 규칙 자료 불러오기", func() -> void: picker.popup_centered_ratio(.75), Vector2(0, 34))
	import_button.name = "RelicSpellLevelImport"
	add_child(import_button)
	picker = FileDialog.new()
	picker.name = "RelicSpellLevelSourcePicker"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.zip ; 원본 규칙 자료 ZIP"])
	picker.title = "최신 누적 523 원본 규칙 자료"
	picker.file_selected.connect(_selected)
	add_child(picker)

func _state_key() -> int:
	var world: Node = hud.get_parent()
	var equipped: Dictionary = world.equipped_catalog.get("성물", {})
	return hash([RULES.revision, equipped.get("source", ""), equipped.get("sourceId", ""), equipped.get("source_card_id", -1), equipped.get("source_deck_id", -1), world.card_draw_fusion.owned.get("성물", {}), world.card_collections.source_server_context()])

func _process(_delta: float) -> void:
	# Observe the existing state without rewriting the shared HUD publisher.
	# This also catches load/server-context changes while this page stays open.
	if hud != null and is_visible_in_tree() and _state_signature != _state_key():
		hud.relic_reference_view.refresh_state()

func _selected(path: String) -> void:
	picker.hide()
	var result: Dictionary = RULES.install_source(path)
	if not result.ok:
		hud.show_message("원본 규칙 자료를 불러오지 못했습니다. 최신 누적 523 ZIP을 확인하세요.")
	else:
		hud.show_message("성물 스킬 레벨 규칙 자료를 불러왔습니다.")
	refresh()

func refresh() -> void:
	_state_signature = _state_key()
	var record: Dictionary = hud.selected_catalog_record if hud.catalog_category == "성물" else {}
	snapshot = RULES.for_world(hud.get_parent(), record)
	var lines: Array[String] = []
	for effect: Dictionary in snapshot.effects:
		lines.append("%s 스킬 레벨 +%d" % [str(effect.label), int(effect.bonus.Value)])
	values.text = " · ".join(lines) if not lines.is_empty() else "이 성물에 연결된 레벨 보너스 없음" if snapshot.ok else "원본 규칙 자료를 불러오세요."
	var labels: Dictionary = {"ready":"현재 소환에 연결됨", "not_owned":"미보유 · 조회 전용", "not_equipped":"소환 시 적용되는 레벨 규칙", "no_source_mapping":"원본에 레벨 보너스 매핑 없음", "server_context_missing":"서버 조건 확인 필요", "server_ineligible":"현재 서버 조건 불충족", "server_definition_missing":"서버 조건 정의 미확인", "time_condition_unresolved":"이벤트 기간 조건 확인 필요", "catalog_identity_missing":"현재 등록 카드와 원본 ID 연결 없음", "catalog_source_changed":"현재 카드와 최신 원본 조건 대조 필요"}
	status.text = str(labels.get(snapshot.code, "최신 누적 523 원본 규칙 자료 필요"))
	if not lines.is_empty(): status.text += "\n현재 스킬의 레벨별 전투 수치 연결은 확인 중입니다."
	import_button.text = "원본 규칙 자료 교체" if RULES.ensure_loaded() else "원본 규칙 자료 불러오기"
