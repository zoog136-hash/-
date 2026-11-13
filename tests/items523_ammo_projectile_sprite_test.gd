extends SceneTree
## Original 523 ammo projectile sprites on the existing normal ranged flight
## (actual Main): flight sprite = weapon AmmoEffectSpriteIDByWeapon > ammo
## AmmoEffectSpriteID > WeaponType.DefaultAmmoEffectSpriteID, explosion = ammo
## AmmoExplosionSpriteID > WeaponType.DefaultAmmoExplosionSpriteID. The flight
## keeps its hit callback; without an original sprite the existing line stays.
const SELECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
const FLIGHT = preload("res://scripts/animation/current523_ammo_flight.gd")
const F = preload("res://scripts/loot/current523_native_fields.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_AMMO_SPRITE_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(SELECT.AMMO_STAGES.flight==["AmmoEffectSpriteIDByWeapon","AmmoEffectSpriteID","DefaultAmmoEffectSpriteID"] and SELECT.AMMO_STAGES.explosion[1]=="AmmoExplosionSpriteID", "flight/explosion field order")
	check(not SELECT.ammo_sprite({},[],"flight").get("ok",true) and not SELECT.ammo_sprite({"ID":1},[],"other").get("ok",true), "incomplete requests are refused")
	check(FLIGHT._facing(Vector2.RIGHT)==0 and FLIGHT._facing(Vector2.DOWN)==2 and FLIGHT._facing(Vector2.LEFT)==4, "flight direction -> host facing8")

func row(world: Node, id: int) -> Dictionary:
	return F.full(world._catalog_item_from_source_id("m523:item:"+str(id))).get("source_original_item",{})

func scan(world: Node) -> Dictionary:
	var picks: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item")!=true or not D.equipment(record): continue
		var full: Dictionary = F.full(record)
		var kind: String = str(full.get("source_weapon_type_name",""))
		var id: int = int(record.source_item_class_id)
		if kind in ["Bow","Gauntlet","Rifle"] and not picks.has(kind) and id not in [357611,362411]: picks[kind] = id
		if "Quiver" in full.get("source_equip_slots",[]) and str(full.get("source_display_name","")).contains("화살") and not picks.has("quiver"): picks["quiver"] = id
	return picks

func select(world: Node, weapon: int, ammo: Array, stage: String) -> Dictionary:
	var rows: Array = []
	for id: int in ammo: rows.append(row(world,id))
	return SELECT.ammo_sprite(row(world,weapon),rows,stage)

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var picks: Dictionary = scan(world)
	evidence["picks"] = picks
	if not check(picks.has("Bow") and picks.has("Gauntlet") and picks.has("Rifle") and picks.has("quiver"), "native bow/gauntlet/rifle/quiver arrow found"): return
	var bow: Dictionary = select(world,picks.Bow,[],"flight")
	check(bow.get("ok",false) and int(bow.sprite_id)==66 and bow.source_reference.field=="WeaponType.DefaultAmmoEffectSpriteID", "bow #%d flies WeaponType default sprite 66 (%s)" % [picks.Bow,str(bow.get("reason",""))])
	var quiver: Dictionary = select(world,picks.Bow,[picks.quiver],"flight")
	check(quiver.get("ok",false) and int(quiver.sprite_id)==66 and quiver.source_reference.field=="AmmoEffectSpriteID", "worn arrow #%d supplies AmmoEffectSpriteID 66" % picks.quiver)
	var girtas: Dictionary = select(world,362411,[picks.quiver],"flight")
	check(girtas.get("ok",false) and int(girtas.sprite_id)==29554 and girtas.source_reference.field=="AmmoEffectSpriteIDByWeapon", "Girtas bow #362411 flies its own 29554")
	var sting: Dictionary = select(world,picks.Gauntlet,[],"flight")
	check(sting.get("ok",false) and int(sting.sprite_id)==2989, "gauntlet #%d flies sting sprite 2989" % picks.Gauntlet)
	var gun_flight: Dictionary = select(world,picks.Rifle,[],"flight")
	var gun_blast: Dictionary = select(world,picks.Rifle,[],"explosion")
	check(not gun_flight.get("ok",true) and str(gun_flight.reason)=="current523_ammo_effect_source_sprite_absent", "rifle has no original flight sprite (existing line kept)")
	check(gun_blast.get("ok",false) and int(gun_blast.sprite_id)==16430, "rifle #%d hit explosion 16430 one-shot" % picks.Rifle)
	evidence["selected"] = {"bow":bow.get("sprite_id"),"quiver":quiver.get("sprite_id"),"girtas":girtas.get("sprite_id"),"sting":sting.get("sprite_id"),"gun_explosion":gun_blast.get("sprite_id")}
	# Real flight with the bow equipped: original node follows, the hit still lands once.
	# A map open still finishing after entry clears in-flight actions; let it settle.
	for frame: int in range(240): await process_frame
	for weapon: int in [picks.Bow,picks.Rifle]:
		world.equipped_items.clear(); world._invalidate_equipment_static()
		world.equipped_items["weapon"] = world._catalog_item_from_source_id("m523:item:"+str(weapon)).duplicate(true)
		world._invalidate_equipment_static()
		var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(monster)
		monster.setup({"name":"과녁","hp":100,"atk":1,"speed":0,"drop":[]},world.player,world,null)
		monster.set_physics_process(false)
		monster.global_position = world.player.global_position+Vector2(220,0)
		var origin: Vector2 = world.player.combat_projectile_origin()
		var options: Dictionary = FLIGHT.options(world,origin,monster)
		var hits: Array = [0]
		var seen: Dictionary = {"visual":false,"frame":false}
		world.combat_flights.launch(origin,monster,"ranged",func() -> void: hits[0] += 1,1300.0,0.0,options)
		seen["flights_after_launch"] = world.combat_flights.flights.size()
		seen["monster"] = {"dead":monster.dead,"in_tree":monster.is_inside_tree(),"distance":origin.distance_to(monster.combat_hit_position())}
		for frame: int in range(90):
			await physics_frame
			for flight: Dictionary in world.combat_flights.flights:
				if bool(flight.get("visual_active",false)): seen.visual = true
			for child: Node in world.combat_flights.get_children():
				if child.get("_reference_bank")!=null and child.get("_is_overlay"): seen.frame = true
			if hits[0]>0 and not seen.has("blasts_at_hit"):
				var at_hit: int = 0
				for child: Node in world.combat_flights.get_children():
					if child.get("_reference_bank")!=null and int(child.get("reference_bank_status").get("source_actor_id",0))==16430: at_hit += 1
				seen["blasts_at_hit"] = at_hit
			if hits[0]>0 and frame>40: break
		var blasts: int = 0
		for child: Node in world.combat_flights.get_children():
			if child.get("_reference_bank")!=null and int(child.get("reference_bank_status").get("source_actor_id",0))==16430: blasts += 1
		if weapon==picks.Bow:
			check(not options.is_empty() and seen.visual and seen.frame and hits[0]==1, "bow shot: original 66 overlay drew the flight and the hit landed once (%s)" % JSON.stringify(FLIGHT.last_status.get("flight",{}).get("reason","")))
		else:
			check(not options.is_empty() and not seen.visual and hits[0]==1 and int(seen.get("blasts_at_hit",0))==1, "rifle shot keeps the existing line, lands once and plays the original 16430 explosion at the hit (%s)" % JSON.stringify(FLIGHT.last_status.get("explosion",{}).get("reason","")))
		monster.queue_free()
		evidence["flight_%d" % weapon] = {"options":not options.is_empty(),"visual":seen.visual,"hits":hits[0],"blasts_at_hit":seen.get("blasts_at_hit",0),"blasts_after":blasts,"debug":seen,"status":FLIGHT.last_status.duplicate(true)}
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEMS523_AMMO_SPRITE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
