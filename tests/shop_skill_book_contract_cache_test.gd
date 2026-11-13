extends SceneTree
const BOOKS = preload("res://scripts/shop/source523_skill_books.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var identity: Dictionary={"source_sha256":"fixture"}
	var reviewed: Dictionary={"local": {"spell_id":17}}
	var spec: Dictionary={"name":"book","skill_id":"local","card_id":4,"spell_id":17,"source_definition_archive":identity.duplicate(),"classes":{"기사":[{"minimum_level":1,"required_card":0,"polymorph_grade":0}]}}
	var good: Dictionary={"schema":BOOKS.BOOK_SCHEMA,"identity":identity,"signature":"sig","books":{"7":spec}}
	check(BOOKS._valid_contract_bake(good,identity,"sig",reviewed),"valid contract")
	check(not BOOKS._valid_contract_bake(good,identity,"changed",reviewed),"binding change")
	check(not BOOKS._valid_contract_bake(good,{"source_sha256":"changed"},"sig",reviewed),"original change")
	check(not BOOKS._valid_contract_bake(good,identity,"sig",{}),"unbound local skill")
	check(not BOOKS._valid_contract_bake(good,identity,"sig",{"local":{"spell_id":18}}),"wrong original spell")
	for value: Variant in [null,[],{}, {"schema":"old"}]:check(not BOOKS._valid_contract_bake(value,identity,"sig",reviewed),"bad envelope")
	for key: String in ["name","skill_id","card_id","spell_id","source_definition_archive","classes"]:
		var bad: Dictionary=good.duplicate(true);bad.books["7"].erase(key);check(not BOOKS._valid_contract_bake(bad,identity,"sig",reviewed),"missing "+key)
	for value: Variant in [true,[],{},"17",INF,NAN,-1]:
		var bad: Dictionary=good.duplicate(true);bad.books["7"].spell_id=value;check(not BOOKS._valid_contract_bake(bad,identity,"sig",reviewed),"bad spell numeric")
	var bad: Dictionary=good.duplicate(true);bad.books["7"].classes["기사"][0].minimum_level=true;check(not BOOKS._valid_contract_bake(bad,identity,"sig",reviewed),"bad limit")
	bad=good.duplicate(true);bad.books["07"]=bad.books["7"];bad.books.erase("7");check(not BOOKS._valid_contract_bake(bad,identity,"sig",reviewed),"noncanonical item ID")
	check(not BAKE.key(["book",JSON.stringify(Engine.get_version_info())]).is_empty(),"engine key is serializable")
	var name: String="zz_skill_books_cache_fixture"
	BAKE.clear(name);check(BAKE.write(name,"fixture-key",good),"atomic fixture write")
	var loaded: Variant=BAKE.read(name,"fixture-key");check(var_to_bytes(loaded)==var_to_bytes(good),"complete byte equality")
	check(BAKE.read(name,"wrong-key")==null,"key mismatch")
	var file:=FileAccess.open(BAKE.data_path(name),FileAccess.WRITE);file.store_string("corrupt");file.close();check(BAKE.read(name,"fixture-key")==null,"payload hash corruption rejected")
	BAKE.clear(name)
	print("SHOP_BOOK_CACHE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
