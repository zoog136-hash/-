#!/usr/bin/env python3
"""One-time, hash-guarded installation against the inspected item resolver."""
from pathlib import Path
import hashlib
root=Path('.')
p=root/'scripts/ui/item_visual_resolver.gd'
s=p.read_text()
if 'static func _describe_original(' not in s:
    assert hashlib.sha256(p.read_bytes()).hexdigest()=='62ea383feb17d3ef00d45d255a7fabb3a9e7c1bdd06ef6065514ec4e7a44b349', 'resolver changed; review before installing'
    signature='static func describe(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:'
    wrapper='''static func describe(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:
	# Ground art and all real/unknown source IDs retain the original resolver.
	if not ground and str(record.get("sourceId", "")).is_empty():
		_ensure()
		var inventory_name: String = str(record.get("name", fallback_name))
		# Catalog names (including ambiguous variants) must never borrow an alias.
		if not _names.has(inventory_name):
			var binding: Dictionary = INVEN_INVENTORY.lookup(record, inventory_name)
			if not binding.is_empty():
				return {"source_id":"", "name":inventory_name, "path":binding.path,
					"status":"inven_exact_name" if binding.match_kind == "exact_name" else "inven_visual_alias",
					"route":"inven_inventory", "family":"", "match_kind":binding.match_kind,
					"art_source":binding.art_source}
	return _describe_original(record, fallback_name, images, ground)

static func _describe_original(record: Dictionary, fallback_name: String = "", images: Dictionary = {}, ground: bool = false) -> Dictionary:'''
    assert s.count(signature)==1
    s=s.replace('extends RefCounted\n','extends RefCounted\nconst INVEN_INVENTORY = preload("res://scripts/ui/inven_inventory_icons.gd")\n',1).replace(signature,wrapper)
    p.write_text(s)
p=root/'tools/check_item_visuals.py';s=p.read_text()
if '"inven_exact_name"' not in s:
    assert hashlib.sha256(p.read_bytes()).hexdigest()=='9426b384617dac17cfa1b3465ed17e0040a77b0c696448af0e9d960cfc70fbab', 'audit changed; review before installing'
    s=s.replace('STATES = ("original_linked", "original_review_pending", "self_authored_substitute", "image_missing")','STATES = ("original_linked", "inven_exact_name", "inven_visual_alias", "original_review_pending", "self_authored_substitute", "bundled_ui_art", "image_missing")')
    s=s.replace('"definitions":{"original_linked":','"definitions":{"inven_exact_name":"Inventory-only exact item name and verified Inven image; no gameplay fields replaced.",\n                             "inven_visual_alias":"Explicit Inven artwork alias for a custom/variant item; not an exact original-item identity match.",\n                             "bundled_ui_art":"Stock UI picture, not an original item identity match.",\n                             "original_linked":')
    s=s.replace('"No source ZIP available, no new third-party image bytes added, no original private pack delivery claimed.",','"Inventory-only source acquisitions and explicit aliases are recorded separately in data/inven_inventory_icons.json; no private pack delivery is claimed.",')
    s=s.replace('            counts[info["status"]] += 1','            if info["status"] not in STATES:\n                errors.append("unrecognized visual state: " + str(info["status"]))\n            counts[info["status"]] += 1')
    p.write_text(s)
print('INVENTORY_INSTALL_OK')
