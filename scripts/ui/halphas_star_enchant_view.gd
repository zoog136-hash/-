extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
var world: Node
var category: String
var identity: String
var selected: Dictionary = {}
var status_label: Label
var last_message: String = ""
var charge_label: Label
var charge_release: Button
const STAT_NAMES: Dictionary = {"hpFlat":"최대 HP", "mpFlat":"최대 MP", "strFlat":"STR", "dexFlat":"DEX", "intFlat":"INT", "conFlat":"CON", "wisFlat":"WIS", "def":"방어력", "damage_reduction_ignore":"대미지 감소 무시", "meleeDamage":"근거리 대미지", "rangedDamage":"원거리 대미지", "magicDamage":"마법 대미지", "hp_regen":"HP 회복", "mp_regen":"MP 회복", "attackSpeed":"공격 속도 %", "speedBonusPct":"이동 속도 %", "skillCooldownPct":"스킬 재사용 감소 %", "stun_accuracy":"스턴 적중 %", "stun_resistance":"스턴 내성 %", "hold_accuracy":"홀드 적중 %", "hold_resistance":"홀드 내성 %", "fear_accuracy":"공포 적중 %", "fear_resistance":"공포 내성 %", "dark_accuracy":"암흑 적중 %", "dark_resistance":"암흑 내성 %", "ice_accuracy":"동빙 적중 %", "ice_resistance":"동빙 내성 %", "charge_time_reduction_pct":"차징 감소 %"}
func configure(host: Node, cat: String, id: String) -> void:
	world=host;category=cat;identity=id
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	refresh()
func line(text: String, size_value: int = 14) -> Label:
	var label: Label=UI.label(text,size_value,UI.TEXT)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(label);return label
func refresh() -> void:
	for child: Node in get_children():remove_child(child);child.queue_free()
	var state: Dictionary=world.halphas_star.view(identity)
	if not state.ok:line(str(state.error));return
	line("TWILIGHT 추정 규칙 · %s · 획득 단계 %d / 3" % ["보유" if state.owned else "미보유",state.earned_stage],16)
	line("원본 비용·수량을 사용합니다. 확률 단위·재료 종류·실패 처리·효과 집계는 자체 설정입니다.")
	line("원본 비활성·서버 제한은 별도로 유지합니다. 외형 선택은 획득 단계로 계산하지 않습니다.")
	for row: Dictionary in state.stages:
		var label: Label=line("%d단계 · 유일 변신 중복 %d장 · 아데나 %d · 추정 %.1f%%" % [row.Enchant,row.SourceAmount,row.CurrencyCost,100.0*float(row.Probability)/maxf(1.0,float(world.halphas_star.settings.get("probability_scale",1000000)))],15)
		label.name="HalphasStage"+str(int(row.Enchant))
	var needed: int=int(state.get("next_rule",{}).get("SourceAmount",0))
	line("재료 선택 · 중복 카드만 소비하며 최초 보유 카드는 남습니다.")
	for item: Dictionary in state.materials:
		var row:=HBoxContainer.new();add_child(row)
		var label: Label=UI.label("%s · 중복 %d장" % [item.name,item.spare],14,UI.TEXT)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var amount:=SpinBox.new();amount.name="HalphasMaterial"+str(item.id).replace(":","_")
		amount.min_value=0;amount.max_value=mini(needed,int(item.spare));amount.step=1
		amount.value=mini(int(selected.get(item.id,0)),int(amount.max_value));selected[item.id]=int(amount.value)
		row.add_child(amount)
		amount.value_changed.connect(func(value: float): selected[item.id]=int(value); _update_attempt())
	var auto: Button=UI.button("필요 수량 자동 선택",_auto_select,Vector2(0,42));auto.name="HalphasAutoSelect";add_child(auto)
	line("실패해도 단계·보유 카드는 유지됩니다. " + ("시도 시 재료와 아데나를 소비합니다." if world.halphas_star.settings.failure_consumes_material_and_gold else "실패 시 재료와 아데나를 소비하지 않습니다."))
	if not state.bonuses.is_empty():
		var pieces:=PackedStringArray()
		for key: String in state.bonuses:pieces.append(str(STAT_NAMES.get(key,key))+" +"+str(state.bonuses[key]))
		line("획득 단계 효과 · 장착·활성 조건 충족 시 적용: "+", ".join(pieces))
	line("상태 효과 연결 · 스턴·홀드·공포·암흑·동빙 (후반2종은 자체 동작)")
	var pending: Label=line("암흑은 공격 명중 저하, 동빙은 이동·행동 봉쇄, 차징 시간은 자체 환산을 사용합니다.")
	pending.name="HalphasPendingEffects"
	line("동일 단계·상태의 독립 보너스는 현재 게임의 합산 규칙을 따릅니다.")
	status_label=line(last_message if not last_message.is_empty() else str(state.blocked_reason))
	status_label.name="HalphasStarEnchantStatus"
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);add_child(actions)
	var recheck: Button=UI.button("강화 조건 다시 확인",_check,Vector2(0,48));recheck.name="HalphasStarEnchantCheck";recheck.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(recheck)
	var attempt: Button=UI.button("성급 강화",_confirm,Vector2(0,48));attempt.name="HalphasStarEnchantAttempt";attempt.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(attempt)
	_update_attempt()
	var appearance: Button=UI.button("획득 단계 외형 적용",_appearance,Vector2(0,42));appearance.name="HalphasApplyAppearance"
	appearance.disabled=int(state.earned_stage)<1 or not world.halphas_star.technical_problem().is_empty();add_child(appearance)
	line("자체 전투 %s · 암흑 명중 ×%.2f · 동빙 행동 봉쇄 %s" % ["ON" if world.halphas_star.combat.enabled() else "OFF",world.halphas_star.combat.number("dark_hit_multiplier",.5,.05,1.0),"ON" if world.halphas_star.settings.custom_combat.ice_blocks_movement_and_actions else "OFF"])
	line("자체 차징 시간 = 원본 시간 ÷ (1 + 감소%/100), 최소0.1초" if world.halphas_star.settings.custom_combat.charge_time_formula=="source_time_divided_by_one_plus_reduction_percent" else "자체 차징 시간 = 원본 시간 × (1 - 감소%/100), 최소0.1초")
	line("습득한 쇼크 스턴만 자체 차징합니다. 해제 시 기존 시전 비용을1회 소비하고, 취소·시간초과는 소비하지 않습니다.")
	charge_label=line("");charge_label.name="HalphasChargeState"
	var start: Button=UI.button("자체 쇼크 스턴 차징",_charge_start,Vector2(0,42));start.name="HalphasChargeStart";start.disabled=not world.halphas_star.active() or not world.halphas_star.combat.enabled();add_child(start)
	charge_release=UI.button("차징 해제·시전",_charge_release,Vector2(0,42));charge_release.name="HalphasChargeRelease";add_child(charge_release)
	var cancel: Button=UI.button("차징 취소",_charge_cancel,Vector2(0,42));cancel.name="HalphasChargeCancel";add_child(cancel)
	_process(0)
