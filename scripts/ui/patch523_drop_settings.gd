extends VBoxContainer
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
var picker: FileDialog
var status: Label
var weapon_scope: OptionButton
var bleed_rule: OptionButton
var bleed_interval: SpinBox
var reward_draw_count: SpinBox
var reward_bags: CheckButton
var select_initial: CheckButton
var source_clock: SpinBox
var ammo_rule: OptionButton
var source_regen_interval: SpinBox
var source_drain_chance: SpinBox
var presentation_flags: CheckButton
const AMMO_RULES: Array[String] = ["uniform","maximum","disabled"]
const SCOPES: Array[String] = ["base_flat_enchant","base_only","disabled"]
const BLEED_RULES: Array[String] = ["total_damage_cap","no_cap","disabled"]

func _ready() -> void:
	name = "Patch523DropSettings"
	var title := Label.new()
	title.text = "원본 아이템·몬스터 드랍 · 523"
	add_child(title)
	status = Label.new()
	status.name = "Patch523DropStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var document: Dictionary = DROPS.data()
	status.text = _status_text(document)
	add_child(status)
	var choose := Button.new()
	choose.name = "InstallPatch523DropPack"
	choose.text = "523 원본 아이템·드랍 ZIP 설치"
	choose.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(choose)
	picker = FileDialog.new()
	picker.title = "523 원본 아이템·드랍 자료 선택"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.zip;TWILIGHT 523 드랍 자료;application/zip"])
	picker.file_selected.connect(_selected)
	add_child(picker)
	var note := Label.new()
	note.text = "이도류 배율 적용 범위 · TWILIGHT 보완 규칙\n발동 확률·배율은 원본. 적용 범위는 공개 실험에 근거한 추정입니다."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	weapon_scope = OptionButton.new()
	weapon_scope.name = "Patch523WeaponDoubleScope"
	for label: String in ["무기 기본+추가+강화 (실험 근거 추정)","무기 기본만 (자체 설정)","이도류 배율 발동 사용 안함"]: weapon_scope.add_item(label)
	var world: Node = _world()
	var selected: int = SCOPES.find(str(world.ui_preferences.get("patch523_weapon_double_scope",SCOPES[0]))) if world != null else 0
	weapon_scope.select(maxi(0,selected))
	weapon_scope.item_selected.connect(_scope_selected)
	add_child(weapon_scope)
	var bleed_note := Label.new()
	bleed_note.text = "총 출혈 · TWILIGHT 보완 규칙\n확률·지속·주사위는 원본. 틱 간격과 MaxHPPercent의 의미는 미확인으로 자체 규칙을 적용합니다."
	bleed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(bleed_note)
	bleed_rule = OptionButton.new()
	bleed_rule.name = "Patch523BleedRule"
	for label: String in ["누적 출혈 피해 최대 HP 50% 상한 (의미 추정)","출혈 피해 상한 없음 (자체 설정)","총 출혈 발동 사용 안함"]: bleed_rule.add_item(label)
	var rule: String = str(world.ui_preferences.get("patch523_bleed_max_hp_rule",BLEED_RULES[0])) if world != null else BLEED_RULES[0]
	bleed_rule.select(maxi(0,BLEED_RULES.find(rule)))
	add_child(bleed_rule)
	var interval_label := Label.new()
	interval_label.text = "출혈 틱 간격(초) · 기본 0.75초는 기존 게임 규칙"
	add_child(interval_label)
	bleed_interval = SpinBox.new()
	bleed_interval.name = "Patch523BleedInterval"
	bleed_interval.min_value = 0.1
	bleed_interval.max_value = 3.0
	bleed_interval.step = 0.05
	bleed_interval.value = clampf(float(world.ui_preferences.get("patch523_bleed_tick_interval_seconds",0.75)),0.1,3.0) if world != null else 0.75
	add_child(bleed_interval)
	bleed_rule.item_selected.connect(_bleed_changed)
	bleed_interval.value_changed.connect(_bleed_changed)
	var reward_note := Label.new()
	reward_note.text = "원본 확률 상자 · 확률·수량·직업 조건은 원본\n확률 보상 선택 횟수는 TWILIGHT 자체 규칙입니다. 기본 1회이며 확정 보상은 한 번 지급합니다."
	reward_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(reward_note)
	reward_bags = CheckButton.new()
	reward_bags.text = "TWILIGHT 원본 상자 선택 규칙 사용"
	reward_bags.button_pressed = bool(world.ui_preferences.get("patch523_source_reward_bags_enabled",true)) if world != null else true
	add_child(reward_bags)
	reward_draw_count = SpinBox.new()
	reward_draw_count.name = "Patch523RewardDrawCount"
	reward_draw_count.min_value = 1
	reward_draw_count.max_value = 10
	reward_draw_count.step = 1
	reward_draw_count.value = clampi(int(world.ui_preferences.get("patch523_reward_bag_draw_count",1)),1,10) if world != null else 1
	add_child(reward_draw_count)
	reward_bags.toggled.connect(_reward_rule_changed)
	reward_draw_count.value_changed.connect(_reward_rule_changed)
	select_initial = CheckButton.new()
	select_initial.name = "Patch523SelectInitialZero"
	select_initial.text = "선택 장비 초기 +0 자체 규칙 사용 (원본 강화값 없음)"
	select_initial.button_pressed = bool(world.ui_preferences.get("patch523_select_reward_initial_zero_enabled",true)) if world != null else true
	add_child(select_initial)
	select_initial.toggled.connect(_select_initial_changed)
	var clock_note := Label.new()
	clock_note.text = "원본 기간 YYYYMMDDHH[MM] · 서버 시각대는 TWILIGHT 설정(기본 UTC+9)
