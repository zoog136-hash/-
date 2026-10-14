# main 기준 디버깅 기록 — 2026-10-14

## 기준과 결론

- 기준 main: `a7c0390a698e43fde61ec6deea867143ead59484` (마지막 재확인에서도 동일).
- 작업 브랜치: `validation/main-debug-20261014`. main과 진행 중인 PR #100은 수정하거나 병합하지 않았다.
- 환경: GitHub Actions Ubuntu, Godot `4.7.2.stable.official.ed1daf0bf`; 프레임 렌더가 필요한 검사는 Xvfb + 실제 소프트웨어 OpenGL을 사용했다.
- 이번 커밋은 테스트/CI/검사 기록만 변경한다. 게임 로직, 밸런스, 세이브 형식, 스프라이트, 원본 리소스는 변경하지 않았다.
- 기본 부팅 및 다수의 기존 기능 검사는 통과했다. 아이콘 검사 자체의 오류는 수정·재검증했다. 지역 전수 검사 시간 초과와 실제 외부 원본 팩 검증은 미해결이다. 전체 디버깅 완료 또는 전체 CI 성공으로 보고하지 않는다.

## 1. 변경 전 main 전수 실행

실행 SHA `02a8260118cf8b918b42dd5057ba80304c8a681d`는 기준 main에 검사 workflow만 추가한 상태다.

