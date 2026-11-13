extends VBoxContainer
## Folder preferences belong to this panel, never to the game save.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const CONFIG_PATH: String = "user://current523_aden_review_paths.cfg"
const RAW_ENV: String = "TWILIGHT_CURRENT523_ADEN_PACK"
const TILE_ENV: String = "TWILIGHT_CURRENT523_ADEN_TILES"
const INSTALL = preload("res://scripts/maps/current523_aden_install.gd")
const PREFERENCES = preload("res://scripts/maps/current523_aden_preferences.gd")
const DEFINITIONS=preload("res://scripts/maps/current523_source_definition_preferences.gd")
const INSTALL_STAGES = {"archive_sha256":"원본 확인", "manifest_validation":"팩 정보 확인", "inventory":"설치 파일 확인", "extract":"파일 저장", "verify":"저장 결과 확인", "reuse_verify":"기존 설치 확인", "cleanup":"임시 파일 정리"}
const PLAY_OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const STATIC_SPR = preload("res://scripts/maps/current523_static_spr.gd")

var raw_path_edit: LineEdit
var tile_path_edit: LineEdit
var raw_browse_button: Button
var tile_browse_button: Button
var open_button: Button
var status_label: Label
var folder_dialog: FileDialog
var zip_dialog: FileDialog
var install_button: Button
var cancel_button: Button
var rollback_button: Button
var installer: Node
var play_profile: OptionButton
var play_offset_x: SpinBox
var play_offset_y: SpinBox
var play_button: Button
var play_apply_button: Button
var play_stop_button: Button
var play_status: Label
var source_manifest: LineEdit
var tile_manifest: LineEdit
var native_land_choice: OptionButton
var native_scope_status: Label
var source_words: LineEdit
var source_search_limit: SpinBox
var aden_inferred_placement: CheckBox
var source_portal_path: LineEdit
var definition_path_edit: LineEdit
var definition_connect_button: Button
var definition_clear_button: Button
var definition_status: Label
var source_portal_choice: OptionButton
var source_portal_button: Button
var source_portal_walk_button: Button
var source_entry_enabled: CheckBox
var source_entry_x: SpinBox
var source_entry_y: SpinBox
var _world_ref: WeakRef
var _built: bool = false
var _native_catalog: RefCounted
var _native_catalog_loads: int = 0
var _folder_target: String = ""
## Listing the active map's original portals evaluates every declaration
## (6 s on desktop for 93 portals, far longer on a phone), so building this
## panel never does it; the player asks for it or starts/changes play.
var _portals_listed: bool = false
var source_portal_list_button: Button
var spr_enabled: CheckBox
var spr_root: LineEdit
var spr_declaration: LineEdit
var spr_actions: LineEdit
var spr_frame_bindings: LineEdit
var spr_group: SpinBox
var spr_fps: SpinBox
var spr_anchor_x: SpinBox
var spr_anchor_y: SpinBox
var spr_layer: SpinBox
var spr_status: Label


func configure(world: Node) -> void:
	_disconnect_world()
	_world_ref = weakref(world) if is_instance_valid(world) else null
	name = "Current523AdenReviewSettings"
	if not _built:
		_build()
		_load_paths()
		_load_play_options(false)
	var current: Node = _world()
	if current != null and current.has_signal("current523_aden_review_closed"):
		current.connect("current523_aden_review_closed", _on_review_closed)
	if current != null and current.has_signal("current523_aden_play_changed"):
		current.connect("current523_aden_play_changed", _on_play_changed)
	_update_open_button()


