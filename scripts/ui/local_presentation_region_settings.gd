extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
var source_view: Node
var host: Node
var world: Node
var radius: SpinBox
var branch: OptionButton
var enabled: CheckButton
var save_button: Button
var remove_button: Button
var status: Label

func configure(view: Node) -> void:
	name = "LocalPresentationRegionSettings"
	source_view = view
	host = view.host_settings
	world = view.world
	add_child(UI.label("자체 영역 자동 적용",16,UI.GOLD))
	add_child(UI.section("원본 M 좌표가 아닌 현재 위치의 정사각형 영역입니다. 영역 안에서는 지역 설정보다 우선하며, 밖에서는 원래 표시로 돌아갑니다.",12))
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(UI.label("정사각 반폭 · 자체값",12))
	radius = SpinBox.new()
	radius.name = "LocalPresentationRadius"
	radius.min_value = 16
	radius.max_value = 4096
	radius.step = 16
	radius.value = 256
	radius.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(radius)
	branch = OptionButton.new()
	branch.name = "LocalPresentationBranch"
	branch.add_item("선택한 원본 구역의 기본 표시값")
	branch.add_item("선택한 원본 조건값 · 자체 수동 선택")
	add_child(branch)
	add_child(UI.section("조건값 선택은 공성/핫타임의 실제 활성 판정이 아닙니다. 반경 256은 게임 편의용 초기값이며 원본 경계·거리로 사용하지 않습니다.",12))
	save_button = UI.button("현재 위치에 자체 영역 저장",_save,Vector2(240,44))
	save_button.name = "SaveLocalPresentationRegion"
	add_child(save_button)
	enabled = CheckButton.new()
	enabled.name = "EnableLocalPresentationRegion"
	enabled.text = "현재 게임 지역의 자체 영역 사용"
	enabled.toggled.connect(_toggle)
	add_child(enabled)
	remove_button = UI.button("현재 게임 지역의 자체 영역 삭제",_remove,Vector2(240,44))
	remove_button.name = "RemoveLocalPresentationRegion"
	add_child(remove_button)
	status = UI.section("",12)
	status.name = "LocalPresentationStatus"
	add_child(status)
	refresh()

func refresh() -> void:
	var rule: Dictionary = world.local_presentation_regions.get(str(world.active_map_id),{})
	enabled.set_pressed_no_signal(bool(rule.get("enabled",false)))
	enabled.disabled = rule.is_empty()
	remove_button.disabled = rule.is_empty()
	if not rule.is_empty(): radius.set_value_no_signal(float(rule.radius))
	var selected: int = -1 if source_view.regions.item_count==0 else int(source_view.regions.get_item_metadata(source_view.regions.selected))
	if not rule.is_empty() and int(rule.row_id)==selected: branch.select(1 if rule.branch=="condition" else 0)
	var row: Dictionary = world.source_optimization.by_id.get(selected,{})
	save_button.disabled = row.is_empty()
	branch.set_item_disabled(1,row.is_empty() or int(row.get("ConditionTypeId",0))==0)
	if branch.is_item_disabled(1) and branch.selected==1: branch.select(0)
	_update_status()

func _process(_delta: float) -> void:
	if is_instance_valid(status): _update_status()

func _update_status() -> void:
	var rule: Dictionary = world.local_presentation_regions.get(str(world.active_map_id),{})
	if rule.is_empty():
		status.text = "자체 영역 없음 · 원본 M 좌표 자동 적용과 별개입니다."
		return
	var state: String = str(world.local_presentation_result.get("status","off"))
	var label: String = "적용 중" if state=="TWILIGHT_local_estimate" else ("영역 밖" if state=="outside" else ("꺼짐" if state=="off" else "원본 설정 확인 필요"))
	status.text = "TWILIGHT 자체 영역 · %s · 구역%d · 중심(%.0f, %.0f) ± %.0f · %s" % [label,int(rule.row_id),rule.center.x,rule.center.y,float(rule.radius),"조건값 수동 선택" if rule.branch=="condition" else "원본 기본값"]

func _commit(rule: Dictionary, erase: bool = false) -> bool:
	var map_id: String = str(world.active_map_id)
	var changes: Array = [{"section":"presentation_local_regions","key":map_id,"value":rule,"erase":erase}]
	if not erase: changes.append({"section":"source_optimization","key":"selected_row_id","value":int(rule.row_id)})
	if host.store_presentation_preferences(changes)!=OK:
		source_view.status.text = "자체 영역을 저장하지 못했습니다. 기존 설정을 유지합니다."
		enabled.set_pressed_no_signal(bool(world.local_presentation_regions.get(map_id,{}).get("enabled",false)))
		return false
	world.set_local_presentation_region(map_id,rule,erase)
	refresh()
	source_view.status.text = "자체 영역을 삭제했습니다." if erase else "TWILIGHT 자체 영역을 저장했습니다."
	return true

func _save() -> void:
	if source_view.regions.item_count==0 or not is_instance_valid(world.player): return
	_commit({"enabled":true,"center":world.player.global_position,"radius":radius.value,
		"row_id":int(source_view.regions.get_item_metadata(source_view.regions.selected)),"branch":"condition" if branch.selected==1 else "default"})

func _toggle(value: bool) -> void:
	var rule: Dictionary = world.local_presentation_regions.get(str(world.active_map_id),{}).duplicate(true)
	if rule.is_empty(): return
	rule.enabled = value
	_commit(rule)

func _remove() -> void: _commit({},true)
