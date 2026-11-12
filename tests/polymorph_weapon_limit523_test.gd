extends SceneTree
## PolymorphEntityWeaponLimit: equip/attack checks for the equipped original
## transform. Without the held original archive no restriction applies.
const LIMIT = preload("res://scripts/cards/polymorph_weapon_limit523.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var real: Dictionary = {}

class StubWorld extends Node:
	var equipped_catalog: Dictionary = {"변신": {}, "마법인형": {}, "성물": {}}
	var weapon: Dictionary = {}
	var class_id: int = 2
	var gender_id: int = 2
	func _source_visual_context() -> Dictionary: return {"class_id":class_id, "gender_id":gender_id, "active_card_options":{}}
	func _equipped_weapon_record() -> Dictionary: return weapon

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run() -> void:
	var world := StubWorld.new()
	root.add_child(world)
	var bow: Dictionary = {"name":"시험 활", "slot":"weapon", "type":"활"}
	var sword: Dictionary = {"name":"시험 한손검", "slot":"weapon", "type":"한손검"}
	var rifle: Dictionary = {"name":"시험 라이플", "slot":"weapon", "type":"라이플"}
	check(LIMIT.weapon_type_id(bow) == 3 and LIMIT.weapon_type_id(sword) == 1 and LIMIT.weapon_type_id(rifle) == 34 and LIMIT.weapon_type_id({}) == 0, "weapon types use the reviewed local mapping")
	check(LIMIT.equip_reason(world, sword).is_empty() and LIMIT.attack_reason(world).is_empty(), "no transform: no restriction")
	world.equipped_catalog["변신"] = {"name":"로컬 변신", "source":"local"}
	check(LIMIT.equip_reason(world, bow).is_empty(), "non-original transform: no restriction")
	if not DEF.identity().is_empty():
		var ranged: Dictionary = {}
		var melee: Dictionary = {}
		var unlimited: Dictionary = {}
		var scanned: int = 0
		for card: Dictionary in DEF.rows("BuffCard"):
			if int(card.get("BuffCardDeckID", -1)) != 1: continue
			scanned += 1
			var found: Dictionary = LIMIT.entities_for_card(int(card.ID), world.class_id, world.gender_id)
			if not found.ok or (found.entities as Array).size() != 1: continue
			var allowed: Array = LIMIT.allowed_types(int(found.entities[0]))
			var entry: Dictionary = {"card":int(card.ID), "entity":int(found.entities[0]), "allowed":allowed}
			if ranged.is_empty() and allowed == [3, 10, 34, 54]: ranged = entry
			elif melee.is_empty() and allowed.has(1) and not allowed.has(3): melee = entry
			elif unlimited.is_empty() and allowed.is_empty(): unlimited = entry
			if not ranged.is_empty() and not melee.is_empty() and not unlimited.is_empty(): break
		real["scanned_cards"] = scanned
		check(not ranged.is_empty() and not melee.is_empty(), "original ranged and melee forms exist")
		if not ranged.is_empty():
			world.equipped_catalog["변신"] = {"name":"원거리형", "source":"lineagem_patch523", "sourceId":"m523:test", "source_card_id":ranged.card}
			var rule: Dictionary = LIMIT.status(world)
			check(rule.active and rule.allowed == [3, 10, 34, 54], "ranged form rule is active")
			check(LIMIT.equip_reason(world, bow).is_empty() and LIMIT.equip_reason(world, rifle).is_empty(), "ranged form allows bow and rifle")
			var rejected: String = LIMIT.equip_reason(world, sword)
			check(not rejected.is_empty(), "ranged form rejects one-handed sword")
			world.weapon = sword
			check(LIMIT.attack_reason(world) == rejected, "attack with a held sword is rejected")
			world.weapon = {}
			check(LIMIT.attack_reason(world).is_empty(), "bare hands are never blocked")
			real["ranged"] = ranged.merged({"sword":rejected})
		if not melee.is_empty():
			world.equipped_catalog["변신"] = {"name":"근거리형", "source":"lineagem_patch523", "sourceId":"m523:test2", "source_card_id":melee.card}
			check(LIMIT.equip_reason(world, sword).is_empty() and not LIMIT.equip_reason(world, bow).is_empty(), "melee form allows sword, rejects bow")
			real["melee"] = melee.merged({"bow":LIMIT.equip_reason(world, bow)})
		if not unlimited.is_empty():
			world.equipped_catalog["변신"] = {"name":"제한 없음", "source":"lineagem_patch523", "sourceId":"m523:test3", "source_card_id":unlimited.card}
			check(LIMIT.equip_reason(world, bow).is_empty() and LIMIT.equip_reason(world, sword).is_empty(), "entity without rows imposes nothing")
			real["unlimited"] = unlimited
		# Unknown class/gender context resolves no entity: no restriction.
		world.class_id = 0
		check(LIMIT.equip_reason(world, sword).is_empty(), "unknown class context imposes nothing")
	else:
		world.equipped_catalog["변신"] = {"name":"원본 변신", "source":"lineagem_patch523", "sourceId":"m523:test", "source_card_id":1}
		check(LIMIT.equip_reason(world, sword).is_empty(), "absent archive imposes nothing")
		real["archive"] = "absent"
	print("POLYMORPH_WEAPON_LIMIT523_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
	quit(0 if failures.is_empty() else 1)
