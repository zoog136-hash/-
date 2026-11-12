extends VBoxContainer

# Presentation options and character-specific consumable safety controls.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Dialog = preload("res://scripts/ui/renewal_dialog.gd")
const SETTINGS_PATH = "user://twilight_ui_settings.cfg"
const PREFS = preload("res://scripts/animation/presentation_preferences.gd")
const SPX = preload("res://addons/twilight_l1j/twilight_external_spx_actor.gd")
var hud: Node
var config: ConfigFile = ConfigFile.new()
var volume: HSlider
var mute: CheckButton
var map_visual_mode: OptionButton
var spx_actor_mode: OptionButton
var impact_intensity: HSlider
var impact_readout: Label
var reduced_motion: CheckButton
var effect_detail: OptionButton
var hide_doll: CheckButton
var limit_effect_count: CheckButton
var region_override: CheckButton
var presentation_map_id: String = ""
var presentation_status: Label

static func apply_saved(controller: Node) -> void:
	var saved := ConfigFile.new()
	var load_error: Error = saved.load(SETTINGS_PATH)
	UI.set_reduced_motion(bool(saved.get_value("visual","reduced_motion",false)))
	if load_error != OK: return
	if controller.log_label != null:
		controller.log_label.visible = bool(saved.get_value("interface","combat_log",true))
	if controller.coordinates_readout != null:
		controller.coordinates_readout.visible = bool(saved.get_value("interface","coordinates",true))
	if AudioServer.get_bus_count() > 0:
		var level := clampf(float(saved.get_value("audio","volume",100.0)),0.0,100.0)
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,level/100.0)))
		AudioServer.set_bus_mute(0,bool(saved.get_value("audio","muted",false)) or level <= 0.0)

