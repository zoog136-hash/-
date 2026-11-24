extends RefCounted
## Bag stacking of receipted original 523 stacks (user request 2026-11-17:
## "아이템들 겹칠 수 있는 건 좀 겹치게 해").
##
## Every grant/pickup of an original non-equipment item gets its own physical
## ID and receipt (current523_native_stack.stage_grant), and the bag drew one
## slot per physical ID: 15 slots of "[재료] 할파스의 집념" x1. Here stacks of
## the same original ItemClass row, bless state (bless_raw), enchant level 0
## and identical record merge into one physical stack up to the original
## ItemClass.MaxStackAmount. Equipment never merges (user 2026-11-17: each
## piece has its own physical ID and per-instance state); different item IDs
## never merge.
##
## Nothing is lost: the merged stack carries a schema 3 receipt whose
## components name each absorbed physical ID and quantity, and the merge
## journal (consumable_state.source_native_stack_merges) keeps every absorbed
## stack's exact receipt, used, transferred and remaining quantity. Absorbed
## stacks' use-ledger rows move into that journal; partition history keeps
## resolving through it. Locked stacks merge only with locked stacks.
## The survivor keeps its physical ID (locks, ammo
## selection follow it) unless every member has partition history.
## TWILIGHT 근사: an original row whose MaxStackAmount is not a positive
## integer (none in the 523 tables) stacks up to 9999.
const RETIRED_ITEMS = preload("res://scripts/loot/retired_enhancement_items523.gd")
const QUANTITY="source_native_stack_quantity"
const RECEIPT="source_native_stack_receipt"
const USED="source_native_stack_used_quantity"
const TRANSFERRED="source_native_stack_transferred_quantity"
const USES="source_native_stack_uses"
const PARTITIONS="source_native_stack_partitions"
const AMMO_EQUIPPED="source_native_ammo_equipped"
const MERGES="source_native_stack_merges"
const KIND="owned_quantity_merge"
const APPROX_MAX_STACK: int=9999
const MAX_INT: int=9007199254740991

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0.0 and float(value)<=9007199254740991.0

static func _hex32(value: Variant) -> bool:
	return value is String and (value as String).length()==32 and (value as String).is_valid_hex_number(false)

static func _new_id(taken: Callable) -> String:
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while taken.call(id):id=Crypto.new().generate_random_bytes(16).hex_encode()
	return id

## Original MaxStackAmount of the receipt's own ItemClass row.
static func max_stack(receipt: Dictionary) -> int:
	var original: Variant=preload("res://scripts/loot/current523_native_fields.gd").field_view(receipt,"source_original_item",{})
	var value: Variant=original.get("MaxStackAmount") if original is Dictionary else null
	if _int(value) and int(value)>=1:return int(value)
	return APPROX_MAX_STACK

## Structural part of a schema 3 receipt (no state needed).
static func receipt_shape_valid(receipt: Dictionary) -> bool:
	var origin: Variant=receipt.get("origin")
	if not origin is Dictionary or origin.get("kind")!=KIND or not _hex32(origin.get("merge_id")):return false
	var components: Variant=origin.get("components")
	if not components is Array or components.is_empty():return false
	var total: int=0;var seen: Dictionary={}
	for component: Variant in components:
		if not component is Dictionary or component.size()!=2 or not component.get("physical_id") is String or str(component.physical_id).is_empty() or seen.has(component.physical_id) or not _int(component.get("quantity")) or int(component.quantity)<1:return false
		seen[component.physical_id]=true
		if total>MAX_INT-int(component.quantity):return false
		total+=int(component.quantity)
	return _int(receipt.get("granted_quantity")) and total==int(receipt.granted_quantity)

## Only non-equipment stack kinds merge (재료·소모품·코인).
const STACK_SLOTS: Array[String]=["consumable","material","currency"]
static func equipment(record: Dictionary) -> bool:
	return preload("res://scripts/loot/patch523_monster_drops.gd").equipment(record)

static func _other_fields(entry: Dictionary) -> Dictionary:
	var result: Dictionary=entry.duplicate()
	for key: String in [QUANTITY,RECEIPT,USED,TRANSFERRED]:result.erase(key)
	return result

