# PR122 색상·이름 파생 애니메이션 병행 작업 지시 (2026-10-20)

## 실행 목적과 브랜치

사용자 요청: PR122의 색상만 다르거나 이름만 다른 개체의 애니메이션을, 진행 중인 다른 Codex의 고유 외형 제작과 충돌하지 않게 병행한다. 문서 작성이나 검토만으로 끝내지 말고 재사용 가능한 소스를 확인하여 실제 파생 리소스와 개체별 연결 패치를 제작한다.

- 저장소: zoog136-hash/-; 최종 통합 대상: 기존 PR #122.
- 기존 외형 제작 브랜치: `feature/twilight-remaining106-20261016`. 이 작업자는 여기에 직접 push하지 않는다.
- 이번 색상·이름 작업 전용 브랜치: `feature/pr122-palette-alias-20261020`.
- 분리 기준 SHA: `500ac94f0826aeeb93a9eb325f72b15165c15382`. 기준점일 뿐 향후 최신 HEAD라고 가정하지 않는다.
- 별도 clone 또는 별도 worktree에서 전용 브랜치를 사용한다. 다른 세션의 작업 폴더에서 checkout/reset/stash/clean하지 않는다. 다른 세션의 미커밋 파일은 GitHub만으로 확인할 수 없다.
- 새 PR, main 병합, PR122 병합, rebase, force push, 기존 파일 삭제는 하지 않는다. 최종 통합은 기존 PR122 담당자가 검증 후 개별 커밋·대상별 패치로 수행한다.

## 기존 상태를 먼저 읽고 보존

`AGENTS.md`, `TWILIGHT_PROJECT_RULES.md`, `docs/RESOURCE_INTEGRITY_POLICY.md`, 최신 `docs/remake/TWILIGHT_PR122_RESUME_20261019.md`를 읽는다. 리소스 작업 전 `python3 tools/check_resource_integrity.py --root .`를 실행하고 환경 또는 원본이 없으면 정확히 미검증으로 기록한다.

`data/pr122_palette_finish_20261019.json`의 기존54프로필(변신33/몬스터21)은 이미 저장된 모션 공유·색상 작업이다. 이번 신규 제작으로 중복 집계하지 않는다. `data/pr122_palette_reuse_20261019.json`의 과거 후보와 `superseded_by_native_pack`도 읽고, 나중에 제작된 고유 리소스를 과거 대체 모션으로 되돌리지 않는다. 두 장부의 모든 항목이 실제로 같은 외형이라는 뜻은 아니다. `original_identity_verified=false` 및 `identity_verified=false`를 승인으로 바꾸지 않는다.

## 작업 분담과 소유권

### 기존 고유 외형 작업자 소유 — 수정 금지

- `docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json`의 최신 전체 대상31종. 할파스393·기르타스267 및 이미 승인된 native production을 포함한다. 목록은 최신 파일에서 읽고 PR 본문의 과거 수치로 되돌리지 않는다.
- 보행/달리기 보완14종: transform:258,412,288,401,176,351,349,328,249,218,173,167,110,2. 이들의 원본 프레임과 자세 제작은 기존 담당자 소유다.
- `data/pr122_native_locomotion_staging.json`, `data/pr122_native_production_approvals.json`, 기존 상세 제작 queue/manifest/승인증명/원화와 모든 기존 production 아트.
- 다른 고유 외형 작업자가 추가로 작업 소유권을 알린 대상도 제외한다. 소유권을 확인하지 못한 대상은 HOLD한다.

### 이번 작업자 소유

- 원형의 체형·장비·관절·프레임 구조가 같다는 근거가 확인된 이름 파생과 색상 파생만 처리한다. 이름 유사성, 동일 fallback atlas cell, 동일 임시 모션을 동일 외형의 증거로 쓰지 않는다.
- 이름만 다르면 승인된 동일 SpriteFrames를 참조하고 개체 ID/이름/등급/능력치/저장 식별자는 분리 유지한다. 불필요한 PNG 복제 금지.
- 색상만 다르면 동일 모션·방향·접지·피벗·프레임 순서·길이를 보존하고 파생 개체에만 색상을 적용한다. 공유 원본 texture/material을 직접 바꾸지 않는다. 피부/장비/광원까지 무차별 변색시키지 말고 필요한 부위만 처리한다.
- 최초 확인 사례: transform:179 랜스 마스터(레드), transform:182 랜스 마스터(블루), source transform:44. 이들은 기존 연결 항목이며 신규 제작으로 계산하지 않는다. 기존 source 경로가 spear_captain이고 source transform:176은 보행 보완 대상이므로, 미완성3프레임 원본을 복제해서 보행/달리기 완성이라고 주장하지 않는다. 최신 소스 품질과 의존 관계를 먼저 확인한다.
- 남녀 외형·무기·체형·날개가 다른 경우 및 총사를 활잡이 모션으로 대체하는 경우는 이번 단순 색상/이름 작업에 포함하지 않는다.