func configure(controller: Node) -> void:
	name = "RenewalSettings"
	hud = controller
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config.load(SETTINGS_PATH)
	presentation_map_id = str(hud.get_parent().get("active_map_id"))
	var scroller := ScrollContainer.new()
	scroller.name = "SettingsScroll"
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroller)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",12)
	scroller.add_child(stack)
	stack.add_child(UI.section("환경 설정",17))
	stack.add_child(UI.section("스킬 아이콘: Lorc · Delapouite / Game-icons.net (CC BY 3.0)", 10))
	stack.add_child(UI.section("게임 화면 · 오디오 · 저장",12))
	stack.add_child(preload("res://scripts/ui/lineagem_pack_settings.gd").new())
	var source_pack: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Source523Pack")
	if source_pack != null:
		# Always shown: the player sees whether the pack and each add-on are
		# connected, and can (re)install from here even when connection failed.
		if source_pack.has_method("status_lines"):
			var pack_state := UI.label("\n".join(source_pack.call("status_lines")), 15)
			pack_state.name = "SourcePackStatus"
			pack_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(pack_state)
		var addon_button := Button.new()
		addon_button.name = "InstallSourceAddon"
		addon_button.text = "추가 리소스(.zip) 설치·업데이트"
		addon_button.custom_minimum_size = Vector2(0,48)
		addon_button.pressed.connect(func() -> void: source_pack.call("open_addon_installer"))
		stack.add_child(addon_button)
	var aden_review := preload("res://scripts/ui/current523_aden_review_settings.gd").new()
	stack.add_child(aden_review)
	aden_review.configure(hud.get_parent())
	stack.add_child(preload("res://scripts/ui/patch523_drop_settings.gd").new())
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("오디오",18,UI.GOLD))
	var audio := HBoxContainer.new()
	stack.add_child(audio)
	audio.add_child(UI.label("전체 음량",14))
	volume = HSlider.new()
	volume.name = "MasterVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.x = 120
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value = float(config.get_value("audio","volume",100.0))
	volume.value_changed.connect(_volume_changed)
	audio.add_child(volume)
	mute = CheckButton.new()
	mute.text = "음소거"
	mute.button_pressed = bool(config.get_value("audio","muted",false))
	mute.toggled.connect(_mute_changed)
	audio.add_child(mute)
	stack.add_child(HSeparator.new())
	var regional_settings := preload("res://scripts/ui/regional_return_settings.gd").new()
	regional_settings.configure(hud)
	stack.add_child(regional_settings)
	stack.add_child(HSeparator.new())
	var consumable_settings := preload("res://scripts/ui/consumable_auto_settings.gd").new()
	consumable_settings.configure(hud)
	stack.add_child(consumable_settings)
	stack.add_child(HSeparator.new())
	var recovery_settings:=preload("res://scripts/ui/skill_recovery523_settings.gd").new()
	recovery_settings.configure(hud)
	stack.add_child(recovery_settings)
	stack.add_child(HSeparator.new())
	var progression_settings:=preload("res://scripts/ui/skill_progression523_settings.gd").new()
	progression_settings.configure(hud)
	stack.add_child(progression_settings)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("HUD 표시",18,UI.GOLD))
	var log_toggle := CheckButton.new()
	log_toggle.name = "CombatLogToggle"
	log_toggle.text = "전투 로그 표시"
	log_toggle.button_pressed = hud.log_label.visible
	log_toggle.toggled.connect(func(enabled: bool) -> void:
		hud.log_label.visible = enabled
		_store("interface","combat_log",enabled))
	stack.add_child(log_toggle)
	var coord_toggle := CheckButton.new()
	coord_toggle.name = "CoordinateToggle"
	coord_toggle.text = "좌표 표시"
	coord_toggle.button_pressed = hud.coordinates_readout != null and hud.coordinates_readout.visible
	coord_toggle.toggled.connect(func(enabled: bool) -> void:
		if hud.coordinates_readout != null: hud.coordinates_readout.visible = enabled
		_store("interface","coordinates",enabled))
	stack.add_child(coord_toggle)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("전투 연출",18,UI.GOLD))
	stack.add_child(UI.section("피해 판정·공격 속도는 유지하며 화면 연출만 조절합니다.",12))
	var impact_row := HBoxContainer.new()
	stack.add_child(impact_row)
	impact_row.add_child(UI.label("타격 연출 강도",14))
	impact_intensity = HSlider.new()
	impact_intensity.name = "ImpactIntensity"
	impact_intensity.min_value = 0
	impact_intensity.max_value = 100
	impact_intensity.step = 5
	impact_intensity.custom_minimum_size.x = 120
	impact_intensity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impact_intensity.value = clampf(float(config.get_value("visual","impact_intensity",.85)),0.0,1.0)*100.0
	impact_row.add_child(impact_intensity)
	impact_readout = UI.label("%d%%" % int(impact_intensity.value),14,UI.TEXT)
	impact_readout.custom_minimum_size.x = 44
	impact_row.add_child(impact_readout)
	impact_intensity.value_changed.connect(func(value: float) -> void:
		impact_readout.text = "%d%%" % int(value)
		if _store_global_presentation("impact_intensity",value/100.0): _apply_presentation())
	reduced_motion = CheckButton.new()
	reduced_motion.name = "ReducedMotion"
	reduced_motion.text = "움직임 줄이기 · 화면 흔들림 끄기"
	reduced_motion.button_pressed = bool(config.get_value("visual","reduced_motion",false))
	reduced_motion.toggled.connect(func(enabled: bool) -> void:
		if _store_global_presentation("reduced_motion",enabled): _apply_presentation())
	stack.add_child(reduced_motion)
	region_override = CheckButton.new()
	region_override.name = "RegionPresentationOverride"
	region_override.text = "현재 지역 별도 설정 · " + str(hud.get_parent().get("active_map").get("name",presentation_map_id))
	region_override.set_pressed_no_signal(config.has_section_key("visual_regions",presentation_map_id))
	region_override.toggled.connect(_region_override_changed)
	stack.add_child(region_override)
	stack.add_child(UI.section("별도 설정을 끄면 기본 표시 설정으로 돌아갑니다.",12))
	var detail_row := HBoxContainer.new()
	stack.add_child(detail_row)
	detail_row.add_child(UI.label("이펙트 세부 표현",14))
	effect_detail = OptionButton.new()
	effect_detail.name = "EffectDetail"
	effect_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_detail.add_item("전체")
	effect_detail.add_item("간소화")
	effect_detail.select(1 if str(config.get_value("visual","effect_detail","full")) == "low" else 0)
	effect_detail.item_selected.connect(func(index: int) -> void:
		_store_presentation("effect_detail","low" if index == 1 else "full")
		_apply_presentation())
	detail_row.add_child(effect_detail)
	limit_effect_count = CheckButton.new()
	limit_effect_count.name = "LimitEffectCount"
	limit_effect_count.text = "동시 이펙트 수 줄이기"
	limit_effect_count.toggled.connect(func(enabled: bool) -> void:
		_store_presentation("limit_effect_count",enabled)
		_apply_presentation())
	stack.add_child(limit_effect_count)
	hide_doll = CheckButton.new()
	hide_doll.name = "HideDoll"
	hide_doll.text = "마법인형 외형 숨기기 · 능력치 유지"
	hide_doll.toggled.connect(func(enabled: bool) -> void:
		_store_presentation("hide_doll",enabled)
		_apply_presentation())
	stack.add_child(hide_doll)
	presentation_status = UI.section("",12)
	presentation_status.name = "PresentationSettingsStatus"
	stack.add_child(presentation_status)
	_sync_presentation_controls()
	stack.add_child(HSeparator.new())
	var source_settings = preload("res://scripts/ui/source_optimization_settings.gd").new()
	source_settings.configure(self)
	stack.add_child(source_settings)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("월드 외형",18,UI.GOLD))
	stack.add_child(UI.section("지도 좌표·충돌·몬스터 배치를 변경하지 않는 시각 설정입니다.",12))
	map_visual_mode = OptionButton.new()
	map_visual_mode.name = "MapVisualMode"
	map_visual_mode.add_item("기존 TWILIGHT 외형")
	map_visual_mode.add_item("클래식 판타지 외형")
	map_visual_mode.select(1 if str(config.get_value("visual","map_mode","twilight")) == "classic" else 0)
	map_visual_mode.item_selected.connect(_map_visual_mode_changed)
	stack.add_child(map_visual_mode)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("캐릭터 8방향 애니메이션",18,UI.GOLD))
	stack.add_child(UI.section("외부 SPX 리소스 팩이 있을 때만 선택할 수 있습니다. 변신 중에는 기존 변신 외형이 우선합니다.",12))
	spx_actor_mode = OptionButton.new()
	spx_actor_mode.name = "ExternalSPXActorMode"
	spx_actor_mode.add_item("기본 TWILIGHT 캐릭터",0)
	spx_actor_mode.add_item("외부 SPX 전사 외형 · 21624",1)
	spx_actor_mode.add_item("외부 SPX 전사 외형 · 21653",2)
	for actor_index: int in range(2):
		var id: String = "21624" if actor_index == 0 else "21653"
		spx_actor_mode.set_item_disabled(actor_index+1,not SPX.available(id))
	var selected_id: String = str(config.get_value("visual","spx_actor",""))
	spx_actor_mode.select(1 if selected_id == "21624" and SPX.available(selected_id) else (2 if selected_id == "21653" and SPX.available(selected_id) else 0))
	spx_actor_mode.item_selected.connect(_spx_actor_changed)
	stack.add_child(spx_actor_mode)
	if not SPX.available("21624") and not SPX.available("21653"):
		stack.add_child(UI.section("팩 미설치: twilight_external_spx_actor_pack.zip 의 assets/를 프로젝트에 복사한 후 다시 실행하세요.",12))
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("PR122 투사 변신 SPX 비교 · 미승인",18,UI.GOLD))
	stack.add_child(UI.section("비공개 원본 팩 설치 시에만 사용합니다. 원작 외형·재배포 권한은 미확정이며 기본값은 꺼짐입니다.",12))
	for transform_id: String in ["142", "411"]:
		var spx_id: String = "21624" if transform_id == "142" else "21653"
		var preview_toggle := CheckButton.new()
		preview_toggle.name = "SPXTransformPreview" + transform_id
		preview_toggle.text = ("신화-투사(남) · 21624" if transform_id == "142" else "신화-투사(여) · 21653") + " (비공개 비교)"
		preview_toggle.disabled = not SPX.chain_review_available(spx_id)
		preview_toggle.button_pressed = not preview_toggle.disabled and bool(config.get_value("visual","spx_transform_preview_" + transform_id,false))
		preview_toggle.toggled.connect(_spx_transform_preview_changed.bind(transform_id))
		stack.add_child(preview_toggle)
	stack.add_child(HSeparator.new())
	stack.add_child(UI.label("게임 데이터",18,UI.GOLD))
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	actions.add_child(UI.button("지금 저장",func() -> void: hud.save_pressed.emit(),Vector2(180,48)))
	actions.add_child(UI.button("저장본 불러오기",_confirm_load,Vector2(190,48)))
	stack.add_child(UI.section("불러오기 전, 현재 진행도를 저장하세요.",12))
	var nav := HBoxContainer.new()
	stack.add_child(nav)
	nav.add_child(UI.button("월드맵",func() -> void: hud._navigate("map")))
	nav.add_child(UI.button("캐릭터 · 장비",func() -> void: hud._navigate("character")))

