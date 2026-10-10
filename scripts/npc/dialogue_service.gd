extends RefCounted
# Read-only TWILIGHT dialogue rules. Player-state conditions are always checked
# by World again when executing an action, not trusted from the HUD.
const DATA_PATH = "res://data/npc/twilight_dialogues.json"
var registry: Dictionary = {}

func load_dialogues() -> void:
	registry.clear()
	if not FileAccess.file_exists(DATA_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("schema_version",0)) != 1:
		return
	var source: Variant = (parsed as Dictionary).get("dialogues",{})
	if source is Dictionary:
		registry = (source as Dictionary).duplicate(true)

static func matches(requires: Variant, state: Dictionary) -> bool:
	if not (requires is Dictionary):
		return true
	var checks: Dictionary = requires as Dictionary
	if checks.has("level_min") and int(state.get("level",0)) < int(checks["level_min"]):
		return false
	if checks.has("level_max") and int(state.get("level",0)) > int(checks["level_max"]):
		return false
	if checks.has("quest_kills_min") and int(state.get("quest_kills",0)) < int(checks["quest_kills_min"]):
		return false
	if checks.has("quest_kills_max") and int(state.get("quest_kills",0)) > int(checks["quest_kills_max"]):
		return false
	if checks.has("job_class") and str(state.get("job_class","")) != str(checks["job_class"]):
		return false
	if checks.has("item_name"):
		var inv: Variant = state.get("inventory",{})
		if not (inv is Dictionary) or int((inv as Dictionary).get(str(checks["item_name"]),0)) < maxi(1,int(checks.get("item_count_min",1))):
			return false
	return true

func resolve(npc_id: String,node_id: String,state: Dictionary) -> Dictionary:
	var npc_value: Variant = registry.get(npc_id,{})
	if not (npc_value is Dictionary):
		return {"ok":false,"reason":"등록되지 않은 NPC입니다"}
	var npc: Dictionary = npc_value as Dictionary
	var id: String = node_id if not node_id.is_empty() else str(npc.get("entry","welcome"))
	var nodes: Dictionary = npc.get("nodes",{})
	if not nodes.has(id) or not (nodes[id] is Dictionary):
		return {"ok":false,"reason":"등록되지 않은 대화 단계입니다"}
	var node: Dictionary = nodes[id] as Dictionary
	var text: String = str(node.get("text",""))
	for raw: Variant in node.get("variants",[]):
		if raw is Dictionary and matches((raw as Dictionary).get("requires",{}),state):
			text = str((raw as Dictionary).get("text",text))
			break
	var options: Array[Dictionary] = []
	for raw: Variant in node.get("choices",[]):
		if not (raw is Dictionary):
			continue
		var choice: Dictionary = raw as Dictionary
		if not matches(choice.get("requires",{}),state):
			continue
		var next_id: String = str(choice.get("next",""))
		var action: String = str(choice.get("action",""))
		if not next_id.is_empty() and nodes.has(next_id) or action in ["shop","warehouse","craft","buyback","teleport","quest"]:
			options.append({"label":str(choice.get("label","계속")),"next":next_id,"action":action})
	return {"ok":true,"npc_id":npc_id,"npc_name":str(npc.get("name",npc_id)),
		"node_id":id,"text":text,"choices":options}

func allowed_action(npc_id: String,node_id: String,action: String,state: Dictionary) -> bool:
	var resolved: Dictionary = resolve(npc_id,node_id,state)
	if not bool(resolved.get("ok",false)):
		return false
	for option: Dictionary in resolved.get("choices",[]):
		if str(option.get("action","")) == action:
			return true
	return false
