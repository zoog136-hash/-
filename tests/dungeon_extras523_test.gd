extends SceneTree
## 던전 창 세부 데이터 API (world.dungeon_play.* → scripts/dungeons/dungeon_extras523.gd).
## With the original ZIP, in actual Main: tower buffs (원본 TrialTowerBuff), the 시련의 증표 payment,
## the speed mode, the local clear ranking, the shop route, Orim achievements and chapter story,
## and save/reload of the new key. Without the ZIP: the API answers empty.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("DUNGEON_EXTRAS523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func token_item() -> int:
	for row: Dictionary in SOURCE.related("CurrencyUnitClass","CurrencyID",152):
		if row.get("ForGive") == true: return int(row.ClassID)
	return 0

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var play = world.dungeon_play
	world.dungeon_extras523.import_state({})
	var offers: Array = play.tower_buff_offers(1)
	evidence["offers"] = offers
	check(offers.size() == 3 and int(offers[0].cost.amount) == 3 and int(offers[2].cost.amount) == 10 and int(offers[0].effects.get("melee_damage",0)) == 3, "3 normal tower buffs from TrialTowerBuff: "+str(offers))
	var token: int = token_item()
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = SUPPLY.stage(world,[{"item_class_id":token,"amount":10,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if check(token > 0 and staged.get("ok",false), "grant 10 시련의 증표 #%d: %s" % [token,str(staged.get("error",""))]):
		world._save_game(true,staged.overrides)
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var bought: Dictionary = play.tower_buy_buff(int(offers[0].buff_id))
		var left: int = 0
		for value: Variant in world.inventory.values(): left += int(value)
		evidence["buy"] = {"result":bought,"left":left,"melee":world._active_item_buff_total("melee_damage"),"offer":play.tower_buff_offers(1)[0]}
		check(bought.get("ok",false) and left == 7 and world.dungeon_extras523.buff_value("melee_damage") == 3 and bool(play.tower_buff_offers(1)[0].active) and int(play.tower_buff_offers(1)[0].remaining_sec) > 350, "buy 1단계: 증표 10→7, 근거리 대미지 +3, 360초 "+str(evidence.buy))
		check(not play.tower_buy_buff(int(offers[0].buff_id)).get("ok",true), "the same active buff is not bought twice")
		world._load_game(true)
		check(world.dungeon_extras523.buff_value("melee_damage") == 3, "reload keeps the buff")
	var speed: Dictionary = play.tower_speed_mode()
	var on: Dictionary = play.tower_set_speed_mode(true)
	var speed_on: Dictionary = play.tower_speed_mode()
	play.tower_set_speed_mode(false)
	evidence["speed"] = {"before":speed,"set":on,"after":speed_on,"off":play.tower_speed_mode()}
	check(bool(speed.available) and on.get("ok",false) and bool(speed_on.on) and is_equal_approx(float(speed_on.multiplier), 2.0) and not bool(play.tower_speed_mode().on), "speed mode on (×2) / off "+str(evidence.speed))
	world.dungeon_extras523._record_clear(4, false, 120)
	world.dungeon_extras523._record_clear(4, false, 90)
	var ranking: Dictionary = play.tower_ranking(1)
	evidence["ranking"] = ranking
	check(ranking.rows.size() == 2 and int(ranking.rows[0].clear_sec) == 90 and int(ranking.rows[0].rank) == 1 and int(ranking.mine.clear_sec) == 90, "local ranking floor 1 sorted by clear time "+str(ranking))
	var shop: Dictionary = play.dungeon_shop("tower")
	evidence["shop"] = {"tower":shop,"orim":play.dungeon_shop("orim")}
	check(str(shop.get("open_method","")) == "open_shop" and world.hud.has_method("open_shop") and play.dungeon_shop("orim").is_empty(), "shop route "+str(evidence.shop))
	var achievements: Array = play.orim_achievements(1)
	check(achievements.size() == 2 and not bool(achievements[0].can_claim) and not play.orim_claim_achievement(str(achievements[0].id)).get("ok",true), "Orim achievements before a clear")
	world.dungeon_extras523.state.orim_clears["1:normal"] = {"at":1,"seconds":200}
	var claimed: Dictionary = play.orim_claim_achievement("orim:1:normal")
	check(claimed.get("ok",false) and bool(play.orim_achievements(1)[0].claimed), "claim after the 1장 일반 clear")
	var story1: Dictionary = play.orim_chapter_story(1); var story2: Dictionary = play.orim_chapter_story(2); var story3: Dictionary = play.orim_chapter_story(3)
	evidence["story"] = {"1":story1,"2":story2.get("unlocked"),"3":story3.get("unlocked")}
	check(str(story1.title).begins_with("1.") and not str(story1.text).is_empty() and bool(story1.unlocked) and bool(story2.unlocked) and not bool(story3.unlocked), "chapter story text and unlock "+str(evidence.story))
	check(world._save_game(true) == OK, "save")
	world.dungeon_extras523.import_state({})
	world._load_game(true)
	check(world.dungeon_extras523.state.ranking.has("1:normal") and world.dungeon_extras523.state.orim_claimed.has("orim:1:normal"), "reload keeps ranking and claims")
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else:
		var extras = preload("res://scripts/dungeons/dungeon_extras523.gd").new()
		check(extras.tower_buff_offers(1).is_empty() and extras.orim_chapter_story(1).is_empty(), "without the original ZIP the API answers empty")
	print("DUNGEON_EXTRAS523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
