extends VBoxContainer
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
var picker: FileDialog
var status: Label
var weapon_scope: OptionButton
var bleed_rule: OptionButton
var bleed_interval: SpinBox
var reward_draw_count: SpinBox
var reward_bags: CheckButton
const SCOPES: Array[String] = ["base_flat_enchant","base_only","disabled"]
const BLEED_RULES: Array[String] = ["total_damage_cap","no_cap","disabled"]

func _ready() -> void:
	name = "Patch523DropSettings"
	var title := Label.new()
	title.text = "몬스터 드랍 자료 · 523"
	add_child(title)
	status = Label.new()
	status.name = "Patch523DropStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var document: Dictionary = DROPS.data()
	status.text = _status_text(document)
	add_child(status)
	var choose := Button.new()
	choose.name = "InstallPatch523DropPack"
	choose.text = "523 드랍 자료 ZIP 설치"
	choose.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(choose)
	picker = FileDialog.new()
	picker.title = "523 드랍 자료 선택"
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

func _world() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_refresh_patch523_drop_catalog"): return node
		node = node.get_parent()
	return null

func _status_text(document: Dictionary) -> String:
	if document.is_empty(): return "미설치 · 드랍 자료 ZIP을 선택하세요."
	var line: String = "설치됨 · 연결 아이템 %d종 · 도감에서 드랍원 확인" % int(document.get("counts",{}).get("verified_item_bindings",0))
	if document.has("item_use_counts"):
		var counts: Dictionary = document.item_use_counts
		line += "\n지정 카드 %d종 · 지속 버프 %d종 · 확정/확률/혼합 상자 %d/%d/%d종" % [int(counts.get("fixed_card",0)),int(counts.get("source_timed_buff",0)),int(counts.get("guaranteed_bag",0)),int(counts.get("source_weighted_bag",0)),int(counts.get("mixed_rewards_bag",0))]
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
