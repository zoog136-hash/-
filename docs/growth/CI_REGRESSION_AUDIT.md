# PR154 CI 실패 귀속과 저장 스키마 수정 — 2026-10-24

대상 HEAD는 `5a1457fb500b8d6f8754e6f90b82e4465f4dfd77`, 비교 main은 `e0a14f07da7764598822be669d05b3c2985d13eb`이다. 조사 시작 시 원격 main도 동일했다. CI 임시 병합 `2b4f11f10fc5ff777064b2ed892bccfb60f630c6`의 부모는 이 두 커밋이며, 파일 트리 `a45e3249d50e6952fe0851a1dfff0f14dd69155c`는 대상 HEAD와 같았다.

**이 표와 맵 비교는 이전 실패 HEAD `5a1457fb`의 귀속 조사다.** 이후 별도 CI 복구가 합쳐진 `163319a1`의 맵 합격/실패를 뜻하지 않는다. 최신 통합 대응은 아래 별도 기록을 참조한다.

## 귀속 결과

| 실패 | 판정 | 근거 / 처리 |
|---|---|---|
| `native-collections`: `growth` missing known key | **PR154의 누락, 수정함** | World가 저장하는 새 `growth`를 컬렉션 런타임의 `KNOWN_SAVE_KEYS`에 누락했다. 실제 알려진 키 목록에만 추가했다. 기존 데이터 감사의 `keys == known` 엄격 비교와 모든 데이터/트랜잭션 검사를 유지했다. |
| `aden_faith_png_monster_spawns_test` 150초 | **기반 main에서도 재현** | 같은 엔진/PNG 팩/CI 합성 fixture 준비와 원래 150초 제한으로 main에서도 시간 초과. CI와 로컬의 진행 지점은 다르며 상대 성능 비교나 완전한 같은 실행 시간이라는 뜻은 아니다. |
| `aden_faith_png_runtime_test` 150초 | **기반 main에서도 재현** | 실제 OpenGL/llvmpipe와 같은 팩/원래 제한으로 main에서도 시간 초과. 테스트나 제한을 변경하지 않았다. |
| `hunting_paths_test` 연결·벽 모서리 실패 92건 | **기반 main의 같은 실패 패턴** | main 전체 검사는 150초에 중단되어 완료로 집계하지 않는다. 그 안에서 지배의 탑 2건을 확인했다. 에스카로스 5개 실제 게임 ID만 기존 검사 함수를 그대로 호출하여 4,645개 검사/90건 실패를 재현했다. 합친 92건은 CI의 실패 문자열 및 중복 개수까지 정확히 일치한다. |
| 추가 `ordinary-game` exit 127 | **변경되지 않은 워크플로 환경 문제** | `rg: command not found`. Aden scale 50개 성공 뒤 양의 rg 검사에서 중단했다. 이후 ownership/autoload 검증은 실행 완료로 주장하지 않는다. 해당 workflow는 main과 동일하고 이 PR에서 수정하지 않는다. |