기간이 지난 항목은 사용·장착을 막고 소유는 보존합니다."
	clock_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(clock_note)
	source_clock = SpinBox.new()
	source_clock.name = "Patch523SourceClockOffset"
	source_clock.min_value = -720
	source_clock.max_value = 840
	source_clock.step = 30
	source_clock.value = int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)) if world != null else 540
	add_child(source_clock)
	source_clock.value_changed.connect(_clock_changed)
	var ammo_note := Label.new()
	ammo_note.text = "원본 탄약 대미지 상한은 소스 값 · 추첨 방식은 TWILIGHT 자체 규칙\n기본 1~상한 균등 추정이며 원본 완전한 전투 공식을 뜻하지 않습니다."
	ammo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(ammo_note)
	ammo_rule = OptionButton.new()
	ammo_rule.name = "Patch523AmmoDamageRule"
	for label: String in ["탄약: 1~원본 상한 균등 추정","탄약: 원본 상한 고정 (자체 설정)","탄약: 추가 대미지 사용 안함"]: ammo_rule.add_item(label)
	ammo_rule.select(maxi(0,AMMO_RULES.find(str(world.ui_preferences.get("patch523_ammo_damage_rule","uniform")) if world != null else "uniform")))
	add_child(ammo_rule)
	ammo_rule.item_selected.connect(_ammo_changed)
	var passive_note := Label.new()
	passive_note.text = "원본 장비 HP·MP 회복량과 흡수량은 소스 값\n회복 간격은 기본 30초(기존 게임 기준), 일반 명중 흡수 발동률은 기본 100%(기존 매 명중 규칙을 따른 추정)입니다.\nMP 흡수는 몬스터의 실제 남은 MP 이내이며 주문·특수 발동에는 확대하지 않습니다."
	passive_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(passive_note)
	source_regen_interval = SpinBox.new()
	source_regen_interval.name = "Patch523ItemRegenInterval"
	source_regen_interval.min_value = 1;source_regen_interval.max_value = 300;source_regen_interval.step = 1
	source_regen_interval.suffix = "초 · 장비 회복 간격 (자체 규칙)"
	source_regen_interval.value = float(world.ui_preferences.get("patch523_item_regen_interval_seconds",30.0)) if world != null else 30.0
	add_child(source_regen_interval)
	source_drain_chance = SpinBox.new()
	source_drain_chance.name = "Patch523ItemDrainChance"
	source_drain_chance.min_value = 0;source_drain_chance.max_value = 100;source_drain_chance.step = 1
	source_drain_chance.suffix = "% · 일반 명중 흡수 발동률 (추정)"
	source_drain_chance.value = float(world.ui_preferences.get("patch523_item_drain_chance_percent",100.0)) if world != null else 100.0
	add_child(source_drain_chance)
	source_regen_interval.value_changed.connect(_passive_changed)
	source_drain_chance.value_changed.connect(_passive_changed)
	presentation_flags = CheckButton.new()
	presentation_flags.name = "Patch523PresentationFlagsPolicy"
	presentation_flags.text = "표시·공지 플래그 사용 해석 (추정)"
	presentation_flags.tooltip_text = "UIShowFilter·NoAnnounce: 원본과 공개 자료에 의미 설명이 없습니다. 무조건0/1 표시 플래그만 사용 차단 조건에서 제외하고 원본 효과·확률·기간·다른 조건은 보존합니다. 끄면 해당 아이템을 소비하지 않습니다."
	presentation_flags.button_pressed = bool(world.ui_preferences.get("patch523_item_presentation_flags_policy",true)) if world != null else true
	add_child(presentation_flags)
	presentation_flags.toggled.connect(_presentation_changed)


