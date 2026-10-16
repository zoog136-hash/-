# PR #121 — 4개 지역 독립 2D 샘플 (24맵 중 4개 대표)
2026-10-16 조사 참고 자료에 근거한 **실행 가능한 별도 TWILIGHT Main.tscn 테스트용 지형**입니다. 원작의 맵 복원 완료가 아닙니다.

## 대상
| ID | 대상/연구 특징 | 원작 고증 상태 |
|---|---|---|
| domination_summit | 지배의 탑 정상: 확대된 성채 접근로, 다양한 길 후보, 보스 광장 | 일본 NC 2026.03.11 확대 공식 확인, 현재 한국판 전도/좌표 미확인 |
| faith_04 | **신념의 탑 4층 유지**: 자주색 카펫/회색 석판/청록빛 기둥과 보스실 | NC 일본 4층 라즈엘 플레이 화면 근거, 한국판 평면도 미확보 |
| albino_03 | 알비노 분지 3구역: 폭포↔유황 상대 연결을 참고한 유황 지대/진입 통로 | NC 한국 2024 유황 추가, 세 지역 원본 경계·좌표 미확보 |
| escaros_01 | 에스카로스 1구역: 회색 협곡, 길목, 체크포인트/성문 경유 | 2022 지도, NC 일본 5석상/진행 규칙, 실제 맵 분할 방식 미확정 |

**알비노 4구역(albino_04)은 제외**했고 **신념 4층(faith_04)은 포함**했습니다.

## 오만 1층 샘플과 동일한 통합 원칙
- 기존 **TWILIGHT Godot 4.7.2 Compatibility/OpenGL Main.tscn + Player + HUD + Monster DB**를 실행합니다.
- 기존 AuthoredRemakeField → AuthoredRemakeRenderer의 실제 **1024px 지형 청크·원래 2D 아틀라스·충돌 스트림·32px AStar 경로**를 그대로 사용합니다.
- 4개 테스트용 맵은 별도 생성된 새로운 지형 경계/방/길/장애물 데이터로 교체합니다. **기존 25맵의 폴리곤을 새 지형인 것처럼 복제하지 않습니다.**
- 4개 지역의 지형은 **참고자료 기반 신규 설계 샘플**입니다. A3 원본 PC 지도나 2026 리니지M 정확한 좌표로 주장하지 않습니다. 기존 TWILIGHT의 보스/몬스터 DB ID를 전투 *시험용*으로 재사용하며 원작 스폰 좌표·개체 구성을 주장하지 않습니다.
- NC 원작 타일이나 타인 소유 이미지 바이트를 포함하지 않습니다. 본 게임에 이미 연결된 TWILIGHT 자체 제작 아틀라스를 사용합니다.
- 이미 설치한 맵 25개의 데이터, PR100/120 코드, main, 사용자 저장을 바꾸지 않습니다. 샘플 생성본은 외부의 별도 새 폴더에서만 사용합니다.

## 실행 (원본 프로젝트가 로컬에 있는 경우)
전체 TWILIGHT 저장소 복사본을 이미 준비해야 하며, 대상 폴더는 **아직 존재하면 안 됩니다**.

    python3 content/newmaps/lineagem_reference/samples/build_four.py --self-test
    python3 content/newmaps/lineagem_reference/samples/build_four.py --root /path/TWILIGHT --output /path/TWILIGHT_PR121_4SAMPLE
    godot --headless --editor --path /path/TWILIGHT_PR121_4SAMPLE --quit
    godot --path /path/TWILIGHT_PR121_4SAMPLE

일반 게임 실행에서 **지도 메뉴**로 위 4개를 선택하면 새 샘플 지형으로 진입합니다. 다른 기존 지도는 원래 데이터 상태로 남습니다. 샘플은 전용 저장 폴더를 사용합니다.

자동으로 4개 샘플에 진입하여 원래 캐릭터/지형/경로/물리/카메라를 확인:

    godot --headless --path /path/TWILIGHT_PR121_4SAMPLE --script res://content/newmaps/lineagem_reference/samples/run_four.gd

실제 화면 PNG 8장 (입구/보스 각각; 별도 디스플레이가 있는 환경):

    godot --path /path/TWILIGHT_PR121_4SAMPLE --script res://content/newmaps/lineagem_reference/samples/run_four.gd -- --capture

Linux CI는 xvfb-run을 사용합니다. headless로 PNG가 생성되지 않으면 실제 렌더링 통과로 계산하지 않습니다.

## 검증 상태
- Python 자체검사: 구역별 새 지형, 안전 입구에서 보스까지 실제 연결성, 기존 폴리곤 복제 없음, 알비노4 제외.
- Godot 검사: 엔진 import, 본 게임 4맵 진입, AStar 입구→보스, 물리 스트리밍, 실 캐릭터 이동, **실제 2D PNG 8장**. **반드시 CI 출력 결과를 따로 확인**해야 PASS입니다.
- 산출: content/newmaps/lineagem_reference/samples/evidence/build_provenance.json, runtime_results.json, PNG. evidence는 독립 복사본의 실행 결과이며, 커밋에 실제 화면 없이 ‘완료’라 쓸 수 없습니다.
- 기존 몬스터/보스의 정확한 원작 출현, 전투 밸런스, Android GPU, 실 기기 24맵 전환 및 2026 원작 지도 동일성은 **NOT_VERIFIED / NOT_RUN**.

자료 출처 ID/URL은 상위 SOURCE_CATALOG_20261016.json와 RESEARCH_ADDENDUM_20261016.md에 기록돼 있습니다. 원작 화면과 디자인의 비교는 **참조 목적으로만** 수행합니다.