## Per-acquisition provenance carried on the stored item record: which
## monster/drop row or reward granted this stack. It is not item state (each
## absorbed stack's receipt keeps its own origin and proof in the merge
## journal), so two stacks of one item from different monsters, the shop, a
## quest or the warehouse still stack (user 2026-11-19: 공성 포인트·가죽 from
## different monsters sat in separate slots).
const PROVENANCE: Array[String]=["source_m_drop_proof","source_m_reward_proof"]

## What must be equal for two stacks of one item/bless to share a slot: every
## stored field except quantity/receipt bookkeeping and record provenance. The
## record is compared in its full form (a saved compact record and a freshly
## granted full one are the same item).
static func stack_identity(entry: Dictionary) -> Dictionary:
	var result: Dictionary=_other_fields(entry)
	var value: Variant=result.get("record")
	if value is Dictionary:
		var record: Dictionary=(preload("res://scripts/loot/current523_native_fields.gd").full(value) as Dictionary).duplicate()
		for key: String in PROVENANCE:record.erase(key)
		# Identity labels a drop record repeats (the plan's group key already
		# has the ItemClass ID and bless): the drop's own item ID and its bless
		# label, dropped only while they agree with the record's identity.
		if record.has("source_m_item_id") and _int(record.source_m_item_id) and int(record.source_m_item_id)==int(record.get("source_item_class_id",-1)):record.erase("source_m_item_id")
		if record.get("bless_state")==BLESS_LABELS.get(int(record.get("source_bless_raw",0)),null):record.erase("bless_state")
		result["record"]=record
	return _canonical(result)

## A stack restored from the save holds JSON numbers (1.0) where a fresh grant
## holds integers (1); Dictionary equality is type-strict, so a loaded stack
## and a new pickup of one item never matched until the next reload.
static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary={}
		for key: Variant in value:out[key]=_canonical(value[key])
		return out
	if value is Array:
		var items: Array=[]
		for item: Variant in value:items.append(_canonical(item))
		return items
	if value is float and is_finite(value) and value==floorf(value) and absf(value)<=9007199254740991.0:return int(value)
	return value

const BLESS_LABELS: Dictionary={1:"normal",2:"blessed",3:"cursed"}

## A same-name peer is necessary (not sufficient) for any merge. Inspect
## only the shell here, before opening the original definition/cache or
## validating a receipt. Use exactly the planner's name and level semantics.
static func possible_names(instances: Dictionary) -> Dictionary:
	var seen: Dictionary={}
	var repeated: Dictionary={}
	for uid: Variant in instances:
		var entry: Variant=instances[uid]
		if not entry is Dictionary or not entry.has(RECEIPT) or entry.get("level")!=0:continue
		var name_value: String=str(entry.get("name",""))
		if seen.has(name_value):repeated[name_value]=true
		else:seen[name_value]=true
	return repeated

