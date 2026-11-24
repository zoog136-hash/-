extends RefCounted
## Original merge-failure compensation is a zero-payment claim, not the
## ordinary shop mileage balance and not an automatic same-grade draw.
const Source=preload("res://scripts/resources/current523_definition_rows.gd")
const Server=preload("res://scripts/loot/current523_server_profile.gd")
const Identity=preload("res://scripts/cards/current523_card_identity.gd")
const DECKS={"변신":1,"마법인형":2,"성물":98}
const DECK_NAMES={1:"PolymorphCardDeck",2:"MagicDollCardDeck",98:"HolyStuffCardDeck"}
const GRADES={"희귀":3,"영웅":4,"전설":5}
const RESULT_GRADES={3:4,4:5,5:32}
const RESULT_NAMES={3:"영웅",4:"전설",5:"신화"}
const MATERIALS={3:4,4:4,5:2}
const LIMIT=20
const WEIGHT=1000000
## deck/grade -> original purchase ID, product ID, pool ID, entry count and
## zero-payment identity. The actual draw weights/identities are read from
## the installed source archive, never reconstructed from card rarity.
const LANES={
	1:{3:[57972,75192,222,24,66652],4:[57982,75202,232,30,66652],5:[64561,85371,651,1,66652]},
	2:{3:[58002,75222,252,10,66652],4:[58012,75232,262,16,66652],5:[64571,85381,661,1,66652]},
	98:{3:[86308,118738,1698,10,94778],4:[86318,118748,1708,13,94778],5:[86298,118728,1718,1,94768]},
}
const SCROLLS={146442:[1,3],146452:[1,4],146462:[2,3],146472:[2,4],172251:[1,5],172261:[2,5],267911:[98,3],267921:[98,4]}
const NO_REWARD_LANE=[180082,180092]
const ITEM_UNITS={"MergeFailPointAmount":"Value","SpecificBuffDeckID":"BuffDeckID","GradeID":"GradeID"}
static var _source_lanes:Dictionary={}
static var _source_thresholds:Dictionary={}
static var _source_epoch:int=-1

static func profile(record:Dictionary,definition:Dictionary)->Dictionary:
	var id:int=int(record.get("source_item_class_id",0))
	if not SCROLLS.has(id) or record.get("source_m_native_item")!=true or record.get("source_definition_archive")!=Source.identity():return {}
	var raw:Dictionary=definition.get("original_item",{})
	if raw.get("ID")!=id or raw.get("CategoryID")!=10362 or raw.get("TestItem")!=false or raw.get("TargettingTypeID")!=1 or raw.get("CanUseWhenInvisible")!=true or raw.get("ServiceRegionCode")!="":return {}
	for field:String in ["LevelLimitMin","LevelLimitMax","MaxLevelLimitMin","MaxLevelLimitMax"]:
		if raw.get(field)!=0:return {}
	var category:Dictionary=Source.row("ItemCategory",10362)
	if category.get("Name")!="MergeFailPointRecharger" or category.get("IsConsumable")!=true or category.get("IsStackable")!=true:return {}
	var exact:Array=SCROLLS[id]
	var expected:Dictionary={"MergeFailPointAmount":1,"SpecificBuffDeckID":exact[0],"GradeID":exact[1]}
	var bonus_rows:Array=definition.get("item_bonus",[])
	if bonus_rows.size()!=expected.size():return {}
	for row:Dictionary in bonus_rows:
		var key:String=str(row.get("bonus_type",{}).get("Name",""))
		var value:Dictionary=row.get("bonus",{})
		if not expected.has(key) or row.get("IsPossession")!=false or row.get("unit",{}).get("Name")!=ITEM_UNITS[key] or value.get("Value")!=expected[key] or value.get("BonusApplicationTypeID")!=0 or value.get("BonusApplicationTargetID")!=0:return {}
		expected.erase(key)
	return {"kind":"source_fusion_point","category":DECKS.find_key(exact[0]),"grade":GRADES.find_key(exact[1]),"amount":1,"can_use_when_invisible":true}