func _spx_actor_changed(index: int) -> void:
	var id: String = "" if index == 0 else ("21624" if index == 1 else "21653")
	var world: Node = hud.get_parent()
	if world == null: return
	var character: Node = world.get("player") as Node
	if character == null or not character.has_method("select_external_spx_actor"): return
	if not bool(character.call("select_external_spx_actor",id)):
		spx_actor_mode.select(0)
		return
	_store("visual","spx_actor",id)

func _spx_transform_preview_changed(enabled: bool, transform_id: String) -> void:
	_store("visual", "spx_transform_preview_" + transform_id, enabled)
	var world: Node = hud.get_parent()
	if world == null or not world.has_method("_apply_transform_visual"): return
	var equipped: Variant = world.get("equipped_catalog")
	if not (equipped is Dictionary): return
	var record: Variant = (equipped as Dictionary).get("변신", {})
	if record is Dictionary and str((record as Dictionary).get("sourceId", "")) == transform_id:
		world.call("_apply_transform_visual", record)

func _map_visual_mode_changed(index: int) -> void:
	var mode: String = "classic" if index == 1 else "twilight"
	_store("visual","map_mode",mode)
	var world: Node = hud.get_parent()
	if world != null and world.has_method("_set_visual_mode"):
		world.call("_set_visual_mode",mode)

