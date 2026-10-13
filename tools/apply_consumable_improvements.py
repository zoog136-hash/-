#!/usr/bin/env python3
"""Apply reviewed consumable changes only to the exact inspected source blobs."""
from pathlib import Path
import subprocess

EXPECTED = {
    "scripts/world.gd": "29bde862181382fe7821c0595c22632ee3c8c5a6",
    "scripts/consumable_rules.gd": "569c652b10c566eeab5121e6316f38f6216c9005",
    "scripts/ui/renewal_hud.gd": "47bec754af5f019ee744f43cd748acf2b8fde623",
    "scripts/ui/renewal_settings.gd": "cb11132386def0e415cdcc27a5bf9077abb6e125",
}
for path, expected in EXPECTED.items():
    actual = subprocess.check_output(["git", "hash-object", path], text=True).strip()
    if actual != expected:
        raise SystemExit(f"Refusing unreviewed source {path}: {actual} != {expected}")
updates = {}

def read(path):
    return Path(path).read_text(encoding="utf-8")

def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected one anchor: {old[:100]!r}; found {text.count(old)}")
    return text.replace(old, new, 1)

path = "scripts/world.gd"
s = read(path)
s = once(s, 'const CONSUMABLE_RULES = preload("res://scripts/consumable_rules.gd")', 'const CONSUMABLE_AUTO = preload("res://scripts/consumable_auto_policy.gd")\nconst CONSUMABLE_RULES = preload("res://scripts/consumable_rules.gd")')
s = once(s, '\t_connect_signals()\n', '\t_connect_signals()\n\tif hud.has_signal("consumable_auto_settings_changed"):\n\t\thud.connect("consumable_auto_settings_changed", set_consumable_auto_settings)\n')
s = once(s, '\tui_preferences = saved_ui.duplicate(true) if saved_ui is Dictionary else {}\n', '\tui_preferences = saved_ui.duplicate(true) if saved_ui is Dictionary else {}\n\tui_preferences["consumable_auto"] = CONSUMABLE_AUTO.normalize(ui_preferences.get("consumable_auto", {}))\n')
s = once(s, '\tif not quiet:\n\t\thud.show_message("불러오기 완료")', '\t_emit_consumable_auto_settings()\n\tif not quiet:\n\t\thud.show_message("불러오기 완료")')
start = s.index('func _run_auto_item_quickslots(delta: float) -> void:')
end = s.index('func _on_self_mode_changed(', start)
old = s[start:end]
if 'hp < _effective_max_hp()' not in old or 'mp < _effective_max_mp()' not in old or old.count('_use_quickslot_item(item)') != 1:
    raise ValueError('Unexpected original auto-use implementation')
replacement = '''func get_consumable_auto_settings() -> Dictionary:
\treturn CONSUMABLE_AUTO.normalize(ui_preferences.get("consumable_auto", {}))

func set_consumable_auto_settings(settings: Dictionary) -> void:
\tui_preferences["consumable_auto"] = CONSUMABLE_AUTO.normalize(settings)
\tauto_item_clock = 0.0
\t_emit_consumable_auto_settings()
\t_save_game(true)

func _emit_consumable_auto_settings() -> void:
\tif is_instance_valid(hud) and hud.has_signal("consumable_auto_settings_updated"):
\t\thud.emit_signal("consumable_auto_settings_updated", get_consumable_auto_settings())

func _run_auto_item_quickslots(delta: float) -> void:
\tauto_item_clock -= delta
\tif auto_item_clock > 0 or hp <= 0 or player.is_stunned() or player.is_feared():
\t\treturn
\tauto_item_clock = 0.2
\tvar settings: Dictionary = get_consumable_auto_settings()
\tvar candidates: Array[Dictionary] = []
\tvar seen: Dictionary = {}
\tfor value: Variant in quickslots:
\t\tif not value is Dictionary:
\t\t\tcontinue
\t\tvar entry: Dictionary = value as Dictionary
\t\tif entry.get("kind", "") != "item" or not bool(entry.get("auto", false)):
\t\t\tcontinue
\t\tvar item: String = str(entry.get("id", ""))
\t\tif seen.has(item) or int(inventory.get(item, 0)) <= 0 or float(item_use_cooldowns.get(item, 0)) > 0:
\t\t\tcontinue
\t\tseen[item] = true
\t\tvar record: Dictionary = _find_catalog_item_record(item)
\t\tvar spec: Dictionary = CONSUMABLE_RULES.definition(item)
\t\tif not CONSUMABLE_AUTO.wanted(item, record, spec, settings, hp, _effective_max_hp(), mp, _effective_max_mp(), job_class, active_item_buffs):
\t\t\tcontinue
\t\tif not _quickslot_auto_allowed(entry):
\t\t\tcontinue
\t\tcandidates.append({"item":item, "priority":CONSUMABLE_AUTO.priority(record, spec)})
\t# One successful consumption per interval. HP first; slot order within
\t# each class is preserved. A refused item cannot starve later slots.
\tfor priority: int in range(3):
\t\tfor candidate: Dictionary in candidates:
\t\t\tif int(candidate.priority) != priority:
\t\t\t\tcontinue
\t\t\tvar item: String = str(candidate.item)
\t\t\tvar before: int = int(inventory.get(item, 0))
\t\t\t_use_quickslot_item(item)
\t\t\tif int(inventory.get(item, 0)) < before:
\t\t\t\treturn

'''
s = s[:start] + replacement + s[end:]
updates[path] = s

path = "scripts/ui/renewal_hud.gd"
s = read(path)
s = once(s, 'signal quickslot_edit_requested(action: String, source_index: int, target: int)\n', 'signal quickslot_edit_requested(action: String, source_index: int, target: int)\nsignal consumable_auto_settings_changed(settings: Dictionary)\nsignal consumable_auto_settings_updated(settings: Dictionary)\n')
updates[path] = s

path = "scripts/ui/renewal_settings.gd"
s = read(path)
s = once(s, '# Presentation options only. No gameplay/save/schema changes.', '# Presentation options and character-specific consumable safety controls.')
s = once(s, '\tstack.add_child(UI.label("HUD 표시",18,UI.GOLD))', '\tvar consumable_settings := preload("res://scripts/ui/consumable_auto_settings.gd").new()\n\tconsumable_settings.configure(hud)\n\tstack.add_child(consumable_settings)\n\tstack.add_child(HSeparator.new())\n\tstack.add_child(UI.label("HUD 표시",18,UI.GOLD))')
updates[path] = s

path = "scripts/consumable_rules.gd"
s = read(path)
s = once(s, '"classes":["기사", "군주"]', '"classes":["기사", "군주", "다크엘프", "투사", "암흑기사", "신성검사", "광전사", "사신", "뇌신", "마검사"]')
s = once(s, '"classes":["요정"]', '"classes":["요정", "총사"]')
s = once(s, 'static func records() -> Array[Dictionary]:', '# Cooking extends the historical four-class table to all 13 TWILIGHT jobs\n# by combat role. Values, duration and groups are unchanged. This is local\n# compatibility policy, not verified Korean live eligibility.\nstatic func records() -> Array[Dictionary]:')
updates[path] = s

# Validate every anchor before writing any existing source file.
for path, content in updates.items():
    Path(path).write_text(content, encoding="utf-8")
    print(f"Updated {path}")
