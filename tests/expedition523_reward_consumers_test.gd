extends SceneTree
## Actual Main + already-published optional consumer code and verified private inputs.
const QA=preload("res://tests/qa_class_selection.gd")
const Bridge=preload("res://scripts/expedition/reward_bridge.gd")
const RewardCards=preload("res://scripts/expedition/reward_cards.gd")
const Model=preload("res://scripts/expedition/estimated_simulation.gd")
var world:TwilightWorld
var checks:int=0
var failures:Array=[]
var counts:Dictionary={"legacy_material":0,"wallet":0,"native_buff":0,"preserved":0}
var full_box_results:Array=[]
var ticket_results:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);printerr("REWARD_CONSUMER_FAIL ",label)
func canonical(value:Variant)->Variant:
	if value is float and value==floorf(value):return int(value)
	if value is Array:
		var result:Array=[]
		for child:Variant in value:result.append(canonical(child))
		return result
	if value is Dictionary:
		var result:Dictionary={}
		for key:Variant in value:result[key]=canonical(value[key])
		return result
	return value
func snap(include_world_rng:bool=true)->String:
	var shop:Variant=Bridge.shop(world)
	return JSON.stringify(canonical([world.inventory,world.item_instances,world.gold,world.warehouse.snapshot(),world.expedition_local.export_state(),world.active_item_buffs,world.item_use_cooldowns,world.card_draw_fusion.export_state(),world.skill_awakening.export_state(),world.rng.state if include_world_rng else 0,world.card_draw_fusion.rng.state,world.next_item_instance_id,world.crafting_log,shop.export_state() if shop!=null else {}]),"",true)
func confirm()->void:
	var modal:Node=world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(modal!=null,"actual confirmation")
	if modal!=null:(modal.find_child("ConfirmTransaction",true,false) as Button).pressed.emit()
