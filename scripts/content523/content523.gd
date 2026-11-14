extends RefCounted
## 523 에스카로스 · 요정 숲 방어전 · 영지 퀘스트 — offline single-player run.
## Table models: escaros523.gd, elfforest523.gd, territory_quest523.gd. This
## layer owns the save key, entry payments, original Land travel and the
## progress the tables define; each own choice is named here and listed in
## docs/escaros_elfforest_territory523_missing_rules.md.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const ESCAROS = preload("res://scripts/content523/escaros523.gd")
const ELF = preload("res://scripts/content523/elfforest523.gd")
const TQUEST = preload("res://scripts/content523/territory_quest523.gd")
const CLOCK = preload("res://scripts/quests/quest_service.gd")
const SAVE_KEY := "content523"
const SCHEMA := 1
const MAX_BLESSING := 999999
## Own: a landmark is examined from the existing town-NPC talk distance
## (source523_town_npcs INTERACT_DISTANCE); EscarosLandmark has no range.
const LANDMARK_DISTANCE := 190.0
## In-Land rules that do not gate a content teleport into the Land: the
## existing Orim list, the contest's own CompetitionDungeonLand row, the
## server/client session attributes with no offline meaning (socket timeout,
## idle kick, lazy object load, clan call) and the multiplayer-only ones
## (party/clan/name masking, player item drop on death, pickup selector).
## In-Land spell/buff bans (NoSpell, NoBuffGroup, NoSpellToOther) are not
## entry gates either; like the Orim NoTeleport they are not enforced inside
## (no owner). BlockLoginEnter is a login rule. The existing field re-checks
## the entry conditions of the current Land while playing (e.g. after a level
## up) with the saved-position waive, so it is waived there too: a level up or
## a load inside the Land keeps the player there (own; noted in the doc).
const LAND_RULES := ["NoTeleport","TurnOffAutoForTeleport","NoPurplePushOnDie","NpcBuff","NoTeleportCome","CompetitionDungeonLand",
	"LandPlayerSocketTimeoutSecond","IdleTime","ObjectLazyLoad","UsableCallClan","NoParty","NoBloodPledgeTarget","NameMasking",
	"PlayerItemDrop","PlayerItemDropMinPercent","PlayerItemDropMaxPercent","PlayerItemDropHUDMinAmount","PlayerOwnItemDropOnDie",
	"NoPickupSelector","NoHellVirtuePoint","NoSpell","NoBuffGroup","NoSpellToOther"]
const ENTRY_WAIVE := LAND_RULES+["BlockLoginEnter"]
const REOPEN_WAIVE := ENTRY_WAIVE

## User decision 2026-11-13: EscarosArtifact.BuffDuration is minutes (15 = 15 min).
const ARTIFACT_BUFF_MINUTES_PER_UNIT := 1
const BUFF_SECONDS_MAX := 86400
## Buff keys the existing consumers read (world._active_item_buff_total), the
## same BonusType mapping as clan523 PERCENT_FIELDS.
const BUFF_FIELDS := {"ExperienceAdditionPercent":"xp"}

static var _cache: Dictionary = {}

var state: Dictionary = empty_state()
var problem: String = ""
var now_override: int = -1
var world: Object
var _zone_id: int = -1
var _artifact_since: Dictionary = {}
var _artifact_ready_ms: Dictionary = {}
var _tick_clock: float = 0.0
var last_note: String = ""

static func empty_state() -> Dictionary:
	return {"schema":SCHEMA,"escaros":{"period":-1,"found":[],"touchdowns":{},"buffs":{}},"elf":{"blessing":0,"entries":0,"wins":0,"run":{},"claimed":[]},"tq":{"active":{},"done":{},"failed":{}}}

## --- Models -------------------------------------------------------------------

static func models() -> Dictionary:
	var sha: String = str(SOURCE.identity().get("source_sha256",""))
	if _cache.get("sha","")==sha and _cache.has("data"): return _cache.data
	var data: Dictionary
	if sha.is_empty():
		var none: Dictionary = {"ok":false,"problem":"원본 523 정의 ZIP 미설치"}
		data = {"escaros":none,"elf":none,"tq":none}
	else:
		# Building reads and indexes large original tables (DescData_Korean,
		# Territories, StatusEffectAttr, ItemClass ...): the phone recorded a
		# 6.1 s "던전" frame on the first content tick. The result is stored
		# per original + builder code, so later starts read it back instead.
		var key: String = models_bake_key(sha)
		var baked: Variant = BAKE.read(MODELS_BAKE, key)
		if baked is Dictionary and baked.has("escaros") and baked.has("elf") and baked.has("tq"):
			data = baked
		else:
			data = {"escaros":ESCAROS.build(SOURCE),"elf":ELF.build(SOURCE),"tq":TQUEST.build(SOURCE)}
			BAKE.write(MODELS_BAKE, key, data)
	_cache = {"sha":sha,"data":data}
	return data

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const MODELS_BAKE := "content523_models"
const MODELS_FORMAT := "twilight.content523.models.v1"
const MODEL_CODE := ["res://scripts/content523/content523.gd","res://scripts/content523/escaros523.gd",
	"res://scripts/content523/elfforest523.gd","res://scripts/content523/territory_quest523.gd"]

