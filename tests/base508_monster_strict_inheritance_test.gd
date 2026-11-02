extends SceneTree
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
const BINDINGS=preload("res://scripts/monsters/base508_monster_bindings.gd")
const VIEW=preload("res://scripts/monsters/base508_monster_view.gd")
func _initialize():
 var manifest: String=BINDINGS.pack_manifest()
 var binding: Dictionary=BINDINGS.data().bindings[0]
 var record={"source_m_npc_id":binding.npc_id,"source_m_sprite_id":binding.sprite_id,"source_m_spawn_view_id":binding.spawn_view_id,"source_m_territory_link_id":binding.territory_link_id}
 var settings: String="user://lineagem_base508/playback_settings.json"
 var existed: bool=FileAccess.file_exists(settings)
 var original: PackedByteArray=FileAccess.get_file_as_bytes(settings) if existed else PackedByteArray()
 DirAccess.make_dir_recursive_absolute(settings.get_base_dir())
 var output=FileAccess.open(settings,FileAccess.WRITE);output.store_string('{"mode":"strict"}');output.close()
 var v=VIEW.new();var ok: bool=v.configure(record,manifest)
 var inherited: bool=ok and v.timing_status.walk.origin=="strict_unresolved"
 v.free()
 if existed:
  output=FileAccess.open(settings,FileAccess.WRITE);output.store_buffer(original);output.close()
 else:DirAccess.remove_absolute(settings)
 print("BASE508_MONSTER_STRICT_INHERITANCE ",inherited)
 quit(0 if inherited else 1)
