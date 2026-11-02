extends SceneTree
const Items=preload("res://scripts/cards/source_awakening_items.gd")
const Skill=preload("res://scripts/cards/skill_awakening_service.gd")
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var catalog: Dictionary={"아이템":[]};Skill.install_book_definitions(catalog)
	check(catalog["아이템"].size()==5,"five definitions without ownership")
	var holder:=Control.new();root.add_child(holder)
	var bag=preload("res://scripts/ui/lineage_inventory_ui.gd").new();holder.add_child(bag)
	bag.set_catalog_data(catalog,{})
	for record: Dictionary in catalog["아이템"]:
		var visuals: Script=preload("res://scripts/ui/item_visual_resolver.gd")
		check(visuals.describe(record,record.name).status=="original_icon_not_installed" and visuals.texture(record,record.name)==null,"missing original icon is explicit without substitute "+record.name)
		check(visuals.describe(record,record.name,{},true).route=="source_original_unavailable","floor cannot replace missing original with category art "+record.name)
		check(Items.recognized(JSON.parse_string(JSON.stringify(record))),"source provenance survives JSON numeric normalization "+record.name)
		var old: Dictionary={"1":{"name":"legacy unrelated","level":7}}
		var drop: Dictionary={"item_name":record.name,"quantity":2,"item_record":record}
		var result: Dictionary=Items.prepare_pickup(drop,old,1)
		check(result.created==2 and result.item_instances.size()==3 and result.next_item_instance_id==4,"new acquisition exact provenance "+record.name)
		check(old.size()==1 and result.item_instances["2"].record.sourceId==record.sourceId,"no backfill or input mutation "+record.name)
		bag.set_character_state({"item_instances":result.item_instances});bag.set_inventory({record.name:5})
		var entries: Array=bag._inventory_entries()
		check(entries.size()==1 and entries[0].amount==5 and entries[0].reference==record.name,"verified plus legacy counts stay one original stack "+record.name)
		check(record.grade in ["희귀","영웅","전설","신화","유일"],"localized source grade "+record.name)
		var name_only: Dictionary=drop.duplicate(true);name_only.erase("item_record")
		check(Items.prepare_pickup(name_only,old,1).created==0,"old name-only ground save remains unverified "+record.name)
		var restored: Dictionary=drop.duplicate(true);restored.physical_item={"id":"2"}
		check(Items.prepare_pickup(restored,old,1).created==0,"restored physical item not duplicated "+record.name)
		var wrong: Dictionary=drop.duplicate(true);wrong.item_record.sourceId="legacy alias"
		check(Items.prepare_pickup(wrong,old,1).created==0,"name cannot establish source ownership "+record.name)
	var count: int=catalog["아이템"].size();Skill.install_book_definitions(catalog)
	check(catalog["아이템"].size()==count,"definitions idempotent")
	holder.queue_free();await process_frame
	print("SOURCE_AWAKENING_PICKUP ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
