# TWILIGHT 화면 변경과 실제 검증 — 2026-10-12

최종 게임 코드: **`411effaf1b20a84fc910562817714712e5f52cb2`**. 전체 회귀와 UI 화면의 기준 코드: `b8d6586`. 기준 main: **`f759112bca672ef909cc695a98fa99b1b123e1d3`**. 브랜치: `feature/twilight-integrated-hud-20261012`, [PR #86](https://github.com/zoog136-hash/-/pull/86).

[실제 전후 비교](ui-integration/layout-r2/comparison.html) · [수정 메뉴](ui-integration/layout-r2/drawer-menu.png) · [가방 상세](ui-integration/layout-r2/drawer-inventory-detail.png) · [현재 필수 시나리오](ui-integration/layout-r2/VALIDATION.md)

PR #59의 스킬 시스템을 통합했다. 화면의 신규 변경과 main에서 재사용한 시스템을 아래에서 구분한다. 이전 PvE 단계의 결과는 `23517d8` 커밋에 보존했다.

## 기존과 같아 보였던 이유

첫 통합 PR(`281001d`)은 24칸 슬롯·메뉴 분류·뒤로가기·잠금·입력 충돌 처리 등을 추가했지만, 큰 창과 왼쪽 메뉴 목록을 유지했다. 인벤토리·장비·스킬·전투·제작·상점의 기본 시스템은 이미 main에 있었다. 재사용 기능을 신규 완성 항목과 구분하지 않은 이전 보고는 변경 폭을 과장했다.

변경은 feature 브랜치와 PR에 있다. main 또는 사용자의 이전 Windows/Android 실행파일에 자동 반영되지 않는다. 사용자가 실제 실행한 버전은 확인되지 않았으므로 같은 화면을 본 이유를 브랜치 문제로 단정하지 않는다.

## 이번에 실제 바뀐 화면과 조작

| 영역 | 변경 전 main | 수정한 기능 |
|---|---|---|
| 전체 메뉴 | 790px 큰 창과 왼쪽 메뉴 목록 | 오른쪽 480px, 4개 카테고리·4열 그리드·30개 진입점 |
| 인벤토리·스킬 | 1010px, 목록/상세 동시 표시 | 오른쪽 480px, 목록/상세 전환, 중앙 게임 시야 확보 |
| 공통 창 | 왼쪽 전체 메뉴 중복 | 공통 이전/메뉴/닫기, 콘텐츠별 폭 |
| 상세의 이전/ESC | 창 사이 이동 위주 | 상세 → 선택·검색을 보존한 목록 → 이전 메뉴 |
| 슬롯 등록 후 복귀 | 목록만 재생성 | 선택한 스킬 상세와 필터 복원 |
| 창이 열린 상태의 상단 HUD | 바깥 터치로 창만 닫힐 수 있음 | 가방·스킬·메뉴 등 한 번 클릭으로 직접 전환 |
| 가방 상세 | 좁은 창에서 버튼이 밀릴 수 있음 | 가용 폭 전체 사용, 사용·잠금·등록 유지 |
| 전투 기록 | 열 때의 기록 표시 | 실제 게임 이벤트 발생 시 열린 기록창도 즉시 갱신 |
| 새 스킬 시스템 연결 | main PR #59에 스킬북·습득·안정 ID 추가 | 오른쪽 스킬 상세의 구매/습득 → 24칸 등록 → 복귀 → 실제 시전, 아이콘·습득 레벨·MP·공유 쿨타임 표시 |
| 저장 후 종료 | 저장 결과 확인 필요 | 원본 맵 팩 누락으로 저장이 보호되면 종료하지 않고 파일 보존 |

폭은 1280×720 설계 좌표다. 1920×1080, 2400×1080에서도 화면 경계·하단 슬롯·오른쪽 정렬을 검사한다. 기존 PC 창 드래그와 안전 영역 계산을 유지한다. 원본 게임 UI 이미지나 아이콘을 가져오지 않았다.

HP/MP·경험치·능력치·재화·효과·미니맵·전투 조작은 기존 게임 상태를 사용한다. 기존 기능 자체를 이번에 새로 구현했다고 주장하지 않는다. 좌우 4칸×3그룹의 24칸 슬롯, 등록·교환·해제·자동사용·저장과 실제 스킬/물약 호출은 첫 통합 코드에서 이어진 변경이다.

## 최신 main 변경 보존

작업 중 main에 PR #84(맵), PR #85(PvE 범위), PR #87(카드 정책), PR #59(스킬 시스템)가 병합됐다. 최신 main을 UI feature에 통합했으며 main 또는 원래 기능 브랜치에 쓰지 않았다.

- `assets/`, `data/`, `scripts/maps/`, `addons/twilight_l1j/`는 최신 main과 동일하다. 맵 콘텐츠를 UI 작업으로 수정하거나 삭제하지 않았다.
- 원본 맵 선택·원본 좌표·누락된 원본 팩의 저장 보호를 유지했다. 지도 검색은 하나의 검색창에서 현재 지도 종류에 맞게 작동한다.
- PR #85가 제거한 퀘스트·채팅·파티·혈맹·거래소를 복원하지 않았다. 하단 기록/Enter는 오프라인 전투·시스템 로그를 연다. 처음 요청 범위와 최신 main의 차이를 사용자에게 알리고, 답변 전에는 최신 main의 제거 상태를 보존했다.
- PR #87의 카드 제외 정책·PvE 스킬 보너스·쿨타임 변환·미확정 능력 안내를 유지했다. 별도의 가짜 소유·합성·보상은 만들지 않았다.
- 전체 회귀가 갱신한 맵 문서 캡처는 `/workspace/evidence/latest-main-map-generated`에 별도로 보존하고, 저장소의 기존 맵 문서는 원래 바이트로 되돌렸다. 최종 회귀의 생성 출력도 같은 방식으로 별도 보존한다.

PR #59의 스킬북 구매·습득·습득 레벨·안정 ID·원자적 저장과 직업별 슬롯 캐시를 재사용했다. UI는 습득 정보를 별도로 저장하지 않는다. 전체 24칸과 의도적으로 비운 직업별 슬롯도 유지한다.

친구·우편·랭킹·이벤트, 컬렉션 보상, 추가 성장, 카드 소유/합성은 실제 구현이 없다. 해당 안내 화면을 실제 서비스 성공으로 계산하지 않는다.

## 수정 파일

후속 화면 수정: `scripts/ui/{renewal_window,renewal_hud,renewal_inventory,renewal_skills,renewal_browser,menu_router}.gd`.

PR 전체의 게임 연결 변경: `project.godot`, `scripts/{world,player}.gd`, `scripts/crafting/expanded_crafting.gd`, `scripts/skills/skill_service.gd`의 공유 쿨타임 조회, `scripts/ui/{menu_registry,quickslot_controller,quickslot_button,safe_area,renewal_dialog,renewal_settings,renewal_teleport}.gd`와 위 후속 파일이다. 새 Autoload는 없으며, UI는 게임 데이터를 별도 소유하지 않는다.

검증: `tests/{integrated_ui_test,integrated_interaction_test,gameplay_drawer_test,skill_drawer_learning_test,skill_landing_bounds_test,original_turn_undead_rewards_test,ui_source_save_guard_test,capture_integrated_hud,lineagem_ui_visual_smoke_test,quickslot_smoke_test,ui_renewal_integration_test,skill_mechanism_smoke_test,lineage_side_ui_smoke_test}.gd`, `.github/workflows/ui-renewal-validate.yml`. 문서 PNG를 게임 자산으로 import하지 않도록 `docs/ui-integration/.gdignore`를 두며 Git 전달은 유지한다.

## 실행과 결과

Godot **4.7.2.stable.official.ed1daf0bf**, 실제 Linux Compatibility/OpenGL Mesa llvmpipe로 `Main.tscn`을 실행했다. 테스트마다 별도 사용자 디렉터리를 써서 사용자 저장 파일을 변경하지 않았다.

- 주요 HUD/게임 상태: **79 PASS / 1 BLOCKED**. BLOCKED는 실제 모바일 기기 부재이며 입력 주입과 구별한다.
- 3해상도 오른쪽 패널과 원래 상세 복귀: **46 PASS**. 드래그/스와이프/롱프레스/모달/안전 영역: **22 PASS**. 공통 UI 회귀: **87 assertions PASS**.
- 스킬북의 실제 아데나 차감 → 습득 → 24번째 슬롯 → 시전 → 원자적 저장/로드 → 직업별 슬롯 복원은 최종 OpenGL에서 **22 PASS**다. 저장 보호는 **6 PASS**다. 스킬/재화/소유 값을 UI에서 조작해 성공시키지 않는다. 무기 제한 검증에 사용한 양손검만 기존 도감 테스트 지급 명령으로 획득했다.
- 전체 **132개** 원본 실행은 **122 PASS / 7 FAIL / 3 SKIP**다. 착지 오류와 테스트 호환 문제를 수정한 뒤 영향 검사 **12개 모두 PASS**, 새 착지 경계 검사 **9 assertions PASS**를 확인했다. 재검사 반영 최종 분류는 **126 PASS / 0 FAIL / 6 BLOCKED**다. [원본 로그와 재검사 근거](ui-integration/layout-r2/evidence/skill-regression/), [18개 필수 시나리오](ui-integration/layout-r2/VALIDATION.md). 전체 133개를 한 번에 통과했다고 주장하지 않는다.
- UI 구조의 실제 실행 화면 **73장**은 `b8d6586` 캡처다. 이후 `411effa`는 착지 좌표 처리와 테스트만 바꿨으며 UI 레이아웃 파일은 동일하다. 실제 화면 캡처: `/workspace/evidence/skill-final-captures`. 최신 main의 원본 실행 비교는 `/workspace/evidence/before-f759112-captures`. 대표 PNG와 [파일별 SHA-256/게임 상태](ui-integration/layout-r2/evidence/captures.json)를 Git에 전달한다.
- 최신 main에서도 재현된 순간이동·소환의 범위 밖 격자 조회를 고쳤다. 표시 타일 수 대신 실제 `astar.region`과 요청 반경을 사용한다. 맵·지형·배치 데이터는 수정하지 않았다. 새 검사는 실제 슬롯 순간이동, 64개 임의 착지, 주인 근처 소환 위치, 비영점 격자 원점을 확인한다.
- 스킬 보상 테스트의 제거된 퀘스트 카운터 참조를 없애고 실제 처치/경험치/아데나/바닥 드랍/저장 검증은 유지했다. 퀵슬롯 테스트는 등록 시 AUTO ON 상태를 다시 끄던 통합 오류를 바로잡아 OFF/ON/SELF를 각각 검증한다. [최종 12개 로그](ui-integration/layout-r2/evidence/landing-fix-final/), [검사 대상 코드 SHA](ui-integration/layout-r2/evidence/landing-fix-snapshot.json).
- 원본 리소스 무결성: 723개 WebP 시트 / 41,442프레임 / 233,420,026바이트 확인. 미설치 개인 원본 맵·PNG·SPX 팩을 포함했다고 주장하지 않는다.
- Windows GPU·실제 Android/iOS 기기 실행은 BLOCKED/미검증이다. Linux 입력 주입이나 CI 빌드를 실기기 실행으로 취급하지 않는다.

## 보존한 이전 단계

| 소스 | 검증/화면 |
|---|---|
| `a1f9f3c` (첫 main 기준 오른쪽 패널) | 전체 87/90, 원본 팩 3 BLOCKED. [원본 기록](ui-integration/layout-r2/evidence/results.json) |
| `06149ac` (맵 통합, main `68283b1`) | 전체 110 PASS / 6 BLOCKED. raw 110/116, FAIL 3 / SKIP 3을 보존. [원본 로그·분류](ui-integration/layout-r2/evidence/map-sync-regression/) |
| `23517d8` (PvE 통합 증거) | `b215b20` 실행, 118개 최초 로그 111 PASS / 4 FAIL / 3 SKIP. 낡은 메뉴 검사 수정 후 재검사 포함 112 PASS / 6 BLOCKED. [이전 manifest](ui-integration/layout-r2/evidence/captures-before-skill-sync.json), [원본 회귀 기록](ui-integration/layout-r2/evidence/pve-regression/) |
| `31feb7f` (맵 통합 증거 커밋) | 82장 manifest 및 대표 화면의 과거 바이트. [이전 manifest](ui-integration/layout-r2/evidence/captures-before-pve-sync.json) |

현재 결과에 이전 SHA의 테스트를 합산하지 않는다. 최신 CI의 SHA·결과·URL은 PR과 현재 검증 기록에서 확인한다.

## 전달과 다음 작업

기능 커밋 `62d085f`(오른쪽 패널), `0ccf57b`(드래그 위치 보존), `d05aba0`(저장 보호 검사), `b215b20`(최신 main 통합), `fb102d1`(카드 쿨타임 검사 호환), `b8d6586`(최신 스킬 시스템과 24칸 연결)은 정상 push했다. 최종 착지 수정 `411effa`와 검증 증거도 같은 feature 브랜치로 전달한다. 강제 초기화·강제 push·main 병합은 하지 않았다.

전체 회귀가 생성한 맵 문서 파일 240개는 `/workspace/evidence/final-skill-map-generated`에 SHA와 함께 보존한 뒤 기존 Git 상태로 복원했다.

다음 UI 우선순위는 설정 내부 분류, 자동사용 정책의 화면 안내, 미구현 소유/성장 모델의 실제 연결, 실기기 검증이다. 최신 한국 리니지M의 모든 메뉴 배치는 확인하지 못했으며 [공식 자료의 확인/추정 구분](ui-integration/REFERENCE_AND_FLOW.md)을 유지한다.

이번 수정은 화면 점유와 탐색 흐름을 실제로 바꾼 단위다. **리니지M 수준의 전체 UI/UX가 100% 완료됐다고 보고하지 않는다.**
