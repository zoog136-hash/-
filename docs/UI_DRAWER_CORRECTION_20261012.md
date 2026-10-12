# 화면 변경 재확인과 오른쪽 패널 수정 — 2026-10-12

맵 통합 단계의 실행 코드: **`06149aca69bf7902ad00c5aceb4661b1676c16e6`**. 작업 중 새 main **`68283b12b18d6e38f462f7b3d58587741756947e`**에 PR #84의 맵이 병합되어 UI 브랜치에도 통합했다. `assets/`, `data/`, `scripts/maps/`, `addons/twilight_l1j/`는 이 main과 바이트 차이가 없다. 원본 맵 브랜치와 main에는 쓰지 않았다.

현재 [전후 비교](ui-integration/layout-r2/comparison.html)는 **같은 최신 맵** 위의 main `68283b1`과 UI 통합본 `06149ac`이다. 이전 맵 기준 캡처는 `1678227` 커밋과 [이전 manifest](ui-integration/layout-r2/evidence/captures-before-main-sync.json)에 보존한다.

## 기존과 같아 보였던 이유

첫 통합 PR(`281001d`)은 24칸 퀵슬롯·메뉴 분류·뒤로가기·잠금·입력 충돌 처리 등을 추가했지만, 기존의 큰 창과 왼쪽 메뉴 목록을 유지했다. 인벤토리·장비·스킬·전투·제작·상점의 기본 시스템은 이미 main에 있었다. 이 재사용 기능을 신규 완성 항목과 구분하지 않은 이전 보고는 변경 폭을 과장했다.

