extends RefCounted
const QUEST_ONLY = preload("res://scripts/quests/retired_quest_items523.gd")
## TWILIGHT gameplay decision, not a source dummy marker or save migration.
## The earlier enhancement retirement remains a separate exact list.
const IDS := {133134:true,133144:true,133154:true,133324:true,151863:true,151873:true,153904:true,153914:true,153924:true,153934:true,163603:true,163613:true,163623:true,163633:true,244282:true,351964:true,358932:true}
## User decision on the 124-ID audit: 38 additional exact IDs, not their
## categories or any same-name variant. No ownership record is rewritten.
const AUDIT_IDS := {
	161762:true,161772:true,161782:true,161792:true,165123:true,171134:true,171554:true,171564:true,
	171741:true,180083:true,180093:true,180103:true,180113:true,180232:true,180242:true,180252:true,180262:true,180453:true,
	183553:true,183563:true,183573:true,183583:true,184723:true,189504:true,202223:true,202233:true,202243:true,202253:true,
	202263:true,202273:true,205231:true,224743:true,224753:true,224763:true,237128:true,293142:true,293152:true,338684:true,
}
## Later exact instruction: exclude all 39 quest-teleport scrolls shown in
## the destination audit. This is not a ScrollTeleport category rule.
const AUDIT_SCROLL_IDS := {
	138531:true,138541:true,138551:true,138561:true,138571:true,138591:true,138601:true,138611:true,138621:true,138631:true,141203:true,
	155701:true,155711:true,155721:true,155731:true,155741:true,155761:true,155771:true,155781:true,155791:true,155801:true,
	188454:true,188464:true,188484:true,188514:true,188524:true,188534:true,188544:true,188554:true,189944:true,189964:true,189994:true,
	221921:true,221931:true,221951:true,221961:true,222811:true,222821:true,222831:true,
}
const REASON := "제외한 원본 아이템입니다 · 기존 소유 기록은 보존합니다"

static func item(id: Variant) -> bool:
	return audited_item(id) or QUEST_ONLY.item(id)

static func audited_item(id: Variant) -> bool:
	if id is int:return IDS.has(id) or AUDIT_IDS.has(id) or AUDIT_SCROLL_IDS.has(id)
	if id is float and id >= 133134 and id <= 358932 and id == floorf(id):return audited_item(int(id))
	return false

static func record(row: Dictionary) -> bool:
	if QUEST_ONLY.matches_reference(row,str(row.get("name",""))):return true
	if row.has("source_item_class_id"):return item(row.source_item_class_id)
	if row.get("source")=="twilight_dungeon_adaptation":return item(row.get("declared_source_item"))
	var key: Variant=row.get("sourceId")
	if not key is String or not key.begins_with("m523:item:"):return false
	var tokens: PackedStringArray=key.split(":")
	if tokens.size()!=3 and (tokens.size()!=5 or tokens[3]!="bless" or tokens[4] not in ["1","2","3"]):return false
	return tokens[2].is_valid_int() and tokens[2]==str(int(tokens[2])) and item(int(tokens[2]))

static func retired_reference(value: String) -> bool:
	# Some older holdings have no surviving catalog/physical DTO. Only an
	# explicit canonical item number in the held key identifies them; never
	# deny an unqualified display name or a same-name variant.
	var key: String=value.get_slice("@@@",0).trim_suffix(" · 축복").trim_suffix(" · 저주")
	var marker: int=key.rfind(" · 원본#")
	if marker<0:return false
	var id: String=key.substr(marker+6)
	return id.is_valid_int() and id==str(int(id)) and audited_item(int(id))

## Return the same array unless a row must actually disappear; preserve order
## and duplicates. Never edit the source document or an inventory collection.
static func catalog(rows: Array) -> Array:
	var result: Array=[]
	var changed:=false
	for i: int in rows.size():
		var row: Variant=rows[i]
		if row is Dictionary and record(row):
			if not changed:result=rows.slice(0,i);changed=true
		elif changed:result.append(row)
	return result if changed else rows
