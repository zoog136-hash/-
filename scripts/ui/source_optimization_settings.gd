extends VBoxContainer
## Source recommendations are an explicit user choice, never a PC/M map alias.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var host_settings: Node
var world: Node
var status: Label
var definition: Label
var regions: OptionButton
var apply_button: Button
var automatic: CheckButton
var directory_dialog: FileDialog
var choose_button: Button
var zip_button: Button
var local_regions: Node
var effect_settings: Node

func configure(host: Node) -> void:
	name = "SourceOptimizationSettings"
	host_settings = host
	world = host.hud.get_parent()
	add_child(UI.label("원본 지역 권장 설정",18,UI.GOLD))
	add_child(UI.section("523 원본 폴더를 선택하고, 원하는 구역의 기본값을 현재 지역에 적용할 수 있습니다.",12))
	zip_button = UI.button("검증된523 원본 자료 ZIP 선택",func() -> void: _choose_directory(false),Vector2(240,44))
	zip_button.name = "SourceOptimizationChooseZIP"
	add_child(zip_button)
	choose_button = UI.button("523 원본 설정 폴더 선택",_choose_directory,Vector2(220,44))
	choose_button.name = "SourceOptimizationChooseFolder"
	add_child(choose_button)
	status = UI.section("",12)
	status.name = "SourceOptimizationStatus"
	add_child(status)
	regions = OptionButton.new()
	regions.name = "SourceOptimizationRegions"
	regions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regions.get_popup().max_size = Vector2i(800,350)
	regions.item_selected.connect(func(_index: int) -> void: _show_definition())
	add_child(regions)
	definition = UI.section("",12)
	definition.name = "SourceOptimizationDefinition"
	add_child(definition)
	apply_button = UI.button("선택한 구역의 기본 권장값 적용",_apply_selected,Vector2(260,44))
	apply_button.name = "ApplySourceOptimization"
	add_child(apply_button)
	automatic = CheckButton.new()
	automatic.name = "AutomaticSourceOptimization"
	automatic.text = "원본 M 좌표에 따라 자동 적용"
	automatic.set_pressed_no_signal(bool(world.presentation_global_settings.get("source_region_optimization",false)))
	automatic.toggled.connect(_automatic_changed)
	add_child(automatic)
	local_regions = preload("res://scripts/ui/local_presentation_region_settings.gd").new()
	add_child(local_regions)
	local_regions.configure(self)
	effect_settings = preload("res://scripts/ui/presentation_effect_settings.gd").new()
	add_child(effect_settings)
	effect_settings.configure(self)
	_refresh()

func _choose_directory(folder: bool = true) -> void:
	if is_instance_valid(directory_dialog): directory_dialog.queue_free()
	directory_dialog = FileDialog.new()
	directory_dialog.name = "SourceOptimizationDirectoryDialog"
	directory_dialog.access = FileDialog.ACCESS_FILESYSTEM
	directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if folder else FileDialog.FILE_MODE_OPEN_FILE
	if not folder: directory_dialog.add_filter("*.zip","523 원본 자료")
	directory_dialog.title = "523 원본 Content 폴더 선택"
	directory_dialog.dir_selected.connect(_load_directory)
	directory_dialog.file_selected.connect(_load_directory)
	host_settings.hud.get_node("Root").add_child(directory_dialog)
	directory_dialog.popup_centered_ratio(0.8)

func _load_directory(path: String) -> void:
	var result: Dictionary = world.load_source_optimization(path,func(selected: String) -> Error:
		return host_settings.store_presentation_preferences([{"section":"source_optimization","key":"path","value":selected}]))
	if not bool(result.ok):
		status.text = str(result.error) + " · 기존 설정을 유지합니다."
		return
	_refresh()

func _automatic_changed(enabled: bool) -> void:
	if host_settings.store_presentation_preferences([{"section":"visual","key":"source_region_optimization","value":enabled}])!=OK:
		automatic.set_pressed_no_signal(bool(world.presentation_global_settings.get("source_region_optimization",false)))
		status.text = "자동 적용 설정을 저장하지 못했습니다. 기존 설정을 유지합니다."
		return
	world.apply_presentation_settings({"source_region_optimization":enabled})

func _refresh() -> void:
	regions.clear()
	var rules = world.source_optimization
	var selected: int = int(host_settings.config.get_value("source_optimization","selected_row_id",-1))
	for row: Dictionary in rules.territories:
		regions.add_item("원본 지역 %d · 구역 %d" % [int(row.LandID),int(row.ID)])
		regions.set_item_metadata(regions.item_count-1,int(row.ID))
		if int(row.ID)==selected: regions.select(regions.item_count-1)
	apply_button.disabled = regions.item_count==0
	regions.disabled = apply_button.disabled
	var field: Variant = world.get("field_map")
	var context_available: bool = field != null and field.has_method("lineagem_m_presentation_context")
	automatic.disabled = apply_button.disabled or not context_available
	status.text = "원본 설정 미선택" if apply_button.disabled else "%d구역·%d지역·간소화 매핑%d개 연결" % [rules.territories.size(),rules.by_land.size(),rules.simplify.size()]
	if not context_available: status.text += " · 현재 지도 자동 감지는 M 좌표 검증 대기"
	_show_definition()

func _show_definition() -> void:
	if is_instance_valid(local_regions): local_regions.refresh()
	if regions.item_count==0:
		definition.text = "원본 폴더를 선택해 주세요. 게임 기본 설정은 유지됩니다."
		return
	var id: int = int(regions.get_item_metadata(regions.selected))
	var row: Dictionary = world.source_optimization.by_id[id]
	definition.text = "기본값: 이펙트 %s · 인형 %s" % ["적게" if row.DefaultLowEffectCount else "기존 표시량","숨김" if row.DefaultHideMagicDoll else "표시"]
	if int(row.ConditionTypeId)!=0:
		var label: String = "공성 진행" if int(row.ConditionTypeId)==1 else "라스타바드 핫타임"
		definition.text += "\n조건(%s): 이펙트 %s · 인형 %s" % [label,"적게" if row.ConditionLowEffectCount else "기존 표시량","숨김" if row.ConditionHideMagicDoll else "표시"]
		definition.text += " · 조건의 자동 판정은 미연결" if world.source_optimization.condition_changes_settings(id) else " · 조건 전후 표시값 동일"
	definition.text += "\n원본 좌표: (%d, %d) ~ (%d, %d)" % [int(row.StartX),int(row.StartY),int(row.EndX),int(row.EndY)]
	if row.StartX==row.EndX or row.StartY==row.EndY: definition.text += " · 경계 판정 대기"
	definition.text += "\n간소화 외형은 기존 세부 표현 선택을 따릅니다."

func _apply_selected() -> void:
	if regions.item_count==0: return
	var id: int = int(regions.get_item_metadata(regions.selected))
	var values: Dictionary = world.presentation_settings.duplicate(true)
	values.merge(world.source_optimization.defaults_for(id),true)
	values = preload("res://scripts/animation/presentation_preferences.gd").region(values)
	if host_settings.store_presentation_preferences([
		{"section":"visual_regions","key":host_settings.presentation_map_id,"value":values},
		{"section":"source_optimization","key":"selected_row_id","value":id}])!=OK:
		status.text = "지역 설정을 저장하지 못했습니다. 기존 설정을 유지합니다."
		return
	host_settings.region_override.set_pressed_no_signal(true)
	world.set_region_presentation_settings(host_settings.presentation_map_id,values)
	host_settings._sync_presentation_controls()
	status.text = "원본 구역%d 기본값을 현재 지역에 적용했습니다." % id