func _process(_delta: float) -> void:
	if not is_instance_valid(charge_label) or world==null:return
	var info: Dictionary=world.halphas_star.combat.charge_view()
	charge_label.text="자체 차징 · %s · %d단계 · %.2f / %.2f초" % ["진행" if info.active else "대기",info.stage,info.elapsed,info.total]
	charge_release.disabled=not info.active or int(info.stage)<1
func _charge_start() -> void:
	var result: Dictionary=world.halphas_star.combat.start_charge()
	last_message="자체 차징 시작 · 아직 소비 없음" if result.ok else str(result.error)
	refresh()
func _charge_release() -> void:
	var result: Dictionary=world.halphas_star.combat.release_charge()
	last_message="자체 차징 %d단계 시전 · 기존 비용1회 소비" % result.stage if result.ok else str(result.error)
	refresh()
func _charge_cancel() -> void:
	world.halphas_star.combat.cancel_charge();last_message="자체 차징 취소 · 소비 없음";refresh()

func _update_attempt() -> void:
	var action: Button=find_child("HalphasStarEnchantAttempt",true,false)
	if action==null:return
	var state: Dictionary=world.halphas_star.view(identity)
	var total: int=0
	for count: Variant in selected.values():total+=int(count)
	action.disabled=not state.get("can_attempt",false) or total!=int(state.get("next_rule",{}).get("SourceAmount",0))
func _auto_select() -> void:
	var state: Dictionary=world.halphas_star.view(identity)
	var left: int=int(state.get("next_rule",{}).get("SourceAmount",0));selected.clear()
	for item: Dictionary in state.get("materials",[]):
		var count: int=mini(left,int(item.spare));selected[item.id]=count;left-=count
	refresh()
func _check() -> void:
	var state: Dictionary=world.halphas_star.view(identity)
	last_message="확인 결과 · "+str(state.blocked_reason)+" · 확인만으로 재료와 아데나는 소모되지 않습니다."
	refresh()
func _confirm() -> void:
	var state: Dictionary=world.halphas_star.view(identity)
	if not state.get("can_attempt",false):_check();return
	var material: Dictionary={};var names:=PackedStringArray()
	for item: Dictionary in state.materials:
		var count: int=int(selected.get(item.id,0))
		if count>0:material[item.id]=count;names.append("%s %d장" % [item.name,count])
	var revision: int=int(state.revision)
	var operation: String="halphas-%d-%d" % [Time.get_ticks_usec(),get_instance_id()]
	var message: String="%d단계 강화 · 추정 %.1f%%\n%s\n아데나 %d\n%s" % [state.next_rule.Enchant,100.0*float(state.next_rule.Probability)/maxf(1.0,float(world.halphas_star.settings.get("probability_scale",1000000))),", ".join(names),state.next_rule.CurrencyCost,"실패 시에도 재료·아데나 소비, 단계 유지" if world.halphas_star.settings.failure_consumes_material_and_gold else "실패 시 재료·아데나 보존, 단계 유지"]
	world.hud.confirm_action("할파스 성급 강화 확인",message,"강화",func(_count: int):
		if not is_instance_valid(self):return
		var result: Dictionary=world.halphas_star.attempt(identity,material,revision,operation)
		last_message=("강화 %s · 현재 %d단계 · 아데나 %d / 카드 %d장 소비" % ["성공" if result.success else "실패",result.level,result.get("consumed_gold",0),result.get("consumed_cards",0)]) if result.ok else str(result.error)
		selected.clear();refresh())
func _appearance() -> void:
	var result: Dictionary=world.halphas_star.apply_appearance(identity,int(world.halphas_star.progress.revision))
	last_message="획득 단계 외형을 저장했습니다." if result.ok else str(result.error)
	refresh()
