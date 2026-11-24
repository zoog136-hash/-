extends SceneTree
## Compare the previous per-node accumulator with the real production clock.
## Same frame IDs, variable simulation deltas, body lifetimes, range, roles
## and round-robin phase. No original NPC bank or device GPU is emulated.
const B=preload("res://scripts/npc/source523_town_npc_bodies.gd")
class Host extends Node:
	var player:=Node2D.new()
class Preview extends Node:
	var calls:=0
	var seconds:=0.0
	var accepts:=true
	var last_role: String
	var last_face: int
	func advance_reference_source(d: float,role: String,face: int)->bool:
		calls+=1; seconds+=d;last_role=role;last_face=face;return accepts
class Baseline extends B:
	func _advance_body_frame(d: float,frame: int)->void:
		if bodies.is_empty():return
		var at:=_player_position()
		var holders:=bodies.values()
		for holder: Variant in holders:
			if is_instance_valid(holder):holder.set_meta("pending_delta",float(holder.get_meta("pending_delta",0.0))+d)
		if frame%ADVANCE_EVERY_FRAMES!=0:return
		var advanced:=0;var visited:=0
		while advanced<ADVANCES_PER_FRAME and visited<holders.size():
			_advance_cursor=(_advance_cursor+1)%holders.size()
			visited+=1
			var h: Node2D=holders[_advance_cursor]
			if not is_instance_valid(h) or not h.is_visible_in_tree():continue
			if at.is_finite() and h.position.distance_to(at)>ANIMATE_RADIUS:continue
			var p: Node=h.get_meta("preview") if h.has_meta("preview") else null
			if not is_instance_valid(p):continue
			var pending:=float(h.get_meta("pending_delta",0.0));h.set_meta("pending_delta",0.0)
			p.advance_reference_source(pending,str(h.get_meta("role")),int(h.get_meta("direction")))
			advanced+=1
var failures: Array[String]=[]
var n:=0
func ck(ok: bool,msg: String)->void:
	n+=1
	if not ok:failures.append(msg);printerr("TOWN_CLOCK_FAIL ",msg)
func _initialize()->void:run.call_deferred()
func add_body(owner: Node,id: int)->void:
	var h:=Node2D.new();var p:=Preview.new()
	h.set_meta("role","idle");h.set_meta("direction",id%8)
	h.set_meta("preview",p);h.add_child(p);owner.add_child(h)
	owner._register_body(str(id),h)
func compare(a: Node,b: Node)->bool:
	if a.bodies.keys()!=b.bodies.keys():return false
	for id: String in a.bodies:
		var x: Node2D=a.bodies[id];var y: Node2D=b.bodies[id]
		var px: Preview=x.get_meta("preview");var py: Preview=y.get_meta("preview")
		if px.calls!=py.calls or px.last_face!=py.last_face or px.last_role!=py.last_role or absf(px.seconds-py.seconds)>0.000001:return false
		if absf(float(x.get_meta("pending_delta",0.0))-b._pending_idle(y))>0.000001:return false
	return true
func run()->void:
	var host:=Host.new();root.add_child(host);host.add_child(host.player)
	var a:=Baseline.new();var b:=B.new()
	for set: Node in [a,b]:
		root.add_child(set);set.world=host
		for id: int in 29:add_body(set,id)
	for frame: int in 180:
		for set: Node in [a,b]:
			if frame==22:set.bodies["4"].hide()
			if frame==39:set.bodies["5"].position.x=1300
			if frame==70:set.bodies["4"].show()
			if frame==80:set._release("20")
			if frame==85:add_body(set,20)
			if frame==99:set.bodies["5"].position.x=0
			set._advance_body_frame((frame%5+1)/140.0,frame)
		ck(compare(a,b),"same calls, facing, speed, pending time "+str(frame))
	var durations: Array=[[],[]]
	for round_id: int in 13:
		for arm: int in ([0,1] if round_id%2==0 else [1,0]):
			var set: Node=a if arm==0 else b
			var start:=Time.get_ticks_usec()
			for frame: int in 600:set._advance_body_frame(1.0/60.0,frame)
			var elapsed:=Time.get_ticks_usec()-start
			if round_id>0:durations[arm].append(elapsed)
	ck(compare(a,b),"after all timed frames")
	var staged:=Node2D.new();var p:=Preview.new();p.accepts=false
	staged.add_child(p);staged.set_meta("direction",7);b.add_child(staged)
	var count_before:=b.bodies.size();var releases:=b.released
	b._finish_first_frame("reject",staged,p)
	ck(staged.get_parent()==null and staged.is_queued_for_deletion() and b.bodies.size()==count_before and b._body_order.size()==count_before and b.released==releases and b.missing.get("reject")=="original_first_frame_unavailable","rejected first frame leaves no orphan holder/label or animation slot")
	b.clear();ck(b._body_order.is_empty() and b._idle_clock==0.0,"map clear releases roster and clock")
	a.free();b.free();host.free()
	print("TOWN_IDLE_CLOCK_RESULT ",JSON.stringify({"checks":n,"failures":failures,"holders":29,"frames_per_sample":600,"cpu_us_old_new":durations}))
	quit(0 if failures.is_empty() else 1)
