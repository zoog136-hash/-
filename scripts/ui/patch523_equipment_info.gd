extends VBoxContainer
## Inspection of exact source branches; spending remains in authoritative Main.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var world: Node
var equipment: OptionButton
var scroll: OptionButton
var detail: RichTextLabel
var ids: Array[String] = []
var scroll_ids: Array[String] = []
var source_action: Button
var pack_sha: LineEdit
var pack_dialog: FileDialog
var pack_status: Label
const DEFAULT_SHA: String = "d2af6eb5cf84314616e60f249539754ddbebbdf36fd759897c8d43b4dd3ea7f5"

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	name = "Patch523EquipmentInfo"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.label("원본523 장비 강화 정보", 20, UI.GOLD))
	add_child(UI.label("원본·공식 표를 대조한 인장 강화와 장비 정보를 확인합니다.", 12, UI.MUTED))
	var installation := HBoxContainer.new()
	add_child(installation)
	pack_sha = LineEdit.new()
	pack_sha.name = "Patch523PackSHA"
	pack_sha.placeholder_text = "규칙 팩 SHA256"
	pack_sha.text = DEFAULT_SHA
	pack_sha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	installation.add_child(pack_sha)
	var install_button: Button = UI.button("규칙 팩 설치·교체", func() -> void: pack_dialog.popup_centered_ratio(.75))
	install_button.name = "Patch523InstallPack"
	installation.add_child(install_button)
	pack_dialog = FileDialog.new()
	pack_dialog.name = "Patch523PackFileDialog"
	pack_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	pack_dialog.access = FileDialog.ACCESS_FILESYSTEM
	pack_dialog.filters = PackedStringArray(["*.json ; 원본523 장비·제작 규칙 팩"])
	pack_dialog.file_selected.connect(_install_selected)
	add_child(pack_dialog)
	pack_status = UI.label("설치된 규칙은 사용자 폴더에 보관하고 다음 실행에 자동 복원합니다.", 11, UI.MUTED)
	pack_status.name = "Patch523PackInstallStatus"
	add_child(pack_status)
	equipment = OptionButton.new()
	equipment.name = "Patch523EquipmentChoice"
	equipment.custom_minimum_size.y = 42
	add_child(equipment)
	scroll = OptionButton.new()
	scroll.name = "Patch523ScrollChoice"
	scroll.custom_minimum_size.y = 42
	add_child(scroll)
	detail = UI.rich("")
	detail.name = "Patch523EquipmentDetail"
	detail.fit_content = false
	detail.scroll_active = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(detail)
	source_action = UI.button("원본 인장 강화", _confirm_source)
	source_action.name = "Patch523SealEnhance"
	add_child(source_action)
	var actions := HBoxContainer.new()
	add_child(actions)
	actions.add_child(UI.button("제작·축복 전환", func() -> void: hud.open_crafting()))
	actions.add_child(UI.button("현재 강화 실행", func() -> void: hud._open_enhance_chooser()))
	world._sync_item_instances()
	var book: Object = world.patch523_equipment
	for id: Variant in world.item_instances:
		var physical: Dictionary = world.item_instances[id]
		var source_id: String = book.identity(physical)
		if source_id.is_empty() or not book.data.get("items", {}).has(source_id):
			continue
		ids.append(str(id))
		equipment.add_item("%s +%d · %s · ID %s" % [str(physical.name), int(physical.level), "축복" if book.bless_code(physical) == 2 else "일반", str(id)])
	for source_id: String in book.data.get("items", {}):
		var item: Dictionary = book.data.items[source_id]
		var is_scroll: bool = false
		for link: Dictionary in item.item_bonuses:
			if int(book.data.bonuses[str(int(link.BonusID))].BonusTypeID) in [2022, 8352]:
				is_scroll = true
		if not is_scroll:
			continue
		scroll_ids.append(source_id)
		scroll.add_item(str(item.catalog_record.name))
	equipment.item_selected.connect(func(_i: int) -> void: _refresh())
	scroll.item_selected.connect(func(_i: int) -> void: _refresh())
	_refresh()

