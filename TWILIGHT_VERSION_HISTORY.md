# TWILIGHT 버전 / 최종 통합 이력

**현재 최신 버전을 찾는 법:** GitHub `zoog136-hash/-` > `main` HEAD SHA를 확인합니다. 이 문서에 기록된 과거 SHA보다 최신 `main`이 우선입니다.

| 단계 | 커밋 / 이력 | 상태 |
| --- | --- | --- |
| 구버전 V20 게임 | 이전 `main` `11894be` | 최종 병합 전 백업으로 보존 |
| 통합 1~2 | 원본 바닥 드랍 PR #15, 전투 애니메이션 PR #16을 단계별 통합 | 통합 완료 |
| 통합 3 | 소모품/옵션/각인/강화의 개체별 반영; `3be4e2b` | 통합 완료 |
| 통합 4 | HUD, 인벤토리, 장비, 스킬, 지도, 상점, 강화 UI; `b0cfcd9`; PR #29 | 46/46 회귀 + UI 68장 증거 |
| 통합 5 | 구버전 저장 이전, 손상 파일 오류 처리; `d923aa2`; PR #30 | 47/47 회귀 및 렌더 검사 |
| 플레이테스트 | 도감 임시 아이템·주문서 지급, 시작 아데나 1억, 공통 창 드래그; PR #32, `455a5f1` | 48/48 회귀, UI 68장, Windows 부팅 검증 |
| Android | Android ARM64 디버그 APK, Godot 4.7.2 export preset 및 ETC2/ASTC 설정; 원본 `2157cb3` | APK 제작/검사 성공. 기기 실사용 미확인 |
| PR #43 재개 | 코드 `98c9e5f`; 최신 main `5596a64`의 PR #46·#48·#49를 기존 브랜치에 통합 | HP/MP 전용 갱신·피격 스탯 갱신 합치기·삭제 예약 시체 풀 수정. 새 전체 53/53, CI 12회 성공, OpenGL 106장. [증거](docs/monster-world-evidence/CI_RUNS.md). main 미병합 |
| 몬스터 월드 후보 | `feature/twilight-monster-world-overhaul-20261009`, 기준 `82dbbdb` | 25개 맵·별도 폭젠·보스 상태 저장. [범위·미완료·검증](docs/MONSTER_WORLD_IMPLEMENTATION.md). main 미병합 |

| UI 리뉴얼 후속 | PR #50 기존 `eefaf37` 유지 + 최신 main `67d69efd` 통합 | [화면별 구현 및 검증 범위](docs/UI_RENEWAL_FIDELITY_20261009.md). main 미병합; 새 SHA CI로 검증 |

