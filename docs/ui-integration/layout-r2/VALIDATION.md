# 현재 UI 통합본 검증

> 이후 main에 PR #59 스킬 시스템이 추가됐다. 이 기록은 아래 소스의 보존된 결과이며 후속 스킬 통합 결과로 대체 집계하지 않는다.

실행 소스 `b215b20172fea1a2989a9b1fc3adebe950da7d8f`, 기준 main `cfbf0fb4307fbb6694163504eb49692f3e3391bf`. Godot 4.7.2, Linux OpenGL llvmpipe. 물리 휴대폰/Windows GPU 테스트와 구별한다.

## 처음 요청한 18개 시나리오

| # | 시나리오 | 결과 | 실제 확인 범위 |
|---|---|---|---|
| 1 | 게임 진입과 HUD | PASS | 실제 클래스 선택 후 월드, 상태/효과/미니맵/슬롯/전투/메뉴 |
| 2 | 상태 실시간 변화 | PASS | 피해 HP, 처치 경험치, 장착 능력치, MP |
| 3 | 인벤토리 열기/닫기 | PASS | 실제 GUI 마우스 입력 |
| 4 | 장착/해제 | PASS | 실제 개별 장비 ID, 공유 상태, 잠금 판매 차단 |
| 5 | 인벤토리 슬롯 등록 | PASS | 실제 등록 UI → 오른쪽 3그룹 슬롯, 직접 드래그 |
| 6 | 스킬 슬롯 등록 | PASS | 실제 직업 스킬 상세 → 슬롯 → 선택 상세 복귀 |
| 7 | 슬롯 그룹 전환 | PASS | 좌우 각각 3그룹, 저장된 페이지 복원 |
| 8 | 슬롯 스킬 사용 | PASS | 실제 시전과 MP 차감 |
| 9 | 쿨타임/MP | PASS | 실제 남은 시간, 시각적 가림, MP 부족 |
| 10 | 자동사냥 ON/OFF | PASS | 기존 사냥 활성화/대상 탐색/수동 중지, 실제 AUTO 캡처 |
| 11 | 퀘스트 상세 | BLOCKED | 최신 main PR #85가 기능을 제거. 부재 검사는 통과했지만 퀘스트 동작 PASS로 세지 않음 |
| 12 | 월드맵/지역 선택 | PASS | 실제 지역 선택·상세·이동 명령 |
| 13 | 채팅 | BLOCKED | 최신 main의 PvE 범위에서 제외. 실제 전투/시스템 로그의 열기·실시간 갱신은 별도 PASS |
| 14 | 메뉴 이동 | PASS | 30개 진입점 중 비종료/비클래스 경로, 뒤로가기, 필터/선택 복원. 미지원 화면은 서비스 구현 PASS가 아님 |
| 15 | 설정·저장 복원 | PASS | 좌표 표시 재진입, 24칸 슬롯 저장/로드, 자동사용/페이지 상태 |
| 16 | 화면 비율 | PASS | 1280×720 / 1920×1080 / 2400×1080, HUD·창 경계, 타겟/지역명 비중첩 |
| 17 | 지역 이동 후 HUD | PASS | 실제 지역 전환과 기존 공유 HUD 유지 |
| 18 | 터치/마우스 | PASS / BLOCKED | Linux Godot 실제 GUI 이벤트 주입 PASS. 물리 휴대폰 실행 BLOCKED |

## 실제 실행 결과

- 주요 UI OpenGL: **79 PASS / 1 BLOCKED**. [로그](evidence/pve-integrated-opengl.txt).
- 카드 정책: **PASS**. [로그](evidence/pve-card-policy.txt).
- 화면 캡처: **73장**, 3해상도, [로그](evidence/pve-capture-opengl.txt), [manifest](evidence/captures.json). 대표 PNG 12개는 변경 전 main 3장을 포함한다.
- 오른쪽 패널 OpenGL **46 PASS**, 제스처/팝업 **21 PASS**, 저장 보호 **6 PASS**, 기존 UI fidelity **87 assertions PASS**. [항목별 소스·로그 연결](evidence/pve-source-snapshot.json).
- 전체 118개 검사: 원본 실행기 **111 PASS / 4 FAIL / 3 SKIP**. 옛 메뉴 버튼 수 검사 수정 후 해당 검사 재실행 PASS를 반영한 최종 분류는 **112 PASS / 0 FAIL / 6 BLOCKED**. 원본 팩 3 FAIL와 3 SKIP는 BLOCKED다. [원본 결과](evidence/pve-regression/raw.json), [분류·재검사 근거](evidence/pve-regression/classified.json), [전체 로그](evidence/pve-regression/).

원본 맵 타일·PNG·SPX 팩이 없으면 해당 검사는 BLOCKED로 기록하고 원래 FAIL/SKIP 로그도 보존한다. 검사 대상을 합성 데이터로 바꾸거나 실패 메시지를 제거하지 않는다.

## 재현

```sh
python3 tools/check_resource_integrity.py --root .
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results --render-visual-tests --timeout 300
XDG_DATA_HOME=/tmp/twilight-ui-test /path/to/godot --path . --audio-driver Dummy --script tests/integrated_ui_test.gd
XDG_DATA_HOME=/tmp/twilight-drawer-test /path/to/godot --path . --audio-driver Dummy --script tests/gameplay_drawer_test.gd
XDG_DATA_HOME=/tmp/twilight-guard-test /path/to/godot --path . --audio-driver Dummy --script tests/ui_source_save_guard_test.gd
XDG_DATA_HOME=/tmp/twilight-captures TWILIGHT_UI_CAPTURE_DIR=/tmp/twilight-captures/png /path/to/godot --path . --audio-driver Dummy --script tests/capture_integrated_hud.gd
```

OpenGL 명령에는 실제 디스플레이 또는 Xvfb/Xorg가 필요하다. 이 환경에서는 `DISPLAY=:9`, `LIBGL_ALWAYS_SOFTWARE=1`을 사용했다. 테스트 사용자는 각 실행마다 분리한다.
