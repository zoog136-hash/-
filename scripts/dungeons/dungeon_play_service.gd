extends RefCounted
## Explicit optional TWILIGHT gameplay, using source declarations and current fields.
signal changed
const ECONOMY = preload("res://scripts/dungeons/dungeon_economy.gd")
const CLOCK = preload("res://scripts/quests/quest_service.gd")
var world: Node
var rules: RefCounted
var state: Dictionary = empty_state()
var save_blocked := false
var problem := ""
var pending: Dictionary = {}
var actors: Dictionary = {}
var template: Dictionary = {}
var tick_clock := 0.0
var placement_blocked := false

static func defaults() -> Dictionary:
	return {"enabled":false,"entry_currency":174,"entry_cost":10,"attempts":1,"duration":420,"live_limit":16,"group_size":1,"care":"timeout","replacement":true,"preserve_items":true,"carry_bonus":true,"zero_cap":86400,"ungrouped_time":3600,"speed_percent":25,"pearl_percent":10,"token_chance":10,"reroll_currency":4,"reroll_percent":10,"specific_daily":true,"holy_ain":900,"heal_percent":20,"boss_hp_multiplier":1,"hard_multiplier":1,"group_time_scale":1,"recharger_price":100000}

static func empty_state() -> Dictionary:
	return {"schema":1,"revision":0,"settings":defaults(),"next":1,"day":0,"active":{},"pools":{},"attempts":{},"receipts":{}}

func configure(owner: Node, source: RefCounted) -> void:
	world=owner;rules=source

