# 검증 결과와 제한

검증 엔진: Godot `4.7.2.stable.official.ed1daf0bf`. 원격 main `434b904d957fd2146b6d2e73325693a402028035`의 별도 worktree와 동일 엔진으로 비교했다. 모든 테스트의 저장 폴더는 분리했다.

| 검사 | 결과/근거 |
|---|---|
| 수정 전/후 필수 리소스 무결성 | 성공. Git 추적된 WebP 723개, 41,442프레임, 233,420,026바이트. 외부 원본 전체 전달을 뜻하지 않음 |
| 2,129개 카탈로그·485개 legacy·2,576개 runtime 로딩 | 성공. 누락 경로/PNG 디코드/완전 투명 이미지/원본 추출 해시/게임 데이터 변경 오류 0 |
| 원본 웹 신원 파서 | 6개 성공. 잘못된 ID·이름·이미지, 주변 텍스트만 일치하는 페이지, 다른 도메인 URL을 검증 성공으로 처리하지 않음 |
| 공통 이미지·효과 검사 | 6,445회 성공. sourceId/같은 이름의 별도 레코드/원본 픽셀/읽기 전용/숨김·클립/반복 갱신/노드 해제 |
| 실제 OpenGL 셰이더 검사 | 성공. 대각선 방향, 기본 밝기 보존, 전설 강도, 신화 폭, 유일 광채, 고정 UI 변환 |
| 연속 캡처 | 실제 화면 16장 + 검증 보드 64프레임. 낮은 3등급 변화 0px, 모든 등급 배지 변화 0px |
| 원본 픽셀 smoke | 31개 성공 |
| UI 장비 인스턴스 | 19개 성공 |
| UI fidelity / native touch 통합 | 각각 88개 / 62개 성공 |
| L1J 실제 게임 통합 재검사 | 85개 성공. sourceId PNG 우선, 별도 L1J 파일 로딩, 바닥 드랍/수동·자동 습득, 물리적 장비 ID/강화/저장, 전투 경로 유지 |

로그는 [checks](evidence/checks/), 파일 SHA/크기는 [artifact-sha256.json](evidence/artifact-sha256.json)에 있다. 이미지와 실행 로그를 실제로 커밋했는지 마지막 단계에서 Git 추적 및 해시를 다시 검사한다.

## 전체 프로젝트 회귀

기준 main 전체 실행은 **139개 중 123 통과, 13 실패, 3 건너뜀, 미실행 0**이다. `_OK` 문자열뿐 아니라 오류와 구조화된 실패 목록도 확인했다. 기준 main과 feature의 원시 로그를 보존하며, 이후 개별 재검사를 전체 재실행처럼 표시하지 않는다.

이번 변경으로 드러난 `l1j_runtime_game_test`의 5개 이미지 경로 assertion은 이전 L1J 우선 정책을 가정했다. sourceId PNG가 UI에 우선 표시되고 기존 검증 L1J 파일은 여전히 독립적으로 로딩되는지 두 조건으로 갱신했다. 기존 80개 검사에서 85개로 늘었으며 실제 저장·강화·습득·전투 검사는 제거하지 않았다. 갱신 후 85개 모두 성공했다.

| main에서도 확인된 실패/환경 제한 | 확인 내용 |
|---|---|
| `hunting_navigation_cache_test` | 25개 checked source cache 미존재 |
| `l1j_map_grid_test`, `l1j_png_load_test`, `l1j_spx_frames_test` | 현재 환경에 원본 팩/선택적 fixture가 없어 실제 원본 파일 검사 실패. 합성 fixture를 원본으로 만들어 통과시키지 않음 |
| `lineagem_ui_visual_smoke_test` | 기존 메뉴 navigation assertion |
| `monster_world_test`, `renewed_map_spawn_test` | 기존 boss 스킬/respawn/dense cap assertion |
| `original_turn_undead_rewards_test` | 기존 `quest_kills` int 대입 오류 후 시간 초과 |
| `skill_mechanism_smoke_test` | 기존 stun cooldown assertion |
| `ui_pointer_transfer_test` | 기존 `낡은 장검@@@1` Dictionary 접근 오류. 앞부분 33회만 지나간 결과를 전체 성공으로 계산하지 않음 |
| `world_regions_test`, `world_structure_test` | 기존 지역 레벨 assertion 및 `map_id` Dictionary 접근 오류 |

