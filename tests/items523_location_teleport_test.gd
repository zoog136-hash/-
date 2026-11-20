extends SceneTree
## Original 523 fixed-destination teleport items (ScrollTeleportDungeon /
## ScrollTeleport: 오만의 탑 n층 이동 주문서 등). One TeleportToLocation
## (Locations LandID/X/Y) or TeleportToTerritory (Territories box) row, with
## ConsumeTerritoryClassID "사용 지역"(type 1) / "사용 불가 지역"(type 2) rows.
## The item debit is saved by the arrival's own checkpoint save; a refused
## move keeps the item. Synthetic checks always run; with the original
## definition ZIP the real items are counted, and with an active original 523
## map in actual Main a real scroll is used, saved and reloaded.
const EFFECTS = preload("res://scripts/loot/source523_item_effects.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## 오만의 탑 2층 이동 주문서: Locations 21272 (Land 22802), ConsumeTerritoryClass 10442.
const OMAN2 := 19352
## 오만과 신념의 탑 입구 (Land 46952) inside ConsumeTerritory 10442 (Territories 160312).
const ENTRANCE_LAND := 46952
## 윈다우드성 던전 이동 주문서 (각인): Life row (clock unknown) -> kept.
const LIFE_ITEM := 117123
## 흑마법 연구실 이동 주문서 (이벤트): ClassUsageInterval row -> kept.
const INTERVAL_ITEM := 123364
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_LOCATION_TELEPORT_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	# 보고서2 NEW04: start <= p < end (end exclusive), a degenerate row holds no cell.
	var rect: Rect2i = EFFECTS.area_rect({"StartX":10,"StartY":20,"EndX":13,"EndY":22})
	check(rect.has_point(Vector2i(10,20)) and rect.has_point(Vector2i(12,21)) and not rect.has_point(Vector2i(13,21)) and not rect.has_point(Vector2i(12,22)) and not rect.has_point(Vector2i(9,20)), "ConsumeTerritories rectangle: StartX <= x < EndX, StartY <= y < EndY")
	check(not EFFECTS.area_rect({"StartX":5,"StartY":5,"EndX":5,"EndY":5}).has_point(Vector2i(5,5)) and not EFFECTS.area_rect({"StartX":5,"StartY":5,"EndX":3,"EndY":9}).has_point(Vector2i(4,6)), "End <= Start contains no cell")
	check(EFFECTS.location_teleport({}).is_empty() and EFFECTS.claims({}).is_empty(), "a non-original record is not claimed")
	check(EFFECTS.location_teleport({"source_m_native_item":true,"slot":"material","source_test_item":false}).is_empty(), "only consumables are claimed")
	var payment_script: Script = PAYMENT
	var keys: Array = payment_script.get_script_constant_map().get("_OVERRIDE_KEYS",[])
	for key: String in ["consumable_state","item_use_cooldowns","patch523_transaction_rng","inventory","item_instances"]:
		check(keys.has(key), "travel save accepts %s" % key)

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func table() -> void:
	var oman: Dictionary = EFFECTS.location_teleport(record(OMAN2))
	evidence["oman2"] = oman
	check(oman.get("land_id")==22802 and oman.get("bounds")==[32730,32803,32730,32803] and oman.get("usable_classes")==[10442] and (oman.get("forbidden_classes",[]) as Array).is_empty(), "#19352 -> Land 22802 (32730,32803), usable only in ConsumeTerritory 10442")
	check(STACK.profile(record(OMAN2)).get("kind")=="teleport_location", "#19352 has the teleport_location use owner")
	check(int(EFFECTS.location_teleport(record(LIFE_ITEM)).get("land_id",0))>0, "Life rows are kept by the item life ledger (TWILIGHT 근사)")
	var interval: Dictionary = EFFECTS.location_teleport(record(INTERVAL_ITEM))
	evidence["class_usage_interval"] = interval
	check(int(interval.get("consume_delay_ms",0))==1800000, "ClassUsageInterval 1800s becomes the reuse delay (TWILIGHT 근사) "+str(interval.get("consume_delay_ms")))
	var areas: Variant = EFFECTS.consume_areas([10442])
	check(areas is Array and (areas as Array).size()==11, "ConsumeTerritory 10442 = entrance + 10 floors")
	var categories: Dictionary = {}
	for category: Dictionary in SOURCE.rows("ItemCategory"):
		if str(category.get("Name","")) in ["ScrollTeleport","ScrollTeleportDungeon","TeleportAmulet"]: categories[int(category.ID)] = str(category.Name)
	var claimed: Dictionary = {}; var lands: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
		if row.get("TestItem")!=false: continue
		var item: Dictionary = record(int(row.ID))
		if STACK.profile(item).get("kind")!="teleport_location": continue
		var name: String = str(categories[int(row.CategoryID)])
		claimed[name] = int(claimed.get(name,0))+1
		var land: int = int(EFFECTS.location_teleport(item).land_id)
		lands[land] = int(lands.get(land,0))+1
	evidence["claimed"] = claimed; evidence["lands"] = lands.size()
	var total: int = 0
	for value: int in claimed.values(): total += value
	check(total>=180 and int(claimed.get("TeleportAmulet",0))>=30, "fixed-destination scrolls and (TWILIGHT 근사) reusable amulets are usable (%s)" % str(claimed))
	var amulet: Dictionary = EFFECTS.location_teleport(record(OMAN2_AMULET))
	evidence["amulet"] = amulet
	check(amulet.get("land_id")==22802 and amulet.get("reusable")==true and amulet.get("usable_classes")==[42], "#19372 오만의 탑 2층 이동 부적 -> Land 22802, reusable, 사용 지역 42")
	var ruler: Dictionary = EFFECTS.location_teleport(record(OMAN2_RULER))
	check(ruler.get("reusable")==true and (ruler.get("ignored_rows",[]) as Array).has("IgnoreNoTeleport"), "#122424 지배 부적: reusable, possession rows listed as not applied "+str(ruler.get("ignored_rows",[])))
	evidence["total"] = total

## Test setup only (reaching a start spot, not the feature): every in-Land
## rule the start Lands declare.
const SETUP_WAIVE := ["NoTeleport","TurnOffAutoForTeleport","NoPurplePushOnDie","NpcBuff","NoTeleportCome","LandPlayerSocketTimeoutSecond","ObjectLazyLoad","IdleTime","UsableCallClan","CompetitionDungeonLand","LandCondition"]
## 오만의 탑 3층 이동 주문서 (Locations -> Land 22812), 해적의 무덤 이동 주문서 (Land 47661, 해적섬에서만).
const OMAN3 := 19362
const PIRATE_TOMB := 259611
const PIRATE_ISLAND_LAND := 47323
## 퀘스트 이동 주문서 -> [초보존][마검사] 말하는 섬 선착장 (Land 49492 declares TurnOffAutoForTeleport).
const AUTO_OFF_SCROLL := 292612
## 오만의 탑 2층 이동 부적 / 지배 부적 (TeleportAmulet, TWILIGHT 근사: not consumed).
const OMAN2_AMULET := 19372
const OMAN2_RULER := 122424

func grant(world: Node, id: int, amount: int) -> String:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "physical grant #%d: %s" % [id,str(staged.get("error",""))]): return ""
	check(world._save_game(true,staged.overrides)==OK, "grant save #%d" % id)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return str(record(id).name)