func valid(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != 1: return "던전 실행 저장 버전 오류"
	for key: String in ["next","day"]:
		if not world.DUNGEON_RUNS.whole(value.get(key),1 if key=="next" else 0): return "던전 실행 번호 오류"
	if not world.DUNGEON_RUNS.whole(value.get("revision",0)):return "던전 저장 번호 오류"
	for key: String in ["settings","active","pools","attempts","receipts"]:
		if not value.get(key) is Dictionary or value[key].size()>10000:return "던전 실행 장부 오류"
	var cfg: Dictionary=value.settings
	for key: String in ["enabled","replacement","preserve_items","carry_bonus","specific_daily"]:
		if not cfg.get(key) is bool:return "던전 자체 설정 오류"
	for range_row: Array in [["entry_cost",0,100000000],["attempts",1,10],["duration",10,3600],["live_limit",1,32],["group_size",1,10],["zero_cap",0,604800],["ungrouped_time",1,604800],["speed_percent",0,100],["pearl_percent",0,100],["token_chance",0,100]]:
		if not world.DUNGEON_RUNS.whole(cfg.get(range_row[0]),int(range_row[1]),int(range_row[2])):return "던전 자체 수치 오류"
	if not world.DUNGEON_RUNS.whole(cfg.get("entry_currency"),1,174) or int(cfg.entry_currency) not in [1,4,174] or cfg.get("care") not in ["timeout","always","off"]:return "던전 자체 규칙 오류"
	if not world.DUNGEON_RUNS.whole(cfg.get("reroll_currency"),1,174) or int(cfg.reroll_currency) not in [1,4,174] or not world.DUNGEON_RUNS.whole(cfg.get("reroll_percent"),0,100):return "재선택 자체 설정 오류"
	if not world.DUNGEON_RUNS.whole(cfg.get("holy_ain"),0,999999) or not world.DUNGEON_RUNS.whole(cfg.get("heal_percent"),0,100):return "자체 회복 수치 오류"
	for key: String in ["boss_hp_multiplier","hard_multiplier","group_time_scale"]:
		if not world.DUNGEON_RUNS.whole(cfg.get(key),1,100):return "자체 배율 오류"
	if not world.DUNGEON_RUNS.whole(cfg.get("recharger_price"),0,100000000):return "자체 충전석 가격 오류"
	for key: Variant in value.pools:
		var p: Variant=value.pools[key]
		if not key is String or not p is Dictionary:return "던전 시간 풀 오류"
		for field: String in ["period","base","bonus"]:
			if not world.DUNGEON_RUNS.whole(p.get(field),0,9000000000000000):return "던전 잔여시간 오류"
	for key: Variant in value.attempts:
		if not key is String or not world.DUNGEON_RUNS.whole(value.attempts[key],0,10):return "던전 도전 횟수 오류"
	for key: Variant in value.receipts:
		var receipt: Variant=value.receipts[key]
		if not key is String or not receipt is Dictionary or not receipt.get("rows") is Array or receipt.rows.size()>100:return "던전 보상 영수증 오류"
		for r: Variant in receipt.rows:
			if not r is Dictionary or not world.DUNGEON_RUNS.whole(r.get("ID"),1) or not world.DUNGEON_RUNS.whole(r.get("Amount"),1):return "던전 보상 행 오류"
	var run: Dictionary=value.active
	if not run.is_empty():
		if run.get("kind") not in ["orim","special"] or not run.get("id") is String or not run.get("map_id") is String or run.get("status") not in ["active","cleared","failed"]:return "던전 실행 상태 오류"
		for k: String in ["stage_id","started","last","duration","seed","cursor","remaining_count"]:
			if not world.DUNGEON_RUNS.whole(run.get(k),0,9000000000000000):return "던전 진행 수치 오류"
		if not run.get("buffs") is Dictionary or not run.get("groups") is Array or not run.get("events") is Dictionary or run.events.size()>10000 or not run.get("rewards") is Array or not run.get("issued",{}) is Dictionary:return "던전 진행 기록 오류"
		if run.kind=="orim" and rules.stage("orim",int(run.stage_id)).is_empty():return "오림 원본 자료 누락"
		if run.kind=="special" and not rules.special_by_id.has(int(run.stage_id)):return "특수던전 자료 누락"
		if run.kind=="special":
			var expected: Array=[]
			for group: Dictionary in rules.special_by_id[int(run.stage_id)].destinations[0].place.time_groups:expected.append(int(group.row.ID))
			if expected.is_empty():expected=[-int(run.stage_id)]
			if JSON.parse_string(JSON.stringify(expected))!=JSON.parse_string(JSON.stringify(run.groups)):return "특수던전 시간 그룹 원본 불일치"
			for group_id: int in expected:
				if not value.pools.has(str(group_id)):return "특수던전 시간 풀 누락"
		if run.kind=="orim":
			var stage: Dictionary=rules.stage("orim",int(run.stage_id));var known: Dictionary={}
			if not world.DUNGEON_RUNS.whole(run.duration,10,3600) or run.rewards.size()>10:return "오림 시간·보상 한도 오류"
			var wave_rows: Dictionary={}
			for row: Dictionary in stage.spawns:wave_rows[str(int(row.ID))]=row
			if run.get("issued",{}).size()>10000:return "오림 생성 기록 한도 오류"
			for token: Variant in run.get("issued",{}):
				var issued: Variant=run.issued[token]
				if not token is String or token.length()>80 or not issued is Dictionary or not issued.get("row") is Dictionary or not world.DUNGEON_RUNS.whole(issued.get("source_id")):return "오림 생성 기록 손상"
				var row_id:=str(int(issued.row.get("ID",0)))
				if not wave_rows.has(row_id) or JSON.parse_string(JSON.stringify(issued.row))!=JSON.parse_string(JSON.stringify(wave_rows[row_id])):return "오림 생성 계획 원본 불일치"
				for vital: String in ["hp","mp"]:
					if issued.has(vital) and not world.DUNGEON_RUNS.whole(issued[vital],0,9000000000000000):return "오림 개체 생명력 기록 오류"
			for token: Variant in run.events:
				if not token is String or not run.get("issued",{}).has(token) or run.events[token]!=true:return "오림 처치 기록 불일치"
			if run.status!="active" and (not run.get("success") is bool or not world.DUNGEON_RUNS.whole(run.get("completed_at"),0,9000000000000000)):return "오림 완료 기록 오류"
			for r: Dictionary in stage.normal_rewards+stage.lucky_rewards:known[str(int(r.row.ID))]=r
			for section: Dictionary in stage.sections:
				for r: Dictionary in section.care_rewards:known[str(int(r.row.ID))]=r
			for r: Variant in run.rewards:
				if not r is Dictionary or not r.get("row") is Dictionary:return "오림 보상 형식 오류"
				var key:=str(int(r.row.get("ID",0)))
				if not known.has(key) or JSON.parse_string(JSON.stringify(r))!=JSON.parse_string(JSON.stringify(known[key])):return "오림 보상 원본 불일치"
	return ""

func restore(value: Dictionary) -> bool:
	problem=valid(value);save_blocked=not problem.is_empty()
	if save_blocked:return false
	cleanup();state=value.duplicate(true);pending.clear();changed.emit();return true

func commit(candidate: Dictionary, changes: Dictionary = {}) -> Dictionary:
	if save_blocked:return {"ok":false,"reason":problem}
	if not pending.is_empty() and candidate!=pending.candidate:return {"ok":false,"reason":"대기 중인 저장을 먼저 재시도하세요."}
	candidate=snapshot(candidate)
	candidate.revision=int(state.get("revision",0))+1
	var error:=valid(candidate)
	if not error.is_empty():problem=error;return {"ok":false,"reason":error}
	var result: Error=world.commit_dungeon_play(candidate,changes)
	if result!=OK:return {"ok":false,"reason":problem if save_blocked else "던전 저장 실패 · 재시도 필요"}
	var refresh: bool=not changes.is_empty() or candidate.active.get("buffs",{})!=state.active.get("buffs",{}) or candidate.active.get("reroll_stat","")!=state.active.get("reroll_stat","")
	state=candidate;problem=""
	if refresh:world._update_hud()
	changed.emit();return {"ok":true}

func snapshot(candidate: Dictionary = {}) -> Dictionary:
	var out: Dictionary=(state if candidate.is_empty() else candidate).duplicate(true)
	if not out.active.is_empty() and out.active.kind=="orim" and out.active.get("id","")==state.active.get("id",""):
		for token: String in actors:
			var actor: Variant=actors[token]
			if is_instance_valid(actor) and not actor.dead and out.active.get("issued",{}).has(token):
				out.active.issued[token].hp=int(actor.hp);out.active.issued[token].mp=int(actor.mp)
	return out

func defer_candidate(candidate: Dictionary, changes: Dictionary) -> void:
	pending={"candidate":candidate,"changes":changes,"base":{"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"gold":world.gold,"experience":world.experience,"hp":world.hp,"mp":world.mp,"blessing":world.ain_service.blessing}}

func pending_changes() -> Dictionary:
	var changes: Dictionary=pending.changes.duplicate(true);var base: Dictionary=pending.base
	if changes.has("inventory"):
		var result: Dictionary=world.inventory.duplicate(true);var names: Dictionary=base.inventory.duplicate(true);names.merge(changes.inventory,true)
		for name: String in names:
			var value: int=int(result.get(name,0))+int(changes.inventory.get(name,0))-int(base.inventory.get(name,0))
			if value<0:return {"blocked":true,"reason":"대기 거래의 소비 수량이 달라졌습니다. 저장 취소 또는 아이템 확인이 필요합니다."}
			if value==0:result.erase(name)
			else:result[name]=value
		changes.inventory=result
	if changes.has("item_instances"):
		var result: Dictionary=world.item_instances.duplicate(true);var ids: Dictionary=base.item_instances.duplicate(true);ids.merge(changes.item_instances,true)
		for id: String in ids:
			var before: Variant=base.item_instances.get(id);var after: Variant=changes.item_instances.get(id)
			if before==after:continue
			if before!=null and (not result.has(id) or result[id]!=before or world._item_locked(str(before.name),id)):return {"blocked":true,"reason":"대기 거래의 실물 개체가 변경/잠금 상태입니다. 저장 취소 또는 확인이 필요합니다."}
			if before==null and result.has(id):return {"blocked":true,"reason":"실물 개체 ID 충돌"}
			if after==null:result.erase(id)
			else:result[id]=after
		changes.item_instances=result
	for key: String in ["gold","experience","hp","mp"]:
		if changes.has(key):changes[key]=int(world.get(key))+int(changes[key])-int(base[key])
	if changes.has("hp"):changes.hp=clampi(int(changes.hp),0,world._effective_max_hp())
	if changes.has("mp"):changes.mp=clampi(int(changes.mp),0,world.max_mp)
	if int(changes.get("gold",0))<0 or int(changes.get("experience",0))<0:return {"blocked":true,"reason":"대기 거래 잔액 부족"}
	if changes.has("ainhasad_state"):
		var ain: Dictionary=world.ain_service.export_state().duplicate(true)
		ain.blessing=clampi(world.ain_service.blessing+int(changes.ainhasad_state.blessing)-int(base.blessing),0,world.ain_service.MAX_BLESSING)
		changes.ainhasad_state=ain
	return changes

func cancel_pending() -> Dictionary:
	if save_blocked:return {"ok":false,"reason":"저장 후보 상태가 불확실하므로 다시 불러오기가 필요합니다."}
	pending.clear();changed.emit();return {"ok":true}

func configure_settings(changes: Dictionary) -> Dictionary:
	if not state.active.is_empty() or not pending.is_empty():return {"ok":false,"reason":"현재 도전과 보상을 먼저 처리하세요."}
	for key: String in changes:
		if not defaults().has(key):return {"ok":false,"reason":"알 수 없는 자체 설정: "+key}
	var next:=state.duplicate(true);next.settings.merge(changes,true)
	return commit(next)

func day(now: int) -> int:
	return maxi(int(state.day),CLOCK.korean_daily_key(now))

func period(group: Dictionary, now: int) -> int:
	var d:=day(now)
	var reset:=str(group.get("reset",{}).get("Name","Daily"))
	if reset=="WeeklyWed":return floori(float(d-6)/7.0)
	if reset=="WeeklyMon":return floori(float(d-4)/7.0)
	if reset=="Monthly":
		var t:=Time.get_datetime_dict_from_unix_time(now+4*3600);return int(t.year)*12+int(t.month)
	return d if reset!="Specific" or state.settings.specific_daily else 0

func pool(group_id: int, now: int) -> Dictionary:
	var key:=str(group_id)
	var group: Dictionary=rules.time_by_id.get(group_id,{})
	var cycle:=period(group,now)
	var base: int=int(group.row.TimeLimit)*int(state.settings.group_time_scale) if not group.is_empty() else int(state.settings.ungrouped_time)
	var p: Dictionary=state.pools.get(key,{"period":cycle,"base":base,"bonus":0}).duplicate(true)
	if cycle>int(p.period) and (state.active.is_empty() or not group_id in state.active.get("groups",[])):
		p={"period":cycle,"base":base,"bonus":int(p.bonus) if state.settings.carry_bonus else 0}
	return p

func check_idle() -> String:
	if not state.settings.enabled:return "자체 던전 실행을 켜 주세요."
	if save_blocked:return problem
	if not pending.is_empty():return "실패한 저장 재시도를 먼저 처리하세요."
	if not state.active.is_empty():return "현재 실행 또는 보상 수령을 먼저 처리하세요."
	if not world.source_dungeon_runs.state.active.is_empty() and world.source_dungeon_runs.state.active.status in ["active","cleared"]:return "시련탑 도전을 먼저 처리하세요."
	return ""

func payment(currency: int, amount: int) -> Dictionary:
	if amount==0:return {"ok":true}
	if currency==1:return {"ok":world.gold>=amount,"gold":world.gold-amount,"reason":"아데나 부족"}
	return ECONOMY.payment(world,currency,amount)

func begin(kind: String, identifier: int, now: int = -1) -> Dictionary:
	if now<0:now=int(Time.get_unix_time_from_system())
	var error:=check_idle()
	if not error.is_empty():return {"ok":false,"reason":error}
	var entry: Dictionary=rules.stage("orim",identifier) if kind=="orim" else rules.special_by_id.get(identifier,{})
	if entry.is_empty():return {"ok":false,"reason":"원본 정의 없음"}
	var minimum:=0;var maximum:=0
	for requirement: Dictionary in entry.get("prerequisites",entry.get("place",{}).get("attributes",[])):
		if requirement.type=="MinLevel":minimum=maxi(minimum,int(requirement.row.Value))
		if requirement.type=="MaxLevel":maximum=int(requirement.row.Value)
	if world.level<minimum or (maximum>0 and world.level>maximum):return {"ok":false,"reason":"원본 입장 레벨 조건 불충족"}
	var next:=state.duplicate(true);var cost: Dictionary;var groups: Array=[]
	if kind=="orim":
		if rules.orim_actor_types.is_empty() or rules.orim_actor_defs.is_empty():return {"ok":false,"reason":"NPC 수치가 포함된 최신 오림 실행 부속 자료가 필요합니다."}
		if not choose_template():return {"ok":false,"reason":"현재 지역의 몬스터 대체형이 필요합니다."}
		if not placement_point().is_finite():return {"ok":false,"reason":"현재 지역의 검증된 배치 공간이 필요합니다. 입장 비용을 보존했습니다."}
		var budget: String=("hard:" if bool(entry.stage.IsHard) else "normal:")+str(day(now))
		if int(next.attempts.get(budget,0))>=int(state.settings.attempts):return {"ok":false,"reason":"오늘 이 모드 도전 횟수 소진"}
		cost=payment(int(state.settings.entry_currency),int(state.settings.entry_cost));next.attempts[budget]=int(next.attempts.get(budget,0))+1
	else:
		var currency:=int(entry.teleport.CurrencyID)
		cost=payment(currency,int(entry.teleport.TeleportCost)) if currency in [1,4,174] else consume_source(int(entry.currency.sources[0].ClassID),int(entry.teleport.TeleportCost))
		for g: Dictionary in entry.destinations[0].place.time_groups:groups.append(int(g.row.ID))
		if groups.is_empty():groups=[-identifier] # Clearly own ungrouped-session pool.
		for group_id: int in groups:
			var p:=pool(group_id,now)
			if int(p.base)+int(p.bonus)<=0:return {"ok":false,"reason":"던전 이용시간 소진"}
			next.pools[str(group_id)]=p
	if not cost.get("ok",false):return cost
	cost.erase("ok");cost.erase("reason")
	var rng:=RandomNumberGenerator.new();rng.randomize()
	next.active={"kind":kind,"id":kind+":"+str(int(next.next)),"stage_id":identifier,"map_id":world.active_map_id,"status":"active","started":now,"last":now,"duration":int(state.settings.duration) if kind=="orim" else 0,"seed":rng.randi_range(1,2000000000),"cursor":0,"remaining_count":0,"groups":groups,"buffs":{},"events":{},"rewards":[],"issued":{},"rerolls":0,"reroll_stat":""}
	next.next=int(next.next)+1;next.day=day(now)
	return commit(next,cost)

func consume_source(item_id: int, amount: int) -> Dictionary:
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true);var selected: Array[String]=[];var name: String=""
	for id: String in instances:
		var record: Variant=instances[id].get("record",{})
		if record is Dictionary and record.get("source_snapshot","")=="current523" and record.get("source","")=="lineagem_current523" and record.get("sourceId","")=="m523:item:"+str(item_id) and int(record.get("source_item_class_id",0))==item_id:
			if name.is_empty():name=str(instances[id].name)
			if instances[id].name==name and not world._item_locked(name,id):selected.append(id)
	if selected.size()<amount or ECONOMY.count(inventory.get(name,0))<amount:return {"ok":false,"reason":"원본 ID가 확인된 실물 아이템 부족"}
	selected.sort()
	for i: int in range(amount):instances.erase(selected[i])
	inventory[name]=int(inventory[name])-amount
	if int(inventory[name])==0:inventory.erase(name)
	return {"ok":true,"inventory":inventory,"item_instances":instances}

func recharge(item_id: int, now: int = -1) -> Dictionary:
	if now<0:now=int(Time.get_unix_time_from_system())
	var error:=check_idle()
	if not error.is_empty():return {"ok":false,"reason":error}
	var item: Dictionary=rules.recharge_by_item.get(item_id,{})
	if item.is_empty() or bool(item.item.row.TestItem) or world.level<int(item.item.row.LevelLimitMin) or (int(item.item.row.LevelLimitMax)>0 and world.level>int(item.item.row.LevelLimitMax)):return {"ok":false,"reason":"충전석 종류·레벨 조건 불충족"}
	if not state.settings.preserve_items and expired(item.item,now):return {"ok":false,"reason":"원본 날짜 기준 만료 아이템"}
	var id:=int(item.group_id);var p:=pool(id,now);var cap:=int(rules.time_by_id[id].row.MaxRechargeTime)*int(state.settings.group_time_scale)
	if cap==0:cap=int(state.settings.zero_cap)
	if int(p.bonus)+3600>cap:return {"ok":false,"reason":"별도 충전시간 상한 초과 · 아이템 보존"}
	var changes:=consume_source(item_id,1)
	if not changes.get("ok",false):changes=consume_own_recharger(item_id)
	if not changes.get("ok",false):return changes
	changes.erase("ok");p.bonus=int(p.bonus)+3600
	var next:=state.duplicate(true);next.pools[str(id)]=p;next.day=day(now)
	return commit(next,changes)

func expired(item: Dictionary, now: int) -> bool:
	for deletion: Dictionary in item.get("deletion",[]):
		if deletion.get("date") is Dictionary:
			var d: Dictionary=deletion.date
			var iso: String="%04d-%02d-%02dT%02d:%02d:00" % [int(d.Year),int(d.Month),int(d.Day),int(d.Hour),int(d.Minute)]
			if now>=Time.get_unix_time_from_datetime_string(iso)-9*3600:return true
	return false

func choose_template() -> bool:
	if not template.is_empty():return true
	for child: Node in world.monsters_root.get_children():
		if child is TwilightMonster and not child.dead:
			var records: Dictionary=world.field_population.records
			if records.has(child.monster_name):template=records[child.monster_name].duplicate(true);return true
	return false

func tick(delta: float, now: int = -1) -> void:
	tick_clock+=delta
	if tick_clock<0.5:return
	tick_clock=0
	if now<0:now=int(Time.get_unix_time_from_system())
	if not pending.is_empty():
		var changes:=pending_changes()
		if changes.get("blocked",false):problem=str(changes.reason);return
		var done:=commit(pending.candidate,changes)
		if done.get("ok",false):
			pending.clear()
			if state.active.is_empty() or state.active.status!="active":cleanup()
			if changes.has("experience"):world._check_level_up();world._request_deferred_save()
		return
	if state.active.is_empty() or state.active.status!="active":return
	var run: Dictionary=state.active
	if run.kind=="special":
		account_special(now,str(run.map_id)!=world.active_map_id);changed.emit();return
	if str(run.map_id)!=world.active_map_id:stop(now);return
	if now>=int(run.started)+int(run.duration):
		finish_orim(false,now);return
	spawn_due(now)
	changed.emit()

func account_special(now: int, stop: bool = false) -> Dictionary:
	var next:=state.duplicate(true);var run: Dictionary=next.active
	if run.is_empty() or run.kind!="special":return {"ok":false,"reason":"시간 세션 없음"}
	var elapsed:=maxi(0,now-int(run.last));var exhausted:=false
	for id: int in run.groups:
		var p: Dictionary=next.pools[str(id)]
		var drain:=mini(elapsed,int(p.base)+int(p.bonus));var from_base:=mini(drain,int(p.base))
		p.base=int(p.base)-from_base;p.bonus=int(p.bonus)-(drain-from_base)
		exhausted=exhausted or int(p.base)+int(p.bonus)==0
	run.last=maxi(now,int(run.last))
	if stop or exhausted:next.active={}
	return commit(next) if elapsed>=5 or stop or exhausted else {"ok":true}

func timeline(stage_id: int) -> Array:
	var rows: Array=rules.waves(stage_id)
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.Second)<int(b.Second) or (int(a.Second)==int(b.Second) and int(a.ID)<int(b.ID)))
	return rows

