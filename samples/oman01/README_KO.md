# 오만 1층 A3 기반 2D 샘플

기준 main: `a7c0390a698e43fde61ec6deea867143ead59484`.
이 샘플은 기존 `Main.tscn`, 플레이어, 몬스터, 전투, HUD를 사용합니다. 별도 3D 게임이나 이미지 모형이 아닙니다.

## 현재 상태를 구분합니다

- 대화 작업 환경에서 A3 101번의 원본 해시와 192×192 배열을 확인했습니다.
- 원본 8방향 연결 규칙으로 이동 연결 칸 16,868개와 연결 성분 1개를 확인했습니다.
- 샘플 빌더·2D 렌더러·기존 게임용 진입/검사 코드를 추가했습니다.
- **Godot 실제 샘플 화면·보스 전투 검증은 완료했다고 표시하지 않습니다.** `evidence/runtime_results.json`과 실제 PNG가 생성되어야 합니다.
- 기존 main, PR #100, 원래 저장 폴더는 변경하지 않습니다.

## 실행

원래 체크아웃과 다른 새 폴더를 지정합니다. 이미 존재하는 폴더는 덮어쓰지 않습니다.

```sh
python3 samples/oman01/build_sample.py --root /path/to/TWILIGHT --a3 /path/to/a3.zip --output /path/to/TWILIGHT_oman01_sample
godot --headless --editor --path /path/to/TWILIGHT_oman01_sample --quit
godot --path /path/to/TWILIGHT_oman01_sample --script res://samples/oman01/run.gd
```

자동 화면·이동·충돌·전투 검사:

```sh
godot --path /path/to/TWILIGHT_oman01_sample --script res://samples/oman01/run.gd -- --sample-capture
```

Linux 화면 없는 실행 환경에서는 `xvfb-run -a`를 실제 렌더 명령 앞에 사용합니다. `--headless` 실행은 실제 화면 검사로 계산하지 않습니다.

## 원본과 임시 설정

원본 격자는 `a3.zip!data/mapcache/101.map`이며 원점은 `[32704,32704]`입니다. 행 우선 SHA-256은 `5e0ea64c017c6d09a8df12d4e7aa267f48a4eb150f10cd6429a199d6625e1aca`입니다. 다른 판본을 자동 대체하지 않습니다.

원본 출입 트리거 `[32724,32799]`와 NPC 기준점 `[32800,32800]`은 이번 캐시에서 연결되지 않는 칸입니다. 샘플 진입·안내인 위치는 가까운 연결 칸으로 별도 선택하고 원본 복원 위치로 주장하지 않습니다.

A3 보스 행 150은 비활성 제니스 퀸 분신 설정입니다. 샘플은 기존 TWILIGHT의 왜곡의 제니스 퀸 전투 레코드 1개와 일반 몬스터 12개를 시험용으로 사용합니다. 보스 180초·일반 30초 재출현은 로컬 샘플 설정이며 실제 리니지M의 시간표나 정확한 폭젠 범위가 아닙니다. 원래 몬스터 DB·드롭 테이블은 변경하지 않습니다.

석조 바닥은 기존 프로젝트 `assets/maps/aden/terrain.png`를 재사용합니다. 철제 난간·기둥은 닫힌 격자 경계에 2D 도형으로 배치한 새 샘플 소품입니다. 원본 타일 그래픽 복원이나 모든 통행 불가 칸의 물체 종류를 확정한 결과가 아닙니다. 충돌은 기존 `OriginalPlayableField`의 원본 방향별 이동 가드를 사용합니다.

참고 화면: https://www.inven.co.kr/board/lineagem/5056/12423 (2019년 플레이어가 게시한 1층 난간·기둥 화면; 현재 판본의 정확한 좌표 근거로 사용하지 않음).

## 완료 판정

소스 검증, 엔진 import, 실제 입력 이동, 닫힌 방향 거절, 보스 생성, AUTO 전투 피해, 실제 화면 PNG를 분리합니다. 파일이 없거나 자료가 빠진 경우 FAIL/BLOCKED로 남기며, 합성 지도나 옛 캡처를 새 샘플 결과로 제출하지 않습니다. Android 조작, NPC 서비스 전체, 보스 처치·드롭·재출현·저장 회귀, 최신 리니지M 배치 대조는 후속 검증 대상입니다.
