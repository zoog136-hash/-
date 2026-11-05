extends RefCounted
## Cumulative 523 projection. Raw source identities and execution capabilities stay separate.
const DATA = "res://data/growth/guardian_source523.json"
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const RAW_TABLES = ["SkillTreeCategory","SkillTreeSlot","SkillTreeSlotReward","SkillTreeSlotPrerequisite",
	"SkillTreeSlotEnchant","Bonus","BonusType","Unit","UIUnit","SpecialResistanceType","SpellTag",
	"InvokeOption","InvokeOptionType","SpellClass","SpellMaterialType","TargettingType","TargetKind",
	"BuffClass","SpellBonus","BuffBonus","SkillTreeConstant","Currency","IntangibleItemClass",
	"CurrencyUnitClass","UIStaticTextData_Korean","ServerLimit","TrialTowerBanConditionType",
	"LandAttributeType","TrialTowerBanCondition","LandGroupAttribute","ItemClass","DescData_Korean"]
const REWARD_RAW_FIELDS = {"row":"SkillTreeSlotReward","bonus":"Bonus","bonus_type":"BonusType",
	"unit":"Unit","invoke":"InvokeOption","invoke_type":"InvokeOptionType","spell":"SpellClass",
	"description_spell_candidate":"SpellClass"}
var data: Dictionary = {}
var nodes: Dictionary = {}
var _selected_rows: Dictionary = {}

func _init() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not value is Dictionary or value.get("source_version") != 523: return
	data = value
	_index_selected_rows()
	_adopt_original_rows()
	for group: Dictionary in data.guardians:
		for row: Dictionary in group.nodes: nodes[row.id] = row

static func _source_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

func _index_selected_rows() -> void:
	# This indexes only the existing cache's selection, including empty tables.
	_selected_rows.clear()
	for table: String in data.get("source_tables",{}):
		var selected: Dictionary = {}
		for row: Dictionary in data.source_tables[table]:
			if not _source_integer(row.get("ID")): continue
			var id: String = str(int(row.ID))
			if not selected.has(id): selected[id] = []
			selected[id].append(row)
		_selected_rows[table] = selected

func _selected_original(table: String, cached: Dictionary) -> Dictionary:
	if table not in RAW_TABLES or not _source_integer(cached.get("ID")): return cached
	var id: int = int(cached.ID)
	var selected: Array = _selected_rows.get(table,{}).get(str(id),[])
	if selected.size()!=1 or selected[0]!=cached: return cached
	var original: Dictionary = DEFINITIONS.row(table,id)
	if original.is_empty() or not _source_integer(original.get("ID")) or int(original.ID)!=id or original!=cached: return cached
	return original

func _replace_raw(target: Dictionary, field: String, table: String) -> void:
	if target.get(field) is Dictionary: target[field] = _selected_original(table,target[field])

func _adopt_reward(reward: Dictionary) -> void:
	for field: String in REWARD_RAW_FIELDS: _replace_raw(reward,field,REWARD_RAW_FIELDS[field])
	var application: Variant = reward.get("bonus",{}).get("BonusApplicationTypeID")
	if not _source_integer(application): return
	# These two scope tables are the compiler's explicit joins, not inferred
	# target namespaces. The existing scope/value/effect interpretation stays intact.
	if int(application)==2: _replace_raw(reward,"scope","SpecialResistanceType")
	elif int(application)==221: _replace_raw(reward,"scope","SpellTag")

func _adopt_effect(effect: Dictionary, link_table: String) -> void:
	_replace_raw(effect,"link",link_table)
	for pair: Array in [["bonus","Bonus"],["type","BonusType"],["unit","Unit"],["ui_unit","UIUnit"]]:
		_replace_raw(effect,pair[0],pair[1])

