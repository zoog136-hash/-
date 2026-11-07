extends RefCounted
## Read-only consumer of the published expedition issued namespace.
## Crafting owns its one candidate/save; issuance and its ledger stay unchanged.
const IDS=[3732,117544,19342,98454,292302,292312,292322,292332,112762,112772,112782,112792,112912,112932,224062,224072,224082,224092,224142,224152,224162,224172,126434,126444,126454,126464,126474,160222,282863,268922,268932,268942,268952,268962,268972,341314,341324,341334,150293,150303,216053,341344,341354,341364]

static func owned(book: RefCounted,material: Dictionary,inventory: Dictionary,physical: Dictionary,locks: Dictionary,context: Dictionary) -> Dictionary:
	var result: Dictionary={}
	var id: int=int(material.source_id)
	if material.physical or id not in IDS+[137,138]:return result
	var owner: Variant=context.get("expedition_owner")
	if owner==null or owner.get("save_blocked")!=false or not owner.has_method("validate"):return result
	var state: Variant=owner.get("state")
	if not state is Dictionary or state.get("version")!=2 or not owner.call("validate",state).is_empty():return result
	var host: Variant=owner.get("world")
	if host==null or not host.has_method("get_expedition_catalog"):return result
	var catalog: RefCounted=host.get_expedition_catalog()
	if catalog==null or not catalog.ready():return result
	var original: Dictionary=book.item_entry(str(id)).get("item_class",{})
	if original.is_empty() or original.get("TestItem")!=false or catalog.record("ItemClass",id)!=original:return result
	var tuple: String="%d:%d:%d" % [id,int(material.bless_code),int(material.level)]
	var key: String=str(original.get("Name",""))+" (탐험 "+tuple+")"
	if state.get("issued",{}).get(tuple)!=key or locks.get(key,false) or locks.get(str(material.item),false):return result
	var amount: Variant=inventory.get(key,0)
	if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or float(amount)!=float(int(amount)) or int(amount)<1 or int(amount)>1000000000:return result
	var record: Dictionary=host._find_catalog_item_record(key)
	if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or record.get("sourceId")!="m523:expedition:"+tuple or record.get("source_item_class_id")!=id or record.get("source_item")!=original or record.get("expedition_key")!=tuple or record.get("name")!=key or record.get("source_m_native_item",false):return result
	# The issued producer omits blessing metadata: the complete tuple is proof.
	if record.has("source_bless_raw") and record.source_bless_raw!=int(material.bless_code):return result
	if record.get("IsStorable")!=original.IsStorable or record.get("tradeable")!=original.IsTradable or record.get("bound")!=(not original.IsTradable) or record.get("droppable")!=original.IsDroppable:return result
	for value: Variant in physical.values():
		if value is Dictionary and value.get("name")==key:return result
	result[key]={"amount":int(amount),"record":record,"tuple":tuple}
	return result

static func scroll(book: RefCounted,key: String,inventory: Dictionary,physical: Dictionary,locks: Dictionary,context: Dictionary) -> Dictionary:
	var owner: Variant=context.get("expedition_owner")
	if owner==null:return {}
	var host: Variant=owner.get("world")
	if host==null:return {}
	var record: Dictionary=host._find_catalog_item_record(key)
	var tuple: String=str(record.get("expedition_key",""))
	var fields: PackedStringArray=tuple.split(":")
	if fields.size()!=3 or fields[0] not in ["137","138"]:return {}
	var rejected: Dictionary={"issued":true,"ok":false,"error":"탐험 주문서의 원본 소지·축복·발급 장부를 확인하세요 · 보존"}
	for part: String in fields:
		if not part.is_valid_int() or str(int(part))!=part:return rejected
	if int(fields[1]) not in [1,2,3] or int(fields[2])!=0:return rejected
	var material: Dictionary={"item":book.record(fields[0]).get("name",""),"source_id":fields[0],"physical":false,"bless_code":int(fields[1]),"level":0}
	if not owned(book,material,inventory,physical,locks,context).has(key):return rejected
	return {"issued":true,"ok":true,"source_id":fields[0],"bless_code":int(fields[1]),"key":key,"tuple":tuple}
