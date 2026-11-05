extends SceneTree
## Renderer-spy contract only. These packets prove field/position forwarding,
## never installed original sprites, rendered pixels or normal acquisition.
const Service = preload("res://scripts/equipment523/service.gd")
var checks: int = 0
var failures: Array[String] = []

class RendererSpy extends RefCounted:
	var calls: Array[Dictionary] = []
	var effect_status: Dictionary = {}
	var available: bool = true
	func emit_effect(actor: Node, spell: Dictionary, field: String, point: Vector2) -> bool:
		calls.append({"actor":actor,"spell":spell.duplicate(true),"field":field,"point":point,"requested_action":int(spell.get("EffectSpriteActionNo",0)) if field == "EffectSpriteID" else -1})
		effect_status["%d:%s" % [int(spell.get("ID",0)),field]] = {"sprite_id":int(spell.get(field,0)),"state":"spy_renderer_returned_true" if available else "exact_overlay_not_available"}
		return available

class NonBooleanRenderer extends RefCounted:
	var calls: int = 0
	func emit_effect(_actor: Node, _spell: Dictionary, _field: String, _point: Vector2) -> Variant:
		calls += 1
		return 1

class LegacyFallback extends RefCounted:
	var calls: int = 0
	func emit_spell(_spell: Dictionary, _target: Node) -> void: calls += 1

class Awakening extends RefCounted:
	var combat = LegacyFallback.new()

class Host extends Node:
	var player = Node2D.new()
	var patch523_npc_spells: Variant = RendererSpy.new()
	var option_awakening = Awakening.new()
	func _init() -> void:
		add_child(player)
		player.position = Vector2(12,34)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var host := Host.new()
	var target := Node2D.new()
	target.position = Vector2(91,72)
	_test_fields(host,target)
	_test_source_shaped_packets(host,target)
	_test_unavailable(host,target)
	_test_guard_and_bound(host,target)
	target.free()
	host.free()
	print("EQUIPMENT523_SPELL_VISUALS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_RENDERER_SPY_FIELD_POSITION_ACTION_AND_UNAVAILABLE_CONTRACT; NO_PIXEL_OR_ORIGINAL_ASSET_DELIVERY_CLAIM"}))
	quit(0 if failures.is_empty() else 1)

func _test_fields(host: Host, target: Node2D) -> void:
	var service = Service.new()
	var spy: RendererSpy = host.patch523_npc_spells
	var spell: Dictionary = {"ID":800001,"CasterEffectSpriteID":11,"EffectSpriteID":12,"EffectExplosionSpriteID":13,"SuccessEffectSpriteID":14,"EffectSpriteActionNo":7,"source_fixture":"explicit synthetic packet"}
	var before: String = JSON.stringify(spell)
	var reports: Array = service.emit_spell_visuals(host,spell,target)
	_check(spy.calls.size() == 4 and reports.size() == 4,"all four nonzero original field selectors reach the existing renderer")
	var fields: Array[String] = ["CasterEffectSpriteID","EffectSpriteID","EffectExplosionSpriteID","SuccessEffectSpriteID"]
	for index: int in range(mini(4,spy.calls.size())):
		var call: Dictionary = spy.calls[index]
		var field: String = fields[index]
		_check(call.field == field and call.actor == host.player and call.spell == spell,"renderer receives the unchanged spell packet, player actor and exact field: "+field)
		_check(call.point == (host.player.global_position if index == 0 else target.global_position),"caster and target field positions remain distinct: "+field)
		_check(reports[index].action == (7 if field == "EffectSpriteID" else null) and int(call.requested_action) == (7 if field == "EffectSpriteID" else -1),"only EffectSpriteID carries the original action selector: "+field)
		_check(reports[index].kind == "spell" and int(reports[index].spell_id) == int(spell.ID) and reports[index].state == "played_by_existing_source_renderer","spell diagnostics reflect only the renderer's actual boolean result: "+field)
	_check(JSON.stringify(spell) == before,"visual forwarding does not rewrite source spell fields")
	reports[0]["state"] = "caller modified copy"
	_check(service.set_visual_results[0].state == "played_by_existing_source_renderer","bounded diagnostics do not alias the caller's returned report")