func _world() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_refresh_patch523_drop_catalog"): return node
		node = node.get_parent()
	return null

func _status_text(document: Dictionary) -> String:
	if document.is_empty(): return "미설치 · 드랍 자료 ZIP을 선택하세요."
	var line: String = "설치됨 · 드랍 연결 %d종 · 도감에서 드랍원 확인" % int(document.get("counts",{}).get("verified_item_bindings",0))
	if document.get("full_item_catalog",false): line += "\n원본 전체 %d개 · 정상 카탈로그 %d개 · 테스트 보존 %d개" % [int(document.counts.source_item_class_rows),int(document.counts.catalog_items),int(document.counts.source_test_items)]
	if document.has("item_use_counts"):
		var counts: Dictionary = document.item_use_counts
		line += "\n원본 사용 정의 · 지정 카드 %d종 · 지속 버프 %d종 · 확정/확률/혼합 상자 %d/%d/%d종" % [int(counts.get("fixed_card",0)),int(counts.get("source_timed_buff",0)),int(counts.get("guaranteed_bag",0)),int(counts.get("source_weighted_bag",0)),int(counts.get("mixed_rewards_bag",0))]
		line += "\n선택 상자 %d종 · 스킬서 원본 정의 %d종 (PR245 연결 검증 필요)" % [int(counts.get("source_selectable_reward",0)),int(counts.get("source_skill_book",0))]
	else: line += "\n이전 자료 버전 · 사용 효과 확장 ZIP 설치 가능"
	return line

func _scope_selected(index: int) -> void:
	var world: Node = _world()
	if world == null or index < 0 or index >= SCOPES.size(): return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_weapon_double_scope"] = SCOPES[index]
	if world._save_game(true) != OK:
		world.ui_preferences = before
		weapon_scope.select(maxi(0,SCOPES.find(str(before.get("patch523_weapon_double_scope",SCOPES[0])))))
		status.text = "보완 규칙 저장 실패 · 기존 설정 유지"
	else: status.text = "TWILIGHT 이도류 보완 규칙 저장 완료"

func _bleed_changed(_value: float) -> void:
	var world: Node = _world()
	if world == null: return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_bleed_max_hp_rule"] = BLEED_RULES[bleed_rule.selected]
	world.ui_preferences["patch523_bleed_tick_interval_seconds"] = float(bleed_interval.value)
	if world._save_game(true) != OK:
		world.ui_preferences = before
		bleed_rule.select(maxi(0,BLEED_RULES.find(str(before.get("patch523_bleed_max_hp_rule",BLEED_RULES[0])))))
		bleed_interval.set_value_no_signal(float(before.get("patch523_bleed_tick_interval_seconds",0.75)))
		status.text = "출혈 보완 규칙 저장 실패 · 기존 설정 유지"
	else: status.text = "TWILIGHT 출혈 보완 규칙 저장 완료"

