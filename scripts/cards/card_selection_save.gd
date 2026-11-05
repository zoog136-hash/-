extends RefCounted
## Scoped save ownership for existing validated primary/secondary selections.
## No cost, reward, eligibility or cap rules live here.
var _candidate: Dictionary = {}

func authorizes(staged: Dictionary) -> bool:
	return not _candidate.is_empty() and staged == _candidate

func commit(world: Node, quiet: bool, staged: Dictionary) -> Error:
	if not _candidate.is_empty(): return ERR_BUSY
	var owners: int = int(staged.has("equipped_catalog")) + int(staged.has("card_option_awakening"))
	if owners != 1 or not staged.has("hp") or not staged.has("mp") or staged.size() != 3: return ERR_INVALID_PARAMETER
	var key: String = "equipped_catalog" if staged.has("equipped_catalog") else "card_option_awakening"
	if not staged[key] is Dictionary: return ERR_INVALID_PARAMETER
	for vital: String in ["hp","mp"]:
		var value: Variant = staged[vital]
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0: return ERR_INVALID_PARAMETER
	_candidate = staged.duplicate(true)
	var result: Error = world._save_game(quiet, staged)
	_candidate.clear()
	return result
