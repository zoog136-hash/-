# PR137 후속: Monster World 캡처 실패 수정

## 기준과 실제 실패

- 기준 main: `ecac4faafdf34a6dcbf60b101accc5911d1dd39a`.
- PR137 HEAD: `01bfd56578abd1f835e921fcd488caa8e1e4f981`.
- 실패 run: https://github.com/zoog136-hash/-/actions/runs/39553966369
- 실패 artifact: `12331775819`; 다운로드 ZIP SHA-256 `5572ef7c1edbbf0b6a3d8b03f537ce8d7d39cc1cae5a0594eed68f8aa9c6cb35`.
- 원본 `capture_monster_world.gd` Git blob `6e1dd9d6be8c021d99e34732ed17492df370de66`와 로컬 재구성 바이트 일치를 확인했다.

로그의 실패는 `boss-oman_08`의 본체 표시, HP 패널 표시, HP 이름 세 항목이다. 실제 PNG는 입장 안전 광장을 보고 있고, 보고서의 HUD 이름은 이전 층 아이리스다. 그런데 원래 보고서의 `on_screen` 및 `overlay_closed`는 검사 결과와 무관하게 항상 `true`였다.

원래 `land_near()`는 반경 170px의 여덟 점만 검사하고, 전부 실패해도 진입 위치를 그대로 둔 채 계속한다. 해당 실행에는 후보별 진단 로그가 없으므로 실제 모든 후보의 거부 사유를 과거 로그만으로 단정하지 않는다. 이 명확한 무결과 처리 결함과 허위 성공 보고를 수정하고 실제 동일 캡처의 재실행으로 검증한다.

## 수정 범위

- 기존 여덟 점을 우선 유지한 뒤 여섯 반경/32방향 및 주변 실제 내비게이션 셀 중심을 탐색한다. 거리 상한, 통행, 발판, 안전 구역, LOS 및 포털 트리거 검사를 모두 통과한 위치만 사용한다.
- 유효 위치가 없으면 `Vector2.INF`와 명시적 실패를 반환한다. 맵/보스 캡처 호출자는 즉시 실패 처리하고 입장 위치로 조용히 대체하지 않는다.
- 카메라 검사 직전 AUTO와 오래된 클릭 경로/속도만 정리한다. 보스 이동, 맵 충돌 수정, 포털 비활성화는 하지 않는다.
- 원래 본체/HP 패널/이름 검사를 모두 유지하고 실제 프레임 후의 관측값과 좌표를 보고서에 기록한다. 실패를 `true`로 기록하지 않는다.
- 단위 테스트는 원래 알고리즘의 좁은 바닥/각도/셀 누락을 재현하고 수정 탐색, 충돌·안전 구역·LOS·포털 거부, 경계, 무결과, 유한 반복을 검사한다.
- 기존 Monster World 전체 회귀 workflow는 변경하지 않는다. 별도 보조 workflow에서 단위 테스트 → 실제 프로젝트 import/navigation/boot → 기존 전체 OpenGL 맵·폭젠 AUTO·보스 10층·갤러리 캡처를 먼저 실행한다. 검사 삭제/skip/continue-on-error는 추가하지 않는다.

## 검증 구분

로컬에는 Godot 실행 파일이 없어 실제 GDScript 실행 또는 OpenGL 통과를 주장하지 않는다. 원본 blob 일치, 변경 범위와 기존 검사 보존, YAML/셀 탐색의 독립 Python 산술 점검은 엔진 검증과 구분한다. 실제 판정은 새 HEAD의 GitHub `Monster Capture Regression` 및 기존 `Monster World Validate` 결과를 사용한다.

PR122, PR143, main, 게임 스탯·스폰·저장·아트는 수정하지 않는다. CI 결과가 나오기 전에 완료/전체 성공으로 표시하지 않는다.