func use(world: Node, name: String) -> Dictionary:
	world.item_use_cooldowns.clear(); world.portal_cooldown = 0.0; world.player.auto_enabled = false
	var result: Dictionary = STACK.try_use(world,name)
	for frame: int in 3: await process_frame
	return result

func land(world: Node) -> int:
	return int(world.orim_current_land().get("land_id",-1))

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 60:
		await process_frame
		if world.current523_aden_source_active(): break
	if not world.current523_aden_source_active():
		evidence["runtime"] = "original 523 map not active (run with --source523-pack=<root>): travel part skipped"
		world.queue_free(); await process_frame; return
	world.inventory = {}; world.item_instances = {}
	world.level = 70
	var oman2: String = grant(world,OMAN2,3)
	var oman3: String = grant(world,OMAN3,1)
	if oman2.is_empty() or oman3.is_empty(): world.queue_free(); await process_frame; return
	var outside: Dictionary = await use(world,oman2)
	evidence["outside"] = outside.get("reason","")
	check(not outside.get("ok",false) and int(world.inventory.get(oman2,0))==3 and land(world)==4, "Aden (outside 사용 지역): refused, 3 kept, still Aden")
	# TurnOffAutoForTeleport: auto hunting is turned off on arrival.
	var dock: String = grant(world,AUTO_OFF_SCROLL,1)
	if not dock.is_empty():
		world.item_use_cooldowns.clear(); world.portal_cooldown = 0.0
		world.player.set_auto_enabled(true)
		var docked: Dictionary = STACK.try_use(world,dock)
		for frame: int in 3: await process_frame
		evidence["auto_off"] = {"ok":docked.get("ok"),"reason":docked.get("reason",docked.get("message","")),"land":land(world),"auto":world.player.auto_enabled}
		check(docked.get("ok",false) and land(world)==49492 and not world.player.auto_enabled and not world.inventory.has(dock), "Aden -> 말하는 섬 선착장 with auto on: moved, auto turned off, scroll used")
		world.player.set_auto_enabled(false)
	var setup: Dictionary = world.content523_enter_land(ENTRANCE_LAND,[32787,32715,32787,32715],SETUP_WAIVE)
	evidence["setup_entrance"] = setup
	if not check(setup.get("ok",false) and land(world)==ENTRANCE_LAND, "test setup: at the tower entrance"): world.queue_free(); await process_frame; return
	world.level = 60
	var low: Dictionary = await use(world,oman2)
	evidence["low_level"] = low.get("reason","")
	check(not low.get("ok",false) and int(world.inventory.get(oman2,0))==3 and land(world)==ENTRANCE_LAND, "level 60 (< 68): refused, kept")
	world.level = 70
	var up: Dictionary = await use(world,oman2)
	evidence["to_2f"] = {"ok":up.get("ok"),"reason":up.get("reason",up.get("message","")),"land":land(world)}
	check(up.get("ok",false) and land(world)==22802 and int(world.inventory.get(oman2,0))==2, "entrance -> 오만의 탑 2층, 3 -> 2")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved is Dictionary and int((saved as Dictionary).get("inventory",{}).get(oman2,0))==2, "the arrival save holds the debit")
	var floor3: Dictionary = await use(world,oman3)
	evidence["to_3f"] = {"ok":floor3.get("ok"),"reason":floor3.get("reason",floor3.get("message","")),"land":land(world)}
	check(floor3.get("ok",false) and land(world)==22812 and not world.inventory.has(oman3), "inside the tower: 2층 -> 3층, last scroll used")
	# TWILIGHT 근사: the 2층 이동 부적 (사용 지역 42 = 탑 입구) moves to 2층 and stays in the bag.
	var amulet: String = grant(world,OMAN2_AMULET,1)
	if not amulet.is_empty():
		var inside: Dictionary = await use(world,amulet)
		check(not inside.get("ok",false) and int(world.inventory.get(amulet,0))==1, "the amulet outside its 사용 지역(탑 입구) is refused and kept")
		world.content523_enter_land(ENTRANCE_LAND,[32787,32715,32787,32715],SETUP_WAIVE)
		var back: Dictionary = await use(world,amulet)
		evidence["amulet_use"] = {"ok":back.get("ok"),"reason":back.get("reason",back.get("message","")),"land":land(world),"left":int(world.inventory.get(amulet,0)),"consumed":back.get("consumed")}
		check(back.get("ok",false) and land(world)==22802 and int(world.inventory.get(amulet,0))==1 and int(back.get("consumed",-1))==0, "entrance -> 2층 with the amulet, amulet kept")
		world.content523_enter_land(ENTRANCE_LAND,[32787,32715,32787,32715],SETUP_WAIVE)
		var again: Dictionary = await use(world,amulet)
		check(again.get("ok",false) and land(world)==22802 and int(world.inventory.get(amulet,0))==1, "the amulet is usable again and still kept "+str(again.get("reason",again.get("message",""))))
		# TWILIGHT 근사: 지배 부적 소지 효과 — on its own floor: NoTeleport ignored + description bonuses.
		var ruler: String = grant(world,OMAN2_RULER,1)
		if not ruler.is_empty():
			world.item_possession523._checked_ms = -100000; world.item_possession523._land_ms = -100000
			var on_floor: Dictionary = {"land":land(world),"active":world.item_possession523.active(),"sp":world._active_item_buff_total("sp"),"xp":world._active_item_buff_total("xp")}
			world.content523_enter_land(ENTRANCE_LAND,[32787,32715,32787,32715],SETUP_WAIVE)
			world.item_possession523._land_ms = -100000
			var off_floor: Dictionary = {"land":land(world),"active":world.item_possession523.active()}
			evidence["ruler_possession"] = {"on":on_floor,"off":off_floor}
			check(int(on_floor.land)==22802 and bool(on_floor.active) and int(on_floor.sp)>=3 and int(on_floor.xp)>=20 and not bool(off_floor.active), "2층 지배 부적: 2층에서만 순간이동 허용·SP+3·경험치+20% "+str(evidence.ruler_possession))
		world.inventory.erase(amulet)
		world._load_game(true)
		check(int(world.inventory.get(amulet,0))==1, "reload keeps the amulet")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")
	world.inventory.erase(oman2)
	world._load_game(true)
	check(int(world.inventory.get(oman2,0))==2 and not world.inventory.has(oman3), "reload keeps 2 / 0")
	# 해적의 무덤: only on 해적섬 (ConsumeTerritoryClass 10771), level 88.
	var tomb: String = grant(world,PIRATE_TOMB,1)
	if not tomb.is_empty():
		world.level = 90
		var wrong: Dictionary = await use(world,tomb)
		check(not wrong.get("ok",false) and world.inventory.has(tomb), "해적의 무덤 scroll outside 해적섬: refused, kept")
		var island: Dictionary = world.content523_enter_land(PIRATE_ISLAND_LAND,[32319,33027,32327,33035],SETUP_WAIVE) # near Territories 172413 "[해적섬] 기란 텔레포트 위치"
		evidence["setup_island"] = island
		if check(island.get("ok",false), "test setup: on 해적섬"):
			var gone: Dictionary = await use(world,tomb)
			evidence["to_tomb"] = {"ok":gone.get("ok"),"reason":gone.get("reason",gone.get("message","")),"land":land(world)}
			check(gone.get("ok",false) and land(world)==47661 and not world.inventory.has(tomb), "해적섬 -> 해적의 무덤, scroll used")
	world.queue_free()
	await process_frame

func run() -> void:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="):
			var base: String = value.trim_prefix("--source523-pack=")
			var pack: Script = load("res://scripts/boot/source523_pack.gd")
			var read: Dictionary = pack.read_descriptor(base.path_join("source523_pack.json"))
			pack.apply(pack.selections(base, read.descriptor, pack.read_addons(base)))
			load("res://scripts/maps/current523_host.gd").refresh()
	rules()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("ITEMS523_LOCATION_TELEPORT_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