## 파일 분리 — 공용 카탈로그 동시 수정 금지

새 출력은 아래의 전용 경로에만 추가한다. 새 리소스가 필요 없으면 JSON 참조 패치만 만든다.

- `assets/actors/eight_direction/palette_alias_pr122/`
- `data/pr122_palette_alias_parallel/`
- `docs/remake/evidence/pr122-palette-alias-parallel/`
- 필요 시 전용 `tools/pr122_palette_alias_*` 및 `tests/pr122_palette_alias_*`만 추가.

기존 `data/combat_animation_profiles.json`, `data/animation_presentation.json`, 공용 카탈로그·매핑, 공용 ActorMotion/Player 로직, 기존 SpriteFrames, 맵·전투·AI·드랍·저장 데이터를 통째로 재생성하거나 수정하지 않는다. 임시 연결 검증은 전용 테스트 씬/로더에서 수행한다. 일반 게임 카탈로그 반영은 통합 담당자 한 명만 한다.

각 대상의 준비 패치에는 target ID, source ID, 원본 리소스 경로/SHA-256, 파생 유형, 색상 설정, 변경 전 대상 레코드의 해시, 새 리소스 경로, 검증 상태를 담는다. 통합 시 최신 원격 대상/소스 해시가 달라지면 자동 적용을 중단하고 다시 조정한다. 새 고유 외형이 적용된 대상을 덮어쓰지 않는다.

## 제작·검증·보고

1. 최신 카탈로그/장부에서 이미 연결됨·재사용 가능·원형 확인 필요·외형 담당자 소유를 구분한다. 실제 근거가 확인된 대상부터 작은 묶음으로 바로 제작한다. 다른 담당자의 작업을 기다리며 전체 작업을 멈추지 않는다.
2. 원본이 가진8방향 idle/walk/attack/hit/death와 실제 존재하는 run을 보존한다. 별도 run이 없으면 미완성으로 기록하고 walk 복제나 FPS 증가를 새 run 제작으로 표시하지 않는다. 타격 마커와 전투/이동 속도는 변경하지 않는다.
3. 새 리소스의 실제 바이트·Git 추적·SHA, 방향/동작/프레임/투명도/피벗과 전용 Godot Player 재생을 검증한다. headless PASS, Main 렌더, Android 실기를 구분하고 실행하지 않은 검사는 NOT_RUN으로 남긴다.
4. 출력 이미지·Base64·대량 파일 목록·전체 로그를 채팅에 붙이지 않는다. 이번 파생 작업에는 새 원화 생성 도구가 필요하지 않다. 기존 실패/WIP/원본을 보존한다.
5. 제작 커밋은 `[skip ci]`로 저장한다. 제작 도중 전체 CI를 재실행하지 않는다. 개별 최소 검증은 수행하고 최종 통합 후에 필요한 회귀 검증을 진행한다.
6. 기존 승인 이력, 프레임 보완14종, 상세 제작31종 상태를 이 작업으로 임의 변경하지 않는다. 신규 원화0, 파생 리소스 수, 실제 연결 수, 실제 재생 검증 수를 각각 분리하여 보고한다.

## 이 준비 커밋의 완료 범위

별도 브랜치와 작업 지시만 준비했다. 추가 애니메이션 제작/일반 게임 연결/실행 검증은 이 커밋에서 수행하지 않았다. 다른 Codex의 수신·착수는 작업 응답이나 실제 코드 커밋이 확인되기 전까지 미확인이다. 기존 PR122 브랜치와 게임 리소스는 이 준비 작업에서 변경하지 않는다.
