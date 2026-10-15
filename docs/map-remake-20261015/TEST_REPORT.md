# 실제 실행 검증 — 오만 그룹 및 기존 기능

전체 맵 완료 **0/25**, 현재 리니지M의 정확한 복원 **0/25**. 코드·아트 기준은 `f0caf83`, main `8cc6dc6`, PR108 `b9a9db1`이다. PR100의 진행 중인 `53e17ae`는 수정·병합하지 않았다. player/monster/animation 파일은 기준 main과 차이가 없다. 새 PR100 전체와의 결합 검사는 미실시다.

## 실제 Main 검사

[최종 로그](evidence/targeted-rechecks/oman-final-accepted.log), [원본 JSON](evidence/gameplay/runtime.json): Godot 공식 4.7.2 / X11 / Compatibility OpenGL / llvmpipe, 오만 1–10층 **5,951 checks, failures 0, 종료 코드 0**. 실제 플레이·충돌·보스 전투 PNG 30장이다.

| 검증 | 범위와 결과 |
|---|---|
| 맵 로딩·진입 | 독립 A3 101–110 격자, 10층 모두 실제 Main 진입 |
| 좌표 | 헤더 원점·크기·해시, 왕복·반전·배율·저장 상태 128개 검사 PASS |
| 연결성·충돌 | 각 층의 원본 연결 영역, 진입점부터 NPC/포털/보스 구역까지 경로, 열린/닫힌 실제 물리 ray와 통행 규칙 대조 PASS |
| 이동 | 실제 클릭 경로 이동, 진입 지점 발 충돌, 기존 맵 복귀 시 Capsule 복원 PASS |
| 출현 | 현재 DB 종류·수량·타이머 보존, 원본 구역 셀 안의 home 위치·통행·예약 영역 검사 PASS |
| NPC·포털 | 기존 안내 NPC 10곳 대화, 실제 근접 포털 트리거 50개 및 도착 발 위치 PASS |
| 전투 | 기존 배우/DB/AI의 보스 10종, 정상 플레이어 공격과 보스 마커에 의한 실제 피해 PASS |
| 보스 상태 | 생존 HP, 처치 단계, 절대 재출현 시각 저장·복원 PASS; 기존 86,400초 조건 보존 |
| 사망·재출현 | QA 직접 치명 피해와 테스트 시계 만료로 기존 처리 경로 검사; 자연스러운 24시간 대기는 미실시 |
| 바닥 드롭 | 보스 처치가 인벤토리에 즉시 아이템을 넣지 않음 확인; 미대응 드롭 등급 경고와 아이템별 실제 드롭 전수 검증은 남음 |
| 그래픽 | 실제 바닥·경계·배우 출력과 이미지 캡처 확인. 구조물 의미와 PR108 수준의 벽/난간/기둥 아트는 미완료 |
| 원작 비교 | PC 원본 격자이며 현재 M 기준점 0개. 현재 M 정확 복원 PASS가 아님 |

보스 구역은 경로 존재를 검사한 후 QA 좌표 이동으로 접근했다. 검증용 레벨/HP를 설정했다. 입구부터 보스까지의 수동 완주, 자연적인 처치 시간·드롭 확률·24시간 재출현의 검증 영상으로 해석하지 않는다.

## 실패와 수정 이력

- `checkpoint-logs/oman-final.log`, `oman10-headless.log`: 수정 전 아덴 복귀에서 정지, 보고서 없음. **FAIL_TIMEOUT**으로 보존한다.
- 충돌 쌍 제거를 추적한 뒤, 포털 코루틴이 물리 프레임에서 재개된 직후의 QA 즉시 맵 변경을 다음 process 프레임으로 옮겼다. 충돌 격자/조건/actor/animation은 변경하지 않았다.
- [수정 전 묶음](evidence/targeted-rechecks/full-group-before-boss-observation-fix.json): 5,951개 중 9층의 보스 공격 관찰 1개 실패. 리치가 AUTO 추격 동안 후퇴했다.
- [9층 재검사](evidence/targeted-rechecks/oman09-after-boss-observation-fix.json): 정지한 플레이어를 상대로도 정상 AI를 관찰하여 830개 PASS. 실제 보스 마커·피해 조건은 유지했다.
- 이후 동일한 최종 코드로 오만 10층 전체 묶음을 실행하여 위 5,951개 PASS를 확인했다. 실패 로그를 성공 로그로 덮어쓰지 않았다.
- 초기 셰이더 임포트의 에디터 로컬 소켓 오류는 실행 샌드박스 권한 문제였다. 네트워크 권한이 있는 환경에서 `pr108-material-import-r2.log` 재실행은 오류 없이 종료했다.

## 기존 기능 회귀와 검사 범위

초기 전체 실행은 [원본 summary](evidence/checkpoint-logs/full-private/summary.json)에 **142 PASS / 15 FAIL / 3 SKIP / NOT_RUN 0**으로 보존했다. 모든 실패를 숨기고 전체 PASS로 바꾸지 않는다. 이후 변경과 실패 대상만 재검사했다.

