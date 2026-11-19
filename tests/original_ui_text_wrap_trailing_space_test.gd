extends SceneTree
## source_text_wrap (Cocos3.6 word wrap): a line's trailing spaces take no
## width. A text whose line ends with a space just past the box width (before
## a newline or at the end) failed as original_unbreakable_word_exceeds_source_width
## and the whole 시련 던전 detail page with it, as did a closing mark after
## CJK at the very end that did not fit ("...등장합니다.").
const WRAP=preload("res://scripts/ui/original_ui/source_text_wrap.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_TEXT_WRAP_TRAILING_SPACE_FAIL: ",label)

func _initialize() -> void:
	var font: FontFile=load("res://assets/fonts/NotoSansKR.ttf")
	var width: float=font.get_string_size("가나다 라마",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+0.5
	var tail: Dictionary=WRAP.lines(font,"가나다 라마 ",18,width)
	check(tail.get("ok",false) and Array(tail.lines)==["가나다 라마"],"a trailing space at the end takes no width: "+str(tail))
	var newline: Dictionary=WRAP.lines(font,"가나다 라마 \n바사",18,width)
	check(newline.get("ok",false) and Array(newline.lines)==["가나다 라마","바사"],"a trailing space before a newline takes no width: "+str(newline))
	var wrapped: Dictionary=WRAP.lines(font,"가나다 라마 바사",18,width)
	check(wrapped.get("ok",false) and Array(wrapped.lines)==["가나다 라마","바사"],"ordinary wrapping is unchanged: "+str(wrapped))
	var dot: Dictionary=WRAP.lines(font,"가나다 라마.",18,font.get_string_size("가나다 라마",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+0.5)
	check(dot.get("ok",false) and Array(dot.lines)==["가나다 라마","."],"a closing mark after CJK at the end that does not fit opens the next line: "+str(dot))
	var long: Dictionary=WRAP.lines(font,"ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJ",18,width)
	check(not long.get("ok",true) and long.get("error")=="original_unbreakable_word_exceeds_source_width","a real unbreakable word still fails")
	print("ORIGINAL_UI_TEXT_WRAP_TRAILING_SPACE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