func _refresh() -> void:
	source_action.disabled = true
	if ids.is_empty() or scroll_ids.is_empty():
		detail.text = "원본523 규칙 팩과 정확한 원본 ID를 가진 보유 장비가 필요합니다. 기존 장비·세이브는 유지됩니다."
		return
	var book: Object = world.patch523_equipment
	var physical: Dictionary = world.item_instances.get(ids[equipment.selected], {})
	if physical.is_empty():
		detail.text = "선택한 장비를 다시 확인하세요."
		return
	var source_id: int = int(book.identity(physical))
	var scroll_id: int = int(scroll_ids[scroll.selected])
	var level_value: int = int(physical.level)
	var blessing: int = book.bless_code(physical)
	# Name-only stack storage cannot prove the scroll's blessing state. Display
	# both explicit branches rather than selecting one on the player's behalf.
	var text: String = "[b]%s +%d[/b]\n" % [UI.safe(physical.name), level_value]
	var quote: Dictionary = world.patch523_seal_quote(ids[equipment.selected],str(scroll_id))
	if bool(quote.get("ok",false)):
		source_action.disabled = false
		text += "\n[b]원본 인장 강화 실행[/b]\n공식 확률 %.4f%% · 현재 +%d → +%d · 실패 %s\n주문서 %d개 · %d 아데나\n%s\n" % [float(quote.success),level_value,level_value+1,"유지" if bool(quote.protected) else "소실",int(quote.count),int(quote.cost),UI.safe(quote.economy_label)]
	else:
		text += "\n원본 인장 강화: %s\n" % UI.safe(str(quote.get("reason","실행 조건을 확인하세요")))
	var effect_text: String = ""
	var effects: Array = book.effect_evidence(source_id, level_value, 2 if blessing == 2 else 0)
	if not effects.is_empty():
		effect_text += "\n[b]해당 단계 원본 효과[/b]" + ("\n" if blessing == 2 else " · 기본계열 매칭 미확정\n")
		var labels: Dictionary = {"MeleeHit":"근거리 명중", "RangeHit":"원거리 명중", "MeleeDamage":"근거리 대미지", "RangeDamage":"원거리 대미지", "DamageReduction":"대미지 리덕션", "HPPotionIncreaseStatic":"물약 회복량", "HPPotionIncreasePercent":"물약 회복률", "ExperienceAdditionPercent":"경험치 증가율", "EinasadSavingPercent":"아인하사드 절약", "PotionConsumeDelayDecreasePercent":"물약 쿨타임 감소", "SpecialResistance":"특수 내성"}
		var supported: Dictionary = {"MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","DamageReduction":"reduction","HPPotionIncreaseStatic":"potion_heal_flat","HPPotionIncreasePercent":"potion_heal_pct","ExperienceAdditionPercent":"xp_pct","EinasadSavingPercent":"ain_saving_pct","PotionConsumeDelayDecreasePercent":"potion_cooldown_pct","SpecialResistance":"stun_resistance"}
		var expected_options: Dictionary = book.supported_seal_options(str(source_id),2).get(str(level_value), {})
		var actual_options: Dictionary = physical.get("record", {}).get("enhancement_options", {}).get(str(level_value), {})
		for effect: Dictionary in effects:
			var kind: String = str(effect.bonus_type.get("Name", ""))
			var value: String = str(int(effect.bonus.Value))
			if int(effect.bonus_type.get("UnitID", 0)) == 3:
				value = "%.2f%%" % (float(effect.bonus.Value) / 10000.0)
			var label: String = str(labels.get(kind, kind))
			if kind == "SpecialResistance" and int(effect.bonus.BonusApplicationTypeID) == 2 and int(effect.bonus.BonusApplicationTargetID) == 6:
				label = "스턴 내성"
			var applied: bool = blessing == 2 and supported.has(kind) and expected_options.has(supported[kind]) and actual_options.get(supported[kind]) == expected_options[supported[kind]]
			effect_text += "%s +%s · %s\n" % [UI.safe(label), value, "적용 연결" if applied else "참고·적용 미연결"]
	var displayed: Dictionary = {}
	var blessing_branches: Array = [1]
	for link: Dictionary in book.data.get("items", {}).get(str(scroll_id), {}).get("item_bonuses", []):
		if int(book.data.bonuses[str(int(link.BonusID))].BonusTypeID) == 8352:
			blessing_branches = [1, 2]
	for scroll_bless: int in blessing_branches:
		var evidence: Dictionary = world.patch523_enhancement_evidence(source_id, scroll_id, level_value, blessing, scroll_bless)
		if evidence.groups.is_empty():
			continue
		text += "\n[b]%s[/b]\n" % (("일반 주문서 조건" if scroll_bless == 1 else "축복 주문서 조건") if blessing_branches.size() == 2 else "선택한 주문서의 원본 표")
		for row: Dictionary in evidence.probabilities:
			var key: String = JSON.stringify(row)
			if displayed.has(key):
				continue
			displayed[key] = true
			var total: int = int(row.Success) + int(row.Vaporize) + int(row.SideEffect) + int(row.Remain)
			if total <= 0:
				continue
			text += "원본 단계 %d · %s\n성공 %.4f%% · 소실 %.4f%% · 부작용 %.4f%% · 유지 %.4f%%\n" % [int(row.EnchantLevel), "대상 축복 조건 미확정(원본0)" if int(row.TargetItemBlessCode) == 0 else ("축복 장비" if int(row.TargetItemBlessCode) == 2 else "일반 장비"), 100.0 * float(row.Success)/total, 100.0 * float(row.Vaporize)/total, 100.0 * float(row.SideEffect)/total, 100.0 * float(row.Remain)/total]
		for row: Dictionary in evidence.costs:
			text += "원본 재료 수량 %d · 비용 값 %d(통화 미확정)\n" % [int(row.ConsumeAmount), int(row.Cost)]
	if displayed.is_empty():
		text += "\n선택한 장비·주문서·단계에 표시 가능한 원본 확률 행이 없습니다. 안전 강화나 확률을 추정하지 않습니다.\n"
	text += effect_text
	text += "\n[color=#b9a67e]인장 전용 실행은 공식 표의 확인된 대상만 사용합니다. 비용값은 원본이며 통화와 일반 주문서 수량0은 별도 게임 설정입니다. 기존 강화 실행은 기존 TWILIGHT 규칙을 유지합니다.[/color]"
	detail.text = text