func _store(section: String,key: String,value: Variant) -> void:
	config.set_value(section,key,value)
	var error := config.save(SETTINGS_PATH)
	if error != OK: push_warning("Could not save UI preferences: %d" % error)

func store_presentation_preferences(changes: Array) -> Error:
	# Save one complete candidate in the same directory, then atomically replace
	# the file. Failed writes/renames leave both the active config and file intact.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SETTINGS_PATH)):
		presentation_status.text = "설정을 저장하지 못했습니다. 기존 설정을 유지합니다."
		return ERR_CANT_OPEN
	var candidate := ConfigFile.new()
	var error: Error = candidate.parse(config.encode_to_text())
	if error != OK: return error
	for change: Dictionary in changes:
		if bool(change.get("erase",false)):
			if candidate.has_section_key(change.section,change.key): candidate.erase_section_key(change.section,change.key)
		else: candidate.set_value(change.section,change.key,change.value)
	var temporary: String = SETTINGS_PATH + ".tmp-" + str(Time.get_ticks_usec())
	error = candidate.save(temporary)
	if error == OK and FileAccess.get_file_as_string(temporary)!=candidate.encode_to_text(): error = ERR_FILE_CORRUPT
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(SETTINGS_PATH))
	if error != OK:
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		presentation_status.text = "설정을 저장하지 못했습니다. 기존 설정을 유지합니다."
		return error
	config = candidate
	presentation_status.text = "표시 설정을 저장했습니다."
	return OK

