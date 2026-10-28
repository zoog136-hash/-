extends SceneTree

class SkillWorld extends Node:
	var job_class: String="기사"
	var equipped_items: Dictionary={}
	var level: int=1
	var weight: int=0
	func _current_weapon_type() -> String:
		return str((equipped_items.get("weapon",{}) as Dictionary).get("type",""))
	func _inventory_total_weight() -> int:return weight
	func _carrying_capacity() -> int:return 100

func _initialize() -> void:
	call_deferred("run")

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
	print("SKILL_STATIC_INDEX_RESULT ",JSON.stringify({"failures":failures,"rebuilds":catalog.stat_rebuild_count,"repeated_queries":40}))
	quit(0 if failures.is_empty() else 1)