func _adopt_original_rows() -> void:
	if DEFINITIONS.identity().is_empty(): return
	for table: String in data.get("source_tables",{}):
		# Description text remains lazy at the existing spell_name consumer.
		# Non-ID text keys are retained by _selected_original without new joins.
		if table=="DescData_Korean": continue
		var selected: Array = data.source_tables[table]
		for index: int in range(selected.size()): selected[index] = _selected_original(table,selected[index])
	for group: Dictionary in data.get("guardians",[]):
		for node: Dictionary in group.get("nodes",[]):
			for reward: Dictionary in node.get("rewards",[]): _adopt_reward(reward)
			var upgrades: Array = node.get("upgrades",[])
			for index: int in range(upgrades.size()): upgrades[index] = _selected_original("SkillTreeSlotEnchant",upgrades[index])
	for spell: Dictionary in data.get("spells",{}).values():
		_replace_raw(spell,"source","SpellClass")
		for effect: Dictionary in spell.get("effects",[]): _adopt_effect(effect,"SpellBonus")
	for buff: Dictionary in data.get("buffs",{}).values():
		_replace_raw(buff,"source","BuffClass")
		for effect: Dictionary in buff.get("effects",[]): _adopt_effect(effect,"BuffBonus")

func has_node(id: String) -> bool:
	return nodes.has(id)

func availability(row: Dictionary) -> String:
	if int(row.get("server_limit_set_id",0)) != 0:
		return "서버별 제공 조건 확인 중 · 개방 보류"
	return ""

func effects(id: String, level: int) -> Dictionary:
	var out: Dictionary = {}
	for reward: Dictionary in nodes.get(id,{}).get("rewards",[]):
		if int(reward.row.Level) != level or reward.status != "applied": continue
		var key: String = str(reward.effect_key)
		out[key] = float(out.get(key,0))+float(reward.effect_value)
	return out

func rewards(id: String, level: int) -> Array:
	var out: Array = []
	for reward: Dictionary in nodes.get(id,{}).get("rewards",[]):
		if int(reward.row.Level) == level:
			_adopt_reward(reward)
			out.append(reward)
	return out

func upgrade(id: String, next_level: int) -> Dictionary:
	for row: Dictionary in nodes.get(id,{}).get("upgrades",[]):
		if int(row.Level) == next_level: return _selected_original("SkillTreeSlotEnchant",row)
	return {}

func detail(id: String, level: int) -> String:
	var parts: Array[String] = []
	for reward: Dictionary in rewards(id,level):
		if reward.status == "applied": continue
		var text: String = str(reward.label)
		if reward.has("invoke"):
			var invoke: Dictionary = reward.invoke
			var kind: int = int(invoke.InvokeOptionTypeID)
			var branch: String = "마법" if invoke.BySpellAttack else "물리"
			text += " · 발동 %.2f%%" % (float(reward.bonus.Value)/10000.0)
			if kind == 2:
				text += " · %s 피격 · 최소 피해 %d" % [branch,int(invoke.Param2)]
			elif kind == 5:
				text += " · 피해 감소 %d" % int(invoke.Param1)
			else:
				text += " · 치명타 공격" if kind == 27 else " · 공격"
				if invoke.Param4: text += " · 주 대상"
			text += " · 발동 스킬"
		elif reward.has("spell"):
			var spell: Dictionary = reward.spell
			text += " · 사용 스킬"
			if int(spell.SpellMaterialTypeID) == 41: text += " · 명예 코인 %d" % int(spell.SpellMaterialItemAmount)
			text += " · 사용 가능"
		else:
			var amount: float=float(reward.get("value",reward.bonus.Value))
			text += " · 조건부 "+("+" if amount>=0 else "")+str(amount)
		parts.append(text)
	return "\n".join(parts)

func constant(name: String) -> float:
	for row: Dictionary in data.source_tables.get("SkillTreeConstant",[]):
		if row.Name==name:return float(_selected_original("SkillTreeConstant",row).Value)
	return 0

func spell_name(id: int) -> String:
	for cached: Dictionary in data.source_tables.get("SpellClass",[]):
		if int(cached.ID)!=id:continue
		var row: Dictionary = _selected_original("SpellClass",cached)
		for cached_text: Dictionary in data.source_tables.get("DescData_Korean",[]):
			if int(cached_text.ID)==int(row.DescID):return str(_selected_original("DescData_Korean",cached_text).Description)
	return "수호성"
