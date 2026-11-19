extends SceneTree
## 하프 엘릭서 from the menu opens the original window: a source without a
## chosen ServerLimit context takes the default one (TWILIGHT 근사: a local
## game has no server — KR:1, else the first KR world, else the first pair)
## while nothing is invested; the menu used to open the TWILIGHT view every time.
const ELIXIR=preload("res://scripts/ui/original_ui/source_main_half_elixir_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeSource extends RefCounted:
	var pairs: Array=["KR:1","KR:2","TW:1"]

class FakeRuntime extends RefCounted:
	var source=FakeSource.new()
	var state: Dictionary={"context":"","allocations":{}}
	var executed: Array=[]
	func request(action: String, id: String="", count: int=1) -> Dictionary:
		return {"action":action,"id":id,"count":count}
	func execute(command: Dictionary) -> Dictionary:
		executed.append(command)
		if command.action=="context":state.context=command.id
		return {"ok":true}

class FakeWorld extends Node:
	var half_elixir=FakeRuntime.new()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_HALF_ELIXIR_DEFAULT_FAIL: ",label)

func _initialize() -> void:
	check(ELIXIR.default_context(["KR:3","KR:1","TW:1"])=="KR:1","KR:1 first")
	check(ELIXIR.default_context(["TW:1","KR:7"])=="KR:7","else the first KR world")
	check(ELIXIR.default_context(["TW:2"])=="TW:2" and ELIXIR.default_context([])=="","else the first pair; none without pairs")
	var world:=FakeWorld.new()
	var hud:=Node.new()
	world.add_child(hud)
	root.add_child(world)
	var window=ELIXIR.new()
	window._hud=weakref(hud)
	check(not window._context_ready(),"no context yet")
	var applied: Dictionary=window.apply_default_context()
	check(applied.ok and world.half_elixir.executed==[{"action":"context","id":"KR:1","count":1}] and window._context_ready(),"the default context goes through the runtime's own context request")
	world.half_elixir.state={"context":"","allocations":{"str":1}}
	check(window.apply_default_context().get("code")=="source_half_elixir_context_locked" and world.half_elixir.executed.size()==1,"an invested state is never switched")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_half_elixir_window.gd")
	check(text.contains("if runtime.source!=null and not _context_ready():apply_default_context()"),"open applies the default before falling back")
	check(text.contains("runtime.link_bundled()"),"with no source recorded the bundled 523 definitions are linked (no copy)")
	var runtime_text: String=FileAccess.get_file_as_string("res://scripts/growth/half_elixir_runtime.gd")
	check(runtime_text.contains("next.source_sha256 = DEFINITIONS.SOURCE_SHA") and not runtime_text.substr(runtime_text.find("func link_bundled")).left(900).contains("copy_absolute"),"link_bundled records the bundled SHA through the save writer")
	world.free()
	print("ORIGINAL_UI_HALF_ELIXIR_DEFAULT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
