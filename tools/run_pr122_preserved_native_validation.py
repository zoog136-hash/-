#!/usr/bin/env python3
"""Recheck the six existing batch16 approvals in current production Main.

Reuse the unchanged gameplay/temporal/transform gates with isolated saves.
This grants no new art approval and never edits production profiles or PNGs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

from test_project_support import classify_result


def read(path):
    return json.loads(path.read_text())


def verify(gameplay, temporal, transform):
    roots = {"gameplay": gameplay, "temporal": temporal, "transform": transform}
    evidence = {}
    reports = {}
    for mode, folder in roots.items():
        process = read(folder / "process.json")
        assert process.get("engine") == "4.7.2.stable.official.ed1daf0bf", mode
        log = (folder / "run.log").read_text(errors="replace")
        assert classify_result(mode, process["returncode"], log) == (True, False), mode
        report = read(folder / "report.json")
        assert report["failures"] == [] and report["checks"] > 0, mode
        reports[mode] = report
        evidence[mode] = {"checks": report["checks"], "report_sha256": hashlib.sha256(
            (folder / "report.json").read_bytes()).hexdigest(), "process": process}
    names = ["알비노 변이된 골렘", "알비노 디어", "스파이더", "검은숲 거미", "왜곡의 타란툴라", "알비노 이구아나"]
    assert [c["name"] for c in reports["gameplay"]["cases"]] == names
    assert [c["name"] for c in reports["temporal"]["cases"]] == names
    for case in reports["gameplay"]["cases"]:
        detail = read(Path(case["report"]))
        assert detail["failures"] == []
        assert detail["lifecycle"]["death_callbacks"] == 1 and detail["lifecycle"]["manual_pickup"]
        assert len(detail["monster"]) == 8 and len(detail["monster_contacts"]) == 8
    assert reports["temporal"]["rendered"] and not reports["temporal"]["direct_texture_assignment"]
    expected = [144, 144, 128, 128, 128, 112]
    assert [c["native_phases"] for c in reports["temporal"]["cases"]] == expected
    assert [c["rendered_native_phases"] for c in reports["temporal"]["cases"]] == expected
    tomb = reports["transform"]["cases"]
    assert len(tomb) == 1 and tomb[0]["transform_id"] == "269" and tomb[0]["pose_samples"] == 112
    detail = read(Path(tomb[0]["report"]))
    assert detail["failures"] == [] and len(detail["player"]) == len(detail["monster"]) == 8
    assert detail["transform_temporal"]["native_phases"] == detail["transform_temporal"]["rendered_native_phases"] == 112
    assert detail["lifecycle"]["death_callbacks"] == 1 and detail["lifecycle"]["manual_pickup"]
    events = {e["name"]: e for e in detail["remaining106_player_visual"]["events"]}
    for direction in ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]:
        assert events["actual-player-" + direction + "-contact"]["state"]["frame"] == 1
    probe = detail["pr122_tomb269_smaller_target"]
    assert probe["real_hit_count"] == 1 and probe["actual_hp_delta"] > 0
    assert probe["attack_phase1_captured"] and probe["real_damage_contact_captured"]
    return {"status": "CURRENT_PRODUCTION_MAIN_PASS", "newly_approved": 0,
            "existing_batch16_approvals_preserved": 6, "normal_native_phases_including_baseline": sum(expected),
            "transform_native_phases": 112, "evidence": evidence, "Android_real_device": "NOT_RUN"}


def run(project, engine, output):
    if not os.environ.get("DISPLAY"):
        raise ValueError("A real OpenGL display is required")
    version = subprocess.check_output([str(engine), "--version"], text=True).strip()
    if version != "4.7.2.stable.official.ed1daf0bf":
        raise ValueError("The pinned Godot 4.7.2 engine is required: " + version)
    output.mkdir(parents=True, exist_ok=False)
    subprocess.run(["python3", str(project / "tools/check_resource_integrity.py"), "--root", str(project)], check=True)
    commands = {
        "import": ["--headless", "--editor", "--import"],
        "navigation": ["--headless", "--script", "res://tools/bake_hunting_navigation.gd"],
        "gameplay": ["--script", "res://tests/pr122_family_reuse_main_review.gd"],
        "temporal": ["--script", "res://tests/original_based_temporal_main_test.gd"],
        "transform": ["--script", "res://tests/pr122_tomb269_baseline_visual_review.gd"],
    }
    for mode, arguments in commands.items():
        folder = output / mode
        folder.mkdir()
        env = os.environ.copy()
        env.update(LIBGL_ALWAYS_SOFTWARE="1")
        for name in ["data", "config", "cache"]:
            (folder / name).mkdir()
        env.update(XDG_DATA_HOME=str(folder / "data"), XDG_CONFIG_HOME=str(folder / "config"),
                   XDG_CACHE_HOME=str(folder / "cache"), APPDATA=str(folder / "data"), LOCALAPPDATA=str(folder / "data"))
        if mode in ["gameplay", "temporal", "transform"]:
            prefix = "TWILIGHT_PR100_TEMPORAL" if mode == "temporal" else "TWILIGHT_PR100_BATCH"
            fixture = "pr122_batch17_preserved_tomb269" if mode == "transform" else "pr122_batch17_preserved_native"
            env.update({prefix + "_ISOLATED": "1", prefix + "_CONFIG": "res://tests/fixtures/" + fixture + ".json",
                        prefix + "_REPORT": str(folder / "report.json"), prefix + "_CAPTURE_DIR": str(folder / "captures")})
            arguments = ["--rendering-driver", "opengl3", "--audio-driver", "Dummy"] + arguments
        command = [str(engine), "--path", str(project)] + arguments
        (folder / "command.json").write_text(json.dumps(command, indent=2) + "\n")
        started = time.monotonic()
        with (folder / "run.log").open("w") as log:
            process = subprocess.run(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
        (folder / "process.json").write_text(json.dumps({"returncode": process.returncode,
            "seconds": time.monotonic() - started, "engine": version}, indent=2) + "\n")
        assert classify_result(mode, process.returncode, (folder / "run.log").read_text()) == (True, False), mode
    result = verify(output / "gameplay", output / "temporal", output / "transform")
    (output / "verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--verify-existing", nargs=3, type=Path, metavar=("GAMEPLAY", "TEMPORAL", "TRANSFORM"))
    args = parser.parse_args()
    if args.verify_existing:
        result = verify(*[p.resolve() for p in args.verify_existing])
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    else:
        if args.godot is None:
            parser.error("--godot is required for execution")
        result = run(args.project.resolve(), args.godot.resolve(), args.output.resolve())
    print(json.dumps(result, ensure_ascii=False))
