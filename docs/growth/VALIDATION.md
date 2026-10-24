# 로컬 검증 기록

기준 main: `e0a14f07da7764598822be669d05b3c2985d13eb`.
브랜치: `feature/twilight-emblems-guardian-20261024`.
엔진: Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility, Linux.
사용자 저장과 분리된 XDG_DATA_HOME에서 검사했다. 새 원본 이미지/외부 게임 계정/실제 결제는 사용하지 않았다.

## 최종 결과

- 전체 프로젝트 import: PASS.
- 실제 Main 부팅: PASS.
- 성장 거래/실제 저장·로드/능력치/메뉴 터치/스와이프 집중 검사: **82 assertions PASS**. `evidence/growth_progression_test.txt` 참조.
- 기존 장비 컬렉션 런타임: **76 assertions PASS** (가상 디스플레이 재검사).
- 기존 UI fidelity 회귀: **88 assertions PASS**.
- OpenGL 실제 화면 4장: 문양·수호성 각각 1280×720 / 854×480, llvmpipe. 생성 결과 PASS, 파일 직접 시각 확인.
- 리소스 무결성: **723 atlas / 41,442 frames / 233,420,026 bytes PASS**. 원본 리소스 전체 전달의 의미는 아니다.
- `git diff --check`: PASS.

## 실패 및 수정 기록

1. 처음 import는 기본 `/home/agent/.config`, `.cache` 쓰기 금지로 FAIL. XDG_CONFIG_HOME/XDG_CACHE_HOME을 `/tmp`로 지정한 재검사 PASS. 초기 import가 끝나기 전에 시작한 첫 Main 시험은 미import 리소스 오류가 있어 중단했으며 성공으로 집계하지 않았다.
2. 집중 검사에서 네이티브 터치 확인창과 작은 화면 assertion이 실패했다. 기존 native_touch_button을 재사용하고 스와이프 전달을 보완했으며 테스트 루트 크기/최종 화면 변환을 명시하여 재검사했다.
3. 실패 카드 저장·로드 시 JSON float과 int의 `Array.has()` 비교 차이로 실패 카드 재선택 문제가 드러났다. 로드 정규화 후 저장·재시도·대표 효과 검사 PASS.
4. 추가 메뉴 진입/스와이프 테스트에서 스와이프 뒤 탭이 무시되는 문제가 발견되어, native 버튼이 수락한 이벤트도 스크롤 창에 명시적으로 전달하도록 수정했다.
5. 최종 5검사 묶음은 **4 PASS / 1 실행준비 FAIL**이었다. 기존 컬렉션 검사가 renderer를 요구하는데 DISPLAY가 없었다. DISPLAY=:97로 그 항목만 재실행하여 **1/1 PASS**. 원래 summary를 성공으로 덮어쓰지 않았다.

## 재현

```sh
XDG_CONFIG_HOME=/tmp/twilight-config XDG_CACHE_HOME=/tmp/twilight-cache \
  python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --only import,boot,growth_progression_test,ui_fidelity_regression_test \
  --logs /tmp/growth-tests --no-ci-synthetic-fixtures

# Xvfb 등 실제 DISPLAY 필요. headless 성공으로 대체하지 않는다.
DISPLAY=:97 LIBGL_ALWAYS_SOFTWARE=1 \
XDG_CONFIG_HOME=/tmp/twilight-config XDG_CACHE_HOME=/tmp/twilight-cache \
  python3 tools/test_project.py --godot /path/to/godot \
  --only equipment_collection_runtime_test --logs /tmp/collection-check

DISPLAY=:97 LIBGL_ALWAYS_SOFTWARE=1 XDG_DATA_HOME=/tmp/growth-capture-save \
GROWTH_CAPTURE_DIR=/tmp/growth-captures /path/to/godot --audio-driver Dummy \
  --path . --script tests/capture_growth.gd
```

## 미실행 / 제한

- 저장소의 전체 256개 테스트를 전수 실행하지 않았다. 전체 import·Main 부팅과 변경 관련 회귀를 선택 실행했다.
- 실제 Android 기기 터치, Android APK 빌드·성능 및 Windows 검증 미실행.
- 그림의 문양/수호성 기본 상태는 실설정이며, 성공·실패 거래 테스트의 비용/노드 fixtures는 합성 값이다. 미확인 원작 경제를 검증한 결과가 아니다.
- 전체 수호성 그래프, 확률 개방 데이터, 절대 옵션 전투 효과, 서버별 개방 상태는 미완료. `RESEARCH.md`의 잠금 항목을 참조한다.
- PR은 검토용 draft이며 main 병합·배포하지 않는다. 최종 SHA와 원격 CI 상태는 작업 결과 응답으로 별도 기록한다.