func spawn_due(now: int) -> void:
	if rules.orim_actor_defs.is_empty():return
	if not choose_template():return
	var run: Dictionary=state.active;var rows:=timeline(int(run.stage_id));var elapsed:=maxi(0,now-int(run.started))
	var source_elapsed:=float(elapsed)*420.0/maxf(1,float(run.duration))
	var spawned:=0
	for token: String in run.get("issued",{}):
		if actors.size()>=int(state.settings.live_limit):break
		if not run.events.has(token) and not actors.has(token):
			var issued: Dictionary=run.issued[token]
			if not spawn_actor(issued.row,int(issued.source_id),token):break
	while int(run.cursor)<rows.size() and actors.size()<int(state.settings.live_limit) and spawned<8:
		var row: Dictionary=rows[int(run.cursor)]
		if float(row.Second)>source_elapsed or int(row.Second)>420:break
		if rules.orim_actor_types.get(int(row.NpcClassID),"")=="Boss":run.cursor=int(run.cursor)+1;run.remaining_count=0;continue
		var remaining:=int(run.remaining_count)
		if remaining==0:remaining=int(row.Count)* (int(state.settings.group_size) if int(row.NpcGroupID)!=0 else 1)
		var source_id:=int(row.NpcClassID)
		if source_id==0:
			var members: Array=rules.orim_groups.get(int(row.NpcGroupID),[])
			if not members.is_empty():source_id=int(members[(remaining-1)%members.size()])
		var token: String=str(int(row.ID))+":"+str(remaining)
		if not run.events.has(token):
			if not spawn_actor(row,source_id,token):break
		remaining-=1;spawned+=1
		run.remaining_count=remaining
		if remaining<=0:run.cursor=int(run.cursor)+1
	# Priority final-boss slot cannot be starved by the capped local wave queue.
	for row: Dictionary in rows:
		if rules.orim_actor_types.get(int(row.NpcClassID),"")=="Boss" and float(row.Second)<=source_elapsed:
			var token:=str(int(row.ID))+":boss"
			if not run.events.has(token) and not actors.has(token):spawn_actor(row,int(row.NpcClassID),token)

