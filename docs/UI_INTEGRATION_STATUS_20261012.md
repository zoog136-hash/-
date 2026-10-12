# TWILIGHT 통합 HUD 실행 기록 — 2026-10-12

> 후속 정정: 아래는 첫 통합 PR의 기록이다. 기본 게임 시스템 대부분은 기존 main에서 재사용했고, 첫 PR의 큰 창 배치는 기존과 비슷했다. 실제 전후 비교와 오른쪽 패널 수정은 [후속 실행 기록](UI_DRAWER_CORRECTION_20261012.md)을 확인한다.

## 기준과 범위

- 기준: 최신 확인 `origin/main` `2f5ae1013da5c7281d3020719d8a723a23adb8cc`.
- 작업 브랜치: `feature/twilight-integrated-hud-20261012`.
- PR #84와 `feature/twilight-reference-expansion-20261011`은 식별 참고만 했으며 체크아웃·병합·변경하지 않았다. 맵, 월드 콘텐츠, 기존 자산 파일을 변경하지 않았다.
- 시작 시 로컬 체크아웃/미커밋 파일이 없는 `/workspace`에서 신규 clone. 강제 초기화·강제 push·main 병합 없음.
- 실행: Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility, Linux OpenGL llvmpipe. `Main.tscn` → `world.gd` → 신규 게임의 13개 클래스 선택 → 실제 월드. 기존 로컬 저장은 바로 복원. 로그인 서버는 없다.

## 코드에 반영한 구조

기존 `HUD.tscn`의 `renewal_hud.gd → hud_v20.gd → hud.gd` 체계와 게임 시스템을 재사용했다. 새로운 Autoload는 없다. `world.gd`가 게임 상태와 명령의 단일 소유자이며, HUD와 세부 창은 기존 스냅샷/신호를 공유한다.

- 상단 상태/재화/효과, 왼쪽 퀘스트·파티 전환, 하단 조이스틱/채팅/경험치, 중앙·오른쪽 퀵슬롯, 오른쪽 전투/지도 영역.
- `menu_registry.gd`: 4개 카테고리, 35개 진입점과 기능 상태. 기존 창을 라우팅하고 서버 미지원 경로는 필요한 연결을 설명한다.
- `menu_router.gd`: 이전 화면, 검색·필터·선택·스크롤 복원. 창 닫기는 게임 상태를 초기화하지 않는다.
- `renewal_window.gd` / `renewal_dialog.gd`: 공통 닫기·이전·모달·화면 경계. 창과 팝업의 실제 GUI 입력 순서 수정.
- `quickslot_controller.gd` / `quickslot_button.gd`: 좌우 각 4칸 × 3페이지, 24칸. 옛 8칸 저장의 위치 보존. 페이지 독립 전환, 숫자키, 마우스 드래그, 모바일 등록 선택, 길게 누르기, 아래 스와이프 자동사용, 해제, 저장.
- `safe_area.gd`: PC/가로 화면과 모바일 안전 영역 공통 계산. 1280×720, 1920×1080, 2400×1080 대응. 초광폭은 stretch `expand`.
- 인벤토리 개별 장비 해제/재장착, 수량·무게·정렬·필터·잠금, 소비 아이템/스킬의 슬롯 등록, 자동사용, MP/쿨타임, 타겟 순환과 실제 줍기 명령 연결.
- 메뉴/텍스트 입력 중 이동·전투 단축키 차단, 슬롯 드래그 중 인벤토리 장착 제스처 충돌 방지. 기존 자동사냥 정책은 유지.
- 퀘스트 처치 이벤트/경험치, 실제 지역 선택/이동, 제작·상점·매입·창고·강화, 변신·인형·성물의 기존 로컬 적용 경로 연결.

## 기능 상태와 통합 경계

