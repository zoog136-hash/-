extends RefCounted
const Source = preload("res://scripts/titles/title_source523.gd")
const Personal = preload("res://scripts/titles/title_personal523.gd")
const CommonSource = preload("res://scripts/resources/current523_definition_rows.gd")
var personal = Personal.new()
const POLICY = "res://data/titles/local_policy523.json"
var source = Source.new()
var world
var state: Dictionary = fresh()
var policy: Dictionary = {}
var blocked: bool = false
var busy: bool = false
var clock: Callable
var session_nonce: String=Crypto.new().generate_random_bytes(8).hex_encode()

static func fresh() -> Dictionary:
	return {"schema":1,"revision":0,"achieved":[],"active":{},"day":0,"attempts":0,"last_clock":0,"rng":"1","display":false,"last_result":{}}

func _init() -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(POLICY)) == OK and parser.data is Dictionary: policy = parser.data
	if FileAccess.file_exists(Source.INSTALLED): source.problem = source.load_zip(Source.INSTALLED)
	var rng := RandomNumberGenerator.new(); rng.randomize(); state.rng = str(rng.state)
	personal.runtime=self

func configure(host: Node) -> void:
	world = host
	# Existing selections and live source data take priority. Reuse the exact
	# title parser only when the separate title input has never been selected.
	if not source.input_selected and source.stages.is_empty() and not source.problem.is_empty():
		var path: String = Source.INSTALLED if FileAccess.file_exists(Source.INSTALLED) else CommonSource.archive_path()
		if not path.is_empty(): source.problem = source.load_zip(path)
	bind_material()

func bind_material() -> void:
	if not source.problem.is_empty() or source.powder_record.is_empty(): return
	var record: Dictionary=source.powder_record
	var by_name: Dictionary=world.loot_catalog.get("by_name",{})
	# This adapter registers the immutable item definition, never ownership.
	if by_name.has(record.name) and by_name[record.name].get("sourceId")!=record.sourceId: return
	if not by_name.has(record.name): by_name[record.name]=record.duplicate(true)
	world.loot_catalog["by_name"]=by_name
	if world.get("catalog_db") is Dictionary:
		var entries: Array=world.catalog_db.get("아이템",[])
		var exists:=false
		for entry: Dictionary in entries:
			if entry.get("sourceId")==record.sourceId: exists=true; break
		if not exists: entries.append(record.duplicate(true))
		if world.has_method("_index_catalog_item_sources"): world._index_catalog_item_sources()

func powder_drop(native_id: int, native_row: Dictionary, draw: float) -> Dictionary:
	if source.problem!="" or not source.powder_npcs.has(native_id): return {}
	var expected: Dictionary=source.powder_npcs[native_id]
	for key: String in expected:
		if native_row.get(key)!=expected[key]: return {}
	if bool(expected.TestNPC) or draw>=clampf(float(policy.get("powder_drop_percent",10.0)),0.0,100.0)/100.0: return {}
	return {"item_name":str(source.powder_record.name),"quantity":1,"item_record":source.powder_record.duplicate(true)}

func now() -> int:
	return int(clock.call()) if clock.is_valid() else int(Time.get_unix_time_from_system())

func day(at: int) -> int:
	# 20:00 UTC = 05:00 Korea time, the same daily boundary as the rest of the game.
	return int(floor(float(at-int(policy.get("reset_hour_utc",20))*3600)/86400.0))

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= low and value <= high

func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != 1: return "작위 저장 버전 오류"
	for key: String in ["revision","day","attempts","last_clock"]:
		if not integer(value.get(key),0,9007199254740991): return "작위 저장 숫자 오류"
	if not value.get("display") is bool or not value.get("active") is Dictionary or not value.get("last_result") is Dictionary or not value.get("achieved") is Array: return "작위 저장 구조 오류"
	if not value.get("rng") is String or not value.rng.is_valid_int(): return "작위 RNG 저장 오류"
	if str(int(value.rng)) != value.rng: return "작위 RNG 범위 오류"
	if value.achieved.size() > 25: return "작위 단계 수 오류"
	if not value.achieved.is_empty() or not value.active.is_empty():
		if not source.problem.is_empty(): return "작위 진행 원본 팩 누락 · 저장 보존"
	for i: int in value.achieved.size():
		if not integer(value.achieved[i],1,1000000) or int(value.achieved[i]) != int(source.stages[i].id): return "작위 순서 오류"
	if value.display and value.achieved.is_empty(): return "미달성 작위 호칭 오류"
	if not value.active.is_empty():
		var a: Dictionary = value.active
		if value.achieved.size() == 25 or not integer(a.get("quest"),1,1000000) or not source.quests.has(int(a.quest)): return "심사 목표 오류"
		var q: Dictionary = source.quests[int(a.quest)]
		if int(q.stage) != int(source.stages[value.achieved.size()].id): return "심사 선행 단계 오류"
		if not integer(a.get("count"),0,int(q.amount)) or not integer(a.get("started"),1,9007199254654591) or not integer(a.get("expires"),1,9007199254740991) or int(a.expires)-int(a.started)!=int(q.limit_seconds): return "심사 진행 값 오류"
		if int(a.started)>int(value.last_clock) or not a.get("last_event","") is String: return "심사 시간 오류"
	return personal.validate(value)

