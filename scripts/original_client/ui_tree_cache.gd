extends RefCounted
## C18 / P5. DESIGN_NOT_RECOVERED_API. CSB tree load, exclusion sets, prototype cache and
## UI lifetime operations. Hiding is not detaching, destructing or unsubscribing.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

var cache: Dictionary = {}
var parses: int = 0

static func make_handle(csb_path: String, node_type: String, node_path: String, callback_mode: String, exclusions: Array, prototype_mode: bool, owner_generation: int) -> Dictionary:
	return {"record": "UiTreeHandle", "design_status": VOCAB.EVIDENCE_DESIGN, "csb_path": csb_path, "node_type": node_type, "node_path": node_path,
		"callback_mode": callback_mode, "exclusions": exclusions.duplicate(), "prototype_mode": prototype_mode, "owner_generation": owner_generation}

## A non-null wrapper callback bypasses the cache. Without a callback the key is (path, "")
## plus the prototype-mode selector; the exclusion set, CRC, mtime and version are NOT part
## of the key, so a different set can still hit an older parse.
static func cache_key(csb_path: String, has_callback: bool, prototype_mode: bool) -> Variant:
	if has_callback:
		return null
	return "%s|%s|%s" % [csb_path, "", str(prototype_mode)]

## tree: {"name","type":"Node"|"ProjectNode","ref_path","children":[...],"referenced": <tree or null>}
## An excluded ProjectNode reference makes that node (and its branch) null. A referenced CSB
## that cannot be loaded becomes an empty Node, which is a different thing from null.
## A nested, different CSB file is parsed with a NEW EMPTY exclusion set.
func parse(tree: Dictionary, exclusions: Array) -> Variant:
	parses += 1
	if tree.get("type") == "ProjectNode":
		if str(tree.get("ref_path", "")) in exclusions:
			return null
		var referenced: Variant = tree.get("referenced")
		if referenced is Dictionary:
			var nested: Variant = parse(referenced, [])
			return {"name": tree.get("name"), "type": "ProjectNode", "ref_path": tree.get("ref_path"), "children": [nested] if nested != null else []}
		return {"name": tree.get("name"), "type": "Node", "fallback": "empty_node", "ref_path": tree.get("ref_path"), "children": []}
	var children: Array = []
	for child: Variant in tree.get("children", []):
		var parsed: Variant = parse(child, exclusions)
		if parsed != null:
			children.append(parsed)
	return {"name": tree.get("name"), "type": tree.get("type", "Node"), "children": children}

func load_tree(csb_path: String, tree: Dictionary, exclusions: Array, has_callback: bool, prototype_mode: bool) -> Dictionary:
	var key: Variant = cache_key(csb_path, has_callback, prototype_mode)
	if key != null and cache.has(key):
		return {"tree": cache[key], "cache_hit": true, "parsed_with_exclusions": null}
	var parsed: Variant = parse(tree, exclusions)
	if key != null:
		cache[key] = parsed
	return {"tree": parsed, "cache_hit": false, "parsed_with_exclusions": exclusions.duplicate()}

## Separate operations with separate effects. input_capture_released is never implied by hide.
static func lifetime_operation(operation: String) -> Dictionary:
	var effects := {
		"hide": {"visible": false, "attached": true, "destructed": false, "unsubscribed": false, "input_capture_released": false},
		"detach": {"visible": false, "attached": false, "destructed": false, "unsubscribed": false, "input_capture_released": false},
		"unsubscribe": {"visible": true, "attached": true, "destructed": false, "unsubscribed": true, "input_capture_released": false},
		"destruct": {"visible": false, "attached": false, "destructed": true, "unsubscribed": true, "input_capture_released": true},
	}
	return effects.get(operation, {})

## A sweep only reclaims prototypes whose reference count is exactly 1.
static func sweep(prototypes: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	var removed: Array = []
	for key: Variant in prototypes:
		if int(prototypes[key].refcount) == 1:
			removed.append(key)
		else:
			kept[key] = prototypes[key]
	return {"kept": kept, "removed": removed}