CI 원문: [맵 실패](https://github.com/zoog136-hash/-/actions/runs/40060695450/job/120773332515), [저장 키 실패](https://github.com/zoog136-hash/-/actions/runs/40060695492/job/120773332684), [도구 누락](https://github.com/zoog136-hash/-/actions/runs/40060695340/job/120773332118). 첨부 ZIP 다운로드는 HTTP 403으로 실패하여 재시도하지 않았으며, 조회에 성공한 job 로그의 실제 실패 출력과 로컬 비교 결과를 보존했다.

## 저장 키 수정의 의미와 검증

`growth`는 World가 소유하고 `growth_runtime.validate()`가 검사하는 schema 1의 최상위 저장 필드다. 포인트/문양/노드/대표/선택 대기/실패 이력/리비전을 포함한다. 로드는 컬렉션 상태를 받기 전에 성장 스키마를 검사하며, 누락된 구버전 필드는 빈 성장 상태로 읽고 지원하지 않는 버전은 저장을 보호한다.

컬렉션 런타임은 알려진 World 필드를 `extra_save_fields`에서 제외하고 진짜 미지 확장만 보존한다. `growth`도 이 목록에 속하므로 누락된 항목을 추가하는 것이 올바른 수정이다. 감사 도구를 완화하거나 임의 키를 허용하지 않았다. 수정 전 동일 assertion을 로컬 재현했고 수정 후 기존 감사가 54개 저장 키, 447개 컬렉션/1,659개 요구 슬롯 검사를 통과했다.

실제 Main 테스트를 확장하여 성장 거래를 먼저 저장한 뒤 컬렉션 등록/저장/로드에서 전체 성장 상태가 보존되고 미지 확장으로 오분류되지 않는지 확인했다. 미래 growth 버전을 읽으면 컬렉션 등록/자동 저장이 막히며 기존 데이터가 유지된다. growth가 없는 과거 컬렉션 저장도 컬렉션 진행을 잃지 않고 빈 성장으로 읽는다. 기존의 미지 확장 보존 검사도 유지했다.

집중 검사 **4/4 PASS**: 컬렉션 바인딩 **3,274**, 컬렉션 런타임 **88**, 컬렉션 스탯 **86**, 성장 거래/저장/터치 **104** assertions. 사용자 저장과 분리된 runner 디렉터리에서 실행했다. 맵 시간 비교와 동시에 돌리지 않았다. 전체 CI나 모든 테스트를 반복 실행하거나 성공 처리하지 않았다.

## 기반 비교 방법과 한계

별도 detached worktree `/workspace/pr154-ci-base`를 위 main SHA로 만들었다. `scripts/maps`, `data/maps`, `external_map_packs`, `scripts/player.gd` Git 객체와 World `_set_map`/`_set_click_destination` 함수는 PR154와 동일하다. 실패 테스트·기존 검사 함수·runner·해당 맵 workflow 10개 파일의 바이트 해시도 같다.

Godot 4.7.2, `GITHUB_ACTIONS=true`, 저장 격리, CI가 사용하는 두 PNG 팩 경로, DISPLAY=:97/llvmpipe, 원래 150초 제한으로 실패한 세 테스트만 실행했다. 준비 단계로 기반 checkout을 import했다. 로컬 CPU/OS/Mesa는 GitHub runner와 다르므로 시간 초과는 기반에서도 이 제한을 넘는다는 증거이며 성장 변경의 미세한 성능 차이를 측정한 결과가 아니다.

전체 hunting은 로컬에서 시간 초과되어, 남은 실패 영역은 `native_png_route_checks.gd.run()`의 원래 검사를 에스카로스 01~05에 호출한 좁은 wrapper로 확인했다. 실제 active map과 그림 map ID가 맞는지도 검사했다. 미술 ID `escaros_world`를 직접 진입시킨 초기 진단은 실제 맵이 Aden에 남았으므로 비교 근거에서 제외했다. 유효한 비교는 게임 ID 01~05를 확인한 결과만 사용한다. 시간 제한/단언/기준은 바꾸지 않았다.

`map-comparison.json`의 `exact_failure_multiset_matches_ci: true`가 동일 실패의 문자열·중복 횟수 비교다. 이것은 전체 7,115개 main 검사를 완료했다는 의미가 아니다. [PR152의 기존 비교 기록](https://github.com/zoog136-hash/-/blob/1cf5f19aa36eceef4251d0d00b1e34f6c242e59b/docs/option-awakening-20261023/hunting_baseline_comparison.json)도 같은 main에서 실패 92건을 별도로 기록하고 있다.

## 의존성과 남은 확인

통행 보정은 [PR152](https://github.com/zoog136-hash/-/pull/152), 맵·성능 개선은 [PR155](https://github.com/zoog136-hash/-/pull/155)의 별도 범위다. PR152가 해당 ordinary-game workflow도 다루므로 도구 설치 정합성도 그 작업과 확인해야 한다. 두 PR의 코드를 복제하거나 여기서 맵/충돌/runner 시간 제한을 수정하지 않았다. 이들 변경이 실제로 모든 실패를 해결한다는 검증도 수행하지 않았다.

의존 변경 통합 후 원래 public-code-regression 및 ordinary-game 실행이 필요하다. 이번 PR의 귀속되는 저장 키 누락만 수정했다. 새 HEAD의 원격 CI 결과는 별도 확인해야 하며, 기존 지도 실패를 성공으로 간주하거나 main에 병합하지 않는다.


## 조사 중 원격 HEAD 변경 대응

원격이 `163319a1b244bd0a79594a449c477e02b100fa9e`로 바뀐 것을 확인하고, 로컬 수정/조사 파일을 stash `8b8e1f38d9a04381a9497089f42636049f8df9d1`에 보존한 뒤 새 원격 커밋을 fast-forward로 받았다. 이 커밋은 별도 CI 복구 `b7c4cd2b`를 포함하며 맵 경로 보정·renderer·workflow·일부 검사 시간 예산 변경을 포함한다. 해당 변경은 그대로 보존하고 우리 수정으로 복제/재작성하지 않았다. main은 건드리지 않았다.

최신 원격의 컬렉션 `KNOWN_SAVE_KEYS`에는 여전히 growth가 없었고 해당 런타임 테스트도 변경되지 않았으므로, 저장 키 한 줄과 새 호환성 검사만 다시 적용했다. 맵/워크플로/timeout 파일은 이 후속 커밋에서 수정하지 않는다. 위 원래 150초 비교는 고정된 옛 main/HEAD 대상이며, 상속받은 CI 복구의 새 예산과 혼동하면 안 된다.

별도 복구의 맵 결과는 [기존 CI 복구 보고서](../ci-recovery-20261024/README.md)를 참조한다. 우리 귀속 실험만으로 최신 맵 복구가 원격에서 통과했다고 주장하지 않는다. 최신 기준에서는 정적 54개 키 감사와 컬렉션/성장 실제 Main 호환성 검사만 재확인한다.

최신 `163319a1` 위 재검증 결과: 엄격한 54개 키 감사 PASS, 실제 Main 컬렉션 런타임 **88** 및 성장 저장·터치 **104** assertions, 두 검사 **2/2 PASS**. 순수 컬렉션 바인딩/스탯 코드는 새 원격에서 변경되지 않아 앞선 3,274/86 검사 결과를 재사용하고 반복하지 않았다. 증거는 `latest-*` 파일이다.

## 후속 cae446ce item-options 실패

새 ground_drop_smoke_test 7건은 앞선 main 지도 실패와 별개다. main 원본 검사는 통과했고, 편입된 한 도착점 경로를 검사 좌표 선택기가 거부해 벽 모서리로 플레이어를 옮긴 테스트 호환성 문제였다. 생산 줍기·맵 코드를 바꾸지 않고 기존 25개 단언을 유지하며 좌표 유효성 단언 3개를 추가했다. [원인·수정·최소 비교](CI_GROUND_DROP_RECHECK.md).