func check_load(data: Dictionary) -> String:
	return validate(data.get("title523",fresh()))

func restore(data: Dictionary) -> void:
	state = data.get("title523",fresh()).duplicate(true)
	if not data.has("title523"):
		var rng:=RandomNumberGenerator.new(); rng.randomize(); state.rng=str(rng.state)
	for i: int in state.achieved.size(): state.achieved[i] = int(state.achieved[i])
	if not state.has("personal"): state.personal=Personal.fresh()
	blocked = false

func next_stage() -> Dictionary:
	return {} if state.achieved.size() >= source.stages.size() else source.stages[state.achieved.size()]

func current_name() -> String:
	return "미달성" if state.achieved.is_empty() or source.stages.is_empty() else str(source.stages[state.achieved.size()-1].name)

func display_name() -> String:
	return personal.display_name() if bool(state.display) else ""

func totals() -> Dictionary:
	var result: Dictionary = {}
	var main_seen: Dictionary = {}
	if not source.problem.is_empty(): return result
	for i: int in state.achieved.size():
		var stage: Dictionary = source.stages[i]
		var ids: Array = stage.sub_effects.duplicate()
		if not main_seen.has(stage.main): ids.append_array(stage.main_effects); main_seen[stage.main]=true
		for id: int in ids:
			var effect: Dictionary = source.effects[id]
			result[effect.type] = float(result.get(effect.type,0.0)) + float(effect.value)
	return result

func bonus(kind: String) -> float:
	return float(totals().get(kind,0.0))

func effect_label(kind: String) -> String:
	for effect: Dictionary in source.effects.values():
		if effect.type==kind: return str(effect.label)
	return kind

func pve_reduction() -> int:
	return int(bonus("PVPDamageReduction")) if policy.get("pvp_bonus_in_pve",false) else 0

func pve_pierce() -> int:
	return int(bonus("PiercePVPDamageReduction")) if policy.get("pvp_bonus_in_pve",false) else 0

func incoming(damage: int, kind: String, draw: float) -> int:
	if not policy.get("weapon_block_enabled",false) or kind not in ["melee","ranged"] or draw>=clampf(bonus("WeaponBlock")/100.0,0.0,1.0): return damage
	# Source specifies chance. Full-hit scope and scale are explicit host policy,
	# since native weapon-component damage is not available in this engine.
	return maxi(1,int(round(damage*clampf(float(policy.get("weapon_block_remaining_damage_scale",0.5)),0.0,1.0))))

func outgoing(damage: int, draw: float) -> int:
	if not policy.get("final_blow_enabled",false) or draw>=clampf(bonus("FinalBlowProbability")/100.0,0.0,1.0): return damage
	var scale:=clampf(float(policy.get("final_blow_base_multiplier",2.0)),1.0,10.0)+bonus("FinalBlowAdditionalScale")/100.0
	return maxi(1,int(round(damage*scale)))

func gate(expected_revision: int) -> String:
	if busy or blocked: return "작위 저장 보호 중"
	if not source.problem.is_empty(): return source.problem
	if not integer(policy.get("donation_denominator"),1500000,2147483647) or not integer(policy.get("reset_hour_utc"),0,23): return "작위 자체 정책 설정 오류"
	if not (policy.get("quest_success_percent") is float or policy.get("quest_success_percent") is int) or not is_finite(float(policy.quest_success_percent)) or float(policy.quest_success_percent)<0 or float(policy.quest_success_percent)>100: return "일반 심사 자체 확률 오류"
	if not validate(state).is_empty(): return "작위 상태 오류"
	if expected_revision != int(state.revision): return "작위 정보가 변경되었습니다. 다시 확인해 주세요."
	if now()<int(state.last_clock): return "시계가 이전으로 이동했습니다. 원래 시각 이후 재시도해 주세요."
	if int(world.level)<source.minimum_level: return "작위 심사는 85레벨부터 가능합니다."
	if next_stage().is_empty(): return "최고 작위 달성"
	return ""

