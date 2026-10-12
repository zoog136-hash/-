# 통합 UI 검증 결과

Godot 4.7.2 공식 Linux 바이너리로 실제 `Main.tscn`을 실행했다. 렌더 검증은 Xorg dummy display + Compatibility / Mesa llvmpipe이며, 단순 파싱 검사를 실기동으로 계산하지 않았다. 테스트마다 분리된 XDG 사용자 디렉터리를 사용하여 플레이어 저장을 건드리지 않았다. 장비/피해/퀘스트 이벤트 fixture는 테스트 스크립트 안에서만 사용한다.

실행 코드: `cfb51e749feb386fa399cd7cebe8ba872e7e3cec`. 런타임 파일별 SHA-256은 [snapshot.json](evidence/snapshot.json). 캡처 스크립트에는 자동 레벨업 장비창을 닫고 AUTO HUD를 촬영하는 후속 절차 보완이 있다. 게임의 레벨업/자동사냥 정책은 바꾸지 않았다.

## 필수 시나리오

| 번호 | 시나리오 | 결과 | 확인한 범위 |
|---|---|---|---|
| 1 | 게임 진입과 전체 HUD | PASS | 실제 클래스 버튼 선택/확인, Main 씬 월드, 외곽 HUD/8개 가시 슬롯/24개 저장 슬롯 |
| 2 | 상태 실시간 변화 | PASS | 실제 피해 HP, 처치 경험치, 장비 능력치와 HUD 공통 상태 |
| 3 | 인벤토리 열기/닫기 | PASS | 실제 마우스 입력으로 가방 단축/닫기 |
| 4 | 아이템 장착/해제 | PASS | 소유 개별 ID 재장착/해제/능력치 갱신; 잠금 판매 및 물약 우회 사용 방지 |
| 5 | 인벤토리 퀵슬롯 등록 | PASS | 상세 등록에서 오른쪽 3그룹 선택, 네이티브 드래그 등록, 자동 ON/OFF/해제 |
| 6 | 스킬창 퀵슬롯 등록 | PASS | 실제 직업 스킬 상세 → 등록 및 스킬 카드 직접 드래그 |
| 7 | 페이지 전환 | PASS | 좌우 독립 3그룹, 터치 가로 스와이프와 페이지 설정 복원 |
| 8 | 슬롯 스킬 사용 | PASS | 실제 버프 시전과 MP 차감 |
| 9 | MP/쿨타임 | PASS | 실제 쿨타임 값/가림 표시/MP 부족 표시 |
| 10 | 자동사냥 ON/OFF | PASS | 기존 AUTO 탐색 호출, 실제 자동 전투 캡처, 수동 중지, 소유 물약 자동 소모/회복 |
| 11 | 퀘스트 상세 | PASS | 실제 처치 이벤트 → 기존 9마리 진행률/상세 갱신. 목적지/보상 시스템은 범위 밖 미구현 |
| 12 | 월드맵과 지역 선택 | PASS | 실제 지역 목록 선택/정보, 이동 명령. NPC 이동 회귀 검사도 통과 |
| 13 | 채팅 사용 | BLOCKED | 로컬 기록 입력/표시와 시스템 로그는 PASS. 실제 일반/월드/파티/혈맹 전송은 서버 계약 부재로 BLOCKED |
| 14 | 메뉴 간 이동 | PASS | 33개 비종료/비클래스 경로 + 실제 클래스 선택. 뒤로가기/선택·검색 복원/바깥 클릭/모달 확인·취소. 종료는 save bool 검증, 실제 프로세스 종료 버튼 클릭은 수행하지 않음 |
| 15 | 설정/저장 복원 | PASS | 좌표 표시 재진입, 24개 슬롯 저장/불러오기, 의도적으로 모두 비운 구성 보존, 연결 중복 없음 |
| 16 | 화면 크기 변경 | PASS | 1280×720, 1920×1080, 2400×1080 HUD/창 경계, 대상/지역명 비중첩, 가상 cutout 안전 영역 |
| 17 | 지역 이동 후 HUD | PASS | `_on_map_selected` 실제 지역 전환 후 HUD와 공유 상태 유지 |
| 18 | 모바일 터치/PC 마우스 | PASS | Linux Godot의 실제 GUI 입력 경로에 ScreenTouch/ScreenDrag/Mouse 이벤트 주입. 등록·교환·스와이프·길게 누르기·모바일 back 알림. Android/iOS 실물 기기 확인은 별도 BLOCKED |

이 18행의 PASS는 명시된 검증 범위에 한정한다. 서버 전송, 파티 초대/탈퇴, 혈맹/우편/거래소 거래, 카드 소유/합성, 퀘스트 보상, 실제 모바일 기기는 테스트 통과로 기록하지 않는다.

## 실행 결과

