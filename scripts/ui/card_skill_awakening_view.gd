extends VBoxContainer
## Read-only source catalog and saved effects. No guessed price or free unlock.
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Ownership=preload("res://scripts/ui/catalog_card_ownership.gd")
var runtime: RefCounted
var identity: String
var level: OptionButton
var stats: Label
var current: Label
var candidates: ItemList
var effect: RichTextLabel
var action: Button
var snapshot: Dictionary={}
func configure(service: RefCounted,target: String) -> void:
	runtime=service;identity=target
	size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	name="CardSkillAwakeningView"
	snapshot=runtime.view(identity)
	if not snapshot.ok:add_child(UI.label(str(snapshot.error),16));return
	var header:=HBoxContainer.new();add_child(header)
	var portrait:=TextureRect.new();portrait.name="SkillAwakeningTargetArt"
	portrait.custom_minimum_size=Vector2(80,96);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture=Ownership.icon_for(snapshot.get("target_record",{}),bool(snapshot.owned));header.add_child(portrait)
	var info:=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(info)
	info.add_child(UI.label(str(snapshot.card.name)+" · 스킬 각성",18,UI.GOLD))
	current=UI.label("",14);current.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(current)
	var selected_id: int=int(snapshot.entry.spell_id)
	current.text="현재 각성 스킬 없음" if selected_id==0 else str(runtime.core.DATA.data.spells.get(str(selected_id),{}).get("name","미지원 스킬"))+" · Lv."+str(int(snapshot.entry.level))
	if not snapshot.owned:current.text+=" · 미보유 · 조회 전용"
	info.add_child(UI.label("저장 경험치 "+str(snapshot.entry.experience)+" · 재각성 시 경험치 유지",12,UI.MUTED))
	if bool(snapshot.get("save_blocked",false)):info.add_child(UI.label("저장 보호 중 · 정상 저장 불러오기 필요",12,UI.GOLD))
	var book: Label=UI.label("필요 각성서: "+str(snapshot.book.get("name","원본 연결 없음"))+" · 소모 수량 확인 중",12,UI.MUTED);book.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(book)
	level=OptionButton.new();level.name="SkillAwakeningPreviewLevel";level.custom_minimum_size.y=44
	for value: int in range(1,21):level.add_item("원본 레벨 프로필 미리보기 · "+str(value),value)
	add_child(level);level.item_selected.connect(_preview)
	stats=UI.label("",13);stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(stats)
	var warning: Label=UI.label(str(snapshot.blocked_reason),12,UI.GOLD);warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(warning)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(body)
	candidates=preload("res://scripts/ui/native_touch_list.gd").new();candidates.name="SkillAwakeningCandidates";candidates.size_flags_horizontal=Control.SIZE_EXPAND_FILL;candidates.size_flags_vertical=Control.SIZE_EXPAND_FILL;candidates.custom_minimum_size=Vector2(240,120);candidates.add_theme_font_size_override("font_size",13);candidates.add_theme_constant_override("v_separation",22);body.add_child(candidates)
	effect=RichTextLabel.new();effect.name="SkillAwakeningSourceEffects";effect.size_flags_horizontal=Control.SIZE_EXPAND_FILL;effect.size_flags_vertical=Control.SIZE_EXPAND_FILL;effect.custom_minimum_size=Vector2(200,120);body.add_child(effect)
	for row: Dictionary in snapshot.candidates:
		var index: int=candidates.add_item(str(row.name)+" · 후보 선택 "+str(float(row.selection_weight)/1000.0)+"%")
		candidates.set_item_metadata(index,int(row.spell_id))
	candidates.item_selected.connect(_select)
	var reason: Label=UI.label(str(snapshot.blocked_reason),13,UI.MUTED);reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(reason)
	if not snapshot.eligibility.ok:
		var eligibility: Label=UI.label(str(snapshot.eligibility.error),13,UI.GOLD);add_child(eligibility)
	action=UI.button("각성 · 원본 소모 규칙 확인 중",Callable(),Vector2(0,44));action.name="SkillAwakeningExecute";action.disabled=true;action.tooltip_text="미확정 수수료·각성서 수량·실패/회수 공식은 적용하지 않습니다";add_child(action)
	var note: Label=UI.label("옵션 각성·시각 aura와 별도 상태 · 원본 각성 화면 스킨 연결 대기",12,UI.MUTED);add_child(note)
	_preview(0)
	if candidates.item_count>0:candidates.select(0);_select(0)
func _preview(index: int) -> void:
	var data: Dictionary=runtime.view(identity,index+1)
	var p: Dictionary=data.get("preview_profile",{})
	stats.text="원본 레벨 프로필 없음" if p.is_empty() else "미리보기 HP +%d · 발동 %s%% · 지연 보정 -%s초 · 원본 누적 경험치 기준 %s" % [int(p.hp),str(float(p.invoke.CastSuccessProb)/100.0),str(float(p.invoke.CastDelayBonus)/1000.0),str(int(p.experience_row.CumExp))]
	stats.tooltip_text="미리보기는 저장 레벨·보유·능력치를 변경하지 않습니다. CumExp를 임의의 레벨업/실패 공식으로 사용하지 않습니다."
func _select(index: int) -> void:
	if index<0 or index>=snapshot.candidates.size():return
	var row: Dictionary=snapshot.candidates[index]
	var lines: PackedStringArray=[str(row.name),"후보 선택 가중치 "+str(row.selection_weight)+" / "+str(row.selection_total),"발동 확률은 카드 레벨 프로필에서 별도 적용"]
	var damage: Dictionary=runtime.core.fixed_damage_profile(int(row.spell_id))
	if not damage.is_empty():
		var minimum: int=int(damage.SpellDamageBase)+int(damage.SpellDamageDiceNumber)
		var maximum: int=int(damage.SpellDamageBase)+int(damage.SpellDamageDiceNumber)*int(damage.SpellDamageDiceSpotCount)
		lines.append("고정 마법 피해 "+str(minimum)+(" ~ "+str(maximum) if maximum!=minimum else ""))
	lines.append("기본 발동 간격 "+str(float(row.source_spell.CastDelay)/1000.0)+"초")
	lines.append("발동 시 HP "+str(int(row.source_spell.HPCost))+" / MP "+str(int(row.source_spell.MPCost))+" 소모")
	effect.text="\n".join(lines)
