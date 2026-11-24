extends SceneTree
const Book=preload("res://scripts/monsterbook/monsterbook523.gd")
var service=Book.new()
var failures:Array[String]=[]
var checks:=0
func ck(yes:bool,reason:String)->void:
	checks+=1
	if not yes: failures.append(reason)
# Reference implementation from the parent commit, including the public progress copy.
func previous_one(book_id:int,clock:String)->Array:
	if not service._within(book_id,clock,"EndDateTimeID"):return []
	var current_epoch:String=str(service._state.books.get(str(book_id),{}).get("current_epoch",""))
	if current_epoch.begins_with("source-season:"):
		var at:=current_epoch.find(":r")
		var turn:int=int(current_epoch.substr(at+2)) if at>=0 else 0
		if turn!=service.rotation(book_id,clock):return []
	var result:Array=[]
	for id:Variant in service.progress(book_id).get("effective_levels",[]):
		result.append_array(service._linked("MonsterBookLevelBonus",int(id),"BonusID","Bonus"))
	return result
func previous(clock:String)->Array:
	var out:Array=[]
	for b:Dictionary in service.books():
		out.append_array(previous_one(int(b.ID),clock))
	return out
func metric(a:Array)->Array:
	a.sort()
	return [a[a.size()/2],a[ceili(a.size()*0.95)-1],a.back()]
func measure(label:String)->void:
	var old:Array=[];var now:Array=[];var clock:="202610290500"
	for i:int in range(101):
		var pair:Array=[];var r:Array=[];var s:Array=[]
		for step:int in range(2):
			var is_old:bool=(i+step)%2==0
			var start:int=Time.get_ticks_usec()
			if is_old:r=previous(clock)
			else:s=service.all_effective_bonuses(clock)
			pair.append(Time.get_ticks_usec()-start)
		if i>0:old.append(pair[i%2]);now.append(pair[(i+1)%2])
		ck(r==s,label+" full ordered bonus rows")
	print("MONSTERBOOK_EFFECT_SCAN_US ",label," old/new median,p95,max ",metric(old)," ",metric(now))
func _initialize()->void:
	var path:=OS.get_environment("MONSTERBOOK523_PACK");var sha:=OS.get_environment("MONSTERBOOK523_SHA256")
	ck(service.all_effective_bonuses("invalid")==[],"zero ledger and no pack")
	if not path.is_empty() and ck_load(path,sha):
		measure("empty")
		var books:Array=service.books()
		var state:Dictionary=service.export_state()
		for book:Dictionary in [books[2],books[0]]:
			var levels:Array=service.levels(int(book.ID));var level:Dictionary=levels.back()
			var lid:int=int(level.ID)
			state.books[str(int(book.ID))]={"sequence":1,"current_epoch":"season","epochs":{"season":{"counts":{str(lid):int(level.Amount)},"registered":[lid],"claimed":[],"effective_levels":[lid]}}}
		ck(service.import_state(state),"accepted two real owners in reverse source order")
		ck(not previous("202610290500").is_empty(),"live options, not just empty parity")
		measure("two owners")
		for rotate:bool in [true,false]:
			service.rotate_ended_seasons=rotate
			for clock:String in ["invalid","202610010500","202611040500","202611240500"]:
				ck(previous(clock)==service.all_effective_bonuses(clock),"expiration, rotation, unparseable clock and order")
		service.rotate_ended_seasons=true
		for book:Dictionary in books:
			var levels:Array=service.levels(int(book.ID));var level:Dictionary=levels.back();var lid:int=int(level.ID)
			state.books[str(int(book.ID))]={"sequence":1,"current_epoch":"source-season:known:r0","epochs":{"source-season:known:r0":{"counts":{str(lid):int(level.Amount)},"registered":[lid],"claimed":[],"effective_levels":[lid]}}}
		ck(service.import_state(state),"accepted all current source-book owners")
		measure("all owners")
		ck(previous("202611240500")==service.all_effective_bonuses("202611240500"),"old rotation does not leak into next season")
	print("MONSTERBOOK_EFFECT_SCAN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
func ck_load(path:String,sha:String)->bool:
	var ok:bool=service.load_pack(path,sha);ck(ok,"verified original pack");return ok
