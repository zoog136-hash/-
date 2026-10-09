# 실제 검증 증거

코드 HEAD: 98c9e5f693df280f1543a6c21133095eed9a4812

검사 checkout: 65b8879f217cb03f4fb83e2ffb7ed6c8b72e1db7

검사 tree: dcafd584c3a3af57248cda41476614485d4eb47d

[GitHub Actions 실행](https://github.com/zoog136-hash/-/actions/runs/37918099919) · [전체 PNG/로그 ZIP](https://github.com/zoog136-hash/-/actions/runs/37918099919/artifacts/11610324668)

실제 Godot 4.7.2 전체 회귀 **53/53 passed**. 25개 맵, 폭젠 4곳 AUTO 처치·24마리 복구, 오만 보스 10종, 전체 318종의 다섯 상태를 실제 Compatibility OpenGL에서 실행했습니다. 지역/폭젠/보스/갤러리 103장과 군집 3장, 총 **106장**이 생성됐습니다. PNG 원본은 편집하지 않았으며 전체 해시는 evidence.json에 있습니다.

같은 러너에서 최신 main의 PR #46·#48을 포함한 HUD 변경 전 커밋 `1b53a3ea56ef61bd69af5d2b1649ac325b52ca33`과 동일한 192회 입력을 비교했습니다. 실제 남은 HP와 표시 상한은 같고, HP만 바뀌는 입력의 전체 HUD·장비 동기화·능력치 재계산은 0회입니다. 원본 수치는 [HUD 비교](logs/hud-comparison.json), 장비·버프·사망·저장 검사는 [로그](logs/combat_hud_test.txt)에 있습니다.

이 증거를 기록한 뒤 자동 문서 커밋만 브랜치에 추가됩니다. 검사한 코드는 위 HEAD/checkout으로 구별하며 문서 커밋을 다시 실행한 게임 검사로 주장하지 않습니다.

## 현재 고밀도 전투

GPU: llvmpipe (LLVM 20.1.2, 256 bits). 120프레임 워밍업 뒤 240프레임을 측정했습니다. HP/AC/공격 유형을 제어한 QA 전투이며 일반 플레이 밸런스 검사가 아닙니다.

| 개체 | 프레임 중앙값 ms | 프레임 p95 ms | 물리 p95 ms | NPC 타격 | 플레이어 타격 |
| --- | --- | --- | --- | --- | --- |
| 32 | 56.741 | 61.325 | 7.809 | 246 | 98 |
| 96 | 92.975 | 108.064 | 8.789 | 817 | 184 |
| 192 | 157.402 | 178.782 | 18.319 | 1474 | 251 |

세 경우 모두 실제 양방향 피해가 발생했고 투사체/VFX 풀이 반환됐으며 orphan 개체는 0입니다. 소프트웨어 GL 수치를 실제 PC/Android GPU의 60FPS 보장으로 해석하지 않습니다. 고밀도 렌더링 비용과 지역별 일반 플레이 밸런스는 추가 확인 대상입니다.

## 셰이더 변경 전 비교

이전 코드 89ec40e, [실제 이전 실행](https://github.com/zoog136-hash/-/actions/runs/37903218088)의 같은 Monster World 군집 검사입니다. 러너 간 하드웨어/부하 차이가 있으므로 단독 변경의 정밀 인과 측정으로 보지 않습니다.

| 개체 | 중앙값 ms | p95 ms | 물리 p95 ms |
| --- | --- | --- | --- |
| 32 | 57.705 | 104.685 | 7.216 |
| 96 | 98.216 | 151.024 | 9.059 |
| 192 | 155.713 | 201.896 | 14.405 |

## 원본 캡처

- [map-aden_world.png](map-aden_world.png)
- [dense-aden_world.png](dense-aden_world.png)
- [dense-auto-oman_03.png](dense-auto-oman_03.png)
- [dense-oman_07.png](dense-oman_07.png)
- [boss-oman_01.png](boss-oman_01.png)
- [boss-oman_08.png](boss-oman_08.png)
- [boss-oman_10.png](boss-oman_10.png)
- [map-faith_03.png](map-faith_03.png)
- [map-escaros_01.png](map-escaros_01.png)
- [map-albino_02.png](map-albino_02.png)
- [catalog-01-attack.png](catalog-01-attack.png)
- [catalog-04-walk.png](catalog-04-walk.png)
- [crowd-32.png](crowd-32.png)
- [crowd-96.png](crowd-96.png)
- [crowd-192.png](crowd-192.png)

종별 상세는 ../MONSTER_SPECIES.md, 좌표·보스 설정은 ../MONSTER_SPAWN_TABLES.md, 미확인/추정 범위는 ../MONSTER_WORLD_SOURCES.md를 참고합니다. 계열 원화 공유·독립 8시점 프레임·일부 원작 지역/보스 기술 고증은 여전히 미완료이며 전면 완료로 주장하지 않습니다.
