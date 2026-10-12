# PR #86 선택 기능 이식 기록 (2026-10-12)

기준: `main` / PR #91 병합 커밋 `9fbcd1a02505a2d9685507411faff577c7e236f6`.

## 범위

- #86에서 **메뉴 이동 히스토리/검색·선택·필터 상태 복원**을 UI 전용 `navigation_memory.gd`로 이식. 로컬 화면 상태만 보관하며 게임 데이터나 원본 저장 파일은 건드리지 않는다.
- 기존 PR #91 `renewal_window.gd`에 상황별 '뒤로' 버튼을 추가하고 Escape도 동일한 화면 복귀 경로를 사용한다. 기존 인벤토리·스킬 상세의 Escape 복귀는 유지.
- 전투/시스템 로그가 **열린 상태에서도 실시간 갱신**되도록 `CombatLogHistory`를 관리한다. 120줄 유지 제한·원본 전투 시스템은 기존 방식 그대로.
- #91에서 이미 **오른쪽 450px 소형 메뉴 및 별도 인벤토리/스킬 창**을 사용하므로 #86의 480px 패널로 덮어쓰지 않는다. 또한 #91 `pointer_transfer.gd`와 50슬롯/독립 페이지 설정을 보존하며 #86의 24슬롯/개별 제어기는 옮기지 않는다.

## 의도적으로 제외한 것

- #86의 구식 `renewal_hud.gd`, `renewal_window.gd`, `quickslot_button.gd`, `quickslot_controller.gd` 전체 덮어쓰기
- #86에만 있던 커뮤니티 안내용 메뉴(친구·우편·랭킹 등), 삭제한 PvP·퀘스트·거래 기능
- 월드 스킬 착지·소환 경계 수정 및 전체 `world.gd` 병합: 최신 main 코드의 별도 소유와 맵 회귀를 건드릴 수 있어 분리 검증 전까지 이식하지 않음
- `scripts/ui/safe_area.gd`의 임의 합병: PR #91 기존 좌표·레이아웃 체계를 유지.

## 검증

- 신규 `ui_navigation_preservation_test.gd`: 히스토리, 필터·선택, 메인 씬 메뉴/설정 복귀, 인벤토리 검색 복원, 라이브 로그, 인벤토리/퀵슬롯 상태 보존.
- 기존 `ui_pointer_transfer_test.gd`, `quickslot_smoke_test.gd`, `ui_renewal_integration_test.gd` 재실행을 CI에 요구.
- PR #91 UI 전체 워크플로도 변경된 `renewal_*.gd` 파일로 트리거된다.

주의: 이 대화 컨테이너에는 Godot 실행 파일이 없어 엔진 검증을 완료했다고 주장하지 않는다. 원격 Actions가 성공하기 전에는 PR을 Draft로 두고 #86도 종료하지 않는다.
