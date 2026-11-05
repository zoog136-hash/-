extends SceneTree
const P=preload("res://scripts/cards/source_card_operation_presentation.gd")
const Skill=preload("res://scripts/cards/skill_awakening_runtime.gd")
const Option=preload("res://scripts/cards/option_awakening_runtime.gd")
const Craft=preload("res://scripts/ui/native_card_craft_view.gd")
const SkillView=preload("res://scripts/ui/card_skill_awakening_view.gd")
const Layout=preload("res://data/ui/base508_skill_awakening_layout.json")
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label);push_error(label)
func denied(reply: Dictionary) -> bool:
	return reply.get("handled",false) and not reply.get("ok",true) and not reply.get("committed",true) and reply.get("code")=="source_presentation_unregistered"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for operation: String in [P.AWAKENING,P.GROWTH,P.CRAFT]:
		check(not P.available(operation) and denied(P.request(operation)),"unregistered original scene has a terminal refusal "+operation)
		var capability: Dictionary=P.capability(operation)
		check(capability.known and not capability.presentation_registered and not capability.original_renderer_registered,"source metadata does not register an interactive scene "+operation)
		capability.presentation_registered=true;capability.source.clear()
		check(not P.available(operation) and not P.capability(operation).source.is_empty(),"caller cannot mutate registration through a snapshot "+operation)
	for operation: String in [P.AWAKENING,P.GROWTH]:
		var source: Dictionary=P.capability(operation).source
		check(Layout.data.screens.has(source.member) and Layout.data.evidence.any(func(row: Dictionary) -> bool:return row.name==source.member and row.sha256==source.sha256),"exact supplied CSB metadata identity retained "+operation)
	check(P.capability(P.CRAFT).source.candidate_only and not P.capability(P.CRAFT).source.recipe_node_binding_verified,"ProductionScene is a candidate, never a guessed recipe binding")
	check(denied(P.request("unknown")) and not P.capability("unknown").known,"unknown operation cannot fall through to another consumer")
	var skill=Skill.new();var option=Option.new()
	var before: int=hash([skill.progress,skill.selection_rng.state,option.progress,option._busy])
	# world is deliberately null: a refusal must precede any supplier, legacy
	# debit, context, prepare, save or RNG access.
	for attempt: int in range(3):
		check(denied(skill.request_operation("source:m523:2:25152")),"paid awakening refuses before world access")
		check(denied(skill.request_experience_feed("source:m523:2:25152","source:m523:2:25152")),"growth refuses before world access")
		check(denied(option.craft_nemesis()) and denied(option._craft_native_nemesis()),"both craft paths refuse before supplier or legacy access")
	check(hash([skill.progress,skill.selection_rng.state,option.progress,option._busy])==before,"refused APIs preserve progress, busy state and selection RNG")
	var craft=Craft.new();craft.configure(option)
	check(not craft is Node and denied(craft.refresh()) and denied(craft._execute()),"old craft adapter cannot construct a screen or execute a purchase")
	var view=SkillView.new();root.add_child(view);view.configure(skill,"source:m523:2:25152");view._execute();view.refresh_growth()
	check(view.get_child_count()==0 and denied(view._feed_experience()),"stale skill view cannot create authored controls or consume materials")
	view.free()
	print("SOURCE_CARD_PRESENTATION_BOUNDARY ",JSON.stringify({"checks":checks,"errors":errors,"scope":"UNREGISTERED_SOURCE_UI; NO_ORIGINAL_SCREEN_PLAYBACK"}))
	quit(0 if errors.is_empty() else 1)
