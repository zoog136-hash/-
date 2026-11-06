extends RefCounted
## Preparation-only capability from the actual data-owner batch result.
## It cannot admit a live actor, publish a catalog, or authorize travel.
const BATCH=preload("res://scripts/monsters/current523_npc_batch.gd")
const POLICY=preload("res://scripts/monsters/patch523_spawn_policy.gd")
var _receipt: Dictionary={}
var _world: WeakRef
var _field: WeakRef
var _population: WeakRef
var _catalog: WeakRef
var _definition: RefCounted

func configure(receipt: Dictionary, world: Node, field: RefCounted, definition: RefCounted, population: Node) -> bool:
	if not _receipt.is_empty() or not is_instance_valid(world) or not is_instance_valid(field) or not is_instance_valid(population):return false
	var service: Variant=world.get("patch523_npc_spells")
	var catalog: Variant=service.get("catalog") if service is Object else null
	var candidate: Variant=receipt.get("candidate")
	var selection: Variant=receipt.get("selection")
	if not catalog is RefCounted or not candidate is RefCounted or candidate.get_script()!=BATCH or not selection is Dictionary:return false
	if receipt.get("ok")!=true or receipt.get("catalog_changed")!=false or receipt.get("spawn_authorized")!=false or not receipt.get("records") is Array or receipt.records.is_empty():return false
	if receipt.get("source_identity")!=catalog.get("source_identity") or receipt.get("previous_model_sha256")!=catalog.get("source_model_sha256"):return false
	if selection.get("field_instance_id")!=field.get_instance_id() or selection.get("land")!=field.get("native_land") or selection.get("asset_path")!=field.get("source_asset") or selection.get("host_map_id")!=field.get("data").get("map_id"):return false
	if selection.get("combat_generation")!=world.get("combat_generation") or selection.get("population_generation")!=population.get("generation"):return false
	if definition==null or definition.get("land")!=selection.land or selection.get("geographic_contract")!=field.call("source_geographic_contract"):return false
	_receipt=receipt.duplicate(true);_world=weakref(world);_field=weakref(field);_population=weakref(population);_catalog=weakref(catalog);_definition=definition
	return true

func accepts(actor: Node, record: Dictionary, player: Node, supplied_world: Node) -> bool:
	if _receipt.is_empty() or supplied_world!=null or not is_instance_valid(actor) or actor.is_inside_tree() or actor.get_parent()!=null or actor.get("world_controller")!=null:return false
	var world: Node=_world.get_ref()
	var field: RefCounted=_field.get_ref()
	var population: Node=_population.get_ref()
	var catalog: RefCounted=_catalog.get_ref()
	if not is_instance_valid(world) or not is_instance_valid(field) or not is_instance_valid(population) or not is_instance_valid(catalog) or player!=world.get("player"):return false
	if catalog.get("source_identity")!=_receipt.source_identity or catalog.get("source_model_sha256")!=_receipt.previous_model_sha256 or catalog.get("source_available")!=true:return false
	if world.get("combat_generation")!=_receipt.selection.combat_generation or population.get("generation")!=_receipt.selection.population_generation:return false
	if field.call("source_geographic_contract")!=_receipt.selection.geographic_contract or not _receipt.records.has(record):return false
	return record.get("source_m_current523_final")==true and record.get("source_m_runtime_host_map")==_receipt.selection.host_map_id

func host_map_id() -> String:
	return str(_receipt.get("selection",{}).get("host_map_id",""))

func admission(record: Dictionary) -> Dictionary:
	# Existing original encounter guard, using the explicit target definition.
	# No live catalog or source actor identity is manufactured for the renderer.
	return POLICY.admit(record,host_map_id(),_definition)

func prepared_model_sha256() -> String:
	return str(_receipt.get("prepared_model_sha256",""))
