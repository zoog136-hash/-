extends RefCounted
## The original 523 boss overhead mark (UI/Overhead/NameCardLayout_BossMonster.csb)
## over a boss monster's name. The NPC's original UIBossNpcClass row names
## its BossNpcOverheadID (1 / 11 / 21 / 31); UIBossNpcOverhead names the one
## Nd_Level_0..3 node of the CSB to show (every other Nd_Level stays hidden).
## The mark plays the CSB's own Fx_On clip once, then its Fx_Loop clip
## repeating. Presentation only: nothing here reads or changes combat.
## Btn_Icon is left out of the scope (the field keeps its taps).
## TWILIGHT 근사: the client's exact anchor above the name card is not in
## the tables; the mark sits centred on top of the existing name label.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const MEMBER="UI/Overhead/NameCardLayout_BossMonster.csb"
const LEVELS: Array[String]=["Nd_Level_0","Nd_Level_1","Nd_Level_2","Nd_Level_3"]
## Frames of Fx_On (5..20) at the Cocos 60 fps timeline.
const ON_SECONDS: float=15.0/60.0

## The Nd_Level node of NPC class `npc_class_id` ("" when it has no mark).
static func resource_name(npc_class_id: int) -> String:
	if npc_class_id<0 or not SOURCE.problem().is_empty():return ""
	for row: Dictionary in SOURCE.related("UIBossNpcClass","NpcClassID",npc_class_id):
		var overhead: int=int(row.get("BossNpcOverheadID",0))
		if overhead<=0:continue
		var name: String=str(SOURCE.row("UIBossNpcOverhead",overhead).get("ResourceName",""))
		if name in LEVELS:return name
	return ""

## {ok, scene, node} for the mark showing `node` (one of LEVELS), playing.
static func build(pack: RefCounted, node: String) -> Dictionary:
	if pack==null or not pack.manifest.get("scenes",{}).has(MEMBER):return {"ok":false,"handled":false,"code":"source_boss_overhead_member_missing"}
	if node not in LEVELS:return {"ok":false,"handled":false,"code":"source_boss_overhead_unknown_level"}
	var spec: Dictionary={"Btn_Icon":{"exclude":true}}
	for level: String in LEVELS:spec[level]={"visible":level==node}
	var out: Dictionary={}
	var built: Dictionary=NamedTree.new(pack).scene_of(MEMBER,spec,out)
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	scene.name="SourceBossOverhead"
	var played: Dictionary=scene.play("Fx_On",false)
	if not played.get("ok",false):
		scene.free()
		return played
	var timer:=Timer.new()
	timer.one_shot=true
	timer.wait_time=ON_SECONDS
	timer.autostart=true
	timer.timeout.connect(func() -> void:
		if is_instance_valid(scene):scene.play("Fx_Loop",true)
		timer.queue_free())
	scene.add_child(timer)
	return {"ok":true,"handled":true,"scene":scene,"node":node,"out":out}

## Every Nd_Level node's own visibility in a built mark (for checks).
static func shown_levels(scene: Node2D, out: Dictionary) -> Array[String]:
	var shown: Array[String]=[]
	for level: String in LEVELS:
		var entry: Dictionary=out.get("/"+level,{})
		var node: Variant=scene.source_nodes.get(int(entry.get("offset",-1))) if not entry.is_empty() else null
		if node is CanvasItem and (node as CanvasItem).visible:shown.append(level)
	return shown