func _build() -> void:
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	add_child(UI.section("맵 원문 검토", 18))
	var note: Label = UI.label("검토 보기는 표시용입니다. 아래 맵 플레이에서 원문 지형과 자체 통행으로 걸을 수 있습니다. 원작 판정은 미확정입니다.", 13, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	var install_row := HBoxContainer.new()
	add_child(install_row)
	install_button = UI.button("원본 ZIP 설치", _browse_zip, Vector2(0, 40))
	install_button.name = "InstallAdenZipButton"
	install_row.add_child(install_button)
	cancel_button = UI.button("설치 취소", _cancel_install, Vector2(0, 40))
	cancel_button.name = "CancelAdenInstallButton"
	cancel_button.disabled = true
	install_row.add_child(cancel_button)
	rollback_button = UI.button("이전 팩 사용", _rollback, Vector2(0, 40))
	rollback_button.name = "RollbackAdenPackButton"
	install_row.add_child(rollback_button)
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
	_build_play_options()
	folder_dialog = FileDialog.new()
	folder_dialog.name = "AdenReviewFolderDialog"
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.use_native_dialog = false
	folder_dialog.dir_selected.connect(_folder_selected)
	folder_dialog.canceled.connect(_folder_cancelled)
	add_child(folder_dialog)
	zip_dialog = FileDialog.new()
	zip_dialog.name = "AdenResourceZipDialog"
	zip_dialog.title = "최신523 아덴 원본 ZIP 선택"
	zip_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	zip_dialog.access = FileDialog.ACCESS_FILESYSTEM
	zip_dialog.use_native_dialog = false
	zip_dialog.filters = PackedStringArray(["*.zip ; ZIP 리소스 팩"])
	zip_dialog.file_selected.connect(_install_zip)
	add_child(zip_dialog)
	installer = INSTALL.new()
	installer.name = "AdenResourceInstaller"
	installer.progress.connect(_install_progress)
	installer.finished.connect(_install_finished)
	add_child(installer)
	visibility_changed.connect(_visibility_changed)


func _build_play_options() -> void:
	add_child(HSeparator.new())
	add_child(UI.section("523 원문 맵 플레이", 18))
	var note: Label = UI.label("원문 S32 통행은 공급된 지형·속성을 자체 해석합니다. 이전 TWILIGHT 통행과 별개이며 M 원작 판정은 미확정입니다.", 13, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	play_profile = OptionButton.new()
	play_profile.name = "AdenPlayNavigationProfile"
	play_profile.add_item("자체 통행 설정을 선택해 주세요")
	play_profile.add_item("기존 TWILIGHT 아덴 통행 · 자체 설정")
	play_profile.add_item("원문 S32 속성 기반 · 자체 통행")
	play_profile.add_item("전체 맵 카탈로그 · 논리 Land 선택")
	play_profile.item_selected.connect(_play_choice_changed)
	add_child(play_profile)
	source_manifest=LineEdit.new(); source_manifest.name="Current523SourceManifestSHA256"
	source_manifest.placeholder_text="전체 원문 카탈로그 SHA256 · source523.json"
	add_child(source_manifest)
	tile_manifest=LineEdit.new(); tile_manifest.name="Current523TileManifestSHA256"
	tile_manifest.placeholder_text="타일 팩 SHA256 · tilepack523.json"
	add_child(tile_manifest)
	add_child(UI.label("전체 맵 모드는 위 원문/타일 폴더와 각 검증값을 사용합니다. 목록에 있는 지역도 실제 원문과 타일이 없으면 입장할 수 없습니다.",12,UI.MUTED))
	var refresh: Button=UI.button("카탈로그 확인 · 지역 목록 읽기",_reload_native_lands,Vector2(0,40))
	refresh.name="ReloadCurrent523NativeLands"; add_child(refresh)
	native_land_choice=OptionButton.new(); native_land_choice.name="Current523NativeLandChoice"
	native_land_choice.item_selected.connect(_native_land_changed); add_child(native_land_choice)
	native_scope_status=UI.label("카탈로그를 확인하면 논리 Land와 원문 확보 범위를 표시합니다.",12,UI.MUTED)
	native_scope_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(native_scope_status)
	source_words = LineEdit.new()
	source_words.name = "AdenSourceAllowedWords"
	source_words.text = "0,4,8,12,32"
	source_words.placeholder_text = "허용할 원문 값 · 쉼표로 구분"
	add_child(UI.label("S32 자체 해석 허용값 · 두 반쪽이 모두 해당하고 바닥 원문이 있어야 이동합니다. 나머지는 거부합니다.",12,UI.MUTED))
	add_child(source_words)
	add_child(UI.label("자체 경로 검색 한도 · 큰 값은 긴 길을 더 탐색하지만 시간이 늘어납니다. 통행 허용값은 바뀌지 않습니다.",12,UI.MUTED))
	source_search_limit=SpinBox.new();source_search_limit.name="Current523SourcePathSearchLimit"
	source_search_limit.min_value=1;source_search_limit.max_value=65536;source_search_limit.step=1;source_search_limit.value=8192
	add_child(source_search_limit)
	aden_inferred_placement=CheckBox.new();aden_inferred_placement.name="Current523AdenInferredPlacement"
	aden_inferred_placement.text="아덴 비표준 원문1개 · TWILIGHT 추정 배치 사용 (원작 위치 미확정)"
	aden_inferred_placement.button_pressed=true;add_child(aden_inferred_placement)
	var placement_note:=UI.label("추정 슬롯 (33472,32128) · 기존 청크와 겹치지 않습니다. 끄려면 먼저 원문 플레이를 종료하세요. 경계의 막힌 셀은 열지 않습니다.",12,UI.MUTED)
	placement_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(placement_note)
	var entry := HBoxContainer.new()
	source_entry_enabled = CheckBox.new(); source_entry_enabled.text = "원문 좌표로 입장"
	entry.add_child(source_entry_enabled)
	source_entry_x = SpinBox.new(); source_entry_y = SpinBox.new()
	for control: SpinBox in [source_entry_x,source_entry_y]:
		control.min_value = 0; control.max_value = 65535; control.step = 1; control.custom_minimum_size = Vector2(125,36)
		entry.add_child(control)
	add_child(entry)
	add_child(UI.label("전체 맵은 선택한 Land의 명시 좌표 또는 같은 Land의 저장 좌표가 필요합니다. 막힌 입장은 거부합니다.",12,UI.MUTED))
	source_portal_path = LineEdit.new(); source_portal_path.name = "AdenSourcePortalContractPath"
	source_portal_path.placeholder_text = "아덴 단일 모드 포탈 JSON · 전체 맵은 아래 정의 폴더 사용"
	add_child(source_portal_path)
	add_child(UI.label("전체 맵의 원문 포탈 정의 폴더 · 연결하면 다음 실행에도 확인해 사용합니다.",12,UI.MUTED))
	var definition_row:=HBoxContainer.new();add_child(definition_row)
	definition_path_edit=LineEdit.new();definition_path_edit.name="Current523SourceDefinitionPath"
	definition_path_edit.placeholder_text="world-links 폴더 · manifest.json이 있는 위치"
	definition_path_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;definition_row.add_child(definition_path_edit)
	definition_row.add_child(UI.button("폴더 선택",_browse.bind("definitions"),Vector2(100,40)))
	definition_connect_button=UI.button("원문 정의 확인 · 연결",_connect_definitions,Vector2(0,40));add_child(definition_connect_button)
	definition_clear_button=UI.button("정의 연결 해제 · 지형 이동만",_clear_definitions,Vector2(0,40));add_child(definition_clear_button)
	definition_status=UI.label("원문 포탈 정의 미연결 · 지형 이동만 가능",12,UI.MUTED)
	definition_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(definition_status)
	source_portal_list_button = UI.button("원문 포탈 목록 읽기 · 시간이 걸릴 수 있음",_list_source_portals,Vector2(0,40))
	source_portal_list_button.name = "ListAdenSourcePortalsButton"
	add_child(source_portal_list_button)
	source_portal_choice = OptionButton.new(); source_portal_choice.name = "AdenSourcePortalChoice"
	add_child(source_portal_choice)
	source_portal_walk_button=UI.button("원문 출발점까지 걷기 · 자동 포탈 활성 없음",_walk_to_source_portal,Vector2(0,40))
	source_portal_walk_button.name="WalkToCurrent523SourcePortalButton"
	add_child(source_portal_walk_button)
	source_portal_button = UI.button("현재 출발 셀의 원문 포탈 사용",_use_source_portal,Vector2(0,40))
	source_portal_button.name = "UseAdenSourcePortalButton"
	add_child(source_portal_button)
	var offsets := HBoxContainer.new()
	add_child(offsets)
	offsets.add_child(UI.label("표시 보정 X", 13))
	play_offset_x = _offset_control("AdenPlayOffsetX")
	offsets.add_child(play_offset_x)
	offsets.add_child(UI.label("Y", 13))
	play_offset_y = _offset_control("AdenPlayOffsetY")
	offsets.add_child(play_offset_y)
	var hint: Label = UI.label("보정은 화면에만 적용합니다. M 발 기준은 미확정이며 원본·캐릭터 위치는 바꾸지 않습니다.", 12, UI.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var actions := HBoxContainer.new()
	add_child(actions)
	play_button = UI.button("실험 플레이 시작", _open_play, Vector2(0, 42))
	play_button.name = "StartAdenPlayButton"
	actions.add_child(play_button)
	play_apply_button = UI.button("표시 보정 적용", _apply_play_options, Vector2(0, 42))
	play_apply_button.name = "ApplyAdenPlayOffsetButton"
	actions.add_child(play_apply_button)
	play_stop_button = UI.button("기존 지도 · 실험 해제", _stop_play, Vector2(0, 42))
	play_stop_button.name = "StopAdenPlayButton"
	actions.add_child(play_stop_button)
	play_status = UI.label("자체 통행 설정을 선택하면 아덴에서 실험 플레이를 시작할 수 있습니다.", 13, UI.MUTED)
	play_status.name = "AdenPlayStatus"
	play_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(play_status)
	_build_static_spr_controls()


func _build_static_spr_controls() -> void:
	var saved: Dictionary=STATIC_SPR.read_options()
	spr_enabled=CheckBox.new();spr_enabled.name="Current523StaticSPREnabled"
	spr_enabled.text="정적 SPR 표시 · 자체 해석"
	spr_enabled.tooltip_text="원문 ID/좌표와 SP2 픽셀을 연결합니다. 원작 배치/액션 동등성은 미확정입니다."
	spr_enabled.button_pressed=saved.enabled;add_child(spr_enabled)
	var row:=HBoxContainer.new();add_child(row)
	spr_root=_path_edit("Current523StaticSPRRoot");spr_root.text=saved.source_root
	spr_root.placeholder_text="989 원문 폴더 · results/와 selected_originals/가 있는 위치"
	row.add_child(spr_root);row.add_child(UI.button("폴더 선택",_browse.bind("static_spr"),Vector2(100,40)))
	spr_declaration=_path_edit("Current523StaticSPRDeclaration");spr_declaration.text=saved.declaration_path
	spr_declaration.placeholder_text="필수: SPR_reference_closure 폴더 또는 list_29.spr · 선언 없는 항목 제외"
	var declaration_row:=HBoxContainer.new();add_child(declaration_row)
	declaration_row.add_child(spr_declaration)
	declaration_row.add_child(UI.button("선언 폴더",_browse.bind("spr_declarations"),Vector2(100,40)))
	spr_actions=_path_edit("Current523StaticSPRActions")
	spr_actions.max_length=32768
	spr_actions.text=JSON.stringify(saved.action_overrides)
	spr_actions.placeholder_text='원문 동작 직접 지정 · 예: {"24590":9} · 미지정은3 · 자동 활성 판정 아님'
	add_child(spr_actions)
	spr_frame_bindings=_path_edit("Current523StaticSPRFrameBindings")
	spr_frame_bindings.max_length=131072
	spr_frame_bindings.text=JSON.stringify(saved.frame_bindings)
	spr_frame_bindings.placeholder_text='선택자별 파일/저장 그룹 직접 지정 · {"24590":{"8":{"member":"Sprite/24590-8.sp2","group_bit":0}}}'
	add_child(spr_frame_bindings)
	var values:=GridContainer.new();values.columns=2;add_child(values)
	spr_group=_spr_number(values,"저장 그룹",0,7,float(saved.group_bit))
	spr_fps=_spr_number(values,"자체 틱/초 · 0=정지",0,60,float(saved.fps))
	spr_anchor_x=_spr_number(values,"앵커 X",-48,48,float(saved.anchor_x))
	spr_anchor_y=_spr_number(values,"Y",-48,48,float(saved.anchor_y))
	spr_layer=_spr_number(values,"자체 레이어",-4095,-1,float(saved.layer))
	add_child(UI.button("SPR 설정 저장 · 현재 맵에 적용",_save_static_spr,Vector2(0,40)))
	spr_status=UI.label("보유 원문 픽셀만 사용합니다. 자식은 원문 참조 순서의 자체 합성·자체 동작 또는 보유 frame0을 사용하며 미해석 표시 속성은 자체 무시합니다. 선언 없는 항목은 제외하고 원작 합성·활성으로 표시하지 않습니다.",12,UI.MUTED)
	spr_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(spr_status)


func _spr_number(row: Container, label: String, low: float, high: float, value: float) -> SpinBox:
	row.add_child(UI.label(label,12))
	var number:=SpinBox.new();number.min_value=low;number.max_value=high;number.step=1;number.value=value
	number.custom_minimum_size=Vector2(78,36);row.add_child(number);return number


func _save_static_spr() -> void:
	var action_text: String=spr_actions.text.strip_edges()
	var actions: Variant={} if action_text.is_empty() else JSON.parse_string(action_text)
	if not actions is Dictionary:
		spr_status.text="원문 동작 지정은 SPR ID와 동작 번호의 JSON 객체여야 합니다. 이전 설정을 유지합니다.";return
	var binding_text: String=spr_frame_bindings.text.strip_edges()
	var bindings: Variant={} if binding_text.is_empty() else JSON.parse_string(binding_text)
	if not bindings is Dictionary:
		spr_status.text="파일/저장 그룹 지정은 SPR ID·원문 선택자별 JSON 객체여야 합니다. 이전 설정을 유지합니다.";return
	var value: Dictionary=STATIC_SPR.read_options()
	value.merge({"enabled":spr_enabled.button_pressed,"source_root":spr_root.text,"declaration_path":spr_declaration.text,"group_bit":int(spr_group.value),"fps":spr_fps.value,"anchor_x":int(spr_anchor_x.value),"anchor_y":int(spr_anchor_y.value),"layer":int(spr_layer.value),"action_overrides":actions,"frame_bindings":bindings},true)
	var current: Node=_world()
	if current!=null and current.has_method("apply_current523_static_spr_options"):
		var applied: bool=current.call("apply_current523_static_spr_options",value)
		if applied:
			spr_status.text="저장 · 보유 원문 픽셀과 자체 자식 표시 정책을 현재 맵 소비자에 연결했습니다." if bool(current.get("current523_aden_play_active")) else "저장됨 · 다음 원문 맵 입장에 적용합니다."
		else:spr_status.text=str(current.get("current523_aden_play_problem"))
		return
	var error: Error=STATIC_SPR.save_options(value)
	spr_status.text="저장됨 · 다음 원문 맵 입장에 적용합니다. 원문에 없는 동작·프레임은 표시하지 않습니다. 동작 선택·틱/초·앵커·레이어는 자체 설정입니다." if error==OK else "설정을 저장하지 못했습니다. 이전 설정과 현재 맵을 유지합니다: "+error_string(error)


func _offset_control(node_name: String) -> SpinBox:
	var control := SpinBox.new()
	control.name = node_name
	control.min_value = -PLAY_OPTIONS.OFFSET_LIMIT
	control.max_value = PLAY_OPTIONS.OFFSET_LIMIT
	control.step = 1
	control.suffix = "px"
	control.custom_minimum_size = Vector2(100, 36)
	return control


func _load_play_options(list_portals: bool = true) -> void:
	var options: Dictionary = PLAY_OPTIONS.read()
	play_profile.select(3 if options.navigation_profile==PLAY_OPTIONS.GENERIC else 2 if options.navigation_profile == PLAY_OPTIONS.SOURCE else (1 if options.navigation_profile == PLAY_OPTIONS.LEGACY else 0))
	if options.navigation_profile in [PLAY_OPTIONS.SOURCE,PLAY_OPTIONS.GENERIC]:
		var words: Array[String] = []
		for word: int in options.allowed_raw_words: words.append(str(word))
		source_words.text = ",".join(words)
		source_portal_path.text = options.portal_contract
		source_search_limit.value=options.get("path_search_limit",8192)
		aden_inferred_placement.button_pressed=options.get("aden_inferred_placement_enabled",true)
	if options.navigation_profile==PLAY_OPTIONS.GENERIC:
		source_manifest.text=options.source_manifest_sha256
		tile_manifest.text=options.tile_manifest_sha256
		raw_path_edit.text=options.raw_root; tile_path_edit.text=options.tile_root
		_reload_native_lands(int(options.native_land_id))
	play_offset_x.value = options.offset_x
	play_offset_y.value = options.offset_y
	var current: Node = _world()
	if current != null and bool(current.get("current523_aden_play_active")):
		raw_path_edit.text = options.raw_root
		tile_path_edit.text = options.tile_root
		play_status.text = "원문 S32 자체 통행 중 · M 원작 판정 미확정" if options.navigation_profile in [PLAY_OPTIONS.SOURCE,PLAY_OPTIONS.GENERIC] else "실험 플레이 중 · 이동과 충돌은 기존 TWILIGHT 자체 설정입니다."
		var map_metrics: Dictionary=current.current523_aden_play_metrics() if current.has_method("current523_aden_play_metrics") else {}
		var spr_metrics: Dictionary=map_metrics.get("static_spr",{})
		if not spr_metrics.is_empty():
			spr_status.text="원문 배치 %d · 연결 대상 %d · 사용자 제외 %d · 표시 노드 %d(부모%d/자식%d) · 미대응 노드%d. 제외·설정은 실제 사용 완료로 세지 않습니다."%[int(spr_metrics.get("raw_records",0)),int(spr_metrics.get("connection_candidate_records",spr_metrics.get("raw_records",0))),int(spr_metrics.get("user_excluded_records",0)),int(spr_metrics.get("drawn_records",0)),int(spr_metrics.get("drawn_parent_records",0)),int(spr_metrics.get("drawn_child_records",0)),int(spr_metrics.get("unresolved_records",0))]
	if list_portals or _portals_listed: _refresh_source_portals()
	_refresh_definition_status()


func _play_values() -> Dictionary:
	var saved: Dictionary = PLAY_OPTIONS.read()
	var value: Dictionary = {"navigation_profile":PLAY_OPTIONS.GENERIC if play_profile.selected==3 else PLAY_OPTIONS.SOURCE if play_profile.selected == 2 else (PLAY_OPTIONS.LEGACY if play_profile.selected == 1 else PLAY_OPTIONS.NONE), "portal_landing_policy":saved.get("portal_landing_policy",PLAY_OPTIONS.EXACT_POINT_ONLY), "map_time_policy":saved.get("map_time_policy",PLAY_OPTIONS.OWN_MAP_TIME), "map_open_policy":saved.get("map_open_policy",PLAY_OPTIONS.OWN_ALWAYS_OPEN_V1), "offset_x":int(play_offset_x.value), "offset_y":int(play_offset_y.value)}
	value["portal_fee_adena"]=saved.get("portal_fee_adena",PLAY_OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA)
	value["aden_return_radius"]=saved.get("aden_return_radius",8)
	if play_profile.selected in [2,3]:
		value.aden_inferred_placement_enabled=aden_inferred_placement.button_pressed
		value.path_search_limit=int(source_search_limit.value)
		value.allowed_raw_words = []
		for part: String in source_words.text.split(",",false):
			if not part.strip_edges().is_valid_int(): value.allowed_raw_words = []; break
			value.allowed_raw_words.append(int(part.strip_edges()))
		value.portal_contract = source_portal_path.text.strip_edges()
		var same_identity: bool=saved.navigation_profile==value.navigation_profile
		if play_profile.selected==3:
			value.source_manifest_sha256=source_manifest.text.strip_edges()
			value.tile_manifest_sha256=tile_manifest.text.strip_edges()
			value.native_land_id=native_land_choice.get_selected_id() if native_land_choice.selected>=0 else -1
			value.portal_contract=""
			same_identity=same_identity and saved.get("native_land_id",-1)==value.native_land_id and saved.get("source_manifest_sha256","")==value.source_manifest_sha256 and saved.raw_root==raw_path_edit.text.strip_edges()
		value.source_position = saved.get("source_position",[]) if same_identity else []
		if source_entry_enabled.button_pressed: value.source_position = [int(source_entry_x.value)+0.5,int(source_entry_y.value)+0.5]
	return value

func _refresh_definition_status() -> void:
	if not is_instance_valid(definition_status):return
	var current: Node=_world()
	if current==null or not current.has_method("current523_source_definition_selection"):return
	var stored: Dictionary=current.current523_source_definition_selection()
	if not stored.ok:definition_status.text=stored.problem;return
	if stored.configured and definition_path_edit.text.is_empty():definition_path_edit.text=stored.directory
	var status: Dictionary=current.current523_source_definition_status()
	if definition_path_edit.text.is_empty() and not status.is_empty():definition_path_edit.text=status.directory
	definition_status.text="원문 정의 연결됨 · 원작 활성·요금 판정은 미확정" if not status.is_empty() else ("저장된 원문 정의 미연결 · 입장 시 다시 확인하거나 폴더를 연결하세요." if stored.configured else "원문 포탈 정의 미연결 · 지형 이동만 가능")
func _connect_definitions() -> void:
	var current: Node=_world()
	if current==null or not current.has_method("bind_current523_source_definition_pack"):return
	if current.bind_current523_source_definition_pack(definition_path_edit.text.strip_edges(),DEFINITIONS.PIN,true):
		_refresh_definition_status();_refresh_listed_source_portals()
	else:definition_status.text="원문 정의를 연결하지 못했습니다: "+str(current.current523_aden_play_problem)
func _clear_definitions() -> void:
	var current: Node=_world()
	if current!=null and current.has_method("clear_current523_source_definition_selection"):
		if current.clear_current523_source_definition_selection():definition_path_edit.text="";_refresh_definition_status();_refresh_listed_source_portals()
		else:definition_status.text=str(current.current523_aden_play_problem)

func _list_source_portals() -> void:
	_refresh_source_portals()
	_update_open_button()

func _refresh_listed_source_portals() -> void:
	if _portals_listed: _refresh_source_portals(); return
	if is_instance_valid(source_portal_button):
		source_portal_button.text="TWILIGHT 자체 수동 이동 · 원작 활성 조건 미확정" if play_profile.selected==3 else "현재 출발 셀의 원문 포탈 사용"

func _refresh_source_portals() -> void:
	if not is_instance_valid(source_portal_choice): return
	_portals_listed = true
	source_portal_button.text="TWILIGHT 자체 수동 이동 · 원작 활성 조건 미확정" if play_profile.selected==3 else "현재 출발 셀의 원문 포탈 사용"
	var selected: int = source_portal_choice.get_selected_id() if source_portal_choice.item_count>0 else -1
	source_portal_choice.clear()
	var current: Node = _world()
	if current == null or not current.has_method("current523_aden_source_portals"): return
	for row: Dictionary in current.call("current523_aden_source_portals"):
		var note: String = ("원문 조건 보류" if not str(row.get("definition_hold","")).is_empty() else "자체 수동 · 사용 시 양끝 검사") if play_profile.selected==3 else ("원문 양끝 대조" if row.get("activation_candidate",false) else "보류")
		var inactive: Array=row.get("declared_inactive_restrictions",[])
		if not inactive.is_empty(): note+=" · 원문 "+", ".join(inactive)
		var level_notes: Array=row.get("actor_level_notes",[])
		if not level_notes.is_empty():note+=" · "+" / ".join(level_notes)
		var calendar_notes: Array=row.get("calendar_notes",[])
		if not calendar_notes.is_empty():note+=" · "+" / ".join(calendar_notes)
		if row.get("landing_position")==null and row.get("configured_arrival_policy")==PLAY_OPTIONS.OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1:
			note+=" · 자체 영역 착지 선택 후 조건 판정"
		source_portal_choice.add_item("%d · %s → %s · %s" % [int(row.id),str(row.source_position),("Land%d · " % int(row.target_land_id) if row.has("target_land_id") else "")+str(row.get("landing_position")),note],int(row.id))
		source_portal_choice.set_item_tooltip(source_portal_choice.item_count-1,source_portal_choice.get_item_text(source_portal_choice.item_count-1))
		source_portal_choice.set_item_metadata(source_portal_choice.item_count-1,row.get("navigation_ticket",{}))
		if int(row.id)==selected: source_portal_choice.select(source_portal_choice.item_count-1)

func _walk_to_source_portal() -> void:
	var current: Node=_world()
	if current==null or source_portal_choice.item_count==0: return
	var ticket: Variant=source_portal_choice.get_item_metadata(source_portal_choice.selected)
	if ticket is Dictionary and current.call("walk_to_current523_source_portal",source_portal_choice.get_selected_id(),ticket):
		current.hud.workspace.hide()

func _use_source_portal() -> void:
	var current: Node = _world()
	if current != null and source_portal_choice.item_count>0:
		current.call("use_current523_aden_source_portal",source_portal_choice.get_selected_id())


func _play_choice_changed(_index: int) -> void:
	_refresh_listed_source_portals()
	_update_open_button()


func _open_play() -> void:
	if installer.busy: return
	var current: Node = _world()
	if current == null or not current.has_method("open_current523_aden_play"): return
	var opened: bool = bool(current.call("open_current523_aden_play", raw_path_edit.text.strip_edges(), tile_path_edit.text.strip_edges(), _play_values()))
	if opened:
		var hud: Variant = current.get("hud")
		if is_instance_valid(hud) and is_instance_valid(hud.workspace): hud.workspace.hide()
	else:
		play_status.text = "실험 플레이를 열지 못했습니다: " + str(current.get("current523_aden_play_problem"))
	_update_open_button()


func _apply_play_options() -> void:
	var current: Node = _world()
	if current != null and current.has_method("apply_current523_aden_play_options"):
		current.call("apply_current523_aden_play_options", _play_values())


func _stop_play() -> void:
	var current: Node = _world()
	if current != null and current.has_method("close_current523_aden_play"):
		current.call("close_current523_aden_play")


func _on_play_changed(active: bool, detail: String) -> void:
	if active: _load_play_options()
	else: _refresh_source_portals()
	play_status.text = detail
	_update_open_button()


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
	if current != null and current.has_signal("current523_aden_play_changed") and current.is_connected("current523_aden_play_changed", _on_play_changed):
		current.disconnect("current523_aden_play_changed", _on_play_changed)


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
	var busy: bool = is_instance_valid(installer) and installer.busy
	var playing: bool = current != null and bool(current.get("current523_aden_play_active"))
	open_button.disabled = busy or playing or current == null or not current.has_method("open_current523_aden_review_ui") or raw_path_edit.text.strip_edges().is_empty() or tile_path_edit.text.strip_edges().is_empty()
	if is_instance_valid(install_button):
		install_button.disabled = busy or playing
		cancel_button.disabled = not busy
		rollback_button.disabled = busy or playing or PREFERENCES.selection(true).raw.is_empty()
		raw_path_edit.editable = not busy and not playing
		tile_path_edit.editable = not busy and not playing
		raw_browse_button.disabled = busy or playing
		tile_browse_button.disabled = busy or playing
	if is_instance_valid(play_button):
		play_button.disabled = busy or playing or current == null or not current.has_method("open_current523_aden_play") or play_profile.selected not in [1,2,3] or raw_path_edit.text.strip_edges().is_empty() or tile_path_edit.text.strip_edges().is_empty()
		play_apply_button.disabled = busy or not playing
		play_stop_button.disabled = busy or (not playing and not PLAY_OPTIONS.read().enabled)
		play_profile.disabled = busy or playing
		play_offset_x.editable = not busy
		play_offset_y.editable = not busy
		source_words.editable = not busy and not playing
		source_search_limit.editable = not busy and not playing
		source_portal_path.editable = not busy and not playing and play_profile.selected!=3
		source_entry_enabled.disabled = busy or playing
		source_entry_x.editable = not busy and not playing
		source_entry_y.editable = not busy and not playing
		source_portal_button.disabled = busy or not playing or source_portal_choice.item_count==0
		source_portal_walk_button.disabled = busy or not playing or play_profile.selected!=3 or source_portal_choice.item_count==0


func _browse_zip() -> void:
	zip_dialog.popup_centered_ratio(0.8)


func _install_zip(path: String) -> void:
	if installer.busy: return
	folder_dialog.hide()
	_folder_target = ""
	if not installer.start(path):
		status_label.text = "설치를 시작하지 못했습니다: " + str(installer.problem)
	_update_open_button()


func _cancel_install() -> void:
	installer.cancel()


func _install_progress(stage: String, done: int, total: int) -> void:
	var percent: int = int(100.0 * done / maxi(1, total))
	status_label.text = "원본 팩 설치: %s (%d%%)" % [str(INSTALL_STAGES.get(stage, "확인 중")), percent]


func _install_finished(result: Dictionary) -> void:
	if result.get("ok", false):
		var saved: Dictionary = PREFERENCES.activate(str(result.raw_root), str(result.tile_root))
		if saved.ok:
			raw_path_edit.text = result.raw_root
			tile_path_edit.text = result.tile_root
			status_label.text = "원본 팩 설치와 경로 설정이 완료되었습니다. '아덴 원문 보기'로 열어 주세요."
		else:
			status_label.text = "파일 설치는 완료되었습니다. " + str(saved.problem)
	else:
		status_label.text = "설치를 취소했습니다. 기존 팩을 계속 사용합니다." if result.get("cancelled", false) else "설치하지 못했습니다: " + str(result.get("problem", "알 수 없는 오류"))
	if result.has("cleanup_pending"):
		status_label.text += " 임시 설치 파일 정리가 필요합니다: " + str(result.cleanup_pending)
	_update_open_button()


func _rollback() -> void:
	if installer.busy: return
	var result: Dictionary = PREFERENCES.rollback()
	if result.ok:
		raw_path_edit.text = result.raw
		tile_path_edit.text = result.tiles
		status_label.text = "이전 팩 경로로 돌아왔습니다. '아덴 원문 보기'로 열어 주세요."
	else:
		status_label.text = str(result.problem)
	_update_open_button()


func _browse(target: String) -> void:
	_folder_target = target
	folder_dialog.title = "전역 SPR 선언 폴더 선택" if target=="spr_declarations" else ("정적 SPR 원문 폴더 선택" if target=="static_spr" else ("원문 포탈 정의 폴더 선택" if target=="definitions" else ("아덴 원문 팩 폴더 선택" if target == "raw" else "타일 검토 팩 폴더 선택")))
	var path: String = spr_declaration.text if target=="spr_declarations" else (spr_root.text if target=="static_spr" else (definition_path_edit.text if target=="definitions" else (raw_path_edit.text if target == "raw" else tile_path_edit.text)))
	path = ProjectSettings.globalize_path(path.strip_edges())
	if not path.is_empty() and DirAccess.dir_exists_absolute(path):
		folder_dialog.current_dir = path
	folder_dialog.popup_centered_ratio(0.8)


func _folder_selected(path: String) -> void:
	if _folder_target == "raw":
		raw_path_edit.text = path
	elif _folder_target == "tiles":
		tile_path_edit.text = path
	elif _folder_target == "definitions":
		definition_path_edit.text=path
	elif _folder_target == "static_spr":
		spr_root.text=path
	elif _folder_target == "spr_declarations":
		spr_declaration.text=path
	_folder_target = ""
	_update_open_button()
	_refresh_path_status()


func _folder_cancelled() -> void:
	_folder_target = ""


func _open_review() -> void:
	if is_instance_valid(installer) and installer.busy: return
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
		var saved: Dictionary = PREFERENCES.activate(raw, tiles)
		if is_instance_valid(status_label) and not is_queued_for_deletion():
			status_label.text = "아덴 원문 검토를 열었습니다." if saved.ok else "아덴 원문 검토를 열었습니다. " + str(saved.problem)
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
	if not is_visible_in_tree() and is_instance_valid(zip_dialog):
		zip_dialog.hide()
		if is_instance_valid(installer) and installer.busy:
			installer.cancel()
	_update_open_button()


func _exit_tree() -> void:
	_disconnect_world()
	_world_ref = null
	_folder_target = ""
	if is_instance_valid(folder_dialog):
		folder_dialog.hide()
	if is_instance_valid(zip_dialog):
		zip_dialog.hide()

func _reload_native_lands(preferred_id: int = -1) -> void:
	if not is_instance_valid(native_land_choice): return
	var previous_id: int=native_land_choice.get_selected_id() if native_land_choice.item_count>0 else -1
	if preferred_id<0: preferred_id=previous_id
	native_land_choice.clear()
	var script: Script=load("res://scripts/maps/current523_source_pack.gd")
	var directory: String=raw_path_edit.text.strip_edges()
	var pin: String=source_manifest.text.strip_edges().to_lower()
	# Revalidate bytes on every refresh; parse only a new verified identity.
	# A rejected candidate must not replace the previously valid catalog.
	var catalog: RefCounted=_native_catalog
	var same_catalog: bool=catalog!=null and catalog.matches_manifest(directory,pin)
	if not same_catalog:
		var candidate: RefCounted=script.new()
		if not candidate.load_catalog(directory,pin):
			native_scope_status.text="카탈로그 확인 실패: "+str(candidate.problem)
			if is_instance_valid(source_entry_enabled): source_entry_enabled.button_pressed=false
			return
		_native_catalog=candidate; _native_catalog_loads+=1; catalog=candidate
	var ready_lands: int=0
	var included_lands: int=0
	for row: Dictionary in catalog.catalog_lands():
		if row.policy_status!="classified" or not row.excluded_content.is_empty(): continue
		var declaration: Dictionary=row.declaration
		var asset: Dictionary=catalog.asset_record(str(declaration.AssetPath))
		var ready: int=int(asset.get("ready_count",0))
		included_lands+=1
		if ready>0: ready_lands+=1
		native_land_choice.add_item("%d · %s · %s · 원문 %d/%d" % [int(declaration.ID),str(declaration.Name),str(declaration.AssetPath),ready,int(asset.get("source_count",0))],int(declaration.ID))
		if int(declaration.ID)==preferred_id: native_land_choice.select(native_land_choice.item_count-1)
	if is_instance_valid(source_entry_enabled) and (not same_catalog or native_land_choice.get_selected_id()!=previous_id):
		source_entry_enabled.button_pressed=false
	native_scope_status.text="범위 내 논리 Land %d개 · 실제 원문이 일부라도 있는 Land %d개. 공유 폴더와 논리 지역은 별개이며 미수신 셀은 거부합니다." % [included_lands,ready_lands]

func _native_land_changed(_index: int) -> void:
	# A cursor from a different logical Land must never become an implicit entry.
	source_entry_enabled.button_pressed=false
