extends SceneTree
const Authority = preload("res://scripts/cards/card_selection_save.gd")
const Boundary = preload("res://scripts/crafting/patch523_owner_transactions.gd")
class Host extends Node:
	var card_selection_saves = Authority.new()
	var writes: int = 0
	var outcome: Error = OK
	var scoped_owner: String = ""
	var altered_rejected: bool = false
	var nested_rejected: bool = false
	func _save_game(_quiet: bool, staged: Dictionary) -> Error:
		writes += 1
		scoped_owner = Boundary.nonquest_vital_owner(self,staged)
		var altered: Dictionary = staged.duplicate(true); altered.hp += 1
		altered_rejected = not card_selection_saves.authorizes(altered)
		nested_rejected = card_selection_saves.commit(self,true,staged) == ERR_BUSY
		return outcome
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("CARD_SELECTION_SAVE_FAIL ",message)
func _initialize() -> void:
	var host := Host.new()
	for key: String in ["equipped_catalog","card_option_awakening"]:
		var staged: Dictionary = {key:{"selection":"source identity"},"hp":15,"mp":10}
		var before: Dictionary = staged.duplicate(true)
		check(not host.card_selection_saves.authorizes(staged),"unscoped snapshot rejected " + key)
		for result: Error in [OK,ERR_CANT_CREATE]:
			host.outcome = result
			var count: int = host.writes
			check(host.card_selection_saves.commit(host,true,staged) == result,"actual writer result preserved " + key)
			check(host.writes == count+1 and host.scoped_owner == "card_owner","one writer call with exact owner " + key)
			check(host.altered_rejected and host.nested_rejected,"altered and reentrant candidates rejected " + key)
			check(not host.card_selection_saves.authorizes(staged),"success/failure always clears authority " + key)
			check(staged == before,"input snapshot preserved " + key)
	for staged: Dictionary in [{"hp":10,"mp":10},{"equipped_catalog":{},"hp":10,"mp":10,"gold":5},{"equipped_catalog":{},"hp":10,"mp":10,"level":90},{"equipped_catalog":{},"card_option_awakening":{},"hp":10,"mp":10},{"equipped_catalog":{},"hp":NAN,"mp":10},{"card_option_awakening":{},"hp":10.5,"mp":10},{"equipped_catalog":"bad","hp":10,"mp":10}]:
		var count: int = host.writes
		check(host.card_selection_saves.commit(host,true,staged) == ERR_INVALID_PARAMETER and host.writes == count,"unrelated/malformed transaction never reaches writer")
	check(not host.card_selection_saves.authorizes({"equipped_catalog":{},"hp":15,"mp":10}),"no authority survives rejected request")
	host.free()
	print("CARD_SELECTION_SAVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
