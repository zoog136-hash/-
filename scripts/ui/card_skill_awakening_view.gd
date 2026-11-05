extends VBoxContainer
## Source candidates and explicit user-policy atomic awakening transaction.
const Presentation=preload("res://scripts/cards/source_card_operation_presentation.gd")
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Ownership=preload("res://scripts/ui/catalog_card_ownership.gd")
const SourceSkin=preload("res://scripts/ui/source_skill_awakening_skin.gd")
const SkillImages=preload("res://scripts/ui/source523_skill_buff_images.gd")
const ItemImages=preload("res://scripts/ui/source523_image_assets.gd")
var runtime: RefCounted
var identity: String
var level: OptionButton
var stats: Label
var current: Label
var candidates: ItemList
var effect: RichTextLabel
var action: Button
var growth: Label
var snapshot: Dictionary={}
func configure(service: RefCounted,target: String) -> void:
	runtime=service;identity=target
	if not Presentation.available(Presentation.AWAKENING):return
	size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	name="CardSkillAwakeningView"
	snapshot=runtime.view(identity)
	if not snapshot.ok:add_child(UI.label(str(snapshot.error),16));return
	var header:=HBoxContainer.new();add_child(header)
	var portrait:=preload("res://scripts/ui/source_skill_awakening_target.gd").new();portrait.name="SkillAwakeningTargetArt"
	portrait.custom_minimum_size=Vector2(240,102)
	portrait.portrait=Ownership.icon_for(snapshot.get("target_record",{}),bool(snapshot.owned));header.add_child(portrait)
	var info:=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(info)
	info.add_child(UI.label(str(snapshot.card.name)+" · 스킬 각성",18,UI.GOLD))
	current=UI.label("",14);current.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(current)
	var selected_id: int=int(snapshot.entry.spell_id)
	current.text="현재 각성 스킬 없음" if selected_id==0 else str(runtime.core.DATA.data.spells.get(str(selected_id),{}).get("name","미지원 스킬"))+" · Lv."+str(int(snapshot.entry.level))
	if not snapshot.owned:current.text+=" · 미보유 · 조회 전용"
	growth=UI.label("저장 경험치 "+str(snapshot.entry.experience)+" · 재각성 시 Lv.1 · 경험치 0부터",12,UI.MUTED)
	growth.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(growth)
	if bool(snapshot.get("save_blocked",false)):info.add_child(UI.label("저장 보호 중 · 정상 저장 불러오기 필요",12,UI.GOLD))
	var book: Label=UI.label("필요 각성서: "+str(snapshot.book.get("name","원본 연결 없음"))+" · 1장 소모",12,UI.MUTED);book.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(book)
	level=OptionButton.new();level.name="SkillAwakeningPreviewLevel";level.custom_minimum_size.y=44
	for value: int in range(1,21):level.add_item("원본 레벨 프로필 미리보기 · "+str(value),value)
	add_child(level);level.item_selected.connect(_preview)
	stats=UI.label("",13);stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(stats)
	var warning: Label=UI.label(str(snapshot.blocked_reason),12,UI.GOLD);warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(warning)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(body)
	candidates=preload("res://scripts/ui/native_touch_list.gd").new();candidates.name="SkillAwakeningCandidates";candidates.size_flags_horizontal=Control.SIZE_EXPAND_FILL;candidates.size_flags_vertical=Control.SIZE_EXPAND_FILL;candidates.custom_minimum_size=Vector2(240,120);candidates.add_theme_font_size_override("font_size",13);candidates.add_theme_constant_override("v_separation",22);body.add_child(candidates)
	effect=RichTextLabel.new();effect.name="SkillAwakeningSourceEffects";effect.size_flags_horizontal=Control.SIZE_EXPAND_FILL;effect.size_flags_vertical=Control.SIZE_EXPAND_FILL;effect.custom_minimum_size=Vector2(200,120);body.add_child(effect)
	var source_images: Array=[]
	for row: Dictionary in snapshot.candidates:
		var visual: Dictionary=SkillImages.describe_spell_class_row(row.source_spell,"IconID")
		var index: int=candidates.add_item(str(row.name)+" · 후보 선택 "+str(float(row.selection_weight)/1000.0)+"%",visual.get("texture") as Texture2D)
		candidates.set_item_metadata(index,int(row.spell_id))
		source_images.append(SkillImages.evidence(visual))
	candidates.set_meta("source523_skill_images",source_images)
	candidates.item_selected.connect(_select)
	var skill_panel: StyleBoxTexture=SourceSkin.panel("Img_Bg","Textuer_Inventory.png")
	if skill_panel!=null:candidates.add_theme_stylebox_override("panel",skill_panel)
	var detail_panel: StyleBoxTexture=SourceSkin.panel("Img_Bg","Img_Bg_Radius3.png")
	if detail_panel!=null:effect.add_theme_stylebox_override("normal",detail_panel)
	var reason: Label=UI.label(str(snapshot.blocked_reason),13,UI.MUTED);reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(reason)
	if not snapshot.eligibility.ok:
		var eligibility: Label=UI.label(str(snapshot.eligibility.error),13,UI.GOLD);add_child(eligibility)
	action=UI.button("재각성" if int(snapshot.entry.spell_id)>0 else "각성",_execute,Vector2(0,44))
	action.set_script(preload("res://scripts/ui/native_touch_button.gd"))
	action.name="SkillAwakeningExecute";action.disabled=not bool(snapshot.can_awaken) or bool(snapshot.get("save_blocked",false));action.tooltip_text=str(snapshot.blocked_reason);add_child(action)
	_bind_book_image()
	var original_action: bool=SourceSkin.button(action,"Btn_Production")
	var note: Label=UI.label("옵션 각성과 별도 상태 · 원본 각성 재질 적용 / 반응형 배치" if original_action else "원본 각성 화면 재질 미설치",12,UI.MUTED);add_child(note)
	_preview(0)
	if candidates.item_count>0:candidates.select(0);_select(0)