func _initialize()->void:call_deferred("run")
func run()->void:
	world=(load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world);check(QA.enter_game(world),"actual Main entry")
	world.process_mode=Node.PROCESS_MODE_DISABLED;world.save_timer=-100000.0
	var source:RefCounted=world.get_expedition_catalog()
	check(source.ready(),"unchanged expedition pack installed")
	if not source.ready():finish();return
	var peer:Variant=Bridge.provider();var peer_use:Variant=Bridge.consumer()
	if "--verify-full-boxes" in OS.get_cmdline_user_args():
		await full_boxes(source,peer,peer_use)
		finish();return
	if "--verify-owned-tickets" in OS.get_cmdline_user_args():
		await owned_tickets(source)
		finish();return
	if "--verify-owned-tickets-restart" in OS.get_cmdline_user_args():
		owned_tickets_restart()
		finish();return
	var require_peer:bool="--require-peer-consumers" in OS.get_cmdline_user_args()
	check(not require_peer or (peer!=null and peer_use!=null and peer.definition_count() in [2568,34743]),"requested real PR238 code and existing verified payload")
	var completed:Dictionary={}
	for row:Dictionary in source.rows("MagicDollExpeditionCompleteRewardView"):
		completed[int(source.record("Reward",int(row.RewardID)).RewardClassID)]=true
	var total:int=0
	for item:Dictionary in source.rows("ItemClass"):
		var id:int=int(item.ID)
		if completed.has(id) or id in [75184,75194,95624,118992] or not RewardCards.fixed_target(source,id).is_empty():continue
		total+=1
		var key:String="%d:1:0"%id
		world.expedition_local.state.storage[key]=3
		check(world.expedition_local.withdraw(key,3).ok,"real inventory receipt "+str(id))
		var typed:String=world.expedition_local.state.issued[key]
		var existing:Dictionary=Bridge.existing_target(world,item,1,0)
		var executable_buff:bool=peer!=null and peer_use!=null and id in [859,230592]
		var before:String=snap();var disk:String=FileAccess.get_sha256(world.save_path())
		if existing.is_empty() and not executable_buff:
			world._on_inventory_item_activated(typed)
			check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"unavailable/test/excluded reward preserves state "+str(id))
			counts.preserved+=1;continue
		if executable_buff and Bridge.supplier()!=null:
			var preview:Dictionary=world.stage_source_item_grants([{"item_class_id":id,"amount":3,"bless_raw":1,"enchant":0}],{"kind":"expedition523_contract_preview","receipt_key":key})
			# Registration belongs to the real handoff. A missing catalog must fail
			# purely; an already registered one may stage, but never publish or save.
			check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"actual supplier preview never mutates inventory or receipt "+str(id))
			if preview.get("ok",false):check(preview.overrides.has_all(["inventory","item_instances","gold"]),"actual supplier returns full candidate rather than delta "+str(id))
		world.equipment_collections.save_blocked=true
		world._on_inventory_item_activated(typed)
		check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"failed receipt handoff preserves all state "+str(id))
		world.equipment_collections.save_blocked=false
		world._on_inventory_item_activated(typed)
		var destination:String
		if not existing.is_empty():
			destination=str(existing.wallet) if not str(existing.wallet).is_empty() else str(existing.record.name)
			counts[existing.kind]+=1
		else:
			destination=str(peer.cached_definition(str(id)).native_record.name)
			counts.native_buff+=1
		check(not world.inventory.has(typed) and int(world.inventory.get(destination,0))>=3,"exact destination receipt "+str(id))
		if executable_buff and Bridge.supplier()!=null:
			check(world.expedition_local.state.native_handoffs.get(destination)==key,"actual supplier output and receipt provenance committed together "+str(id))
			before=snap();disk=FileAccess.get_sha256(world.save_path())
			for bad:Array in [[id,0,1,0],[id,1,0,0],[id,1,1,1],[-1,1,1,0]]:
				var invalid:Dictionary=world.stage_source_item_grants([{"item_class_id":bad[0],"amount":bad[1],"bless_raw":bad[2],"enchant":bad[3]}],{"kind":"expedition523_invalid_preview"})
				check(not invalid.get("ok",false) and snap()==before and FileAccess.get_sha256(world.save_path())==disk,"actual supplier rejects invalid source grant without live mutation "+str(id)+str(bad))
		before=snap();world._on_inventory_item_activated(typed)
		check(snap()==before,"empty source stack cannot duplicate receipt "+str(id))
		if not executable_buff:continue
		world.ui_preferences.item_locks[destination]=true;before=snap()
		world._on_inventory_item_activated(destination)
		check(snap()==before,"actual source consumer respects item lock "+str(id))
		world.ui_preferences.item_locks.erase(destination)
		before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
		world._on_inventory_item_activated(destination)
		check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"real PR238 effect failure preserves item buff cooldown and RNG "+str(id))
		world.equipment_collections.save_blocked=false
		world._on_inventory_item_activated(destination)
		var buff:Dictionary=world.active_item_buffs.get(destination,{})
		check(int(world.inventory.get(destination,0))==2 and int(buff.get("source_item_class_id",0))==id and int(buff.get("duration",0))==1800,"real published PR238 consumes and applies original buff "+str(id))
		check(int(world._active_item_buff_total("melee_damage" if id==859 else "damage_reduction"))==(3 if id==859 else 2),"actual game stat consumer reads source buff "+str(id))
	check(total==105 and counts.legacy_material==26 and counts.wallet==4,"entire105 scope with26 safe legacy and4 wallet bindings")
	check(not require_peer or counts.native_buff==2,"two real optional effects executed, not synthetic fixture")
	var disk:String=FileAccess.get_sha256(world.save_path());var before:String=snap(false)
	world._load_game(true)
	check(FileAccess.get_sha256(world.save_path())==disk and snap(false)==before,"all receipts effects wallets and provenance survive byte-preserving reload")
	# Existing warehouse and local price rules; no native automation engine copied.
	var name:String="블랙 미스릴 판금"
	before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
	world._warehouse_transfer(name,1,"deposit","")
	check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"warehouse save failure preserves inventory and warehouse")
	world.equipment_collections.save_blocked=false
	var held:int=int(world.inventory.get(name,0));world._warehouse_transfer(name,1,"deposit","")
	check(int(world.inventory.get(name,0))==held-1 and int(world.warehouse.stacks.get(name,0))==1,"existing warehouse stores received material")
	world._warehouse_transfer(name,1,"withdraw","")
	check(int(world.inventory.get(name,0))==held and not world.warehouse.stacks.has(name),"warehouse withdrawal restores same stack")
	var sell_quote:Dictionary=world.LOCAL_BUYBACK.quote(name,1,"",world.inventory,world._craft_item_index(),world.item_instances,world.equipped_items,world.gold)
	check(sell_quote.ok,"material uses existing local buyback price without fake equipment ID")
	if not sell_quote.ok:printerr("SELL_DIAGNOSTIC ",sell_quote);finish();return
	before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
	world._sell_shop_item(name,1,"")
	check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"sale save failure preserves material and gold")
	world.equipment_collections.save_blocked=false;var gold:int=world.gold
	world._sell_shop_item(name,1,"")
	check(world.gold==gold+int(sell_quote.payment) and int(world.inventory.get(name,0))==held-1,"existing local sale consumes exact received quantity and price")
	var restricted:String=world.expedition_local.state.issued["3732:1:0"]
	before=snap();world._warehouse_transfer(restricted,1,"deposit","");world._sell_shop_item(restricted,1,"")
	check(snap()==before,"source non-storable/nontradable material cannot use legacy transfer bypass")
	# Existing TWILIGHT recipe, exact unchanged costs/output; controlled other ingredients.
	var recipe:Dictionary=world.crafting.recipes["scroll_gear_001"]
	var blueprint:int=int(world.inventory.get("신화 제작 비법서",0))
	# Preserve the normal ammo keys; omitting them deliberately invokes legacy starter-ammo migration.
	world.inventory={"신화 제작 비법서":blueprint,"화살":int(world.inventory.get("화살",0)),"총알":int(world.inventory.get("총알",0))};world.item_instances={};world.gold=int(recipe.adena)+10000
	for material:Dictionary in recipe.materials:
		if material.item!="신화 제작 비법서":world.inventory[str(material.item)]=int(material.quantity)
	world._sync_item_instances();check(world._save_game(true)==OK,"existing recipe fixture baseline")
	var craft_quote:Dictionary=world._craft_quote("scroll_gear_001",1)
	check(craft_quote.ok,"received blueprint is an ordinary stack ingredient, not fake equipment")
	if not craft_quote.ok:printerr("CRAFT_DIAGNOSTIC ",craft_quote);finish();return
	before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
	world._craft_requested("scroll_gear_001",1)
	check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"craft save failure preserves materials output gold IDs and history")
	world.equipment_collections.save_blocked=false
	world.hud.open_crafting()
	var listing:ItemList=world.hud.workspace.find_child("CraftRecipes",true,false) as ItemList
	var view:Control=listing.get_parent()
	while view!=null and not Bridge.host_property(view,"recipe_ids") is Array:view=view.get_parent() as Control
	check(view!=null,"actual crafting view found through layout wrappers")
	if view==null:finish();return
	var index:int=view.recipe_ids.find("scroll_gear_001")
	check(index>=0,"existing crafting UI contains unchanged recipe")
	if index>=0:listing.select(index);listing.item_selected.emit(index)
	check(not view.action.disabled,"existing UI enables received source blueprint")
	view.action.pressed.emit();confirm();await process_frame
	check(int(world.inventory.get("신화 제작 비법서",0))==blueprint-1 and int(world.inventory.get(str(recipe.result.item),0))==1 and world.gold==10000,"actual crafting UI consumes source blueprint at unchanged recipe cost")
	disk=FileAccess.get_sha256(world.save_path());before=snap(false);world._load_game(true)
	check(FileAccess.get_sha256(world.save_path())==disk and snap(false)==before,"crafted output instances and history survive reconnect")
	finish()
