# 전투 애니메이션 고도화

## 기준과 보호 범위

- 저장소: `zoog136-hash/-`, 시작 main `da5141bb91c0d852a0d8d175d54bb8b369e76a5d`.
- 맵 기준 `cd635a74e9974637fdd4ae7854ab8434b0ea084e`가 main의 조상임을 Git/API 양쪽에서 확인.
- 새 clone의 status/diff는 비어 있었으며 작업 브랜치는 `feature/combat-animation-overhaul`.
- Godot 4.7.2, 기존 설정/씬/좌표/카메라/맵 아트를 유지. 변경 전 24/24 검사 통과.
- 도감: 변신 413, 인형 166, 성물 144. 방향 시트: 변신 78, 인형 59.
- 몬스터 DB 163종은 기존 정지 이미지 6종을 공유. 기본 직업은 4방향+공격 5프레임.

## 단계

1. 공통 Resource 프로필/모션과 캐릭터 이동: 8방향 논리, 기존 4방향 아트 대체,
   실제 변위 기반 보행, 발 기준 시각 변환, 공격/복귀/피격/사망 상태. 물리 좌표 불변.
2. 변신별 프로필과 명시적 시트 형식. 단일 이미지를 4×4로 자르던 기존 오류 제거.
3. 플레이어 공격 마커, 취소, 투사체 도착 시 판정. 기존 데미지/명중/크리티컬 계산 재사용.
4. 인형 추적/대기/소환/전투 반응.
5. 성물 부유/추적/등급 발광/소환 해제.
6. 몬스터 공통 모션과 공격 마커/시체 연출. 보상과 드랍은 기존 사망 시 1회.
7. 풀링 타격/투사체/데미지 연출.
8. 실제 판정에 따른 크리티컬 강조와 시각 전용 정지.
9. 프레임 캐시/화면 밖 시각 처리 제한/수명과 풀 상한.
10. 회귀 및 실제 렌더 검사. 전용/공통 리소스 현황을 별도 목록으로 기록.

## 단계별 적용 결과

모든 코드 커밋은 `feature/combat-animation-overhaul`에 보존했다. 테스트와 리소스 상태는 아래 표 및 다음 절의 범위를 기준으로 한다.

