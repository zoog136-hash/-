extends RefCounted
class_name TwilightBossDirector

## Boss cooldown deadlines use the device's local wall clock (Unix timestamps).
## Live boss identity and saved HP remain protected across map reloads.
var game_seconds: float = 0.0
var states: Dictionary = {}

func tick(delta: float) -> void:
	game_seconds += maxf(0.0, delta)

func key(map_id: String, region: Dictionary) -> String:
	return map_id + ":" + str(region.get("boss_id", region.id))

func state_for(map_id: String, region: Dictionary) -> Dictionary:
	var id: String = key(map_id, region)
	if not states.has(id):
		states[id] = {"phase":"ready","ready_at":Time.get_unix_time_from_system()+float(region.get("initial_delay",0)),"hp":-1,"position":[],"home":[]}
	var revision: int = int(region.get("layout_revision",0))
	if int(states[id].get("layout_revision",0)) != revision:
		# Preserve the life, HP and cooldown; old canvas positions may name a
		# different room after a geometry migration. Spawn in the checked zone.
		states[id]["position"] = []
		states[id]["home"] = []
		states[id]["layout_revision"] = revision
	return states[id]

func can_spawn(map_id: String, region: Dictionary) -> bool:
	var state: Dictionary = state_for(map_id, region)
	# Alive is a persisted life to restore, not a fresh spawn deadline. Wall-clock
	# rollback must not hide it; runtime population slots prevent duplicates.
	return str(state.phase) == "alive" or Time.get_unix_time_from_system() >= float(state.ready_at)

func capture(map_id: String, region: Dictionary, monster: TwilightMonster) -> void:
	if not is_instance_valid(monster) or monster.dead: return
	var state: Dictionary = state_for(map_id, region)
	state.merge({"phase":"alive","hp":monster.hp,"position":[monster.global_position.x,monster.global_position.y],
		"home":[monster.home_position.x,monster.home_position.y]},true)

func died(map_id: String, region: Dictionary) -> void:
	var state: Dictionary = state_for(map_id, region)
	state.merge({"phase":"cooldown","hp":-1,"position":[],"home":[],
		"ready_at":Time.get_unix_time_from_system()+maxf(1.0,float(region.get("respawn_time",86400)))},true)

func export_state() -> Dictionary:
	return {"version":2,"game_seconds":game_seconds,"bosses":states.duplicate(true)}

func import_state(value: Variant) -> void:
	states.clear()
	game_seconds = 0.0
	if not value is Dictionary: return
	var data: Dictionary = value as Dictionary
	game_seconds = maxf(0.0,float(data.get("game_seconds",0)))
	var version: int = int(data.get("version", 1))
	var raw: Variant = data.get("bosses",{})
	var now: float = Time.get_unix_time_from_system()
	if not raw is Dictionary: return
	for id: Variant in raw:
		if not raw[id] is Dictionary: continue
		var state: Dictionary = raw[id]
		var phase: String = str(state.get("phase","ready"))
		if phase not in ["ready","alive","cooldown"]: phase = "ready"
		var position: Variant = state.get("position",[])
		var home: Variant = state.get("home",[])
		var deadline: float = maxf(0.0, float(state.get("ready_at", 0.0)))
		if version < 2:
			# Old saves stored game-time deadlines. Preserve remaining cooldown at upgrade.
			deadline = now + maxf(0.0, deadline - game_seconds)
		states[str(id)] = {"phase":phase,"ready_at":deadline,
			"layout_revision":int(state.get("layout_revision",0)),
			"hp":maxi(-1,int(state.get("hp",-1))),"position":position if position is Array and position.size()==2 else [],
			"home":home if home is Array and home.size()==2 else []}
