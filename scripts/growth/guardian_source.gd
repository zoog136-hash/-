extends RefCounted
## Cumulative 523 projection. Raw source identities and execution capabilities stay separate.
const DATA = "res://data/growth/guardian_source523.json"
var data: Dictionary = {}
var nodes: Dictionary = {}

func _init() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not value is Dictionary or value.get("source_version") != 523: return
	data = value
	for group: Dictionary in data.guardians:
		for row: Dictionary in group.nodes: nodes[row.id] = row

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
		if int(reward.row.Level) == level: out.append(reward)
	return out

func upgrade(id: String, next_level: int) -> Dictionary:
	for row: Dictionary in nodes.get(id,{}).get("upgrades",[]):
		if int(row.Level) == next_level: return row
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
		if row.Name==name:return float(row.Value)
	return 0

func spell_name(id: int) -> String:
	for row: Dictionary in data.source_tables.get("SpellClass",[]):
		if int(row.ID)!=id:continue
		for text: Dictionary in data.source_tables.get("DescData_Korean",[]):
			if int(text.ID)==int(row.DescID):return str(text.Description)
	return "수호성"
