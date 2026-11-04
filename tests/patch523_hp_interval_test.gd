extends SceneTree
const Native=preload("res://scripts/cards/native_collection_rules.gd")
const API=preload("res://scripts/lineagem_base508.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/patch523_collections.json"))
	var rows: Array=data.collections.filter(func(r: Dictionary) -> bool:return int(r.source_original.ID) in [14813,16521])
	var owned: Dictionary={}
	for category: String in Cards.CATEGORIES:owned[category]={}
	for row: Dictionary in rows:
		for member: Dictionary in row.requirements:owned[member.category][member.id]=true
	var core=Native.new();check(core.configure(data,API.cards().catalog),"source configure")
	var typed_rows: int=0
	for row: Dictionary in core.definitions:
		for effect: Dictionary in row.effects:
			if Native.TYPED_DAMAGE_CODES.has(Native.effect_code(effect)):
				typed_rows+=1
				check(effect.native_supported,"typed reduction supported with exact native unit")
	check(typed_rows==56,"exact56 newly supported typed damage rewards")
	var profile: Dictionary=data.source_server_limits.filter(func(r: Dictionary) -> bool:return int(r.ServerLimitSetID)==772)[0]
	var context: Dictionary={"source_snapshot":"base508","ServiceRegionCode":profile.ServiceRegionCode,"WorldNo":profile.WorldNo}
	var state: Dictionary={"owned":owned,"source_server_context":context}
	var derived: Dictionary=core.derive(state)
	for row: Dictionary in rows:
		check(derived.completed.has(row.id),"eligible interval collection completes "+str(row.id))
		var effect: Dictionary=row.effects.filter(func(e: Dictionary) -> bool:return not e.source_original.nested_intervals.is_empty())[0]
		check(not derived.totals.has("native_HPIntervalBonus:raw"),"reference ID never enters stat totals")
		var base: float=1.0 if int(row.source_original.ID)==14813 else 3.0
		for sample: Array in [[1000,0],[701,0],[700,base],[610,base],[601,base],[600,base+1],[510,base+1],[501,base+1],[500,base+2],[1,base+2],[0,0],[-1,0],[1001,0]]:
			var active: Array=Native.interval_effects(effect,int(sample[0]),1000)
			check((active.is_empty() and sample[1]==0) or (active.size()==1 and active[0].value==sample[1]),"ceil HP boundary "+str(row.id)+" "+str(sample[0]))
		check(Native.interval_effects(effect,601,1000,false)[0].value==base+1,"explicit floor policy differs only at declared boundaries")
		check(Native.interval_effects(effect,10,0).is_empty(),"invalid maximum grants nothing")
		var bad: Dictionary=effect.duplicate(true);bad.source_original.nested_intervals[1].High=70
		check(not Native.interval_supported(bad),"overlapping source intervals blocked")
		bad=effect.duplicate(true);bad.source_original.nested_intervals[0].bonus.BonusApplicationTargetID=99
		check(not Native.interval_supported(bad),"mismatched exact target blocked")
	check(core.derive({"owned":owned}).completed.keys().all(func(id: String) -> bool:return id not in ["base508:collection:14813","base508:collection:16521"]),"missing server context remains blocked")
	print("HP_INTERVAL_STAGE units passed; loading Main")
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world)
	for frame: int in range(10):await process_frame
	print("HP_INTERVAL_STAGE Main ready")
	world.set_process(false);world.save_timer=-100000
	var save_before: String=FileAccess.get_file_as_string(world.save_path())
	world.card_draw_fusion.owned=owned.duplicate(true);world._invalidate_equipment_static()
	check(world.card_collections.set_source_server_context(context),"explicit matching context only in isolated fixture")
	world.hp=world._effective_max_hp()
	var stun: int=world._stun_resistance_stat();var fear: int=world._fear_resistance_stat()
	var rebuilds: int=world.card_collections.rebuild_count
	var maximum: int=world._effective_max_hp();world.hp=maxi(1,int(maximum*.5))
	check(world._stun_resistance_stat()==stun+3,"actual World stun reader uses live HP")
	check(world._fear_resistance_stat()==fear+5,"actual World fear reader uses live HP")
	check(world.card_collections.rebuild_count==rebuilds,"HP query does not rebuild1793 ownership rows")
	print("HP_INTERVAL_STAGE live readers passed; opening UI")
	world.hud.open_normal_card_collections("마법인형")
	for frame: int in range(6):await process_frame
	var view=world.hud.normal_card_collection_view
	var texts: Array=view.totals_body.find_children("*","Label",true,false).map(func(label: Label) -> String:return label.text)
	check(texts.any(func(t: String) -> bool:return t.contains("+5% | +5%")),"actual effect panel shows active HP branch and maximum")
	world.hp=maximum;view.refresh()
	texts=view.totals_body.find_children("*","Label",true,false).map(func(label: Label) -> String:return label.text)
	check(texts.any(func(t: String) -> bool:return t.contains("0% | +5%")),"open panel updates HP effect without ownership changes")
	check(world.card_collections._completed.has("base508:collection:16521"),"HP outside active intervals does not undo acquisition completion")
	world.hp=0
	check(world.card_collections.interval_bonus("fear_resistance:percent",0,maximum)==0,"dead player has no conditional branch")
	check(not world.card_collections.set_source_server_context({}),"clear native context")
	check(world.card_collections.interval_bonus("fear_resistance:percent",50,100)==0,"clearing eligibility removes dynamic bonus")
	check(FileAccess.get_file_as_string(world.save_path())==save_before,"HP reads and UI never write saves")
	# Real source ownership/context drives the live damage channels as a whole;
	# then isolate each channel with a cache fixture to verify routing/rounding.
	var native_totals: Dictionary=world.card_collections.totals.duplicate(true)
	for kind: String in ["melee","ranged","magic","poison"]:
		world.card_collections.totals={kind+"_damage_reduction:flat":3,kind+"_damage_reduction:percent":20,"critical_damage_reduction:flat":2}
		check(world.card_collections.incoming_damage(100,kind)==78,"typed flat then percent "+kind)
		check(world.card_collections.incoming_damage(100,kind,true)==76,"critical flat only on critical "+kind)
		check(world.card_collections.incoming_damage(100,"unknown")==100,"unknown damage scope never guessed")
		check(world.card_collections.incoming_damage(1,kind)==1,"existing minimum retained "+kind)
	world.card_collections.totals={"poison_damage_reduction:flat":3,"poison_damage_reduction:percent":20}
	world.hp=maximum;world._on_player_poison_tick(10)
	check(world.hp==maximum-6,"actual poison tick consumer reads the typed channel")
	world.card_collections.totals=native_totals
	check(FileAccess.get_file_as_string(world.save_path())==save_before,"typed consumer does not save")
	world.queue_free();for frame: int in range(3):await process_frame
	print("PATCH523_HP_INTERVAL_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"policy":Native.HP_POLICY}))
	quit(0 if failures.is_empty() else 1)
