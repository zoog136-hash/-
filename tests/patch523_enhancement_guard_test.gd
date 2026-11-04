extends SceneTree
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")
class SyntheticBook extends RefCounted:
	var data: Dictionary={"items":{"101":{}}}
	func catalog_identity_matches(record: Dictionary,_id: String) -> bool:return record.get("name")=="synthetic"
func _initialize() -> void:
	var book:=SyntheticBook.new()
	var record: Dictionary={"source":"inven","sourceId":"101","name":"synthetic"}
	var checks: Array=[
		ENHANCE.rule(book,record,"138",0,-1,1).get("success",-1)==0.0,
		ENHANCE.rule(book,record,"138",0,1,3).get("success",-1)==0.0,
		ENHANCE.rule(book,{"source":"inven","sourceId":"101","name":"conflict"},"138",0,1,1).get("success",-1)==0.0,
		ENHANCE.prepare(book,record,-1)==record]
	print("PATCH523_ENHANCEMENT_GUARDS ",JSON.stringify({"checks":checks.size(),"passed":checks.count(true),"scope":"synthetic rejection paths only"}))
	quit(0 if checks.count(true)==checks.size() else 1)
