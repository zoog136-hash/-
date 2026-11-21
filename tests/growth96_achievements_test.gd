extends SceneTree
## 사용자 목록 4: the level growth rewards (former 96레벨 보상 screen) are rows
## of the original quest window's 업적 tab; claims go through world.growth96
## and a received point is complete and never paid again. Synthetic.
const ROWS=preload("res://scripts/progression/growth96_achievements.gd")
const WINDOW=preload("res://scripts/ui/original_ui/source_main_quest_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeSource extends RefCounted:
	var ready: bool=true
	var rewards: Dictionary={"501":{"RewardClassID":96094},"502":{"RewardClassID":371128},"503":{"RewardClassID":96084}}

class FakeRuntime extends RefCounted:
	var source:=FakeSource.new()
	var claimed: Dictionary={"93":true}
	var reached: Dictionary={"93":true,"94":true,"95":false}
	var revision: int=4
	var executed: Array=[]
	func snapshot() -> Dictionary:
		var points: Array=[]
		for pair: Array in [["93",96,10,"501"],["94",96,20,"502"],["95",96,30,"503"]]:
			points.append({"id":pair[0],"level":pair[1],"percent":pair[2],"reached":reached[pair[0]],"claimed":claimed.has(pair[0]),"rewards":[{"id":pair[3],"name":"상자","amount":3,"version":0}]})
		return {"ready":true,"points":points}
	func quote(action: String, id: String) -> Dictionary:
		if action!="claim":return {"ok":false}
		if claimed.has(id):return {"ok":false,"message":"이미 수령한 성장 보상입니다."}
		if not reached[id]:return {"ok":false,"message":"필요한 레벨과 경험치 비율에 도달하지 않았습니다."}
		return {"ok":true,"revision":revision}
	func execute(action: String, id: String, expected: int) -> Dictionary:
		if expected!=revision:return {"ok":false}
		executed.append([action,id])
		claimed[id]=true
		revision+=1
		return {"ok":true}

class FakeWorld extends Node:
	var growth96: FakeRuntime

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("GROWTH96_ACHIEVEMENTS_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var runtime:=FakeRuntime.new()
	var rows: Array[Dictionary]=ROWS.rows(runtime)
	check(rows.size()==3 and rows[0].id=="growth96:93" and rows[0].category=="achievement" and rows[0].title==ROWS.title(96,10),"every growth point is an achievement row")
	check(rows[0].completed and not rows[0].available,"a received point is complete")
	check(WINDOW._receivable(rows[1]) and not WINDOW._receivable(rows[2]) and not WINDOW._receivable(rows[0]),"only a reached, unreceived point can be received")
	check(rows[1].source_rewards[0].source_item.ItemClassID==371128 and int(rows[1].source_rewards[0].Amount)==3 and int(rows[1].source_rewards[0].RewardEnhancementTypeID)==1,"the reward slots carry the original reward item")
	check(ROWS.rows(null).is_empty(),"no growth owner: no rows")
	var claimed: Dictionary=ROWS.claim(runtime,"growth96:94")
	check(claimed.ok and runtime.executed==[["claim","94"]],"receiving goes through growth96 quote -> execute")
	var again: Dictionary=ROWS.claim(runtime,"growth96:94")
	check(not again.ok and runtime.executed.size()==1,"a received point is never paid again")
	check(not ROWS.claim(runtime,"growth96:93").ok and not ROWS.claim(runtime,"m523:quest:1").ok,"the saved receipt and other quest ids are refused")
	# The 업적 tab order: receivable growth rows, other receivable, the next waiting point, the rest, received.
	var window=WINDOW.new()
	window._category="achievement"
	var world:=FakeWorld.new()
	runtime.claimed={"93":true}
	world.growth96=runtime
	var quest_ready: Dictionary={"id":"q1","completed":false,"available":true,"progress":1,"objective":{"count":1}}
	var quest_wait: Dictionary={"id":"q2","completed":false,"available":false,"progress":0}
	var quest_done: Dictionary={"id":"q3","completed":true}
	var listed: Array[Dictionary]=[quest_ready,quest_wait,quest_done]
	var ids: Array=window._with_growth(world,listed).map(func(row: Dictionary) -> String: return str(row.id))
	check(ids==["growth96:94","q1","growth96:95","q2","q3","growth96:93"],"the 업적 tab lists receivable rows first, received ones last: "+str(ids))
	window._category="main"
	var single: Array[Dictionary]=[quest_ready]
	check(window._with_growth(world,single).size()==1,"other tabs list no growth rows")
	world.free()
	var hud: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(not hud.contains("[\"growth96\",\"96레벨 보상·증표\"]"),"the separate 96레벨 보상 menu tile is gone")
	print("GROWTH96_ACHIEVEMENTS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
