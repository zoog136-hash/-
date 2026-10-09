# PR #43 재개 코드의 새 GitHub Actions

게임 코드 HEAD: `98c9e5f693df280f1543a6c21133095eed9a4812`.

검사 checkout: `65b8879f217cb03f4fb83e2ffb7ed6c8b72e1db7`; tree: `dcafd584c3a3af57248cda41476614485d4eb47d`. 코드 HEAD와 PR 검사 checkout의 tree가 같습니다.

최신 main: `5596a6415269975e985954ee6249ac15f28fac02`. PR #46·#48과 작업 중 추가된 PR #49를 기존 작업 브랜치에 통합했고, main을 수정하지 않았습니다.

아래는 위 코드에서 새로 실행한 **PR 검사 11개와 push 검사 1개, 총 12회 성공**입니다. 이후 증거·문서만 추가하며 이 문서 커밋을 다시 실행한 게임 검사로 주장하지 않습니다.

| 워크플로 | 트리거 | 결과 | 실제 실행 |
| --- | --- | --- | --- |
| Twilight Skill Mechanism | pull_request | success | [37918100042](https://github.com/zoog136-hash/-/actions/runs/37918100042) |
| Twilight Consumable Integration | pull_request | success | [37918099999](https://github.com/zoog136-hash/-/actions/runs/37918099999) |
| Twilight Item Options Runtime | pull_request | success | [37918100025](https://github.com/zoog136-hash/-/actions/runs/37918100025) |
| Ground Loot Validate | pull_request | success | [37918099946](https://github.com/zoog136-hash/-/actions/runs/37918099946) |
| Twilight Catalog Effects Validation | pull_request | success | [37918099872](https://github.com/zoog136-hash/-/actions/runs/37918099872) |
| UI Renewal Validate | pull_request | success | [37918100079](https://github.com/zoog136-hash/-/actions/runs/37918100079) |
| Godot Validate | pull_request | success | [37918100056](https://github.com/zoog136-hash/-/actions/runs/37918100056) |
| Item Codex Art Validate | pull_request | success | [37918100034](https://github.com/zoog136-hash/-/actions/runs/37918100034) |
| Monster World Validate | pull_request | success | [37918099919](https://github.com/zoog136-hash/-/actions/runs/37918099919) |
| TWILIGHT Integration Validate | pull_request | success | [37918099876](https://github.com/zoog136-hash/-/actions/runs/37918099876) |
| Combat Animation Validate | pull_request | success | [37918099871](https://github.com/zoog136-hash/-/actions/runs/37918099871) |
| Monster World Validate | push | success | [37918090445](https://github.com/zoog136-hash/-/actions/runs/37918090445) |

Monster World Validate: 전체 회귀 **53/53**, 전투 HUD **1,200항목**, 몬스터 월드 **9,323항목** 및 공격 프로필 **48항목** 통과. 실제 Compatibility OpenGL에서 25개 맵, 4곳 폭젠 AUTO 처치 후 24마리 재출현, 오만 보스 10종, 318종의 5상태, 32/96/192마리 양방향 전투를 새로 실행했습니다. PNG 106장과 전체 로그는 [artifact](https://github.com/zoog136-hash/-/actions/runs/37918099919/artifacts/11610324668)에 있습니다.

UI Renewal Validate도 같은 코드에서 **57개 UI 검사와 클래스 선택을 포함한 실제 OpenGL 72화면**을 실행했습니다. [실제 UI job 로그](logs/github-actions-ui-renewal.txt), [실제 몬스터 job 로그](logs/github-actions-monster-world.txt), [53개 검사 요약](logs/summary.json)을 보존합니다.

## 실패 실행과 수정

보완 코드 `fb05437`의 [PR 실행 37916677807](https://github.com/zoog136-hash/-/actions/runs/37916677807)은 전체 회귀 뒤 실제 폭젠 검사에서 실패했습니다. 삭제 예약 시체가 마지막 물리 콜백으로 풀에 들어간 뒤 해제되어 `FieldPopulation._spawn_slot`에 유효하지 않은 참조가 남았습니다. 성공 결과로 재사용하지 않습니다.

최종 코드 `98c9e5f`는 삭제 예약 노드의 반환을 거부하고 중복 반환을 멱등 처리하며, 스폰 시 해제·삭제 예약 풀 항목을 건너뜁니다. 실제 시체 정리 경계를 재현하는 검사 3개와 새 OpenGL 폭젠 검사로 검증했습니다.

## 변경 전후 HUD 비교

[같은 러너 비교 JSON](logs/hud-comparison.json)은 PR #46·#48 통합 후 HUD 최적화 전 `1b53a3ea56ef61bd69af5d2b1649ac325b52ca33`을 기준으로, 같은 192회 실제 근접·원거리·마법 입력을 32프레임에 나누어 실행합니다. 실제 남은 HP 16,078과 표시 상한 20,000이 같았습니다. HP만 변하는 입력의 전체 HUD 2→0회, 장비 동기화 4→0회, 능력치 스냅샷 2→0회, 표시 상한 재조회 110→0회입니다. 이는 제어한 HUD 경로의 비교이며 전체 GPU 프레임/FPS 측정이 아닙니다.

| 캐릭터 창 | 월드 갱신 함수 p95 변경 전 ms | 변경 후 ms |
| --- | --- | --- |
| 닫힘 | 40.532 | 0.066 |
| 열림 | 39.588 | 0.082 |

실제 군집에서 스탯 발동·버프 만료 등 필요한 전체 갱신은 계속 수행합니다. 32/96/192마리의 전체 갱신 4/7/14회는 일반 HP 피격당 재계산과 구별합니다. [전체 군집 성능과 한계](VALIDATION.md)를 함께 확인하세요.

최신 main을 feature 브랜치가 포함하며 GitHub PR #43의 병합 충돌이 없습니다. Draft를 유지하고 사용자 승인 없이 main에 병합하지 않았습니다.
