extends PanelContainer
## In-field 오림의 흔적 panel while a run is active: hero HP, Orim level/exp,
## owned skills and the level-up skill cards (+ reroll). Plain controls: the
## original Mission_Dungeon_TracesOrim*.csb windows are not bound yet
## (docs/orim523_missing_rules.md). No image is drawn or substituted.
var world: Node
var status: Label
var cards: HBoxContainer
var reroll_button: Button

func configure(owner: Node) -> void:
	world = owner
	name = "Orim523Hud"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position = Vector2(-300,64)
	custom_minimum_size = Vector2(600,0)
	var box := VBoxContainer.new()
	add_child(box)
	status = Label.new()
	status.name = "Orim523Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	cards = HBoxContainer.new()
	cards.name = "Orim523Cards"
	box.add_child(cards)
	reroll_button = Button.new()
	reroll_button.name = "Orim523Reroll"
	reroll_button.pressed.connect(func() -> void:
		var result: Dictionary = world.dungeon_play.reroll()
		if not result.get("ok",false): world.hud.show_message(str(result.get("reason","다시 고르기 실패")))
		refresh())
	box.add_child(reroll_button)
	world.dungeon_play.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_instance_valid(world): return
	var info: Dictionary = world.dungeon_play.orim_status()
	visible = not info.is_empty() and str(world.dungeon_play.state.active.get("status",""))=="active"
	if not visible: return
	var skills: Array[String] = []
	for skill: Dictionary in info.skills: skills.append("%s Lv%d" % [str(skill.name),int(skill.level)])
	status.text = "오림의 흔적 · %s HP %d/%d · 오림 Lv %d (%d/%d) · %s\n스킬: %s" % [str(info.hero),int(info.hp),int(info.max),int(info.level),int(info.exp),int(info.next),str(info.land),", ".join(skills)]
	var signature: String = JSON.stringify(info.cards)
	if cards.get_meta("signature","")!=signature:
		cards.set_meta("signature",signature)
		for child: Node in cards.get_children(): child.queue_free()
		for card: Dictionary in info.cards:
			var button := Button.new()
			button.name = "Orim523Card_%d" % int(card.group)
			button.text = "%s\n[%s]" % [str(card.name),str(card.type)]
			button.tooltip_text = str(card.desc)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 56
			var group: int = int(card.group)
			button.pressed.connect(func() -> void:
				var result: Dictionary = world.dungeon_play.choose_skill(group)
				world.hud.show_message(("스킬 습득: "+str(result.get("name",""))) if result.get("ok",false) else str(result.get("reason","")))
				refresh())
			cards.add_child(button)
	cards.visible = not (info.cards as Array).is_empty()
	reroll_button.visible = cards.visible and int(info.reroll_cost)>0
	reroll_button.text = "다시 고르기 (%d회째 · 비용 %d)" % [int(info.rerolls)+1,int(info.reroll_cost)]