func _reward_rule_changed(_value: Variant) -> void:
	var world: Node = _world()
	if world == null: return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_source_reward_bags_enabled"] = reward_bags.button_pressed
	world.ui_preferences["patch523_reward_bag_draw_count"] = int(reward_draw_count.value)
	if world._save_game(true) != OK:
		world.ui_preferences = before
		reward_bags.set_pressed_no_signal(bool(before.get("patch523_source_reward_bags_enabled",true)))
		reward_draw_count.set_value_no_signal(int(before.get("patch523_reward_bag_draw_count",1)))
		status.text = "상자 선택 규칙 저장 실패 · 기존 설정 유지"
	else: status.text = "TWILIGHT 상자 선택 규칙 저장 완료"

func _selected(path: String) -> void:
	var result: Dictionary = DROPS.install_zip(path)
	if result.ok:
		var ancestor: Node = get_parent()
		while ancestor != null:
			if ancestor.has_method("_refresh_patch523_drop_catalog"):
				ancestor.call("_refresh_patch523_drop_catalog")
				break
			ancestor = ancestor.get_parent()
	status.text = "드랍 자료 설치 완료 · "+_status_text(DROPS.data()) if result.ok else str(result.error)

func _select_initial_changed(enabled: bool) -> void:
	var world: Node = _world()
	if world == null: return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_select_reward_initial_zero_enabled"] = enabled
	if world._save_game(true) != OK:
		world.ui_preferences = before
		select_initial.set_pressed_no_signal(bool(before.get("patch523_select_reward_initial_zero_enabled",true)))
		status.text = "선택 장비 자체 규칙 저장 실패 · 이전 설정 유지"
	else: status.text = "선택 장비 초기 +0 자체 규칙 저장 완료" if enabled else "선택 장비 초기 강화 미확인 · 장비 선택 시 상자 보존"

func _clock_changed(value: float) -> void:
	var world: Node = _world()
	if world == null: return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_source_clock_offset_minutes"] = int(value)
	if world._save_game(true) != OK:
		world.ui_preferences = before
		source_clock.set_value_no_signal(int(before.get("patch523_source_clock_offset_minutes",540)))
		status.text = "원본 기간 시각대 저장 실패 · 기존 설정 유지"
	else:
		world._enforce_patch523_equipment_requirements()
		world._update_hud()
		status.text = "원본 기간 시각대 저장 · UTC%+.1f" % (value/60.0)

func _ammo_changed(index: int) -> void:
	var world: Node = _world()
	if world == null or index < 0 or index >= AMMO_RULES.size(): return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_ammo_damage_rule"] = AMMO_RULES[index]
	if world._save_game(true) != OK:
		world.ui_preferences = before
		ammo_rule.select(maxi(0,AMMO_RULES.find(str(before.get("patch523_ammo_damage_rule","uniform")))))
		status.text = "탄약 대미지 설정 저장 실패 · 기존 설정 유지"
	else: status.text = "TWILIGHT 탄약 대미지 규칙 저장 완료"

func _passive_changed(_value: float) -> void:
	var world: Node = _world()
	if world == null: return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_item_regen_interval_seconds"] = float(source_regen_interval.value)
	world.ui_preferences["patch523_item_drain_chance_percent"] = float(source_drain_chance.value)
	if world._save_game(true) != OK:
		world.ui_preferences = before
		source_regen_interval.set_value_no_signal(float(before.get("patch523_item_regen_interval_seconds",30.0)))
		source_drain_chance.set_value_no_signal(float(before.get("patch523_item_drain_chance_percent",100.0)))
		status.text = "원본 장비 회복·흡수 자체 규칙 저장 실패 · 기존 설정 유지"
	else: status.text = "원본 장비 회복·흡수 자체 규칙 저장 완료"

func _presentation_changed(enabled: bool) -> void:
	var world: Node = _world()
	if world == null: return
	var before: Dictionary = world.ui_preferences.duplicate(true)
	world.ui_preferences["patch523_item_presentation_flags_policy"] = enabled
	if world._save_game(true) != OK:
		world.ui_preferences = before
		presentation_flags.set_pressed_no_signal(bool(before.get("patch523_item_presentation_flags_policy",true)))
		status.text = "표시 플래그 해석 설정 저장 실패 · 기존 설정 유지"
	else: status.text = "표시 플래그 해석은 TWILIGHT 추정 · 원본 조건과 확률 유지"