static func models_bake_key(sha: String) -> String:
	return BAKE.key([MODELS_FORMAT, sha, SOURCE.STORE_FORMAT, BAKE.code_key(MODEL_CODE), BAKE.engine_key()])

static func release() -> void:
	_cache.clear(); _lands.clear()

## Lands of these contents (for keeping a saved position inside one).
static var _lands: Dictionary = {}
static func content_land_ids() -> Dictionary:
	var ids: Dictionary = {}
	if SOURCE.not_installed(): return ids
	var sha: String = str(SOURCE.identity().get("source_sha256",""))
	if _lands.get("sha","")==sha and _lands.has("ids"): return _lands.ids
	var m: Dictionary = models()
	for land: Dictionary in m.escaros.get("lands",[]): ids[int(land.id)] = true
	for grade: Dictionary in m.elf.get("grades",[]): ids[int(grade.route.get("land_id",0))] = true
	for id: int in m.tq.get("quests",{}):
		if m.tq.quests[id].playable: ids[int(m.tq.quests[id].land_id)] = true
	ids.erase(0)
	_lands = {"sha":sha,"ids":ids}
	return ids

## --- Save --------------------------------------------------------------------

static func _whole(value: Variant, low: int = 0) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=float(low)

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "콘텐츠 저장 형식 오류"
	if value.is_empty(): return ""
	if not _whole(value.get("schema")) or int(value.schema)!=SCHEMA: return "콘텐츠 저장 버전 오류"
	for key: String in ["escaros","elf","tq"]:
		if not value.get(key) is Dictionary: return "콘텐츠 저장 값 오류: "+key
	var e: Dictionary = value.escaros
	if not typeof(e.get("period")) in [TYPE_INT,TYPE_FLOAT] or not e.get("found") is Array or e.found.size()>64 or not e.get("touchdowns") is Dictionary or e.touchdowns.size()>64: return "에스카로스 저장 값 오류"
	for id: Variant in e.found:
		if not _whole(id,1): return "에스카로스 랜드마크 기록 오류"
	for key: Variant in e.touchdowns:
		if not key is String or not key.is_valid_int() or not _whole(e.touchdowns[key]): return "에스카로스 터치다운 기록 오류"
	var buffs: Variant = e.get("buffs",{})
	if not buffs is Dictionary or buffs.size()>16: return "에스카로스 버프 기록 오류"
	for key: Variant in buffs:
		if not key is String or not key.is_valid_int() or not typeof(buffs[key]) in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(buffs[key])) or float(buffs[key])<0.0 or float(buffs[key])>float(BUFF_SECONDS_MAX): return "에스카로스 버프 기록 오류"
	var f: Dictionary = value.elf
	if not _whole(f.get("blessing")) or not _whole(f.get("entries")): return "요정 숲 저장 값 오류"
	if not _whole(f.get("wins",0)) or int(f.get("wins",0))>100000 or not f.get("run",{}) is Dictionary or not f.get("claimed",[]) is Array or f.get("claimed",[]).size()>64: return "요정 숲 승리 기록 오류"
	for no: Variant in f.get("claimed",[]):
		if not _whole(no,1): return "요정 숲 보상 기록 오류"
	var run: Dictionary = f.get("run",{})
	if not run.is_empty():
		for key: String in ["grade","land","target","kills"]:
			if not _whole(run.get(key)): return "요정 숲 진행 기록 오류"
		if run.has("alive") and not _whole(run.alive): return "요정 숲 진행 기록 오류"
	var q: Dictionary = value.tq
	if not q.get("active") is Dictionary or not q.get("done") is Dictionary or not q.get("failed") is Dictionary or q.done.size()>256 or q.failed.size()>256: return "영지 퀘스트 저장 값 오류"
	if not q.active.is_empty():
		for key: String in ["quest","started","deadline","count"]:
			if not _whole(q.active.get(key)): return "영지 퀘스트 진행 기록 오류"
	for table: Dictionary in [q.done,q.failed]:
		for key: Variant in table:
			if not key is String or not key.is_valid_int() or not typeof(table[key]) in [TYPE_INT,TYPE_FLOAT]: return "영지 퀘스트 완료 기록 오류"
	return ""