## Plans the bag merge. Pure: returns new copies, never edits its inputs.
## {changed, item_instances, consumable_state, item_locks, merged_slots}
## The world supplies a synchronous read-only snapshot callback. It is invoked
## only for real bins, returns {state,reserved}, and must not mutate the bag.
static func plan(instances: Dictionary,state: Dictionary,locks: Dictionary,reserved: Dictionary={}, repeated_names: Variant=null, owner_snapshot: Callable=Callable()) -> Dictionary:
	var unchanged: Dictionary={"changed":false,"merged_slots":0}
	var candidates: Dictionary=possible_names(instances) if repeated_names==null else repeated_names
	if candidates.is_empty():return unchanged
	var stock: Script=load("res://scripts/loot/current523_native_stack.gd")
	# Same item, bless, enchant 0 and identical other fields, in bag order.
	var groups: Dictionary={};var order: Array[String]=[]
	for raw: Variant in instances:
		var uid: String=str(raw);var entry: Variant=instances[raw]
		if not entry is Dictionary or not entry.has(RECEIPT) or entry.get("level")!=0:continue
		var name_value: String=str(entry.get("name",""))
		if not candidates.has(name_value):continue
		if entry.get("record") is Dictionary and RETIRED_ITEMS.record(entry.record):continue
		var owned: Dictionary=stock.call("proof_entry",entry,uid)
		if owned.is_empty():continue
		var cap: int=max_stack(owned.receipt)
		if cap<=1:continue
		# User 2026-11-17: equipment never merges, whatever its MaxStackAmount;
		# each piece keeps its own enchant/bless/element/option/lifetime/lock.
		if equipment(owned.record) or str(owned.record.get("slot","")) not in STACK_SLOTS:continue
		var locked: bool=bool(locks.get(name_value+"@@@"+uid,false))
		var key: String="%s|%d|%d|%d" % [name_value,int(owned.receipt.item_class_id),int(owned.receipt.bless_raw),int(locked)]
		if not groups.has(key):groups[key]=[];order.append(key)
		groups[key].append({"uid":uid,"owned":owned,"entry":entry,"cap":cap})
	var bins: Array=[]
	for key: String in order:
		var members: Array=groups[key]
		if members.size()<2:continue
		var kinds: Array=[]
		for member: Dictionary in members:
			member["other"] = stack_identity(member.entry)
			var placed: bool=false
			for kind: Array in kinds:
				if kind[0].other==member.other:kind.append(member);placed=true;break
			if not placed:kinds.append([member])
		for kind: Array in kinds:
			if kind.size()<2:continue
			var cap: int=kind[0].cap;var current: Array=[];var total: int=0
			for member: Dictionary in kind:
				var amount: int=int(member.owned.remaining)
				if not current.is_empty() and total+amount>cap:
					if current.size()>1:bins.append(current)
					current=[];total=0
				current.append(member);total+=amount
			if current.size()>1:bins.append(current)
	if bins.is_empty():return unchanged
	if owner_snapshot.is_valid():
		var snapshot: Variant=owner_snapshot.call()
		if not snapshot is Dictionary or not snapshot.get("state") is Dictionary or not snapshot.get("reserved") is Dictionary:return unchanged
		state=snapshot.state;reserved=snapshot.reserved
	var ledger: Variant=state.get(USES,{});var partitions: Variant=state.get(PARTITIONS,{});var merges: Variant=state.get(MERGES,{})
	if not ledger is Dictionary or not partitions is Dictionary or not merges is Dictionary:return unchanged
	var involved: Dictionary={}
	for event: Variant in partitions.values():
		if event is Dictionary:involved[str(event.get("parent_id",""))]=true;involved[str(event.get("child_id",""))]=true
	var ammo: Variant=state.get(AMMO_EQUIPPED,{})
	var next_instances: Dictionary=instances.duplicate(true)
	var next_state: Dictionary=state.duplicate(true)
	var next_ledger: Dictionary=next_state.get(USES,{});var next_merges: Dictionary=next_state.get(MERGES,{})
	var next_locks: Dictionary=locks.duplicate(true)
	var replaced: Dictionary={} # absorbed uid -> true; fresh survivor anchor uid -> new uid
	var anchors: Dictionary={}
	var merged_slots: int=0
	var taken: Callable=func(id: String) -> bool:return next_instances.has(id) or next_ledger.has(id) or next_merges.has(id) or involved.has(id) or reserved.has(id)
	for members: Array in bins:
		var survivor: Dictionary={}
		for member: Dictionary in members:
			if not involved.has(member.uid):survivor=member;break
		var survivor_id: String=str(survivor.get("uid",""))
		if survivor_id.is_empty():survivor_id=_new_id(taken)
		var extend: bool=false
		if not survivor.is_empty() and survivor.owned.receipt.get("schema")==3:
			var event: Variant=next_merges.get(str(survivor.owned.receipt.origin.merge_id))
			extend=event is Dictionary and event.get("into")==survivor_id
		var absorbed: Array=[]
		for member: Dictionary in members:
			if not (extend and member.uid==survivor_id):absorbed.append(member)
		var components: Array=[];var receipt_parts: Array=[];var added: int=0
		for member: Dictionary in absorbed:
			var owned: Dictionary=member.owned
			components.append({"physical_id":member.uid,"receipt":owned.receipt.duplicate(true),"used_quantity":int(owned.used),"transferred_quantity":int(owned.transferred),"remaining_quantity":int(owned.remaining)})
			receipt_parts.append({"physical_id":member.uid,"quantity":int(owned.remaining)})
			added+=int(owned.remaining)
		var entry: Dictionary;var receipt: Dictionary;var used: int=0;var transferred: int=0
		if extend:
			entry=survivor.entry.duplicate(true);receipt=survivor.owned.receipt.duplicate(true)
			var merge_id: String=str(receipt.origin.merge_id)
			receipt.granted_quantity=int(receipt.granted_quantity)+added
			receipt.origin.components=receipt.origin.components+receipt_parts
			next_merges[merge_id].components=next_merges[merge_id].components+components
			used=int(survivor.owned.used);transferred=int(survivor.owned.transferred)
			entry[QUANTITY]=int(survivor.owned.remaining)+added
		else:
			var base: Dictionary=(survivor if not survivor.is_empty() else members[0])
			entry=base.entry.duplicate(true);receipt=base.owned.receipt.duplicate(true)
			var merge_id: String=_new_id(func(id: String) -> bool:return next_merges.has(id))
			receipt.schema=3;receipt.issued_physical_id=survivor_id;receipt.granted_quantity=added
			receipt.origin={"kind":KIND,"merge_id":merge_id,"components":receipt_parts}
			next_merges[merge_id]={"schema":1,"into":survivor_id,"item_class_id":int(receipt.item_class_id),"bless_raw":int(receipt.bless_raw),"components":components}
			entry[QUANTITY]=added;entry.erase(TRANSFERRED)
		entry[RECEIPT]=receipt;entry[USED]=used
		if transferred>0:entry[TRANSFERRED]=transferred
		var name_value: String=str(entry.get("name",""))
		var locked: bool=false
		for member: Dictionary in members:
			if locks.get(name_value+"@@@"+str(member.uid),false):locked=true
			if member.uid!=survivor_id:
				replaced[member.uid]=true;next_ledger.erase(member.uid);next_locks.erase(name_value+"@@@"+str(member.uid))
		if not extend:next_ledger.erase(survivor_id)
		if used+transferred>0:next_ledger[survivor_id]=stock.call("ledger_row",{"receipt":receipt,"transferred":transferred},used,int(entry[QUANTITY]))
		if locked:next_locks[name_value+"@@@"+survivor_id]=true
		if survivor.is_empty():anchors[str(members[0].uid)]=survivor_id
		next_instances[survivor_id]=entry
		if ammo is Dictionary and not ammo.has("ownership_kind") and ammo.get("name")==name_value:
			for member: Dictionary in members:
				if ammo.get("physical_id")==member.uid:
					next_state[AMMO_EQUIPPED]={"physical_id":survivor_id,"name":name_value,"receipt":receipt.duplicate(true)}
		merged_slots+=members.size()-1
	# Keep acquisition order: the survivor stays where it was (a fresh ID takes
	# its first member's place); absorbed stacks leave the bag.
	var ordered: Dictionary={}
	for raw: Variant in instances:
		var uid: String=str(raw)
		if anchors.has(uid):ordered[anchors[uid]]=next_instances[anchors[uid]]
		if replaced.has(uid):continue
		ordered[uid]=next_instances[uid]
	next_state[USES]=next_ledger;next_state[MERGES]=next_merges
	return {"changed":true,"item_instances":ordered,"consumable_state":next_state,"item_locks":next_locks,"merged_slots":merged_slots}

