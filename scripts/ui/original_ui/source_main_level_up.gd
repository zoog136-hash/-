extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 level-up presentation (UI/Main/Hud_LevelUp.csb): its
## Fx_Level_Up_Top (the reached level in BitmapFontLabel_1) and three
## Fx_Level_Up_Bottom guidance rows (Label_Title / Label_Info) filled from
## the original LevelUpEffectDesc rows of the player's class and level
## (DescOrder order; DescData_Korean texts). Rows take the three bottom nodes
## in turn, one second apart (a fourth row reuses the first node when its
## clip has ended); every clip is the CSB's own one-shot timeline, and the
## scene frees itself after the last one. Presentation only: no growth,
## stat or reward rule is read or changed here.
## TWILIGHT 근사: the client's mount point and exact delay source are not
## in the tables; the scene sits on the HUD design centre and rows start
## 1 s apart. LevelUpEffectUIType ColorIDs (30/32/33) have no Color row in
## the 523 tables, so the labels keep their authored colour.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const ROOT="UI/Main/Hud_LevelUp.csb"
const TOP="UI/Effect/Effect_Source/Fx_Level_Up_Top.csb"
const BOTTOM="UI/Effect/Effect_Source/Fx_Level_Up_Bottom.csb"
const BOTTOMS: Array[String]=["Fx_Level_Up_Bottom_01","Fx_Level_Up_Bottom_02","Fx_Level_Up_Bottom_03"]
## Seconds between guidance rows, and the length of one original clip
## (180 frames at the Cocos 60 fps timeline).
const ROW_DELAY: float=1.0
const CLIP_SECONDS: float=3.0
var level: int=0
var rows: Array[Dictionary]=[]
var started: Array=[]

func required_members() -> Array[String]:
	return [ROOT,TOP,BOTTOM]

func _root_member() -> String:
	return ROOT

## The guidance rows of `class_id` reaching `levels` (each level's rows in
## DescOrder): [{title, text, type}] with both texts present, DisplayStep > 0.
static func rows_for(class_id: int, levels: Array) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	if class_id<=0 or levels.is_empty() or not SOURCE.problem().is_empty():return found
	var wanted: Dictionary={}
	for value: Variant in levels:wanted[int(value)]=true
	var picked: Array=[]
	for row: Dictionary in SOURCE.related("LevelUpEffectDesc","ClassID",class_id):
		if not wanted.has(int(row.get("DescLevel",-1))) or int(row.get("DisplayStep",0))<=0:continue
		picked.append([int(row.DescLevel),int(row.get("DescOrder",0)),int(row.get("ID",0)),row])
	picked.sort()
	for entry: Array in picked:
		var row: Dictionary=entry[3]
		var title: String=_text(int(row.get("TitleDescID",0)))
		var text: String=_text(int(row.get("TextDescID",0)))
		if title.is_empty() and text.is_empty():continue
		found.append({"title":title,"text":text,"type":int(row.get("LevelUpEffectUITypeID",0)),"level":int(row.DescLevel),"id":int(row.get("ID",0))})
	return found

static func _text(id: int) -> String:
	if id<=0:return ""
	var row: Dictionary=SOURCE.row("DescData_Korean",id)
	return str(row.Description) if row.get("Description") is String else ""

## Plays the presentation for `reached` with `guidance` rows (rows_for).
func play_level_up(parent: Node, reached: int, guidance: Array[Dictionary]) -> Dictionary:
	level=reached
	rows=guidance.duplicate(true)
	started.clear()
	close()
	var opened: Dictionary=open_window(parent)
	if not opened.get("ok",false):return opened
	var top: Dictionary=_clip(["Fx_Level_Up_Top"],"Fx_Level_Up_Top")
	if not top.get("ok",false):
		close()
		return top
	for index: int in range(rows.size()):
		var delay: float=ROW_DELAY*float(index)
		if index==0:_show_row(0)
		else:_after(delay,_show_row.bind(index))
	_after(maxf(CLIP_SECONDS,ROW_DELAY*float(maxi(0,rows.size()-1))+CLIP_SECONDS),close)
	last_result["rows"]=rows.size()
	last_result["level"]=level
	return last_result

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Fx_Level_Up_Top/BitmapFontLabel_1"]={"role":"source_text","text":str(level)}
	for index: int in range(BOTTOMS.size()):
		spec[BOTTOMS[index]]={"visible":false}
		spec[BOTTOMS[index]+"/Label_Title"]={"role":"source_text","text":" "}
		spec[BOTTOMS[index]+"/Label_Info"]={"role":"source_text","text":" "}
	return spec

## Row `index` on bottom node index % 3: its texts, shown, clip from frame 0.
func _show_row(index: int) -> Dictionary:
	if not is_open() or index>=rows.size():return {"ok":false}
	var node: String=BOTTOMS[index%BOTTOMS.size()]
	var row: Dictionary=rows[index]
	for pair: Array in [["Label_Title",str(row.get("title",""))],["Label_Info",str(row.get("text",""))]]:
		var located: Dictionary=_locate(_scene,_out,node+"/"+str(pair[0]))
		if located.get("ok",false):located.player.set_bound_text(int(located.offset),str(pair[1]) if not str(pair[1]).is_empty() else " ")
	var shown: Dictionary=_out.get("/"+node,{})
	if not shown.is_empty():_scene.set_bound_visible(int(shown.offset),true)
	var played: Dictionary=_clip([node],"Fx_Level_Up_Bottom")
	if played.get("ok",false):started.append({"row":index,"node":node})
	return played

## Plays `clip` on the ProjectNode player at the name path `names`.
func _clip(names: Array, clip: String) -> Dictionary:
	# The exact root path: Fx_Level_Up_Top also names its own inner node.
	var entry: Dictionary=_out.get("/"+"/".join(PackedStringArray(names)),{})
	if str(entry.get("kind",""))!="ProjectNode":return {"ok":false,"code":"source_level_up_project_missing","names":names}
	var chain: Array=(entry.get("chain",[]) as Array).duplicate()
	chain.append(int(entry.get("offset",-1)))
	var player: Dictionary=_scene.project_player(chain)
	if not player.get("ok",false):return player
	return player.player.play(clip,false)

func _after(seconds: float, action: Callable) -> void:
	if not is_open():return
	var timer:=Timer.new()
	timer.one_shot=true
	timer.wait_time=maxf(0.01,seconds)
	timer.timeout.connect(action)
	_scene.add_child(timer)
	timer.start()
