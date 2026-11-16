extends RefCounted
## 던전 창 세부 데이터 (UI 요청 2026-11-16) — 시련의 탑 버프·스피드 모드·클리어 타임 랭킹,
## 던전 상점, 오림 업적·챕터 스토리. Original 523 values first; the rest is TWILIGHT 근사.
## docs/SOURCE_DUNGEONS523.md "던전 창 세부 데이터". Own save key `dungeon_extras523`.
##  - 탑 버프: TrialTowerBuff rows (BuffClass, 화폐 152 시련의 증표 / 2734 하드, 비용) — 원본.
##    지속: TrialTowerConstant.BuffMaxTime 360초(원본 값, 지속으로 읽음 — 근거 약함). 한 번에 하나
##    (더 높은 단계로 바꾸면 교체 — 근사). 효과는 그 BuffClass의 근거리/원거리 대미지·명중 행.
##    화폐 152/2734는 CurrencyUnitClass의 원본 아이템(#327824 등) 물리 수량에서 뺀다.
##  - 스피드 모드: 표 없음 → 근사: 기존 로컬 탑 시간 배율(source_dungeon_runs.configure_local)을 2배로.
##  - 랭킹: 서버 랭킹 없음 → 근사: 이 기기의 클리어 기록(층마다 가장 빠른 10개, TrialTowerConstant.UIRank 100 상한 안).
##  - 상점: 시련의 증표 = MarketDisplayCategoryGroupEntity DisplayCurrencyId 152 (카테고리 122) → 기존 상점 열기.
##    오림: 표에 오림 전용 상점 없음 → {}.
##  - 오림 업적: 업적 표가 523에 없음 → 근사: 챕터(UIOrimsTrailStage)마다 일반 클리어·하드 클리어 2개, 보상 없음.
##  - 오림 스토리: UIOrimsTrailStage.StageName / StoryDescID (원본). 열림 = 그 챕터 일반 입장 가능(앞 챕터 일반 클리어, 1장은 항상).
const SAVE_KEY := "dungeon_extras523"
const SCHEMA := 1
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const RANK_ROWS := 10
const SPEED_SCALE := 2

var world: Node = null
var state: Dictionary = {}
var _tower_seen: Dictionary = {}
var _orim_seen: String = ""

func _init() -> void:
	state = fresh()

static func fresh() -> Dictionary:
	return {"schema":SCHEMA,"tower_buff":{},"ranking":{},"orim_clears":{},"orim_claimed":{}}

func configure(owner: Node) -> void:
	world = owner

func export_state() -> Dictionary:
	return state.duplicate(true)

func import_state(value: Variant) -> void:
	state = fresh()
	if not value is Dictionary or int(value.get("schema",0)) != SCHEMA: return
	for key: String in ["tower_buff","ranking","orim_clears","orim_claimed"]:
		if value.get(key) is Dictionary: state[key] = (value[key] as Dictionary).duplicate(true)

func _save() -> void:
	if world != null and world.has_method("_request_deferred_save"): world._request_deferred_save()

static func _now() -> int:
	return int(Time.get_unix_time_from_system())

# --- 시련의 탑 버프 ---------------------------------------------------------------

func _tower_hard() -> bool:
	var runs: Variant = world.get("source_dungeon_runs") if world != null else null
	return runs != null and not runs.state.active.is_empty() and bool(runs.state.active.get("hard",false))

func _constant(name: String, hard: bool) -> int:
	for row: Dictionary in SOURCE.rows("TrialTowerConstant"):
		if str(row.get("Name","")) == name: return int(row.HardValue if hard else row.Value)
	return 0

static func _buff_values(buff_class_id: int) -> Dictionary:
	var keys := {"MeleeDamage":"melee_damage","RangeDamage":"ranged_damage","MeleeHit":"melee_accuracy","RangeHit":"ranged_accuracy","MagicHit":"magic_accuracy","SpellPower":"sp"}
	var out: Dictionary = {}
	for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",buff_class_id):
		var bonus: Dictionary = SOURCE.row("Bonus", int(link.get("BonusID",0)))
		var kind: String = str(SOURCE.row("BonusType", int(bonus.get("BonusTypeID",0))).get("Name",""))
		if keys.has(kind) and int(bonus.get("BonusApplicationTypeID",0)) == 0: out[keys[kind]] = int(out.get(keys[kind],0)) + int(bonus.get("Value",0))
	return out

