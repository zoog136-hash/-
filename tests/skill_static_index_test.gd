extends SceneTree

class CollectionState extends RefCounted:
	func source_server_context() -> Dictionary:
		return {}

class DrawState extends RefCounted:
	var owned: Dictionary = {}

class SkillWorld extends Node:
	var job_class: String="기사"
	var equipped_items: Dictionary={}
	var equipped_catalog: Dictionary = {}
	var item_instances: Dictionary = {}
	var card_draw_fusion := DrawState.new()
	var card_collections := CollectionState.new()
	var level: int=1
	var weight: int=0
	func _current_weapon_type() -> String:
		return str((equipped_items.get("weapon",{}) as Dictionary).get("type",""))
	func _equipped_weapon_record() -> Dictionary:
		return equipped_items.get("weapon", {})
	func _inventory_total_weight() -> int:return weight
	func _carrying_capacity() -> int:return 100

class ObservedCatalog extends TwilightOriginalSkillCatalog:
	var ownership_checks: Array[String] = []
	var projections: Array[String] = []
	func owned(record: Dictionary) -> bool:
		ownership_checks.append(str(record.id))
		return super.owned(record)
	func _resolve_uncached(record: Dictionary) -> Dictionary:
		projections.append(str(record.id))
		return super._resolve_uncached(record)

func _initialize() -> void:
	call_deferred("run")

func check_upgrades(owner: SkillWorld, failures: Array[String]) -> void:
	var catalog := ObservedCatalog.new()
	catalog.world = owner
	owner.job_class = "기사"
	var base: Dictionary = {"id":"base", "class":"기사", "mode":"stats", "stats":{"atk":3}}
	var earlier: Dictionary = {"id":"earlier", "class":"기사", "mode":"upgrade", "grade":"희귀"}
	var later: Dictionary = {"id":"later", "class":"기사", "mode":"upgrade", "grade":"영웅"}
	var sibling: Dictionary = {"id":"sibling", "class":"기사", "mode":"upgrade", "grade":"고급"}
	var unrelated: Dictionary = {"id":"unrelated", "class":"기사", "mode":"buff"}
	var equipment: Dictionary = {"id":"equipment", "class":"기사", "mode":"upgrade", "grade":"전설", "equipment_spell523":78}
	catalog.records = [later, base, unrelated, sibling, earlier, equipment]
	for row: Dictionary in catalog.records:
		catalog.by_id[row.id] = row
	catalog.relations = {
		"earlier":{"upgrades_from":"base", "patch":{"stats":{"atk":7}}},
		"later":{"upgrades_from":"earlier", "patch":{"stats":{"atk":11}}},
		"sibling":{"upgrades_from":"base", "patch":{"stats":{"atk":5}}},
		"equipment":{"upgrades_from":"later", "patch":{"stats":{"atk":14}}},
	}
	catalog.learned = {"base":1, "earlier":1, "later":1, "sibling":1, "unrelated":1}
	catalog.source523.equip_spell_items = {78:{92:true}}
	var resolved: Dictionary = catalog.resolve(base)
	if int(resolved.stats.atk) != 11 or resolved.relic_resolved_id != "later":
		failures.append("ordered upgrade passes and last active tier changed")
	if catalog.ownership_checks.has("unrelated"):
		failures.append("resolving a lineage inspected unrelated skill ownership")
	if catalog.stat("atk") != 11.0:
		failures.append("static index lost upgraded stats")
	if catalog.projections.has("unrelated"):
		failures.append("static index fully projected a cast-only buff")
	owner.equipped_items = {"weapon":{"source_item_class_id":92}}
	if catalog.stat("atk") != 14.0 or catalog.resolve(base).relic_resolved_id != "equipment":
		failures.append("static index or lineage omitted unlearned equipment grant")
	owner.equipped_items.clear()
	catalog.learned.erase("earlier")
	if catalog.stat("atk") != 5.0 or catalog.resolve(base).relic_resolved_id != "sibling":
		failures.append("removing a parent left an unreachable descendant active")
	catalog.relations.sibling = {"upgrades_from":"unrelated", "patch":{"mode":"stats", "stats":{"weight":2}}}
	catalog.revision += 1
	if catalog.stat("weight") != 2.0:
		failures.append("an upgrade can turn a non-stat base into a passive")

func run() -> void:
	var failures: Array[String]=[]
	var owner:=SkillWorld.new()
	root.add_child(owner)
	var catalog:=TwilightOriginalSkillCatalog.new()
	catalog.world=owner
	var record: Dictionary={"id":"fixture","class":"기사","classes":["기사"],"mode":"stats",
		"weapons":["staff"],"stats":{"atk":3,"speed":1.1,"weight_bonus":5},
		"stat_conditions":{"weight_bonus":{"weight_min_percent":50}}}
	catalog.records=[record]
	catalog.by_id={"fixture":record}
	catalog.learned={"fixture":1}
	if catalog.stat("atk")!=0.0:failures.append("weapon condition ignored")
	owner.equipped_items={"weapon":{"type":"staff"}}
	if catalog.stat("atk")!=3.0:failures.append("weapon invalidation")
	var rebuilds: int=catalog.stat_rebuild_count
	for _i: int in range(40):catalog.stat("atk")
	if catalog.stat_rebuild_count!=rebuilds:failures.append("unchanged static stats rebuilt")
	if catalog.stat("weight_bonus")!=0.0:failures.append("weight gate ignored")
	owner.weight=60
	if catalog.stat("weight_bonus")!=5.0 or catalog.stat_rebuild_count!=rebuilds:failures.append("dynamic weight frozen or static cache rebuilt")
	var editable: Dictionary=catalog.resolve(record)
	editable.stats.atk=99
	if int(catalog.resolve(record).stats.atk)!=3:failures.append("cached lineage exposed to mutation")
	catalog.learned.clear()
	if catalog.stat("atk")!=0.0:failures.append("direct learned change ignored")
	catalog.learned["fixture"]=1
	owner.job_class="마법사"
	if catalog.stat("atk")!=0.0:failures.append("class change ignored")
	check_upgrades(owner, failures)
	print("SKILL_STATIC_INDEX_RESULT ",JSON.stringify({"failures":failures,"rebuilds":catalog.stat_rebuild_count,"repeated_queries":40}))
	quit(0 if failures.is_empty() else 1)