func placement_point() -> Vector2:
	var origin: Vector2=world.player.global_position
	if not origin.is_finite():return Vector2.INF
	# Own arena sampling uses the current verified field's existing geometry.
	# No M523 coordinate, landing or collision data is inferred or modified.
	for attempt: int in range(64):
		var point: Vector2=origin+Vector2.from_angle(world.rng.randf()*TAU)*world.rng.randf_range(80.0,450.0)
		if not world._is_walkable_world(point):continue
		var separated:=true
		for actor: Variant in actors.values():
			if is_instance_valid(actor) and actor.global_position.distance_squared_to(point)<784.0:separated=false;break
		if not separated:continue
		if world.field_map.has_method("path") and world.field_map.path(origin,point).is_empty():continue
		return point
	return Vector2.INF

func spawn_actor(row: Dictionary, source_id: int, token: String) -> bool:
	if actors.has(token):return true
	var point:=placement_point()
	if not point.is_finite():placement_blocked=true;return false
	placement_blocked=false
	var saved_actor: Dictionary=state.active.issued.get(token,{})
	var monster: TwilightMonster=world.MONSTER_SCENE.instantiate()
	monster.position=world.monsters_root.to_local(point)
	world.monsters_root.add_child(monster)
	var role: String=rules.orim_actor_types.get(source_id,"Monster")
	# Borrow visual identity only, never unrelated poison/skills/combat stats.
	var record: Dictionary={"name":str(template.name),"source":"twilight_dungeon_visual_adapter","lv":maxi(1,int(row.Level)),"hp":1,"atk":8,"def":0,"ac":-1,"mr":0,"drop":[],"exp":0,"gold":0,"attack_type":"melee"}
	for visual_key: String in ["sourceId","visual","visual_height","animation_profile"]:
		if template.has(visual_key):record[visual_key]=template[visual_key]
	record["ai"]={"aggressive":role in ["Monster","MiddleBoss","Boss"]}
	var attribute_input: Dictionary=preload("res://scripts/resources/current523_actor_attribute_input.gd").orim(source_id,int(state.active.stage_id),row)
	if not attribute_input.is_empty():record["original_attribute_input"]=attribute_input
	if not monster.setup(record,world.player,world,world._monster_texture(record)):
		monster.queue_free()
		return false
	monster.set_meta("summoned",true)
	var factor: int=int(state.settings.hard_multiplier) if bool(rules.stage("orim",int(state.active.stage_id)).stage.IsHard) else 1
	var definition: Dictionary=rules.orim_actor_defs.get(source_id,{})
	if not definition.is_empty():
		monster.max_hp=maxi(1,int(definition.row.HP));monster.max_mp=maxi(0,int(definition.row.MP));monster.mp=monster.max_mp
		monster.armor_class=int(definition.row.AC);monster.magic_resistance=int(definition.row.MR)
		monster.attack_power=0
		for attack: Dictionary in definition.attacks:
			if not attack.IsSpell:
				monster.attack_power=maxi(0,int(round(float(attack.DiceCount)*(float(attack.DiceSpots)+1.0)/2.0+float(attack.DiceBonus))));monster.set_meta("dungeon_play_attack",attack.duplicate(true))
				var range_input: Dictionary = preload("res://scripts/resources/current523_actor_attribute_input.gd").attack_range(attribute_input,attack,monster.attack_type)
				if not range_input.is_empty():
					monster.configured_attack_range=float(range_input.host_length)
					monster.set_meta("original_orim_attack_range_input",range_input)
				break
	monster.max_hp*=factor*(int(state.settings.boss_hp_multiplier) if role=="Boss" else 1);monster.hp=monster.max_hp;monster.hp_bar.max_value=monster.max_hp;monster.hp_bar.value=monster.hp
	monster.attack_power*=factor;monster.is_boss=role in ["MiddleBoss","Boss"]
	preload("res://scripts/maps/source_body_profile.gd").apply(monster,world.field_map is RemakePlayableField or world.field_map is NativePngField)
	monster.hp=clampi(int(saved_actor.get("hp",monster.max_hp)),1,monster.max_hp);monster.mp=clampi(int(saved_actor.get("mp",monster.max_mp)),0,monster.max_mp);monster.hp_bar.value=monster.hp
	monster.set_meta("dungeon_play_run",str(state.active.id));monster.set_meta("dungeon_play_token",token)
	state.active.issued[token]={"row":row.duplicate(true),"source_id":source_id,"hp":monster.hp,"mp":monster.mp}
	monster.set_meta("dungeon_play_role",role);monster.set_meta("declared_npc",source_id)
	monster.name_label.text=str(definition.get("name","오림"))+" · 자체 외형"
	monster.died.connect(world._on_monster_died);monster.player_hit.connect(actor_hit)
	actors[token]=monster
	return true

