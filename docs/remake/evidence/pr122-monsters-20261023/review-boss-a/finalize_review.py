"""Persist the private, read-only visual observations; never mutate approvals."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
prepared = json.loads((OUT / "prepared.json").read_text())
vision = json.loads((OUT / "vision-pins.json").read_text())
DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
FULL_CYCLES = {
    "antlion_small", "wyvern_air_boss", "male_plate_plate_helm_longsword",
    "baphomet_project_source", "beres_project_source", "raziel_watcher",
}


def pin(path):
    p = ROOT / path
    return {"path": path, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}


def finding(check, result, observed):
    return {"check": check, "result": result, "observed": observed}


OBSERVATIONS = {
    "antlion_small": [
        finding("source_identity", "REWORK_CANDIDATE", "원형은 구리색의 둥근 분절 복부, 길고 가는 6개 다리가 두드러진 거대 개미다. runtime은 연두색의 낮고 작은 개미귀신형 곤충으로, 원형의 큰 분절 복부와 금속질 머리/흉부 실루엣이 보존되지 않았다. 색 차이 외에 복부 비율과 다리/몸통 형상이 다르다."),
        finding("eight_view_camera", "OBSERVED", "8방향 모두 곤충의 앞/옆/등 시점이 구분되며 방향별 원근이 있다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "WALK 8위상에서 다리의 전후 지지 교대와 몸통 높낮이 변화가 보인다. 전용 RUN은 없으며 실제 게임 이동속도에서 접지는 확인하지 않았다."),
        finding("attack_contact", "HOLD", "4위상에서 앞다리 들기와 몸통 뻗기가 구분된다. 설정 contact=2는 아직 앞다리를 든 자세이고 phase3에서 몸통이 더 낮게 뻗는다. 실제 공격 판정과 도달점 일치 여부는 재생/대상 검증이 필요하다."),
    ],
    "wyvern_air_boss": [
        finding("source_identity", "REWORK_CANDIDATE", "원형 드레이크는 붉은 비늘의 굵은 목/머리, 네 다리와 별도 날개를 가진 육중한 용이고 그라디움 원형은 검정/금색의 두꺼운 갑주형 용이다. 공통 runtime은 회청색의 가는 목/작은 머리, 큰 박쥐날개와 두 뒷다리를 가진 가벼운 와이번이다. 체형·사지 수·종별 갑주가 유지되지 않는다."),
        finding("eight_view_camera", "OBSERVED", "8방향 앞/옆/등과 날개의 원근이 구분된다. 외측 날개까지 포함한 넓은 검사 뷰포트로 다시 확인했으며 초기 검사 시트에서 보인 잘림은 시트 뷰포트 문제였다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "WALK 8위상은 공중 날갯짓이며 날개가 위/수평/아래로 바뀐다. 공중 개체이므로 발 접지 교대는 적용하지 않았다. 네 다리 육중한 원형의 지상 이동/무게감은 이 세트로 보존되지 않는다."),
        finding("attack_contact", "HOLD", "ATTACK 8위상에서 날개와 뒷다리/가슴이 바뀐다. 설정 contact=4의 들린 다리/가슴 자세는 보이나 실제 대상에 대한 발톱·물기 접촉은 확인하지 않았다."),
    ],
    "male_plate_plate_helm_longsword": [
        finding("source_identity", "REWORK_CANDIDATE", "지배자 계열 로컬 원형은 큰 가시 견갑, 각진 폐쇄형 투구, 긴 붉은 찢긴 망토와 넓고 큰 장검을 가진 중갑 기사다. runtime은 둥근 단순 투구, 작은 검, 큰 방패와 짧은 평범한 망토의 병사다. 원형의 무게감/갑주 외곽/무기 비율이 사라졌으며 원형에 없는 방패가 주요 실루엣을 차지한다."),
        finding("eight_view_camera", "OBSERVED", "8방향 앞/뒤/옆, 방패의 앞뒤 가림과 망토 방향이 읽힌다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "WALK 8위상 전 방향에서 반대 지지 다리가 교대로 뻗고 접힌다. 몸통/장비가 분리되지는 않는다. 전용 RUN 트랙과 실제 속도에서 발 미끄러짐은 검증하지 않았다."),
        finding("attack_contact", "HOLD", "4위상 베기와 회복은 구분된다. contact=2의 E/S 검은 비스듬히 들린 중간 궤적이고 phase3이 낮은 회복 자세다. 실제 타겟 접촉 시점을 판정할 재생 증거는 없다."),
    ],
    "male_chain_chain_coif_longsword": [
        finding("source_identity", "REWORK_CANDIDATE", "뱀파이어 원형의 창백한 귀족 얼굴, 높은 붉은 옷깃, 길고 찢긴 붉은 망토와 가느다란 검이 runtime에서 사라졌다. runtime은 얼굴을 가린 사슬 두건 병사와 방패/단검형 실루엣이다. 보라 tint로 원형 정체성을 대체할 수 없다."),
        finding("eight_view_camera", "OBSERVED", "개요 시트의 8방향은 앞/옆/등과 방패 가림이 구분된다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "E/S/N의 WALK 8위상에서 다리 지지가 교대하며 검/방패가 연결되어 있다. 나머지 이동방향은 개요의 phase0만 보았다."),
        finding("attack_contact", "HOLD", "E/S/N 4위상은 베기/회복으로 읽히지만 타겟이나 실제 판정 시점을 함께 보지 않았다."),
    ],
    "reaper_male": [
        finding("source_identity", "REWORK_CANDIDATE", "원형은 노출된 해골/갈비뼈, 검은 후드와 긴 누더기 로브, 어두운 낫의 사신이다. runtime은 푸른 긴 깃털/머리, 검정/금색 전신 판금, 청색 발광 장식 낫의 무장 전사다. 낫이라는 부위 외에 머리·몸통·의복 종족 정체성이 바뀌었다."),
        finding("eight_view_camera", "OBSERVED", "8방향에서 낫, 망토와 전후 시점이 구분된다."),
        finding("locomotion_support", "HOLD", "E/S/N의 WALK는 2위상뿐이며 보폭 변화는 있지만 반대 발의 완전한 지지 교대와 빠른 RUN 연속성을 이 두 정지 이미지로 승인할 수 없다."),
        finding("attack_contact", "OBSERVED_WITH_LIMIT", "E/S/N 3위상은 낫 머리 위 준비, phase1의 큰 전방/하향 베기, phase2 회복이 분명하다. 실제 타격 타이밍은 미검증이다."),
        finding("cross_role_body_consistency", "REWORK_CANDIDATE", "8방향 개요의 HIT는 IDLE보다 어깨와 몸통이 두껍고 덩치가 커 보여 역할 전환 시 실루엣 변화 검토가 필요하다."),
    ],
    "skeleton_mage_boss": [
        finding("source_identity", "REWORK_CANDIDATE", "네크로맨서의 로컬 원형은 긴 검정/금색 로브, 큰 왕관, 큰 해골 머리 장식의 긴 지팡이를 가진 리치다. runtime은 노출된 가는 해골 사지, 짧은 검은 두건/등 천, 짧은 파란 끝 막대다. 로브의 질량과 왕관/긴 해골 지팡이가 유지되지 않았다."),
        finding("eight_view_camera", "OBSERVED", "8방향의 해골 앞/등과 후드 방향은 구분된다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "E/S/N WALK 8위상에서 반대 다리 지지가 바뀐다. 원형의 긴 로브 무게감은 노출된 다리 병사 리그에서 확인되지 않는다."),
        finding("attack_contact", "HOLD", "E/S/N ATTACK에서 짧은 막대를 전방으로 뻗는 캐스팅 자세가 보인다. 주문/목표 및 실제 판정 시점은 보지 않았다."),
    ],
    "skeleton_knight_boss": [
        finding("source_identity", "REWORK_CANDIDATE", "데스나이트 원형의 육중한 검은 가시 중갑, 폐쇄형 투구, 긴 붉은 누더기 망토, 넓은 대검이 runtime에서 유지되지 않았다. runtime은 갈비뼈가 노출된 해골, 붉은 깃 투구, 붉은 둥근 방패와 양 끝에 칼날이 달린 긴 무기다. 의복 질량과 주요 무기 실루엣이 다르다."),
        finding("eight_view_camera", "OBSERVED", "8방향에서 갈비뼈 앞/뒤와 방패 가림, 붉은 깃 방향이 구분된다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "E/S/N WALK 8위상에서 양 다리의 전후 지지가 바뀌며 몸통/무기가 분리되지는 않는다."),
        finding("attack_contact", "OBSERVED_WITH_LIMIT", "E/S/N ATTACK 4위상은 긴 양날 무기를 크게 휘두르는 공격으로 읽힌다. 원형의 대검 베기와는 다르고, 실제 피격 대상과 판정 타이밍은 미검증이다."),
    ],
    "male_plate_plate_helm_battle_axe": [
        finding("source_identity", "REWORK_CANDIDATE", "듀페리온 로컬 원형의 큰 뿔/가시 투구와 거대 견갑, 몸통 갑주 덩어리, 긴 붉은 망토가 runtime의 단순 둥근 투구/작은 갑주/짧은 망토 병사에서 사라졌다. DB 무기 분류는 도끼이지만 로컬 원형 그림은 큰 톱니 장검으로 보여 무기 기준에는 원형/DB 충돌도 있다. 판정 근거는 단순 색상보다 갑주와 질량 차이다."),
        finding("eight_view_camera", "OBSERVED", "8방향 몸통 앞/뒤, 작은 도끼와 짧은 망토의 원근은 구분된다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "E/S/N WALK 8위상은 반대 지지 다리 교대가 보이고 몸통이 연결되어 있다. 원형 대형 보스의 무게감은 보존되지 않았다."),
        finding("attack_contact", "HOLD", "E/S/N 4위상 도끼 베기에서 준비/하향 회복이 보인다. contact=2와 게임 대상 충돌의 일치는 확인하지 않았다."),
    ],
    "baphomet_project_source": [
        finding("source_identity", "OBSERVED_LOCAL_REFERENCE_MATCH", "원형의 굽은 염소뿔/해골 얼굴, 노출된 골격 몸통, 붉은 찢긴 옷/망토와 긴 곡선 도끼가 8방향 runtime에 유지된다."),
        finding("boss_specific_identity", "HOLD", "바포메트와 베레스는 authoring_sources 원형 crop도 같고 runtime PNG도 동일한 salah/poses-0,1을 사용한다. 각 보스가 서로 다른 고유 외형이어야 하는지 판정할 독립된 원형 증거가 없으므로 보스별 고유성 최종 승인은 보류한다. 단순 공유 사실만으로 기존 승인을 취소하지 않는다."),
        finding("eight_view_camera", "OBSERVED", "앞쪽 해골 얼굴과 N의 뒤통수/망토, 측면 긴 무기가 8방향에서 일관된다."),
        finding("locomotion_support", "HOLD", "WALK 3위상 전 방향에서 발 위치와 무릎의 전후 변화가 보이나 전용 RUN은 없다. 짧은 3위상의 실제 이동속도에서 접지와 망토 후행/무게감은 정지 시트로 확정할 수 없다."),
        finding("attack_contact", "OBSERVED_WITH_LIMIT", "ATTACK 3위상 전 방향에서 phase0 머리 위 준비, phase1 전방/하향 도끼 뻗기, phase2 회복이 명확하고 설정 contact=1이 가장 뻗은 도끼 자세에 해당한다. 실제 대상 접촉 타이밍은 미검증이다."),
    ],
    "beres_project_source": [],
    "raziel_watcher": [
        finding("source_identity", "OBSERVED_LOCAL_REFERENCE_MATCH", "원형의 상아색/연보라 촉수, 금색 눈 테두리, 작은 여러 눈과 청자홍색 전면 중심 눈 보석이 유지된다. 이 세트의 고유한 부유형 주시자 실루엣이 실제로 보인다."),
        finding("eight_view_camera", "OBSERVED", "8방향에서 전면 중심 눈과 N/북대각의 중심 눈 없는 뒷면, 측면 촉수 원근이 구분되어 단순 2D 회전처럼 보이지 않는다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "WALK 3위상 전 방향에서 부유 몸통의 기울기와 촉수 방향 변화가 보인다. 발이 없는 부유형이므로 반대 발 접지는 해당하지 않는다. 실제 속도에서 촉수 후행의 자연스러움은 확인하지 않았다."),
        finding("attack_contact", "HOLD", "ATTACK 3위상에서 phase1의 좌우 확장과 촉수/몸통 쏠림이 보이며 idle과 구분된다. 중심 눈/촉수 어느 부위가 어떤 거리의 대상을 타격하는지, 이 자세가 판정 contact=1과 맞는지는 실제 장면에서 보지 않았다."),
    ],
    "skeleton_mage_high_boss": [
        finding("source_identity", "REWORK_CANDIDATE", "불멸의 리치 원형의 긴 검정/금색 로브, 화려한 왕관과 긴 해골 지팡이에 비해 runtime은 노출된 금색 해골 다리, 단순 왕관/흉갑, 평범한 보라색 등 망토와 짧은 보라 끝 막대다. 왕관 추가만으로 원형의 로브 질량과 해골 지팡이 정체성이 복구되지 않는다."),
        finding("eight_view_camera", "OBSERVED", "8방향 앞/등과 왕관/등 망토 가림은 구분된다."),
        finding("locomotion_support", "OBSERVED_WITH_LIMIT", "E/S/N WALK 8위상에서 반대 다리 지지가 바뀌고 보라 망토가 흔들린다. 원형의 긴 의복/지팡이 무게감은 없다."),
        finding("attack_contact", "HOLD", "E/S/N ATTACK은 짧은 막대를 전방으로 내미는 캐스팅이다. 주문/목표 및 실제 판정 시점은 보지 않았다."),
    ],
}
OBSERVATIONS["beres_project_source"] = json.loads(json.dumps(OBSERVATIONS["baphomet_project_source"]))

reviewed_sets = {}
for frames_path, group in prepared["runtime_sets"].items():
    name = Path(frames_path).parent.name
    cycle_views = DIRECTIONS if name in FULL_CYCLES else ["E", "S", "N"]
    actual = []
    for mode, sheet in group["sheets"].items():
        for sample in sheet["planned_samples"]:
            if mode != "overview" and sample["direction"] not in cycle_views:
                continue
            sample = dict(sample)
            count = group["track_counts"][f"{sample['role']}_{DIRECTIONS.index(sample['direction'])}"]
            if sample["phase"] < 0:
                sample["phase"] += count
            if sample not in actual:
                actual.append(sample)
    evidence = []
    for mode in ["overview", "move", "attack"]:
        if mode == "overview" or name in FULL_CYCLES:
            # The six sampled sets' overviews were inspected at full resolution;
            # the shared knight's full cycles were too. Others have private resized copies.
            direct = name not in {"antlion_small", "wyvern_air_boss"} and mode == "overview"
            direct = direct or name == "male_plate_plate_helm_longsword"
            evidence.append({"mode": mode, **(group["sheets"][mode] if direct else vision[f"{name}-{mode}"])})
    if name not in FULL_CYCLES:
        evidence.append({"mode": "E_S_N_complete_move_attack", **vision[f"{name}-cycle-samples"]})
    unreviewed = []
    for track, count in group["track_counts"].items():
        role, direction = track.rsplit("_", 1)
        absent = [i for i in range(count) if {"direction": DIRECTIONS[int(direction)], "role": role, "phase": i} not in actual]
        if absent:
            unreviewed.append({"track": track, "phases": absent})
    reviewed_sets[frames_path] = {
        "runtime_species": group["runtime_species"],
        "shared_body_render_profile": group["runtime_species"][0],
        "source_PNG_pins": group["source_pins"],
        "track_counts": group["track_counts"],
        "actual_examined_views": DIRECTIONS,
        "complete_move_attack_cycle_views": cycle_views,
        "actual_examined_samples": actual,
        "actual_unique_track_samples_count": len(actual),
        "private_visual_evidence": evidence,
        "unseen_track_phases": unreviewed,
        "run_track_present": any(k.startswith("run_") for k in group["track_counts"]),
        "new_WALK_or_DEATH_assets": 0,
    }

rows = []
for row in prepared["bosses"]:
    group = reviewed_sets[row["profile"]["frames_path"]]
    name = Path(row["profile"]["frames_path"]).parent.name
    observations = json.loads(json.dumps(OBSERVATIONS[name]))
    if row["id"] == "monster:교만의 왕자 데우스":
        observations[0] = finding("source_identity", "REWORK_CANDIDATE", "데우스 원형은 큰 흰 깃털 날개, 백/금색 갑주, 청/백색 긴 로브와 긴 금색 지팡이를 가진 왕자다. 공유 runtime은 날개·로브·지팡이가 없는 작은 검/큰 방패 병사다. 원형의 가장 큰 정체성 부위 세 가지가 모두 없다.")
    observations.append(finding("idle_hit_separation", "OBSERVED_SAMPLES_ONLY", "8방향의 IDLE 0/1과 HIT 첫/마지막 자세를 대조했다. 피격의 몸통 굽힘/수축·무기 자세 변화가 idle과 구분된다. 긴 IDLE/HIT 클립의 중간 위상은 unseen 목록에 남긴다."))
    observations.append(finding("gross_clipping_body_collapse", "NO_GROSS_DEFECT_IN_EXAMINED_SAMPLES", "넓은 검사 뷰포트에 포함된 샘플에서는 무기/날개 끝의 명백한 절단이나 분리된 신체가 보이지 않았다. unseen 위상과 실제 게임 카메라/스케일에서의 경미한 교차·잘림을 통과시킨 판정은 아니다."))
    status = "HOLD" if name in {"baphomet_project_source", "beres_project_source", "raziel_watcher"} else "REWORK_CANDIDATE"
    reasons = [f["observed"] for f in observations if f["result"] == status]
    if status == "HOLD":
        reasons.append("신화급 최종 품질 승인에는 실제 재생 속도/접촉 시점 확인이 남아 있다. 로컬 원형 일치나 기하 검사만으로 PASS 처리하지 않았다.")
    row.update({
        "original_approval": {"production_status": row["preserved_production_status"], "previously_approved": row["approval_preserved"]},
        "original_approval_unchanged": True,
        "source_profile_file_pin": pin("data/combat_animation_profiles.json"),
        "source_profile_canonical_sha256": hashlib.sha256(json.dumps(row["profile"], ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        "actual_examined_views": DIRECTIONS,
        "actual_examined_roles": ["idle", "walk (existing RUN fallback)", "attack", "hit"],
        "actual_examined_cycle_views": group["complete_move_attack_cycle_views"],
        "runtime_evidence_ref": row["profile"]["frames_path"],
        "actual_reference_examined": row["reference_crop_pin"],
        "visual_findings": observations,
        "status": status,
        "reasons": reasons,
        "unseen_not_reviewed": [
            "실제 Main 장면과 Godot 실시간 재생, 실제 이동속도에서 발 미끄러짐, 타겟/피격 판정과 공격 contact 시간 일치를 이번 정지 시트 검사는 증명하지 않는다.",
            "runtime_sets의 unseen_track_phases에 남은 IDLE/HIT 중간 위상과 DEATH/CAST/SPECIAL/RANGED_ATTACK은 이번 시각검사 대상에서 보지 않았다. 기존 자산은 보존했다.",
            "shared_body_render_profile 이외의 종별 tint는 별도로 재렌더하지 않았다. 종별 실루엣/장비 비교는 동일 PNG/프레임과 각 원형 crop의 대조에 근거한다.",
        ] + (["이 종의 원형은 전용 animation_authoring_sources 레코드가 없어 현재 monster_world_catalog의 atlas/cell을 사용했다. 외부 원작 정합성은 별도 미검증이다."] if row["reference_resolution"] != "animation_authoring_sources" else []),
        "review_scope_disclaimer": "별도 현재 품질 재점검이다. 원래 VERIFIED_COMPLETED/NOT_AUTHORED 상태와 기존 승인을 변경하지 않는다.",
    })
    rows.append(row)

report = {
    "schema": "pr122-boss-private-visual-recheck-v1",
    "reviewed_at_utc": datetime.now(timezone.utc).isoformat(),
    "read_commit": prepared["read_commit"],
    "scope": "kind=boss, sorted id[0:20]; 일반 몬스터 품질은 검사하지 않음",
    "method": "실제 Git에서 hydrate한 PNG의 AtlasTexture region/margin을 재구성하고 shared profile의 tint/scale/offset으로 foot-line 검사 시트를 만들었다. 비공개 view_image를 이용해 각 로컬 원형 crop과 시각 비교했다. 모든 8방향 역할 개요 및 명시된 방향의 전체 WALK/ATTACK 위상을 실제 관찰했다. 원화 재제작/Git/기존 파일 수정은 하지 않았다.",
    "approval_mutations": 0,
    "existing_asset_mutations": 0,
    "new_visual_approvals": 0,
    "input_pins": [pin(p) for p in ["data/pr122_monster_production_scope.json", "data/combat_animation_profiles.json", "data/animation_authoring_sources.json", "data/monsters/monster_world_catalog.json", "data/monsters/art_atlases.json"]],
    "reference_overview_pin": prepared["reference_overview_pin"],
    "summary": {
        "bosses": len(rows),
        "preserved_existing_approvals": sum(r["approval_preserved"] for r in rows),
        "previously_pending_bosses": sum(not r["approval_preserved"] for r in rows),
        "recheck_status_counts": dict(Counter(r["status"] for r in rows)),
        "runtime_resource_sets": len(reviewed_sets),
        "resource_sets_with_all_eight_views_examined": len(reviewed_sets),
        "resource_sets_with_all_eight_full_move_attack_cycles_examined": len(FULL_CYCLES),
        "unique_resource_track_samples_examined": sum(g["actual_unique_track_samples_count"] for g in reviewed_sets.values()),
        "missing_PNG_dependencies": sum(len(g["missing_PNGs"]) for g in prepared["runtime_sets"].values()),
        "dedicated_RUN_track_sets": sum(g["run_track_present"] for g in reviewed_sets.values()),
        "reference_resolution_counts": dict(Counter(r["reference_resolution"] for r in rows)),
    },
    "bosses": rows,
    "runtime_sets": reviewed_sets,
}
(OUT / "review.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report["summary"], ensure_ascii=False))
