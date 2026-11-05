extends SceneTree
## Base-contract inventory only; not a gameplay-completion count.
class Owner extends Node:
	var job_class: String="기사"
	var level: int=90
	var equipped_items: Dictionary={}
	func _current_weapon_type() -> String:return ""

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var owner:=Owner.new()
	root.add_child(owner)
	var catalog:=preload("res://scripts/skills/skill_catalog.gd").new()
	catalog.configure(owner)
	var rows: Array=[]
	var counts: Dictionary={}
	for record: Dictionary in catalog.records:
		owner.job_class=str(record.get("classes",[record.get("class","")])[0])
		var skill: Dictionary=catalog.resolve(record)
		var status: String="reference_blocked" if bool(skill.get("runtime_blocked",false)) else "source_blocked" if not str(skill.get("source523_block_reason","")).is_empty() else "host_contract_available"
		counts[status]=int(counts.get(status,0))+1
		rows.append({"id":record.id,"name":record.name,"class":owner.job_class,"status":status,"mode":skill.get("mode",""),"activation":skill.get("activation",""),"native_id":skill.get("source523",{}).get("spell_id",0),"reason":skill.get("source523_block_reason","")})
	var report: Dictionary={"counts":counts,"source_profiles":catalog.source523.profiles.size(),"rows":rows,"scope":"base contracts; no grants or gameplay completion claims"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--skills523-inventory="):
			var file:=FileAccess.open(arg.get_slice("=",1),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"  ")+"\n")
	print("SKILLS523_INVENTORY ",JSON.stringify({"counts":counts,"source_profiles":catalog.source523.profiles.size()}))
	owner.free();quit()