func actor_hit(actor: TwilightMonster, _display_damage: int, kind: String) -> void:
	if state.active.is_empty() or state.active.kind!="orim" or state.active.status!="active" or actor.get_meta("dungeon_play_run","")!=state.active.id:return
	if actor.get_meta("dungeon_play_role","") not in ["Monster","MiddleBoss","Boss"] or not actor.has_meta("dungeon_play_attack"):return
	var attack: Dictionary=actor.get_meta("dungeon_play_attack");var damage:=roll_attack(attack,world.rng)
	if bool(rules.stage("orim",int(state.active.stage_id)).stage.IsHard):damage*=int(state.settings.hard_multiplier)
	world._on_player_hit(actor,maxi(0,damage),kind)

static func roll_attack(attack: Dictionary, rng: RandomNumberGenerator) -> int:
	var damage:=int(attack.DiceBonus)
	for die: int in range(int(attack.DiceCount)):
		if int(attack.DiceSpots)>0:damage+=rng.randi_range(1,int(attack.DiceSpots))
	return damage

func monster_died(monster: TwilightMonster, now: int = -1) -> void:
	if now<0:now=int(Time.get_unix_time_from_system())
	var run: Dictionary=state.active
	if run.is_empty() or run.kind!="orim" or run.status!="active" or monster.get_meta("dungeon_play_run","")!=run.id:return
	if not monster.dead or monster.get_parent()!=world.monsters_root:return
	var token: String=monster.get_meta("dungeon_play_token","")
	if run.events.has(token) or not pending.is_empty():return
	actors.erase(token)
	monster.call_deferred("queue_free")
	if monster.get_meta("dungeon_play_role","")=="Boss":
		finish_orim(now<int(run.started)+int(run.duration),now,token)
		return
	var next:=state.duplicate(true);next.active.events[token]=true
	var saved:=commit(next)
	if not saved.get("ok",false):defer_candidate(next,{});return
	if now>=int(run.started)+int(run.duration):finish_orim(false,now);return
	var role: String=monster.get_meta("dungeon_play_role","")
	if role in ["HealingSphere","LastHealingSphere"]:
		var heal: Dictionary={"hp":mini(world._effective_max_hp(),world.hp+int(round(world._effective_max_hp()*float(state.settings.heal_percent)/100.0)))}
		var healed:=commit(state.duplicate(true),heal)
		if not healed.get("ok",false):defer_candidate(state.duplicate(true),heal)
	else:
		var rng:=RandomNumberGenerator.new();rng.seed=int(run.seed)+token.hash()
		var chance:=float(state.settings.token_chance)*(1.1 if run.buffs.has("72362") else 1.0)
		if rng.randf()*100.0<chance:
			var name: String="TWILIGHT · 오림의 증표"
			world.ground_loot.spawn(name,monster.global_position,1,"",{"item_record":local_item(name,226862,1)})