func commit(candidate: Dictionary, inventory: Variant = null) -> Dictionary:
	if busy: return {"ok":false,"message":"작위 처리 중"}
	busy=true
	candidate.revision=int(state.revision)+1
	candidate.last_clock=now()
	var overrides := {"title523":candidate}
	if inventory!=null: overrides.inventory=inventory
	var problem := validate(candidate)
	var saved: Error = ERR_INVALID_DATA if not problem.is_empty() else world._save_game(true,overrides)
	if saved!=OK:
		busy=false; return {"ok":false,"message":"작위 저장 실패 · 재료와 이전 상태 보존"}
	state=candidate
	if inventory!=null: world.inventory=inventory
	busy=false
	world._update_hud()
	return {"ok":true,"message":"작위 상태 저장 완료"}

func start_trial(quest_id: int, revision: int) -> Dictionary:
	var error := gate(revision)
	if not error.is_empty(): return {"ok":false,"message":error}
	if not source.quests.has(quest_id) or int(source.quests[quest_id].stage)!=int(next_stage().id): return {"ok":false,"message":"현재 심사 후보가 아닙니다."}
	error=trial_access(quest_id,now())
	if not error.is_empty(): return {"ok":false,"message":error}
	if not state.active.is_empty() and now()<int(state.active.expires): return {"ok":false,"message":"진행 중인 심사가 있습니다."}
	var q: Dictionary=source.quests[quest_id]
	var candidate:=state.duplicate(true)
	candidate.active={"quest":quest_id,"count":0,"started":now(),"expires":now()+int(q.limit_seconds),"last_event":""}
	return commit(candidate)

func abandon(revision: int) -> Dictionary:
	var error := gate(revision)
	if not error.is_empty(): return {"ok":false,"message":error}
	var candidate:=state.duplicate(true); candidate.active={}
	return commit(candidate)

func record_last_hit(npc_id: int, token: String, direct_player: bool, native_row: Dictionary = {}) -> bool:
	if blocked or busy or not direct_player or token.is_empty() or state.active.is_empty() or not source.problem.is_empty(): return false
	token=session_nonce+":"+token
	if now()<int(state.last_clock) or now()>=int(state.active.expires) or int(world.level)<source.minimum_level: return false
	var q: Dictionary=source.quests[int(state.active.quest)]
	if not trial_access(int(q.id),now()).is_empty(): return false
	if not q.targets.has(npc_id) or token==str(state.active.last_event) or int(state.active.count)>=int(q.amount): return false
	for key: String in source.trial_npcs[npc_id]:
		if native_row.get(key)!=source.trial_npcs[npc_id][key]: return false
	state.active.count=int(state.active.count)+1
	state.revision=int(state.revision)+1
	state.active.last_event=token
	state.last_clock=now()
	world._request_deferred_save()
	return true

func powder_keys() -> Array[String]:
	var result: Array[String]=[]
	for key: String in world.inventory:
		if int(world.inventory[key])<=0 or world.item_instances.has(key) or world._item_locked(key): continue
		var record: Dictionary=world.loot_catalog.get("by_name",{}).get(key,{})
		# A same-name unknown stack is not evidence of native material ownership.
		if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or record.get("source_m_native_item")!=true: continue
		if int(record.get("source_item_class_id",-1))!=117544 or str(record.get("sourceId",""))!="m523:item:117544": continue
		if record.get("source_category_name")!="StackableItem" or record.get("source_display_name")!="상급 축복의 가루" or record.get("name")!="상급 축복의 가루 · 원본#117544": continue
		if int(record.get("source_bless_raw",1))!=1 or record.get("source_test_item",false): continue
		result.append(key)
	result.sort()
	return result

func powder_count() -> int:
	var result:=0
	for key: String in powder_keys(): result+=int(world.inventory[key])
	return result

func can_pickup(record: Dictionary) -> bool:
	var key: String="상급 축복의 가루 · 원본#117544"
	if record.get("item_name")!=key: return true
	if not source.problem.is_empty() or source.powder_record.is_empty(): return false
	var amount: Variant=record.get("quantity")
	var limit:=int(source.powder_record.source_item_row.MaxStackAmount)
	return integer(amount,1,limit) and int(world.inventory.get(key,0))+int(amount)<=limit

