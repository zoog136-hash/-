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
	await native_cell_timeline()
	print("LIGHTNING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)

func native_cell_timeline() -> void:
	var parent := Node2D.new()
	var card: Control = STAGE.CARD.new()
	card.open_at = 0.0
	card.reel_seconds = 0.1
	var no_legacy: Array[Texture2D] = []
	card.configure({"name":"검증","grade":"영웅"}, no_legacy, "변신")
	var image := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	card.face.candidates.append(null)
	card.face.candidates.append(texture)
	var completed: Array[bool] = []
	STAGE._mount_result_cell(parent, card, func() -> void: completed.append(not card.visible), true)
	check(card.art_missing and card.face.candidates.size() == 1 and card.face.candidates[0] == texture, "one missing candidate and a missing result leave the verified reel image in place")
	check(card.clock == 0.0 and completed.is_empty(), "off-tree fusion cell waits for the page to mount")
	card.seek(card.promotion_at()+0.028, true)
	var primary: float = PROFILES.pulse("영웅", card.clock-card.lightning_at())
	var promotion: float = PROFILES.pulse("영웅", 0.028)
	check(promotion > 0.0 and is_equal_approx(card.face.illumination.a, minf(0.055,(primary+promotion)*0.023)), "successful fusion retains the old stacked promotion illumination")
	root.add_child(parent)
	await create_timer(0.15).timeout
	check(card.clock > 0.0 and completed.is_empty(), "mounted result cell advances the existing reel before settlement")
	await create_timer(2.05).timeout
	check(completed == [true] and not is_instance_valid(card), "result cell hands off once, after clearing the reel")
	var cancelled: Control = STAGE.CARD.new()
	cancelled.configure({"name":"검증","grade":"영웅"}, no_legacy, "변신")
	STAGE._mount_result_cell(parent, cancelled, func() -> void: completed.append(false), false)
	parent.queue_free()
	await process_frame
	check(completed == [true] and not is_instance_valid(cancelled), "closing a native page removes its pending reel")
	for fusion: bool in [false, true]:
		var missing := Node2D.new()
		var awarded := {"name":"원화 없음","grade":"영웅","source":"lineagem_patch523"}
		# No candidate texture can resolve in this fixture. Exercise the real
		# entry point even though neither the candidate nor the award has art.
		check(STAGE.play_result_cell(missing, Rect2(0, 0, 80, 130), awarded, func() -> void: completed.append(false), "변신", fusion, true, [awarded], {}), "missing source art still starts the result timeline")
		var hidden: Control = missing.get_child(0)
		check(hidden.art_missing and hidden.face.candidates.is_empty(), "no portrait is substituted for missing source art")
		hidden.seek(hidden.lightning_at()-0.01, fusion)
		check(hidden.face.illumination.a == 0.0, "pre-lightning result cell has no grade illumination")
		hidden.seek(hidden.lightning_at()+0.028, fusion)
		var extra: float = 0.0 if fusion else STAGE.CARD.DRAW_EXTRA_LIGHTNING_SECONDS
		var alpha: float = minf(0.055, PROFILES.pulse("영웅", 0.028, extra)*0.023*0.85)
		check(alpha > 0.0 and is_equal_approx(hidden.face.illumination.a, alpha) and completed == [true], "missing art preserves the old primary light before native grade and name")
		check(is_equal_approx(hidden.reveal_at()-hidden.lightning_at(), STAGE.CARD.CONFIRM_DELAY_SECONDS+extra), "missing art preserves the delay before the native grade and name")
		missing.free()
