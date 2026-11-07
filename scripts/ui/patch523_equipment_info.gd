extends VBoxContainer
## Inspection of exact source branches; spending remains in authoritative Main.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
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
var catalog_dialog: FileDialog
var catalog_status: Label
const DEFAULT_SHA: String = "e362bbaf4e957863397808127485f3dbab47ce1c7010bb47766f381ae891b7d1"

func configure(controller: Node) -> void:
	hud = controller
	world = hud.get_parent()
	name = "Patch523EquipmentInfo"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.label("원본523 장비 강화 정보", 20, UI.GOLD))
	add_child(UI.label("아이템·주문서 그룹별 원본 강화 확률과 적용 효과를 확인합니다.", 12, UI.MUTED))
	var installation := HBoxContainer.new()
	add_child(installation)
	pack_sha = LineEdit.new()
	pack_sha.name = "Patch523PackSHA"
	pack_sha.placeholder_text = "규칙 팩 SHA256"
	pack_sha.text = str(world.patch523_equipment.digest) if not str(world.patch523_equipment.digest).is_empty() else DEFAULT_SHA
	pack_sha.tooltip_text="현재 로드한 규칙의 SHA256입니다. 다른 팩으로 교체할 때는 새 파일의 SHA256을 입력하세요."
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
	var catalog_install: Button=UI.button("제작 아이템 자료 ZIP 설치",func() -> void: catalog_dialog.popup_centered_ratio(.75))
	catalog_install.name="Patch523InstallCraftCatalog"
	add_child(catalog_install)
	catalog_dialog=FileDialog.new()
	catalog_dialog.name="Patch523CraftCatalogDialog"
	catalog_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	catalog_dialog.access=FileDialog.ACCESS_FILESYSTEM
	catalog_dialog.filters=PackedStringArray(["*.zip ; 검증된523 공통 아이템 자료"])
	catalog_dialog.file_selected.connect(func(path: String) -> void:
		if world.install_patch523_craft_catalog_zip(path): catalog_status.text="제작 아이템 자료 등록 완료 · 추가 %d개" % int(world.patch523_craft_catalog_status.get("added",0))
		else: catalog_status.text=world.PATCH523_CRAFT_CATALOG.problem)
	add_child(catalog_dialog)
	catalog_status=UI.label("제작 재료·결과의 정확한 아이템 정체를 등록합니다.",11,UI.MUTED)
	catalog_status.name="Patch523CraftCatalogStatus"
	if world.patch523_craft_catalog_status.get("ok",false):catalog_status.text="공통 제작 아이템 %d개 등록됨 · 검증된 설치 자료" % int(world.patch523_craft_catalog_status.get("registered_count",0))
	add_child(catalog_status)
	if world.protection523!=null and not world.protection523.get("source").is_empty():
		var protection_button: Button=UI.button("불멸·파멸의 가호 제작",func() -> void:world.open_patch523_protection_owner())
		protection_button.name="Patch523OpenProtectionOwner"
		add_child(protection_button)
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
		_option_source_image(equipment,equipment.item_count-1,int(source_id))
	for source_id: String in book.data.get("items", {}):
		var item: Dictionary = book.item_entry(source_id)
		var is_scroll: bool = false
		for link: Dictionary in item.item_bonuses:
			if int(book.bonus_row(str(int(link.BonusID))).get("BonusTypeID",0)) in [2022, 8352]:
				is_scroll = true
		if not is_scroll:
			continue
		scroll_ids.append(source_id)
		scroll.add_item(str(book.catalog_record_of(source_id).get("name","")))
		_option_source_image(scroll,scroll.item_count-1,int(source_id))
	equipment.item_selected.connect(func(_i: int) -> void: _refresh())
	scroll.item_selected.connect(func(_i: int) -> void: _refresh())
	# Keep source actions inside short windows while the growing installation/
	# evidence area scrolls. Rich source details must not collapse to zero height.
	var viewport:=ScrollContainer.new()
	viewport.name="Patch523EquipmentScroll"
	viewport.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	viewport.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for child: Node in get_children():
		if child is Control and child!=source_action and child!=actions:
			remove_child(child);content.add_child(child)
	add_child(viewport);viewport.add_child(content);move_child(viewport,0)
	detail.custom_minimum_size.y=180
	detail.size_flags_vertical=Control.SIZE_FILL
	detail.fit_content=true
	detail.scroll_active=false
	hud.workspace.register_scroll_drag(viewport,content)
	_refresh()