| 기능 | 실제 동작/제한 | 연결점 |
|---|---|---|
| HP/MP/경험치/장비 능력치/재화/버프 | 기존 게임 데이터 실시간 표시 | `world._update_hud`, `_refresh_combat_hud` |
| 인벤토리·장비·스킬·퀵슬롯 | 소유 아이템, 개별 장비 ID, 직업/패시브 제한, 실제 사용/시전/저장 | 기존 명령 + `_unequip_item`, `_edit_quickslot` |
| 자동사냥·줍기·타겟 | 기존 탐색·전투·드랍/수동 습득에 연결 | `Player.auto_enabled`, `_run_auto_hunt`, `loot_pickup` |
| 퀘스트 | 기존 9마리 처치 기록과 진행률. 다중 퀘스트/목적지/보상 수령 모델 없음 | `quest_kills`, `QUEST_GOAL`; 보상 가짜 지급 없음 |
| 월드맵·지역/던전 이동 | 기존 25개 지역, 지도 검색/선택, NPC 이동 비용/레벨 검증. 입장권/던전 시간 서비스 없음 | `_on_map_selected`, 기존 teleport 서비스 |
| 제작·상점·창고·강화 | 기존 레시피/재료·아데나·실물 장비 ID 변경 | 기존 crafting/shop/warehouse/enhancement 명령 |
| 변신·마법인형·성물 | 기존 도감 검색/상세/로컬 적용. 소유 카드·합성·확률형 구매 없음 | `catalog_equip_requested` / `_equip_catalog` |
| 채팅 | 이번 플레이의 로컬 기록·실시간 시스템 로그. 일반/월드/파티/혈맹 전송 비활성 | `_submit_chat`; 서버 채널 계약 필요 |
| 파티·혈맹·친구·우편·랭킹·거래소 | 메뉴/복귀 경로와 미지원 안내. 서버 API·소유·보상 데이터 없음 | `menu_registry` 상태와 `_open_capability` |
| 컬렉션·추가 성장·스킬 습득/레벨 | 도감/현재 사용 가능 스킬만 지원. 등록/보상/습득 서비스 없음 | 기존 모델 확장 필요 |
| 설정 | 기존 전투/화면/음량 설정 + UI 접기/슬롯 페이지 저장 | `user://twilight_ui_settings.cfg` |

서버 권한이 필요한 기능을 로컬 성공 응답이나 가짜 보상으로 대체하지 않았다. 전체 UI의 **진입 구조**와 현재 구현된 로컬 기능의 연결을 제공하며, 리니지M 온라인 기능 전체 또는 최신 한국판 화면과 100% 동일하다고 주장하지 않는다.

## 검증과 전달

- 실제 게임 코드 커밋: `4fc43cd1b08040015c51da42ddf2c80ae8e6a089`(통합 기능), `cfb51e749feb386fa399cd7cebe8ba872e7e3cec`(대상/지역명 겹침 수정).
- 첫 커밋은 새 feature 브랜치에 정상 push했고 [초안 PR #86](https://github.com/zoog136-hash/-/pull/86)을 생성했다. 후속 증거 커밋과 최종 HEAD는 PR에 표시된다. 강제 push와 main 병합 없음.
- 전체 회귀: **86 PASS / 0 기능 FAIL / 3 BLOCKED**. 원본 팩 부재 3건 때문에 원본 실행기의 결과는 `86/89`, 종료 코드 1이다. 실패를 숨기지 않고 [원본 결과](ui-integration/evidence/regression-raw.json)와 [이유를 포함한 분류](ui-integration/evidence/regression-classified.json)를 모두 보존한다.
- 실제 Linux OpenGL 통합 UI: **80 PASS / 0 FAIL / 1 BLOCKED**(온라인·실기기). 추가 실제 마우스/터치 이벤트 **21 PASS**. 기존 UI fidelity **75 assertions PASS**.
- 실제 렌더 캡처 **67장**: 신규 클래스 선택 1장 + 22개 상태 × 3해상도. 이 중 8개 PNG 원본과 전체 67개 파일의 SHA-256/실제 게임 상태/크기를 저장소에 보존한다. 전체 캡처는 로컬 `/workspace/evidence/integrated-ui-delivery`와 UI CI artifact에 생성된다. CI artifact 업로드 성공은 Actions 결과에서 별도 확인해야 한다.
- 기존 723개 시트/41,442프레임/233,420,026바이트의 Git 추적 및 SHA-256 무결성 PASS. 원본 맵/PNG/SPX 팩의 미전달 상태는 유지한다.
- 상세 [필수 18개 시나리오와 재현 방법](ui-integration/VALIDATION.md), [공식 자료의 확인/추정 구분](ui-integration/REFERENCE_AND_FLOW.md), [화면 비교](ui-integration/comparison.html), [소스 SHA-256](ui-integration/evidence/snapshot.json).

실제 수정한 구현 파일은 `project.godot`, `scripts/world.gd`, `scripts/player.gd`, `scripts/crafting/expanded_crafting.gd`, `scripts/ui/{menu_registry,menu_router,quickslot_controller,quickslot_button,safe_area,renewal_hud,renewal_window,renewal_dialog,renewal_inventory,renewal_skills,renewal_quest,renewal_settings,renewal_teleport}.gd`다. 검증용 변경은 `tests/{integrated_ui_test,integrated_interaction_test,capture_integrated_hud,quickslot_smoke_test}.gd`와 `.github/workflows/ui-renewal-validate.yml`이다. 문서/로그/PNG는 `docs/ui-integration/`에 있다. 맵 제작 파일은 변경 목록에 없다.
