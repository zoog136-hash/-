# Main 및 열린 PR CI 복구 — 2026-10-24

기준 main: `e0a14f07da7764598822be669d05b3c2985d13eb`.

## 확인한 문제

[main Integration 39957518319](https://github.com/zoog136-hash/-/actions/runs/39957518319)는 총 258개 중 244개 통과, 11개 명시적 건너뜀, 3개 실패였다. 전체 회귀 단계는 약 93분 걸렸으며, 120분 job 제한으로 중단된 경우가 아니다. 실패 뒤 실제 렌더 검증 단계들은 실행되지 않았다.

| 실패 | 원인 | 변경 |
|---|---|---|
| `aden_faith_png_monster_spawns_test` | 5개 맵·9개 보스의 실제 시간 기반 생애 주기를 150초 안에 끝내지 못함 | 이 검사에만 300초 수행 한도 적용. 검사와 게임 시간은 유지. |
| `hunting_paths_test` | 셀 중심만 연결한 길이 실제 장애물/바닥 모서리를 통과하고, 검수 좌표 세 곳에 작은 불일치가 있음 | 실제 발 판정을 통과한 연결선으로 보완하고 제한된 검수 데이터 교정 적용. 25맵 검사에 300초 수행 한도. |
| `remake_door_runtime_test` | PNG 청크에서 닫힌 문 경계가 그려지지 않음 | 기존 충돌/내비게이션과 같은 문 상태로 PNG 위 경계 표시. |

경로와 문 수정의 근거, 정확한 범위, 원본 및 저장 호환성 검증은 [MAP_PATH_RECOVERY.md](MAP_PATH_RECOVERY.md)와 [map-path-recovery.json](map-path-recovery.json)에 기록했다. 아덴·신념 배율, 기능 PR의 게임 동작 및 원본 이미지 파일을 이 복구안에서 변경하지 않는다.

## CI 실행량과 오래된 실행 정리

- 기존 PR 자동 검사 워크플로 38개에 브랜치/PR 및 이벤트별 `concurrency`를 추가했다. 새 자동 실행은 같은 그룹의 오래된 실행을 취소한다. 수동 `workflow_dispatch`는 `run_id`로 구분해 독립 실행한다.
- `consumable-validate`의 push를 main으로 제한하여 기능 브랜치 push와 PR 검사의 중복을 줄였다.
- 아래 8개 워크플로의 PR 이벤트는 담당 영역 검사만 실행한다. 공통 import, navigation bake, 실제 부팅과 각 워크플로 고유의 렌더/증거 단계는 유지한다.
- Integration과 L1J Linux/Windows는 계속 **필터 없는 전체 검사**를 실행한다. 새 회귀 검사 1개를 포함하면 main 기준 계획은 준비 3개 + GDScript 검사 256개다. 수동 실행과 별도 기능 브랜치 push의 전체 검사도 유지한다.

| PR 전용 범위 조정 | 준비 단계 포함 검사 수 |
|---|---:|
| Combat Animation | 19 |
| Combat Resolution | 15 |
| Monster World | 20 |
| Renewed Map Spawns | 16 |
| 25 Map Visual Styles | 18 |
| Monster AI | 15 |
| Original Skills | 22 |
| Item Icon Art | 11 |

Monster World의 기존 증거 게시 브랜치는 전체 검사 계약을 유지한다. 정확한 검사 이름을 기존 fail-closed 선택기에 전달하므로 오탈자가 검사를 조용히 생략하지 않는다. `continue-on-error`, 성공 기준, 오류 탐지, 권한은 완화하지 않는다.

2026-10-24 **14:53:12 KST** 재조회에서 이전 PR HEAD의 자동 실행은 0개였다. 이번 정리에서 취소한 **179개**는 모두 API에서 `completed/cancelled`를 확인했다. 당시 최신 PR HEAD, main, 수동 실행은 보존했다. 이 숫자는 그 시점의 정리 결과이며 이후 새 HEAD가 생성되면 다시 판단해야 한다. [stale-ci-cancellation.json](stale-ci-cancellation.json)에 실행 ID와 확인 상태를 기록했다.

## 로컬 검증

공식 Godot `4.7.2.stable.official.ed1daf0bf`, 최종 asset import 후 격리된 저장 디렉터리에서 실행했다. 아래 실제 실행은 모두 종료 코드 0, 엔진 오류 0이며 시작/종료 소스 SHA가 일치했다.

| 검사 | 결과 |
|---|---|
| 아덴·신념 실제 몬스터/보스/이동 | 1,261개 통과, 170.226초 |
| 전체 사냥 경로 | 25맵, 10,666개 통과, 123.904초 |
| 실제 문 개폐 | 14개 통과, 9.490초 |
| 신규 경로·격자·저장 호환 회귀 | 1,554개 통과 |
| 아덴·신념 저장 마이그레이션 | 부모 156개 + legacy 자식 6개씩 2회 통과, 34.548초 |
| Native PNG 카탈로그·원본 plan·저장 SHA | 53개 통과, 0.390초 |
| 검사 계획/runner 계약 | 29개 + 27개 통과 |
| Python native PNG / renewed spawn | 12개 + 10개 통과 |
| 전체 워크플로 | 74개 YAML 구문/중복 키 검사, actionlint 1.7.12 통과 |
| 리소스 무결성 | 723개 atlas, 41,442개 frame, 233,420,026바이트 일치 |

초기 환경 준비 시 PNG import 누락 오류가 있던 실행은 최종 통과 집계에서 제외했다. 제한 시간을 바꾸기 전 아덴·신념 검사는 150.073초에 실제 시간 초과를 재현했다. 최종 170.226초 완주로 검사 삭제 없이 시간 한도 수정의 근거를 확인했다.

위 runtime 실행 뒤 `test_project_support.py`에 사냥 경로 검사의 300초 한도만 추가했다. 게임/검사 소스는 그대로이며, 그 최종 runner 파일로 계획·runner 계약 56개를 다시 통과했다. `local-validation.json`은 실행 당시 SHA와 이 후속 변경의 최종 SHA를 구분한다.

이 로컬 표는 GitHub의 새 전체 CI 성공을 대신하지 않는다. 통합 PR의 최종 commit에 연결된 전체 검사 및 실제 렌더 결과가 모두 확인되어야 main 병합 여부를 판단할 수 있다. 기존 main은 필수 status check가 확인되지 않았으므로 mergeable 또는 빈 legacy status를 CI 성공으로 간주하지 않는다.

## 기존 PR에 반영할 때 지킬 사항

- #122의 XDG 격리/temporal fixture 및 별도 애니메이션 검사 워크플로를 보존한다.
- #152/#153에 이미 있는 PNG 검사 3개의 300초 한도와 문 표시 수정을 유지한다. #152의 전역 body-clear 셀 제거 및 대각선 금지 블록은 경로/스폰을 끊으므로 이번 정확한 연결선 보완으로 교체한다.
- #153의 Pillow 설치와 `verify_authored_vfx.py --require-tracked` 단계를 유지한다.
- #155의 경로 프로파일링, 신념 배율, floor/alpha 생성 최적화는 유지하면서 경로 함수를 병합한다.
- 공통 파일은 3-way로 통합하고, PR 고유의 파일·생성·검증 단계·이력을 보존한다. 새 HEAD 확인 없이 브랜치를 갱신하거나 force push하지 않는다.

코드 리뷰에서 현재 main 기준 차단할 결함은 발견하지 못했다. 경로 그래프의 첫 요청은 약 313ms, 27개 목적지 조회 후 엔진 static 할당은 약 20.86MiB였으며, 대표 반복 경로는 평균 1.49ms였다. Android FPS나 최대 메모리 보장은 아니다. 원본 리소스 전체 통합 여부는 기존 리소스 장부의 별도 상태를 따른다.
