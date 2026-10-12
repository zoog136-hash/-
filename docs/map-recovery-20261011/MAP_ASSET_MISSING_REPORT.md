# 맵 자료 누락 및 적용 제한

원본 지형의 실제 게임 적용: **0/25, 미완료**.

`a2(1).zip`은 이번 환경에 전달되지 않았다. 나머지 16개 첨부를 검사했다.

S32가 참조하는 타일 ID: 2,683개. 발견한 .til / tile.pak / tile.idx: 0개.
타일 ID와 통행 바이트는 배경 이미지가 아니다. 원본 배경을 생성했다고 집계하지 않는다.

다른 판본의 통행 바이트는 출처별로 보존하며 A3 규칙으로 자동 실행하지 않는다.

| 게임 맵 | 대응 후보 | 상태 |
| --- | --- | --- |
| oman_01 | 101 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_02 | 102 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_03 | 103 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_04 | 104 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_05 | 105 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_06 | 106 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_07 | 107 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_08 | 108 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_09 | 109 | 배경·판본·좌표·NPC/포털 미검증 |
| oman_10 | 110 | 배경·판본·좌표·NPC/포털 미검증 |
| domination_summit | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| escaros_01 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| escaros_02 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| escaros_03 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| escaros_04 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| escaros_05 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| albino_01 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| albino_02 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| albino_03 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| albino_04 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| faith_01 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| faith_02 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| faith_03 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| faith_04 | 미확인 | 배경·판본·좌표·NPC/포털 미검증 |
| aden_world | 4 | 배경·판본·좌표·NPC/포털 미검증 |

## 파싱 보류 원본

- `12-a3.zip!data/client_maps/normal/4/tempseg.s32`: invalid declared_tile_ids count (SHA-256 `fe069e8fa6771cc248a0b3eb2cb8a5fe24cdbc36651153f26637cc98ff26af1e`)
- `12-a3.zip!data/client_maps/halloween/4/tempseg.s32`: invalid declared_tile_ids count (SHA-256 `fe069e8fa6771cc248a0b3eb2cb8a5fe24cdbc36651153f26637cc98ff26af1e`)