main의 `ground_loot_system_test`는 150초 시간 초과였고 feature에서는 성공했다. 이를 별도의 바닥 로직 버그 수정이나 성능 향상 증거라고 주장하지 않는다. 3개의 원본 맵 검사는 원본 미설치로 명시적으로 건너뛰었다.

`world_regions_test`는 양쪽 모두 24맵·6,036회를 끝까지 검사했지만 지역 레벨 assertion에서 main 67회, feature 75회 실패했다. 추가 지역도 같은 레벨 assertion이다. 두 실행의 소요시간은 약 126초/414초로 달랐다. 전투·맵 소스는 변경되지 않았으나 이 전체 장면 시간 차이의 원인을 분리하지 못했으므로 성능 개선 또는 전역 회귀 없음의 증거로 사용하지 않는다. 아래 아이콘 측정은 다른 Godot 프로세스가 종료된 후 별도로 수행한다.

첫 baseline import는 쓰기 불가능한 기본 설정 폴더로 실패했다. 쓰기 가능한 XDG 경로를 지정하고 완전 재실행했다. 처음 시도한 feature import의 로컬 소켓 제한도 실행 환경 설정 후 해결하고 재실행했다. 이 준비 실패를 게임 코드의 회귀로 집계하지 않는다.

feature 전체 초회 실행은 **140개 중 124 통과, 13 실패, 3 건너뜀, 미실행 0**이다. 위 L1J 정책 assertion을 갱신해 별도로 재검사한 뒤 남은 실패 테스트 12개는 모두 main에서도 실패한 이름이다. 전체를 다시 140개 실행한 것은 아니다. 이후 추가한 실제 픽셀 렌더 검사는 이 140개 수집과 별도로 성공했다. [비교 JSON](evidence/regression.json)과 [양쪽 전체 원시 로그](evidence/regression-logs.tar.gz)를 보존했다. 테스트 이름 수준의 신규 실패는 남지 않았지만, 맵 순회 시간 증가와 기존 실패가 있어 전체 회귀 통과라고 표시하지 않는다.

## CI

같은 Draft PR에 `.github/workflows/item-visuals-validate.yml`을 추가했다. Godot 4.7.2 import → 신원/저장/UI 검사 → 실제 runtime 전수 감사 → Xvfb Compatibility 픽셀 검사/캡처/부하 측정 → artifact 보관을 실행한다.

확인 시점의 [구현 커밋 CI](https://github.com/zoog136-hash/-/actions/runs/38258203980)는 GitHub runner 실행 대기 상태이며 완료/성공을 확인하지 못했다. 후속 푸시의 최신 실행 번호와 상태는 PR 설명에 갱신한다. 기존 전역 회귀 실패와 CI 실행 대기를 이유로 Draft를 유지하며 main에 병합하지 않는다.

## 성능 측정 범위

`benchmark_item_visuals.gd`는 기존 PNG 64종을 사용하는 600개 아이콘 중 300개를 화면에, 300개를 화면 밖에 둔다. 동일 배치를 정적 목록과 4등급 균등 애니메이션으로 비교한다. 각 조건에서 60프레임 준비 후 240프레임을 측정한다. 등급 오버라이드는 측정용 메모리 복제에만 적용되며 DB는 수정하지 않는다.

평균 FPS와 프레임 시간 p50/p95/p99, CPU 시간, draw call, 활성 이펙트 수와 공유 재질 수를 기록한다. 화면 밖 300개에 애니메이션 재질이 붙지 않는지도 assertion으로 확인한다. 이 수치는 Linux 소프트웨어 렌더의 해당 장면에 대한 측정이다. 실제 전체 전투 화면의 60FPS 유지나 Windows/Android 실기기 성능을 대신하지 않는다.

| 1280×720, llvmpipe, 60FPS 상한 | 평균 FPS | 프레임 p50 | p95 | p99 | draw calls | 활성 효과 |
|---|---:|---:|---:|---:|---:|---:|
| 정적 목록 300개 | 59.91 | 16.653ms | 18.782ms | 21.882ms | 199 | 0 |
| 고등급 효과 300개 | 59.86 | 16.669ms | 21.592ms | 25.284ms | 300 | 300 |

화면 밖 300개는 비활성, 측정에서 공유 재질 30개(구조상 최대 32개)를 사용했다. 240프레임 약 4초씩의 짧은 측정이며 일부 프레임은 16.67ms를 넘었다. 따라서 **60FPS 안정 유지 달성**이라고 보고하지 않는다. [실제 측정 JSON](evidence/benchmark.json)과 [실행 로그](evidence/checks/benchmark.txt)를 확인할 수 있다.
