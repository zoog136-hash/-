extends RefCounted
class_name TwilightBossDirector

## All keys include the map ID. Only elapsed game time advances cooldowns;
## wall-clock changes and reloading cannot spawn another live copy.
var game_seconds: float = 0.0
var states: Dictionary = {}

func tick(delta: float) -> void:
	game_seconds += maxf(0.0, delta)

func key(map_id: String, region: Dictionary) -> String:
	return map_id + ":" + str(region.get("boss_id", region.id))

func state_for(map_id: String, region: Dictionary) -> Dictionary:
	var id: String = key(map_id, region)
	if not states.has(id):
		states[id] = {"phase":"ready","ready_at":game_seconds+float(region.get("initial_delay",0)),"hp":-1,"position":[]}
	return states[id]

func can_spawn(map_id: String, region: Dictionary) -> bool:
	var state: Dictionary = state_for(map_id, region)
	return game_seconds >= float(state.ready_at)

func capture(map_id: String, region: Dictionary, monster: TwilightMonster) -> void:
	if not is_instance_valid(monster) or monster.dead: return
	var state: Dictionary = state_for(map_id, region)
	state.merge({"phase":"alive","hp":monster.hp,"position":[monster.global_position.x,monster.global_position.y]},true)

func died(map_id: String, region: Dictionary) -> void:
	var state: Dictionary = state_for(map_id, region)
	state.merge({"phase":"cooldown","hp":-1,"position":[],
		"ready_at":game_seconds+maxf(1.0,float(region.get("respawn_time",900)))},true)

func export_state() -> Dictionary:
	return {"version":1,"game_seconds":game_seconds,"bosses":states.duplicate(true)}

func import_state(value: Variant) -> void:
	states.clear()
	game_seconds = 0.0
	if not value is Dictionary: return
	var data: Dictionary = value as Dictionary
	game_seconds = maxf(0.0,float(data.get("game_seconds",0)))
	var raw: Variant = data.get("bosses",{})
	if not raw is Dictionary: return
	for id: Variant in raw:
		if not raw[id] is Dictionary: continue
		var state: Dictionary = raw[id]
		var phase: String = str(state.get("phase","ready"))
		if phase not in ["ready","alive","cooldown"]: phase = "ready"
		var position: Variant = state.get("position",[])
		states[str(id)] = {"phase":phase,"ready_at":maxf(0.0,float(state.get("ready_at",game_seconds))),
			"hp":maxi(-1,int(state.get("hp",-1))),"position":position if position is Array and position.size()==2 else []}