func use_inventory(name:String)->void:
	world.hud.refresh_inventory(world.inventory)
	var ui:Control=world.hud.lineage_inventory_ui
	ui.show_inventory();ui._select_item(name)
	if int(world.inventory.get(name,0))==0:
		check(ui.detail_action.disabled,"empty stack disables actual inventory action "+name)
		world._on_inventory_item_activated(name) # Explicit stale-event rejection, not a disabled-button click.
		return
	check(not ui.detail_action.disabled,"actual inventory action enabled "+name)
	ui.detail_action.pressed.emit()

func discover_box(source:RefCounted,item_id:int,amount:int,completion_ticket:bool=false)->bool:
	# Controlled discovery in a real original-eligible job. This tests the
	# producer/claim pipeline, not the frequency of exploration discoveries.
	var spot_id:int=1 if item_id==116022 else (212 if item_id==269212 else 274)
	if completion_ticket:spot_id={166744:1,254088:112,342064:274,342074:284,352054:304,352064:332}[item_id]
	var deck:int=int(source.record("MagicDollExpeditionSpot",spot_id).BuffCardDeckID)
	var category:String={1:"변신",2:"마법인형",98:"성물"}[deck]
	var wanted_grade:String="신화" if int(source.record("MagicDollExpeditionSpot",spot_id).MinGrade)==32 else "전설"
	var identities:Array=[]
	for record:Dictionary in world.catalog_db[category]:
		if record.get("grade")!=wanted_grade:continue
		var identity:String=world.CARD_DRAW_FUSION.card_id(record)
		if not world.skill_awakening.core.eligibility(identity).ok:continue
		if world.equipped_catalog.values().any(func(r:Dictionary)->bool:return world.CARD_DRAW_FUSION.card_id(r)==identity):continue
		var spells:Array=world.skill_awakening.core.candidates(identity)
		if spells.is_empty():continue
		world.card_draw_fusion.owned[category][identity]=true
		world.skill_awakening.progress.cards[identity]={"spell_id":int(spells[0].spell_id),"level":20,"experience":"0"}
		identities.append(identity)
		if identities.size()==(4 if deck==1 else 1):break
	world.gold=20000000
	check(world._save_game(true)==OK,"controlled discovery baseline "+str(item_id))
	var started:Dictionary=world.request_expedition_start(spot_id,identities)
	check(started.get("ok",false),"actual original-eligible job starts "+str(item_id)+("" if started.get("ok",false) else str(started)))
	if not started.get("ok",false):return false
	var job:Dictionary=world.expedition_local.state.jobs.back();var linked:bool=false
	var completion_id:int=int(source.record("Reward",int(job.completion_reward_id)).RewardClassID)
	if completion_ticket:
		for row:Dictionary in source.completion_box_candidates(completion_id):
			if int(row.ItemClassID)==item_id and int(row.ItemBlessCodeID)==1 and int(row.ItemEnchant)==0 and int(row.Probability)>0:linked=true
	else:
		for row:Dictionary in source.rows("MagicDollExpeditionSpotReward"):
			if int(row.MagicDollExpeditionSpotID)==spot_id and int(row.MagicDollExpeditionGroupID)==int(job.group_id) and int(source.record("Reward",int(row.RewardID)).RewardClassID)==item_id:linked=true
	check(linked,"discovery belongs to exact original spot and card group "+str(item_id))
	if not linked:return false
	if not completion_ticket:job.sim.loot["%d:1:0"%item_id]=amount
	for event:String in job.sim.policy.normal_event_weights:job.sim.policy.normal_event_weights[event]=1 if int(event)==71 else 0
	world.expedition_local.advance(28800)
	check(job.status=="completed" or world.expedition_local.state.jobs.back().status=="completed","actual timer completes controlled exploration "+str(item_id))
	var before:String=snap();var disk:String=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
	check(not world.expedition_local.claim(int(job.id)).get("ok",false) and snap()==before and FileAccess.get_sha256(world.save_path())==disk,"producer settlement save failure preserves receipt and reward "+str(item_id))
	world.equipment_collections.save_blocked=false
	world.hud.open_expedition();await process_frame
	var view:Control=world.hud.workspace.find_child("ExpeditionSourceView",true,false)
	view._refresh_jobs();view.claim_button.pressed.emit();confirm();await process_frame
	var key:String="%d:1:0"%item_id
	if completion_ticket:
		var completion_key:String="%d:1:0"%completion_id
		check(int(world.expedition_local.state.storage.get(completion_key,0))==1,"real completion container produced before ticket discovery "+str(item_id))
		var candidates:Array=source.completion_box_candidates(completion_id);var seed:int=-1;var probe:=RandomNumberGenerator.new()
		for candidate in range(500000):
			probe.seed=candidate
			if int(Model.choose(candidates,"Probability",probe).ItemClassID)==item_id:seed=candidate;break
		check(seed>=0,"controlled seed reaches native completion ticket without changing weights "+str(item_id))
		if seed<0:return false
		world.expedition_local.random.seed=seed;world.expedition_local.state.rng_state=str(world.expedition_local.random.state)
		check(world._save_game(true)==OK,"completion ticket RNG baseline")
		before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
		check(not world.expedition_local.open_box(completion_key).ok and snap()==before and FileAccess.get_sha256(world.save_path())==disk,"completion opening failure preserves container ticket and original RNG")
		world.equipment_collections.save_blocked=false;view._refresh_storage()
		for index in range(view.storage_picker.item_count):
			if view.storage_picker.get_item_metadata(index)==completion_key:view.storage_picker.select(index);view.storage_picker.item_selected.emit(index)
		view.open_button.pressed.emit();confirm();await process_frame
		check(not world.expedition_local.state.storage.has(completion_key),"actual completion UI consumes container exactly once")
	check(world.expedition_local.state.receipts.has(str(job.id)) and int(world.expedition_local.state.storage.get(key,0))==amount,"actual completion UI saves receipt and discovered box together "+str(item_id))
	before=snap();check(not world.expedition_local.claim(int(job.id)).get("ok",false) and snap()==before,"duplicate producer settlement cannot grant another box "+str(item_id))
	before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
	check(not world.expedition_local.withdraw(key,amount).get("ok",false) and snap()==before and FileAccess.get_sha256(world.save_path())==disk,"receipt withdrawal failure preserves producer inventory and ledger "+str(item_id))
	world.equipment_collections.save_blocked=false
	view._refresh_storage()
	for index in range(view.storage_picker.item_count):
		if view.storage_picker.get_item_metadata(index)==key:view.storage_picker.select(index);view.storage_picker.item_selected.emit(index)
	view.withdraw_button.pressed.emit();confirm();await process_frame
	var typed:String=str(world.expedition_local.state.issued.get(key,""))
	check(not typed.is_empty() and int(world.inventory.get(typed,0))==amount and not world.expedition_local.state.storage.has(key),"actual storage UI withdraws exact discovered quantity "+str(item_id))
	if completion_ticket:return true
	before=snap();disk=FileAccess.get_sha256(world.save_path());world.equipment_collections.save_blocked=true
	use_inventory(typed)
	check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"supplier and exploration receipt save failure rolls back together "+str(item_id))
	world.equipment_collections.save_blocked=false;use_inventory(typed)
	return true