| 단계 | 실제 구현 | 주요 추가·수정 파일 | 리소스 상태 / 검사 | GitHub 커밋 |
|---|---|---|---|---|
| 1 캐릭터 | 실제 이동 속도에 따른 보행, 8방향 논리, 대기·회전·공격·복귀·피격·사망 표현, 발 기준 변환 | `scripts/player.gd`, `scripts/animation/actor_motion.gd`, `animation_profile.gd`, `animation_catalog.gd`, `tests/actor_motion_test.gd` | 기존 직업 시트 / 방향·물리 좌표·타격 프레임 검사 통과 | [4852a257](https://github.com/zoog136-hash/-/commit/4852a2576e0c1ac4f160f9363b42f37f64f05d05) |
| 2 변신 | ID별 프로필, 방향 시트와 단일 이미지 구분, 전환 중 위치·AUTO·공격 시퀀스 보존 | `data/combat_animation_profiles.json`, `docs/combat_animation_coverage.json`, `scripts/player.gd`, `scripts/world.gd`, `tests/animation_catalog_test.gd` | 변신 413종 검사, 78 방향 시트 / 나머지는 정지 이미지와 공통 모션 | [87a9112c](https://github.com/zoog136-hash/-/commit/87a9112cfee48c4f3dc4672037a69810ee1a22e2) |
| 3 전투 타이밍 | 공격 준비→마커→기존 판정→복귀, 이동·상태이상 취소, 원거리·마법 도착 시 판정, 사망 타깃 무효화 | `scripts/world.gd`, `scripts/player.gd`, `scripts/animation/combat_flights.gd`, `tests/combat_timing_test.gd`, 기존 스킬 검사 2개 | 기존 전투 수식 재사용 / 실제 물리 프레임 타이밍·움직이는 타깃 검사 통과 | [de793ac4](https://github.com/zoog136-hash/-/commit/de793ac4a7147151a19cfb6a10e741217dd50911) |
| 4 마법인형 | 부드러운 추적, 정지 지점 안정화, 보행·부유, 방향 전환, 소환·해제, 전투 반응 | `scripts/animation/follower_motion.gd`, `scripts/world.gd`, `tests/follower_motion_test.gd` | 166종 검사, 기존 59 방향 시트 / 공통 추적·반응 | [cff319c7](https://github.com/zoog136-hash/-/commit/cff319c7a9be33721c8f34d0bb722208799c89f2) |
| 5 성물 | 별도 추적 지점, 부유·흔들림·등급 빛 반응, 소환·해제, 지면 기준 정렬 | `scripts/animation/relic_motion.gd`, `assets/effects/relic_glow.gdshader`, `scripts/world.gd`, `tests/relic_motion_test.gd` | 144 기존 이미지 + 새 경량 셰이더 / 인형과 동시 추적 및 GL 검사 통과 | [124af1e7](https://github.com/zoog136-hash/-/commit/124af1e7ac85ccdd85520dc4428eef72bbe10a6a) |
| 6 몬스터 | 대기·순찰·추적·공격·피격·사망·시체, 타격 마커, 크기별 발·타격 지점·그림자, 기존 보상·드랍 1회 | `scripts/monster.gd`, `scripts/world.gd`, `tests/monster_motion_test.gd` | 163종에 6 기존 이미지와 공통 모션 / 개별 프로필·공격·사망 검사 통과 | [95da8827](https://github.com/zoog136-hash/-/commit/95da8827b9862738643472acb3f0e34ce0f919eb) |
| 7 일반 타격 | 베기·찌르기·충격·마법 스파크, 월드 좌표 숫자, 이동 타깃 투사체, 지면 그림자 | `scripts/animation/combat_vfx.gd`, `actor_shadow.gd`, `scripts/player.gd`, `scripts/monster.gd`, `scripts/world.gd`, `tests/combat_vfx_test.gd` | 새 Canvas 도형 VFX / 3,000회 생성, 160 슬롯 반환 검사 통과 | [8ed8dd45](https://github.com/zoog136-hash/-/commit/8ed8dd45cc1ce8b7d29c7a1a6522e1b6ef232d00) |
| 8 크리티컬·연속 공격 | 실제 크리티컬 결과의 섬광·숫자 강조, 시각 전용 짧은 정지, 다단 투사체 시간차 도착 | `scripts/world.gd`, `scripts/animation/combat_vfx.gd`, `combat_flights.gd`, `tests/volley_motion_test.gd` | 공통 절차적 효과 / 트리플 3발·탄약 3개·중복 방지·시뮬레이션 시간 불변 검사 통과 | [eec61c80](https://github.com/zoog136-hash/-/commit/eec61c8009da4a20641852a8b25dfaa6df8747aa) |
| 9 최적화 | 프레임 캐시 96, VFX 슬롯 160, 투사체 대기 풀 128, 표시 64 제한과 판정 분리, 화면 밖 시각 갱신 생략, 유휴 처리 중지 | 모션·VFX·투사체·몬스터 코드, `tests/flight_lifecycle_test.gd`, `tests/capture_combat.gd`, `.github/workflows/combat-animation-validate.yml` | 새 이미지 없음 / 33개 전체 검사와 실제 GL·원본 비교 통과 | [6326f0cd](https://github.com/zoog136-hash/-/commit/6326f0cd0eaba312d717c95ecbc82edd6fd6e0ea) |
| 10 검증·수정 | 전용 SpriteFrames 연결, 프로필별 마커·타격 프레임·포즈 속도, 복원 시 이전 공격 폐기, 반복 명령의 중복 비용 방지, 피격 정지 중 공격 마커 정렬 | 프로필·카탈로그·모션·플레이어·인형·월드, `tests/animation_restore_test.gd`, `authored_frames_test.gd`, `actor_motion_test.gd`, `combat_timing_test.gd`, `skill_mechanism_smoke_test.gd` | 기존 리소스를 사용하는 검사 fixture / 35/35 전체 검사와 전투·지역·원본 비교 GL 검사 통과 | [2768b033](https://github.com/zoog136-hash/-/commit/2768b0339c0a675344e7cf8cb0a882dd347933e2), [28983a82](https://github.com/zoog136-hash/-/commit/28983a82acc845f349580d04e5b3a4de5ac57cbf) |

단계 1~9의 다음 단계는 표의 다음 행으로 진행했으며, 단계 10 이후의 과제는 전용 아트 제작과 실제 PC GPU에서의 장시간 측정이다. 코드·검사 범위 내의 잔여 오류와 아트 대체 상태는 아래에 구분한다.

## 전용 리소스와 공통 모션 구분

| 실제 활성 항목 | 수 | 기존 전용 프레임 | 이번 적용한 공통 표현 / 남은 아트 |
|---|---:|---|---|
| 기본 직업 외형 | 4 | 직업별 4방향 보행, 5프레임 공격 | 대기·회전·피격·사망·복귀 보정. 공격은 원본 단일 방향 행을 사용하며 좌우 미러링 |
| 변신 | 413 | 개별 4방향 보행 시트 78종 | 정지 이미지 대체 335종. 모든 413종의 공격은 공통 절차적 모션이며 전용 공격 시트는 0종 |
| 마법인형 | 166 | 개별 4방향 보행 시트 59종 | 정지 이미지 대체 107종. 추적·소환·해제·전투 반응 공통 |
| 성물 | 144 | 기존 정지 이미지 | 독립적인 부유·추적·흔들림·발광 프로필. 전용 프레임 애니메이션 없음 |
| 몬스터 | 163 | 기존 6종 정지 텍스처 공유 | 개별 설정을 갖는 공통 보행·공격·피격·사망·시체 표현. 전용 방향·공격 시트는 0종 |

전체 ID·이름·실제 리소스 경로·방향 수·대체 모션은 [combat_animation_coverage.json](combat_animation_coverage.json)에 기록했다. 프로필 1,331개에는 최신 main에 남아 있는 비활성 레거시 데이터의 확장용 설정도 포함한다(변신 559, 인형 312, 성물 297, 몬스터 163). 실제 UI 도감 수는 위 표의 413/166/144를 유지한다.

8방향은 논리적 방향 처리이며 현재 실제 아트는 4방향 또는 정지 이미지 대체다. 이번 작업에서 새 래스터 이미지·음향을 제작하거나 외부 게임의 에셋을 새로 복제하지 않았다. 따라서 모든 종류에 전용 8방향 공격 아트가 구현되었다거나 리니지M의 완성된 아트 품질에 도달했다고 주장하지 않는다.

## 프로필과 판정 연결

`AnimationPlayer`/`AnimationTree`를 일괄 추가하지 않고 기존 `AnimatedSprite2D`와 `Sprite2D`에 Resource 프로필·공통 모션 시계·Signal 마커를 연결했다. 이동·충돌·AI·데미지 수식과 시각 변환을 분리한다. 직업의 기존 공격 시트는 타격 프레임 3에 맞추며, 전용 리소스를 추가할 때 변신과 인형은 `frames_path`로 네이티브 `SpriteFrames`를 연결할 수 있다.

`data/combat_animation_profiles.json`의 ID별 설정이나 개별 레코드의 `animation_profile`에서 `layout`, `motion_style`, `movement_fps`, `reference_speed`, `attack_hit_ratio`, `attack_hit_frame`, `frames_path`, `animation_names`, `sprite_offset`, `collision_offset`, `projectile_origin`, `hit_position`, `shadow_size`, `floating`을 지정한다. 현재 캐릭터 충돌체는 기존 위치를 보존하고, 몬스터의 충돌 오프셋·반경은 명시적 설정이 있을 때만 적용한다.

실제 공격 간격은 기존 장비·변신·버프 수치로 계산한다. `attack_animation_speed`는 그 간격과 타격 마커를 유지하면서 준비·복귀 구간의 포즈 진행을 조절한다. 프로필에 타격 비율이 명시되면 해당 비율을 적용하고, 없으면 현재 무기의 베기·찌르기·중량·활·마법 타이밍을 사용한다. 크리티컬 정지는 시각 포즈에만 적용하며 `Engine.time_scale`, 이동 입력, 공격 간격과 판정 수를 바꾸지 않는다.

공격 시퀀스는 마커를 한 번만 방출한다. 이동·상태이상·맵 이동·불러오기·리스폰에서 이전 공격을 취소하고, 타깃은 약한 참조와 전투 세대 번호로 검증한다. 투사체 표시 예산을 초과해도 논리적 타격을 버리지 않는다. 다단 공격은 기존 총 대미지 분배·명중·크리티컬·소모 규칙을 재사용한다.

## 테스트 범위와 결과

- 변경 전 원본 main: 24/24 검사 통과.
- 9단계: 로컬 및 GitHub 33/33 검사 통과. 실제 전투 10장, 기존 지역 37장, 원본 main 지역 37장 캡처 성공.
- 10단계: GitHub 35/35 헤드리스 검사와 실제 전투 10장·기존 지역 37장·원본 지역 37장 렌더·비교 모두 통과. [최종 검증 실행](https://github.com/zoog136-hash/-/actions/runs/37787334107), [캡처·로그 artifact](https://github.com/zoog136-hash/-/actions/runs/37787334107/artifacts/11555167284).
- 실제 물리 타이밍, 이동 취소, 타깃 이동·사망, 프로필 변경, 전용 리소스 연결, 반복 명령, 저장·복원, 풀 반환, 다단 공격 및 크리티컬 검사를 포함한다.
- 기존 장비·방패·무기·인벤토리·아이템 상세·퀵슬롯·패시브·스킬·드랍·입력·지역·포털 검사를 보존했다. 원래 즉시 판정하던 스킬 검사의 기존 수치 단언은 유지하고 실제 모션·투사체 시계 완료 후 검사한다.
- 24개 새 지역 전체의 이동·충돌·카메라 좌표 변환·포털·저장·전투 보상 검사는 단독 로컬 실행에서도 통과(126.34초).
- 맵 코드/아트, `project.godot`, 모든 기존 `.tscn`, 카메라 투영 설정과 기존 HUD 스크립트의 기준 커밋 대비 차이는 없다.
- 미실행: Windows/macOS 실제 GPU에서 장시간 플레이, 장시간 메모리 안정성, 모든 도감 항목의 사람이 보는 전 방향 전투 검수. 전체 도감 로딩 검사는 시각적인 전용 아트 품질을 보장하지 않는다.

재현: Godot 4.7.2로 `project.godot`을 열고 실행한다. 자동 검사는 `python3 tools/test_project.py --godot /path/to/godot`을 사용한다. 실제 렌더는 디스플레이가 있는 환경에서 `tests/capture_combat.gd` 및 기존 `tests/capture_regions.gd`를 실행한다. 테스트 저장 데이터는 독립적인 임시 사용자 폴더를 사용한다.

## 확인된 실패와 수정 이력

- 변경 전부터 존재한 테스트 문제: 돌진 검사 한 번의 명중을 반드시 요구하지만 실제 규칙은 MISS를 허용한다. 테스트 fixture의 난수 시드를 고정했으며 게임의 명중률과 수식은 변경하지 않았다.
- 작업 중 발견·수정: 전용 리소스 추가 시 export 필터 표기의 파싱 오류를 커밋 전에 수정했다. 최종 네이티브 리소스·시트·마커 검사는 통과했다.
- 작업 중 발견·수정: 타격 직전 크리티컬 피격 정지가 공격 포즈를 준비 프레임에 남길 수 있었다. 게임 시계를 지연하지 않고 마커에서 타격 포즈로 맞추며 전용 회귀 단언을 추가했다.
- 환경 실패: 재개 시 Godot 바이너리가 잘려 실행 실패했다. 공식 배포 파일을 복구했다. 로컬 X11 소켓 제약 때문에 GL 검사는 GitHub Linux 가상 디스플레이에서 실행했다.
- 환경/검사 시간 제한: 병렬 지역 검사 한 번이 150초 제한을 초과했다. 단독 재실행은 전체 24지역·모든 단언을 유지하고 126.34초에 통과했다. 최종 CI에서도 같은 전체 검사 게이트를 실행한다.

## 성능 측정과 한계

아래는 9단계에서 같은 GitHub runner의 Linux `llvmpipe` 소프트웨어 GL로 원본 main과 순차 측정한 결과다. 게임의 맵·카메라·1280×720 뷰포트·60 FPS 상한을 유지했다. 값은 프레임 시간(ms)이며 실제 PC GPU의 FPS 보장이 아니다.

| 자동사냥 맵 | 원본 중앙값 / P95 | 변경 중앙값 / P95 | 변경 최대 draw calls |
|---|---:|---:|---:|
| 아덴 | 40.290 / 71.334 | 40.547 / 68.539 | 278 |
| 오만 10층 | 39.047 / 69.809 | 38.927 / 70.056 | 294 |
| 알비노 4층 | 47.280 / 78.703 | 46.468 / 80.188 | 297 |
| 신념 4층 | 48.203 / 103.826 | 50.139 / 105.266 | 301 |

정적 지역 중앙값은 37.515→36.800ms, P95는 70.657→70.107ms였다. 중앙값은 대체로 유사하지만 오만의 process P95 42.593→290.309ms 등 CPU 지연 표본이 있어 전체 성능 향상으로 단정하지 않는다. 각 활성 맵 180프레임의 짧은 측정이며 전투 진행·몬스터 수가 조금 다르다. 원본에도 소프트웨어 GL의 큰 프레임 지연이 존재한다.

전투 300프레임 별도 표본: 중앙값 40.206ms, P95 70.558ms, 최대 노드 2,860, orphan 노드 0, VFX 사용 최대 6, 이동 782.45px, 경험치 +560. 이는 해당 측정 중 누락 노드를 확인하지 않았다는 뜻이며 장시간 메모리 누수 부재를 증명하지 않는다. 최종 실행의 원본·변경 성능 JSON과 모든 캡처는 Actions artifact에 보존한다.

최종 코드에서 한 번 더 측정한 값도 함께 기록한다. 원본과 변경을 같은 runner에서 순차 실행한 비교이며 이전 실행과 VM 부하가 다를 수 있다.

| 최종 자동사냥 맵 | 원본 중앙값 / P95 | 변경 중앙값 / P95 |
|---|---:|---:|
| 아덴 | 34.956 / 73.975 | 34.980 / 72.991 |
| 오만 10층 | 34.256 / 71.732 | 34.320 / 70.661 |
| 알비노 4층 | 41.064 / 77.497 | 41.344 / 79.878 |
| 신념 4층 | 44.092 / 102.649 | 62.700 / 101.421 |

최종 전투 표본은 중앙값 33.698ms, P95 38.457ms, orphan 0, 경험치 +515였다. 신념 4층의 중앙값은 이 실행에서 약 42% 높아졌고, 이전 실행의 차이는 약 4%였다. 이 편차를 최적화 성공으로 포장하지 않으며 실제 GPU 측정과 반복 표본에서 원인을 확인해야 한다. P95와 일부 CPU 지연도 아직 남아 있다. 모든 원본 수치는 [combat_animation_validation.json](combat_animation_validation.json)에 보존했다.

## 미완료 항목과 다음 작업

현재 전용 공격/피격/사망 아트가 없는 변신과 몬스터에는 공통 절차적 모션이 적용되어 있다. 다음 제작 과제는 변신 335종의 방향 보행, 모든 변신·몬스터의 전용 공격·피격·사망 시트 및 실제 8방향 아트다. 현재 지원되는 변신·인형 전용 SpriteFrames 연결을 사용하고, 몬스터의 전용 프레임 리소스 연결은 별도 확장 작업으로 진행할 수 있다.

Windows PC GPU의 다수 몬스터 장시간 측정, 소프트웨어 GL 신념 4층 중앙값 편차와 CPU 지연 표본의 추가 확인도 남아 있다. 본 결과는 기존 기능을 보호한 전투 모션·VFX 시스템과 실제 실행 가능한 공통 모션 적용이며 모든 종의 전용 아트 완성본은 아니다.
