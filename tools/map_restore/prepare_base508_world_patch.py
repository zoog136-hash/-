"""Produce a small reviewable world.gd integration patch; never apply it."""
import argparse,difflib
from pathlib import Path

def patch(source):
 edits=[('const NATIVE_PNG = preload("res://scripts/maps/native_png_registry.gd")','const BASE508_TEST = preload("res://scripts/maps/base508_game_mode.gd")\nconst NATIVE_PNG = preload("res://scripts/maps/native_png_registry.gd")'),
 ('\t_load_data()\n','\t_load_data()\n\tif BASE508_TEST.enabled():\n\t\tvar test_map:String=BASE508_TEST.register_test_map(maps,maps_by_id)\n\t\tif test_map.is_empty():\n\t\t\tpush_error("base508 test pack rejected: "+BASE508_TEST.problem)\n\t\t\tprocess_mode=Node.PROCESS_MODE_DISABLED\n\t\t\treturn\n\t\tactive_map_id=test_map\n'),
 ('\tvar requested_native: PlayableField = null\n\tif NATIVE_PNG.supports(map_id)', '\tvar requested_native: PlayableField = BASE508_TEST.field_for(map_id)\n\tif requested_native == null and NATIVE_PNG.supports(map_id)'),
 ('\t\tif field_map is NativePngField:\n\t\t\t# Instantiate', '\t\tif bool(field_map.get_meta("base508_source_test",false)):\n\t\t\tfield_renderer=load(BASE508_TEST.RENDERER_PATH).new() as FieldRenderer\n\t\telif field_map is NativePngField:\n\t\t\t# Instantiate'),
 ('func base_save_path() -> String:\n','func base_save_path() -> String:\n\tif BASE508_TEST.enabled():return "user://base508_source_test_never_written.json"\n'),
 ('func _save_game(quiet: bool, collection_override: Dictionary = {}) -> Error:\n','func _save_game(quiet: bool, collection_override: Dictionary = {}) -> Error:\n\tif BASE508_TEST.enabled():return ERR_UNAVAILABLE\n'),
 ('func _load_game(quiet: bool) -> void:\n','func _load_game(quiet: bool) -> void:\n\tif BASE508_TEST.enabled():return\n')]
 updated=source
 for before,after in edits:
  if updated.count(before)!=1:raise ValueError('World hook is missing or ambiguous: '+before[:90])
  updated=updated.replace(before,after)
 return ''.join(difflib.unified_diff(source.splitlines(True),updated.splitlines(True),fromfile='a/scripts/world.gd',tofile='b/scripts/world.gd'))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('world',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.write_text(patch(a.world.read_text()))