func _test_source_shaped_packets(host: Host, target: Node2D) -> void:
	var service = Service.new()
	var spy: RendererSpy = host.patch523_npc_spells
	spy.calls.clear()
	var twin: Dictionary = {"ID":56554,"CasterEffectSpriteID":17001,"EffectSpriteID":17001,"SuccessEffectSpriteID":746,"EffectSpriteActionNo":0}
	var reports: Array = service.emit_spell_visuals(host,twin,target)
	_check(reports.size() == 3 and spy.calls.size() == 3,"identical caster and target SpriteIDs are independently emitted")
	if spy.calls.size() >= 2:
		_check(int(spy.calls[0].spell.CasterEffectSpriteID) == 17001 and int(spy.calls[1].spell.EffectSpriteID) == 17001 and spy.calls[0].point != spy.calls[1].point,"equal SpriteIDs retain their two original owners and positions")
	spy.calls.clear()
	reports = service.emit_spell_visuals(host,{"ID":56564,"EffectSpriteID":0,"EffectSpriteActionNo":1,"SuccessEffectSpriteID":4184},target)
	_check(reports.size() == 1 and spy.calls.size() == 1 and spy.calls[0].field == "SuccessEffectSpriteID" and reports[0].action == null,"a nonzero action with zero EffectSpriteID never suppresses the separate success field")
	spy.calls.clear()
	reports = service.emit_spell_visuals(host,{"ID":78898,"EffectExplosionSpriteID":24726},target)
	_check(reports.size() == 1 and int(reports[0].sprite_id) == 24726 and spy.calls[0].field == "EffectExplosionSpriteID" and spy.calls[0].point == target.global_position,"Yahi's explosion field uses the target point without an invented action")
	spy.calls.clear()
	_check(service.emit_spell_visuals(host,{"ID":78908},target).is_empty() and spy.calls.is_empty(),"Yahi's zero-FX next spell creates no placeholder visual")

func _test_unavailable(host: Host, target: Node2D) -> void:
	var service = Service.new()
	var spell: Dictionary = {"ID":56504,"SuccessEffectSpriteID":15936}
	var spy: RendererSpy = host.patch523_npc_spells
	spy.available = false
	var reports: Array = service.emit_spell_visuals(host,spell,target)
	_check(reports.size() == 1 and reports[0].state == "unavailable_exact_source_binding_or_renderer","a false renderer result stays unavailable")
	_check(reports[0].renderer_status == {"sprite_id":15936,"state":"exact_overlay_not_available"},"the renderer's exact unavailable diagnostic is preserved")
	_check(host.option_awakening.combat.calls == 0,"missing source pixels do not fall back to a same-numbered legacy spell emitter")
	host.patch523_npc_spells = null
	reports = service.emit_spell_visuals(host,spell,target)
	_check(reports.size() == 1 and reports[0].state == "unavailable_exact_source_binding_or_renderer" and host.option_awakening.combat.calls == 0,"absent renderer records unavailability without art or namespace substitution")
	var wrong := NonBooleanRenderer.new()
	host.patch523_npc_spells = wrong
	reports = service.emit_spell_visuals(host,spell,target)
	_check(wrong.calls == 1 and reports[0].state == "unavailable_exact_source_binding_or_renderer","truthy nonboolean renderer results do not claim successful rendering")
	var bare := Node.new()
	reports = service.emit_spell_visuals(bare,spell,target)
	_check(reports.size() == 1 and reports[0].state == "unavailable_exact_source_binding_or_renderer","a host without player or renderer properties is reported safely")
	bare.free()
	host.patch523_npc_spells = RendererSpy.new()

func _test_guard_and_bound(host: Host, target: Node2D) -> void:
	var service = Service.new()
	var spy: RendererSpy = host.patch523_npc_spells
	service.set_effects._visual_events.append({"kind":"guard_created","buff_id":91614,"spell":{"ID":117684,"EffectSpriteID":29085,"EffectSpriteActionNo":1},"field":"EffectSpriteID"})
	service.set_effects._visual_events.append({"kind":"guard_removed","buff_id":91614,"spell":{"ID":0,"OnBuffRemovedEffectSpriteID":29090},"field":"OnBuffRemovedEffectSpriteID"})
	service._emit_set_visuals(host)
	_check(spy.calls.size() == 2 and spy.calls[0].point == host.player.global_position and spy.calls[1].point == host.player.global_position,"guard creation and removal reuse the exact source-renderer bridge at the player point")
	_check(service.set_visual_results[0].kind == "guard_created" and int(service.set_visual_results[0].buff_id) == 91614 and service.set_visual_results[0].action == 1,"guard creation preserves its existing diagnostic fields and exact action")
	_check(service.set_visual_results[1].kind == "guard_removed" and int(service.set_visual_results[1].sprite_id) == 29090 and service.set_visual_results[1].action == null,"guard removal preserves its exact SpriteID without inventing an action")
	service._emit_set_visuals(host)
	_check(spy.calls.size() == 2,"drained guard visual events are not replayed")
	for index: int in range(40): service.emit_spell_visuals(host,{"ID":index+1,"SuccessEffectSpriteID":15936},target)
	_check(service.set_visual_results.size() == 32 and int(service.set_visual_results[0].spell_id) == 9 and int(service.set_visual_results.back().spell_id) == 40,"spell and guard visual diagnostics share a bounded thirty-two-entry history")
