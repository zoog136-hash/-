# TWILIGHT 8방향 애니메이션 재구축

## 기준 / 작업 보존
- 기준 main: `434b904d957fd2146b6d2e73325693a402028035` (2026-10-13 원격 재확인).
- 작업: `feature/twilight-animation-20261013`, `/workspace/twilight-animation`.
- 이전 `feature/twilight-remake-20261013`, PR #98, `1216c00756fe602173fb7346a452c9586d9f5754` 및 미커밋 파일은 별도 checkout에 보존. 이 작업에 전투/맵 변경을 가져오지 않음.
- 신규 PR: 아직 없음. main 병합 금지.

## 1단계 조사
- `Main.tscn` → `world.gd` → `player.gd` / `monster.gd` → 기존 `animation_catalog.gd`, `actor_motion.gd`가 실제 표시/공격 마커를 관리.
- 기사 기본 외형 `assets/sprites/classes/warrior.png`: 740×580, 5열×5행, 4방향 이동과 공통 공격. 8시점 원본이 아님.
- 일반 몬스터 `해골 근위병`: 기존 DB 및 맵 스폰, 검 근접 공격. 기존 family plate + shader 자세 변형. 전용 8시점 모션 없음.
- 소스 키트 SHA-256 `99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98`의 두 본체 21624/21653은 PC 계열 남녀 용기사. 기사/해골 대응 및 재배포 권리 미확인으로 해당 ID에 임의 적용하지 않음. 기존 외부 검증/추출 기록 재사용.
- 기존 재생기는 방향별 SpriteFrames, 원본 duration 및 타격 프레임 샘플링을 지원. 별도 재생기를 만들지 않고 실제 연속 프레임을 연결할 예정.
- 기사 + 해골의 게임 내 이동/공격 시각 검증 전 전체 ID 확장 금지.

## 기준 검사
- 편집 전 `python3 tools/check_resource_integrity.py --help` 및 `python3 tools/check_resource_integrity.py --root .`: PASS, 723 atlases / 41442 cells / 233420026 bytes. 이 수치를 원본 연속 모션 수로 주장하지 않음.
- Godot 4.7.2 + Compatibility 유지. `tools/test_project.py` 유효. 동일 main의 이전 전체 기준선 122 PASS / 14 FAIL / 3 SKIP 재사용; 이번 애니메이션 변경은 관련 회귀 및 실제 렌더로 검사 예정.
- 초기 리소스 임포트 캐시는 동일 main checkout에서 복사. 새 파일은 실제 Godot import로 검증 예정.

## 미완료 / 다음 실행
- Flare Game `af6eee6d339ac98011864bfe89da837fe7769c28`의 공개 2D PNG를 검토 후 변환. CC BY-SA 3.0, 출처/이용 조건/해시를 `assets/actors/eight_direction/`에 포함.
- 검/방패를 든 흑기사 `transform:46`, 기본 외형 `class:0`, 일반 몬스터 `해골 근위병`에만 연결. 2본체 × 8방향 × (대기 4 + 이동 8 + 공격 4) = 256개 고유 프레임. 대기 왕복 재생의 재사용 프레임은 중복 집계하지 않음.
- 원본 2D 오프셋, 방향별 장비 레이어 순서 보존. 방향 대응은 8시점 이미지로 확인. 기존 공통 재생기를 사용하며 이 대상에만 root 흔들기/회전/셰이더 가짜 방향을 제거.
- 최초 import는 편집기 XDG_CONFIG_HOME 미설정 오류 발생. 쓰기 가능한 환경변수와 동일 main의 texture `.import` 메타데이터까지 복원한 수정 명령으로 종료 코드 0, ERROR 없음. 로그: `/workspace/evidence/animation-20261013/import-fixed.log`.
- `eight_direction_animation_test.gd`: 930 assertions / 0 failures. `actor_motion_test.gd`, `authored_state_motion_test.gd`, `monster_motion_test.gd`: PASS. 로그: `/workspace/evidence/animation-20261013/`.
- 실제 Main 캡처 실행 중: `TWILIGHT_CAPTURE_DIR=/workspace/evidence/animation-20261013/gameplay python3 /workspace/evidence/baseline/run_gl.py --root /workspace/twilight-animation --script res://tests/capture_eight_direction_play.gd --name animation-native-first --timeout 200 --movie`.
- 피격/사망, 전체 확장, Android, 사용자 시각 승인 모두 미완료/미검증.
