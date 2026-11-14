extends RefCounted
## Consumer namespace binding only; the published owner retains every trade.
## Re-reviewed 2026-11-14 at blob b6d088e: since 650b69b (11-05) only
## persisted_last_seen()/play_use_visual() and template-field changes were
## added; records_for(), binding_cache and binding_catalog_size are unchanged.
const REVIEWED_OWNER_BLOB="b6d088e49c2a1c965f8d4eb3b41e931de7bb04c0"
const IDS=[200723,245718,297828,328254,346911,371108,75764,123373]
static var views: Dictionary={}

static func select(records: Array,inventory: Dictionary,item_id: int,original: Dictionary,book: RefCounted) -> Dictionary:
	var owned: Array=[]
	for record: Dictionary in records:
		if int(inventory.get(str(record.get("name","")),0))>0:owned.append(record)
	# Multiple owned identities stay ambiguous. Never combine or silently move.
	if not owned.is_empty():return {"ok":true,"records":owned}
	var canonical: Array=[]
	var invalid_native: bool=false
	for record: Dictionary in records:
		if record.get("sourceId")!="m523:item:"+str(item_id) or record.get("source")=="protection523":continue
		if record.get("source")=="lineagem_patch523" and record.get("source_snapshot")=="patch523" and record.get("source_m_native_item")==true and record.get("source_bless_raw")==1 and record.get("source_item_class_id")==item_id and book.data.get("items",{}).get(str(item_id),{}).get("item_class",{})==original and book.catalog_identity_matches(record,str(item_id)):canonical.append(record)
		else:invalid_native=true
	if invalid_native:return {"ok":false,"error":"가호 원본 카탈로그 정체 불일치 · 기존 소유 보존"}
	return {"ok":true,"records":canonical if not canonical.is_empty() else records}

## The owner's reviewed contract is pinned by its git blob where the source
## text exists (editor, tests, CI). Exported apps ship compiled scripts with no
## source text (get_source_code() is empty); hashing that empty text made every
## phone report a contract mismatch and closed 가호 crafting (2026-11-14 phone
## error record: hashing_context "len == 0" from this function).
static func owner_source_mismatch(script: Script) -> bool:
	if script==null:return true
	var source: String=script.get_source_code()
	if source.is_empty():return false
	var bytes: PackedByteArray=source.to_utf8_buffer()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA1)
	var header: PackedByteArray=("blob "+str(bytes.size())).to_utf8_buffer();header.append(0)
	hash.update(header);hash.update(bytes)
	return hash.finish().hex_encode()!=REVIEWED_OWNER_BLOB

static func prepare(world: Node) -> Dictionary:
	var owner: RefCounted=world.protection523
	if owner==null:return {"ok":false,"error":"가호 제작 소유자 미설치"}
	var input_error: String=preload("res://scripts/crafting/patch523_owner_transactions.gd").protected_inputs_error(world)
	if not input_error.is_empty():return {"ok":false,"error":input_error}
	if owner_source_mismatch(owner.get_script()):return {"ok":false,"error":"가호 소유자 공개 계약 버전 확인 필요 · 재료 보존"}
	var size: int=world.catalog_db.get("아이템",[]).size()
	var key: int=owner.get_instance_id()
	if not views.has(key) or owner.binding_catalog_size!=size:
		owner.binding_catalog_size=-1
		owner.records_for(IDS[0])
		var raw: Dictionary={}
		for id: int in IDS:raw[id]=owner.binding_cache.get(id,[]).duplicate()
		views[key]={"raw":raw,"owner":weakref(owner)}
	for id: int in IDS:
		var result: Dictionary=select(views[key].raw[id],world.inventory,id,owner.source.get("items",{}).get(str(id),{}),world.patch523_equipment)
		if not result.ok:return result
		owner.binding_cache[id]=result.records
	# Retain the owner's source validation, pending-receipt reader and cache
	# invalidation contract. No inventory, output, fee, title or ledger writes.
	owner.binding_catalog_size=size
	return {"ok":true}