func finish_orim(success: bool, now: int, event_token: String = "") -> Dictionary:
	var next:=state.duplicate(true);var run: Dictionary=next.active
	if run.is_empty() or run.kind!="orim":return {"ok":false,"reason":"오림 실행 없음"}
	if not event_token.is_empty():run.events[event_token]=true
	var stage: Dictionary=rules.stage("orim",int(run.stage_id));var left:=maxi(0,int(run.started)+int(run.duration)-now)
	var rows: Array=[]
	if success:rows=stage.normal_rewards.duplicate(true)
	var section: Dictionary={}
	# Own rule: at a shared endpoint select the interval with the higher minimum.
	for s: Dictionary in stage.sections:
		if left>=int(s.row.MinRemainTimeSecond) and left<=int(s.row.MaxRemainTimeSecond) and (section.is_empty() or int(s.row.MinRemainTimeSecond)>int(section.row.MinRemainTimeSecond)):section=s
	var rng:=RandomNumberGenerator.new();rng.seed=int(run.seed)
	if not section.is_empty():
		if state.settings.care=="always" or (not success and state.settings.care=="timeout"):rows.append_array(section.care_rewards.duplicate(true))
		if success:
			var candidates: Array=stage.lucky_rewards.duplicate(true)
			for draw: int in range(rng.randi_range(int(section.row.MinLuckyRewardCount),int(section.row.MaxLuckyRewardCount))):
				var total:=0
				for r: Dictionary in candidates:total+=int(r.link.Weight)
				if total<=0:break
				var choice:=rng.randi_range(1,total)
				for i: int in range(candidates.size()):
					choice-=int(candidates[i].link.Weight)
					if choice<=0:
						rows.append(candidates[i].duplicate(true))
						if not state.settings.replacement:candidates.remove_at(i)
						break
	run.status="cleared" if not rows.is_empty() else "failed";run.rewards=rows;run.success=success;run.completed_at=now
	var result:=commit(next)
	if result.get("ok",false):cleanup()
	else:defer_candidate(next,{})
	return result

func claim() -> Dictionary:
	if state.active.is_empty() or state.active.status!="cleared":return {"ok":false,"reason":"수령할 보상 없음"}
	var next:=state.duplicate(true);var run: Dictionary=next.active
	if next.receipts.has(run.id):return {"ok":false,"reason":"이미 지급된 보상"}
	var changes:=reward_plan(run.rewards)
	if not changes.get("ok",false):return changes
	changes.erase("ok");var rows: Array=[]
	for r: Dictionary in run.rewards:rows.append(r.row.duplicate(true))
	next.receipts[run.id]={"rows":rows,"mode":"twilight_orim"};next.active={}
	return commit(next,changes)

func buy_buff(buff_id: int) -> Dictionary:
	if state.active.is_empty() or state.active.kind!="orim" or state.active.status!="active":return {"ok":false,"reason":"오림 자체 실행 중에만 준비 강화 가능"}
	if state.active.buffs.has(str(buff_id)):return {"ok":false,"reason":"이미 구매한 강화"}
	for buff: Dictionary in rules.data.declarations.OrimsTrailBuff:
		if int(buff.BuffClassID)!=buff_id:continue
		var cost:=payment(int(buff.CurrencyID),int(buff.CurrencyCost))
		if not cost.get("ok",false):return cost
		cost.erase("ok");cost.erase("reason")
		var next:=state.duplicate(true);next.active.buffs[str(buff_id)]=true
		return commit(next,cost)
	return {"ok":false,"reason":"준비 강화 원본 없음"}

func reroll() -> Dictionary:
	if state.active.is_empty() or state.active.kind!="orim" or state.active.status!="active":return {"ok":false,"reason":"실행 중에만 자체 능력 재선택 가능"}
	var count:=int(state.active.get("rerolls",0))+1;var amount: int=-1
	for row: Dictionary in rules.data.declarations.OrimsTrailRerollCurrencyCost:
		if int(row.RerollCount)==count:amount=int(row.Cost)
	if amount<0:return {"ok":false,"reason":"원본 재선택 횟수 상한"}
	var cost:=payment(int(state.settings.reroll_currency),amount)
	if not cost.get("ok",false):return cost
	cost.erase("ok");cost.erase("reason")
	var next:=state.duplicate(true);var rng:=RandomNumberGenerator.new();rng.seed=int(next.active.seed)+count
	next.active.rerolls=count;next.active.reroll_stat=["move_speed","attack_speed","boss_damage"][rng.randi_range(0,2)]
	return commit(next,cost)

