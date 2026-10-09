# TWILIGHT 프로젝트 작업 규칙 — 최종 개발 기준 (2026-10-09)

> **최우선 원칙: GitHub 저장소 `zoog136-hash/-`의 `main` 최신 HEAD가 유일한 기준 소스입니다.**

## 새 대화 / 새 Work 시작 전 필수 확인
1. GitHub 저장소 `zoog136-hash/-`의 **main 최신 HEAD SHA**를 직접 확인합니다. 이 파일과 `TWILIGHT_VERSION_HISTORY.md` 및 `README.md`를 먼저 읽습니다.
2. `main`의 `project.godot`, `scripts/world.gd`, `scripts/ui/renewal_hud.gd` 및 변경할 관련 파일을 실제로 읽고 작업합니다.
3. **과거 ZIP 파일이나 대화에 적힌 SHA를 최신 원본이라고 간주하지 않습니다.** 2026-10-07 라이브러리 ZIP 및 2026-10-09 이전 모바일·PC 테스트 ZIP은 보조 자료로만 취급합니다.
4. 최신 `main`에서 별도 `feature/` 또는 `validation/` 브랜치를 만든 뒤 수정합니다. 원본 기능 브랜치와 백업은 수정·삭제하지 않습니다.
5. **Godot 프로젝트 전체 검사, 게임 부팅, UI 테스트, 가능하면 해당 플랫폼 실제 렌더링 검증**을 진행합니다. 테스트 없는 '완료' 주장은 금지합니다. 필요한 증거는 GitHub Actions URL과 정확한 SHA를 기록합니다.
6. 기능 검증 후 PR로 통합합니다. `main` 변경은 사용자 승인 시에만 하며, PR 최종 SHA·CI 결과·충돌 여부를 확인하고 사전 백업을 남깁니다.

## 현재 프로젝트 원칙
- TWILIGHT는 **서버 없는 PC 단독 실행 로컬 Godot RPG**입니다. 모바일 Android는 병행 시험 플랫폼입니다.
- Godot 4.7.2를 검증 기준으로 사용하며, 프로젝트 렌더러는 Compatibility(OpenGL)입니다.
- 주된 기능: 맵/이동/몬스터/전투 프레임 동기화/자동사냥/바닥 드랍/수동·자동 습득/인벤토리/강화/소모품/저장/변신/인형/성물/상점·HUD.
- **몬스터 처치 시 아이템을 인벤토리에 즉시 지급하지 않습니다.** 월드 바닥 드랍을 반드시 거쳐 습득해야 합니다.
- **동일 장비의 강화 상태는 물리적 장비 ID별로 독립적**입니다. ID 스키마와 구버전 저장 마이그레이션을 보존합니다.
- 테스트용 아이템 도감 지급, 아데나 1억, 주문서 ×10 버튼은 **개발·검증 편의 기능**이며 밸런스/출시 기능이 아닙니다. 출시 빌드에서는 별도로 숨기거나 제거하도록 결정해야 합니다.
- Android ARM64 APK는 공식 Godot 4.7.2로 **빌드 및 압축 검증**했으나 사용자 실기기의 실행 결과는 계속 별도 수집해야 합니다. 모바일 Godot 편집기에서 보인 노란색 GDScript 경고는 **치명적 오류와 구분**합니다.
- Linux 소프트웨어 OpenGL(llvmpipe) CI 성능 수치는 Windows/Android GPU 실제 FPS를 보장하지 않습니다.

## 병합 이력 및 참고
- 1~5단계 플레이 기능 통합 기준: `integration/twilight-complete-20261009` @ `d923aa2`.
- 이후 실제 플레이테스트 수정: PR #32, 통합 커밋 `455a5f1` (기능 시험 중인 임시 지급 / 1억 / 드래그).
- Android 테스트판 빌드가 성공한 원본: `validation/twilight-android-playtest-apk-20261009` @ `2157cb3` (ETC2/ASTC, Android ARM64).
- 이전 `main` 백업: `backup/main-before-twilight-final-20261009` (`11894be`).
- 이전 5단계 통합 백업: `backup/integration-before-playtest-final-20261009` (`d923aa2`).
- 기타 백업과 원본 feature 브랜치는 보존하고 임의 병합/정리하지 않습니다.

## 최종 검증
- 전체 기능: `python3 tools/test_project.py` (Godot 4.7.2 지정).
- Godot UI: `.github/workflows/ui-renewal-validate.yml`; 17화면 × 4해상도 = 68 OpenGL 캡처.
- Android: `export_presets.cfg`, `project.godot`의 ETC2/ASTC, `.github/workflows/twilight-android-playtest-apk.yml`.
- Android APK는 서명된 **디버그 테스트 APK**입니다. 배포용 최종 서명·Google Play 출시·실기기 성능 점검은 미완료입니다.
