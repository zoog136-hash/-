# 실제 8방향 애니메이션 확장 — PR #100

현재 런타임 커밋은 **`3d0447618e68d4a386ef0c4ce407e80d2cecd97e`**, 브랜치는 `feature/twilight-animation-20261013`, [PR #100](https://github.com/zoog136-hash/-/pull/100)은 draft다. 최신 main `02842fdd123bf14db46bed91a3cb68c36fa8b9b1`의 아이템 아이콘 수정도 별도 merge로 보존했다. main에 이 PR을 병합하지 않았다. 전체 개체의 전용 애니메이션 완성은 아니다.

## 실제로 바뀐 범위

| 대상 | 8방향 연속 프레임 연결 | 원본 부족으로 기존 외형 유지 |
|---|---:|---:|
| 영웅 이상 변신 | **126 / 180** | **54** |
| 일반 몬스터 | **119 / 258** | **139** |
| 보스 | **31 / 60** | **29** |

변신 전체 DB는 413종이며 이 중 기존 고급 흑기사까지 포함한 native 연결은 127종이다. 기본 `class:0`도 기존 흑기사 리소스를 사용한다. 이번 확장 275개 ID는 **34개 공용 외형 리소스**(인간 장비 조합 15, 몬스터 원본 변형 19)를 사용한다. 기존 기사·해골 2개를 더하면 36개다. 이는 개체마다 별도 원화를 제작했다는 수치가 아니다. 무기·성별·체형·색상이 대응하는 TWILIGHT용 적응이며 리니지/리니지M 원화의 세부 의상 복원은 아니다. 개별 이름·연결 파일·해시·부족 이유·검증 단계는 단일 [리소스 장부](../../data/resource_delivery_ledger.json)의 `sequential_actor_art`에 있다.

- 검·방패, 양손검, 활, 지팡이, 단검, 도끼의 원본 장비 레이어와 방향별 순서로 실제 PNG 자세를 합성했다. 걷는 다리와 무기를 움직이는 자세가 프레임마다 달라진다.
- 모든 새 외형에 대기·이동·공격·피격·사망 × 8방향을 연결했다. 원본이 제공하는 시전·발사·특수 동작도 해당 외형에서 연결한다. 하나의 정면 이미지를 회전하거나 복제해 방향을 채우지 않았다.
- 해골 검사/궁수/마법사, 고블린/홉고블린, 좀비, 미노타우르스, 개미 사자, 와이번 계열 등은 해당 본체를 사용한다. 데스나이트는 인간 판금병이 아닌 해골 기사 원본을 사용한다.
- 창·총·낫·체인소드·이도류/클로와 특수 의상·날개·별도 체형 등 적합한 연속 프레임이 없는 대상은 기존 식별 가능한 외형을 보존한다.
- 사용자가 지적했던 반대 방향 오류는 `292c80363fbc88d18a004277f740749b86b7fd71`에서 수정했다. 원본 W/SW/S/SE/E/NE/N/NW를 게임 E/SE/S/SW/W/NW/N/NE에 **4/3/2/1/0/7/6/5**로 연결하고 픽셀 회귀 검사를 유지한다.

## 실제 게임 영상

모두 기존 **Main.tscn / 아덴 용의 계곡 / 실제 DB 드레이크**를 사용한다. 실제 직업 선택·장비·입력·AI·피해·바닥 드랍·수동 습득·변신 복원을 통과한 실행이다.

| 영상 | 실제 설정 | 결과 |
|---|---|---|
| [기사](https://drive.google.com/file/d/12pbWGdlt6Yxytoc87vGjot0wzT9SKhSX/view) | 신화-기사(여), 변신 131 | 8방향 이동, 기본 공격 14회, 적 공격 5회, 사망/드랍/습득/변신 왕복 |
| [활](https://drive.google.com/file/d/13ShhV7fHy76k6WBOsnYIhrRCsthL-_d1/view) | 요정, 신화-요정(여) 135, 실제 훈련용 활 | 당김→발사 4프레임, 공격 13회, 적 공격 5회, 드랍/습득/변신 왕복 |
| [지팡이](https://drive.google.com/file/d/1WY8MpSyGOY4j0FwSeSjh3czmoqBEC-RB/view) | 마법사, 신화-마법사(여) 137, 실제 훈련용 지팡이 | 기존 HUD 마법 22회, 시전 동작, 드랍/습득/변신 왕복 |

영상은 각각 20.267 / 20.467 / 23.033초, 1280×720 H.264다. 세 파일 모두 Drive 업로드 후 전체 파일을 다시 내려받아 SHA-256 일치를 확인했다. [영상 해시·전달 기록](evidence/animation-expansion/video-delivery.json). 익명 접근 및 브라우저 플레이어 재생은 별도 미검증이다.

[초기 기사/해골 애니메이션 교체 전후 비교](https://drive.google.com/file/d/1SrBIY5QfJRwjnS-Kaxh77tQYIUkCzzMm/view)는 이전 단계 기록이며 이번 활/지팡이 전후 비교로 표시하지 않는다. 이번 활/지팡이의 동일 장면 변경 전 영상은 없다.

시각 확인은 기사·활·지팡이 3외형과 드레이크 표본이다. 전수 ID의 코드/리소스 검사와 **모든 디자인의 시각 승인**을 구분한다. 녹화에서는 자세 식별을 위해 실제 카메라를 1.8배 확대하고 다른 몬스터를 일시 정지했다. 게임 피해 수식·플레이어 스탯을 변경하지 않았으며 다수 몬스터 성능 시험으로 사용하지 않는다. 사용자 세이브는 사용하지 않았다.

## 출처와 구현

사용한 원본은 Flare Game **`af6eee6d339ac98011864bfe89da837fe7769c28`**의 공개된 2D PNG, 동작 정의, 장비 레이어 순서다. 실제 입력 183파일 / 309,516,282 bytes의 크기·Git blob·SHA-256을 확인했다. [출처와 허용 조건](../../assets/actors/eight_direction/ATTRIBUTION.md), [파일별 credit](../../assets/actors/eight_direction/UPSTREAM-PER-FILE-CREDITS.md), [입력 영수증](../../assets/actors/eight_direction/expansion_source_receipt.json). 기본 CC BY-SA 3.0 및 명시된 CC BY 3.0 credit을 보존한다. 이 작업에서 3D 모델 제작/렌더링을 수행하지 않았다.

제공된 PC 계열 21624/21653 소스 키트는 정체성 및 재배포 권리 미확인으로 이번 runtime에 넣지 않았다. 현행 모바일 원본으로 분류하지 않는다. 공식 영상의 접촉/복귀 리듬 관찰과 원본 PNG의 실제 동작 duration, TWILIGHT의 타격 시점 보정은 서로 다른 근거다.

기존 `AnimationCatalog → ActorMotion → Player/Monster`를 확장했다. 동작마다 프레임 수와 접촉 프레임을 데이터로 분리하여 짧은 검 휘두르기·활 발사·시전·보스 특수 동작이 같은 전투 타임라인을 따른다. 공격 간격과 피해 계산은 유지한다. 발 위치는 256×256 가상 캔버스의 (128,160), 원본 오프셋과 방향별 장비 레이어 순서를 보존한다. atlas 투명 여백을 제거하되 margin으로 같은 캔버스를 복원한다.

이미 사용 중인 AnimatedSprite의 리소스를 유지하면서 조회 캐시를 96MiB/96항목으로 제한한다. 모든 새 atlas를 부팅 때 한꺼번에 로딩하지 않는다. 페이지 크기는 최대 1024×2048이다. 새 확장 PNG 합계 **92,415,885 bytes**, 전체 페이지를 동시에 디코딩한 계산값 **449,265,664 bytes**다. 이는 프로세스 메모리 피크가 아니다. 실제 테스트 종료 시 조회 캐시는 79,347,712 bytes였다.

## 검증

Godot **4.7.2**, Compatibility, Linux Xvfb + Mesa llvmpipe. [로그/화면](evidence/animation-expansion/), [runtime 바이너리 291파일의 Git 및 SHA-256 확인](evidence/animation-expansion/tracked-resource-sha256.json).

- `python3 tools/check_resource_integrity.py --root .`: 기존 723 WebP / 41,442 cell 무결성 통과. 새 개체 수와 혼동하지 않는다.
- `tests/native_animation_expansion_test.gd`: **35,455 assertions PASS**, 275개 새 연결, 34개 외형, 8방향·5필수 동작·실제 프레임 다양성·발 캔버스·페이지 해시·캐시 퇴출 후 생존 actor 확인.
- 같은 검사에서 공격/발사/시전/특수 동작의 8방향, 1.44/0.72/0.18초 공격과 큰 시간 건너뜀을 검사했다. 접촉 자세와 타격 사건이 한 번씩 발생한다.
- 기존 방향 검사 **1,362 assertions**, 전체 presentation **76,336 checks / 변신 413·몬스터 318**, 타격 lifecycle **158**, 보스 presentation **693 / 60보스**, world lifecycle **21** 통과. 이는 전체 보스의 새 전용 모션이나 화면 검증 수가 아니다.
- catalog/restore/actor motion/authored state/monster motion/weapon rules 회귀 통과. `python3 tests/animation_expansion_plan_test.py`: 무기·체형 오연결 방지와 부적합 mapping 복원 2개 회귀 통과.
- 실제 Main 기사·활·지팡이 녹화에서 script/resource 오류 없음. llvmpipe의 VSync 변경 미지원 경고는 남아 있다.
- 2개 누락 입력을 만난 최초 변환은 실패로 기록하고 중지했다. 원본 검증/복원 후 해당 결과만 재생성했다. 잘못된 QA 무기 조회, 직업 선택, 사거리 밖 접근은 시험 코드에서 수정했고 실패 기록을 보존했다.
- 전체 기존 시험의 이전 기준 실패 14건·건너뜀 3건을 이번 애니메이션 통과로 덮지 않는다. 이번 범위의 집중 검증을 수행했으며 전체 CI 성공은 별도 확인한다. `3d04476` CI의 스킬 쿨타임 실패는 변경 전 기준선에서도 재현된다. L1J 실제 actor 검사의 정적 이미지 전제는 새 8방향 경로를 기대하도록 갱신하되, 원본 static bridge 검증과 미적용 actor의 정적 이미지 검증은 유지했다.
- 새 GitHub clone의 `3d04476`에서 작업자 임포트 캐시/연구자료 없이 **cold import 204.941초, boot 16.141초, native 15.445초, restore 22.683초, 전체 registry 27.294초 모두 통과**. [실행 명령과 로그](evidence/animation-expansion/clean-delivery/result.json). boot는 `--quit-after 60` 전체 프로세스 시간이며 첫 조작 가능 시간이나 성능 전후 비교가 아니다. 이후 main 통합 `dec79a6`에서도 warm import, L1J 실제 actor/자동사냥 **101 checks**, 아이템 icon **193 checks** 통과. 검사 갱신 커밋은 `b516f38`이다.

| 품질 | 현재 판정 | 범위 |
|---|---|---|
| 몸·발·무기 정렬 | 표본 통과 | 3플레이어 외형+드레이크 화면, 전체 리소스 offset 검사 |
| 동작 식별 | 표본 통과 | 검 휘두르기, 활 당김/발사, 지팡이 시전, 실제 이동 |
| 타격 동기 | 통과 | 공통 타임라인 회귀 및 대표 실제 교전 |
| 지형/전체 보스 회피/전체 UI | 미검증 | 이번 애니메이션 확장 범위 밖 |
| 성능 | 부분 검증 | 페이지/캐시 상한 확인; GPU p50/p95·60fps·메모리 피크 미측정 |
| Android | 미검증 | 이번 확장 APK 빌드/부팅/기기 플레이 미수행 |

플레이어 사망은 기존 즉시 부활과 시체 효과 흐름을 유지한다. 사망 프레임 존재와 부활 전 전체 동작을 화면에 보여 주는 것은 별개다. 보스 고유 스킬마다 전용 원화를 모두 확보한 것도 아니다.

## 복원과 실행

새로 사용하는 runtime PNG/TRES·설정·credit은 Git에 들어 있다. 연구 ZIP·원본 대용량 시트·영상이나 작업자 임시 경로가 실행에 필요하지 않다.

```sh
git clone --branch feature/twilight-animation-20261013 https://github.com/zoog136-hash/-.git TWILIGHT
cd TWILIGHT
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT_BIN" --headless --editor --path . --import
python3 tools/check_resource_integrity.py --root .
"$GODOT_BIN" --headless --path . --script res://tests/native_animation_expansion_test.gd
"$GODOT_BIN" --path .
```

기사·요정·마법사를 선택하고 해당 신화 변신 및 검/활/지팡이를 장착한다. WASD/방향키 이동, Space 기본 공격, 기존 HUD 스킬. 드레이크는 아덴 용의 계곡의 기존 스폰을 사용한다. 검증 장면을 평상시 게임의 별도 메뉴로 추가하지 않았다.

주요 변경 파일: `assets/actors/eight_direction/`, `data/combat_animation_profiles.json`, `data/resource_delivery_ledger.json`, 기존 `scripts/animation/` 공통 재생기, 기존 capture/회귀 검사, 변환 도구. 최소 확장 `7af22e0`, 34외형 확장 **`3d04476`**. 세부 커밋과 남은 54변신·168몬스터의 재개 항목은 [체크포인트](REMAKE_CHECKPOINT.md)에 보존한다.
