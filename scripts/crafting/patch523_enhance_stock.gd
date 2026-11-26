extends RefCounted
## Use only a validated original scroll receipt for the exact identity the
## enhancement rule was quoted for. Do not convert an entire owned stack into
## a plain stack merely for opening the chooser.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const ITEM_USE = preload("res://scripts/loot/patch523_item_use.gd")
const ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")

static func select_owned(world: Node, name: String, selected: String, count: int, require_receipt: bool=false) -> Dictionary:
	var ids: Array = world.item_instances.keys()
	ids.sort()
	var has_receipts: bool = false
	var refused: String = ""
	for uid: String in ids:
		var entry: Variant = world.item_instances[uid]
		if not entry is Dictionary or entry.get("name") != name or not entry.has(STACK.RECEIPT): continue
		has_receipts = true
		if not selected.is_empty() and uid != selected: continue
		if world._item_locked(name,uid):
			refused="선택한 원본 강화 주문서의 잠금을 해제하세요"
			continue
		var proof: Dictionary=STACK.proof(world,uid)
		if proof.is_empty():return {"native":true,"reason":"원본 강화 주문서의 물리 소유를 확인할 수 없습니다"}
		var reason: String=ITEM_USE.eligibility(world,proof.record)
		if not reason.is_empty():refused=reason;continue
		if ENHANCE.item_id(proof.record).is_empty():return {"native":true,"reason":"원본 강화 주문서의 ItemClass를 확인할 수 없습니다"}
		if int(proof.remaining)<count:
			refused="선택한 원본 강화 주문서 묶음의 수량이 부족합니다"
			continue
		return {"native":true,"ok":true,"uid":uid,"proof":proof}
	if has_receipts or require_receipt:
		return {"native":true,"reason":refused if not refused.is_empty() else "가방에서 사용할 원본 강화 주문서 묶음을 다시 선택하세요"}
	return {}

static func stage(world: Node, owned: Dictionary, quantity: int) -> Dictionary:
	if STACK.busy:return {"ok":false,"reason":"원본 아이템 저장 처리 중 · 주문서 보존"}
	var proof: Dictionary=owned.proof
	if quantity<=0 or int(proof.remaining)<quantity:return {"ok":false,"reason":"선택한 원본 강화 주문서 묶음의 수량이 부족합니다"}
	var request: Dictionary={"physical_id":owned.uid,"quantity":quantity,"expected_quantity":proof.remaining,
		"expected_remaining":int(proof.remaining)-quantity,"source_native_stack_receipt":proof.receipt}
	return STACK.stage_debit(world,[request])