func export_state() -> Dictionary:
	return state.duplicate(true)

func import_state(value: Variant) -> void:
	problem = ""
	state = empty_state()
	_zone_id = -1; _artifact_since.clear()
	var invalid: String = validate(value)
	if not invalid.is_empty(): problem = invalid; return
	if (value as Dictionary).is_empty(): return
	state = (value as Dictionary).duplicate(true)
	# JSON loads numbers as floats.
	state.schema = int(state.schema)
	state.escaros.period = int(state.escaros.period)
	state.escaros.found = state.escaros.found.map(func(id: Variant)->int: return int(id))
	for key: String in state.escaros.touchdowns: state.escaros.touchdowns[key] = int(state.escaros.touchdowns[key])
	state.elf.blessing = int(state.elf.blessing); state.elf.entries = int(state.elf.entries)
	# Saves from before the 2026-11-13 decisions have no buff/win fields.
	if not state.escaros.has("buffs"): state.escaros.buffs = {}
	for key: String in state.escaros.buffs: state.escaros.buffs[key] = float(state.escaros.buffs[key])
	state.elf.wins = int(state.elf.get("wins",0))
	state.elf.claimed = (state.elf.get("claimed",[]) as Array).map(func(no: Variant)->int: return int(no))
	var run: Dictionary = state.elf.get("run",{})
	for key: String in run: run[key] = int(run[key])
	state.elf.run = run
	for key: String in ["quest","started","deadline","count"]:
		if state.tq.active.has(key): state.tq.active[key] = int(state.tq.active[key])
	for table: String in ["done","failed"]:
		for key: String in state.tq[table]: state.tq[table][key] = int(state.tq[table][key])

func configure(owner: Object) -> void:
	world = owner
	# Prepare the content tables while the loading screen is up, not on the
	# first in-game tick.
	if owner != null: models()

func now() -> int:
	return now_override if now_override>=0 else int(Time.get_unix_time_from_system())

func period(at: int = -1) -> int:
	return CLOCK.korean_daily_key(now() if at<0 else at)

