extends SceneTree
const STAGE=preload("res://scripts/ui/card_reveal_stage.gd")
const PROFILES=preload("res://scripts/ui/card_reveal_profiles.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("LIGHTNING_FAIL ",label)
func run() -> void:
	var stage=STAGE.new();root.add_child(stage);stage.silent=true
	var values: Array[Dictionary]=[{"name":"검증","grade":"유일"}]
	var textures: Array[Texture2D]=[]
	for category: String in ["변신","마법인형","성물"]:
		stage.present(values,textures,category);stage.playing=false
		var card=stage.cards[0]
		check(is_equal_approx(stage.duration,11.9),category+" duration adds 2s to 9.9s")
		check(is_equal_approx(card.reveal_at()-card.lightning_at(),4.0),category+" confirmation follows extended lightning")
		check(card.surface_fx.extra_lightning_seconds==2 and card.promotion_fx.extra_lightning_seconds==0,category+" only primary draw enhanced")
		# Draw cards cannot reveal merely because time was advanced.
		stage.seek(card.reveal_at());check(card.waiting_for_press and not card.name_label.visible,category+" untouched card stays closed")
		stage.seek(0.0)
		stage._reveal_card(0)
		check(not card.waiting_for_press,category+" explicit press starts reveal")
		stage.seek(card.reveal_at()-.01);check(not card.name_label.visible,category+" no premature face confirmation")
		stage.seek(card.reveal_at());check(card.name_label.visible,category+" confirmation boundary")
		stage.skip_to_result();check(not stage.playing and PROFILES.pulse(card.grade,stage.clock-card.lightning_at(),2)==0,category+" skip clears discharge")
		var old=card
		stage.present(values,textures,category);check(not old.visible and old.is_queued_for_deletion(),category+" replacement hides old cards immediately")
		await process_frame
	stage.present(values,textures,"변신",true,true)
	check(is_equal_approx(stage.duration,8.7) and stage.cards[0].extra_lightning_seconds==0,"fusion timing and effects unchanged")
	for grade: String in ["일반","고급","희귀","영웅","전설","신화","유일"]:
		var p: Dictionary=PROFILES.profile(grade);var burst: float=p.burst
		check(PROFILES.pulse(grade,burst+1.5,2)>0,grade+" additional sustained lightning")
		check(PROFILES.pulse(grade,burst+2.01,2)==0,grade+" bounded end")
		check(PROFILES.pulse(grade,burst+.01)==0,grade+" original fusion pulse end")
		check(PROFILES.pulse(grade,.028,2)==PROFILES.pulse(grade,.028),grade+" original first pulse strength")
	stage.close_reveal();check(stage.closing and not stage.visible and not stage.playing,"close hides immediately")
	stage.close_reveal();await process_frame
	print("LIGHTNING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
