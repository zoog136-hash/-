extends VBoxContainer

# Presentation options and character-specific consumable safety controls.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Dialog = preload("res://scripts/ui/renewal_dialog.gd")
const SETTINGS_PATH = "user://twilight_ui_settings.cfg"
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
	stack.add_child(UI.section("게임 화면 · 오디오 · 저장",12))
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
	var consumable_settings := preload("res://scripts/ui/consumable_auto_settings.gd").new()
	consumable_settings.configure(hud)
	stack.add_child(consumable_settings)
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
		_store("visual","impact_intensity",value/100.0)
		_apply_presentation())
	reduced_motion = CheckButton.new()
	reduced_motion.name = "ReducedMotion"
	reduced_motion.text = "움직임 줄이기 · 화면 흔들림 끄기"
	reduced_motion.button_pressed = bool(config.get_value("visual","reduced_motion",false))
	reduced_motion.toggled.connect(func(enabled: bool) -> void:
		_store("visual","reduced_motion",enabled)
		_apply_presentation())
	stack.add_child(reduced_motion)
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
		_store("visual","effect_detail","low" if index == 1 else "full")
		_apply_presentation())
	detail_row.add_child(effect_detail)
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

func _apply_presentation() -> void:
	UI.set_reduced_motion(reduced_motion.button_pressed)
	var world: Node = hud.get_parent()
	if world != null and world.has_method("apply_presentation_settings"):
		world.call("apply_presentation_settings",{
			"impact_intensity":impact_intensity.value/100.0,
			"reduced_motion":reduced_motion.button_pressed,
			"effect_detail":"low" if effect_detail.selected == 1 else "full"
		})

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
