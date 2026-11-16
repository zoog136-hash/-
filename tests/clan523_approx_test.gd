extends SceneTree
## 혈맹 남은 규칙 — TWILIGHT 근사 (docs/clan523_missing_rules.md 3-4, 3-8, 3-9, 3-11).
## With the original ZIP, in actual Main:
## - clan buff RangeEvasion raises the existing ER, PierceMelee/RangeEvasion raise the
##   melee/ranged accuracy (clan level 20: ER +5, accuracy +2);
## - the 고급 donation's Einasad 2,500 is charged as blessing points and saved;
## - 성장의 뿔피리 gives the user 경험치 +20 % for 1,800 s, 전투의 뿔피리 a 3 % damage
##   reduction against monsters for 600 s (PvP numbers count against monsters);
## - 아인하사드: LevelEinasadBlessRecharge once per game day, Experience.EinasadReduction
##   as a consumption reduction.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CLAN = preload("res://scripts/clan523/clan523.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CLAN523_APPROX_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func clan_state(experience: int) -> Dictionary:
	return {"schema":1,"name":"황혼","created_at":1,"experience":experience,"day":0,"donations":{},"day_points":{},"week":0,"week_points":0,"weekly_claimed":[]}

func grant(world: Node, id: int, amount: int) -> String:
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [id,str(staged.get("error",""))]): return ""
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return str(D.variant_item(D.definition_id(str(id)).get("native_record",{}),1).get("name",""))

func runtime() -> void:
	CLAN.reset_cache()
	var data: Dictionary = CLAN.definition()
	if not check(data.get("ok",false), "original clan rows"): return
	evidence["l20"] = data.buffs[20].effects
	check(int(data.buffs[20].effects.get("ranged_evasion",0)) == 5 and int(data.buffs[20].effects.get("melee_evasion_ignore",0)) == 2 and int(data.buffs[20].effects.get("ranged_evasion_ignore",0)) == 2, "clan buff 20 maps the evasion rows "+str(data.buffs[20].effects))
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.clan523.import_state({})
	var er0: int = world._effective_er(); var melee0: int = world._melee_accuracy_stat(); var ranged0: int = world._ranged_accuracy_stat()
	world.clan523.import_state(clan_state(int(data.levels[19].cumulative)))
	var er1: int = world._effective_er(); var melee1: int = world._melee_accuracy_stat(); var ranged1: int = world._ranged_accuracy_stat()
	var hit_m: int = world.clan523.buff_value("melee_accuracy"); var hit_r: int = world.clan523.buff_value("ranged_accuracy")
	evidence["stats"] = {"level":world.clan523.level(),"er":[er0,er1],"melee_hit":[melee0,melee1],"ranged_hit":[ranged0,ranged1],"clan_hit":[hit_m,hit_r]}
	check(world.clan523.level() == 20 and er1 == er0+5 and melee1 == melee0+hit_m+2 and ranged1 == ranged0+hit_r+2, "clan level 20: ER +5, melee/ranged accuracy +2 over the clan MeleeHit/RangeHit rows "+str(evidence.stats))
	# Einasad donation (고급 = donate 12, 100 다이아 → Einasad 2,500).
	world.clan523.import_state(clan_state(0))
	world.inventory["다이아"] = 1000
	world.ain_service.blessing = 1000
	var donated: Dictionary = world.clan523.donate(world,12)
	evidence["donate"] = {"ok":donated.get("ok"),"granted":donated.get("granted"),"withheld":donated.get("withheld"),"blessing":world.ain_service.blessing}
	check(donated.get("ok",false) and world.ain_service.blessing == 3500 and str(donated.granted).contains("아인하사드 축복 2500"), "고급 기부: 아인하사드 축복 +2,500 "+str(evidence.donate))
	world._load_game(true)
	check(world.ain_service.blessing == 3500, "reload keeps the charged blessing")
	# Horns.
	world.inventory = {}; world.item_instances = {}; world.active_item_buffs = {}
	var growth: String = grant(world, 350562, 1)
	var battle: String = grant(world, 350572, 1)
	var xp0: int = world._active_item_buff_total("xp"); var red0: int = world._active_item_buff_total("pve_damage_reduction_pct")
	world.item_use_cooldowns.clear()
	var used1: Dictionary = STACK.try_use(world, growth)
	world.item_use_cooldowns.clear()
	var used2: Dictionary = STACK.try_use(world, battle)
	var horn: Dictionary = world.active_item_buffs.get(growth,{})
	var horn2: Dictionary = world.active_item_buffs.get(battle,{})
	evidence["horns"] = {"growth":{"ok":used1.get("ok"),"reason":used1.get("reason",""),"left":int(world.inventory.get(growth,0)),"buff":{"xp":horn.get("xp"),"duration":horn.get("duration")}},"battle":{"ok":used2.get("ok"),"reason":used2.get("reason",""),"buff":{"red":horn2.get("pve_damage_reduction_pct"),"duration":horn2.get("duration")}}}
	check(used1.get("ok",false) and int(world.inventory.get(growth,0)) == 0 and world._active_item_buff_total("xp") == xp0+20 and is_equal_approx(float(horn.get("duration",0)),1800.0), "성장의 뿔피리: 경험치 +20 %, 1,800초 "+str(evidence.horns.growth))
	check(used2.get("ok",false) and world._active_item_buff_total("pve_damage_reduction_pct") == red0+3 and is_equal_approx(float(horn2.get("duration",0)),600.0), "전투의 뿔피리: 몬스터 대상 대미지 감소 3 %, 600초 "+str(evidence.horns.battle))
	# 아인하사드 (docs/einasad523_missing_rules.md 3·6, TWILIGHT 근사(근거 약함)).
	var ain = world.ain_service
	ain.blessing = 1000; ain.last_extra_day = 0
	var at: int = 1800000000
	var first_day: int = ain.daily_extra(80, at)
	var again: int = ain.daily_extra(80, at+60)
	var next_day: int = ain.daily_extra(110, at+86400)
	var restored = TwilightAinhasadService.new(); restored.import_state(JSON.parse_string(JSON.stringify(ain.export_state())))
	evidence["einasad"] = {"80":first_day,"again":again,"110":next_day,"blessing":ain.blessing,"restored_day":restored.last_extra_day,"reduction":[TwilightAinhasadService.level_reduction_percent(59),TwilightAinhasadService.level_reduction_percent(60),TwilightAinhasadService.level_reduction_percent(160)]}
	check(first_day == 50 and again == 0 and next_day == 2200 and ain.blessing == 3250 and int(restored.last_extra_day) == int(ain.last_extra_day), "ExtraRecharge once per game day: 80레벨 +50, 110레벨 +2,200 "+str(evidence.einasad))
	check(is_equal_approx(TwilightAinhasadService.level_reduction_percent(59),0.0) and is_equal_approx(TwilightAinhasadService.level_reduction_percent(60),20.0) and is_equal_approx(TwilightAinhasadService.level_reduction_percent(160),40.0), "EinasadReduction as consumption reduction %")
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.level = 59
	var saving59: float = world._blessing_consumption_reduction_percent()
	world.level = 60
	var saving60: float = world._blessing_consumption_reduction_percent()
	check(is_equal_approx(saving60-saving59, 20.0), "level 60 adds 20 % to the existing consumption reduction (%.1f → %.1f)" % [saving59,saving60])
	world.clan523.import_state({})
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else: check(CLAN.FIELDS.has("RangeEvasion"), "RangeEvasion has a consumer key without the ZIP")
	CLAN.reset_cache()
	print("CLAN523_APPROX_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
