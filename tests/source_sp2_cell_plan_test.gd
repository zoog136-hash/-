extends SceneTree
const PLAN = preload("res://scripts/animation/source_sp2_cell_plan.gd")
const BLEND = preload("res://scripts/animation/source_sp2_compositor.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);print("SOURCE_SP2_CELL_PLAN FAIL "+label)
func ref(a: int=0,b: int=0,depth: int=8,index: int=0) -> Dictionary:
 return {"a":a,"b":b,"type":depth,"index":index,"raw_reference_word":index}
func submission(key: String,refs: Array,high: int=0,low: int=1,override: int=0,actor: Vector2i=Vector2i.ZERO) -> Dictionary:
 return {"source_key":key,"refs":refs,"block_count":16,"identity_high":high,"identity_low":low,"layer_override":override,"actor_cell":actor}
func keys(plan: Dictionary,cell: Vector2i=Vector2i.ZERO) -> Array:
 var values: Array=[]
 for entry: Dictionary in plan.cells[cell]:values.append(entry.source_key)
 return values
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var input: Array=[submission("main",[ref(0,0,20)]),submission("clothes",[ref(0,0,8)]),submission("shadow",[ref(0,0,12)])]
 var before: Array=input.duplicate(true)
 var plan: Dictionary=PLAN.build(input)
 check(plan.ok and keys(plan)==["clothes","shadow","main"],"per-cell depth precedes asset submission order")
 check(input==before,"input references/provenance are not changed")
 check(plan.reference_count==3 and plan.cell_count==1,"all references retained")
 check(not plan.inter_cell_order_verified and not plan.admission_or_blend_verified and not plan.retained_history_verified,"ordering is not visibility or whole-render proof")
 input=[submission("low",[ref()],0,0xffffffff),submission("high",[ref()],0x80000000,0),submission("max",[ref()],0xffffffff,0xffffffff)]
 check(keys(PLAN.build(input))==["max","high","low"],"unsigned64 identity order without double or signed64 conversion")
 input=[submission("first",[ref(),ref(0,0,8,1)]),submission("second",[ref()])]
 plan=PLAN.build(input)
 check(keys(plan)==["second","first","first"],"new exact ties precede old across assets")
 check(plan.cells[Vector2i.ZERO][1].reference_index==1 and plan.cells[Vector2i.ZERO][2].reference_index==0,"exact ties reverse original reference submission")
 check(plan.reference_count==3,"same-cell duplicate references are not deduplicated")
 input=[submission("near",[ref(0,0,200)]),submission("other-cell",[ref(1,0,0)])]
 plan=PLAN.build(input)
 check(plan.cell_count==2 and keys(plan)==["near"] and keys(plan,Vector2i(1,0))==["other-cell"],"different cells are separate buckets, never globally depth sorted")
 input=[submission("negative",[ref(-3,1,8)],0,1,0,Vector2i(10,-10))]
 plan=PLAN.build(input)
 check(plan.cells.has(Vector2i(7,-9)),"signed a/b offsets use world cells, not pixel geometry")
 input=[submission("wrapped",[ref(1,-1,8)],0,1,0,Vector2i(2147483647,-2147483648))]
 check(PLAN.build(input).cells.has(Vector2i(-2147483648,2147483647)),"native32 addition retains low32")
 input=[submission("raw",[ref(0,0,1)]),submission("override",[ref(0,0,255)],0,1,4)]
 plan=PLAN.build(input)
 check(keys(plan)==["raw","override"] and int(plan.cells[Vector2i.ZERO][1].depth)==4,"nonzero caller override replaces cell depth")
 check(int(input[1].refs[0].type)==255,"override leaves raw depth intact")
 for field: String in ["identity_high","identity_low","source_key","actor_cell","block_count","layer_override","refs"]:
  var bad: Dictionary=submission("bad",[ref()]);bad.erase(field)
  check(not PLAN.build([bad]).ok,"missing explicit input rejected: "+field)
 for field: String in ["a","b","type","index"]:
  var bad: Dictionary=submission("bad",[ref()]);bad.refs[0][field]=0.0
  check(not PLAN.build([bad]).ok,"untyped JSON float not admitted as decoded int: "+field)
 for pair: Array in [["a",-129],["a",128],["b",-129],["b",128],["type",-1],["type",256],["index",-1],["index",16]]:
  var bad: Dictionary=submission("bad",[ref()]);bad.refs[0][pair[0]]=pair[1]
  check(not PLAN.build([bad]).ok,"reference bound rejected: "+str(pair))
 for pair: Array in [["identity_high",-1],["identity_low",0x100000000],["layer_override",256],["block_count",65537],["source_key",""]]:
  var bad: Dictionary=submission("bad",[ref()]);bad[pair[0]]=pair[1]
  check(not PLAN.build([bad]).ok,"submission bound rejected: "+str(pair))
 check(not PLAN.build([submission("budget",[ref(),ref()])],1).ok,"reference budget applies before building buckets")
 check(not PLAN.build([],0).ok and not PLAN.build([],PLAN.MAX_REFERENCES+1).ok,"caller cannot disable or enlarge hard cap")
 var many: Array=[];many.resize(PLAN.MAX_SUBMISSIONS+1)
 check(not PLAN.build(many).ok,"submission count hard cap")
 check(PLAN.build([]).ok and PLAN.build([]).reference_count==0,"empty plan is harmless")
 var snapshot: Array=[submission("snapshot",[ref()])]
 plan=PLAN.build(snapshot);plan.cells[Vector2i.ZERO][0].depth=200
 check(int(snapshot[0].refs[0].type)==8,"returned scalar plan does not retain mutable source reference")
 check(PLAN.build([submission("boundary",[ref(),ref()])],2).ok,"exact reference budget boundary admitted")
 # Destination-dependent kernels do not commute. This synthetic covered pixel
 # uses explicit caller operators; the planner never derives flags or alpha.
 var samples: Dictionary={"main":0x001f,"clothes":0xf800}
 var operations: Dictionary={"main":1,"clothes":2}
 input=[submission("main",[ref()]),submission("clothes",[ref()])]
 var old_pixel: int=BLEND.blend565(BLEND.blend565(0x7bef,0x001f,1),0xf800,2)
 var cell_pixel: int=0x7bef
 for entry: Dictionary in PLAN.build(input).cells[Vector2i.ZERO]:
  cell_pixel=BLEND.blend565(cell_pixel,int(samples[entry.source_key]),int(operations[entry.source_key]))
 check(old_pixel==0x7800 and cell_pixel==0x781f,"same-cell order changes exact covered RGB565 under screen/multiply")
 print("SOURCE_SP2_CELL_PLAN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"details":failures}))
 quit(0 if failures.is_empty() else 1)
