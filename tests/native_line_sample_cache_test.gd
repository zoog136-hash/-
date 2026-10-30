extends SceneTree
const CACHE=preload("res://scripts/maps/native_line_sample_cache.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("LINE_SAMPLE_CACHE_FAIL "+label)
func run() -> void:
	var cache=CACHE.new()
	cache.store(Vector2(1,2),false)
	check(cache.lookup(Vector2(1,2))==0,"blocked sample is a hit, not a miss")
	check(cache.lookup(Vector2(1.0001,2))==-1,"subpixel coordinate remains distinct")
	cache.store(Vector2(1,2),true)
	check(cache.size()==1 and cache.lookup(Vector2(1,2))==1,"replacement does not duplicate a key")
	cache.clear()
	for i: int in range(CACHE.LIMIT+1):cache.store(Vector2(i,.25),i%2==0)
	check(cache.size()==CACHE.LIMIT and cache.order.size()==CACHE.LIMIT,"both storage structures bounded")
	check(cache.lookup(Vector2(0,.25))==-1,"oldest entry evicted")
	check(cache.lookup(Vector2(CACHE.LIMIT,.25))==1,"new samples admitted after capacity")
	check(cache.lookup(Vector2(1,.25))==0,"neighboring retained blocked sample unchanged")
	cache.clear()
	check(cache.size()==0 and cache.order.is_empty() and cache.cursor==0,"geometry lifetime reset releases all samples")
	print("LINE_SAMPLE_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
