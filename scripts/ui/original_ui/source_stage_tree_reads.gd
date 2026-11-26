extends RefCounted
## Reuse detached source node trees within one synchronous binding/staging
## call. Callers own the scratch dictionary and never pass it across a wait
## or pack replacement. The renderer still independently validates and
## creates each projected instance (roots, bindings and child state).
const MAX_MEMBERS: int=8

static func node_tree(pack: RefCounted, member: String, scratch: Dictionary) -> Dictionary:
	if scratch.has(member):return scratch[member]
	var tree: Dictionary=pack.scene(member).get("nodeTree",{})
	if scratch.size()<MAX_MEMBERS:scratch[member]=tree
	return tree
