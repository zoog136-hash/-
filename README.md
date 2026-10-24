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

몬스터 월드 구현 후보의 [구현·배치·조사 한계·검증 보고서](docs/MONSTER_WORLD_IMPLEMENTATION.md)를 참고하세요. 원작 전체 고증과 모든 종의 독립 8시점 아트 완성 여부는 기능 검사 통과와 구분합니다.


UI 전면 리뉴얼 후속 PR #50의 [화면별 변경·참조·검증 범위](docs/UI_RENEWAL_FIDELITY_20261009.md)를 참고하세요. 실제 터치 입력 회귀와 작은 창/Android 크기 화면 검증은 `tests/ui_fidelity_regression_test.gd`와 `tests/capture_ui_fidelity.gd`에 포함됩니다.


원작 스킬 이행 작업은 별도 feature 브랜치의 검증 중인 변경입니다. [조사 도감](docs/skills/CATALOG.md), [검증·미완료 보고서](docs/skills/VALIDATION.md), [구현 구조와 재개 절차](docs/skills/IMPLEMENTATION.md)를 참고하세요. 2025-06-17의 전체 스킬 목록과 원작 이펙트 복원이 완료된 상태는 아닙니다. 원본 257개 스킬 DB는 보존하고, 활성 도감은 날짜가 확인된 자료를 바탕으로 실행을 연결한 별도 DB를 사용합니다.

## 리소스 누락 방지 자동검사 (2026-10-11)

새 Work를 시작하기 전 [리소스 상태 장부](data/resource_delivery_ledger.json)와 [필수 리소스 확인 절차](docs/RESOURCE_INTEGRITY_POLICY.md)를 확인하십시오. `python3 tools/check_resource_integrity.py --root .`은 Git에 실제 포함된 시트 723개와 SHA/매핑을 전수 검사합니다. 업로드된 원본 ZIP이나 외부 팩이 자동으로 GitHub 또는 배포본에 포함되는 것은 **아닙니다**. 원본 전달은 별도 ZIP/영수증 및 깨끗한 환경 재검증이 있어야 완료로 보고합니다.

리메이크 작업의 실제 변경·실패·전후 영상·재현 절차는 [검증 결과](docs/remake/VALIDATION.md)와 [재개 기록](docs/remake/REMAKE_CHECKPOINT.md)에 있습니다. 전체 원본 모션 적용/Android 실기기 완료 상태는 아닙니다.

## 독립 UI 샘플

2026-10-23 리니지M 참고 웹 샘플은 [samples/twilight-ui](samples/twilight-ui/README.md)에 있습니다. 실제 실행 캡처·비교 이미지와 입력 검증 기록을 함께 보존했습니다. Godot 본게임 UI로 이식한 버전이 아니며 게임 저장·계정·APK와 연결하지 않습니다.
