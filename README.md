# TWILIGHT — 최신 개발본

**권위 있는 소스: [GitHub zoog136-hash/-](https://github.com/zoog136-hash/-)의 `main` 최신 커밋.**

이 저장소는 서버 없이 PC에서 실행하는 Godot 4.7.2 로컬 RPG 프로젝트입니다. Android는 테스트 APK 및 Godot 편집기용 프로젝트를 지원하며, **Android 실기기 플레이 확인은 아직 완료되지 않았습니다.**

## 프로젝트 실행
- Godot 4.7.2에서 `project.godot`을 열고 `Main.tscn`을 실행합니다.
- Windows 휴대용 실행 ZIP은 별도의 GitHub Actions 검증 산출물에 있으며, 저장소 소스와 별개입니다.
- Android ARM64 디버그 테스트 APK는 `export_presets.cfg`와 `.github/workflows/twilight-android-playtest-apk.yml`을 사용하여 생성합니다. 직접 APK를 실행하면 모바일 편집기 경고 화면을 거치지 않습니다.
- 주요 키: WASD/방향키 이동, Space 공격, T 자동사냥, I 인벤토리, M 메뉴, Tab 지도, F5 저장, F9 불러오기.

## 현재 개발 중임을 나타내는 기능
- 도감의 **선택 아이템 임시 지급**, **강화 주문서 ×10**, **아데나 1억**은 테스트 편의용입니다. 기존 저장 데이터 아데나는 자동으로 1억으로 덮어쓰지 않으며, 도감에서 수동 보충할 수 있습니다.
- 모든 주요 UI는 공통 제목 표시줄을 드래그하여 위치를 옮길 수 있습니다. 모바일은 제목에서 손가락 드래그를 사용합니다.
- 장비 강화는 같은 이름의 아이템도 물리적 ID별로 분리합니다.
- 정상 아이템은 몬스터 처치 후 월드 바닥에 드랍되고 습득 단계를 거칩니다.

## 새 대화나 Work에 이어서 작업하기
**먼저 `main` HEAD를 확인하고 `TWILIGHT_PROJECT_RULES.md`와 `TWILIGHT_VERSION_HISTORY.md`을 읽으세요.** 이전 대화에서 생성된 ZIP이나 오래된 SHA로 버전을 역행시키지 마세요. 모든 변경은 새 브랜치/PR과 Godot CI 증거로 관리하세요.

게임플레이 자동 검사는 `tools/test_project.py`, UI 검증은 `tests/ui_renewal_integration_test.gd`, 모바일 APK 검증은 `.github/workflows/twilight-android-playtest-apk.yml`을 참고하세요.
