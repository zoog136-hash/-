extends SceneTree
## Frozen pre-index walker is the reference for exact scope, order, callbacks,
## exclusions and nested project paths (same window instance in both arms).
const WINDOW=preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const BASE=preload("res://tests/original_ui_card_gacha_window_test.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const PIN="5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c"
class CompareWindow extends WINDOW:
	var scan: bool=false
	func _bind(member: String, key: String, chain: Array, spec: Dictionary, out: Dictionary, list_key: String="")->Dictionary:
		if scan:return _scan(member,key,chain,spec,out,list_key)
		return super._bind(member,key,chain,spec,out,list_key)
	func _scan(member: String, key: String, chain: Array, spec: Dictionary, out: Dictionary, list_key: String="") -> Dictionary:
		var tree: Dictionary=_read_stage_tree(member)
		var scope: Array[int]=[]
		var bindings: Dictionary={}
		var external: Array=_pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[])
		for node: Dictionary in tree.get("children",[]):_scan_walk(node,member,key,chain,spec,scope,bindings,external,out,list_key)
		return {"scope":scope,"bindings":bindings}

	func _scan_walk(node: Dictionary, member: String, parent_key: String, chain: Array, spec: Dictionary, scope: Array[int], bindings: Dictionary, external: Array, out: Dictionary, list_key: String) -> void:
		if node.is_empty():return
		var options: Dictionary=node.get("options",{})
		var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
		var offset: int=int(node.get("_offset",-1))
		var key: String=parent_key+"/"+str(widget.get("name",""))
		var kind: String=str(node.get("classname",""))
		for pattern: String in spec:
			if key.ends_with("/"+pattern) and bool(spec[pattern].get("exclude",false)):return
		scope.append(offset)
		var touch: bool=bool(widget.get("touchEnabled",false))
		var binding: Dictionary={}
		match kind:
			"ProjectNode":
				var child_member: String=str(options.get("fileName",""))
				if not child_member.begins_with("UI/"):child_member="UI/"+child_member
				var next_chain: Array=chain.duplicate()
				next_chain.append(offset)
				var child: Dictionary=_scan(child_member,key,next_chain,spec,out,list_key)
				binding={"role":"project","source_node_offsets":child.scope,"bindings":child.bindings}
			"Button":
				binding={"role":"button","activate":Callable(self,"_ignore")}
				if not str(widget.get("callBackName","")).is_empty():binding["callback_name"]=str(widget.callBackName)
			"CheckBox":binding={"role":"checkbox","displaystate":false}
			"Text","TextBMFont":binding={"role":"static_source_text"}
			"ListView":
				var rows: Array=[]
				for row: Dictionary in node.get("children",[]):rows.append(int(row.get("_offset",-1)))
				binding={"role":"source_list","row_offsets":rows}
				if touch:binding["input"]=Callable(self,"_list_input").bind(list_key if not list_key.is_empty() else key)
			"ScrollView":
				if touch:binding={"role":"source_scroll","input":Callable(self,"_ignore_input")}
			"LoadingBar":binding={"role":"source_percent","percent":0.0}
		if offset in external and kind=="Sprite":binding={"role":"source_asset_slot","visible":false}
		elif touch and not binding.has("role") and kind!="ProjectNode":
			if not list_key.is_empty() and kind in ["Panel","ImageView"]:binding["input"]=Callable(self,"_list_input").bind(list_key)
			else:binding["role"]="consume"
		for pattern: String in spec:
			if key.ends_with("/"+pattern):binding.merge(spec[pattern],true)
		if not binding.is_empty():bindings[offset]=binding
		out[key]={"chain":chain,"offset":offset,"kind":kind,"member":member}
		if kind=="ProjectNode":return
		for child: Dictionary in node.get("children",[]):_scan_walk(child,member,key,chain,spec,scope,bindings,external,out,list_key)


var checks: int=0
var failures: Array[String]=[]
var samples: Dictionary={}
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)

func _initialize()->void:run.call_deferred()

func _parity(w: CompareWindow, member: String, rules: Dictionary)->void:
	var old_out: Dictionary={};var now_out: Dictionary={}
	w.scan=true
	var old: Dictionary=w._bind(member,"",[],rules,old_out)
	w.scan=false
	var updated: Dictionary=w._bind(member,"",[],rules,now_out)
	check(updated==old and now_out==old_out,"%s full scope, merged bindings and owning project match"%member)
	check(var_to_bytes(now_out)==var_to_bytes(old_out),member+" node insertion order")

func _node(id: int,title: String,children: Array=[])->Dictionary:
	return {"_offset":id,"classname":"Text","options":{"widgetOptions":{"name":title}},"children":children}