func full_boxes(source:RefCounted,peer:Variant,peer_use:Variant)->void:
	check(peer!=null and peer_use!=null and Bridge.supplier()!=null,"actual published consumer and supplier modules installed")
	if peer==null or peer_use==null or Bridge.supplier()==null:return
	var zip_path:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--full238-zip="):zip_path=arg.trim_prefix("--full238-zip=")
	check(not zip_path.is_empty() and FileAccess.get_sha256(zip_path)=="fb2a4de030b7d302fd7d8d2c541ca3cc8d1fbe246cf67ef574d812d3ccb6fc8d","exact newly materialized ZIP")
	if zip_path.is_empty():return
	var installed:Dictionary={"ok":peer.pack_identity().get("sha256")=="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"}
	if not installed.ok:installed=peer.install_zip(zip_path)
	check(installed.get("ok",false),"official validated consumer-local root and136 shards available; reuse identical installation")
	if not installed.get("ok",false):return
	check(peer.definition_count()==34743 and peer.pack_identity().get("sha256")=="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27","actual full catalog loaded from installed pinned root")
	# Register the complete five-box output closure through the real owner
	# registrar. The full verified document and probabilities remain unchanged;
	# unrelated34k items need no duplicate catalog/UI allocation in this test.
	var scope:Dictionary=peer.data().duplicate(false)
	var needed:Dictionary={}
	for id:int in [116022,341384,341424,341434,269212]:
		needed[str(id)]=true
		for reward:Dictionary in Bridge.definition(peer,str(id)).native_record.source_use_spec.rewards:needed[str(int(reward.item_class_id))]=true
	scope.native_item_ids=needed.keys();scope.catalog_aliases={}
	for id:String in needed:
		if peer.data().catalog_aliases.has(id):scope.catalog_aliases[id]=peer.data().catalog_aliases[id]
	var registration:Dictionary=peer.register_catalog(scope,world.catalog_db)
	check(int(registration.get("added",0))>0,"actual owner catalog registration of complete scoped closure, no synthetic supplier")
	world._index_catalog_item_sources();world.hud.set_catalog_data(world.catalog_db,world.catalog_image_index)
	world.level=99
	var relationships:int=0
	for id:int in [116022,341384,341424,341434,269212]:
		var definition:Dictionary=Bridge.definition(peer,str(id));var record:Dictionary=definition.native_record
		var action:Dictionary=peer_use.action_record(world,record);var spec:Dictionary=action.source_use_spec
		check(definition.original_item==source.record("ItemClass",id),"exact producer/consumer original item row "+str(id))
		check(spec.activation_status=="unrestricted","original use constraints remain resolved "+str(id))
		var rewards:Array=spec.rewards;var amount:int=rewards.size()
		if not await discover_box(source,id,amount):return
		var key:String="%d:1:0"%id;var name:String=str(record.name)
		check(int(world.inventory.get(name,0))==amount and world.expedition_local.state.native_handoffs.get(name)==key,"actual stage supplier commits native box and receipt provenance "+str(id))
		var before:String=snap(false);var disk:String=FileAccess.get_sha256(world.save_path());world._load_game(true)
		check(snap(false)==before and FileAccess.get_sha256(world.save_path())==disk,"native box receipt survives byte-preserving reconnect "+str(id))
		for reward:Dictionary in rewards:
			world.item_use_cooldowns.clear()
			var seed:int=-1
			if id!=269212:
				var probe:=RandomNumberGenerator.new()
				for candidate in range(500000):
					probe.seed=candidate
					var selected:Dictionary=peer_use.select_rewards(spec,world.BASE508.source_class_id(world.job_class),probe,1)
					if selected.get("ok",false) and int(selected.rewards[0].source_entity_id)==int(reward.source_entity_id):seed=candidate;break
				check(seed>=0,"controlled seed selects an unchanged original weighted row "+str(reward.source_entity_id))
				if seed<0:return
				world.rng.seed=seed
			check(world._save_game(true)==OK,"relationship baseline "+str(reward.source_entity_id))
			var output:Dictionary=peer.variant_item(Bridge.definition(peer,str(int(reward.item_class_id))).native_record,int(reward.bless_raw))
			var wallet:String=peer.currency_identity_name(output)
			var output_key:String=wallet if not wallet.is_empty() else str(output.name)
			var previous:int=world.gold if wallet=="아데나" else int(world.inventory.get(output_key,0))
			var held:int=int(world.inventory.get(name,0));before=snap();disk=FileAccess.get_sha256(world.save_path())
			world.ui_preferences.item_locks[name]=true;use_inventory(name)
			check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"locked native box cannot open or consume "+str(id));world.ui_preferences.item_locks.erase(name)
			if not spec.item_requirements.get("can_use_when_invisible",false):
				world.active_skill_buffs["fixture-conceal"]={"stealth":true};use_inventory(name)
				check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"original concealment restriction preserves box "+str(id));world.active_skill_buffs.erase("fixture-conceal")
			if id==269212:
				use_inventory(name);var dialog:Control=world.hud.get_meta("patch523_reward_choice")
				check(dialog.choices.item_count==4,"actual selection UI lists four source entities")
				dialog.find_child("CancelSourceReward",true,false).pressed.emit();await process_frame
				check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"selection cancel never debits source box")
				use_inventory(name);dialog=world.hud.get_meta("patch523_reward_choice")
				check(not Bridge.claim_selection(world,record,int(reward.item_class_id)) and snap()==before,"reward item ID cannot replace source selection entity ID")
				for index in range(dialog.choices.item_count):
					if int(dialog.choices.get_item_metadata(index))==int(reward.source_entity_id):dialog.choices.select(index);dialog.choices.item_selected.emit(index)
				world.ui_preferences.item_locks[name]=true;dialog.confirm.pressed.emit()
				check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"selection confirmation rechecks newly added source lock");world.ui_preferences.item_locks.erase(name)
				world.equipment_collections.save_blocked=true;dialog.confirm.pressed.emit()
				check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"selection failure preserves source output and receipt together")
				world.equipment_collections.save_blocked=false;dialog.confirm.pressed.emit();await process_frame
			else:
				world.equipment_collections.save_blocked=true;use_inventory(name)
				check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"weighted box failure preserves input output receipt and RNG "+str(id))
				world.equipment_collections.save_blocked=false;use_inventory(name)
			var after:int=world.gold if wallet=="아데나" else int(world.inventory.get(output_key,0))
			check(int(world.inventory.get(name,0))==held-1 and after==previous+int(reward.amount),"actual source quantity blessing and exact output applied "+str(reward.source_entity_id))
			check(world.expedition_local.state.native_handoffs.get(name)==key,"box use preserves producer receipt provenance "+str(id))
			before=snap(false);disk=FileAccess.get_sha256(world.save_path());world._load_game(true)
			check(snap(false)==before and FileAccess.get_sha256(world.save_path())==disk,"actual output and receipt survive byte-preserving reconnect "+str(reward.source_entity_id))
			relationships+=1
		before=snap();use_inventory(name)
		check(snap()==before,"empty source box cannot duplicate final reward "+str(id))
		full_box_results.append({"item_class_id":id,"relationships":amount,"controlled_source_eligible_discovery":true})
	check(relationships==19 and full_box_results.size()==5,"all five producer boxes and19 actual consumer relationships")