func _install_selected(path: String) -> void:
	if not world.install_patch523_equipment_file(path, pack_sha.text.strip_edges().to_lower()):
		pack_status.text = world.patch523_equipment.problem + " · 기존 설치·세이브 보존"
		return
	hud.show_message("원본523 규칙 팩 설치 완료")
	hud.open_patch523_equipment_info()

func _confirm_source() -> void:
	if ids.is_empty() or scroll_ids.is_empty(): return
	var item_id: String = ids[equipment.selected]
	var scroll_id: String = scroll_ids[scroll.selected]
	var quote: Dictionary = world.patch523_seal_quote(item_id,scroll_id)
	if not bool(quote.get("ok",false)):
		hud.show_message(str(quote.get("reason","실행 조건을 확인하세요")))
		_refresh()
		return
	hud.confirm_action("원본 인장 강화 확인", "%s +%d → +%d\n성공 %.4f%% · 실패 %s\n%s %d개 + %d 아데나\n%s" % [str(quote.item),int(quote.level),int(quote.level)+1,float(quote.success),"유지" if bool(quote.protected) else "장비 소실",str(quote.scroll_name),int(quote.count),int(quote.cost),str(quote.economy_label)],"강화",func(_count: int) -> void: world._patch523_attempt_seal(item_id,scroll_id))