func run()->void:
	var w:=CompareWindow.new()
	var p:=PACK.new();w._pack=p
	p.manifest={"scenes":{"UI/Test":{"nodeTree":{"children":[_node(1,"Panel",[_node(2,"label"),_node(3,"sub/label"),_node(4,""),_node(5,"literal\\label")]),_node(6,"Clip",[_node(7,"label")])]}}}}
	var rules: Dictionary={"label":{"text":"short","visible":false},"Panel/label":{"text":"override","percent":1},"sub/label":{"text":"slash"},"":{"text":"unnamed"},"literal\\label":{"text":"literal"},"Clip":{"exclude":true},"Clip/label":{"text":"excluded child"}}
	_parity(w,"UI/Test",rules)
	var out: Dictionary={};var bound: Dictionary=w._bind("UI/Test","",[],rules,out)
	check(bound.bindings[2].text=="override" and not bound.bindings[2].visible and bound.bindings[3].text=="slash" and bound.bindings[4].text=="unnamed" and bound.bindings[5].text=="literal","exact overlap precedence, slash and empty node names")
	check(not bound.scope.has(6) and not bound.scope.has(7),"exclude entire branch")
	rules={"Panel/label":{"text":"first"},"label":{"text":"last"}}
	_parity(w,"UI/Test",rules)
	check(w._bind("UI/Test","",[],rules,{}).bindings[2].text=="last","a broad rule added later still wins")
	_parity(w,"UI/Test",{})
	var path: String=OS.get_environment("TWILIGHT_SUFFIX_BENCH_UI44")
	if not path.is_empty():await _pack_bench(w,path)
	print("SOURCE_WINDOW_SUFFIX_INDEX_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ui44":samples}))
	quit(0 if failures.is_empty() else 1)

func _pack_bench(w: CompareWindow,path: String)->void:
	var p:=PACK.new();var opened: Dictionary=p.open(path,PIN)
	check(opened.get("ok",false) and p._records!=null,"requires exact privately installed baked UI44")
	if not failures.is_empty():return
	var parent:=Node2D.new();root.add_child(parent)
	var hud:=BASE.FakeHud.new();root.add_child(hud)
	check(w.configure(p,hud).get("ok",false),"window configured")
	# Different users of the same walker: actual reward/currency root specs,
	# not a simulated draw or an assertion that their whole windows are faster.
	var reward:=preload("res://scripts/ui/original_ui/source_main_reward_select_window.gd").new()
	var currency:=preload("res://scripts/ui/original_ui/source_main_currency_window.gd").new()
	for feature: Variant in [reward,currency]:
		var member: String=feature._root_member()
		var rules: Dictionary=feature._spec()
		check(p.manifest.scenes.has(member),member+" in real pack")
		w._stage_trees={}
		_parity(w,member,rules)
		var times: Array=[[],[]]
		for i: int in 17:
			for arm: int in ([0,1] if i%2==0 else [1,0]):
				w.scan=arm==0
				var out: Dictionary={}
				var start:=Time.get_ticks_usec()
				w._bind(member,"",[],rules,out)
				if i>0:times[arm].append(Time.get_ticks_usec()-start)
				if i==0:check(not out.is_empty(),member+" bound actual nodes")
		samples[member]={"rules":rules.size(),"bind_usec":times}
	for count: int in [3,10]:
		var cards: Array=[]
		for i: int in count:cards.append({"name":"카드 %d"%i,"grade":["영웅","희귀","신화"][i%3]})
		w.results=cards;w.category="변신";w.title="테스트";w.opened.clear()
		w._stage_trees={}
		_parity(w,WINDOW.ROOT,w._spec())
		var spec: Dictionary=w._spec()
		var binds: Array=[[],[]];var opens: Array=[[],[]]
		var expected: PackedByteArray=PackedByteArray()
		for i: int in 9:
			for arm: int in ([0,1] if i%2==0 else [1,0]):
				# Same preloaded stage members in both bind-only arms; no disk timer.
				w.scan=arm==0
				var before: int=Time.get_ticks_usec()
				w._bind(WINDOW.ROOT,"",[],spec,{})
				if i>0:binds[arm].append(Time.get_ticks_usec()-before)
				# Actual synchronous open; both arms evict only scoped projections.
				SCENE._scoped_trees.clear()
				before=Time.get_ticks_usec()
				var result: Dictionary=w.open(parent,cards,"변신","테스트")
				if i>0:opens[arm].append(Time.get_ticks_usec()-before)
				var filled: PackedByteArray=var_to_bytes(result.get("filled",{}))
				if expected.is_empty():expected=filled
				check(result.get("handled",false) and int(result.filled.get("shown",-1))==count and int(result.filled.get("backs",-1))==count and filled==expected,"same %d closed cards"%count)
				check(int(w.open_all().get("lit",-1))==count-floori(float(count+1)/3),"same per-grade reveal for %d cards"%count)
				w.close();await process_frame
		samples[str(count)]={"rules":spec.size(),"bind_usec":binds,"open_usec":opens}
	w._stage_trees=null
	parent.queue_free();hud.queue_free()