## Every schema 3 receipt must match its merge journal entry exactly, every
## journal entry must be the history of a live/ledgered/absorbed receipt, and
## an absorbed physical ID may not be owned or ledgered again.
static func merges_error(all: Dictionary,ledger: Dictionary,merges: Variant,partitions: Variant) -> String:
	if not merges is Dictionary:return "원본 묶음 병합 장부 형식 확인 필요"
	if merges.is_empty():return ""
	var stock: Script=load("res://scripts/loot/current523_native_stack.gd")
	var absorbed: Dictionary={}
	var receipts: Array=[] # [uid, schema 3 receipt]
	for id: Variant in merges:
		var event: Variant=merges[id]
		if not _hex32(id) or not event is Dictionary or event.get("schema")!=1 or not event.get("into") is String or str(event.into).is_empty() or not _int(event.get("item_class_id")) or not _int(event.get("bless_raw")) or not event.get("components") is Array or event.components.is_empty():return "원본 묶음 병합 기록 정체 확인 필요"
		for component: Variant in event.components:
			if not component is Dictionary or not component.get("physical_id") is String or not component.get("receipt") is Dictionary:return "원본 묶음 병합 구성 형식 확인 필요"
			for key: String in ["used_quantity","transferred_quantity","remaining_quantity"]:
				if not _int(component.get(key)):return "원본 묶음 병합 구성 수량 형식 확인 필요"
			var receipt: Dictionary=component.receipt
			if not stock.call("receipt_valid",receipt,str(component.physical_id)) or int(receipt.item_class_id)!=int(event.item_class_id) or int(receipt.bless_raw)!=int(event.bless_raw):return "원본 묶음 병합 구성 영수증 확인 필요"
			if int(component.remaining_quantity)<1 or int(component.remaining_quantity)!=int(receipt.granted_quantity)-int(component.used_quantity)-int(component.transferred_quantity):return "원본 묶음 병합 구성 최초량·사용량·잔량 불일치"
			if receipt.get("schema")==3:receipts.append([str(component.physical_id),receipt])
			if component.physical_id!=event.into:
				if absorbed.has(component.physical_id) or all.has(component.physical_id) or ledger.has(component.physical_id):return "병합된 원본 개체의 중복 소유·장부 보존 중지"
				absorbed[component.physical_id]=true
	for uid: String in all:
		var entry: Variant=all[uid]
		if entry is Dictionary and entry.get(RECEIPT) is Dictionary and entry[RECEIPT].get("schema")==3:receipts.append([uid,entry[RECEIPT]])
	for uid: String in ledger:
		var row: Variant=ledger[uid]
		if row is Dictionary and row.get("receipt") is Dictionary and row.receipt.get("schema")==3:receipts.append([uid,row.receipt])
	if partitions is Dictionary:
		for event: Variant in partitions.values():
			if event is Dictionary and event.get("parent_receipt") is Dictionary and event.parent_receipt.get("schema")==3:receipts.append([str(event.get("parent_id","")),event.parent_receipt])
	var matched: Dictionary={}
	for pair: Array in receipts:
		var receipt: Dictionary=pair[1]
		var merge_id: String=str(receipt.origin.merge_id)
		var event: Variant=merges.get(merge_id)
		if not event is Dictionary or event.into!=pair[0] or event.into!=receipt.issued_physical_id or event.components.size()!=receipt.origin.components.size():return "원본 묶음 병합 영수증과 병합 장부 불일치"
		for index: int in range(event.components.size()):
			var part: Dictionary=receipt.origin.components[index];var component: Dictionary=event.components[index]
			if part.physical_id!=component.physical_id or int(part.quantity)!=int(component.remaining_quantity):return "원본 묶음 병합 구성 개체·수량 불일치"
		matched[merge_id]=true
	for id: Variant in merges:
		if not matched.has(id):return "근거 없는 원본 묶음 병합 기록"
	return ""

## partition_error resolves absorbed partition parents/children through the
## journal: adds absorbed receipts/transferred amounts it cannot find in the
## bag, warehouse, floor or ledger.
static func add_absorbed(receipts: Dictionary,transferred: Dictionary,merges: Variant) -> void:
	if not merges is Dictionary:return
	for event: Variant in merges.values():
		if not event is Dictionary or not event.get("components") is Array:continue
		for component: Variant in event.components:
			if not component is Dictionary or component.get("physical_id")==event.get("into"):continue
			var uid: String=str(component.get("physical_id",""))
			if receipts.has(uid):continue
			receipts[uid]=component.get("receipt",{});transferred[uid]=int(component.get("transferred_quantity",0))