func _option_source_image(choice: OptionButton, index: int, item_class_id: int) -> void:
	if not SOURCE_IMAGES.selected(): return
	# The equipment book's identity and items keys are explicit ItemClass IDs.
	# They remain separate from the physical selection IDs and action inputs.
	var image: Dictionary = SOURCE_IMAGES.describe_item_class(item_class_id)
	choice.set_item_icon(index,image.get("texture") as Texture2D)
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	var images: Dictionary = choice.get_meta("source523_images",{})
	images[index] = evidence
	choice.set_meta("source523_images",images)

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
	var record: Dictionary=physical.get("record",book.record(str(source_id)))
	var prepared: Dictionary=world.PATCH523_ENHANCE.prepare(book,record,blessing)
	var source_rule: Dictionary=world.PATCH523_ENHANCE.rule(book,record,str(scroll_id),level_value,blessing,1)
	if source_rule.get("source_rule",false) and float(source_rule.get("success",0))>0:
		text+="\n[b]선택한 원본 정의의 규칙[/b]\n안전 강화 +%d · 성공 %.4f%% · 유지 %.4f%% · 하락 %.4f%% · 소실 %.4f%%\n성공 %s · 주문서 %d개 · %d 아데나\n%s\n실행 시에는 보유 주문서의 실제 정체를 다시 확인합니다.\n" % [int(source_rule.safe_level),float(source_rule.success),float(source_rule.no_change),float(source_rule.decrease),float(source_rule.destroy),str(source_rule.gain_text),int(source_rule.count),int(source_rule.cost),UI.safe(source_rule.basis)]
	if prepared.has("patch523_effect_basis"):
		text+="\n[b]현재 단계 적용 효과[/b]\n%s\n축복 옵션: %s\n" % [UI.safe(world.ENCHANT.summary(world._enhancement_kind_for_record(record),level_value,prepared)),UI.safe(world.EQUIPMENT_BLESSING.effect_text(str(record.get("grade","")),world._enhancement_kind_for_record(record),prepared))]
		var unconnected: Array=prepared.patch523_effect_basis.get("unconnected_effect_row_ids",[])
		if not unconnected.is_empty(): text+="이 아이템의 전체 단계 중 조건부·발동 등 미연결 원본 행 %d개: 원문 보존, 수치로 대체 적용하지 않음\n" % unconnected.size()
	var quote: Dictionary = world.patch523_seal_quote(ids[equipment.selected],str(scroll_id))
	if bool(quote.get("ok",false)):
		source_action.disabled = false
		text += "\n[b]원본 인장 강화 실행[/b]\n공식 확률 %.4f%% · 현재 +%d → +%d · 실패 %s\n주문서 %d개 · %d 아데나\n%s\n" % [float(quote.success),level_value,level_value+1,"유지" if bool(quote.protected) else "소실",int(quote.count),int(quote.cost),UI.safe(quote.economy_label)]
	else:
		text += "\n원본 인장 강화: %s\n" % UI.safe(str(quote.get("reason","실행 조건을 확인하세요")))
	var final_base: Dictionary=preload("res://scripts/crafting/patch523_final_blow.gd").base(book,physical.get("record",{}),blessing)
	if not final_base.is_empty():text+="\n원본 기본 결정타 %.2f%% · 증폭 %.2f%% · 적용 범위/계산 순서는 TWILIGHT 설정\n" % [float(final_base.get("source_final_blow_chance_pct",0)),float(final_base.get("source_final_blow_amp_pct",0))]
	text+="\n스턴 조건 주체: %s · 원본 상태6/단위/수치 보존, 주체와 계산 범위는 TWILIGHT 설정\n" % UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_stun_condition_subject","disabled")))
	text+="\nPVP 수치의 싱글플레이어 투영: %s / 스킬 성공 가상 레벨: %s\n실제 캐릭터 레벨·경험치 불변 · 여섯 기존 상태 성공 계산만 사용(TWILIGHT 설정)\n공포8 조건: 주체 %s · 범위 %s · 처리 %s\n" % [UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_pvp_flat_ignore_consumer","disabled"))),UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_pvp_status_level_consumer","disabled"))),UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_fear_condition_subject","disabled"))),UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_fear_flat_ignore_scope","disabled"))),UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_fear_flat_ignore_consumer","disabled")))]
	text+="\n유형별 리덕션 무시 처리: %s\n원본 수치 보존 · NPC AC/리덕션 공식 복원이 아닌 TWILIGHT 기존 추가 피해 해석\n" % UI.safe(str(world.PATCH523_ENHANCE.policy().get("source_typed_flat_ignore_consumer","disabled")))
	if book.data.get("equipment_spell_item_constraints",{}).has(str(source_id)):
		var source_spell_reason: String=preload("res://scripts/crafting/patch523_equipment_spells.gd").item_reason(world,record,str(source_id))
		text+="\n장비 발동 실행 자격: %s\n원본 주문 수치·확률·기간 보존 / MR·속성·리덕션 단계와 반격 순서는 TWILIGHT 설정\n" % UI.safe("현재 소유/직업/기간 조건 충족" if source_spell_reason.is_empty() else source_spell_reason)
	var effect_text: String = ""
	var effects: Array = book.effect_evidence(source_id, level_value, 2 if blessing == 2 else 0)
	if not effects.is_empty():
		effect_text += "\n[b]해당 단계 원본 효과[/b]" + ("\n" if blessing == 2 else " · 기본계열 선택: 게임 설정\n")
		var labels: Dictionary = {"MeleeHit":"근거리 명중", "RangeHit":"원거리 명중", "MeleeDamage":"근거리 대미지", "RangeDamage":"원거리 대미지", "DamageReduction":"대미지 리덕션", "HPPotionIncreaseStatic":"물약 회복량", "HPPotionIncreasePercent":"물약 회복률", "ExperienceAdditionPercent":"경험치 증가율", "EinasadSavingPercent":"아인하사드 절약", "PotionConsumeDelayDecreasePercent":"물약 쿨타임 감소", "SpecialResistance":"특수 내성"}
		var supported: Dictionary = {"MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","DamageReduction":"reduction","HPPotionIncreaseStatic":"potion_heal_flat","HPPotionIncreasePercent":"potion_heal_pct","ExperienceAdditionPercent":"xp_pct","EinasadSavingPercent":"ain_saving_pct","PotionConsumeDelayDecreasePercent":"potion_cooldown_pct","SpecialResistance":"stun_resistance"}
		var expected_options: Dictionary = book.supported_seal_options(str(source_id),2).get(str(level_value), {})
		var actual_options: Dictionary = physical.get("record", {}).get("enhancement_options", {}).get(str(level_value), {})
		labels.merge({"ArmorClass":"물리 방어력(AC)","WeaponDamageBonus":"추가 대미지","WeaponHitBonus":"무기 명중","HPPlus":"최대 HP","MPPlus":"최대 MP","CarryPlus":"무게 보너스","MagicResist":"MR","SpellPower":"SP","MeleeCritical":"근거리 치명타","RangeCritical":"원거리 치명타","MagicCritical":"마법 치명타","AttackSpeedBonus":"공격 속도","MoveSpeedBonus":"이동 속도","RegenMP":"MP 회복","PVEDamageReduction":"PVE 리덕션","PVPDamageReduction":"PVE 리덕션","PVEDamageReductionPercent":"PVE 리덕션 비율"})
		labels.merge({"PierceDamageReductionPercent":"대미지 증가","PVEPierceDamageReductionPercent":"PVE 대미지 증가","DamageReductionPercent":"대미지 감소","IncreaseNpcItemDropAmount":"아데나 드롭량"})
		labels.merge({"HPHealIncreasePercent":"회복 마법량","CastSpeedBonus":"시전 속도","MeleeCriticalResist":"근거리 치명타 저항","RangeCriticalResist":"원거리 치명타 저항","MeleeDamageReductionPercent":"근거리 대미지 감소","RangeDamageReductionPercent":"원거리 대미지 감소","MagicDamageReductionPercent":"마법 대미지 감소","PoisonDamageReductionPercent":"지속 대미지 감소"})
		labels.merge({"StrengthScale":"STR 비율","DexterityScale":"DEX 비율","IntelligenceScale":"INT 비율"})
		labels.merge({"PiercePVPDamageReduction":"PVP 대미지 리덕션 무시","PVPSpellByLevelAdditionLevel":"PVP 스킬 성공 레벨","FinalBlowProbability":"결정타 확률","FinalBlowAdditionalScale":"결정타 증폭","ElementalDamage":"속성별 고정 추가 피해 · 개별 저항 적용(TWILIGHT 설정)","AttackDrainHP":"공격 HP 흡수 강화량","AttackDrainMP":"공격 MP 흡수 강화량","UndeadAdditionalMaxDamage":"언데드 추가 피해 최댓값"})
		for effect: Dictionary in effects:
			var kind: String = str(effect.bonus_type.get("Name", ""))
			var value: String = str(int(effect.bonus.Value))
			if int(effect.bonus_type.get("UnitID", 0)) == 3:
				value = "%.2f%%" % (float(effect.bonus.Value) / 10000.0)
			elif int(effect.bonus_type.get("UnitID",0))==211:value="%.2f%%" % float(effect.bonus.Value)
			elif int(effect.bonus_type.get("UnitID",0))==44:value="%.2f" % (float(effect.bonus.Value)/100.0)
			var label: String = str(labels.get(kind, kind))
			if kind=="InvokeOption":label="발동 확률"
			if kind=="FixedDesc" and int(effect.bonus.BonusApplicationTypeID)==72 and int(effect.bonus.BonusApplicationTargetID)==1111182 and int(effect.bonus.Value)==1111192:
				label="스턴 시간 감소(원문 설명)";value="1초 · 원본 지정 주문별 실행 계약 미연결"
			if kind == "SpecialResistance" and int(effect.bonus.BonusApplicationTypeID) == 2 and int(effect.bonus.BonusApplicationTargetID) == 6:
				label = "스턴 내성"
			if kind in ["SpecialResistance","HitSpecialResistance"] and int(effect.bonus.BonusApplicationTypeID)==2:
				var status_name: String="원본#%d" % int(effect.bonus.BonusApplicationTargetID)
				for status: Dictionary in book.data.enchantment.get("SpecialResistanceType",[]):
					if int(status.ID)==int(effect.bonus.BonusApplicationTargetID):status_name=str({"Stun":"스턴","Hold":"홀드","Fear":"공포","Poison":"독","Silence":"침묵"}.get(status.Name,status.Name));break
				label=status_name+(" 적중" if kind=="HitSpecialResistance" else " 내성")
			if kind=="ElementalDamage" and int(effect.bonus.BonusApplicationTypeID)==3:
				var target_channel: String=str(world.PATCH523_ENHANCE.policy().get("source_elemental_target_channels",{}).get(str(int(effect.bonus.BonusApplicationTargetID)),"미확인"))
				label=str({"fire":"불","water":"물","wind":"바람","earth":"땅"}.get(target_channel,target_channel))+" 속성 추가 피해 · 저항/범위는 TWILIGHT 설정"
			var applied: bool = blessing == 2 and supported.has(kind) and expected_options.has(supported[kind]) and actual_options.get(supported[kind]) == expected_options[supported[kind]]
			if prepared.get("patch523_effect_basis",{}).get("selection")=="source_exact_level":
				applied=int(effect.row.ID) not in prepared.patch523_effect_basis.get("unconnected_effect_row_ids",[])
				if kind=="InvokeOption":
					applied=false
					for live: Dictionary in world.PATCH523_EQUIPMENT_COMBAT.level_effects(prepared,level_value):
						if int(live.row_id)==int(effect.row.ID):applied=true;break
			var sign: String="-" if kind=="ArmorClass" else "+"
			var application_label: String="적용 연결" if applied else "참고·적용 미연결"
			if applied and kind in ["PiercePVPDamageReduction","PVPSpellByLevelAdditionLevel"]:
				var setting: String="source_pvp_flat_ignore_consumer" if kind=="PiercePVPDamageReduction" else "source_pvp_status_level_consumer"
				var enabled: String="existing_singleplayer_flat_damage_projection" if kind=="PiercePVPDamageReduction" else "existing_singleplayer_status_virtual_level"
				application_label="싱글플레이어 해석 연결(TWILIGHT)" if world.PATCH523_ENHANCE.policy().get(setting)==enabled else "설정 꺼짐·원본 보존"
			if applied and kind=="PierceDamageReduction" and int(effect.bonus.BonusApplicationTypeID)==2 and int(effect.bonus.BonusApplicationTargetID)==8:
				label="공포8 조건 대미지 리덕션 무시"
				application_label="공포 상태·주체·범위 조건부 연결(TWILIGHT)" if world.PATCH523_ENHANCE.policy().get("source_fear_flat_ignore_consumer")=="existing_flat_damage_projection" and world.PATCH523_ENHANCE.policy().get("source_fear_condition_subject") in ["target_status","self_status"] and world.PATCH523_ENHANCE.policy().get("source_fear_flat_ignore_scope") in ["all_successful_hits","normal_only","spell_hits_only"] else "설정 꺼짐·원본 보존"
			effect_text += "%s %s%s · %s\n" % [UI.safe(label),sign,value,application_label]
	var displayed: Dictionary = {}
	var blessing_branches: Array = [1]
	for link: Dictionary in book.item_entry(str(scroll_id)).get("item_bonuses", []):
		if int(book.bonus_row(str(int(link.BonusID))).get("BonusTypeID",0)) == 8352:
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
			text += "원본 단계 %d · %s\n성공 %.4f%% · 소실 %.4f%% · 부작용 %.4f%% · 유지 %.4f%%\n" % [int(row.EnchantLevel), "기본 대상 선택(원본0·게임 해석)" if int(row.TargetItemBlessCode) == 0 else ("축복 장비" if int(row.TargetItemBlessCode) == 2 else "일반 장비"), 100.0 * float(row.Success)/total, 100.0 * float(row.Vaporize)/total, 100.0 * float(row.SideEffect)/total, 100.0 * float(row.Remain)/total]
		for row: Dictionary in evidence.costs:
			text += "원본 재료 수량 %d · 비용 값 %d(통화 미확정)\n" % [int(row.ConsumeAmount), int(row.Cost)]
	if displayed.is_empty():
		text += "\n선택한 장비·주문서·단계에 표시 가능한 원본 확률 행이 없습니다. 안전 강화나 확률을 추정하지 않습니다.\n"
	text += effect_text
	text += "\n[color=#b9a67e]현재 강화 화면은 원본 아이템·주문서 그룹을 우선 적용합니다. 비용값은 원본이며 통화·수량0·기본축복 선택·부작용 하락폭은 별도 게임 설정입니다. 표에 없는 기존 장비는 기존 규칙을 유지합니다.[/color]"
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
