extends SceneTree
## 사용자 목록 8 (컬렉션 렉): a card acquisition re-derives only the collections
## that hold the card (collection_runtime._rederive_changed), with exactly the
## rows, totals, completion and stat record a full derive gives. Synthetic.
const Runtime=preload("res://scripts/cards/collection_runtime.gd")
const Rules=preload("res://scripts/cards/collection_rules.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeFusion extends RefCounted:
	var owned: Dictionary={"변신":{},"마법인형":{},"성물":{}}

class FakeWorld extends Node:
	var card_draw_fusion:=FakeFusion.new()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("CARD_COLLECTION_INCREMENTAL_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

static func _data() -> Dictionary:
	var collections: Array=[]
	for index: int in 40:
		var requirements: Array=[]
		for member: int in 3:
			var card: int=(index*2+member)%30
			requirements.append({"id":"source:c%d" % card,"category":"변신","name":"카드 %d" % card})
		collections.append({"id":"col%d" % index,"category":"변신","requirements":requirements,
			"effects":[{"key":"max_hp","unit":"flat","value":index+1},{"key":"mr","unit":"flat","value":1}],
			"source":{"verified_pre2026":true,"date":"2024-01-01"}})
	return {"schema_version":1,"collections":collections}

static func _catalog() -> Dictionary:
	var cards: Array=[]
	for card: int in 30:cards.append({"sourceId":"c%d" % card,"name":"카드 %d" % card})
	return {"변신":cards,"마법인형":[],"성물":[]}

## A fresh runtime that derives everything from the same owned cards.
func _full(owned: Dictionary) -> Object:
	var world:=FakeWorld.new()
	world.card_draw_fusion.owned=owned.duplicate(true)
	var runtime=Runtime.new()
	runtime.world=world
	runtime.core=Rules.new()
	runtime.core.configure(_data(),_catalog())
	runtime.invalidate();runtime._ensure()
	world.free()
	return runtime

func _same(a: Object, b: Object, label: String) -> void:
	check(a.totals==b.totals,label+": totals "+str(a.totals)+" vs "+str(b.totals))
	check(a._completed==b._completed,label+": completed collections")
	check(a._record==b._record,label+": stat record")
	check(a.snapshot("변신")==b.snapshot("변신"),label+": every shown row")

func _run() -> void:
	var world:=FakeWorld.new()
	var runtime=Runtime.new()
	runtime.world=world
	runtime.core=Rules.new()
	check(runtime.core.configure(_data(),_catalog()),"fixture configures: "+runtime.core.error)
	runtime.invalidate();runtime._ensure()
	check(runtime.incremental_count==0 and runtime.rebuild_count==1,"the first derive is a full one")
	var owned: Dictionary=world.card_draw_fusion.owned
	var rng:=RandomNumberGenerator.new()
	rng.seed=523
	for step: int in 25:
		var pick: int=rng.randi_range(0,29)
		while owned["변신"].has("source:c%d" % pick):pick=(pick+1)%30
		owned["변신"]["source:c%d" % pick]=true
		var before: int=runtime.revision
		runtime.invalidate();runtime._ensure()
		check(runtime.revision==before+1,"each acquisition is a new revision")
		if step%5==4:_same(runtime,_full(owned),"after %d acquisitions" % (step+1))
	check(runtime.incremental_count==25 and runtime.rebuild_count==runtime.incremental_count+1,"acquisitions re-derive only the touched collections: "+str([runtime.incremental_count,runtime.rebuild_count]))
	check(not runtime.totals.is_empty(),"completed collections add their effects")
	# Losing a card (a reload of an older ledger) is the same change backwards.
	owned["변신"].erase(owned["변신"].keys()[0])
	runtime.invalidate();runtime._ensure()
	_same(runtime,_full(owned),"after a removal")
	# Many changes at once: one full derive.
	var full_before: int=runtime.rebuild_count-runtime.incremental_count
	world.card_draw_fusion.owned={"변신":{},"마법인형":{},"성물":{}}
	for card: int in 30:world.card_draw_fusion.owned["변신"]["source:c%d" % card]=true
	runtime.invalidate();runtime._ensure()
	_same(runtime,_full(world.card_draw_fusion.owned),"after a bulk change")
	check(runtime.rebuild_count-runtime.incremental_count==full_before or runtime.rebuild_count-runtime.incremental_count==full_before+1,"a bulk change stays exact")
	# Nothing changed: no re-derive at all.
	var stable: int=runtime.rebuild_count
	runtime.invalidate();runtime._ensure()
	check(runtime.rebuild_count==stable,"an unchanged ledger is not derived again")
	world.free()
	print("CARD_COLLECTION_INCREMENTAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
