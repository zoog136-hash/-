extends SceneTree
const Runtime=preload("res://scripts/titles/title_runtime523.gd")
const Host=preload("res://tests/title523_test.gd").Host
var checks:=0
var failures: Array[String]=[]
var instant:=1793797200
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); printerr("TITLE523_PERSONAL_FAIL ",label)
func _initialize() -> void: call_deferred("run")
func rank(t, count: int) -> void:
 t.state=Runtime.fresh(); t.state.achieved=[]; t.state.last_clock=instant
 for i: int in count: t.state.achieved.append(int(t.source.stages[i].id))
func run() -> void:
 var host:=Host.new(); root.add_child(host)
 var t=Runtime.new(); host.titles=t; t.configure(host); t.clock=func() -> int: return instant
 check(t.source.load_zip(OS.get_environment("TWILIGHT_TITLE523_ZIP")).is_empty(),"whole owner source loads")
 if not t.source.problem.is_empty(): host.free(); quit(1); return
 check(t.source.letters.size()==4 and t.source.upgrade_descriptions.size()==16,"complete narrative4plus16 rows")
 for stage: Dictionary in t.source.stages:
  for success: bool in [false,true]:
   for variant: int in [0,1]:
    check(not t.source.result_text(int(stage.id),success,variant).is_empty(),"all25 narrative results and variants")
  rank(t,t.source.stages.find(stage)+1)
  check(t.personal.display_color().is_equal_approx(Color("#"+str(stage.display_color))),"all25 highest native title colors")
 var limited:=0
 for q: Dictionary in t.source.quests.values():
  check(t.trial_access(int(q.id),instant).is_empty(),"all128 current native calendar and mapped server gates")
  check(not t.trial_access(int(q.id),t.calendar_second(q.calendar_start)-1).is_empty(),"all128 before native start")
  check(not t.trial_access(int(q.id),t.calendar_second(q.calendar_end)+60).is_empty(),"all128 after native end minute")
  if int(q.server_limit_set)!=0:
   limited+=1; t.policy.offline_source_world_no=999999
   check(not t.trial_access(int(q.id),instant).is_empty(),"all restricted21 nonmember blocked")
   t.policy.offline_source_world_no=1
 check(limited==21,"exact21 server-limited targets preserved")
 var p=t.personal
 check(t.source.personal.title_limit==278 and t.source.personal.max_names==5 and t.source.personal.activation_delay_raw==2,"all3 native constants")
 check(t.source.personal.banned_words.size()==139345 and t.source.personal.banned_types.size()==5,"complete Korean139345 rows and5 filter types")
 for kind: int in [62,1,11,21,43]:
  var found:=false
  for word: Dictionary in t.source.personal.banned_words:
   if int(word.type)==kind and not str(word.text).is_empty():
    check(not p.name_error(str(word.text)).is_empty(),"selected filter type "+str(kind)); found=true; break
  check(found,"filter type loaded "+str(kind))
 # Boundary assertions use actual source list and deliberately benign symbols.
 for text: String in ["", "A", "abcdefghijklmnopq", "◇".repeat(9), " 앞", "뒤 ", "a\nb", "a\u200bb", "a\u202eb", "a\ufeffb"]:
  check(not p.name_error(text).is_empty(),"invalid boundary "+str(text.length()))
 for text: String in ["ZX", "ZxQvKpRtWaYsNuFb", "◇", "◇".repeat(8), "◇Z"]:
  check(p.name_error(text).is_empty(),"allowed length boundary "+str(text.length()))
 rank(t,12)
 check(not p.unlocked(t.state) and not p.edit(0,"◇Z",0).ok,"preBaronI gate")
 rank(t,13)
 check(p.unlocked(t.state) and p.colors(t.state).size()==1,"BaronI opens name and only first color")
 check(p.edit(0,"◇Z",0).ok,"normal name edit atomically commits")
 check(not p.activate(0,12,int(t.state.revision)).ok,"locked color server-side refusal")
 for i: int in range(4):
  check(p.edit(i+1,"◇".repeat(i+2),int(t.state.revision)).ok,"all5 slots "+str(i))
 check(not p.edit(5,"◇◇Z",int(t.state.revision)).ok,"sixth slot blocked")
 check(not p.edit(1,"◇z",int(t.state.revision)).ok,"case-insensitive duplicate")
 var rev:=int(t.state.revision)
 check(p.activate(0,2,rev).ok and t.display_name()=="◇Z","activation and actual display")
 check(not p.use_highest(int(t.state.revision)).ok,"2second activation delay")
 instant+=1
 check(not p.edit(0,"◇Q",int(t.state.revision)).ok,"active edit cooldown")
 instant+=1
 check(p.edit(0,"◇Q",int(t.state.revision)).ok,"active edit exactly2seconds")
 check(t.display_name()=="◇Q","active rename changes badge source")
 var previous:=JSON.stringify(t.state); var hash_before:=FileAccess.get_sha256("user://title523-unit-save.json")
 host.reject=true
 check(not p.edit(1,"◇X",int(t.state.revision)).ok,"writer failure returned")
 check(JSON.stringify(t.state)==previous and FileAccess.get_sha256("user://title523-unit-save.json")==hash_before,"failure preserves actual file and live state")
 host.reject=false
 check(not p.edit(1,"◇X",rev).ok,"stale revision")
 instant-=1
 check(not p.edit(1,"◇X",int(t.state.revision)).ok,"clock rollback")
 instant+=3
 check(p.remove(0,int(t.state.revision)).ok and int(p.data(t.state).active)==-1,"active removal restores highest")
 check(t.display_name()==t.current_name(),"highest display after removal")
 instant+=2
 check(p.activate(2,2,int(t.state.revision)).ok,"activate later slot")
 check(p.remove(0,int(t.state.revision)).ok and int(p.data(t.state).active)==1,"earlier deletion repairs active index")
 instant+=2
 check(p.use_highest(int(t.state.revision)).ok and p.data(t.state).color_rule==0,"clear restores highest and zero color")
 var roundtrip: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://title523-unit-save.json"))
 check(t.check_load(roundtrip).is_empty(),"real writer roundtrip valid")
 t.restore(roundtrip)
 check(p.data(t.state).names.size()==3 and int(p.data(t.state).active)==-1,"saved names restored")
 for color: Dictionary in t.source.personal.colors:
  var prerequisite_index:=0
  for i: int in t.source.stages.size():
   if int(t.source.stages[i].id)==int(color.stage): prerequisite_index=i
  rank(t,prerequisite_index)
  var unlocked_before: bool=p.colors(t.state).any(func(c: Dictionary) -> bool: return int(c.id)==int(color.id))
  check(not unlocked_before,"each color locked before threshold "+str(color.id))
  rank(t,prerequisite_index+1)
  check(p.edit(0,"◇Z",0).ok and p.activate(0,int(color.id),int(t.state.revision)).ok,"each color active at threshold "+str(color.id))
  check(p.display_color().is_equal_approx(Color("#"+str(color.hex))),"each ColorTable value "+str(color.color_table_id))
  if int(color.color_table_id)==412: check(p.display_color().is_equal_approx(Color("#ffde00")),"ColorTable412 yellow namespace")
 var good: Dictionary=t.state.duplicate(true)
 for mutation: String in ["slot","color","future","type","duplicate","locked"]:
  var bad:=good.duplicate(true)
  match mutation:
   "slot": bad.personal.active=4
   "color": bad.personal.color_rule=999999
   "future": bad.personal.changed_at_ms=(int(bad.last_clock)+2)*1000
   "type": bad.personal.names=[5]
   "duplicate": bad.personal.names=["◇Z","◇z"]
   "locked": bad.achieved=bad.achieved.slice(0,12)
  check(not t.validate(bad).is_empty(),"corrupt personal state "+mutation)
 var legacy:=good.duplicate(true); legacy.erase("personal")
 check(t.validate(legacy).is_empty(),"old title schema compatible")
 t.restore({"title523":legacy})
 check(p.data(t.state)==p.fresh(),"old schema migrates without granting personal name")
 print("TITLE523_PERSONAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 host.free(); quit(0 if failures.is_empty() else 1)
