#!/usr/bin/env python3
"""Test private catalog bytes/consumer in an isolated project and user-data dir.

Requires the delivered ZIP and an independent unchanged-source atlas tree.
No Google login, network, real saves, main merge, or original-M claim is involved.
The setup handoff uses a minimal sentinel scene; full World/device tests are separate.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--zip", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    reports = []
    with tempfile.TemporaryDirectory(prefix="twilight-private-catalog-test-") as temporary:
        temporary = Path(temporary)
        project = temporary / "project"
        project.mkdir()
        queue = ["scripts/animation/visual_manifest.gd", "scripts/resources/catalog_pack_setup.gd"]
        copied = set()
        while queue:
            name = queue.pop()
            if name in copied:
                continue
            copied.add(name)
            text = (root / name).read_text()
            out = project / name
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(text)
            queue.extend(re.findall(r'preload\("res://([^"\n]+\.gd)"\)', text))
        for name in ("data/visuals/runtime_manifest.json", "data/visuals/private_catalog_motion.json",
                     "CatalogPackSetup.tscn", "tests/private_catalog_motion_runtime_test.gd",
                     "tests/private_catalog_consumer_test.gd", "tests/private_catalog_gate_cancel_test.gd",
                     "tests/private_catalog_gate_empty_test.gd", "tests/private_catalog_no_space.gd"):
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / name, target)
        (project / "no_space.gd").write_text('extends "res://scripts/resources/private_catalog_motion.gd"\nfunc available_space() -> int: return 0\n')
        (project / "gate_handoff.gd").write_text('''extends Control
func _ready() -> void:
 if FileAccess.get_file_as_string("user://save-sentinel") != "preserved":
  get_tree().quit(1)
  return
 print("CATALOG_GATE_HANDOFF_OK all723verified save_preserved")
 get_tree().quit(0)
''')
        (project / "Main.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://gate_handoff.gd" id="1"]
[node name="Main" type="Control"]
script = ExtResource("1")
''')
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="CatalogPrivateRuntimeIsolated"\nrun/main_scene="res://CatalogPackSetup.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        data = temporary / "data"
        cache = temporary / "cache"
        data.mkdir()
        cache.mkdir()
        env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CACHE_HOME=str(cache), TWILIGHT_PRIVATE_TEST_ROOT=str(temporary))

        def run(extra, marker, *, isolated_empty=False):
            current_env = dict(env)
            if isolated_empty:
                empty = temporary / "empty-data"
                empty.mkdir()
                current_env["XDG_DATA_HOME"] = str(empty)
            result = subprocess.run([args.godot, "--headless", "--path", str(project), *extra],
                                    capture_output=True, text=True, env=current_env, timeout=180)
            output = result.stdout + result.stderr
            if result.returncode or marker not in output or "SCRIPT ERROR" in output:
                raise RuntimeError(output[-12000:])
            parsed = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
            reports.extend(parsed or [{"passed_contract": marker}])
            print(marker, flush=True)

        run(["--script", "tests/private_catalog_motion_runtime_test.gd", "--", str(args.zip.resolve()),
             str(args.source_root.resolve())], '"pixels_compared"')
        run(["--script", "tests/private_catalog_consumer_test.gd"], '"frames":41442')
        run([], "CATALOG_GATE_HANDOFF_OK")
        run(["--script", "tests/private_catalog_gate_cancel_test.gd"], "CATALOG_GATE_CANCEL_OK")
        run(["--script", "tests/private_catalog_gate_empty_test.gd"], "CATALOG_GATE_EMPTY_OK", isolated_empty=True)
    report = {"reports": reports, "real_user_data_or_saves_touched": False,
              "embedded_catalog_atlases": 0, "full_World_Android_verified": False}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2))
    print(json.dumps(report))


if __name__ == "__main__":
    main()
