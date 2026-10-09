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

마지막 수동 갱신: 2026-10-09.