static func _currency_name(currency_id: int) -> String:
	if currency_id == 1: return "아데나"
	if currency_id == 4: return "다이아"
	return str(SOURCE.row("Currency", currency_id).get("Name","#%d" % currency_id)).trim_prefix("[시련의탑] ")

func tower_buff_offers(floor_index: int = 0) -> Array:
	var out: Array = []
	if world == null or SOURCE.not_installed(): return out
	var hard: bool = _tower_hard()
	var active: Dictionary = state.tower_buff
	var left: int = maxi(0, int(active.get("expires",0)) - _now())
	for row: Dictionary in SOURCE.rows("TrialTowerBuff"):
		if bool(row.get("IsHard",false)) != hard: continue
		var buff: Dictionary = SOURCE.row("BuffClass", int(row.BuffClassID))
		var on: bool = int(active.get("buff_id",0)) == int(row.ID) and left > 0
		out.append({"buff_id":int(row.ID),"name":str(buff.get("Name","")).replace("[아이템][버프] ","").replace("[시련의 탑][하드] ",""),"buff_class_id":int(row.BuffClassID),
			"cost":{"currency":_currency_name(int(row.CurrencyID)),"currency_id":int(row.CurrencyID),"amount":int(row.CurrencyCost)},"active":on,"remaining_sec":left if on else 0,
			"effects":_buff_values(int(row.BuffClassID)),"floor":floor_index})
	return out

## Pays the original currency (화폐 152/2734 = its CurrencyUnitClass item; 1 아데나; 4 다이아).
func _pay(currency_id: int, amount: int) -> Dictionary:
	if currency_id == 1: return {"ok":world.gold >= amount,"gold":world.gold - amount,"reason":"아데나 부족"}
	if currency_id in [4,174,764]: return world.source_dungeon_payment_plan(currency_id,amount)
	var items: Dictionary = {}
	for row: Dictionary in SOURCE.related("CurrencyUnitClass","CurrencyID",currency_id): items[int(row.get("ClassID",0))] = true
	var uid: String = ""
	var have: int = 0
	for key: String in world.item_instances:
		var stack: Dictionary = STACK.proof(world, key)
		if stack.is_empty() or not items.has(int(stack.get("record",{}).get("source_item_class_id",0))): continue
		if int(stack.remaining) > have: have = int(stack.remaining); uid = key
	if uid.is_empty() or have < amount: return {"ok":false,"reason":"%s 부족 (%d/%d)" % [_currency_name(currency_id), have, amount]}
	var owned: Dictionary = STACK.proof(world, uid)
	var paid: Dictionary = STACK.stage_debit(world,[{"physical_id":uid,"quantity":amount,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-amount,"source_native_stack_receipt":owned.receipt.duplicate(true)}])
	if not paid.get("ok",false): return {"ok":false,"reason":str(paid.get("reason",paid.get("error","재화 차감 실패")))}
	var out: Dictionary = paid.overrides.duplicate(true)
	out["ok"] = true
	return out

func tower_buy_buff(buff_id: int) -> Dictionary:
	if world == null or SOURCE.not_installed(): return {"ok":false,"reason":"원본 523 정의가 설치되지 않았습니다"}
	var row: Dictionary = SOURCE.row("TrialTowerBuff", buff_id)
	if row.is_empty(): return {"ok":false,"reason":"시련의 탑 버프 원본 없음"}
	if bool(row.get("IsHard",false)) != _tower_hard(): return {"ok":false,"reason":"이 모드의 버프가 아닙니다"}
	var active: Dictionary = state.tower_buff
	if int(active.get("buff_id",0)) == buff_id and int(active.get("expires",0)) > _now(): return {"ok":false,"reason":"이미 적용 중인 버프입니다"}
	var paid: Dictionary = _pay(int(row.CurrencyID), int(row.CurrencyCost))
	if not paid.get("ok",false): return {"ok":false,"reason":str(paid.get("reason",""))}
	var next: Dictionary = state.duplicate(true)
	next.tower_buff = {"buff_id":buff_id,"buff_class_id":int(row.BuffClassID),"expires":_now() + maxi(1,_constant("BuffMaxTime",bool(row.IsHard)))}
	var staged: Dictionary = {SAVE_KEY:next}
	for key: String in ["inventory","item_instances","gold","consumable_state","ainhasad_state"]:
		if paid.has(key): staged[key] = paid[key]
	if world._save_game(true, staged) != OK: return {"ok":false,"reason":"저장 실패 · 버프와 재화 변화 없음"}
	state = next
	if staged.has("inventory"): world.inventory = staged.inventory
	if staged.has("item_instances"): world.item_instances = staged.item_instances
	if staged.has("gold"): world.gold = int(staged.gold)
	if staged.has("consumable_state"): world.consumable_service.import_state(staged.consumable_state)
	if staged.has("ainhasad_state"): world.ain_service.import_state(staged.ainhasad_state)
	var name: String = str(SOURCE.row("BuffClass", int(row.BuffClassID)).get("Name",""))
	return {"ok":true,"reason":"","message":"%s 적용 · %d초 (TWILIGHT 근사: 지속 = BuffMaxTime)" % [name, int(next.tower_buff.expires) - _now()]}