func total_cards()->int:
	var result:int=0
	for category:String in world.card_draw_fusion.CATEGORIES:
		result+=world.card_draw_fusion.owned[category].size()
		for amount:Variant in world.card_draw_fusion.spare[category].values():result+=int(amount)
	return result

func owned_tickets(source:RefCounted)->void:
	check(ResourceLoader.exists("res://scripts/shop/source523_shop_runtime.gd"),"real published owned-ticket consumer installed")
	if not ResourceLoader.exists("res://scripts/shop/source523_shop_runtime.gd"):return
	var shop:RefCounted=load("res://scripts/shop/source523_shop_runtime.gd").new()
	world.expedition_local.reward_recipients.source_shop=shop
	shop.configure(world)
	check(shop.inventory_tickets.loaded_sha=="d25d89d1e16800141e1d7ac2e4341515931b857878b50e76eb0431f2622ae08e" and shop.inventory_tickets.problem.is_empty(),"actual consumer loads exact deterministic six-ticket extension")
	if shop.inventory_tickets.loaded_sha.is_empty():return
	var pool_before:Dictionary=world.card_draw_fusion.known_ids.duplicate(true)
	var generic_rng:int=world.card_draw_fusion.rng.state
	var pity_before:Dictionary=world.card_draw_fusion.pity.duplicate(true)
	var result_counts:Dictionary={166744:1,342064:5,342074:10,352054:5,352064:10}
	for id:int in Bridge.OWNED_TICKETS:
		if not await discover_box(source,id,1,true):return
		var key:String="%d:1:0"%id;var name:String=str(world.expedition_local.state.issued[key])
		var before:String=snap();var disk:String=FileAccess.get_sha256(world.save_path())
		var quote:Dictionary=shop.quote_inventory_ticket(name,{})
		if id==254088:
			check(not quote.ok and quote.get("missing_card_ids",[])==[25162],"positive-weight missing card25162 preserves entire original relic pool")
			use_inventory(name)
			check(snap()==before and FileAccess.get_sha256(world.save_path())==disk and int(world.inventory.get(name,0))==1,"actual expedition-produced unavailable ticket remains unconsumed")
			ticket_results.append({"item_class_id":id,"actual_completion_box_producer":true,"consumed":0,"missing_card_ids":[25162]});continue
		check(quote.get("ok",false) and int(quote.get("draw_count",0))==int(result_counts[id]),"actual issued key resolves complete original pool and count "+str(id)+("" if quote.get("ok",false) else str(quote)))
		if not quote.get("ok",false):return
		check(not shop.quote_inventory_ticket(name,{"index":0}).ok and snap()==before,"owned random ticket rejects caller-selected results")
		var record:Dictionary=world._find_catalog_item_record(name)
		record.source_expires_at=1
		check(not shop.use_inventory_ticket(name,{}).ok and snap()==before and FileAccess.get_sha256(world.save_path())==disk,"existing source expiry is preserved without extending ticket life")
		record.erase("source_expires_at")
		record.expedition_key="%d:2:0"%id
		check(not shop.use_inventory_ticket(name,{}).ok and snap()==before,"different source blessing tuple cannot consume normal ticket")
		record.expedition_key=key
		world.ui_preferences.item_locks[name]=true;use_inventory(name)
		check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"actual UI respects owned ticket lock");world.ui_preferences.item_locks.erase(name)
		var dedicated_rng:int=shop.inventory_tickets.random.state
		world.equipment_collections.save_blocked=true;use_inventory(name)
		check(snap()==before and FileAccess.get_sha256(world.save_path())==disk and shop.inventory_tickets.random.state==dedicated_rng,"single consumer save failure preserves ticket cards receipt and dedicated RNG "+str(id))
		world.equipment_collections.save_blocked=false
		var total_before:int=total_cards();var gold:int=world.gold;var uses:int=int(shop.state.get("ticket_redemption",{}).get("uses",0))
		use_inventory(name)
		check(not world.inventory.has(name) and total_cards()==total_before+int(result_counts[id]),"real inventory route consumes one produced ticket for native result count "+str(id))
		check(int(shop.state.get("ticket_redemption",{}).get("uses",0))==uses+1 and world.gold==gold,"owner commits one successful use counter without linked purchase charge")
		check(world.card_draw_fusion.known_ids==pool_before and world.card_draw_fusion.rng.state==generic_rng and world.card_draw_fusion.pity==pity_before,"existing card registry generic draw RNG and pity unchanged")
		check(world.hud.is_card_reveal_busy(),"actual card result UI shows committed ticket results")
		if is_instance_valid(world.hud.card_reveal_stage):world.hud.card_reveal_stage.close_reveal()
		await process_frame;await process_frame
		before=snap(false);disk=FileAccess.get_sha256(world.save_path());world._load_game(true)
		check(snap(false)==before and FileAccess.get_sha256(world.save_path())==disk,"ticket/card/independent RNG/issuer ledger survive byte-preserving reconnect "+str(id))
		var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(int(saved.source_shop.ticket_redemption.uses)==uses+1 and saved[world.EXPEDITION_LOCAL.KEY].receipts==world.expedition_local.state.receipts,"one durable payload includes actual producer receipt and owner use counter")
		before=snap();use_inventory(name)
		check(snap()==before,"empty produced ticket cannot replay native draw")
		ticket_results.append({"item_class_id":id,"actual_completion_box_producer":true,"consumed":1,"results":int(result_counts[id])})
	check(ticket_results.size()==6 and int(shop.state.get("ticket_redemption",{}).get("uses",0))==5,"five real produced tickets consumed; missing-card ticket preserved")

