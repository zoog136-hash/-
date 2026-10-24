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

## 후속 구현·이미지 개선 검증 (PR154)

- 별도 개발 모드: `growth_lab_check.gd -- --growth-lab`, **37 assertions PASS**. 일반 저장 거부, 신규 시험 재료, 실제 1회/5회 강화, 초기화 환급, 선행 해금, 카드 실패/재시도/로드, 대표 HP, 절대 I~V 비용·상한·저장 검증. `followup/development-check.txt`.
- 최종 변경 범위 통합 묶음: **4/4 PASS** — Main 부팅, 성장 **86 assertions**, 기존 Ain **26 assertions**, 기존 UI fidelity **88 assertions**. 성장 검사에는 실제 MP 회복 tick/물약 쿨타임과 일반 모드의 개발 저장 거부를 추가했다. `followup/summary.json`.
- 래스터 자산 추가 후 전체 import PASS (`/tmp/growth-cards-import`). 기존 장비 컬렉션 76개 검사는 첫 커밋에서 통과했으며 후속 변경에서 반복하지 않았다.
- 후속 리소스 무결성 PASS (동일 723 atlas/41,442 frames). 생성 UI 3개 PNG는 별도 `assets/growth/PROVENANCE.json` 해시/크기/생성 경로로 확인.
- 투명도 검사: 카드 atlas 외곽/중앙 경계 alpha 0, sigil atlas 중앙 세로 경계 최대 alpha 1/255. 실제 검은 배경 적용 화면에서 잘린 테두리·옆 칸 문장 혼입 여부를 시각 확인한다. Godot AtlasTexture.filter_clip 사용. 외곽의 극미세 alpha를 원본 파일 편집으로 제거하지 않았다.
- 작은 화면 개선: 문양/수호성 창만 전체 화면, 48px 기본 터치 버튼/76px 노드/110×150 카드, 스크롤·닫기 유지. 실제 Android 기기가 아닌 Linux 854×480 렌더+ScreenTouch/ScreenDrag 이벤트 검증이다.
- 첫 개발 검사 실패는 테스트가 `joe_stat` 선행 노드를 건너뛰었기 때문이다. 순서를 수정한 재검사 통과. 첫 카드 캡처도 성공으로 집계하지 않는다. 캡처 fixture가 `.eva`로 StringName 키를 넣어 저장 검증에서 거절됐고, 문자열 키 `["eva"]`로 수정했다. 실제 게임 입력의 id는 String으로 해당하지 않는다.
- 시각 비교의 `before/`는 첫 커밋의 기본 잠금 화면이다. 후속 이미지는 **개발 모드의 명시적인 진행 fixture**(에바 18, 조우 앞 3노드)이며 자연 플레이로 이 상태를 획득했다는 증거가 아니다. 카드 화면만 실제 개발 거래 후 촬영한다. 전후 진행 수치는 같지 않다.

재현:

```sh
# 사용자 저장과 격리된 새 경로 권장. debug/editor 엔진만 허용.
XDG_CONFIG_HOME=/tmp/growth-config XDG_CACHE_HOME=/tmp/growth-cache \
XDG_DATA_HOME=/tmp/growth-lab-new /path/to/godot --headless --path . \
  --script res://tests/growth_lab_check.gd -- --growth-lab

# 직접 플레이: 같은 플래그, --headless/--script 생략
/path/to/godot --path . -- --growth-lab
```

일반 플레이의 공식 강화 비용 전체표, 수호성 원본 전체 노드/비용/카드 수/전투 스킬, 절대 옵션 원작 효과는 아직 미완료다. 개발 모드 통과를 원작 수치 검증으로 해석하지 않는다. 전체 CI나 실제 Android 검증 통과도 주장하지 않는다.

최종 래스터 적용 렌더: **7장 PASS**, llvmpipe. 문양/수호성 1280×720·854×480, 카드 뒷면·선택 강조·성공 앞면 854×480. `after/`와 `followup/capture.txt`에 보존했다. 카드 캡처는 실제 수호석 차감(100→99), 선택 대기 저장, 성공 노드 개방을 검사한 뒤 생성했다. 카드 미선택·선택·성공 화면을 직접 확인했다.

문양 탭 변경/다른 메뉴 이동 시 확률 변경 상태를 지우는 경로를 추가 보완한 뒤 성장 검사만 재실행: **88 assertions PASS**, `followup/growth-tab-final.txt`. 전체 묶음을 반복하지 않았다. 캡처 후 대표 표시의 내부 ID를 사용자용 노드 이름으로 바꾼 텍스트 수정이 있으며 스크린샷은 그 직전 렌더다.
