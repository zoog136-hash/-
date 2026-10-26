extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var stage=load("res://scripts/ui/card_reveal_stage.gd").new();root.add_child(stage);stage.silent=true;stage.present_showcase();stage.playing=false
	var output: String=OS.get_environment("LIGHTNING_OUTPUT")
	var rows: Array=[]
	for elapsed: float in [.028,1.8,2.3]:
		stage.seek(stage.cards[0].lightning_at()+elapsed)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/lightning-"+str(elapsed)+".png")
		rows.append({"elapsed":elapsed,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	print("LIGHTNING_CAPTURE ",JSON.stringify({"stage_duration":stage.duration,"reveal_at":stage.cards[0].reveal_at(),"lightning_at":stage.cards[0].lightning_at(),"samples":rows}))
	stage.close_reveal();await process_frame;quit()