func modifier(stat: String) -> float:
	if state.active.is_empty() or state.active.kind!="orim" or state.active.status!="active":return 0.0
	var result:=0.0
	if stat in ["move_speed","attack_speed"]:
		for key: String in state.active.buffs:
			if key not in ["71672","71682","71692"]:continue
			var setting: String="pearl_percent" if key=="71692" else "speed_percent"
			var amount: float=float(state.settings[setting])
			var original: Dictionary=rules.original_orim_speed_input(int(key),stat)
			# Existing custom settings remain explicit host overrides. Source
			# defaults feed the same operand; no purchase/state/stack rule changes.
			if original.get("excluded",false):continue
			if amount==float(defaults()[setting]) and original.get("ok",false):amount=float(original.value)
			result+=amount
	if state.active.get("reroll_stat","")==stat:result+=float(state.settings.reroll_percent)
	return result

func reward_plan(rows: Array) -> Dictionary:
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	for reward: Dictionary in rows:
		var row: Dictionary=reward.row;var id:=int(row.RewardClassID);var bless:=int(row.ItemBlessCodeID)
		if reward.type!="Item" or ECONOMY.count(row.Amount)<1:return {"ok":false,"reason":"지원하지 않는 보상"}
		if not state.settings.preserve_items and expired(reward.item,int(Time.get_unix_time_from_system())):continue
		var name: String=ECONOMY.ITEM_NAMES[id] if id in [3631,3252,3242,246058] else "TWILIGHT · "+str(reward.item.name)+(" (축복)" if bless==2 else "")
		if ECONOMY.count(inventory.get(name,0))<0:return {"ok":false,"reason":"기존 수량 오류"}
		inventory[name]=int(inventory.get(name,0))+int(row.Amount)
		if id not in [3631,3252,3242,246058]:
			var record:=local_item(name,id,bless)
			for i: int in range(int(row.Amount)):
				if id==226862:break # stackable own token, not a physical consumable.
				var physical: String="dungeon:"+Crypto.new().generate_random_bytes(16).hex_encode()
				instances[physical]={"name":name,"level":0,"element":"","element_level":0,"record":record}
	return {"ok":true,"inventory":inventory,"item_instances":instances}

func original_item(item_id: int) -> Dictionary:
	for stage: Dictionary in rules.data.get("orim",[]):
		for reward: Dictionary in stage.normal_rewards+stage.lucky_rewards:
			if int(reward.row.RewardClassID)==item_id:return reward.item
	return {}

static func local_item(name: String, source_id: int, bless: int) -> Dictionary:
	return {"name":name,"type":"재료","slot":"material","grade":"일반","weight":0,"stackable":true,"droppable":false,"sellable":false,"source":"twilight_dungeon_adaptation","declared_source_item":source_id,"declared_bless":bless}

func install_items() -> void:
	var seen: Dictionary={}
	for stage: Dictionary in rules.data.get("orim",[]):
		for reward: Dictionary in stage.normal_rewards+stage.lucky_rewards:
			var id:=int(reward.row.RewardClassID);var bless:=int(reward.row.ItemBlessCodeID)
			if id in [3631,3252,3242,246058]:continue
			var name: String="TWILIGHT · "+str(reward.item.name)+(" (축복)" if bless==2 else "")
			if seen.has(name):continue
			seen[name]=true
			if world._find_catalog_item_record(name).is_empty():world.item_db.append(local_item(name,id,bless))

func own_physical(name: String, declared_id: int) -> String:
	for id: String in world.item_instances:
		var physical: Dictionary=world.item_instances[id];var record: Variant=physical.get("record",{})
		if physical.get("name","")==name and record is Dictionary and record.get("source","")=="twilight_dungeon_adaptation" and int(record.get("declared_source_item",0))==declared_id and not world._item_locked(name,id):return id
	return ""

func buy_recharger(item_id: int) -> Dictionary:
	var error:=check_idle()
	if not error.is_empty():return {"ok":false,"reason":error}
	var charger: Dictionary=rules.recharge_by_item.get(item_id,{})
	if charger.is_empty() or charger.item.row.TestItem:return {"ok":false,"reason":"구입할 충전석 정의 없음"}
	if not state.settings.preserve_items and expired(charger.item,int(Time.get_unix_time_from_system())):return {"ok":false,"reason":"원본 날짜 기준 만료된 충전석 · 자체 상점 구입 거부"}
	var amount:=int(state.settings.recharger_price)
	if world.gold<amount:return {"ok":false,"reason":"자체 상점 아데나 부족"}
	var name: String="TWILIGHT · "+str(charger.item.name)
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	inventory[name]=int(inventory.get(name,0))+1
	instances["dungeon:"+Crypto.new().generate_random_bytes(16).hex_encode()]={"name":name,"level":0,"element":"","element_level":0,"record":local_item(name,item_id,1)}
	if world._find_catalog_item_record(name).is_empty():world.item_db.append(local_item(name,item_id,1))
	var next:=state.duplicate(true);next.receipts["own_charger:"+str(int(next.next))]={"rows":[],"kind":"own_recharger_purchase"};next.next=int(next.next)+1
	return commit(next,{"inventory":inventory,"item_instances":instances,"gold":world.gold-amount})

func consume_own_recharger(item_id: int) -> Dictionary:
	var charger: Dictionary=rules.recharge_by_item.get(item_id,{})
	if charger.is_empty():return {"ok":false,"reason":"충전석 없음"}
	var name: String="TWILIGHT · "+str(charger.item.name);var id:=own_physical(name,item_id)
	if id.is_empty() or ECONOMY.count(world.inventory.get(name,0))<1:return {"ok":false,"reason":"원본 확인 충전석 또는 자체 충전석 부족"}
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	inventory[name]=int(inventory[name])-1;instances.erase(id)
	if int(inventory[name])==0:inventory.erase(name)
	return {"ok":true,"inventory":inventory,"item_instances":instances}

