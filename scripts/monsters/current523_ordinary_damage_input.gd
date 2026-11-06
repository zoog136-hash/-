extends RefCounted
## Data input for the existing ordinary host attack_power receiver only.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const LOOT=preload("res://scripts/loot_drop.gd")
const POLICY="res://data/monsters/current523_ordinary_damage_input_policy.json"

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func project(catalog: RefCounted,record: Dictionary,source: Dictionary) -> Dictionary:
	# Same already admitted actor, never an actor/spawn or native attack selector.
	var identity: Dictionary=SOURCE.identity()
	if identity.is_empty() or catalog.get("source_available")!=true or catalog.get("source_mode")!="current523_original" or catalog.get("source_identity")!=identity:return record
	var id: Variant=source.get("ID")
	if not _integer(id) or int(id)<=0 or record.get("source_m_npc_id")!=id or record.get("source_m_definition_snapshot")!="patch523" or record.get("source_m_definition_archive_sha256")!=identity.get("source_sha256"):return record
	var declaration: Variant=source.get("Name")
	if not declaration is String or declaration.contains("[테스트]") or declaration.contains("[미사용]"):return record
	if catalog.row("NpcClass",int(id))!=source or SOURCE.row("NpcClass",int(id))!=source or not catalog.definition_eligible(source):return record
	var bound: Variant=record.get("source_m_original")
	if not bound is Dictionary:return record
	for field: String in source:
		if not bound.has(field) or bound[field]!=source[field]:return record
	var admission: Variant=catalog.get("admitted_source_identities").get(str(int(id)))
	if not admission is Dictionary or admission.get("npc_class_id")!=id or admission.get("sprite")!=source.get("Sprite") or admission.get("desc_id")!=source.get("DescId") or admission.get("source_archive_sha256")!=identity.get("source_sha256"):return record
	var ai: Variant=record.get("ai",{})
	var action_contract: Variant=record.get("source_m_host_action_contract",{})
	if not ai is Dictionary or ai.has("special") or not action_contract is Dictionary or not action_contract.is_empty() or LOOT.is_boss_record(record):return record
	var fallback: Variant=record.get("source_m_ordinary_host_atk_default")
	if record.get("source_m_current523_final")!=true or not fallback is Dictionary or fallback!={"kind":"twilight_host_default","producer":"base508_source_roster.record","value":8} or record.get("atk")!=8:return record
	if str(record.get("attack_type",record.get("attackType",record.get("공격타입","melee")))).to_lower()!="melee":return record
	var attacks: Array=catalog.owned("NpcAttack",int(id))
	# The entire admitted set must contain exactly one ordinary, unchained row.
	# No picking the first/max attack or interpreting a native dispatch enum.
	if attacks.size()!=1 or not attacks[0] is Dictionary:return record
	var attack: Dictionary=attacks[0]
	if not _integer(attack.get("ID")) or attack.get("NpcClassID")!=id or attack.get("IsSpell")!=false or attack.get("IsAbsoluteAtk")!=false:return record
	var originals: Array[Dictionary]=SOURCE.related("NpcAttack","ID",int(attack.ID))
	if originals.size()!=1 or originals[0]!=attack or catalog.row("NpcAttack",int(attack.ID))!=attack or not SOURCE.declared_exclusion("NpcAttack",attack).is_empty():return record
	for field: String in ["SpellID","NextAttack","AttackType","WeaponType","ChangeTarget","FixedDelayTime"]:
		if not _integer(attack.get(field)) or int(attack[field])!=0:return record
	# Positive raw Prob is only retained source evidence, never normalized,
	# rolled or used to select/schedule an attack by this projection.
	if attack.get("MotionType")!=2 or not _integer(attack.get("Prob")) or attack.Prob<=0:return record
	for field: String in ["DiceCount","DiceSpots","DiceBonus"]:
		if not _integer(attack.get(field)):return record
	var count: int=int(attack.DiceCount);var spots: int=int(attack.DiceSpots);var bonus: int=int(attack.DiceBonus)
	# Match the existing native damage_spec bounds, but do not call its RNG or
	# put this numeric host estimate back into native dice damage_spec.
	if count<0 or count>1000 or spots<0 or spots>1000000 or bonus<0 or (count>0 and spots<=0) or (count==0 and bonus==0):return record
	var file:=FileAccess.open(POLICY,FileAccess.READ)
	if file==null or file.get_length()>65536:return record
	var bytes: PackedByteArray=file.get_buffer(file.get_length());file.close()
	var parser:=JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:return record
	var policy: Dictionary=parser.data
	if policy.get("schema")!="twilight.current523.ordinary-damage-input-policy.v1" or policy.get("source_sha256")!=identity.get("source_sha256") or policy.get("source_snapshot")!="patch523" or policy.get("enabled")!=true or policy.get("origin")!="twilight_adjustable_numeric_estimate":return record
	if policy.get("projection")!="floor(DiceBonus + DiceCount * (DiceSpots + 1) / 2)" or policy.get("native_damage_formula_recovered")!=false or policy.get("host_formula")!="existing_Monster_attack_power_receiver_retained":return record
	var mean: float=float(bonus)+float(count)*(float(spots)+1.0)/2.0
	# Do not silently rely on Monster.setup's minimum3 clamp for smaller values.
	if not is_finite(mean) or mean<3.0 or mean>1000000000.0:return record
	var digest: String=str(catalog.get("source_model_sha256"))
	if digest.length()!=64 or not digest.is_valid_hex_number(false):return record
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	var result: Dictionary=record.duplicate(true)
	result["atk"]=int(floor(mean))
	result["source_m_ordinary_damage_input"]={"source":identity,"npc_class_id":id,"admission":admission.duplicate(true),"registry_sha256":digest,"source_attack_row":attack.duplicate(true),"source_attack_member":SOURCE.table_metadata("NpcAttack"),"source_fields":{"DiceCount":count,"DiceSpots":spots,"DiceBonus":bonus},"prior_host_atk":record.get("atk",record.get("attack",record.get("공격력",8))),"host_atk_input":result.atk,"policy_path":POLICY,"policy_sha256":hash.finish().hex_encode(),"origin":"twilight_adjustable_numeric_estimate","native_damage_formula_recovered":false,"native_dice_damage_unchanged":true,"host_formula":"existing_Monster_attack_power_receiver_retained"}
	if SOURCE.identity()!=identity or catalog.get("source_identity")!=identity or catalog.get("source_model_sha256")!=digest or catalog.row("NpcClass",int(id))!=source or catalog.owned("NpcAttack",int(id))!=attacks:return record
	return result
