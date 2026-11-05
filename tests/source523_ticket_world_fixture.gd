extends "res://scripts/world.gd"
## Contract-only issuer ledger. This does not run or duplicate expedition logic.
class Issuer extends RefCounted:
	var state:Dictionary={"issued":{}}
var expedition_local=Issuer.new()
func _ready() -> void:
	super._ready()
	var previous:Variant=equipment_collections.extra_save_fields.get("qa_ticket_issuer_contract",{})
	if previous is Dictionary and previous.get("issued") is Dictionary:expedition_local.state=previous.duplicate(true)
	install_proof_definitions()

func install_proof_definitions() -> void:
	# Recreate only the documented issuer record shape, never inventory or cards.
	for key:String in expedition_local.state.issued:
		var parts:PackedStringArray=key.split(":")
		if parts.size()!=3 or not parts[0].is_valid_int():continue
		var spec:Dictionary=source_shop.inventory_tickets.document.get("tickets",{}).get(parts[0],{})
		if spec.is_empty():continue
		var name:String=str(expedition_local.state.issued[key])
		if not _find_catalog_item_record(name).is_empty():continue
		catalog_db["아이템"].append({"name":name,"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:expedition:"+key,"source_item_class_id":int(parts[0]),"source_item":spec.original_item.duplicate(true),"expedition_key":key,"slot":"material","type":"탐험 보상","grade":"일반","weight":0})
	_index_item_weights()
func _save_game(quiet:bool,override:Dictionary={}) -> Error:
	equipment_collections.extra_save_fields["qa_ticket_issuer_contract"]=expedition_local.state.duplicate(true)
	return super._save_game(quiet,override)