func buff_value(key: String) -> int:
	var active: Dictionary = state.tower_buff
	if active.is_empty() or int(active.get("expires",0)) <= _now(): return 0
	return int(_buff_values(int(active.get("buff_class_id",0))).get(key,0))

# --- 스피드 모드 -----------------------------------------------------------------

func tower_speed_mode() -> Dictionary:
	var runs: Variant = world.get("source_dungeon_runs") if world != null else null
	if runs == null: return {"available":false,"on":false,"multiplier":1.0,"cost":{},"reason":"시련의 탑 소유자 없음"}
	var settings: Dictionary = runs.state.get("local_settings",{})
	var busy: bool = not runs.state.active.is_empty() and str(runs.state.active.get("status","")) in ["active","cleared"]
	var scale: int = int(settings.get("time_scale",1))
	return {"available":not busy,"on":scale > 1,"multiplier":float(scale),"cost":{},"reason":"도전 중에는 바꿀 수 없습니다" if busy else "",
		"basis":"TWILIGHT 근사: 원본 표에 스피드 모드 없음 → 기존 로컬 탑 시간 배율 %d배" % SPEED_SCALE}

func tower_set_speed_mode(on: bool) -> Dictionary:
	var runs: Variant = world.get("source_dungeon_runs") if world != null else null
	if runs == null: return {"ok":false,"reason":"시련의 탑 소유자 없음"}
	var settings: Dictionary = runs.state.get("local_settings",{})
	var result: Dictionary = runs.configure_local(bool(settings.get("enabled",false)), SPEED_SCALE if on else 1)
	return {"ok":bool(result.get("ok",false)),"reason":str(result.get("reason",""))}

# --- 클리어 타임 랭킹 (로컬) -------------------------------------------------------

func _floor_of(stage_id: int) -> int:
	return int(SOURCE.row("TrialTowerStage", stage_id).get("StageIndex",0))

func tick() -> void:
	if world == null: return
	var runs: Variant = world.get("source_dungeon_runs")
	if runs != null and not runs.state.active.is_empty():
		var run: Dictionary = runs.state.active
		var id: String = str(run.get("id",""))
		if str(run.get("status","")) == "active" and not _tower_seen.has(id): _tower_seen[id] = _now()
		elif str(run.get("status","")) == "cleared" and _tower_seen.has(id) and int(_tower_seen[id]) > 0:
			var seconds: int = maxi(1, _now() - int(_tower_seen[id]))
			_tower_seen[id] = 0
			_record_clear(int(run.get("stage_id",0)), bool(run.get("hard",false)), seconds)
	var play: Variant = world.get("dungeon_play")
	if play != null and not play.state.get("active",{}).is_empty():
		var orim: Dictionary = play.state.active
		var token: String = str(orim.get("id",""))
		if str(orim.get("kind","")) == "orim" and str(orim.get("status","")) == "cleared" and bool(orim.get("success",false)) and token != _orim_seen:
			_orim_seen = token
			var stage: Dictionary = SOURCE.row("OrimsTrailStage", int(orim.get("stage_id",0)))
			var key: String = "%d:%s" % [int(stage.get("StageIndex",0)), "hard" if bool(stage.get("IsHard",false)) else "normal"]
			if not state.orim_clears.has(key):
				state.orim_clears[key] = {"at":_now(),"seconds":maxi(0,int(orim.get("completed_at",0)) - int(orim.get("started",0)))}
				_save()

