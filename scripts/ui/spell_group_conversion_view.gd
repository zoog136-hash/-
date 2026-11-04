extends VBoxContainer
const UI=preload('res://scripts/ui/renewal_theme.gd')
var world:Node
var choices:OptionButton
var payment:OptionButton
var message:Label
var confirm:Button
var dialog:ConfirmationDialog
var pending:Dictionary={}
func configure(owner:Node)->void:
 world=owner;name='SpellGroupConversionView'
 var title:=Label.new();title.text='현재 직업의 스킬 계열 전환';add_child(title)
 choices=OptionButton.new();choices.name='SpellGroupCandidates';choices.custom_minimum_size.y=44;add_child(choices)
 payment=OptionButton.new();payment.name='SpellGroupPayment';payment.custom_minimum_size.y=44
 for label:String in ['아데나','회상의 촛불 · 원본 ID 1122','회상의 촛불 · 원본 ID 32801']:payment.add_item(label)
 add_child(payment)
 message=Label.new();message.name='SpellGroupQuote';message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(message)
 var policy:=Label.new();policy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 policy.text='전환해도 학습 기록·퀵슬롯·자동사용 지정은 보존합니다. 비선택 계열의 보유스킬은 삭제하지 않고 사용 조건만 바뀝니다. 회차는 이 캐릭터의 직업별로 기록하는 TWILIGHT 정책입니다.';add_child(policy)
 confirm=UI.button('전환 내용 확인',show_confirmation);confirm.name='SpellGroupReview';add_child(confirm)
 dialog=ConfirmationDialog.new();dialog.name='SpellGroupConfirm';dialog.title='스킬 계열 전환 확인';dialog.ok_button_text='비용 지불 후 전환';dialog.cancel_button_text='취소';add_child(dialog)
 dialog.confirmed.connect(apply);dialog.canceled.connect(func()->void:pending.clear();refresh_quote())
 choices.item_selected.connect(func(_index:int)->void:refresh_quote());payment.item_selected.connect(func(_index:int)->void:refresh_quote())
 for row:Dictionary in world.spell_group_conversion.candidates():
  choices.add_item(str(row.name)+(' · 비용 정의 없음' if not row.source_has_costs else ''),int(row.SpellGroupID))
  choices.set_item_tooltip(choices.item_count-1,'원본 구성 %d개 · 대체 정의 %d개 · 효과 Sprite %d' % [row.source_member_count,row.replacement_definitions.size(),row.EffectSpriteID])
 refresh_quote()
func refresh_quote()->void:
 pending.clear()
 if choices.item_count==0:
  message.text=world.spell_group_conversion.problem if not world.spell_group_conversion.problem.is_empty() else '현재 직업에는 원본 계열 전환 설정이 없습니다.';confirm.disabled=true;return
 var plan:Dictionary=world.spell_group_conversion.quote(choices.get_selected_id(),[26,1122,32801][payment.selected])
 confirm.disabled=not plan.get('error','').is_empty()
 message.text=str(plan.error) if confirm.disabled else '%d회 전환 · 재료 ID %d × %d · 아데나 보유 %d' % [plan.count,plan.item,plan.amount,world.gold]
func show_confirmation()->void:
 if choices.item_count==0:return
 pending=world.spell_group_conversion.quote(choices.get_selected_id(),[26,1122,32801][payment.selected])
 if not pending.get('error','').is_empty():message.text=pending.error;return
 dialog.dialog_text='%s → %s\n재료 ID %d × %d를 지불합니다. 저장 성공 시에만 적용합니다.\n기존 학습·퀵슬롯·자동사용 지정은 보존합니다.' % [world.job_class,choices.get_item_text(choices.selected),pending.item,pending.amount]
 dialog.popup_centered(Vector2i(520,230))
func apply()->void:
 if pending.is_empty():return
 var plan:Dictionary=pending;pending={};confirm.disabled=true
 var result:String=world.spell_group_conversion.commit(plan)
 refresh_quote();message.text='계열 전환을 저장했습니다.' if result.is_empty() else result
