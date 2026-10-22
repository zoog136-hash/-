# main 전체 CI 실패 후속 수정 — 2026-10-22

## 정확한 기준

- 감사한 main: `88b1773f90e9d5cc092d9423ef9e80407b102bf5`.
- 전체 실행기: run `39598152327`; 실제 자식 검사 55개: 39 success / 14 failure / 2 cancelled.
- 기존 PR #144: `f373673736771e156ae40c868feeed8943b84a87`의 25개 PR 검사는 통과했으나 main에는 미병합이다.
- 이번 변경은 위 PR의 상점/보스 검사 수정을 보존하고, main의 수동 실행 설정 여섯 파일을 함께 보존한다. main, PR #122, PR #143은 직접 변경하지 않는다.

## 직접 확인한 증거와 원인

1. Integration `39602594641`의 artifact `12354114042`에는 249개 중 237 PASS / 11 기존 선택 SKIP / 1 FAIL이 기록돼 있다. 실패는 `l1j_reviewed_shop_test`: PR #141에서 확장한 재고를 과거 총 20개라고 검사하던 두 조건이다. 기존 #144의 독립 legacy 가격 및 전체 재고 불변성 검사를 그대로 유지한다.
2. Main Debug Audit `39602528689`의 네 shard artifact `12351319103`, `12355160724`, `12354630138`, `12354238680`를 확인했다. 독립 복사한 실행 루프가 정식 `test_project.py`의 legacy geometry 옵션, renderer 선택 규칙, temporal 격리/보고 환경, world-region child sharding을 누락했다. 고정 지형 검사가 설치된 PNG를 옛 prop 구조로 읽는 오류 및 잘못 실행된 temporal 검사들이 발생했다.
3. Inventory `39602491564`/artifact `12348643540`, Ground matte `39602470380`/artifact `12348270185`는 자산 import 240초 제한에서 중단됐다. 해당 import의 로그/시간 제한을 보완한다. 무제한 대기는 허용하지 않는다.
4. Ground Alpha `39602463704`/artifact `12347854578`, Ground Category `39602466792`/artifact `12347388182`는 다른 동작 검사들이 통과했지만 실제 캡처에서 drop failed가 발생했다. 두 캡처가 옛 좌표 `(3550,4300)`를 그대로 사용했다. 현재 native PNG 바닥에서 완전한 12개 격자를 찾도록 수정한다.
5. 취소된 AUTO `39602408265`는 import 단계, Item Codex `39602496042`는 기존 전체 회귀 단계에서 중단됐다. 각각 전체 job 제한 15/20분이었다. 시간과 renderer 준비/파이프 오류 전파/로그 보존을 보완하되 기존 8회 AUTO 및 전체 회귀를 줄이지 않는다. 취소 원인 전부를 게임 오류라고 단정하지 않는다.

다른 몬스터 AI/맵/전투/스킬/새 배치/몬스터 월드/L1J workflow도 전체 회귀 단계에서 실패한 것을 확인했다. 위 대표 Integration artifact의 공통 원인을 수정하지만, 모든 workflow의 후속 단계까지 이미 정상이라고 추정하지 않는다. 새 커밋으로 각각 재검증해야 한다.

## 수정 범위

- 정식 `tools/test_project.py`에 누락 없는 shard 선택과 `--no-ci-synthetic-fixtures` 옵션을 추가했다. 기본 실행 및 기존 legacy 목록/timeout/판정은 그대로다. 새 감사는 해당 정식 실행기를 사용하며 테스트를 임의로 legacy 목록에 추가하지 않는다.
- 각 shard는 import/navigation/boot를 모두 실행하고, 정렬된 전체 runtime 테스트를 정확히 한 번씩 나눠 실행한다. 시작/각 검사 후 summary를 기록해 중단된 테스트를 성공으로 오인하지 않는다. 비공개 리소스 선택 SKIP은 기존처럼 별도 집계한다.
- 바닥 캡처는 실제 설치 맵의 유효 floor/LOS/포털 조건을 만족하는 12개 배치를 찾는다. 드롭은 원래 loot manager로 생성하고 전체 샘플을 유지하며, 찾지 못하면 명시적으로 실패한다. 맵이나 드롭 규칙은 변경하지 않는다.
- Inventory/matte import를 900초로 제한하고 필요한 workflow 총 시간을 조정했다. AUTO의 import/각 회차에도 명시적 제한 및 오류 로그 검사를 추가했다.
- Item Codex에 전체 회귀가 요구하는 software OpenGL을 준비하고 pipefail 및 전체 테스트 로그 보존을 추가했다.

## 검증 구분

- 정식 실행기 선택/환경/실패 보존의 새 Python 회귀 **29개 PASS**. controlled executable을 이용한 실행기 검증이지 Godot 모사 성공이 아니다.
- 변경 Python AST 및 변경 workflow 5개의 YAML/내장 shell 구문 검사 PASS.
- 원본 복사와 runner/support/unit-test 업로드는 Git blob SHA로 확인했다.
- 로컬 Godot/GDScript 실행, 실제 OpenGL, Android 실기: **NOT_RUN**. 새 커밋의 실제 GitHub Actions가 판단 근거다.
- 게임 스크립트, 아이템/몹 수치, 맵/그림 리소스, 사용자 저장 데이터는 이번 수정 범위에 없다. CI 성공 전 main 병합을 완료로 보고하지 않는다.
