#!/usr/bin/env python3
"""Combine the frozen, separately scoped PR122 review receipts."""
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
SOURCE_COMMIT = "a6e8a8dec7aa5882e15eef72a238f1406a6626a6"


def read(path):
    return json.loads((ROOT / path).read_text())


def rel(path):
    return path.relative_to(ROOT).as_posix()


def pin(path):
    path = ROOT / path
    return {"path": rel(path), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    scope = read("data/pr122_monster_production_scope.json")
    index = {row["id"]: row for row in scope["monsters"]}
    prior = json.loads(subprocess.check_output(
        ["git", "show", SOURCE_COMMIT + ":data/pr122_monster_production_scope.json"],
        cwd=ROOT, text=True))
    for old in prior["monsters"]:
        assert all(index[old["id"]][key] == old[key]
                   for key in ("kind", "preserved_status", "production_status"))
    protected = ["assets", "data/combat_animation_profiles.json",
                 "data/animation_authoring_sources.json",
                 "docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json"]
    assert not subprocess.check_output(
        ["git", "diff", "--name-only", SOURCE_COMMIT, "--", *protected],
        cwd=ROOT, text=True).strip()

    inputs = []
    manifest_files = []
    manifest_specs = [
        ("review-normal-frames", "file-manifest.json"),
        ("review-boss-a", "manifest.json"),
        ("review-boss-b", "file-manifest.json"),
        ("review-boss-c", "file-manifest.json"),
        ("review-boss-runtime", "file-manifest.json"),
    ]
    for folder, name in manifest_specs:
        path = BASE / folder / name
        manifest = read(path)
        for expected in manifest["files"]:
            assert pin(expected["path"]) == expected, expected["path"]
            manifest_files.append(expected)
        inputs.append(pin(path))

    specs = [
        ("review-boss-a/actor-list.json", "actors", "status", "original_approval"),
        ("review-boss-b/review-results.json", "reviews", "current_review", "prior_production_status"),
        ("review-boss-c/review-results.json", "actors", "status", "original_approval_status"),
    ]
    bosses = []
    for path, key, status_key, prior_key in specs:
        path = BASE / path
        inputs.append(pin(path))
        for actor in read(path)[key]:
            status = actor[status_key]
            previous = actor[prior_key]
            if isinstance(previous, dict):
                previous = previous["production_status"]
            assert index[actor["id"]]["kind"] == "boss"
            assert index[actor["id"]]["preserved_status"] == previous
            bosses.append({"id": actor["id"], "name": index[actor["id"]]["name"],
                           "prior_status_preserved": previous, "current_visual_screen": status,
                           "approval_changed": False, "new_production_approval": False,
                           "reasons": actor["reasons"], "detail_report": rel(path)})
    assert len(bosses) == len({row["id"] for row in bosses}) == 60
    assert {row["id"] for row in bosses} == {key for key, row in index.items() if row["kind"] == "boss"}
    bosses.sort(key=lambda row: row["id"])

    normal_path = BASE / "review-normal-frames/results.json"
    normal = read(normal_path)
    assert {row["key"] for row in normal["runtime"]} == {key for key, row in index.items() if row["kind"] == "normal"}
    assert len(normal["runtime"]) == 258
    for row in normal["runtime"]:
        assert row["preserved_status"] == index[row["key"]]["preserved_status"]
    runtime_path = BASE / "review-boss-runtime/summary.json"
    runtime = read(runtime_path)
    assert len(runtime["exact_boss_ids"]) == len(set(runtime["exact_boss_ids"])) == 60
    assert set(runtime["exact_boss_ids"]) == {row["id"] for row in bosses}
    assert runtime["approved_preserved"] == 43
    assert runtime["required_resolver_unavailable"] == 0
    assert runtime["AnimatedSprite2D_play_failures"] == 0
    inputs.extend([pin(normal_path), pin(BASE / "review-inputs.json"),
                   pin("data/pr122_monster_review_scope.json"),
                   pin(runtime_path),
                   pin(BASE / "review-boss-b/queen-staging-review.json")])
    counts = dict(Counter(row["current_visual_screen"] for row in bosses))
    approved_counts = dict(Counter(row["current_visual_screen"] for row in bosses
                                   if row["prior_status_preserved"] == "VERIFIED_COMPLETED"))
    summary = {
        "schema": "pr122-monster-recheck-summary-v1", "review_date": "2026-10-23",
        "reviewed_source_commit": SOURCE_COMMIT,
        "include_previously_approved": True,
        "normal": {"review": "frame_integrity_only", "art_quality_review_performed": False,
                   "runtime": normal["runtime_summary"], "staging": normal["staging_summary"],
                   "staging_partial_candidates": read(BASE / "review-normal-frames/receipt.json")["partial_candidates"],
                   "runtime_WALK_to_RUN_reuse_included": True,
                   "runtime_frame_availability_is_dedicated_source_completion": False,
                   "invalid_frame_occurrences": normal["invalid_frame_occurrences"],
                   "failed_PNG_sources": normal["PNG_failed_sources"], "details": rel(normal_path)},
        "boss": {"reviewed": 60, "previously_approved_included": 43,
                 "current_visual_screen_counts": counts,
                 "previously_approved_current_visual_screen_counts": approved_counts,
                 "PASS_meaning": "Source-frame visual screening only; no new production/release approval. Actual Main target contact/timing not signed off.",
                 "coverage_limits": [
                     "Group A: 12 packs, all eight views and role overviews; full movement/attack phases in all eight directions for six packs, E/S/N for six packs. Other intermediate phases unreviewed.",
                     "Group B: all source-frame role/view sheets and enlarged selected locomotion; actual Main timing/contact/physical support not approved.",
                     "Group C: all existing role/view source phases in eight packs; actual Main target timing, flight altitude and weight transfer not approved."
                 ], "actors": bosses,
                 "new_queen_RUN_review": read(BASE / "review-boss-b/queen-staging-review.json"),
                 "runtime_validation": runtime,
                 "runtime_validation_directory": rel(BASE / "review-boss-runtime")},
        "preservation": {"existing_normal_approvals": 221, "existing_boss_approvals": 43,
                         "approval_mutations": 0, "production_status_mutations": 0,
                         "existing_asset_mutations": 0, "runtime_catalog_mutations": 0,
                         "new_art_in_this_review": 0, "new_production_approvals": 0,
                         "production_counts_unchanged": scope["summary"]},
        "validation": {"manifest_file_entries_verified": len(manifest_files),
                       "manifest_bytes_verified": sum(row["bytes"] for row in manifest_files),
                       "manifest_mismatches": 0, "full_CI_repeated": False,
                       "chat_images_or_base64_emitted": False},
        "input_pins": inputs,
    }
    out = BASE / "review-summary.json"
    out.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    hold_reasons = {
        "바포메트": "베레스와 참조 crop·runtime PNG가 같아 개별 고유성 근거 부족. 이동 접지·망토 중량·타격 타이밍 미확정.",
        "베레스": "바포메트와 참조 crop·runtime PNG가 같아 개별 고유성 근거 부족. 이동 접지·망토 중량·타격 타이밍 미확정.",
        "분노의 주시자 라즈엘": "중심 눈·촉수의 타격 부위/거리와 실제 판정 프레임 접촉 미확인.",
        "불사의 머미 로드": "망토에 가려진 반대발 지지 교대와 체중 이동이 확정되지 않음.",
        "살라흐": "발굽 지지 교대 및 정면 공격의 실제 전방 타격 접촉 미확정.",
        "웨링": "앞·뒷발의 반대 지지 교대와 접촉 미확정.",
        "이프리트": "이동·화염 방출과 실제 대상 접촉 타이밍 추가 확인 필요.",
        "지옥의 쿠거": "대형 사족 보행의 반대 지지 교대·중량·접촉 미확정.",
        "피닉스": "비행 중 몸통 고도·날개 중량 및 실제 타격 타이밍 추가 확인 필요.",
    }
    held = [row for row in bosses if row["current_visual_screen"] == "HOLD"]
    passed = [row["name"] for row in bosses if row["current_visual_screen"] == "PASS"]
    table = "\n".join(f"| {row['name']} | {hold_reasons[row['name']]} |" for row in held)
    doc = f"""# PR122 몬스터 재점검 — 2026-10-23

기승인 항목을 포함하여 일반 258종은 프레임 누락만, 보스 60종은 프로젝트의 기존 원형과 실제 프레임을 대조했다. 일반의 외형·색상·종족·접지·공격 자세는 재심사하지 않았다. 기존 자산·승인·제작 상태와 현재 게임 카탈로그는 변경하지 않았다.

## 결과

| 대상 | 검사 수 | 포함한 기승인 | 현재 결과 |
| --- | ---: | ---: | --- |
| 일반 runtime | 258종 | 221종 | 필수 8,514 동작·방향 요청 누락 0, 로드·빈 프레임·범위 오류 0 |
| 보스 시각 검토 | 60종 | 43종 | 재제작 후보 48, HOLD 9, 시각 검토 통과 3 |
| 기승인 보스만 | 43종 | 43종 | 재제작 후보 31, HOLD 9, 시각 검토 통과 3; 기존 승인은 전부 보존 |

일반 runtime 결과는 기존 WALK를 RUN 요청에 재사용한 2,064건을 포함한다. 258종 모두의 전용 신규 RUN 원화가 완성되었다는 뜻은 아니다. 고유 runtime SpriteFrames 93개/PNG 433경로를 실제 Godot와 픽셀 검사로 확인했다. 일반의 과거 시각 품질 HOLD는 이번 프레임 검사 실패로 취급하지 않는다.

별도 신규 일반 staging 12항목 중 10항목은 필수 33 동작·방향을 갖췄다. 놀 31클립, 알비노 몽크 32클립은 아직 미제작이다. 합계 63개는 미제작 동작·방향 슬롯 수이며 손상 PNG 프레임 수가 아니다. staging을 포함한 고유 SpriteFrames 99개/PNG 461경로에서 로드·빈 프레임·범위 오류는 없었다. 신규 원화와 현재 게임의 공용 대체 자산은 구분해 기록했다.

보스 시각 검토 통과 3종: {', '.join(passed)}. 이는 실제 소스 프레임의 원형·방향·역할 구분 검토 결과다. 실제 Main의 대상 접촉·타격 타이밍까지 최종 승인하거나 신규 제작 승인을 부여한 결과는 아니다.

재제작 후보의 주요 사유는 공용 기사·마법사·악마·용 모델이 보스의 원형 체형, 망토·장비, 날개·사지 수 등 고유 정체성을 보존하지 못한 것이다. 60종 각각의 기존 승인, 현재 판정과 구체 사유는 [통합 JSON](evidence/pr122-monsters-20261023/review-summary.json)에 있다.

## 보스 HOLD 9종

| 이름 | 남은 확인 |
| --- | --- |
{table}

얼음 여왕의 신규 staging RUN 8방향×6포즈는 현재 후드 마법사 대체 자산과 별도로 검토했다. 은발·왕관·보라 날개·검금 갑옷·지팡이 정체성 회복은 확인했다. E/S/SE/SW의 반대발 지지와 NE의 후방 사선 카메라가 확정되지 않아 HOLD를 유지한다. 두 NativeProfile의 실제 scale을 적용한 관찰이며 공통 scale 통합·실제 게임 타이밍 승인은 하지 않았다. [별도 판정](evidence/pr122-monsters-20261023/review-boss-b/queen-staging-review.json)

## 검증 범위와 보존

- 일반: 실제 Godot 4.7.2 ActorMotion resolver 8,514 요청, PNG alpha·AtlasTexture 범위 검사. 외형 품질 검토 0종.
- 보스 A: 12공유 세트의 8방향·역할 개요 확인. 6세트는 이동·공격 전 방향 전체 위상, 나머지 6세트는 E/S/N 전체 위상 확인. 나머지 중간 위상과 실제 게임 타이밍은 미검증.
- 보스 B/C: 명시한 전체 역할·방향 소스와 확대 이동 위상을 실제 관찰. 실제 Main의 타격 접촉·물리 접지·비행 고도·중량 타이밍은 승인하지 않음.
- 보스 Godot: 60종 전부의 고유 TRES 29개/PNG 163경로 로드 오류 0. 필수 1,980요청과 기존 다방향 사망 추가 420요청을 합친 AnimatedSprite2D.play 2,400건 실패 0. RUN→WALK 재사용 480건 포함. 137배 가속 headless 엔진 프레임 진행 검사로, 실제 게임 속도·Main 전투·타격 타이밍·신화급 품질 검증과 구분한다. [별도 증거](evidence/pr122-monsters-20261023/review-boss-runtime/summary.json)
- 모든 파생 시각 증거는 저장소 파일로 보관했으며 채팅 이미지/Base64 출력은 하지 않았다. 각 검사 폴더의 SHA-256 장부를 대조했다. 전체 CI는 반복하지 않았다.

검토 기준 소스 커밋: `{SOURCE_COMMIT}`. 기존 승인 일반 221/258(잔여 37), 보스 43/60(잔여 17)은 유지했다. 이번 재점검의 신규 원화 제작·신규 승인·기존 승인 취소는 0건이다. 원본 상태 장부와 승인 자산은 변경하지 않았다.

재현 집계: `python3 docs/remake/evidence/pr122-monsters-20261023/summarize_review.py`
"""
    (ROOT / "docs/remake/PR122_MONSTER_RECHECK_20261023.md").write_text(doc)
    print(json.dumps({"normal": normal["runtime_summary"], "boss": counts,
                      "previously_approved_boss": approved_counts}, ensure_ascii=False))


if __name__ == "__main__":
    main()
