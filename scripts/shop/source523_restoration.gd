extends RefCounted
## Reuse the real potion consumer; failed durable writes restore quantity/HP/RNG.
const DATA = preload("res://data/shop/source523_restoration.json")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ITEM_IDS = [233,237,236]
const EFFECT_NAMES = ["HPRestoration","HPRestorationDiceNumber","HPRestorationDiceSpotCount","ItemConsumeDelay","ItemConsumeEffectSpriteID","AutoUseRegistrable"]
static var source_problem: String = ""
static var source_state: String = "not_loaded"
static var source_input_identity: Dictionary = {}
static var source_provenance: Dictionary = {}

static func _source_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _hold_source(reason: String) -> Dictionary:
	source_problem = reason
	source_state = "held"
	return {}

static func _source_items() -> Dictionary:
	# UNVERIFIED input port of tools/shop/build_source523_restoration.py::build.
	# DATA retains the existing host origin/dice policy, never fallback values.
	var identity: Dictionary = SOURCE.identity()
	if identity.get("source_sha256") != SOURCE.SOURCE_SHA:
		return _hold_source("회복제 현재523 원문 입력이 없습니다. "+SOURCE.problem())
	var result: Dictionary = {}
	var provenance: Dictionary = {"projection":"tools/shop/build_source523_restoration.py::build","source_definition_archive":identity.duplicate(true),"selected_inputs":{}}
	for id: int in ITEM_IDS:
		var item: Dictionary = SOURCE.row("ItemClass",id)
		if item.is_empty(): return _hold_source("회복제 원문 ItemClass가 없습니다: "+str(id)+" · "+SOURCE.problem())
		if typeof(item.get("TestItem")) != TYPE_BOOL or bool(item.TestItem):
			return _hold_source("회복제 원문의 명시적 TestItem=false가 확인되지 않았습니다: "+str(id))
		var exclusion: Dictionary = SOURCE.declared_exclusion("ItemClass",item)
		if not exclusion.is_empty(): return _hold_source("원문 제외 선언이 있는 회복제 입력입니다: "+str(id))
		var values: Dictionary = {}
		var references: Array[Dictionary] = []
		for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",id):
			if not SOURCE.declared_exclusion("ItemBonus",link).is_empty(): return _hold_source("원문 제외 선언이 있는 회복제 효과 연결입니다: "+str(id))
			if typeof(link.get("IsPossession")) != TYPE_BOOL or bool(link.IsPossession) or not _source_integer(link.get("BonusID")):
				return _hold_source("회복제 비소지 효과의 원문 조건이 확인되지 않았습니다: "+str(id))
			var bonus: Dictionary = SOURCE.row("Bonus",int(link.BonusID))
			if bonus.is_empty() or not _source_integer(bonus.get("BonusTypeID")) or not _source_integer(bonus.get("BonusApplicationTypeID")) or not _source_integer(bonus.get("BonusApplicationTargetID")):
				return _hold_source("회복제 원문 Bonus 연결이 불완전합니다: "+str(id))
			if not SOURCE.declared_exclusion("Bonus",bonus).is_empty(): return _hold_source("원문 제외 선언이 있는 회복제 보너스입니다: "+str(id))
			if int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0:
				return _hold_source("조건부 회복제 효과는 기존 입력 계약에 없습니다: "+str(id))
			var type: Dictionary = SOURCE.row("BonusType",int(bonus.BonusTypeID))
			if not type.get("Name") is String or str(type.Name) not in EFFECT_NAMES:
				return _hold_source("기존 허용셋에 없는 회복제 원문 효과입니다: "+str(id))
			if not SOURCE.declared_exclusion("BonusType",type).is_empty(): return _hold_source("원문 제외 선언이 있는 회복제 효과 종류입니다: "+str(id))
			var name: String = str(type.Name)
			if values.has(name): return _hold_source("중복된 회복제 원문 효과입니다: "+str(id)+" · "+name)
			values[name] = bonus.get("Value")
			references.append({"item_bonus":link,"bonus":bonus,"bonus_type":type})
		if values.get("ItemConsumeDelay") != 1000:
			return _hold_source("회복제 원문 재사용 대기가 기존 1000ms 입력 계약과 다릅니다: "+str(id))
		for field: String in ["HPRestoration","HPRestorationDiceNumber","HPRestorationDiceSpotCount"]:
			if not _source_integer(values.get(field)): return _hold_source("회복제 원문 수치가 없거나 정수가 아닙니다: "+str(id)+" · "+field)
		if not _source_integer(item.get("DescID")): return _hold_source("회복제 원문 표시명 참조가 없습니다: "+str(id))
		var label: Dictionary = SOURCE.row("DescData_Korean",int(item.DescID))
		if not label.get("Description") is String or str(label.Description).is_empty():
			return _hold_source("회복제의 선택된 원문 표시명을 읽을 수 없습니다: "+str(id))
		result[str(id)] = {"name":label.Description,"base":values.HPRestoration,"dice_count":values.HPRestorationDiceNumber,"dice_sides":values.HPRestorationDiceSpotCount}
		provenance.selected_inputs[str(id)] = {"item_class":item,"description_id":item.DescID,"effects":references}
	source_input_identity = identity.duplicate(true)
	source_provenance = provenance
	source_problem = ""
	source_state = "ready"
	return result