또한 변경은 `feature/twilight-integrated-hud-20261012`와 [PR #86](https://github.com/zoog136-hash/-/pull/86)에만 있다. main이나 사용자의 이전 Windows/Android 실행파일에 자동 반영되지 않는다. 사용자가 실행한 버전은 아직 확인되지 않았으므로 같은 화면을 본 이유를 브랜치 문제로 단정하지 않는다.

처음에는 당시 main `2f5ae10`을 별도 detached worktree에서 실제 Godot로 실행해 비교했고, 원격 갱신 확인 후 비교용 worktree와 UI 통합본을 모두 최신 맵으로 갱신했다. [전후 화면 비교](ui-integration/layout-r2/comparison.html)에서 최신 main/이전 PR을 선택해 볼 수 있다. 이전 PR 비교에는 당시의 맵이 표시됨을 SHA로 구분한다.

## 이번에 실제 수정한 범위

오른쪽 패널 코드: `62d085ff31491c1db5e61c47888aaf4df27a6d5d`. 창 드래그 위치 보존: `0ccf57b`. 검사 화면 크기 보완을 포함한 검증 소스: `a1f9f3c4934858cb7cd60f58a9aae80d185fd6b8`.

| 영역 | main / 이전 PR의 배치 | 이번 수정 |
|---|---|---|
| 전체 메뉴 | 폭 790px의 큰 창, 왼쪽 상시 메뉴 목록 | 오른쪽 폭 480px, 4개 카테고리·4열 그리드 |
| 가방·스킬 | 폭 1010px, 목록/상세 동시 표시, 중앙 캐릭터 가림 | 오른쪽 폭 480px, 목록/상세 전환, 중앙 게임 화면 확보 |
| 퀘스트·효과·던전·커뮤니티 안내 | 공통 큰 창 | 같은 오른쪽 패널 규칙 적용 |
| 장비·지도·제작·상점·설정 등 | 모든 창에 왼쪽 전체 메뉴 목록 중복 | 콘텐츠 폭에 맞는 공통 창, 이전/메뉴/닫기만 유지 |
| 상세에서 이전/ESC | 창 간 이동만 처리 | 상세 → 선택·검색을 유지한 목록 → 이전 메뉴 순서 |
| 스킬 등록 후 복귀 | 목록만 재생성 | 선택된 스킬 상세와 필터 상태 복원 |
| 열린 창 위 HUD 단축 버튼 | 바깥 터치로 창만 닫힐 수 있음 | 가방/스킬/메뉴 등 한 번 클릭으로 직접 전환 |
| 가방 상세 폭 | 좁은 패널에서 최소 폭만 사용 | 가용 폭 전체 사용, 사용·잠금·등록 버튼 유지 |

폭은 1280×720 설계 좌표 기준이다. 1920×1080과 2400×1080에서도 오른쪽 정렬, 화면 경계, 하단 슬롯 접근을 검사했다. PC 창 드래그, 모바일 입력, 기존 안전 영역 계산을 유지했다.

메인 HUD의 기존 HP/MP/상태·미니맵·공격 영역, 게임 데이터, 전투 규칙, 월드/맵, 자산을 이번 후속 수정에서 새로 만들었다고 주장하지 않는다. 원본 아이콘을 가져오지 않고 프로젝트의 기존 리소스를 재사용했다.

실제 구현 파일: `scripts/ui/{renewal_window,renewal_hud,renewal_inventory,renewal_skills,renewal_browser,menu_router}.gd`.

검증/캡처 파일: `tests/{gameplay_drawer_test,integrated_ui_test,lineagem_ui_visual_smoke_test,ui_renewal_integration_test,capture_integrated_hud}.gd`, `.github/workflows/ui-renewal-validate.yml`.

## 실행과 검증

- Godot 4.7.2 공식 바이너리, Compatibility / Linux OpenGL llvmpipe.
- 새 `gameplay_drawer_test.gd`: **46 PASS / 0 FAIL**. 실제 GUI에 마우스·터치 이벤트를 주입해 3해상도에서 메뉴 전환, 아이템 상세, 뒤로가기, 드래그 등록, 스킬 등록 후 상세 복귀, 입력 차단 해제를 확인했다. [로그](ui-integration/layout-r2/evidence/native-drawer.txt).
- 기존 통합 UI·제스처·fidelity와 전체 프로젝트 회귀 결과는 최종 [검증 요약](ui-integration/layout-r2/evidence/results.json)에 기록한다. 먼저 끝난 일부 검사를 전체 완료로 계산하지 않는다.
- 최신 main 통합 후 OpenGL 주요 UI **80 PASS / 1 BLOCKED**, 오른쪽 패널 입력 **46 PASS**. 지도 선택·원본 좌표·원본 팩 누락 시 저장 보호를 유지했고 검색창을 하나로 통합했다. 이전 기반의 전체 결과는 **87 PASS / 3 BLOCKED**, raw 87/90으로 보존한다. 최신 맵을 포함한 전체 116개 검사는 별도 결과로 기록한다.
- 테스트 사용자 디렉터리를 별도로 만들어 실제 사용자 저장 데이터를 변경하지 않았다. 새 입력 검사는 기존 시작 아이템·스킬을 사용한다.
- 실제 휴대폰·Windows GPU는 **BLOCKED/미검증**. Linux에 주입한 터치 이벤트를 실기기 테스트로 취급하지 않는다.
- 서버 채팅·파티·혈맹·우편·거래소, 퀘스트 보상/목적지, 카드 소유/합성, 스킬 습득 모델의 기존 미구현 상태는 그대로다.

이전 PR SHA의 UI Renewal Validate와 Integration Validate는 PASS였다. 같은 SHA의 L1J Runtime CI는 기존 fixture 덮어쓰기 보호에서 FAIL, 25 Map Visual Styles CI는 import 및 후속 5개 검사 FAIL이었다. 새 SHA의 결과와 혼동하지 않는다. 최신 CI와 전달 HEAD는 PR에서 확인한다.

**후속 통합 진행:** 원격 main이 `cfbf0fb`(PvE 범위 정리 PR #85, 카드 정책 PR #87)로 갱신됐다. 아래 캡처와 위 검증은 `06149ac`의 기록이며, 새 main 통합 결과로 대신 계산하지 않는다. 새 main의 제거된 기능을 보존하며 오른쪽 패널·슬롯·전투 기록을 통합한다.

## 전달과 남은 작업

- 코드와 후속 회귀 수정은 기존 feature 브랜치에 정상 push. 강제 push, main 병합 없음.
- 이전 보고/증거는 이전 SHA의 이력으로 보존하고 이 문서로 변경 범위를 정정한다.
- 실제 캡처 사본과 SHA-256: [layout-r2](ui-integration/layout-r2/), [manifest](ui-integration/layout-r2/evidence/captures.json). 전체 캡처 경로는 `/workspace/evidence/merged-final-captures`이며 추적된 대표 사본과 로컬에만 있는 전체를 구분한다.
- 통합본 82장 중 대표 8장과 최신 main 비교 3장, 총 11개 PNG를 Git에 보존한다. 캡처 코드는 `06149ac`다. 문서 폴더의 `.gdignore`는 검토용 스크린샷을 Godot 게임 자산으로 재가져오지 않게 하며, Git 추적/전달은 유지한다.
- 다음 UI 우선순위는 미완료 메뉴의 내부 동선과 설정 분류, 퀵슬롯 자동사용 정책의 화면 안내다. 온라인/보상/소유 시스템은 실제 계약과 데이터 모델 구현이 선행되어야 한다.

이 후속 수정은 메뉴의 화면 점유와 탐색 흐름을 바로잡은 단위다. 리니지M 수준의 전체 UI/UX가 100% 완료됐다고 보고하지 않는다.
