extends SceneTree
## Original UI scenes with an explicit node scope reuse the scoped projection
## of the same pinned pack/member/scope instead of reading and pruning the
## whole member again; each scene still gets its own copy.
##   godot --headless --path <repo> --script res://tests/ui_scope_cache_test.gd
const SCENE = preload("res://scripts/ui/original_ui/sprite_scene.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("UI_SCOPE_CACHE_FAIL: " + label)

class FakePack extends RefCounted:
	var manifest: Dictionary = {}
	var manifest_sha256: String = "a".repeat(64)
	var reads: int = 0
	func scene(_member: String) -> Dictionary:
		reads += 1
		return {"nodeTree": {"_offset": 1, "classname": "Node", "options": {"name": "root"}, "children": [
			{"_offset": 2, "classname": "Sprite", "options": {"name": "kept"}, "children": []},
			{"_offset": 3, "classname": "Sprite", "options": {"name": "dropped"}, "children": []}]}}

func _scoped(pack: RefCounted, offsets: Array[int]) -> Node2D:
	var scene = SCENE.new()
	scene._requested_source_nodes = offsets
	scene.configure(pack, "UI/Test.csb", true)
	return scene

func _initialize() -> void:
	SCENE._scoped_trees.clear()
	var pack := FakePack.new()
	var first: Node2D = _scoped(pack, [2] as Array[int])
	var second: Node2D = _scoped(pack, [2] as Array[int])
	check(pack.reads == 1, "the same pinned pack/member/scope reads the member once: " + str(pack.reads))
	var other: Node2D = _scoped(pack, [3] as Array[int])
	check(pack.reads == 2, "another node scope reads its own projection")
	var cached: Array = SCENE._scoped_trees.values()[0]
	var tree: Dictionary = cached[1]
	check(tree.nodeTree.children.size() == 1 and int(tree.nodeTree.children[0]._offset) == 2, "the cached projection keeps only the requested node and its ancestors")
	var third: Node2D = _scoped(pack, [2] as Array[int])
	var handed: Variant = third.get("source_tree")
	check(pack.reads == 2 and not (handed is Dictionary and is_same(handed, tree)), "still served from the cache, as a copy")
	pack.manifest_sha256 = "b".repeat(64)
	var fourth: Node2D = _scoped(pack, [2] as Array[int])
	check(pack.reads == 3, "a different pinned manifest is read again")
	pack.manifest_sha256 = ""
	var fifth: Node2D = _scoped(pack, [2] as Array[int])
	var sixth: Node2D = _scoped(pack, [2] as Array[int])
	check(pack.reads == 5, "an unpinned pack is never cached")
	for node: Node2D in [first, second, other, third, fourth, fifth, sixth]: node.free()
	print("UI_SCOPE_CACHE_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
