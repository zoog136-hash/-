extends SceneTree
## The TWILIGHT 근사 sort / filter options of the original 523 windows
## (docs/original_ui523_approx.md): 아이템 컬렉션 Btn_Sort (전체 / 진행 중 /
## 미완성 / 완성), 몬스터 도감 Btn_Sort (모두 보기 / 진행 중 / 완료), 제작
## Btn_Sort (제작 가능 우선) and the 변신 list's 전체 Btn_Sort2 (전체 / 등급순 /
## 이름순). No original files are needed.
const ITEM_BOOK=preload("res://scripts/ui/original_ui/source_main_item_book_window.gd")
const MONSTERBOOK=preload("res://scripts/ui/original_ui/source_main_monsterbook_window.gd")
const PRODUCTION=preload("res://scripts/ui/original_ui/source_main_production_window.gd")
const CHANGE=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	var rows: Array=[{"name":"a","registered":0,"complete":false},{"name":"b","registered":1,"complete":false},{"name":"c","registered":2,"complete":true}]
	var names: Callable=func(list: Array) -> Array:return list.map(func(row: Dictionary) -> String:return str(row.name))
	check(ITEM_BOOK.STATES==["전체","진행 중","미완성","완성"],"item book states")
	check(names.call(ITEM_BOOK.filtered(rows,0))==["a","b","c"] and names.call(ITEM_BOOK.filtered(rows,1))==["b"] and names.call(ITEM_BOOK.filtered(rows,2))==["a","b"] and names.call(ITEM_BOOK.filtered(rows,3))==["c"],"item book filter")
	var books: Array=[{"ID":1},{"ID":2},{"ID":3}]
	var done: Callable=func(id: int) -> bool:return id==2
	var ids: Callable=func(list: Array) -> Array:return list.map(func(row: Dictionary) -> int:return int(row.ID))
	check(MONSTERBOOK.STATES[0]=="모두 보기","the monster book's first option is the original text")
	check(ids.call(MONSTERBOOK.filtered(books,done,0))==[1,2,3] and ids.call(MONSTERBOOK.filtered(books,done,1))==[1,3] and ids.call(MONSTERBOOK.filtered(books,done,2))==[2],"monster book filter")
	var recipes: Array[String]=["r1","r2","r3","r4"]
	check(PRODUCTION.ready_first(recipes,func(id: String) -> bool:return id in ["r2","r4"])==["r2","r4","r1","r3"],"제작 가능 우선 keeps each group's order")
	var cards: Array[Dictionary]=[{"name":"다","grade":"영웅"},{"name":"가","grade":"신화"},{"name":"나","grade":"영웅"},{"name":"라","grade":"전설"}]
	var card_names: Callable=func(list: Array) -> Array:return list.map(func(row: Dictionary) -> String:return str(row.name))
	check(CHANGE.ORDERS==["전체","등급순","이름순"],"change list orders")
	check(card_names.call(CHANGE.ordered(cards,0))==["다","가","나","라"],"전체 keeps the list order")
	check(card_names.call(CHANGE.ordered(cards,1))==["가","라","다","나"],"등급순: highest grade first, ties in list order")
	check(card_names.call(CHANGE.ordered(cards,2))==["가","나","다","라"],"이름순")
	var doc: String=FileAccess.get_file_as_string("res://docs/original_ui523_approx.md")
	check(doc.contains("TWILIGHT 근사(근거 약함)"),"the approximations are recorded in the docs")
	print("ORIGINAL_UI_APPROX523_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