func review(route: String, revision: int) -> Dictionary:
	var error := gate(revision)
	if not error.is_empty(): return {"ok":false,"message":error}
	var stage:=next_stage()
	if route=="donation":
		if powder_count()<int(stage.cost): return {"ok":false,"message":"원본#117544 상급 축복의 가루 부족 또는 미확인 소지 키"}
		return {"ok":true,"message":"%s 기부 심사\n상급 축복의 가루 %d개 소비\n실패해도 재료가 소비됩니다.\n성공률 %.1f%% (TWILIGHT 자체 해석)\n일일 일반 심사 횟수는 소비하지 않습니다."%[stage.name,stage.cost,float(stage.probability_raw)*100.0/float(policy.donation_denominator)]}
	if route!="quest": return {"ok":false,"message":"알 수 없는 심사 경로"}
	if state.active.is_empty() or now()>=int(state.active.expires): return {"ok":false,"message":"24시간 내 선택 목표를 완료해 주세요."}
	var q: Dictionary=source.quests[int(state.active.quest)]
	error=trial_access(int(q.id),now())
	if not error.is_empty(): return {"ok":false,"message":error}
	if int(state.active.count)<int(q.amount): return {"ok":false,"message":"직접 막타 목표 미달성"}
	var used:=int(state.attempts) if int(state.day)==day(now()) else 0
	if used>=source.daily_limit: return {"ok":false,"message":"오늘 일반 심사 10회를 모두 사용했습니다."}
	return {"ok":true,"message":"%s 일반 심사\n완료한 목표 자격과 오늘 심사 1회를 소비합니다.\n원본 확률 미확정 · 자체 성공률 %.1f%%\n기부 재료는 소비하지 않습니다."%[stage.name,float(policy.quest_success_percent)]}

func attempt(route: String, revision: int) -> Dictionary:
	var checked:=review(route,revision)
	if not checked.ok: return checked
	var stage:=next_stage()
	var candidate:=state.duplicate(true)
	var next_inventory: Dictionary=world.inventory.duplicate(true)
	var rng:=RandomNumberGenerator.new(); rng.state=int(state.rng)
	var success:=false
	if route=="donation":
		var remaining:=int(stage.cost)
		for key: String in powder_keys():
			var take:=mini(remaining,int(next_inventory[key]))
			next_inventory[key]=int(next_inventory[key])-take; remaining-=take
			if int(next_inventory[key])==0: next_inventory.erase(key)
			if remaining==0: break
		if remaining!=0: return {"ok":false,"message":"기부 재료가 변경되었습니다."}
		success=rng.randi_range(0,int(policy.donation_denominator)-1)<int(stage.probability_raw)
	else:
		candidate.day=day(now()); candidate.attempts=(int(state.attempts) if int(state.day)==day(now()) else 0)+1
		candidate.active={}
		success=rng.randf()*100.0<float(policy.quest_success_percent)
	candidate.rng=str(rng.state)
	if success: candidate.achieved.append(int(stage.id)); candidate.active={}
	candidate.last_result={"route":route,"stage":int(stage.id),"success":success,"cost":int(stage.cost) if route=="donation" else 0}
	var result:=commit(candidate,next_inventory if route=="donation" else null)
	if result.ok: result.message=source.result_text(int(stage.id),success,int(state.revision))
	return result

func toggle_display(revision: int) -> Dictionary:
	if blocked or busy or revision!=int(state.revision) or state.achieved.is_empty() or now()<int(state.last_clock): return {"ok":false,"message":"작위 호칭 변경 불가"}
	var candidate:=state.duplicate(true); candidate.display=not bool(state.display)
	return commit(candidate)

func calendar_second(row: Dictionary) -> int:
	var fields: Dictionary={"year":int(row.Year),"month":int(row.Month),"day":int(row.Day),"hour":int(row.Hour),"minute":int(row.Minute),"second":0}
	return Time.get_unix_time_from_datetime_dict(fields)-int(policy.get("source_calendar_utc_offset_seconds",32400))

func trial_access(quest_id: int, at: int) -> String:
	if not source.quests.has(quest_id): return "원본 심사 목표 누락"
	if not integer(policy.get("source_calendar_utc_offset_seconds"),-50400,50400): return "원본 일정 자체 시간대 설정 오류"
	var q: Dictionary=source.quests[quest_id]
	# Source precision is one minute; host policy keeps the final minute inclusive.
	if at<calendar_second(q.calendar_start) or at>=calendar_second(q.calendar_end)+60: return "원본 심사 개방 기간 밖입니다."
	if int(q.server_limit_set)!=0:
		for member: Dictionary in q.server_memberships:
			if str(member.ServiceRegionCode)==str(policy.get("offline_source_service_region","")) and int(member.WorldNo)==int(policy.get("offline_source_world_no",-1)): return ""
		return "원본 서버 제한 집합%d에 자체 오프라인 월드가 속하지 않습니다."%int(q.server_limit_set)
	return ""