- `tools/test_project.py --timeout 120`: **89개 중 86 PASS**, 원본 실행기 FAIL 3개. [원본 summary](evidence/regression-raw.json), [전 로그](evidence/regression/), [분류](evidence/regression-classified.json).
- `integrated_ui_test.gd`: OpenGL **80 PASS, 1 BLOCKED**, SCRIPT ERROR/ERROR 없음. [항목별 JSON](evidence/integrated-ui-results.json), [실기동 로그](evidence/integrated-gl-final.txt).
- `integrated_interaction_test.gd`: OpenGL **21 PASS**, SCRIPT ERROR/ERROR 없음. [JSON](evidence/integrated-interaction-results.json), [로그](evidence/interaction-gl-final.txt).
- `ui_fidelity_regression_test.gd`: **75 assertions PASS**. 기존 검사의 기준을 낮추지 않고 퀘스트 최소 높이 문제를 수정했다.
- 실제 화면에서 발견한 타겟 제목/지역명 겹침은 위치를 분리하고 3해상도 회귀 assertion을 추가했다.
- `check_resource_integrity.py`: [PASS 로그](evidence/resource-integrity.txt). 원본 팩의 전체 전달 성공을 뜻하지 않는다.

### 원본 팩 때문에 차단된 검사

| 검사 | 누락 입력 | 결과 취급 |
|---|---|---|
| `l1j_map_grid_test` | `data/l1j/maps/raw/4.bin` | 원본 실행기 FAIL → 원인 확인 후 BLOCKED |
| `l1j_png_load_test` | `assets/l1j/preview/a2/items/34.png`, `monsters/ms852.png` | 원본 실행기 FAIL → BLOCKED |
| `l1j_spx_frames_test` | `assets/l1j/candidates/spx_converted/21624-0/`의 SpriteFrames/metadata | 원본 실행기 FAIL → BLOCKED |

이 파일들은 시작한 공개 main에도 설치되어 있지 않다. 이번 작업에서 합성 fixture로 해당 검사를 통과시키거나 원본 자산 상태를 바꾸지 않았다. 기존 GitHub Actions는 `GITHUB_ACTIONS=true`에서 별도의 합성 fixture를 생성하므로 CI 통과를 원본 팩 확인으로 해석하지 않는다.

## 화면과 재현

[캡처 manifest](evidence/captures.json)에 전체 67장의 정확한 크기·SHA-256·게임 상태·로컬 경로·추적된 사본 여부가 있다. 저장소에는 가공하지 않은 대표 PNG 8장을 보존하고, 나머지 전체는 캡처 스크립트/CI artifact로 재생성한다. [1280 HUD](screenshots/hud-1280x720.png), [1920 HUD](screenshots/hud-1920x1080.png), [2400 HUD](screenshots/hud-2400x1080.png), [메뉴](screenshots/menu-1280x720.png), [인벤토리](screenshots/inventory-1280x720.png), [스킬](screenshots/skills-1280x720.png), [퀵슬롯](screenshots/quickslots-1280x720.png), [자동사냥](screenshots/auto-hunt-1280x720.png).

```sh
python3 tools/check_resource_integrity.py --root .
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results --timeout 150
```

실제 디스플레이 또는 Xvfb에서 사용자 저장과 분리된 경로로:

```sh
XDG_DATA_HOME=/tmp/twilight-ui-check /path/to/godot --path . --audio-driver Dummy --script res://tests/integrated_ui_test.gd
XDG_DATA_HOME=/tmp/twilight-input-check /path/to/godot --path . --audio-driver Dummy --script res://tests/integrated_interaction_test.gd
XDG_DATA_HOME=/tmp/twilight-capture TWILIGHT_UI_CAPTURE_DIR=/tmp/twilight-captures /path/to/godot --path . --audio-driver Dummy --script res://tests/capture_integrated_hud.gd
```

[PR #86](https://github.com/zoog136-hash/-/pull/86)의 UI Renewal Validate와 Integration Validate 실행은 GitHub 서버 검증이다. 로컬 결과와 CI 결과를 구분하고, 최종 CI 상태/실행 URL은 PR 및 최종 전달 기록에서 확인한다. main은 병합하지 않았다.

### 기존 L1J CI의 추가 차단

첫 push의 [L1J Runtime and Recovery Validation](https://github.com/zoog136-hash/-/actions/runs/38195156298)은 UI 실행 전 fixture 준비에서 FAIL이다. `make_live_fixture.py`가 이미 추적된 `assets/l1j/verified/items/11.png`를 덮어쓰지 않도록 거부한다. 추가 확인 결과 live bindings의 14개 PNG 중 13개만 있고 `assets/l1j/verified/monsters/18698.png` 및 대응 `f43e8472022391ad54876368b0978308f65d309b857d924f2602a01c09d98d65.l1jpng` 원본 바이트가 없다.

부분 설치를 합성 이미지로 채우거나 원본 보존 검사를 약화하지 않았다. 이 workflow/fixture 도구/자산은 main 그대로 유지하며 이 CI를 PASS로 표시하지 않는다. 누락 원본이 안전하게 제공되거나 원본 팩과 완전히 분리된 합성 테스트 작업 디렉터리가 기존 리소스 정책에 맞게 구축되어야 재검증할 수 있다. 따라서 Windows/Android 해당 CI 작업도 통과로 주장하지 않는다.