## Saves `next` with the given world overrides, or keeps the old state.
func _commit(next: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	if not problem.is_empty(): return {"ok":false,"reason":"콘텐츠 저장을 읽지 못해 진행을 막았습니다: "+problem}
	var previous: Dictionary = state.duplicate(true)
	state = next
	var saved: bool = true
	if world!=null and world.has_method("_save_game"): saved = world.call("_save_game",true,overrides)==OK
	if not saved:
		state = previous
		return {"ok":false,"reason":"저장 실패 · 이전 상태 유지"}
	if world!=null:
		for key: String in ["gold","inventory","item_instances"]:
			if overrides.has(key): world.set(key,overrides[key])
		if overrides.has("ainhasad_state"): world.ain_service.import_state(overrides.ainhasad_state)
		var hud: Variant = world.get("hud")
		if hud!=null and is_instance_valid(hud) and hud.has_method("refresh_inventory") and (overrides.has("inventory") or overrides.has("gold")): hud.refresh_inventory(world.inventory)
		if world.has_method("_update_hud"): world.call("_update_hud")
	return {"ok":true}

## --- Position ----------------------------------------------------------------

func here() -> Dictionary:
	if world==null or not world.has_method("orim_current_land"): return {}
	return world.call("orim_current_land")

func _world_point(cell: Array) -> Vector2:
	if world==null or not world.has_method("content523_cell_point"): return Vector2.INF
	return world.call("content523_cell_point",Vector2i(int(cell[0]),int(cell[1])))

## --- Entry -------------------------------------------------------------------

func _route_check(route: Dictionary) -> String:
	if route.is_empty() or int(route.get("land_id",0))==0: return "원본 이동(LandTeleport) 행이 없습니다"
	if int(route.get("targets",1))!=1: return "원본 이동 목적지가 하나가 아닙니다"
	if not (route.get("other_prerequisites",[]) as Array).is_empty(): return "원본 이동 조건 %s 확인 불가" % str(route.other_prerequisites)
	var level: int = int(world.get("level")) if world!=null else 0
	if level<int(route.min_level): return "%d레벨부터 이동할 수 있습니다" % int(route.min_level)
	if int(route.max_level)>0 and level>int(route.max_level): return "%d레벨까지만 이동할 수 있습니다" % int(route.max_level)
	if int(route.currency)!=1 and int(route.cost)>0: return "이동 재화 %d는 아데나가 아닙니다" % int(route.currency)
	if world!=null and int(world.get("gold"))<int(route.cost): return "아데나 부족 (%d 필요)" % int(route.cost)
	return ""

## Own landing search inside a large Territory box (a whole round area is
## hundreds of cells wide and the existing first-clear-cell search has a
## budget): windows of LANDING_WINDOW cells around its centre, growing, and
## the whole box last. Every window lies inside the original box.
const LANDING_WINDOW := 8
static func landing_windows(box: Array) -> Array:
	var b: Array = box.map(func(v: Variant)->int: return int(v))
	var out: Array = []
	var cx: int = (b[0]+b[2])/2; var cy: int = (b[1]+b[3])/2
	var r: int = LANDING_WINDOW
	while cx-r>b[0] or cy-r>b[1] or cx+r<b[2] or cy+r<b[3]:
		out.append([maxi(b[0],cx-r),maxi(b[1],cy-r),mini(b[2],cx+r),mini(b[3],cy+r)])
		r *= 2
		if out.size()>=4: break
	out.append(b)
	return out

## Original LandTeleport: level/adena check, travel to its Territory box,
## then the adena fee (charged only after the move succeeded).
func travel(route: Dictionary, waive: Array = ENTRY_WAIVE) -> Dictionary:
	var reason: String = _route_check(route)
	if not reason.is_empty(): return {"ok":false,"reason":reason}
	if not world.has_method("content523_enter_land"): return {"ok":false,"reason":"원본 지도 이동 연결 없음"}
	var moved: Dictionary = {}
	for bounds: Array in landing_windows(route.box):
		moved = world.call("content523_enter_land",int(route.land_id),bounds,waive)
		if moved.get("ok",false) or not str(moved.get("reason","")).contains("도착 셀 없음"): break
	if not moved.get("ok",false): return {"ok":false,"reason":"원본 지도 이동 실패: "+str(moved.get("reason",""))}
	_zone_id = -1; _artifact_since.clear()
	if int(route.cost)<=0: return {"ok":true,"land_id":int(route.land_id),"cost":0}
	var paid: Dictionary = _commit(state.duplicate(true),{"gold":int(world.get("gold"))-int(route.cost)})
	if not paid.get("ok",false): return {"ok":false,"reason":"이동 후 비용 저장 실패: "+str(paid.reason)}
	return {"ok":true,"land_id":int(route.land_id),"cost":int(route.cost)}

func enter_escaros() -> Dictionary:
	var model: Dictionary = models().escaros
	if not model.get("ok",false): return {"ok":false,"reason":str(model.get("problem",""))}
	var result: Dictionary = travel(model.dungeon.teleport)
	if result.get("ok",false): last_note = "에스카로스 입장 · %s" % str(model.dungeon.teleport.land_name)
	return result

## A village/field teleporter (EarthObjectSpawn with a LandTeleportID unit):
## used from within its EarthObjectAttribute Range (cells) of its cell.
func use_teleporter(spawn_id: int) -> Dictionary:
	var model: Dictionary = models().escaros
	for teleporter: Dictionary in model.get("teleporters",[]):
		if int(teleporter.spawn_id)!=spawn_id: continue
		var at: Dictionary = here()
		if at.is_empty() or int(at.land_id)!=int(teleporter.land_id): return {"ok":false,"reason":"이 텔레포터가 있는 지역이 아닙니다"}
		var reach: int = int(teleporter.get("range",0))
		if reach<=0 or ESCAROS.cell_distance(at.cell,teleporter.cell)>reach: return {"ok":false,"reason":"%s에 더 가까이 가세요 (%d칸 이내)" % [str(teleporter.name),reach]}
		var result: Dictionary = travel(teleporter.route)
		if result.get("ok",false): last_note = "%s → %s" % [str(teleporter.name),str(teleporter.route.land_name)]
		return result
	return {"ok":false,"reason":"원본 텔레포터 없음"}

## --- Escaros: landmarks, zones, touchdowns ------------------------------------

func _escaros_rolled() -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var day: int = period()
	if int(next.escaros.period)!=day:
		next.escaros.period = day; next.escaros.found = []
	return next

func landmarks_view() -> Array:
	var model: Dictionary = models().escaros
	if not model.get("ok",false): return []
	var rolled: Dictionary = _escaros_rolled()
	var at: Dictionary = here()
	var out: Array = []
	for id: int in ESCAROS.active_landmarks(model,period()):
		var landmark: Dictionary = model.landmarks[id]
		var near: bool = false
		if not at.is_empty() and int(at.land_id)==int(landmark.land_id) and world!=null and world.get("player")!=null:
			var point: Vector2 = _world_point(landmark.cell)
			near = point.is_finite() and world.player.global_position.distance_to(point)<=LANDMARK_DISTANCE
		out.append({"id":id,"name":str(landmark.name),"group":str(landmark.group_name),"cell":landmark.cell,"land_id":int(landmark.land_id),
			"found":id in rolled.escaros.found,"near":near,"reward":landmark.reward,"distance":ESCAROS.cell_distance(at.cell,landmark.cell) if not at.is_empty() and int(at.land_id)==int(landmark.land_id) else -1})
	return out

## Examining a shown landmark pays its Reward once per period (own period:
## the daily key). Reward type Einasad adds Amount to the 아인하사드 blessing
## (the routine523 mission rule); an Item reward goes through the 523 supplier.
func examine_landmark(id: int) -> Dictionary:
	var model: Dictionary = models().escaros
	var row: Dictionary = {}
	for view: Dictionary in landmarks_view():
		if int(view.id)==id: row = view
	if row.is_empty(): return {"ok":false,"reason":"오늘 나타난 랜드마크가 아닙니다"}
	if bool(row.found): return {"ok":false,"reason":"오늘 이미 조사한 랜드마크입니다"}
	if not bool(row.near): return {"ok":false,"reason":"%s에 더 가까이 가세요" % str(row.name)}
	var reward: Dictionary = model.landmarks[id].reward
	var next: Dictionary = _escaros_rolled()
	next.escaros.found.append(id)
	var overrides: Dictionary = {}
	var note: String = ""
	if str(reward.type)=="Einasad" and int(reward.amount)>0:
		var ain: Dictionary = world.ain_service.export_state().duplicate(true)
		ain.blessing = mini(MAX_BLESSING,int(ain.get("blessing",0))+int(reward.amount))
		overrides["ainhasad_state"] = ain
		note = "아인하사드 +%d" % int(reward.amount)
	elif str(reward.type)=="Item" and int(reward.amount)>0:
		var staged: Dictionary = _stage_items([reward])
		if not staged.get("ok",false): return staged
		overrides.merge(staged.overrides,true); note = ", ".join(staged.granted)
	else: return {"ok":false,"reason":"보상 종류 %s의 지급 규칙이 없습니다" % str(reward.type)}
	var result: Dictionary = _commit(next,overrides)
	if result.get("ok",false): result["reward"] = note; last_note = "%s 조사 · %s" % [str(row.name),note]
	return result

func touchdowns() -> Dictionary:
	return state.escaros.touchdowns.duplicate()

## Touchdown (GoalType EscarosTouchDown): standing within ActivationRange
## cells of an artifact for TouchdownDelaySec, at most once per
## ArtifactUseCoolTime (ms). The artifact's BuffClass is applied for
## BuffDuration minutes (user decision 2026-11-13); a new touchdown of the same
## artifact restarts it. The round schedule and the ranking are not in the
## tables (all artifacts always usable, no rank reward).
func _artifact_tick(at: Dictionary) -> void:
	var model: Dictionary = models().escaros
	var cooldown: int = int(model.constants.get("ArtifactUseCoolTime",0))
	var clock: int = Time.get_ticks_msec()
	for artifact: Dictionary in model.artifacts:
		var key: String = str(int(artifact.id))
		var inside: bool = int(at.land_id)==int(artifact.land_id) and ESCAROS.cell_distance(at.cell,artifact.cell)<=int(artifact.range)
		if not inside: _artifact_since.erase(key); continue
		if not _artifact_since.has(key): _artifact_since[key] = clock
		if clock-int(_artifact_since[key])<int(artifact.touchdown_delay_sec)*1000 or clock<int(_artifact_ready_ms.get(key,0)): continue
		_artifact_ready_ms[key] = clock+maxi(1000,cooldown)
		_artifact_since[key] = clock+maxi(1000,cooldown)
		state.escaros.touchdowns[key] = int(state.escaros.touchdowns.get(key,0))+1
		var seconds: int = int(artifact.buff_duration_raw)*60*ARTIFACT_BUFF_MINUTES_PER_UNIT
		if int(artifact.buff_id)>0 and seconds>0: state.escaros.buffs[str(int(artifact.buff_id))] = float(seconds)
		last_note = "터치다운 · %s (%d회) · %s %d분" % [str(artifact.name),int(state.escaros.touchdowns[key]),str(artifact.buff_name),seconds/60]
		if world!=null and world.has_method("_update_hud"): world.call("_update_hud")
		_show(last_note)

func _zone_tick(at: Dictionary) -> void:
	var zone: Dictionary = ESCAROS.zone_at(models().escaros,int(at.land_id),at.cell)
	var id: int = int(zone.get("id",0))
	if id==_zone_id: return
	_zone_id = id
	if id!=0: _show("%s · %s" % [str(zone.name),str(zone.sub)])

func _show(text: String) -> void:
	var hud: Variant = world.get("hud") if world!=null else null
	if hud!=null and is_instance_valid(hud) and hud.has_method("show_message"): hud.show_message(text)

## --- Elf forest --------------------------------------------------------------

func enter_elf(grade_id: int) -> Dictionary:
	var model: Dictionary = models().elf
	if not model.get("ok",false): return {"ok":false,"reason":str(model.get("problem",""))}
	for grade: Dictionary in open_elf_grades():
		if int(grade.id)!=grade_id: continue
		var result: Dictionary = travel(grade.route)
		if result.get("ok",false):
			var next: Dictionary = state.duplicate(true); next.elf.entries = int(next.elf.entries)+1
			next.elf.run = {"grade":int(grade.id),"land":int(grade.route.land_id),"target":0,"kills":0}
			_commit(next)
			last_note = "요정 숲 방어전 · %s" % str(grade.name)
		return result
	return {"ok":false,"reason":"승리가 더 필요한 단계입니다 (현재 %d승)" % int(state.elf.get("wins",0))}

func choose_blessing(blessing_id: int) -> Dictionary:
	for blessing: Dictionary in models().elf.get("blessings",[]):
		if int(blessing.id)==blessing_id:
			var next: Dictionary = state.duplicate(true); next.elf.blessing = blessing_id
			var result: Dictionary = _commit(next)
			if result.get("ok",false): result["text"] = str(blessing.select_text)
			return result
	return {"ok":false,"reason":"원본 가호 없음"}

## Active artifact buffs: [{buff_id, name, left (s), effects}].
func artifact_buffs() -> Array:
	var out: Array = []
	for artifact: Dictionary in models().escaros.get("artifacts",[]):
		var key: String = str(int(artifact.buff_id))
		if float(state.escaros.get("buffs",{}).get(key,0.0))>0.0:
			out.append({"buff_id":int(artifact.buff_id),"name":str(artifact.buff_name),"left":float(state.escaros.buffs[key]),"effects":artifact.effects})
	return out

## Value of one existing buff key from the active artifact buffs (percent
## effects as whole percent points: Value / UIUnit Denominator).
func buff_value(key: String) -> int:
	if state.escaros.get("buffs",{}).is_empty(): return 0
	var total: float = 0.0
	for buff: Dictionary in artifact_buffs():
		for effect: Dictionary in buff.effects:
			if str(BUFF_FIELDS.get(str(effect.type),""))==key: total += float(effect.percent)
	return int(round(total))

## In-game time: the remaining seconds are saved and continue after a load.
func _buff_tick(elapsed: float) -> void:
	var buffs: Dictionary = state.escaros.get("buffs",{})
	if buffs.is_empty(): return
	for key: String in buffs.keys():
		buffs[key] = maxf(0.0,float(buffs[key])-elapsed)
		if float(buffs[key])<=0.0:
			buffs.erase(key)
			_show("아티팩트 버프 종료")
			if world!=null and world.has_method("_update_hud"): world.call("_update_hud")

## --- Elf forest wins (user decision 2026-11-13) ------------------------------
## A grade is won by killing every monster that appeared on its Land: after
## at least one kill there, the existing population reports no live monster
## on that Land (a monster that appears before the last one falls must be
## killed too). Wins open GradeNo <= wins and the original WinNo rewards
## (ElfForestDefenseRewardGroup -> QuestReward), each once.

func open_elf_grades() -> Array:
	var wins: int = int(state.elf.get("wins",0))
	return models().elf.get("grades",[]).filter(func(grade: Dictionary)->bool: return int(grade.grade_no)<=wins)

func elf_run() -> Dictionary:
	return state.elf.get("run",{}).duplicate()

func record_kill() -> void:
	var run: Dictionary = state.elf.get("run",{})
	if run.is_empty() or int(run.target)<=0: return
	var at: Dictionary = here()
	if at.is_empty() or int(at.land_id)!=int(run.land): return
	run.kills = int(run.kills)+1
	last_note = "요정 숲 방어전 처치 %d" % int(run.kills)

func _elf_win() -> void:
	var next: Dictionary = state.duplicate(true)
	next.elf.wins = int(next.elf.wins)+1; next.elf.run = {}
	if _commit(next).get("ok",false):
		last_note = "요정 숲 방어전 승리 · 누적 %d승" % int(state.elf.wins)
		_show(last_note)

func _elf_tick(at: Dictionary) -> void:
	var run: Dictionary = state.elf.get("run",{})
	if run.is_empty(): return
	if int(at.land_id)!=int(run.land):
		var next: Dictionary = state.duplicate(true); next.elf.run = {}
		if _commit(next).get("ok",false): _show("요정 숲 방어전을 떠나 도전을 마칩니다")
		return
	if world==null or not world.has_method("content523_spawn_metrics"): return
	var metrics: Dictionary = world.call("content523_spawn_metrics")
	if not bool(metrics.get("ok",false)): return
	var alive: int = int(metrics.get("alive",0))
	run["alive"] = alive
	if int(run.target)==0:
		if alive>0:
			run.target = alive
			_show("요정 숲 방어전 · 나타난 몬스터 %d마리를 모두 처치하세요" % alive)
		return
	if int(run.kills)>0 and alive==0: _elf_win()

func elf_rewards() -> Array:
	var out: Array = []
	for win: Dictionary in models().elf.get("wins",[]):
		out.append({"win_no":int(win.win_no),"rewards":win.rewards,"goal":str(win.goals[0].text) if not win.goals.is_empty() else "",
			"reached":int(state.elf.get("wins",0))>=int(win.win_no),"claimed":int(win.win_no) in state.elf.get("claimed",[])})
	return out

func claim_elf_reward(win_no: int) -> Dictionary:
	for row: Dictionary in elf_rewards():
		if int(row.win_no)!=win_no: continue
		if bool(row.claimed): return {"ok":false,"reason":"이미 받은 승리 보상입니다"}
		if not bool(row.reached): return {"ok":false,"reason":"승리 %d회가 필요합니다 (현재 %d회)" % [win_no,int(state.elf.get("wins",0))]}
		# As the Orim rewards: every row the 523 item supplier owns is paid,
		# rows it refuses are named (withheld); nothing payable keeps it open.
		var staged: Dictionary = _stage_items(row.rewards,true)
		if (staged.granted as Array).is_empty(): return {"ok":false,"reason":"지급할 수 있는 보상이 없습니다: "+", ".join(staged.withheld)+" · 보상 보존"}
		var next: Dictionary = state.duplicate(true); next.elf.claimed.append(win_no)
		var result: Dictionary = _commit(next,staged.overrides)
		if result.get("ok",false):
			result["granted"] = staged.granted
			if not (staged.withheld as Array).is_empty(): result["reason"] = "미지급: "+", ".join(staged.withheld)
		return result
	return {"ok":false,"reason":"원본 승리 보상 없음"}

## --- Territory quests --------------------------------------------------------

## ItemCollect progress: original items (Goal.GoalClassID) picked up while
## the quest runs, as the trial tower counts its ItemCollect goals.
func record_pickup(source_item_class_id: int, amount: int) -> void:
	var active: Dictionary = state.tq.active
	if active.is_empty() or source_item_class_id<=0 or amount<=0: return
	var quest: Dictionary = models().tq.quests.get(int(active.quest),{})
	for goal: Dictionary in quest.get("goals",[]):
		if str(goal.type)=="ItemCollect" and int(goal.class_id)==source_item_class_id:
			active.count = mini(int(goal.amount),int(active.count)+amount)
			last_note = "%s %d/%d" % [str(goal.text),int(active.count),int(goal.amount)]

func quest_progress() -> Dictionary:
	var active: Dictionary = state.tq.active
	if active.is_empty(): return {}
	var quest: Dictionary = models().tq.quests.get(int(active.quest),{})
	var need: int = 0
	for goal: Dictionary in quest.get("goals",[]): need = maxi(need,int(goal.amount))
	return {"quest":int(active.quest),"count":int(active.count),"need":need,"left":maxi(0,int(active.deadline)-now()),"done":need>0 and int(active.count)>=need,"area":str(quest.get("area",""))}

func _quest_tick(at: Dictionary) -> void:
	var model: Dictionary = models().tq
	if not model.get("ok",false): return
	var active: Dictionary = state.tq.active
	if not active.is_empty():
		if now()>=int(active.deadline) and not bool(quest_progress().get("done",false)):
			var failed: Dictionary = state.duplicate(true)
			failed.tq.failed[str(int(active.quest))] = period(); failed.tq.active = {}
			if _commit(failed).get("ok",false): _show("영지 퀘스트 시간 초과 · 실패")
		return
	# Own: one try per quest per daily key (no repeat rule in the tables).
	var quest: Dictionary = TQUEST.quest_at(model,int(at.land_id),at.cell)
	if quest.is_empty(): return
	var key: String = str(int(quest.id))
	if int(state.tq.done.get(key,-1))==period() or int(state.tq.failed.get(key,-1))==period(): return
	var next: Dictionary = state.duplicate(true)
	next.tq.active = {"quest":int(quest.id),"started":now(),"deadline":now()+int(quest.timeout),"count":0}
	if _commit(next).get("ok",false): _show("영지 퀘스트 시작 · %s · %d초" % [str(quest.goals[0].text),int(quest.timeout)])

## AutoComplete false: the player completes it; rewards (sent by mail in the
## original) go straight to the bag through the 523 item supplier.
func complete_quest() -> Dictionary:
	var progress: Dictionary = quest_progress()
	if progress.is_empty(): return {"ok":false,"reason":"진행 중인 영지 퀘스트가 없습니다"}
	if not bool(progress.done): return {"ok":false,"reason":"목표 미달성 (%d/%d)" % [int(progress.count),int(progress.need)]}
	var quest: Dictionary = models().tq.quests[int(progress.quest)]
	var staged: Dictionary = _stage_items(quest.rewards)
	if not staged.get("ok",false): return staged
	var next: Dictionary = state.duplicate(true)
	next.tq.done[str(int(quest.id))] = period(); next.tq.active = {}
	var result: Dictionary = _commit(next,staged.overrides)
	if result.get("ok",false): result["granted"] = staged.granted; last_note = "영지 퀘스트 완료 · "+", ".join(staged.granted)
	return result

func _stage_items(rewards: Array, partial: bool = false) -> Dictionary:
	var overrides: Dictionary = {"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"gold":int(world.gold)}
	var granted: Array = []
	var withheld: Array = []
	for reward: Dictionary in rewards:
		if str(reward.type)=="NoReward": continue # RewardType NoReward: an empty row.
		var refusal: String = ""
		if str(reward.type)!="Item" or int(reward.amount)<1: refusal = "보상 종류 %s 지급 규칙 없음" % str(reward.type)
		else:
			var staged: Dictionary = preload("res://scripts/dungeons/dungeon_play_service.gd").stage_original_item(world,overrides,int(reward.class_id),int(reward.amount),maxi(1,int(reward.bless)),{"kind":"content523_reward","reward_id":int(reward.id)})
			if staged.get("ok",false):
				overrides = staged.overrides
				granted.append("%s ×%d" % [_item_name(int(reward.class_id)),int(reward.amount)]); continue
			refusal = "%s ×%d (%s)" % [_item_name(int(reward.class_id)),int(reward.amount),str(staged.get("error",""))]
		if not partial: return {"ok":false,"reason":refusal+" · 보상 보존","granted":[],"withheld":[refusal]}
		withheld.append(refusal)
	return {"ok":true,"overrides":overrides,"granted":granted,"withheld":withheld}

static func _item_name(id: int) -> String:
	var item: Dictionary = SOURCE.row("ItemClass",id)
	var desc: Dictionary = SOURCE.row("DescData_Korean",int(item.get("DescID",0))) if not item.is_empty() else {}
	return str(desc.get("Description",item.get("Name",str(id))))

## --- Tick --------------------------------------------------------------------

func tick(delta: float) -> void:
	_tick_clock += delta
	if _tick_clock<0.5: return
	var elapsed: float = _tick_clock
	_tick_clock = 0.0
	if not problem.is_empty(): return
	_buff_tick(elapsed)
	if SOURCE.not_installed(): return
	var at: Dictionary = here()
	if at.is_empty(): return
	_elf_tick(at)
	var lands: Dictionary = content_land_ids()
	if not lands.has(int(at.land_id)) and state.tq.active.is_empty(): _zone_id = -1; return
	var escaros: Dictionary = models().escaros
	if escaros.get("ok",false):
		for land: Dictionary in escaros.lands:
			if int(land.id)==int(at.land_id): _zone_tick(at); _artifact_tick(at); break
	_quest_tick(at)

func status_line() -> String:
	var at: Dictionary = here()
	var lines: Array = []
	var progress: Dictionary = quest_progress()
	if not progress.is_empty(): lines.append("영지 퀘스트 %d/%d · 남은 %d초" % [int(progress.count),int(progress.need),int(progress.left)])
	if not at.is_empty(): lines.append("현재 Land %d (%d,%d)" % [int(at.land_id),int(at.cell[0]),int(at.cell[1])])
	if not last_note.is_empty(): lines.append(last_note)
	return " · ".join(lines)
