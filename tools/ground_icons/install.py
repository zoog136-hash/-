#!/usr/bin/env python3
"""One-time guarded integration against the exact checked-out source."""
from pathlib import Path
import subprocess
root=Path('.')
p=root/'scripts/ui/item_visual_resolver.gd';s=p.read_text()
if 'const GROUND_ICONS' not in s:
    assert p.read_bytes()==subprocess.check_output(['git','show','HEAD:scripts/ui/item_visual_resolver.gd']), 'uncommitted resolver changes; preserve and review'
    signature='static func describe(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:\n'
    assert s.count(signature)==1 and 'ground_category' not in s and 'static func _describe_original(' in s
    block='''	if ground:
		var original: Dictionary = _describe_original(record, fallback_name, images, true)
		# Preserve existing dedicated floor pairs and their provenance.
		if original.route in ["reviewed_ground", "l1j_dedicated_ground_candidate"]:
			return original
		var source: Dictionary = _source(record, str(original.name))
		# A known publisher ID paired with the wrong name remains rejected.
		if source.is_empty(): return original
		var choice: Dictionary = GROUND_ICONS.lookup(source, str(original.name))
		if not choice.is_empty() and _valid(str(choice.path)):
			original.path = choice.path
			original.route = "ground_category"
			original.status = "ground_category_art"
			original.family = ""
			original["category"] = choice.category
			original["art_source"] = choice
		return original
'''
    s=s.replace('extends RefCounted\n','extends RefCounted\nconst GROUND_ICONS = preload("res://scripts/ui/ground_item_icons.gd")\n',1).replace(signature,signature+block)
    p.write_text(s)
p=root/'tests/inven_inventory_icons_test.gd';s=p.read_text()
old='\tcheck(JSON.stringify(ground) == JSON.stringify(before_ground), "ground unchanged:" + item_name)'
new='''	if before_ground.route in ["reviewed_ground", "l1j_dedicated_ground_candidate"]:
		check(JSON.stringify(ground) == JSON.stringify(before_ground), "dedicated ground unchanged:" + item_name)
	else:
		check(ground.get("route", "") == "ground_category" and ground.get("name", "") == item_name, "independent ground category preserves item name:" + item_name)'''
if old in s:
    assert p.read_bytes()==subprocess.check_output(['git','show','HEAD:tests/inven_inventory_icons_test.gd'])
    assert s.count(old)==1;s=s.replace(old,new);p.write_text(s)
print('GROUND_INTEGRATION_INSTALLED')
