# 소모품 순차 보완 — 2026-10-13

기준 main: `02842fdd123bf14db46bed91a3cb68c36fa8b9b1`.
작업: `feature/consumables-stepwise-20261013`. main 및 PR #99/#100은 수정하지 않는다.

## 이번 1·2단계

- HP 자동 사용 기준 기본 70%, 일반 즉시 MP 30%, 긴 재사용 MP 20%. 모두 사용자 설정(5–95%). 긴 재사용 MP 자동 사용은 별도 허용 기본 OFF. 이것은 TWILIGHT 안전 기본값이지 원작 확정값이 아니다.
- AUTO로 등록한 슬롯만 사용. 사망·기절·공포·재사용 대기·수량 검사를 유지. HP 우선, 같은 종류에서는 슬롯 순서 유지, 0.2초당 성공한 소모 한 번. 거부된 아이템이 뒤의 유효 슬롯을 막지 않는다.
- 설정은 기존 `ui_preferences.consumable_auto`에 저장. 잘못된 타입/누락/범위를 정규화하고 다른 저장 정보는 보존한다. 환경 설정의 실제 컨트롤 → HUD 신호 → 월드 판정으로 연결한다.
- 요리의 근거리군에 다크엘프·투사·암흑기사·신성검사·광전사·사신·뇌신·마검사, 원거리군에 총사를 추가해 13직업을 지원한다. 마법사는 기존 칠면조를 유지한다. 회복량·회복 간격·요리 수치·30분 지속·중복 그룹·30분 MP 쿨다운은 변경하지 않는다.
- 요리의 기존 4직업 목록은 2017-06-21 공식 파워북에서 확인된다. 13직업 확장은 TWILIGHT 호환 정책이며 한국 현행 원작의 확정 사용 조건으로 표기하지 않는다.
  출처: https://rc-wstatic.plaync.co.kr/lineagem/guidebook/game_item_item_general.html

## 검사

`python3 tools/check_resource_integrity.py --root .`
`Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit`
`Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/consumable_auto_safety_test.gd`
`Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/consumable_smoke_test.gd`

각 테스트는 별도 XDG_DATA_HOME에서 실행하며 실제 사용자 저장을 쓰지 않는다. 실제 결과는 Actions 로그 및 tested-sha로 판단한다. 검사 파일 작성만으로 통과라고 보고하지 않는다.

## 다음 범위 / 미완료

3. 품목별 버프 아이콘 및 누락 표시 개선. 정상 연결된 교체 이미지는 보존.
4. MP 물약·요리·이동 주문서의 재보급 경로 확인/보완. 가격을 원작 수치로 임의 단정하지 않음.
5. 소모품별 사용 연출과 소리. 원작 프레임/소리를 확보·검증한 것으로 오인시키지 않음.

이번 코드에 제3자 이미지, 소리, 원본 팩은 추가하지 않는다. 삭제된 해독제/상태이상 해제 물약은 복구하지 않는다. 원본 리소스 전체 통합, Android 실행, 전체 시각 검수는 완료 범위가 아니다.
