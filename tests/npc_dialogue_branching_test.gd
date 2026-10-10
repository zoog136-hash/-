extends SceneTree

const DIALOGUE = preload("res://scripts/npc/dialogue_service.gd")
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		printerr("NPC_DIALOGUE_FAIL: " + message)

func _run() -> void:
	var service = DIALOGUE.new()
	service.load_dialogues()
	_check(service.registry.size() == 6,"all six Aden NPC role dialogues are registered")
	var base: Dictionary = {"level":1,"job_class":"기사","quest_kills":0,"inventory":{}}
	var welcome: Dictionary = service.resolve("warden","",base)
	_check(bool(welcome.get("ok")),"guide NPC dialogue resolves")
	_check(str(welcome.get("text","")).contains("황혼의 길"),"default guide message")
	var choices: Array = welcome.get("choices",[])
	_check(choices.size() == 3,"level/item gated guide options are hidden at early level")
	_check(service.resolve("warden","",{"level":1,"job_class":"요정","quest_kills":0,"inventory":{}}).get("text","").contains("요정"),"job class changes dialogue text")
	_check(service.resolve("warden","",{"level":45,"job_class":"기사","quest_kills":0,"inventory":{}}).get("text","").contains("숙련된"),"level changes dialogue text")
	_check(service.resolve("warden","",{"level":1,"job_class":"기사","quest_kills":0,"inventory":{"수정 단검":1}}).get("text","").contains("수정 단검"),"owned item changes dialogue text")
	_check(service.resolve("warden","",{"level":1,"job_class":"기사","quest_kills":9,"inventory":{}}).get("text","").contains("공로"),"quest progress changes dialogue text")
	var advanced: Dictionary = {"level":45,"job_class":"요정","quest_kills":0,"inventory":{"수정 단검":1}}
	_check((service.resolve("warden","welcome",advanced).get("choices",[]) as Array).size() == 5,"advanced options unlock with valid player state")
	_check(not service.allowed_action("warden","welcome","buyback",advanced),"forged service action must be rejected")
	_check(service.allowed_action("warden","welcome","shop",advanced),"explicit whitelisted shop dialogue action remains allowed")
	_check(not bool(service.resolve("warden","not_real",advanced).get("ok")),"fabricated dialogue node rejected")
	_check(not bool(service.resolve("unknown_npc","",advanced).get("ok")),"unknown NPC rejected")
	_check(service.allowed_action("warden","quest","quest",base),"quest-window option resolves")
	var field_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	_check(field_value is Dictionary,"live Aden field JSON parses")
	if field_value is Dictionary:
		var known: Dictionary = {}
		for raw: Variant in (field_value as Dictionary).get("npc_spawn",[]):
			if raw is Dictionary:
				known[str((raw as Dictionary).get("id",""))] = true
		for npc_id: String in service.registry:
			_check(known.has(npc_id),"dialogue NPC has a real positioned Aden field character: "+npc_id)
	if errors.is_empty():
		print("NPC_DIALOGUE_OK: live six NPCs, conditional quest/level/class/item branches and action checks")
		quit(0)
	else:
		print("NPC_DIALOGUE_FAILED: %d issues" % errors.size())
		quit(1)
