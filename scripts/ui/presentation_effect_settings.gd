extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
var host: Node
var world: Node
var status: Label
var choose_button: Button
var play_button: Button
var enabled: CheckButton
var action: OptionButton
var dialog: FileDialog
var preview: Node2D
var preview_area: Control
var freeze: CheckButton
var last_preview: Dictionary = {}

func configure(view: Node) -> void:
	name = "PresentationEffectSettings"
	host = view.host_settings
	world = view.world
	add_child(UI.label("간소화 효과 · 자체 해석",16,UI.GOLD))
	add_child(UI.section("실제 SP2 원문에서 만든 후보입니다. 기하·알파·블렌드·한 번 재생은 자체 해석이며 M 원작 동작 검증이 아닙니다. 선택한 원본 action의 틱과 FPS는 보존합니다.",12))
	choose_button = UI.button("자체 해석 효과 폴더 선택",_choose,Vector2(230,44))
	choose_button.name = "ChoosePresentationEffectPack"
	add_child(choose_button)
	action = OptionButton.new()
	action.name = "PresentationEffectAction"
	action.add_item("원본 action0 · walk · 한 번 보기(자체)")
	action.add_item("원본 action3 · breath · 한 번 보기(자체)")
	action.select(1 if world.presentation_effect_action==3 else 0)
	action.item_selected.connect(_action_changed)
	add_child(action)
	enabled = CheckButton.new()
	enabled.name = "EnablePresentationEffectCandidate"
	enabled.text = "24941 효과 호출에 자체 해석 사용 · 기본 꺼짐"
	enabled.set_pressed_no_signal(world.presentation_effect_enabled)
	enabled.toggled.connect(_enabled_changed)
	add_child(enabled)
	play_button = UI.button("현재 전체/간소화 선택으로 효과 보기",_play,Vector2(270,44))
	play_button.name = "PlayPresentationEffect"
	add_child(play_button)
	freeze = CheckButton.new()
	freeze.name = "FreezePresentationEffect"
	freeze.text = "미리보기 중간 프레임 고정 · 자체 보기"
	add_child(freeze)
	preview_area = PanelContainer.new()
	preview_area.name = "PresentationEffectPreviewArea"
	preview_area.custom_minimum_size.y = 220
	preview_area.clip_contents = true
	preview_area.resized.connect(_fit_preview)
	add_child(preview_area)
	status = UI.section("",12)
	status.name = "PresentationEffectStatus"
	add_child(status)
	_refresh()

func _choose() -> void:
	if is_instance_valid(dialog): dialog.queue_free()
	dialog = FileDialog.new()
	dialog.name = "PresentationEffectDirectoryDialog"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.dir_selected.connect(_load_directory)
	host.hud.get_node("Root").add_child(dialog)
	dialog.popup_centered_ratio(0.8)

func _load_directory(path: String) -> void:
	var result: Dictionary = world.load_presentation_effect_pack(path,func(value: String) -> Error:
		return host.store_presentation_preferences([{"section":"presentation_effect","key":"path","value":value}]))
	if not bool(result.ok): status.text = str(result.error);return
	_refresh()

func _action_changed(index: int) -> void:
	var value: int = 3 if index==1 else 0
	if host.store_presentation_preferences([{"section":"presentation_effect","key":"action","value":value}])!=OK:
		action.select(1 if world.presentation_effect_action==3 else 0)
		status.text = "효과 선택을 저장하지 못했습니다. 기존 선택을 유지합니다."
		return
	world.presentation_effect_action = value
	_refresh()

func _enabled_changed(value: bool) -> void:
	if host.store_presentation_preferences([{"section":"presentation_effect","key":"enabled","value":value}])!=OK:
		enabled.set_pressed_no_signal(world.presentation_effect_enabled)
		status.text = "효과 설정을 저장하지 못했습니다. 기존 선택을 유지합니다."
		return
	world.presentation_effect_enabled = value
	_refresh()

func _refresh() -> void:
	var ready: bool = not world.presentation_effect_pack.manifests.is_empty()
	play_button.disabled = not ready
	enabled.disabled = not ready
	preview_area.visible = ready
	status.text = "자체 해석 효과 후보 준비 · 원작 렌더/실전 트리거 검증 아님" if ready else "효과 후보 폴더 미선택 · 기존 효과 유지"

func _play() -> void:
	if is_instance_valid(preview): preview.clear();preview.queue_free()
	preview = PREVIEW.new()
	preview_area.add_child(preview)
	preview._manifest_path = world.presentation_effect_pack.manifests.get(world.presentation_effect_action,"")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(preview._manifest_path))
	preview._manifest_records = index.records
	preview._root = preview._manifest_path.get_base_dir()
	preview._playback_mode = "compatible"
	if not preview.spawn_source_overlay(24941,int(world.player.facing)):
		status.text = "효과 후보를 표시하지 못했습니다. 기존 효과를 유지합니다."
		return
	var selected: int = int(preview._overlay_nodes.back().get_meta("selected_source_effect"))
	var overlay: Node2D = preview._overlay_nodes.back()
	if freeze.button_pressed:
		overlay.set_process(false)
		var total: float = 0.0
		for frame: Dictionary in overlay._playback_tracks.idle.directions[0]: total+=float(frame.duration)
		overlay.advance_source(total*0.5,"idle",int(world.player.facing),0,false)
	last_preview = {"selected":selected,"action":int(overlay._record.tracks.idle.source_action_id),
		"attachments":overlay.attachment_status(),"frame":overlay.last_source_frame}
	_fit_preview()
	status.text = "자체 해석 미리보기 · 효과%d · action%d · 원본 전투 판정/재화 변화 없음" % [selected,world.presentation_effect_action]
	host.find_child("SettingsScroll",true,false).ensure_control_visible(preview_area)

func _fit_preview() -> void:
	if not is_instance_valid(preview) or preview._overlay_nodes.is_empty(): return
	var overlay: Node2D = preview._overlay_nodes.back()
	if not is_instance_valid(overlay): return
	var bounds := Rect2()
	var found: bool = false
	var sprites: Array = overlay._layers.duplicate()
	sprites.append_array(overlay._effect_nodes.values())
	for sprite: Sprite2D in sprites:
		if sprite.texture==null: continue
		var rect := Rect2(sprite.position,sprite.texture.get_size())
		bounds = bounds.merge(rect) if found else rect
		found = true
	if not found or bounds.size.x<=0 or bounds.size.y<=0: return
	var fit: float = minf(1.0,minf(maxf(1.0,preview_area.size.x-24.0)/bounds.size.x,maxf(1.0,preview_area.size.y-24.0)/bounds.size.y))
	overlay.scale = Vector2.ONE*fit
	overlay.position = preview_area.size*0.5-bounds.get_center()*fit

func _exit_tree() -> void:
	if is_instance_valid(preview): preview.clear();preview.queue_free()
	if is_instance_valid(dialog): dialog.queue_free()