func _record_clear(stage_id: int, hard: bool, seconds: int) -> void:
	var key: String = "%d:%s" % [_floor_of(stage_id), "hard" if hard else "normal"]
	var rows: Array = state.ranking.get(key, [])
	rows.append({"name":str(world.get("character_display_name")) if not str(world.get("character_display_name")).is_empty() and world.get("character_display_name") != null else "나","class":str(world.job_class),"clear_sec":seconds,"at":_now()})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.clear_sec) < int(b.clear_sec) or (int(a.clear_sec) == int(b.clear_sec) and int(a.at) < int(b.at)))
	if rows.size() > RANK_ROWS: rows.resize(RANK_ROWS)
	state.ranking[key] = rows
	_save()

func tower_ranking(floor_index: int, hard: bool = false) -> Dictionary:
	var rows: Array = []
	var index: int = 0
	for row: Dictionary in state.ranking.get("%d:%s" % [floor_index, "hard" if hard else "normal"], []):
		index += 1
		var entry: Dictionary = row.duplicate(true); entry["rank"] = index
		rows.append(entry)
	return {"rows":rows,"mine":{"rank":1,"clear_sec":int(rows[0].clear_sec)} if not rows.is_empty() else {},"basis":"TWILIGHT 근사: 이 기기의 클리어 기록"}

# --- 던전 상점 --------------------------------------------------------------------

func dungeon_shop(kind: String) -> Dictionary:
	if kind == "tower":
		for row: Dictionary in SOURCE.rows("MarketDisplayCategoryGroupEntity"):
			if int(row.get("DisplayCurrencyId",0)) == 152:
				return {"open_method":"open_shop","args":[],"market_display_category":int(row.get("MarketDisplayCategoryType",0)),"currency":_currency_name(152)}
	return {}

# --- 오림 업적·스토리 ----------------------------------------------------------------

func _chapter_row(chapter: int) -> Dictionary:
	for row: Dictionary in SOURCE.rows("UIOrimsTrailStage"):
		if int(row.get("OrimsTrailStageIndex",-1)) == chapter: return row
	return {}

func orim_achievements(chapter: int) -> Array:
	var out: Array = []
	var row: Dictionary = _chapter_row(chapter)
	if row.is_empty() or chapter <= 0: return out
	var title: String = str(row.get("StageName",""))
	for mode: String in ["normal","hard"]:
		var id: String = "orim:%d:%s" % [chapter, mode]
		var done: bool = state.orim_clears.has("%d:%s" % [chapter, mode])
		var claimed: bool = state.orim_claimed.has(id)
		out.append({"id":id,"name":"%s %s 클리어" % [title, "일반" if mode == "normal" else "하드"],"progress":1 if done else 0,"goal":1,"reward":[],"claimed":claimed,"can_claim":done and not claimed,
			"basis":"TWILIGHT 근사: 523 표에 오림 업적이 없어 챕터 클리어 기록으로 만들었고 보상 없음"})
	return out

func orim_claim_achievement(id: String) -> Dictionary:
	var parts: PackedStringArray = id.split(":")
	if parts.size() != 3 or parts[0] != "orim" or not parts[1].is_valid_int(): return {"ok":false,"reason":"업적 ID 오류","message":""}
	if not state.orim_clears.has("%s:%s" % [parts[1], parts[2]]): return {"ok":false,"reason":"아직 달성하지 않았습니다","message":""}
	if state.orim_claimed.has(id): return {"ok":false,"reason":"이미 받은 업적입니다","message":""}
	state.orim_claimed[id] = _now()
	_save()
	return {"ok":true,"reason":"","message":"업적 완료 표시 (보상 없음 · TWILIGHT 근사)"}

func orim_chapter_story(chapter: int) -> Dictionary:
	var row: Dictionary = _chapter_row(chapter)
	if row.is_empty() or chapter <= 0: return {}
	var text: String = str(SOURCE.row("DescData_Korean", int(row.get("StoryDescID",0))).get("Description",""))
	var unlocked: bool = chapter == 1 or state.orim_clears.has("%d:normal" % (chapter - 1))
	return {"title":str(row.get("StageName","")),"text":text,"unlocked":unlocked}
