extends SceneTree
## Draft pure test for main918c8e84's outgoing material owner contract.
const Core=preload("res://scripts/cards/skill_awakening_service.gd")
const Growth=preload("res://scripts/cards/skill_awakening_growth.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var errors: Array[String]=[]
var checks: int=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:
	var core:=Core.new();var identity: String=""
	for key: String in core.cards:
		var row: Dictionary=core.cards[key]
		if row.category=="마법인형" and int(row.source_card.GradeID)==3 and not bool(row.source_card.IsNoMergeOut) and core.eligibility(key).ok:identity=key;break
	check(not identity.is_empty(),"real source fixture exists")
	if identity.is_empty():finish();return
	var category: String=str(core.cards[identity].category)
	var state: Dictionary=Core.fresh_state()
	state.cards[identity]={"spell_id":int(core.candidates(identity)[0].spell_id),"level":1,"experience":"0","opaque":{"preserve":true}}
	var receipt: Dictionary={"origin":"quest_current523","category":category,"identity":identity,"source_sha256":"d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832","item_pack_sha256":"38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27","quest_use_token":"b".repeat(64),"quest_option_feed_hold":1,"quest_option_feed_policy":"TWILIGHT_host_hold_until_option_owner_verified","opaque":{"preserve":[1,"future"]}}
	var cards: Dictionary={"version":1,"owned":{category:{identity:true}},"spare":{category:{identity:2}},"pity":{},"source_card_receipts":[receipt],"future":{"preserve":true}}
	var before: int=hash([state,cards])
	var view: Dictionary=Growth.view(core,state,cards.owned,identity,cards.spare,1000000,cards)
	check(view.can_feed and view.materials.size()==1 and view.materials[0].quantity==1 and view.materials[0].owned_quantity==2 and view.materials[0].reserved_quantity==1,"view lists available copies only")
	var feed: Dictionary=Growth.prepare_feed(core,state,cards,1000000,identity,identity,0)
	check(feed.ok and feed.card_state.spare[category][identity]==1 and Cards.outgoing_material_spare(feed.card_state,category,identity)==0,"one free spare is consumed while reserved spare stays")
	check(feed.card_state.source_card_receipts==cards.source_card_receipts and feed.card_state.future==cards.future and hash([state,cards])==before,"pure feed preserves receipts and opaque metadata")
	var rejected: Dictionary=Growth.prepare_feed(core,feed.state,feed.card_state,feed.gold,identity,identity,1)
	check(not rejected.ok and rejected.code=="material_reserved","reserved final copy is rejected")
	var held_view: Dictionary=Growth.view(core,feed.state,feed.card_state.owned,identity,feed.card_state.spare,feed.gold,feed.card_state)
	check(not held_view.can_feed and held_view.materials.is_empty(),"reserved-only copies do not appear in UI materials")
	var malformed: Dictionary=cards.duplicate(true);malformed.source_card_receipts={"unrecognized":"preserve"}
	check(not Growth.prepare_feed(core,state,malformed,1000000,identity,identity,0).ok,"malformed receipt ledger fails closed")
	var duplicates: Dictionary=cards.duplicate(true);duplicates.source_card_receipts.append(receipt.duplicate(true))
	check(Cards.quest_reserved_spare(duplicates,category,identity)==1 and Growth.prepare_feed(core,state,duplicates,1000000,identity,identity,0).ok,"owner's token deduplication is reused exactly")
	var legacy: Dictionary=cards.duplicate(true);legacy.erase("source_card_receipts")
	check(Growth.prepare_feed(core,state,legacy,1000000,identity,identity,0).ok,"legacy saves without receipts retain ordinary spare use")
	finish()
func finish() -> void:
	print("SKILL_GROWTH_RESERVED ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
