extends RefCounted
## Explicit TWILIGHT adaptation. No M523 map, server or season is impersonated.
const CLOCK := "twilight-local-kst05-v1"
const DAILY = preload("res://scripts/quests/quest_service.gd")

static func install_definition(world: Node) -> void:
	if not world._find_catalog_item_record("TWILIGHT 도전 목표물").is_empty(): return
	world.item_db.append({"name":"TWILIGHT 도전 목표물","type":"재료","slot":"material","grade":"일반","weight":0,"stackable":true,"droppable":false,"sellable":false,"source":"twilight_local_dungeon"})

static func settings(state: Dictionary) -> Dictionary:
	return state.get("local_settings",{"enabled":true,"time_scale":1})

static func cycle(state: Dictionary, now: int) -> int:
	return maxi(int(state.get("local_day",0)),DAILY.korean_daily_key(now))

static func context(world: Node, stage_id: int) -> Dictionary:
	var state: Dictionary = world.source_dungeon_runs.state
	if not settings(state).enabled or not is_instance_valid(world.field_map) or not is_instance_valid(world.player): return {}
	var stage: Dictionary = world.source_dungeons.stage("tower",stage_id)
	if stage.is_empty(): return {}
	var run: Dictionary = state.active
	var now := int(Time.get_unix_time_from_system())
	var in_run: bool = not run.is_empty() and run.get("host_kind","") == "twilight_local" and run.status == "active"
	var open: bool = not world.local_dungeon_failure_pending and (not in_run or now < int(run.local_deadline))
	return {"host_kind":"twilight_local","source_sha256":world.DUNGEON_RUNS.SOURCE_SHA,"stage_id":stage_id,"hard":bool(stage.stage.IsHard),"land_id":int(stage.place.land.ID),"map_id":world.active_map_id,"stage_access":open,"cycle":int(run.cycle) if in_run else cycle(state,now),"clock_contract":CLOCK,"combat_open":open,"completion_allowed":open,"completion_reward_ids":world.DUNGEON_RUNS._reward_ids(stage.normal_rewards),"immediate_reward_ids":world.DUNGEON_RUNS._reward_ids(stage.immediate_rewards),"local_deadline":now+int(stage.stage.TimeLimit)*int(settings(state).time_scale)}

static func kill(world: Node, monster: Node, run: Dictionary) -> void:
	if run.map_id != world.active_map_id or run.status != "active": return
	if context(world,int(run.stage_id)).get("combat_open",false) != true: return
	var stage: Dictionary = world.source_dungeons.stage("tower",int(run.stage_id))
	if stage.type == "BreakThrough" and not monster.is_boss: return
	for goal: Dictionary in stage.goals:
		if goal.type == "ItemCollect":
			# Own adaptation: one tagged objective drop per ordinary monster life.
			# It must pass the actual floor pickup path and is never Item327824.
			var record := {"name":"TWILIGHT 도전 목표물","type":"재료","slot":"material","grade":"일반","weight":0,"stackable":true,"droppable":false,"sellable":false,"source":"twilight_local_dungeon","dungeon_run_id":str(run.id),"declared_goal_id":int(goal.row.GoalClassID)}
			world.ground_loot.spawn(record.name,monster.global_position,1,"",{"item_record":record})
			return
	world._queue_dungeon_event("kill",world.local_dungeon_session_id+":"+str(monster.get_instance_id())+":"+str(monster.life_id),0)

static func tick(world: Node) -> void:
	var run: Dictionary = world.source_dungeon_runs.state.active
	if run.is_empty() or run.get("host_kind","") != "twilight_local" or run.status != "active": return
	if world.local_dungeon_failure_pending or int(Time.get_unix_time_from_system()) >= int(run.local_deadline) or str(run.map_id) != world.active_map_id:
		world.local_dungeon_failure_pending = true
		var result: Dictionary = world.source_dungeon_runs.fail_run()
		if result.get("ok",false):
			world.local_dungeon_failure_pending = false
			world.hud.show_message("현재 지역 도전 종료 · 입장 비용 미환급")
		else: world.hud.show_message(str(result.get("reason","도전 종료 저장 실패")))