[전수 실행 및 원본 로그](https://github.com/zoog136-hash/-/actions/runs/38493340415)

| 범위 | 통과 | 실패 | 건너뜀 |
|---|---:|---:|---:|
| 서로 다른 게임 테스트 파일 150개 | 141 | 5 | 4 |
| 각 4개 작업의 임포트·내비게이션 베이크·부팅 (3 × 4) | 12 | 0 | 0 |

미실행 테스트는 없다. Python 도구 문법 검사, 실행기 단위 테스트 23개, 리소스 무결성 검사도 각 작업에서 통과했다. 723개 시트/41,442프레임 무결성 통과를 미전달 원본 전체 복원으로 해석하지 않는다.

전수 실행에는 합성 외부 리소스를 설치하지 않았다. 따라서 외부 어댑터의 테스트 자료 부족과 게임 자체의 실패를 구분해야 한다.

### 실패 5개 분류

| 테스트 | 실제 관찰 | 처리 |
|---|---|---|
| `item_optional_icons_test` | 정상 등록 아이콘 15개를 누락/변조로 오판, 93개 assertion 중 15개 실패 | 테스트의 JSON 숫자 → 파일명 변환 수정 후 통과 |
| `l1j_map_grid_test` | `data/l1j/maps/raw/4.bin` 등 테스트 자료 없음 | 별도 임시 synthetic fixture에서 연결 계약 통과; 실제 원본 팩 검증은 아님 |
| `l1j_png_load_test` | 선택적 외부 아이템/몬스터 PNG 및 registry 없음 | 별도 임시 synthetic fixture에서 통과; 실제 원본 팩 검증은 아님 |
| `l1j_spx_frames_test` | 선택적 외부 SpriteFrames/registry 없음; 빈 JSON 파싱 오류 동반 | 별도 임시 synthetic fixture에서 통과; 실제 원본 팩 검증은 아님 |
| `world_regions_test` | 540.07초에 timeout. `faith_03`까지 23개 지역 완료 표식, 24개 전체 종료 표식 없음 | 미해결. 한도만 올리거나 실패를 무시하지 않음 |

지역 timeout 로그에는 `REGION FAIL` assertion 출력이 없었다. 그렇다고 24개 지역 성공으로 계산하거나 실제 게임이 반드시 멈춘다고 단정하지 않는다. 남은 `faith_04` 및 종료 구간은 이번 전수 로그로 완료를 증명하지 못했다.

### 건너뜀 4개

`source_first_map_test`, `original_world_runtime_test`, `original_map_catalog_test`: 별도 원본 맵 팩 미설치.

`main_debug_failed_load_test`: 첫 audit가 만든 임시 폴더 접두사 `twilight-audit-`를 기존 저장 보호 검사에서 거부했다. 실제 사용자 세이브는 접근하지 않았다. audit를 기존 계약인 `twilight-test-`로 수정했고, 별도 focused 실행에서는 이 테스트가 통과했다. 게임 저장 로직 문제로 집계하지 않는다.

## 2. 수정 내용

### 아이콘 검사 오류

수정 커밋: `b05fd1f07cf44cac99c370a82313d268c0f6c2bf`.

`tests/item_optional_icons_test.gd`는 JSON에서 읽은 `icon_id`를 곧바로 문자열로 만들었다. 그 결과 `7.png` 대신 `7.0.png`와 같은 잘못된 검사 경로가 생겼다. 실제 resolver는 이미 정수로 변환하고 있어서 정상 파일을 로드했다.

검사 측에도 양의 정수 ID 확인과 정수 파일명 변환을 적용했다. resolver가 반환한 경로를 그대로 기대값으로 쓰지 않고 독립적으로 기대 경로를 계산한다. SHA-256 확인, 잘못된 type/slot/sourceId 거부, 기존 catalog 이미지 보호, 누락 시 fallback 검사를 유지했다. assertion을 삭제하지 않았으며 총 검사 수는 93에서 108로 늘었다.

### 재발 방지

`.github/workflows/item-visual-repair-validate.yml`의 PR 경로 조건에 `assets/original_items/inventory/**`를 추가했다. 이 폴더의 PNG만 바뀌는 PR도 기존 이미지 검사를 받게 한다. 기존 권한이나 병합 정책은 변경하지 않았다.

전수 audit는 수동 실행으로 남겨 매번 4개 전체 작업이 불필요하게 재실행되지 않게 했다. focused workflow는 실제 이미지 검사와 합성 외부 어댑터 검사를 명확히 구분한다.

## 3. 수정 후 재검증

실행 SHA: `3463f5b637a80f4f4ea22a46bb4bd87c52ebbbb3`.

[focused 실행 및 로그](https://github.com/zoog136-hash/-/actions/runs/38494522265)

총 13단계(임포트 2회 포함)가 모두 통과했다. 이는 수정된 대상의 focused 검사이며 새 SHA에서 150개 전수를 다시 통과했다는 뜻은 아니다.

| 실제 main 리소스로 검사한 항목 | 결과 |
|---|---|
| 아이콘 15개: 정상 경로/해시/분류/디코딩/fallback 보호 | 108개 assertion 통과 |
| 이미지 파일 1개를 변조한 별도 프로세스 | 변조 거부 및 fallback 검사 108개 통과 |
| 같은 파일을 제거한 별도 프로세스 | 누락 fallback 검사 108개 통과 |
| 원래 바이트 복원 후 검사 | 108개 통과; tracked assets/data 차이 없음 |
| item visual 전체 | 6,445개 assertion 통과 |
| item visual repair | 193개 assertion 통과 |
| item icon art | 31개 assertion 통과 |
| 실패한 저장 로드의 기존 세션 보존 | `MAIN_DEBUG_FAILED_LOAD_OK` |

그 다음에만 별도 CI checkout에 저장소의 작은 합성 테스트 자료를 설치했다. `l1j_map_grid_test`, `l1j_png_load_test`, `l1j_spx_frames_test`가 모두 통과했다. 이 자료를 main이나 PR에 커밋하지 않았고, 원본 아이템/몬스터/맵 전달 실적으로 계산하지 않았다.

## 4. 남은 작업과 정확한 재개 지점

가장 우선적인 미해결 검사는 `tests/world_regions_test.gd`의 540초 timeout이다. 기존 `--prefix=` 선택 기능으로 지역군을 분리하고, `_set_map`, 경로/스폰 검사, 실제 이동, `_save_game`/`_load_game`, 아덴 복귀 단계별 시간을 계측해 누적 비용과 특정 지역 병목을 구분해야 한다. 24개 맵/5개 지역군 및 저장·물리·전투 assertion은 유지해야 한다. 현재 로그에는 단계별 시간 정보가 없어 원인을 확정하지 않았다.

Android 빌드/실기기 실행, PC 실제 GPU 성능, 모든 개체의 8방향 화면/접지/공격 프레임은 이번 검사만으로 승인할 수 없다. 실제 원본 맵·외부 PNG·SPX 팩도 별도 설치와 해시/실행 검증이 필요하다. 현재 대화의 원본 ZIP을 게임에 추가하거나 진행 중인 PR #100을 이 검사에 섞지 않았다.

## 증거 보존

전수 artifact ID: `11862678554` (shard 0), `11862873401` (shard 1), `11863298255` (shard 2), `11863351419` (shard 3).

focused artifact ID: `11863522999`.

GitHub artifact 보존 기간은 7일이다. 사용자 전달 ZIP에는 전수/후속 원본 텍스트 로그, 150개 상세 결과, 최소 수정 patch를 함께 보관한다. 엔진 바이너리, 폰트, 원본 이미지 또는 사용자 세이브는 포함하지 않는다.