| 대상 | 최신 결과 | 의미 |
|---|---|---|
| monster_world | 9,915 checks PASS | 실제 현재 게임 DB·25맵 배치, 3개 오만 폭젠 반경 240/240/220px와 24마리 보존 |
| hunting_paths | 14,603 checks PASS | 기존 15개 맵 경로와 새 A3 10층 분기, 구간/예약/물리 규칙 |
| inventory / consumable / ground_alpha | PASS | main 수정 및 source 귀환 규칙 보존, 아이템/회복/알파 검증 |
| 기존 기하 구조 검사 7개 | 모두 PASS | 명시적인 `--legacy-map-layouts` fixture, 기존 assertion 보존. 새 A3 아트 완료 판정에 사용하지 않음 |
| reference_expansion | 이전 렌더 192 PASS; 새 바닥 이후 headless 142 PASS | 25개 ID의 렌더/atlas/스폰/미니맵 공통 연결; 실제 화면은 별도 PNG |
| 원본 좌표 | 기존 66 / 확장 128 PASS | 판본·축·원점·정밀도·기존 보스 상태 |
| 동적 문 | 14 PASS | 실제 A3 층 위의 **합성 QA 문**. 원본 문 존재/위치의 증거가 아님 |
| runner 계약 | 최종 23 PASS | 프로세스 실패·타임아웃·SKIP·증거·저장 경로 격리 처리 |
| L1J grid/png/spx 3개 | 합성 fixture에서는 PASS | 원본 리소스가 없는 현재 설치의 원본 검증은 여전히 불가 |
| 원본 catalog/world/source-first 3개 | SKIP | 1,000개용 별도 런타임 팩 미설치. 이번 10층 팩과 구분 |
| 리소스 무결성 | 723 WebP / 41,442프레임 PASS | 기존 Git 포함 아트만 해당. 추가 PR108 석판은 별도 아트 해시로 실제 추적·바이트 확인 |

초기 15개 실패 중 L1J 원본 리소스 3개는 원본 통합 완료로 바뀌지 않았다. `공포의 뱀파이어:영웅`, `우그누스:전설` 등의 기존 미대응 드롭 항목은 임의 대체하지 않았다. A3 ZIP 자체는 SHA/CRC를 검증했지만 나머지 다섯 ZIP이 현재 환경에 설치되지 않아 전체 `--source-dir` 검사는 실패 상태다.

## 화면과 성능

[25개 맵 PNG 100장](evidence/current-diagnostic/captures.json)은 기존 Main을 정지한 진단 렌더다. 오만 10개는 새 격자, 나머지 15개는 기존 맵이다. [동일 카메라 비교 25쌍](evidence/COMPARISON.md)은 카메라 픽셀·줌·뷰포트를 검증했으며 원작 지형 기준점 정합 비교가 아니다. PR108 실제 샘플은 [별도 12개 검사 및 PNG 4장](evidence/pr108-baseline/runtime_results.json)을 보존했다.

[성능 JSON](evidence/performance/streaming-uncontended.json)은 다른 Godot 프로세스가 없는 상태의 10층 측정이다. 각 진입/원거리에서 실제 draw interval 60개씩, QA 좌표 이동으로 청크 교체를 관찰했다. 청크 상한·해제·재방문 메시 동일성은 10층 모두 PASS다. 소프트웨어 OpenGL이고 이동 속도·실기기 합격 검사는 아니다.

- 동기 맵 진입 320.1–464.4ms, 프레임 간격 중앙값 25.4–48.7ms.
- Godot static memory 287.4–302.9MiB. GPU/전체 프로세스 RSS를 모두 포함한 수치가 아니다.

## 남은 완료 조건

[다운로드 팩의 재복원](evidence/fresh-restore/restoration.json): `f0caf83`의 추적 파일이 깨끗한 격리 체크아웃에 Drive에서 재다운로드한 v2 ZIP을 설치했다. 원본 격자를 재생성하지 않았으며, 새 Godot 임포트 종료 코드 0, 실제 Main 오만 1층 **180 checks / failures 0 / 종료 코드 0 / PNG 3장**을 확인했다. 같은 호스트의 새 체크아웃 검증이며 다른 장치·Android 검증으로 집계하지 않는다.

오만 10층의 구조물 의미·층별 아트, 현재 M 기준점과 스폰 근거, 아덴/S32의 지형 의미/장거리 이동, 지배 정상 및 나머지 13개 구역의 판본·지형, 미대응 드롭, Android·Windows GPU·실제 기기 성능이 남았다. 15개 맵은 리메이크 미적용이다. 이 때문에 기술적 맵 완료와 시각적 원작 일치 완료 모두 0/25로 집계한다. Draft를 유지하고 main으로 병합하지 않는다.