static func result(ok:bool=false,message:String="")->Dictionary:
	return {"ok":ok,"message":message}

static func _source_open()->bool:
	if Source.identity().get("source_sha256")!=Source.SOURCE_SHA:return false
	var generation:int=Source.cache_generation()
	if generation!=_source_epoch:
		_source_epoch=generation;_source_lanes.clear();_source_thresholds.clear()
	return true

## The 21-row original rule table is sufficient to show the gauge. Neither
## the market tables nor the draw pools are opened by a read-only UI refresh.
static func supported_threshold(category:String,grade:String)->bool:
	if not DECKS.has(category) or not GRADES.has(grade) or not _source_open():return false
	var key:String=category+":"+grade
	if _source_thresholds.has(key):return _source_thresholds[key]
	var deck:int=DECKS[category];var rank:int=GRADES[grade];var expected:Array=LANES[deck][rank]
	var count:int=0;var exact:bool=false
	for row:Dictionary in Source.rows("BuffCardRuleMergeView"):
		if row.get("BuffCardDeckID")!=deck or row.get("GradeID")!=rank:continue
		count+=1
		exact=row.get("RewardFailPoint")==LIMIT and row.get("OnFailReward")==true and row.get("ServerLimitSetID")==0 and row.get("SuccessGradeID")==RESULT_GRADES[rank] and row.get("SourceAmount")==MATERIALS[rank] and row.get("FailRewardPurchaseID")==expected[0]
	if count==1 and exact:_source_thresholds[key]=true;return true
	return false

static func source_lane(category:String,grade:String)->Dictionary:
	if not supported_threshold(category,grade):return {}
	var key:String=category+":"+grade
	if _source_lanes.has(key):return _source_lanes[key]
	var projected:Dictionary=_read_lane(int(DECKS[category]),int(GRADES[grade]))
	if not projected.is_empty():_source_lanes[key]=projected
	return projected

