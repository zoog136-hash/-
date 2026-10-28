extends SceneTree

class SaveHost extends Node:
	class QuietHud extends Node:
		var logs: Array[String]=[]
		func append_log(value: String) -> void:logs.append(value)
	var hud:=QuietHud.new()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var host:=SaveHost.new()
	root.add_child(host)
	host.add_child(host.hud)
	var writer:=preload("res://scripts/collections/equipment_collection_runtime.gd").new()
	writer.world=host
	var path: String="user://identical_payload_test.json"
	if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var state: Dictionary={"hp":10,"item_instances":{"41":{"name":"검","level":2}}}
	if writer.write_save(path,state)!=OK:failures.append("initial durable write")
	var first_hash: String=FileAccess.get_sha256(path)
	if writer.write_save(path,state.duplicate(true))!=OK or writer.save_writes!=1 or writer.skipped_identical_saves!=1:failures.append("identical snapshot not skipped")
	if FileAccess.get_sha256(path)!=first_hash:failures.append("skip changed durable bytes")
	state.hp=11
	if writer.write_save(path,state)!=OK or writer.save_writes!=2:failures.append("changed snapshot not written")
	var external:=FileAccess.open(path,FileAccess.WRITE)
	external.store_string("externally changed");external.flush();external.close()
	if writer.write_save(path,state)==OK or not writer.save_blocked or FileAccess.get_file_as_string(path)!="externally changed":failures.append("external mutation protection bypassed")
	print("SAVE_IDENTICAL_PAYLOAD_RESULT ",JSON.stringify({"failures":failures,"writes":writer.save_writes,"skips":writer.skipped_identical_saves}))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