func try_use_item(name: String, requested_id: String = "") -> bool:
	var physical:=own_physical(name,231162)
	if not requested_id.is_empty() and name=="TWILIGHT · "+str(original_item(231162).get("name","")):
		var chosen: Dictionary=world.item_instances.get(requested_id,{})
		var record: Dictionary=chosen.get("record",{})
		if chosen.get("name","")!=name or record.get("source","")!="twilight_dungeon_adaptation" or int(record.get("declared_source_item",0))!=231162 or world._item_locked(name,requested_id):
			world.hud.show_message("선택한 성수 개체를 다시 확인하세요.");return true
		physical=requested_id
	if physical.is_empty():return false
	if not state.settings.preserve_items and expired(original_item(231162),int(Time.get_unix_time_from_system())):world.hud.show_message("원본 날짜 기준 만료된 성수 · 아이템 보존");return true
	if rules.orim_item_effects.is_empty():world.hud.show_message("검증된 보상 효과 자료 필요");return true
	if not pending.is_empty() or save_blocked:world.hud.show_message("던전 저장을 먼저 복구하세요.");return true
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	if ECONOMY.count(inventory.get(name,0))<1:return true
	inventory[name]=int(inventory[name])-1;instances.erase(physical)
	if int(inventory[name])==0:inventory.erase(name)
	var ain: Dictionary=world.ain_service.export_state().duplicate(true)
	# Own conversion for the source's fixed-point blessing field, clearly exposed.
	ain.blessing=mini(world.ain_service.MAX_BLESSING,int(ain.blessing)+int(state.settings.holy_ain))
	var next:=state.duplicate(true);next.receipts["holy:"+str(int(next.next))]={"rows":[],"kind":"holy"};next.next=int(next.next)+1
	var experience_gain:=0
	for effect: Dictionary in rules.orim_item_effects.get(231162,[]):
		if effect.type=="Experience":experience_gain=int(effect.row.Value)
	var changes: Dictionary={"inventory":inventory,"item_instances":instances,"experience":world.experience+experience_gain,"ainhasad_state":ain}
	var result:=commit(next,changes)
	if not result.get("ok",false):defer_candidate(next,changes)
	else:world._check_level_up();world._request_deferred_save()
	world.hud.show_message("TWILIGHT 성수 사용 · EXP %d · 자체 환산 아인 %d" % [experience_gain,int(state.settings.holy_ain)] if result.get("ok",false) else str(result.reason));return true

func has_experience_award() -> bool:
	for receipt: Dictionary in state.receipts.values():
		if receipt.get("kind","")=="holy":return true
	return false

func try_enhancement(scroll_name: String, target_reference: String) -> bool:
	var scroll_id:=own_physical(scroll_name,232352)
	if scroll_id.is_empty():return false
	if not state.settings.preserve_items and expired(original_item(232352),int(Time.get_unix_time_from_system())):world.hud.show_message("원본 날짜 기준 만료된 주문서 · 아이템 보존");return true
	if not pending.is_empty() or save_blocked:world.hud.show_message("던전 저장 재시도 필요");return true
	if world.hud.has_method("is_enhancement_presenting") and world.hud.is_enhancement_presenting():return true
	var target: Dictionary=world._parse_enhancement_target(target_reference)
	var id: String=str(target.id)
	if id.is_empty():id=world._chosen_instance(str(target.name))
	if not world.item_instances.has(id) or world._item_locked(str(target.name),id):world.hud.show_message("강화할 장신구 개체 또는 잠금을 확인하세요.");return true
	var physical: Dictionary=world.item_instances[id]
	var record: Dictionary=physical.get("record",world._find_catalog_item_record(str(target.name)))
	if record.is_empty():record=world._find_catalog_item_record(str(target.name))
	if world._enhancement_kind_for_record(record)!="accessory" or int(world.inventory.get(scroll_name,0))<1:return true
	var mode: String="blessed_orim" if int(world.item_instances[scroll_id].record.declared_bless)==2 else "orim"
	var level:=int(physical.level)
	if not world._enhancement_level_allowed("accessory",mode,level):world.hud.show_message("사용 가능한 장신구 강화 단계가 아닙니다.");return true
	var chance: Dictionary=world._enhancement_chance("accessory",level,mode)
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	inventory[scroll_name]=int(inventory[scroll_name])-1;instances.erase(scroll_id)
	if int(inventory[scroll_name])==0:inventory.erase(scroll_name)
	var roll: float=world.rng.randf()*100.0;var outcome: String="maintain";var after:=level
	if roll<float(chance.success):after=mini(21,level+world._roll_enhancement_gain(mode,level));outcome="success"
	elif roll>=float(chance.success)+float(chance.no_change):after=maxi(0,level-1);outcome="decrease"
	instances[id].level=after
	var next:=state.duplicate(true);next.receipts["enchant:"+str(int(next.next))]={"rows":[],"kind":"own_orim_scroll","target":id,"before":level,"after":after};next.next=int(next.next)+1
	var changes: Dictionary={"inventory":inventory,"item_instances":instances}
	var result:=commit(next,changes)
	if not result.get("ok",false):defer_candidate(next,changes);world.hud.show_message(str(result.reason))
	else:world.hud.show_enhancement_result(outcome,str(target.name),level,after)
	return true

func stop(now: int = -1) -> Dictionary:
	if now<0:now=int(Time.get_unix_time_from_system())
	if state.active.is_empty():return {"ok":true}
	if state.active.kind=="special":return account_special(now,true)
	var next:=state.duplicate(true);next.active={}
	var result:=commit(next)
	if result.get("ok",false):cleanup()
	return result

func cleanup() -> void:
	for actor: Variant in actors.values():
		if is_instance_valid(actor):actor.queue_free()
	actors.clear();template.clear()

func status_text(now: int = -1) -> String:
	if now<0:now=int(Time.get_unix_time_from_system())
	if state.active.is_empty():return "실행 없음"
	var run: Dictionary=state.active
	if run.kind=="orim":
		var at: int=int(run.get("completed_at",now)) if run.status!="active" else now
		var ability: String={"move_speed":"이동속도","attack_speed":"공격속도","boss_damage":"기본공격 보스피해"}.get(str(run.get("reroll_stat","")),"없음")
		return "오림 자체 실행 · %s · 남은 %d초 · 웨이브 %d · 외형 대체 %d · 이동+%d%% 공격+%d%% · 능력 %s%s%s" % [str(run.status),maxi(0,int(run.started)+int(run.duration)-at),int(run.cursor),actors.size(),int(modifier("move_speed")),int(modifier("attack_speed")),ability," · 배치 공간 대기" if placement_blocked else "","" if ability=="없음" else " +%d%%" % int(state.settings.reroll_percent)]
	var left:=2147483647
	for id: int in run.groups:
		var p: Dictionary=state.pools[str(id)];left=mini(left,maxi(0,int(p.base)+int(p.bonus)-maxi(0,now-int(run.last))))
	return "특수던전 자체 시간 세션 · 남은 %d초 · 현재 지역 유지" % left