## 검증 근거
- [Stage 5 Integration CI](https://github.com/zoog136-hash/-/actions/runs/37872771613): 47/47.
- [Playtest Godot Full CI](https://github.com/zoog136-hash/-/actions/runs/37879136512): 48/48.
- [Playtest UI CI](https://github.com/zoog136-hash/-/actions/runs/37879136491): UI 기능 테스트 및 68개 실제 화면.
- [Android APK CI](https://github.com/zoog136-hash/-/actions/runs/37883382633): Android ARM64 디버그 APK 내보내기 성공.
- 위 테스트는 별도 브랜치에서 진행됐습니다. **메인에 반영된 각 파일의 blob SHA를 검증된 후보와 비교**하고 필요 시 새 main 대상 회귀를 돌립니다.

## 계속 작업할 때 주의
1. `main`을 최신 기준으로 가져오고 이전 날짜 ZIP의 코드로 덮어쓰지 않습니다.
2. 새 변경은 `feature/` 브랜치에 작성하고 PR 검증 후 병합합니다.
3. 원작 리니지M과 혼동되지 않도록 자체 아트/코드/데이터 저작권 및 라이선스를 확인합니다.
4. 도감 지급과 아데나 1억은 **개발 전용**이며 출시 전에 분리/제거하도록 별도 작업합니다.
5. Windows·Android GPU 실제 성능, 장시간 플레이, Android 경고 정리 및 실제 기기 실행 확인은 남은 점검입니다.

마지막 수동 갱신: 2026-10-10.


## 원작 스킬 이행 작업 — 미완료, 별도 브랜치

- 최초 작업 시점 기준 main: `edefc7c120b9ad4f8e211c6e36478d4afb73c21d`. 후속 비교 시점 SHA는 아래 재개 기록 참조.
- 작업 브랜치: `feature/original-lineagem-skill-complete-20261010`. main 미병합.
- 13직업 조사 인벤토리 695개: 실행 연결 123개 PARTIAL, 570개 BLOCKED, PvP 전용 근거가 있는 2개 PVP_EXCLUDED. 전체 역사 목록의 완전성 UNKNOWN.
- 학습·스킬북·강화 관계·수동/자동/패시브 전투 경로·슬롯 이전·별도 수치·ID별 VFX/아이콘/합성 오디오를 연결했습니다. 기존 아이템 인스턴스와 원본 스킬 DB를 보존합니다.
- 최신 실행 결과와 정확한 CI SHA는 [검증 보고서](docs/skills/VALIDATION.md)에 기록합니다. 원작 전체 구현 완료나 출시/병합 준비 완료를 뜻하지 않습니다.
- [Draft PR #59](https://github.com/zoog136-hash/-/pull/59): 코드 `4911340`의 전체 62/62와 실제 OpenGL 화면 4장 확인 PASS. 상세창/작은 창 스크롤과 자동등록 경로를 보강했습니다. 최신 코드의 [CI 로그·해시](docs/skills/evidence/ci-4911340/manifest.json)와 [실제 화면](docs/skills/previews/README.md)을 보존했습니다.

- 가디언 후속: 서먼 가디언 독립 소환 NPC·명령·HP 조건 SP 보호막·안전 저장/종료·자동사용 연결. 새 Godot 4.7.2 headless 전체 **63/63 PASS**, [로그/해시](docs/skills/evidence/guardian-local/manifest.json). 새 가디언 OpenGL 캡처는 CI 대기, 전체 원작 복원은 미완료. 첨부 a2(1).zip을 포함한 13개 조사 기록 보존.

### PR #59 재개 — 2026-10-10

- 이전 미커밋 턴 언데드 패치·WAV 중간 파일은 찾지 못해 실제 원격 `b69adeb9`에서 재구성했습니다. 기존 브랜치와 가디언 코드·자료는 보존했습니다.
- `3264fec3`: 턴 언데드 기본/에이션트의 실제 시전 마커·투사체·확률 판정·NPC HP/사망 경로. [CI](https://github.com/zoog136-hash/-/actions/runs/38046643647) **64/64 + 실제 OpenGL/가디언 SUCCESS**.
- `bbc08e9a`: 안정 ID 기반 수동/AUTO 슬롯, 이전 생명 대상 투사체 차단, 시전·상태·저항·적중 오디오. [CI](https://github.com/zoog136-hash/-/actions/runs/38047604342) **65/65 + 실제 OpenGL 11장 SUCCESS**. 앞선 가디언 렌더 대기도 이 실행에서 검증됐습니다.
- `f318161d` 후속 수정: HP/MP 갱신 후 직업명 유지, 스킬바 갱신 시 이름 변경 슬롯 보존, 재생성 몬스터의 약화/표식 분리, 면역 대상 상태 AUTO 제외. 로컬 전체 **66/66**, 집중 검사 **10/10**, 실제 보상·드랍·습득·저장 검사 **24개** 및 실제 OpenGL 11장 통과. 새 보상 검사는 로컬 전체 66개 열거 이후 추가되어 별도로 실행했습니다. 이후 정확한 코드 SHA의 [최종 CI](https://github.com/zoog136-hash/-/actions/runs/38048993582)에서 새 검사까지 **67/67 + OpenGL 11장 SUCCESS**를 확인했습니다.
- 현재 조사 배정 695개 / 실행 **125 PARTIAL(63 액티브·62 패시브/강화)** / **568 BLOCKED** / **2 PVP_EXCLUDED**. 원작 전체 완성은 미확인이고 자체 수치는 CUSTOM_BALANCE입니다.
- 최신 main 비교 `1947469b4bd817ffd2b1c9e42ac28c90d154c25b`의 저장 백업 대 창고·제작 복원 충돌은 남겨 두었습니다. PR Draft와 main 미병합을 유지합니다. [재개 파일·함수·명령·실패 기록](docs/skills/PR59_CONTINUATION.md).
