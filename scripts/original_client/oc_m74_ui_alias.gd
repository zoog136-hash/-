extends RefCounted
## M74 (C04/C11/C12/C18, R74). DESIGN_NOT_RECOVERED_API. Shared UI alias lookup and node walk.
## A lookup miss returns a NON-NULL shared-empty string (one identity, 05958E48), which is not the
## same object as an existing empty value (node+40). Typed helpers turn length 0 into null.
## The dot walker follows the first exact direct child per segment: no DFS, no backtracking.
const V = preload("res://scripts/original_client/oc_m47_m81_vocab.gd")

const SHARED_EMPTY_IDENTITY := "shared_empty_string@05958E48"
const ALIAS_SURVEY_COUNT := 16881  # surveyed ASCII aliases; not a UI-completion count

## Query side effects are recorded, not hidden: the first query may initialise the singleton/read
## the file, and each query may set up the empty holder and a temporary upper-case key.
static func lookup(aliases: Dictionary, key: String, session: Dictionary) -> Dictionary:
	var effects: Array = []
	if not bool(session.get("initialised", false)):
		session["initialised"] = true
		effects.append("singleton_init_or_file_read")
	effects.append_array(["empty_holder_init", "temp_upper_key:" + key.to_upper(), "temp_key_cleanup"])
	session["queries"] = int(session.get("queries", 0)) + 1
	var upper: String = key.to_upper()
	if aliases.has(upper):
		return {"value": str(aliases[upper]), "identity": "node+40:" + upper, "nonnull": true, "effects": effects}
	return {"value": "", "identity": SHARED_EMPTY_IDENTITY, "nonnull": true, "effects": effects}

## 00BFDAC0 / selected 70 binding: length 0 -> null.
static func typed_text(lookup_result: Dictionary) -> Variant:
	return null if str(lookup_result.value).length() == 0 else lookup_result.value

## node: {"name", "children": [...]}
static func walk(root: Variant, dotted: String) -> Variant:
	if root == null:
		return null
	var cur: Dictionary = root
	for seg: String in dotted.split("."):
		var next: Variant = null
		for child: Dictionary in cur.get("children", []):
			if child.name == seg:
				next = child
				break
		if next == null:
			return null
		cur = next
	return cur

## Non-empty alias: the second query happens and only then is root checked (root null -> null).
static func resolve_alias_node(aliases: Dictionary, root: Variant, key: String, session: Dictionary) -> Dictionary:
	var first: Dictionary = lookup(aliases, key, session)
	if typed_text(first) == null:
		return V.rec("AliasNode", "M74", V.CONFIRMED, {"node": null, "queries": 1, "side_effects_happened": true})
	var second: Dictionary = lookup(aliases, key, session)
	if root == null:
		return V.rec("AliasNode", "M74", V.CONFIRMED, {"node": null, "queries": 2, "root_checked_after_second_query": true})
	return V.rec("AliasNode", "M74", V.CONFIRMED, {"node": walk(root, str(second.value)), "queries": 2, "root_checked_after_second_query": true})

## Detach happens before the Layout cast; the returned pointer is borrowed (no new retain).
static func detach_then_layout_cast(node: Dictionary, class_chain: Array) -> Dictionary:
	var trace: Array = ["detach_from_parent", "cast_to_Layout"]
	return {"trace": trace, "layout": node if "Layout" in class_chain else null, "detached": true, "retained": false}
