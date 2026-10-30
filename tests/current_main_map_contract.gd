extends RefCounted
## Assert the admitted current main map; never accept a silent legacy fallback.
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const LOCAL=preload("res://scripts/maps/source_map_local_policy.gd")
const PNG=preload("res://scripts/maps/native_png_registry.gd")
static func valid(world: Node) -> bool:
 for flag: String in ["--legacy-map-layouts","--legacy-aden-faith-layouts","--png-review","--no-native-png-auto"]:
  if flag in OS.get_cmdline_user_args():return false
 if world.active_map_id!="aden_world" or world.field_map==null:return false
 if RUN.supports("aden_world"):
  var rule:Dictionary=RUN.policy().aden_world
  return bool(world.field_map.get_meta("source_map84",false)) and world.field_map.definition.source_sha256==rule.grid_sha256 and int(world.field_map.definition.source_map_id)==int(rule.source_map_id) and not LOCAL.index(RUN.root_path()).is_empty() and world.field_renderer.get_script().resource_path=="res://scripts/maps/source_map_runtime_renderer.gd"
 return world.field_map is NativePngField and world.field_map.png_manifest.get("source_sha256")=="c0af339cbc2dbba5fb2e65c3c7f01d9467507545d7b91cbb331f5bbd51128730" and world.field_renderer.get_meta("native_png",false)==true and PNG.extra_installed()
static func describe(world: Node) -> Dictionary:
 return {"map_id":world.active_map_id,"field_script":world.field_map.get_script().resource_path,"layout_revision":world.field_map.data.layout_revision,"source_map84":world.field_map.get_meta("source_map84",false),"identity":RUN.identity("aden_world") if RUN.supports("aden_world") else {"source_sha256":world.field_map.png_manifest.source_sha256},"args":OS.get_cmdline_user_args()}
