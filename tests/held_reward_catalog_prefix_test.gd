extends SceneTree
## Exact default World lookup, unchanged catalog row and private bag. The old
## path here is a frozen oracle. Do not interpret these as phone frame times.
const R=preload("res://scripts/quests/quest_auto_runner.gd")
const W=preload("res://scripts/world.gd")
const LOOKUP=preload("res://scripts/catalog_item_lookup.gd")
var checks:=0;var fails: Array[String]=[]
func ck(v: bool,m: String)->void:
	checks+=1
	if not v:fails.append(m);printerr("HELD_PREFIX_FAIL ",m)
class Custom extends RefCounted:
	func held_record(s: String,_i: Dictionary)->Dictionary:return {"name":s,"custom":true}
class Old extends RefCounted:
	var index: Dictionary={};var rows: Dictionary={};var n: int=-1
	func held_record(s: String,bag: Dictionary)->Dictionary:
		if not is_same(rows,bag) or n!=bag.size():
			index.clear();rows=bag;n=bag.size()
			for id: String in bag:
				var name: String=str(bag[id].get("name",""))
				if name.begins_with("[원본 보상] ") and not index.has(name):index[name]=id
		if not s.begins_with("[원본 보상] "):return {}
		var c: Dictionary=bag.get(str(index.get(s,"")),{})
		if c.get("name")!=s:n=-1;return {}
		return c.record.duplicate(true) if c.get("record",{}).get("source_pending_use",false) else {}
func old_lookup(w: Node,s: String)->Dictionary:
	var held: Dictionary=w.quest_auto.call("held_record",s,w.item_instances)
	if not held.is_empty():return held
	if s.begins_with("[원본 보상] "):return w.quest_auto.held_record(s,w.item_instances)
	return LOOKUP.find_one([w.catalog_db.get("아이템",[]),w.item_db],w.item_instances,s)
func _initialize()->void:run.call_deferred()
func run()->void:
	var a:=W.new();var b:=W.new();a.quest_auto=Old.new()
	a.item_db=[{"name":"화살","id":5}];b.item_db=a.item_db
	var bag: Dictionary={};var name: String="[원본 보상] 상자";var missing: String="[원본 보상] 없음"
	for j: int in 3000:bag[str(j)]={"name":"장비-"+str(j),"record":{"level":1}}
	bag["3000"]={"name":name,"record":{"name":name,"source_pending_use":true,"tags":[1]}}
	b.item_instances=bag
	ck(b._find_catalog_item_record("화살").id==5 and b.quest_auto.indexed_size==-1,"real ordinary lookup never builds held index")
	ck(b.quest_auto.held_record("화살",bag).is_empty() and b.quest_auto.indexed_size==-1,"direct ordinary path skips index too")
	ck(b._find_catalog_item_record(missing).is_empty() and b.quest_auto.indexed_size==-1,"missing still invalidates prior held index for later changes")
	var r: Dictionary=b._find_catalog_item_record(name);r.tags.append(2);ck(bag["3000"].record.tags==[1],"held is detached")
	bag["0"]={"name":missing,"record":{"name":missing,"source_pending_use":true}}
	ck(b._find_catalog_item_record(missing).name==missing,"permitted same-size edits immediately visible, as in old double lookup")
	bag["0"]={"name":"보통","record":{}}
	var compact: Dictionary={}
	for mode: String in ["ordinary_after_bag_change","ordinary_warm_200","missing_held"]:
		var times: Array=[[],[]]
		for i: int in 13:
			for arm: int in ([0,1] if i%2==0 else [1,0]):
				var w: Node=a if arm==0 else b
				w.item_instances=bag.duplicate(false)
				if mode=="ordinary_warm_200":
					if arm==0:old_lookup(w,"화살")
					else:w._find_catalog_item_record("화살")
				var start:=Time.get_ticks_usec();var result: Dictionary={}
				var target: String=missing if mode=="missing_held" else "화살"
				for j: int in (200 if mode=="ordinary_warm_200" else 1):
					result=old_lookup(w,target) if arm==0 else w._find_catalog_item_record(target)
				var delta:=Time.get_ticks_usec()-start
				ck(result==({} if mode=="missing_held" else {"name":"화살","id":5}),"same lookup result")
				if i>0:times[arm].append(delta)
		compact[mode]=times
	b.quest_auto=Custom.new();ck(b._find_catalog_item_record("화살").custom,"external/custom owner retains ordinary name precedence")
	b.quest_auto=null;ck(b._find_catalog_item_record("화살").id==5 and b._find_catalog_item_record(missing).is_empty(),"missing owner is not called")
	a.free();b.free()
	print("HELD_REWARD_CATALOG_PREFIX_RESULT ",JSON.stringify({"checks":checks,"failures":fails,"us_old_new":compact}))
	quit(0 if fails.is_empty() else 1)