func _bind_book_image() -> void:
	action.icon=null
	if action.has_meta("source523_book_image"):action.remove_meta("source523_book_image")
	if not ItemImages.selected():return
	var book: Dictionary=snapshot.get("book",{})
	var item: Variant=book.get("item_row")
	var requirement: Dictionary=snapshot.get("book_requirement",{})
	var item_id: Variant=requirement.get("item_class_id")
	if not item is Dictionary or not ItemImages.PACK._integer(item_id) or int(item_id)<=0 or item.get("ID")!=item_id:return
	var image: Dictionary=ItemImages.describe_item_class_row(item,str(book.get("name","")))
	action.icon=image.get("texture") as Texture2D
	action.expand_icon=true
	var evidence: Dictionary=image.duplicate(true)
	evidence.erase("texture")
	evidence["caller_item_class_id"]=item_id
	action.set_meta("source523_book_image",evidence)

func _preview(index: int) -> void:
	var data: Dictionary=runtime.view(identity,index+1)
	var p: Dictionary=data.get("preview_profile",{})
	stats.text="원본 레벨 프로필 없음" if p.is_empty() else "미리보기 HP +%d · 발동 %s%% · 지연 보정 -%s초 · 원본 누적 경험치 기준 %s" % [int(p.hp),str(float(p.invoke.CastSuccessProb)/100.0),str(float(p.invoke.CastDelayBonus)/1000.0),str(int(p.experience_row.CumExp))]
	stats.tooltip_text="미리보기는 저장 상태를 변경하지 않습니다. 원본 레벨 수치와 게임의 성장 환산·수수료 설정을 구분합니다."
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

func _execute() -> void:
	if not Presentation.available(Presentation.AWAKENING):return
	action.disabled=true
	var result: Dictionary=runtime.request_operation(identity,{"expected_revision":int(runtime.progress.revision)})
	if result.ok:
		snapshot=runtime.view(identity)
		current.text=str(runtime.core.DATA.data.spells[str(int(snapshot.entry.spell_id))].name)+" · Lv."+str(int(snapshot.entry.level))
		growth.text="저장 경험치 "+str(snapshot.entry.experience)+" · 재각성 시 Lv.1 · 경험치 0부터"
	else:current.text=str(result.error)
	action.disabled=not bool(snapshot.can_awaken) or bool(snapshot.get("save_blocked",false))
	refresh_growth()

func refresh_growth(_force: bool=false) -> void:
	if not Presentation.available(Presentation.AWAKENING):return
	# Existing read-only saved EXP text; no material picker or synthesis form.
	snapshot=runtime.view(identity)
	if not snapshot.ok:return
	_bind_book_image()
	var entry: Dictionary=snapshot.entry
	current.text="현재 각성 스킬 없음" if int(entry.spell_id)==0 else str(runtime.core.DATA.data.spells[str(int(entry.spell_id))].name)+" · Lv."+str(int(entry.level))
	growth.text="저장 경험치 "+str(entry.experience)+" · 재각성 시 Lv.1 · 경험치 0부터"

func _feed_experience() -> Dictionary:
	return Presentation.request(Presentation.GROWTH)
