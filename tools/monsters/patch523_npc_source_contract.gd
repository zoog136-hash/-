extends SceneTree
## Run explicitly with the materialized private pack. Never counted as a fixture test.
const SERVICE = preload("res://scripts/monsters/patch523_npc_combat.gd")
var checks: int = 0
var failed: bool = false
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failed = true; push_error(label); quit(1)
func _init() -> void: call_deferred("run")
func run() -> void:
	var service = SERVICE.new()
	check(service.configure(root),"actual private source pack loads with pinned SHA")
	var c = service.catalog
	var source_path: String = "user://source_npc523/manifest.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-npc-catalog="): source_path = arg.trim_prefix("--patch523-npc-catalog=")
	var rejected = c.get_script().new()
	check(not rejected.load_pack(source_path,"0".repeat(64)) and rejected.error == "manifest_sha_mismatch","bad pin rejected without replacing live catalog")
	var probe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	probe.catalog_file = "../npc_spells.json"
	var probe_path: String = "user://patch523_path_probe_%d.json" % Time.get_ticks_usec()
	var probe_file := FileAccess.open(probe_path,FileAccess.WRITE)
	probe_file.store_string(JSON.stringify(probe)); probe_file.close()
	check(not rejected.load_pack(probe_path,FileAccess.get_sha256(probe_path)) and rejected.error == "catalog_path_rejected","catalog traversal rejected")
	DirAccess.remove_absolute(probe_path)
	check(c.content.report_boss_npc_ids.size() == 15 and c.content.boss_npc_ids.size() == 16,"15 report NPC identities")
	check(c.content.report_attack_ids.size() == 270 and c.content.report_spell_ids.size() == 126,"source graph counts")
	check(c.content.host_extension_npc_ids.size() == 1 and int(c.content.host_extension_npc_ids[0]) == 60303 and service.supported({"IsSpell":true,"SpellID":43423}),"exact current Kurts host binding reaches typed single-target attack")
	var chain: Dictionary = c.spell_chain(88822)
	check(chain.next.size() == 1 and int(chain.next[0].spell.source.ID) == 88832,"forewarning follows NextSpell rather than only NpcAttack")
	check(int(chain.next[0].edge.bonus.BonusApplicationTargetID) == 1,"application target 1 stays raw")
	check(c.scalar("SpellBonus",88822,"NextSpellDelay","MilliSeconds") == 3000,"explicit ms delay preserved separately")
	var barrier: Dictionary = c.buff_details(58953)
	check(barrier.invokes.size() == 3 and int(barrier.group.ID) == 82 and not barrier.group.IsAllowOverlap,"shared group and all defence branches")
	check(int(barrier.invokes[2].source.AttackTypeID) == 42 and not bool(barrier.invokes[2].source.BySpellAttack),"AttackType42 false branch not merged")
	check(c.scalar("BuffBonus",61023,"HPHealDecreasePercent","Percentage") == 3000000,"3 million healing raw value not clamped")
	var potion: Dictionary = c.buff_details(61043)
	check(c.scalar("BuffBonus",61043,"CannotUseItem","TrueFalse") == 1,"item-use restriction differs from healing reduction")
	check(int(potion.statuses[0].id) == 2232 and int(potion.statuses[0].attributes[0].Value) == 24051,"status and sprite namespaces remain distinct")
	check(service.status_plan(121718).is_empty(),"CannotCastSpell not broadened into legacy full skill silence")
	check(service.support_reason({"IsSpell":true,"SpellID":120988}).contains("회복"),"support NPC heal not damage")
	check(not service.supported({"IsSpell":true,"SpellID":88822}),"test land box never executed with invented geometry")
	var environment: Array = c.environment_buffs(53)
	check(environment.size() == 1 and int(environment[0].attribute.TerritoryID) == 171713,"jail buff retains bounded territory")
	check(environment[0].buff.invokes.size() == 10,"all jail defence branches preserved")
	check(c.content.tables.LandAttribute.size() == 183,"all source environmental NPC buffs retained")
	var attacks: Dictionary = c.attack_chain(60303,209093)
	check(int(attacks.next.source.ID) == 208983 and int(attacks.next.source.SpellID) == 43423,"actual Kurts NextAttack chain preserves exact source target")
	check(service.supported(c.attack(60303,209093)) and service.supported(c.attack(60303,208753)),"source self enemy and basic damage components supported")
	check(c.attack(60303,209073).is_empty() and c.attack_chain(60303,209083).next.pending == "missing_or_different_npc_attack","dangling source reference remains pending")
	var root_ids: Array = []
	for source: Dictionary in c.attack_roots(60303): root_ids.append(int(source.ID))
	check(root_ids.has(209093) and not root_ids.has(208983),"source child is not selected as an independent root")
	check(c.scalar("SpellBonus",121718,"IgnoreCannotCastSpell","TrueFalse") == 1 and c.scalar("SpellBonus",121718,"IgnoreCannotCastSkill","TrueFalse") == 1,"actual Hardin caster flags stay separate from target restrictions")
	var counts: Dictionary = {}
	for entry: Dictionary in c.content.tables.NpcAttack.values():
		var reason: String = service.support_reason(entry.row)
		counts[reason] = int(counts.get(reason,0))+1
	if failed: quit(1); return
	print("PATCH523_NPC_SOURCE_OK checks=",checks," source_archive_sha256=",c.SOURCE_SHA," components=",JSON.stringify(counts))
	quit()