func owned_tickets_restart()->void:
	var disk:String=FileAccess.get_sha256(world.save_path())
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var shop:RefCounted=load("res://scripts/shop/source523_shop_runtime.gd").new()
	world.expedition_local.reward_recipients.source_shop=shop;shop.configure(world)
	check(shop.check_load(saved).is_empty(),"fresh real owner validates persisted source-shop namespace")
	shop.accept_load(saved)
	var before:String=snap(false);world._load_game(true)
	check(FileAccess.get_sha256(world.save_path())==disk and snap(false)==before,"fresh process preserves producer owner cards inventory and save bytes")
	check(int(shop.state.ticket_redemption.uses)==5 and shop.state.ticket_redemption.policy_sha256=="d25d89d1e16800141e1d7ac2e4341515931b857878b50e76eb0431f2622ae08e","fresh process restores exact ticket policy independent RNG and five-use counter")
	check(canonical(world.card_draw_fusion.export_state())==canonical(saved.card_draw_fusion),"fresh process restores exact native card ownership duplicates and ordinary draw state")
	check(world.expedition_local.state.receipts.size()==6,"six real producer completion receipts survive new process")
	for id:int in [166744,342064,342074,352054,352064]:
		var name:String=world.expedition_local.state.issued["%d:1:0"%id]
		check(int(world.inventory.get(name,0))==0 and not shop.use_inventory_ticket(name,{}).ok,"fresh process cannot replay consumed issued ticket "+str(id))
	var retained:String=world.expedition_local.state.issued["254088:1:0"]
	var quote:Dictionary=shop.quote_inventory_ticket(retained,{})
	check(int(world.inventory.get(retained,0))==1 and not quote.ok and quote.get("missing_card_ids",[])==[25162],"fresh process retains missing-card ticket without pool reduction")
	world.hud.refresh_inventory(world.inventory);var ui:Control=world.hud.lineage_inventory_ui
	ui.show_inventory();ui._select_item(retained)
	check(ui.detail_text.text.contains("TWILIGHT 소지 티켓1개") and ui.quick_button.disabled and not ui.detail_action.disabled,"actual retained-ticket UI shows local policy and disallows quickslot while keeping use action")
	before=snap();ui.detail_action.pressed.emit()
	check(snap()==before and FileAccess.get_sha256(world.save_path())==disk,"actual fresh-process inventory route preserves unavailable ticket and every saved ledger")

func finish()->void:
	print("EXPEDITION523_REWARD_CONSUMERS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"counts":counts,"peer_effects_are_conditional_integration":true,"full_box_results":full_box_results,"ticket_results":ticket_results}))
	world.queue_free();quit(0 if failures.is_empty() else 1)
