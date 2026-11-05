extends RefCounted
## Exact held ownership input for the PR247 return consumer. No movement,
## inventory grant, stack rename, debit adoption or save occurs here.
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const IDENTITY=preload("res://scripts/quickslots/regional_return.gd")

static func prepare(world: Node, physical_id: String) -> Dictionary:
	var prepared: Dictionary=OWN.prepare_debit(world,physical_id,1)
	if not prepared.ok:return prepared
	var owned: Dictionary=prepared.ownership
	if int(owned.item_class_id)!=239 or int(owned.bless_code_id)!=1:return OWN.denied("정확한 원본239 Normal 보상 개체가 필요합니다")
	if D.pack_identity().get("sha256")!=D.DATA_SHA:return OWN.denied("검증된 원본 아이템 소비 팩 미설치")
	var definition: Dictionary=D.definition_id("239")
	if definition.get("original_item",{})!=owned.source_item:return OWN.denied("독립 원본 행과 귀환 아이템 정의 불일치")
	var record: Dictionary=D.variant_item(definition.get("native_record",{}),1)
	# Validate the canonical DEFINITION; ownership remains the actual raw
	# receipt-selected physical record, never this canonical inventory key.
	var identity: Dictionary=IDENTITY.stack_identity(str(record.get("name","")),record)
	if identity.get("origin")!="patch523_native_normal" or int(identity.get("item_class_id",0))!=239:return OWN.denied("원본239 정의의 Normal 정체 불일치")
	var problem: String=USE.eligibility(world,record)
	if not problem.is_empty():return OWN.denied(problem)
	var receipt: Dictionary=OWN.use_state(world,prepared,D.DATA_SHA)
	if not receipt.ok:return receipt
	var overrides: Dictionary=prepared.override.duplicate(true)
	overrides["quest_state"]=receipt.state
	return {"ok":true,"kind":"quest523.return239.input.v1","physical_id":physical_id,"inventory_key":str(owned.inventory_key),"record":record.duplicate(true),"prepared":prepared,"override":overrides}

static func current(world: Node, input: Dictionary) -> bool:
	if input.get("kind")!="quest523.return239.input.v1" or not OWN.current(world,input.get("prepared",{})):return false
	var fresh: Dictionary=prepare(world,str(input.get("physical_id","")))
	return fresh.get("ok",false) and fresh.override==input.get("override") and fresh.record==input.get("record") and fresh.inventory_key==input.get("inventory_key")