static func _read_lane(deck:int,grade:int)->Dictionary:
	var exact:Array=LANES[deck][grade]
	var deck_row:Dictionary=Source.row("BuffCardDeck",deck)
	if deck_row.get("Name")!=DECK_NAMES[deck] or deck_row.get("CharacterBased")!=false:return {}
	var offer:Dictionary=Source.row("MarketPurchase_Korean",exact[0])
	if offer.get("MarketPaymentID")!=exact[4] or offer.get("EffectiveFromId")!=1 or offer.get("EffectiveToId")!=3 or offer.get("OnSale")!=true:return {}
	var from:Dictionary=Source.row("DateTimes_Korean",1)
	var until:Dictionary=Source.row("DateTimes_Korean",3)
	var date_columns:Array[String]=["Year","Month","Day","Hour","Minute"]
	var from_fields:Array[int]=[2016,1,1,0,0];var end_fields:Array[int]=[2099,12,31,23,59]
	for i:int in range(date_columns.size()):
		var field:String=date_columns[i]
		if from.get(field)!=from_fields[i] or until.get(field)!=end_fields[i]:return {}
	var pay:Dictionary=Source.row("MarketPayment_Korean",exact[4])
	if not str(pay.get("UniqueKey","")).begins_with("BuffCardMergeReward_NoPayment") or pay.get("MarketPaymentTypeID")!=0 or pay.get("UnitID")!=4 or pay.get("ClassID")!=0 or pay.get("Amount")!=0 or pay.get("ClassChangeDiscount")!=false:return {}
	if not Source.related("MarketPurchaseServerLimitGroup","MarketPurchaseID",exact[0]).is_empty() or not Source.related("MarketBonusForPurchase","MarketPurchaseID",exact[0]).is_empty():return {}
	var links:Array[Dictionary]=Source.related("MarketPurchaseProduct","MarketPurchaseID",exact[0])
	if links.size()!=1 or links[0].get("MarketProductID")!=exact[1]:return {}
	var product:Dictionary=Source.row("MarketProduct",exact[1])
	if product.get("UnitID")!=35 or Source.row("Unit",35).get("Name")!="GotChaClassID" or Source.row("Unit",33).get("Name")!="BuffCardID" or product.get("ClassID")!=exact[2] or product.get("Amount")!=1 or product.get("ClassChangeDiscount")!=false:return {}
	var entries:Array[Dictionary]=Source.related("GotChaEntityView","GotChaClassID",exact[2])
	if entries.size()!=int(exact[3]):return {}
	var total:int=0;var seen:Dictionary={};var choices:Array[Dictionary]=[]
	for entry:Dictionary in entries:
		var id:int=int(entry.get("ClassID",0));var weight:Variant=entry.get("Probability")
		if id<=0 or seen.has(id) or entry.get("UnitID")!=33 or entry.get("BuffCardID")!=id or entry.get("Grade")!=RESULT_GRADES[grade] or not _whole(weight) or weight<=0 or weight>WEIGHT:return {}
		var card:Dictionary=Source.row("BuffCard",id)
		if card.get("BuffCardDeckID")!=deck or card.get("GradeID")!=RESULT_GRADES[grade] or card.get("StartDateTimeID")!=0 or card.get("EndDateTimeID")!=0:return {}
		seen[id]=true;total+=int(weight)
		choices.append({"source_id":id,"chance":int(weight),"server":int(card.get("ServerLimitSetID",-1)),"no_merge":card.get("IsNoMergeOut"),"no_swap":card.get("IsNoSwapOut")})
	if total!=WEIGHT:return {}
	return {"deck":deck,"grade":grade,"result_grade":RESULT_GRADES[grade],"result_name":RESULT_NAMES[grade],"offer":exact[0],"pool":exact[2],"choices":choices}

static func _whole(value:Variant)->bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

## Prove every original nonzero candidate before making a roll. If a player
## uses a nonmatching server context or lacks any candidate, keep the exact
## weights and ownership unchanged rather than redistributing missing rows.
static func reward(world:Node,category:String,grade:String)->Dictionary:
	var lane:Dictionary=source_lane(category,grade)
	if lane.is_empty():return {}
	var records:Dictionary={}
	for card:Dictionary in world.catalog_db.get(category,[]):
		var id:int=int(card.get("source_card_id",0))
		if id>0:
			if records.has(id):return {}
			records[id]=card
	var draw:Array[Dictionary]=[]
	var checked_sets:Dictionary={}
	for choice:Dictionary in lane.choices:
		var id:int=choice.source_id
		var record:Dictionary=records.get(id,{})
		var stable:String=Identity.source_id(lane.deck,id)
		if record.get("sourceId")!=stable or record.get("source") not in ["lineagem_base508","lineagem_patch523"] or record.get("source_deck_id")!=lane.deck or record.get("source_grade_id")!=lane.result_grade or record.get("grade")!=lane.result_name or record.get("source_merge_out_disabled",false)!=choice.no_merge or record.get("source_swap_out_disabled",false)!=choice.no_swap:return {}
		if world.card_draw_fusion.known_ids.get(category,{}).get("source:"+stable)!=lane.result_name:return {}
		var server:int=choice.server
		if not checked_sets.has(server):checked_sets[server]=bool(Server.allows(world,server).get("ok",false))
		if not checked_sets[server]:return {}
		draw.append({"record":record,"source_id":id,"chance":choice.chance})
	return {"ok":true,"lane":lane,"draw":draw}

static func choose(draw:Array,roll:int)->Dictionary:
	if roll<0 or roll>=WEIGHT:return {}
	var end:int=0
	for entry:Dictionary in draw:
		end+=int(entry.chance)
		if roll<end:return entry
	return {}