func _store_global_presentation(key: String,value: Variant) -> bool:
	if store_presentation_preferences([{"section":"visual","key":key,"value":value}])==OK: return true
	impact_intensity.set_value_no_signal(clampf(float(config.get_value("visual","impact_intensity",.85)),0.0,1.0)*100.0)
	impact_readout.text = "%d%%" % int(impact_intensity.value)
	reduced_motion.set_pressed_no_signal(bool(config.get_value("visual","reduced_motion",false)))
	return false

func _apply_presentation() -> void:
	UI.set_reduced_motion(reduced_motion.button_pressed)
	var world: Node = hud.get_parent()
	if world != null and world.has_method("apply_presentation_settings"):
		world.call("apply_presentation_settings",{
			"impact_intensity":impact_intensity.value/100.0,
			"reduced_motion":reduced_motion.button_pressed,
			"effect_detail":config.get_value("visual","effect_detail","full"),
			"limit_effect_count":config.get_value("visual","limit_effect_count",false),
			"hide_doll":config.get_value("visual","hide_doll",false)
		})

func _presentation_values() -> Dictionary:
	var result: Dictionary = {}
	for key: String in PREFS.REGION_KEYS:
		result[key] = config.get_value("visual",key,"full" if key == "effect_detail" else false)
	result = PREFS.region(PREFS.normalized(result))
	if region_override.button_pressed:
		var local: Variant = config.get_value("visual_regions",presentation_map_id,{})
		if local is Dictionary: result.merge(PREFS.region(local),true)
	return result

func _sync_presentation_controls() -> void:
	var values: Dictionary = _presentation_values()
	effect_detail.select(1 if str(values.effect_detail) == "low" else 0)
	limit_effect_count.set_pressed_no_signal(bool(values.limit_effect_count))
	hide_doll.set_pressed_no_signal(bool(values.hide_doll))

func _region_override_changed(enabled: bool) -> void:
	var change: Dictionary = {"section":"visual_regions","key":presentation_map_id,"erase":not enabled,"value":_presentation_values()}
	if store_presentation_preferences([change])!=OK:
		region_override.set_pressed_no_signal(config.has_section_key("visual_regions",presentation_map_id))
		_sync_presentation_controls()
		return
	hud.get_parent().call("set_region_presentation_settings",presentation_map_id,_presentation_values(),enabled)
	_sync_presentation_controls()

func _store_presentation(key: String, value: Variant) -> void:
	if region_override.button_pressed:
		var values: Dictionary = _presentation_values()
		values[key] = value
		if store_presentation_preferences([{"section":"visual_regions","key":presentation_map_id,"value":values}])!=OK:
			_sync_presentation_controls()
			return
		hud.get_parent().call("set_region_presentation_settings",presentation_map_id,values)
	else:
		if store_presentation_preferences([{"section":"visual","key":key,"value":value}])!=OK: _sync_presentation_controls()

func _volume_changed(value: float) -> void:
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,value/100.0)))
		AudioServer.set_bus_mute(0,mute.button_pressed or value <= 0.0)
	_store("audio","volume",value)

func _mute_changed(value: bool) -> void:
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0,value or volume.value <= 0.0)
	_store("audio","muted",value)

func _confirm_load() -> void:
	var dialog := Dialog.new()
	dialog.title_text = "저장된 게임 불러오기"
	dialog.message_text = "현재 미저장 진행도가 사라질 수 있습니다. 저장본을 불러올까요?"
	hud.get_node("Root").add_child(dialog)
	dialog.confirmed.connect(func() -> void: hud.load_pressed.emit())

