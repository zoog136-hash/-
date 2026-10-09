# 몬스터 월드 구현 후보 — 2026-10-09

기준 main: `82dbbdb18ec3088fcf521ce887af61c0c48c5a28`
브랜치: `feature/twilight-monster-world-overhaul-20261009`
main·백업 브랜치 미수정. 사용자 승인 없이 병합하지 않습니다.

이 후보는 현재 25개 맵의 지역 스폰, 공격 유형, 폭젠, 보스 생명주기와 저장을 연결합니다. 원작 전체 고증과 모든 종의 독립 8시점 아트 완료본은 아닙니다. 확인되지 않은 값·모션·지역 대응은 [조사 한계](MONSTER_WORLD_SOURCES.md)에 표시했습니다.

## 시작 시 조사 결과

- 기존 몬스터 DB 163종. 이름에 따라 여섯 공용 텍스처를 선택했습니다.
- 163종 모두 DB에 attack_type이 없어서 런타임 기본 근접 공격을 사용했습니다. PR #13·#16의 모션·마커·선택적 native 프레임 기반은 이미 존재했으며 재작성하지 않았습니다.
- 실제 플레이 맵은 아덴 1, 오만 10, 지배 정상 1, 신념 4, 에스카로스 5, 알비노 4로 총 25개였습니다.
- 오만 층별 구성·보스가 요청한 목록과 달랐고, 특수 맵에서 기존 종 재사용 배치가 있었습니다. 독립 폭젠 슬롯과 보스 생존/대기 저장이 없었습니다.
- 아덴 자체 지형의 기존 7개 권역은 원작 지역 지형과 동일하지 않았습니다.

## 구현 범위

| 항목 | 결과 |
| --- | --- |
| 몬스터 카탈로그 | 기존 163종 유지·확장 + 신규 155종 = 318종. 현재 맵 배치 고유 종류 177종, 나머지는 DB 보존 |
| 자체 아트 | 96개 계열 원화, 6개 PNG plate. 종별 비율·장식·장비·공격 프로필. 원화 공유 및 독립 8시점 프레임 미완료 |
| 공통 모션 | Idle/Walk/Attack/Hit/Death, 마법 Cast, 원거리 RangedAttack, 보스 SpecialAttack 표현. 피해는 모션 마커와 연결 |
| 일반 AI | 선공/비선공·반격·사회적 어그로·추적·복귀·배회·원거리 후퇴·서큐버스 거리 이탈. 데이터별 설정 |
| 원거리/마법 | 실제 조준 투사체, 원소 색/피해, 움직이는 대상의 회피, 장애물·안전지대·은신 재검사, 재사용 개체의 이전 투사체 차단 |
| 지역 배치 | 25개 맵, 총 192개 스폰 구역. 연결 가능 셀·통행·안전 구역 검사를 사용 |
| 폭젠 | 아덴 용의 계곡, 오만 3/7/10층. 각 24개, 반경 220px, 7초, 접근 거리 1900px, 최소 간격 38px |
| 보스 | 27개 맵별 보스 구역. 오만 요청 10종 포함. 일반 공격 + 7가지 특수 패턴, 범위 경고, HP UI, 로컬 격노 |
| 보스 생명주기 | map:boss ID 기준 HP·위치·생존·대기·다음 출현 게임 시각 저장. 최초 즉시 출현, 이후 설정 간격 |
| 드랍 | 기존 loot_drop 계산·확률·보스 장비 최대 3개 유지. 새 종은 기존 풀 상속. 바닥 드랍 → 습득 |
| 성능 | 원거리 AI 수면, 30Hz 의사결정/60Hz 이동·모션·마커, LOS 캐시, 경로 탐색 분산/직선 최적화, 64개 개체 풀, 기존 투사체/VFX 풀, 전투 HUD 전체 계산 합치기 |

특수 패턴은 광역 파동, 부채꼴 공격, 직선 마법, 돌진, 흡혈, 제한 소환, 3연발입니다. 원작에서 각 보스의 정확한 기술을 확인한 것으로 주장하지 않습니다. 소환 개체는 보스당 최대 4개이며 무한 보상 파밍을 막기 위해 별도 보상을 주지 않습니다.

## 결과 데이터

- [몬스터별 외형·공격·모션·배치 목록](MONSTER_SPECIES.md)
- [25개 맵·192개 스폰·27개 보스 표](MONSTER_SPAWN_TABLES.md)
- [카탈로그와 근거·AI·상태이상·수치](../data/monsters/monster_world_catalog.json)
- [일반/폭젠/보스 좌표·비율·리스폰 설정](../data/monsters/world_spawn_profiles.json)
- [자체 아트 provenance](../assets/monsters/original/ORIGINAL_ART.md)
- [확인·추정·자료 부족 구분](MONSTER_WORLD_SOURCES.md)
- [검증 증거](monster-world-evidence/VALIDATION.md)

## 보호 범위와 변경 파일

변경은 `scripts/monster.gd`, `scripts/maps/field_population.gd`, `scripts/monsters/`, `data/monsters/`, 자체 몬스터 아트, 검사/캡처/CI/문서입니다. `world.gd`에는 카탈로그·맵 적용·저장 복원·풀 반환·보상 없는 보스 보조 개체 처리와 전투 HUD 갱신 합치기를 연결했습니다. `combat_flights.gd`는 선택적 고정 조준/장애물/원소 색 인수를 추가했으며 기존 플레이어 호출 방식은 유지합니다.

원본 몬스터/아이템 DB, 13클래스 데이터, 지형/포털 원본, actor_motion/native-frame 기반, loot_drop 확률, 장비 개체 ID·강화·소모품·인벤토리 UI는 변경하지 않습니다. 두 지역 검사의 개체 수 가정만 먼 폭젠 슬롯을 대기시키는 정책에 맞췄고 경로/안전/물리/저장 검사는 유지했습니다.

## 검증 방법

```bash
python3 tools/build_monster_world.py
python3 tools/report_monster_world.py
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results
```

[Monster World Validate](../.github/workflows/monster-world-validate.yml)는 전체 회귀 후 실제 Compatibility OpenGL에서 25개 지역, 폭젠 AUTO, 오만 보스 10개, 모든 카탈로그 종의 다섯 모션 화면과 32/96/192 전투를 실행해 PNG/JSON/로그를 올립니다. 밀집 AUTO 검사는 경로·공격·처치·재출현을 격리하기 위해 HP/AC를 제어합니다. 군집은 공격 유형을 교차 배치한 제어 수치 테스트이며 일반 플레이 밸런스 보장이 아닙니다. 소프트웨어 GL 결과를 실제 PC/Android GPU의 60FPS 보장으로 해석하지 않습니다.
