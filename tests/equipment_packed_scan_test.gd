extends SceneTree
## Frozen main 28f308 packed-store oracle. Every fetched row/field compared,
## including shape changes, interning boundary, loose aliases and clear reuse.
const CURRENT = preload("res://scripts/crafting/patch523_packed_records.gd")
const OLD = preload("res://tests/fixtures/equipment_scan_legacy/packed_records.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)
func equal(a: Variant,b: Variant) -> bool:
	return typeof(a) == typeof(b) and var_to_bytes(a) == var_to_bytes(b)
func _initialize() -> void:
	var current = CURRENT.new()
	var old = OLD.new()
	for cycle: int in 2:
		for index: int in 6000:
			var record: Variant = {"name":"item"+str(index),"number":float(index),"flag":index%2==0,"nested":{"v":[index%513]},"array":[index%513]}
			match index % 37:
				0: record = {"number":float(index),"name":"reordered"}
				1: record = {"name":"int","number":index}
				2: record = {"name":null,"number":float(index)}
				3: record = {}
				4: record = {1:"nonstring"}
				5: record = "loose"
			var pack: bool = index%41 != 0
			check(current.add(record,pack)==old.add(record,pack),"handle")
		for index: int in current.size():
			var expected: Variant = old.fetch(index)
			check(equal(current.fetch(index),expected),"record "+str(index))
			check(equal(current.field(index,"missing","default"),old.field(index,"missing","default")),"missing default")
			check(not current.has_field(index,"missing"),"missing presence")
			if expected is Dictionary:
				for key: Variant in expected:
					if key is String:
						check(equal(current.field(index,key),old.field(index,key)),"field")
						check(current.has_field(index,key),"present field")
		check(current.shape_count()==old.shape_count() and current.packed_count()==old.packed_count(),"shape and loose counts")
		var first: Dictionary = current.fetch(10)
		first.nested.v.append("changed")
		check(equal(current.fetch(10),old.fetch(10)),"nested copies")
		current.clear(); old.clear()
		check(current.size()==0 and current.shape_count()==0,"clear")
	print("EQUIPMENT_PACKED_SCAN_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