static func install(world, catalog) -> Dictionary:
	var result: Dictionary={}
	var changed: bool=false
	var specs: Dictionary=_source_items()
	for id: String in specs:
		var spec: Dictionary=specs[id]
		var original: Dictionary=catalog.record("ItemClass",int(id))
		if original.is_empty() or original.get("TestItem",true) or catalog.label(int(original.get("DescID",0)))!=spec.name:continue
		var name: String=str(spec.name)
		var record: Dictionary=world._find_catalog_item_record(name)
		var fresh: bool=record.is_empty()
		if not record.is_empty() and (record.get("source")!="twilight-shop523-restoration" or int(record.get("source_item_class_id",0))!=int(id) or record.get("source_bless_raw")!=1):continue
		if record.is_empty():
			record={"name":name,"grade":"일반","type":"회복물약","slot":"consumable","heal":int(spec.base),"source":"twilight-shop523-restoration","source_item_class_id":int(id),"source523_shop_item_id":int(id),"source_bless_raw":1,"source523_shop_use_origin":str(DATA.data.origin),"weight":3,"desc":"기본 회복 %d + %dd%d · %s" % [int(spec.base),int(spec.dice_count),int(spec.dice_sides),str(DATA.data.origin)]}
		record.merge({"source_weight_raw":original.get("Weight",0),"source_max_stack":int(original.get("MaxStackAmount",0)),"droppable":original.get("IsDroppable",false),"storable":original.get("IsStorable",false),"source_is_tradable":original.get("IsTradable",false)},true)
		if fresh:
			world.item_db.append(record.duplicate(true));world.catalog_db["아이템"].append(record);changed=true
		result["4:"+id]={"name":name,"record":record.duplicate(true)}
	if changed:world._index_item_weights()
	return result

static func try_use(world, name: String) -> bool:
	var record: Dictionary=world._find_catalog_item_record(name)
	if record.get("source")!="twilight-shop523-restoration":return false
	var spec: Dictionary=_source_items().get(str(int(record.get("source_item_class_id",0))),{})
	if spec.is_empty() or spec.name!=name or record.get("source_bless_raw")!=1 or DATA.data.dice_policy!="base_plus_uniform_dice":
		world.hud.show_message("회복제 원본 정체/적용 정책 확인 실패 · 보존");return true
	var before: int=int(world.inventory.get(name,0))
	if before<=0 or int(world.hp)<=0 or int(world.hp)>=int(world._effective_max_hp()) or float(world.item_use_cooldowns.get(world.HP_POTION_COOLDOWN_KEY,0.0))>0.0:
		world.hud.show_message("회복제 보유량·HP·공유 재사용 대기를 확인하세요");return true
	var old_hp: int=int(world.hp)
	var old_rng: int=world.rng.state
	var old_cooldowns: Dictionary=world.item_use_cooldowns.duplicate(true)
	var amount: int=int(spec.base)
	for die: int in range(int(spec.dice_count)):amount+=world.rng.randi_range(1,int(spec.dice_sides))
	world._use_healing_item(name,amount)
	if int(world.inventory.get(name,0))==before:return true
	if world._save_game(true)!=OK:
		world.hp=old_hp;world.inventory[name]=before;world.item_use_cooldowns=old_cooldowns;world.rng.state=old_rng
		world._update_hud();world.hud.show_message("회복 저장 실패 · HP·물약·난수 보존")
	return true
