# PR #100 후속 수정 및 검증

기존 `feature/twilight-animation-20261013` / `8ea63b3f036b91a801730ae101a1bfd7c0524b99`에서 이어서 수정했다. 이 보고서는 전체 외형 제작 완료를 뜻하지 않는다. 최종 저장 커밋은 이 문서를 포함하는 [PR #100](https://github.com/zoog136-hash/-/pull/100)의 HEAD에서 확인한다. 새 PR이나 main 병합을 수행하지 않았다.

## 상하 방향 오류

Godot의 화면 좌표 계산은 정상이다. `+Y`는 아래이고 게임 방향은 `E, SE, S, SW, W, NW, N, NE`다. 기존 변환기가 Flare 원본 방향을 `W, SW, S, SE, E, NE, N, NW`로 잘못 해석했다. 실제 원본 순서는 **`W, NW, N, NE, E, SE, S, SW`**이며 게임 방향에 대한 원본 인덱스는 **`[4,5,6,7,0,1,2,3]`**이다.

- 기존 **36개 SpriteFrames / 1,864개 트랙**의 이름과 출처 매핑을 수정했다. 대기·이동·공격·발사·시전·특수·피격·사망 모두 같은 기준을 따른다.
- 기존 **233개 PNG의 바이트·SHA-256, AtlasTexture 영역, 프레임 순서·시간·루프는 보존**했다. 상하 이미지 반전이나 음수 Y 스케일을 사용하지 않는다.
- `tools/build_open_sprite_sample.gd`, 36개 `provenance.json`, 독립 픽셀 기준과 회귀 검사를 함께 수정했다. 이전 방향 승인 기록의 잘못된 결론은 [독립 원인 분석](evidence/pr100-direction-fix/DIRECTION_CAUSE.md)에서 명시적으로 정정했다.
- `scripts/animation/animation_profile.gd::projectile_offset`와 `scripts/player.gd::combat_projectile_origin`은 8방향 무기의 발사점을 실제 조준 방향으로 옮긴다. 몸통의 높이와 조준 벡터를 구분하며 기존 좌우 발사점은 유지한다.

[원본 엔진 근거·전체 외형 접촉 시트](evidence/pr100-direction-fix/DIRECTION_CAUSE.md), [PNG 보존 및 TRES 변경 해시](evidence/pr100-direction-fix/resource-mapping-audit.json).

## 연결 수 및 미완료 외형

| 분류 | 실제 8방향 연속 프레임 연결 | 전체 | 미완료 |
|---|---:|---:|---:|
| 영웅 이상 변신 | 128 | 180 | 52 |
| 일반 몬스터 | 134 | 258 | 124 |
| 보스 | 31 | 60 | 29 |
| 기본 외형 | 4 | 4 | 0 |

기존 34개 확장 공용 외형과 기사·해골 표본 2개를 보존했다. `class:1/2/3`은 기존 지팡이·활·단검 외형에 연결한다. 후속 제작으로 **늑대인간·고스트·여성 사신·오우거·라바 골렘·아이스 골렘·코카트리스·사이클롭스·경비병(창) 대장 9개 외형**을 각자의 기존 이미지에서 새로 그렸다. 각 104자세(8방향 × 대기 2·이동 3·공격 3·피격 2·사망 3), 합계 936자세이며 총 45개 리소스를 사용한다. 원본이 이미 동일한 지역 개체만 공유했고 각 이름으로 Main 전투를 별도로 검사했다. 새 그림 9개가 변신 2종·몬스터 15종에 적용됐다. 원본과 기존 모션을 덮어쓰지 않는다.

고정된 공개 소스의 377개 애니메이션 정의와 현재 로컬 자료를 확인했지만, 나머지 외형에 맞는 날개·마물·동물·특수 의상·창·총·이도류·클로·체인소드·낫 등의 8방향 원본은 확보하지 못했다. 서로 다른 몸체를 무리하게 대체하지 않았다. **남은 52/124/29종, 총 205종은 미완료**다. [현재 ID·사유 목록](evidence/pr100-direction-fix/original-based/coverage/missing-native-sources.json). 기존 54/139/29종 조사표는 이전 검증 증거로 보존했다.

전체 413개 변신, 318개 몬스터/보스, 4개 기본 외형의 **735개 ID × 8방향 = 5,880행** [검증표](evidence/pr100-direction-fix/original-based/coverage/all-identities-eight-directions.csv)를 자동 생성했다. 실제 RGBA 고유 프레임과 재생 슬롯 수를 구분한다. `source_metadata_only`, `actual_gameplay=not_run`은 전수 화면 승인이 아니라는 뜻이다. 성공한 실제 Main 보고서를 명시한 행만 `recorded_Main_sample`로 표시하며 해당 증거 경로를 함께 기록한다. 같은 리소스를 쓰더라도 실행하지 않은 다른 이름은 자동 승격하지 않는다. 실제 플레이한 표본은 별도 [Main 실행 기록](evidence/pr100-direction-fix/gameplay.json)으로 제공한다.

## 실제 TWILIGHT 검증

공식 Godot **4.7.2**, 실제 `Main.tscn`, 기존 직업 선택·아이템 장착·아덴 필드·HUD 명령·전투·AI·바닥 드랍·수동 습득을 사용했다. QA는 유효한 필드 위치에 배우를 배치하고 배경 몬스터를 잠시 정지하며 사용자 저장과 분리된 데이터 디렉터리를 사용한다. 별도 게임이나 프리뷰를 만들지 않았다.

- 검, 활, 지팡이의 기본 외형과 호환되는 실제 변신 `131/135/137`에서 각각 8방향 입력 이동·대기·공격/시전 **48사례**, 지팡이 일반 공격 **16사례**를 검사한다. 투사체 생성·진행 방향, 실제 피해 1회, 접촉 프레임·타격 시점, 같은 방향 대기 복귀, 외형 왕복을 확인한다. headless 전체 검사 **7,703개**, 실제 OpenGL 전체 검사 **7,618개**와 112개 Main 화면 캡처도 통과했다. JSON의 검사 수는 마지막 보고서 저장 확인 1개를 제외하며, 최종 수는 함께 저장한 stdout 로그에서 확인한다.
- 기존 해골 근위병의 실제 AI 추적·공격 8방향, 글루디오의 지배자의 기존 beam 경고·스킬·피해 8방향, 피격·사망·드랍·아이템 습득을 확인한다.
- 아덴 흑장로와 데스나이트에는 누락된 기존 엔진의 beam/cone 설정과 보스 메타데이터를 보완했다. 원작 고유 기술로 검증한 설정은 아니며 `local_adaptation_not_verified_original_skill`로 기록했다. 실제 Main의 16방향 경고·접촉·효과·복귀·중단·사망 검사 **164개**와 전체 60보스 presentation **713개**가 통과했다.
- 수정 방향 검사 **1,362개**, native 확장 **35,742개**가 통과했다. 실제 프레임·8방향·필수 동작·공격 접촉·해시·발 캔버스·캐시 생존을 검사한다. 이는 모든 이름의 개별 디자인·모든 무기 조합·모든 고유 보스 기술 화면 승인과 다르다.
- Godot 전체 임포트 및 Main 부팅은 통과했다. 최초 네트워크 제한 실행의 editor 소켓 오류를 별도 보존했고, 소켓 접근이 가능한 재실행에서는 parse/resource 오류 없이 종료했다.

[검](evidence/pr100-direction-fix/gameplay-video/sword.mp4) · [활](evidence/pr100-direction-fix/gameplay-video/bow.mp4) · [지팡이](evidence/pr100-direction-fix/gameplay-video/staff.mp4)는 실제 Main 화면 녹화다. 30FPS 원본을 H.264 20FPS로 압축한 검토용 영상이며 GPU 성능 측정으로 사용하지 않는다. 영상의 표본은 3개 변신과 드레이크이며, 방향별 공격 전수 확인은 Main 테스트와 화면 캡처를 함께 사용한다. [글루디오 보스의 8방향 beam 영상](evidence/pr100-direction-fix/gameplay-video/boss.mp4)은 실제 Main의 별도 보스 범위 **1,909개** 검사와 연결되며 전체 무기 검사를 대신하지 않는다. [실행 절차](evidence/pr100-direction-fix/gameplay-replay.txt)와 [실제 표본 80행 방향 검증표](evidence/pr100-direction-fix/gameplay-direction-verification.csv)를 제공한다.

## Android

Godot 4.7.2 디버그 ARM64 APK를 내보냈다. ZIP CRC, ARM64 구성, v2/v3 서명, 16KB 라이브러리 정렬, 36개 compiled SpriteFrames의 1,864개 트랙/10,320개 재생 프레임, 233개 실제 `.ctex`와 원본 임포트 해시, JSON/출처 메타데이터 일치를 검사한다. 재생 프레임 수를 고유 자세 수로 보고하지 않는다.

APK 크기는 771,837,680 bytes, SHA-256은 `7192fb894c02e286656da514a959d82bc939b444ef3d8b0b7d30c32b2d14ac95`다. [APK 검사 결과](evidence/pr100-direction-fix/android/summary.json).

**Android 기기 실행은 미검증**이다. 기기 연결이 없고 로컬 adb가 읽기 전용 사용자 홈에서 기기 검색을 완료하지 못했다. APK 내보내기 및 독립 검증과 실제 기기 실행을 구분한다. APK는 대용량 Git 리소스로 추가하지 않으며 같은 PR의 Android CI 산출물로 전달한다.

## CI 및 재현

시작 커밋의 CI 실패는 지역 레벨의 오래된 기대값, 실제 속도 보정을 무시한 스킬 쿨다운 기대값, 숨겨진 UI 바로가기 검사, 유지된 아이콘 연결 검사, 이동 캐시 서명, 보스 메타데이터·특수 설정, 밀집 스폰 후보 부족이었다. 해당 기능의 실제 계약을 확인하며 고쳤다. 밀집 스폰은 24마리·38px 간격·220px 반경과 보호 지형을 유지하고 실제 격자 후보를 선택한다. 지역 레벨·쿨다운·UI 검사는 실제 값·경계·불변성·신호 연결을 더 정확하게 검증한다.

최종 전체 로컬 회귀 및 PR HEAD CI 결과는 전달 시점의 실제 완료 상태를 기록한다. 실행 중인 CI를 성공으로 간주하지 않는다.

첫 푸시 `93df8ee`의 29개 workflow는 실제 종료까지 확인했으며 **19 성공 / 10 실패**였다. Android와 애니메이션 presentation은 통과했다. 성공한 APK의 [CI 산출물](https://github.com/zoog136-hash/-/actions/runs/38368109928/artifacts/11798237157)은 PR merge context `e3d0fb1`에서 생성되어 로컬 디버그 서명 APK와 해시가 다르다. [첫 푸시 결과](evidence/pr100-direction-fix/ci-followup/first-pushed-head-ci.json)를 최종 수정 후 CI와 혼동하지 않는다.

후속 실패 원인을 확인하여 두 아덴 보스 설정을 생성기에 반영했다. 생성기를 2회 실행해 승인된 카탈로그와 byte 일치를 확인했다. 스폰 검사는 **9,694개 / 0 실패**였으나 runner에 필요한 성공 marker가 없어 실패로 분류되던 문제를 고쳤다. 125개 실제 스킬 학습의 **1,689개** 검사는 약 **195초**에 통과하여 해당 검사에만 540초 제한을 부여했다. 로컬에 선택적 L1J 원본/CI fixture 전체가 없으면 세 검사는 명시적 SKIP이며, 일부 파일만 있는 불완전 설치는 계속 실패한다. 원본 에셋 확보나 화면 승인을 의미하지 않는다.

지도 캡처는 현재 오만 1층에 없는 tomb 대신 기존 stairs를 사용하고, 모든 저장 시 실제 map ID를 확인한다. 정적 검토 위치의 포탈은 그 검사 중에만 대기시켜 다른 지도를 잘못 저장하지 않도록 했다. 실제 OpenGL에서 기존 목표 **37장**과 4개 실제 이동·전투 표본 모두 통과했다. [검사 결과·해시](evidence/pr100-direction-fix/ci-followup/capture-regions-result.json), [실제 오만 1층 화면](evidence/pr100-direction-fix/ci-followup/oman_01-landmark.png).

드랍 검사는 실제 직업 선택을 거친 뒤 실행하고, 맵 재로딩으로 다시 생성된 주변 몬스터를 고정 위치 GUI 검사 전에 정리한다. 해당 구간에만 플레이어 물리를 정지하며 실제 걷기·보스 처치·AUTO 습득 구간에는 물리를 사용한다. 기존 단언은 모두 유지했다. 실제 전달 파일이 headless **167개 / 33.8초**, OpenGL **167개 / 48.1초**로 통과했다. 게임 런타임 변경은 없으며 엔진 결함이 확인됐다고 주장하지 않는다. [검사 범위와 전후 증거](evidence/pr100-direction-fix/ground-ci-fix/fixture-isolation.json).

## 원본 기반 제작 진행 상황

사용자 후속 지시에 따라 처음 미완료였던 222종의 입력 이미지를 [대응표](../../data/animation_authoring_sources.json)로 고정했다. 153개 서로 다른 파일/atlas 영역이며, 54개 카탈로그 이미지, 87개 기존 등록 몬스터 이미지, 81개 기존 프로젝트 atlas 연결이다. **프로젝트 atlas를 검증된 외부 원작 이미지라고 표시하지 않는다.** 각 대상의 실루엣·팔레트·얼굴·장비·무기를 확인하고 원본 바이트를 그대로 유지한다. 이 입력 목록은 완료 목록이 아니다.

늑대인간은 `assets/l1j/verified/monsters/5030.png`, 고스트는 기존 같은 종 연결 이미지 `assets/external_l1j/monsters/1318.png`를 바탕으로 제작했다. 별도 PNG 3개(4,686,902 bytes), 실제 208자세를 추가했고 반복 정지 프레임을 새 동작으로 세지 않았다. 원본 기반 새 그림이며 회수된 원작 애니메이션이 아니다. 방향 순서는 이 새 시트 자체의 `E,SE,S,SW,W,NW,N,NE` 메타데이터를 사용한다.

서로 다른 해상도로 제작된 고스트 동작은 AtlasTexture의 비례 캔버스와 `actor_motion.gd`의 명시적 메타데이터 처리로 발 위치와 표시 크기를 유지한다. 원본/새 시트 픽셀을 재샘플링하지 않는다. 기존 리소스는 이 메타데이터가 없어 기존 크기를 유지한다. Sprite2D와 AnimatedSprite2D의 8방향·상태 전환·반복 적용 **640개 검사**와 기존 native 확장 **35,742개 검사**가 통과했다.

실제 Main에서 늑대인간 headless **942개**, OpenGL 녹화 실행 **951개**, 고스트 headless **1,083개**, OpenGL **1,196개** 검사를 통과했다. 8방향 실제 추적/공격, 피격, 사망, 기존 확률 드랍, 수동 습득을 확인했다. 고스트의 기존 HP는 50으로 기본 캐릭터의 첫 공격에 죽으므로, 피격 모션 확인에는 실제 `take_damage(1)` 경로의 비치명 피해를 먼저 발생시킨다. 그 뒤 실제 무기로 처치하며 전투 능력치와 드랍 표는 바꾸지 않는다. 프레임별 수동 표본 검토는 AI 전투 증거와 별도로 기록한다.

[실제 Main 늑대인간 영상](evidence/pr100-direction-fix/original-based/werewolf-main.mp4), [범위·원본 보존·산출물 해시](evidence/pr100-direction-fix/original-based/preservation-and-scope.json), [고스트 실제 Main 기록](evidence/pr100-direction-fix/original-based/original_based_ghost_gameplay_test-opengl.json)을 보존했다. 제작 중 발견한 프레임 겹침, 불투명 배경, 중복 낫 초안은 적용 수치에서 제외했다. 이 문단의 2개 외형은 `15c71f5`까지의 저장 내역이며, 아래 후속 제작을 포함한 현재 미완료 수는 205종이다.

새 2개 외형을 포함한 APK도 빌드 및 독립 검사에 통과했다. 38개 compiled SpriteFrames, 1,944개 트랙, 10,528개 재생 슬롯, 236개 PNG 임포트와 캔버스 메타데이터가 일치한다. APK는 774,993,177 bytes, SHA-256 `b582568218bcf9083f592e43de52a3635e7fbdb2d926a91bc6fede3502ea4e52`다. [검사 결과](evidence/pr100-direction-fix/original-based/android/android.json). 실제 Android 기기 실행은 여전히 미검증이다. 빌드 후 adb의 읽기 전용 홈 디렉터리 오류를 빌드 실패나 기기 실행 성공과 혼동하지 않는다.

`e66e861`의 CI는 실제 종료 기준 **28 workflow 성공, 1 취소**다. 취소된 Windows 회귀는 마지막 검사들에 도달한 뒤 35분 작업 제한에 걸렸으며, 현재 변경에서 45분으로 늘렸다. 개별 검사 제한과 모든 단언은 유지한다. [실제 종료 결과](evidence/pr100-direction-fix/original-based/e66-ci-summary.json). 이 후속 변경의 CI는 푸시한 정확한 HEAD에서 다시 종료까지 확인해야 한다.

## 여성 사신·오우거와 같은 원본의 지역 개체 추가

`신화-사신(여)`는 기존 카탈로그 이미지 `e090d7a50d6f7a23fe55576c.png`, 오우거는 기존 `16145.png`를 기준으로 제작했다. 원본의 얼굴·의상·무기·색상을 보존하며, 각 104개 실제 포즈를 별도 PNG로 연결했다. 중복 낫·접촉한 프레임·잘못된 행 수의 후보는 제외했다. 당시 창 경비병 후보는 집계하지 않았으며, 아래 세 번째 제작 묶음의 수정 시트로 별도 검증했다.

고스트/글루디오 던전 유령/지옥의 고스트는 기존 `1318.png`, 오우거/기란 평원 오우거/잊혀진 섬 고대오우거는 기존 `16145.png`를 이미 공유한다. 기존 `MonsterArt.material_for`와 `MonsterVisual`에서 사용하지 않는 폴백 색·장비·폭 메타데이터만 공유 비교에서 제외하고, **원본 경로·SHA·종 연결·몸체·표시 높이·공격 형태·모션 설정은 일치해야 한다.** 서로 다른 이미지나 프로젝트 atlas의 장식을 같은 외형으로 대체하지 않는다. 각 대상의 이전 설정을 출처 메타데이터에 보존했다.

여성 사신은 실제 사신 직업·배틀 사이드·변신 장착으로 8방향 이동/대기/공격, 타격 시점, 변신 왕복, 피격과 사망/부활을 검사했다. 피격과 치명 독 피해는 명시적인 production 콜백 입력이며 AI가 사신을 죽인 시험으로 표시하지 않는다. 사망 잔상에도 서로 다른 시트 해상도의 캔버스를 정규화하도록 `scripts/animation/combat_vfx.gd`를 수정했다. 기존 리소스의 잔상 크기·전투 판정은 유지한다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 여성 사신 | 1,516 | 1,535 |
| 오우거 | 1,202 | 1,317 |
| 글루디오 던전 유령 | 1,005 | 1,030 |
| 지옥의 고스트 | 1,005 | 1,014 |
| 기란 평원 오우거 | 1,044 | 1,069 |
| 잊혀진 섬 고대오우거 | 1,126 | 1,135 |

모두 실패 0개다. 지역 개체 검사는 원래 HP·방어·회피·전투 공식을 유지한다. 105레벨 고대 오우거는 훈련용 무기의 30회 한도로 처치되지 않아, 기존 도감의 진명황의 집행검을 정상 장착 경로로 사용했다. 높은 HP 표본의 시도 한도만 늘렸으며 HP를 낮추거나 명중을 강제하지 않았다. 각 실행의 실제 무기·시도 수·드랍·수동 습득은 [검증 결과](evidence/pr100-direction-fix/original-based/expansion-validation.json)와 원시 로그에 기록했다. 저장 확인 1개는 JSON보다 stdout 합계에 포함된다.

추가 검사: 원본/고유 포즈/공유 제한 Python 6개, 검증표의 실패 보고서·미실행 별칭 승격 방지 5개, 기존 native 35,742개, 캔버스 640개, hit feedback 58개 및 VFX 3,000회 스트레스가 통과했다. Godot 전체 임포트와 실제 Main OpenGL 기동도 통과했다. [원본 보존·새 파일 해시](evidence/pr100-direction-fix/original-based/preservation-and-scope.json), [사신 북쪽](evidence/pr100-direction-fix/original-based/original_based_reaper_gameplay_test-authored-N-idle-0.png), [사신 남쪽](evidence/pr100-direction-fix/original-based/original_based_reaper_gameplay_test-authored-S-idle-0.png), [오우거 북쪽](evidence/pr100-direction-fix/original-based/original_based_ogre_gameplay_test-authored-N-idle-0.png).

`bc9dddc`까지의 APK는 **778,717,948 bytes**, SHA-256 **`578d72f67cd3b5b9f2c8bd1a8b0e0af0247c4bc1c8dc924f95b04aeb6311489e`**다. 40개 compiled SpriteFrames·2,024개 트랙·10,736개 재생 슬롯·239개 PNG 임포트 및 SHA·캔버스, ARM64·서명·16KB 정렬·ZIP CRC가 통과했다. [이전 APK 검증](evidence/pr100-direction-fix/original-based/android-expanded/android.json). 실제 Android 기기 실행은 미검증이며, APK 빌드 성공으로 대체하지 않는다.

`15c71f5`는 자동 CI가 등록되지 않아 기존 브랜치의 검증 workflow 29개를 명시적으로 실행했다. 실제 종료 결과는 27 성공·1 실패·1 취소다. `bc9dddc`에서 별도로 실행한 관련 5개 workflow는 2 성공·3 실패로 종료했다. 아래 수정과 최종 HEAD의 CI를 이전 실행과 구분한다.

## 골렘·코카트리스·사이클롭스·창 대장 추가

이번 묶음은 기존 `15738.png`의 라바 골렘 2종, `10358.png`의 아이스 골렘, `14169.png`의 코카트리스 4종, `5683.png`의 사이클롭스, 카탈로그 `4954db6f65010804b3185b7a.png`의 경비병(창) 대장이다. **원본 5개 디자인에서 새 520자세를 제작하여 9종을 연결**했다. 원본 팔레트·얼굴·몸체·장비를 유지했고 상하·좌우를 별도로 그렸다. 코카트리스의 남쪽 접촉이 오른쪽으로 돌아간 후보는 수정했으며, 무기가 이웃 프레임에 닿은 사이클롭스·창 대장 후보는 다시 제작했다. 픽셀 중복·잘림·안전한 프레임 영역 검사도 통과했다.

| 실제 Main 대상 | headless 검사 | OpenGL 검사 |
|---|---:|---:|
| 라바 골렘 | 1,284 | 1,397 |
| 아이스 골렘 | 996 | 1,077 |
| 화룡의 둥지 라바 골렘 | 1,044 | 1,053 |
| 코카트리스 | 956 | 1,117 |
| 기란 평원 코카트리스 | 1,020 | 1,013 |
| 잊혀진 섬 고대코카트리스 | 1,086 | 1,095 |
| 왜곡의 코카트리스 | 844 | 837 |
| 사이클롭스 | 1,204 | 1,302 |
| 경비병(창) 대장 | 1,528 | 1,553 |

모두 실패 0개다. 몬스터는 각 이름별 8방향 실제 AI 추적·공격, 정상 장착 무기로 처치, 원래 확률 드랍, 수동 습득을 검사했다. 코카트리스는 HP 880을 유지한 채 30회 공격 한도를 초과하므로 검사 시도 한도를 200회로 통일했다. 낮은 HP 표본은 처치 즉시 루프를 끝내며 전투 공식을 바꾸지 않는다. 창 대장은 기사 직업에서 기존 크림슨 랜스를 장착하고 변신 176을 적용하여 8방향 타격·변신 왕복·피격·사망/부활을 검사했다. 사망 시험의 들어오는 피해는 기존 사신 시험처럼 명시적인 production 콜백 입력이며 AI 공격으로 표기하지 않는다. [실행 기록 및 검사 수](evidence/pr100-direction-fix/original-based/batch3/validation-summary.json).

원본 참조 222건의 SHA-256과 이전에 추적하던 에셋은 모두 유지됐다. 새 리소스를 Git에 등록한 뒤 735개 ID × 8방향 검증표를 다시 생성했다. 새 제작 리소스 9개, 기존 리소스 36개, 총 45개이며 누락 경로·프레임 무결성 오류는 0개다. 원본/공유/포즈 Python 6개, 검증표 Python 5개, 기존 native 35,742개와 캔버스 640개 검사가 통과했다. 기존 사신과 늑대인간의 Main 회귀도 별도로 통과했다.

최신 로컬 APK는 **786,426,179 bytes**, SHA-256 **`4f43f77b4198ee645f676dcdbe6272b666b23074cbcb3c61066e7f9c053d07b6`**다. compiled SpriteFrames 45개·트랙 2,224개·재생 슬롯 11,256개·PNG 임포트 246개, ARM64·서명·16KB 정렬·ZIP CRC·원본 SHA·캔버스가 통과했다. [APK 검사 결과](evidence/pr100-direction-fix/original-based/batch3/android/android.json). Android 실제 기기 실행은 미검증이다.

이전 CI 실패 세 가지를 다음과 같이 수정했다.

- 아덴 고정 시작점은 몬스터와 1,000px 이상 떨어져 빠른 렌더러에서 180프레임이 접근 도중 끝났다. 실제 스폰된 몬스터 근처의 통행·시야가 유효한 지점으로 검사 시작점을 선택한다. 로컬 37장 캡처와 4개 필드 활성 전투가 종료 코드 0으로 끝났다.
- 군중 검사 종료 후 남은 독·출혈이 새 피해 숫자 VFX를 생성했다. 표본 사이에서 상태 효과도 정리한다. 실제 독·출혈 경로의 수정 전 실패를 재현했고 수정 후 재검사와 32/96/192마리 × 사냥/보스의 6개 OpenGL 표본이 모두 통과했다. 전투 중 실제 상태 효과는 그대로 검사한다.
- L1J 합성 CI는 늑대인간 원본을 별도 `_ci_fixture` 경로로 교체하므로 원본 경로 단언과 충돌했다. 원본 SHA를 항상 검사하면서 명시적으로 선언된 합성 경로와 해당 SHA도 확인한다. 실제 원본 경로와 분리된 동일 TWILIGHT 프로젝트의 합성 경로에서 모두 통과했다. **합성 결과는 원본 화면 검증표에 포함할 수 없도록 거부한다.**

원본 기반 17종의 Main 검사를 CI의 네 작업으로 나눴으며 기존 표본과 단언을 유지했다. [수정 전 CI 종료 결과](evidence/pr100-direction-fix/original-based/batch3/ci-before-fixes/bc9-ci-summary.json)는 성공으로 바꾸지 않았다. 이 문서 저장 후 푸시된 HEAD의 실제 종료 결과는 PR #100의 Checks와 본문에 기록한다. 남은 **205종 제작과 Android 실기기 실행은 미완료**다.

```sh
python3 tools/check_resource_integrity.py --root .
godot --headless --editor --path . --import --quit
godot --headless --path . --quit-after 120
godot --headless --path . --script res://tests/eight_direction_animation_test.gd
godot --headless --path . --script res://tests/native_animation_expansion_test.gd
godot --headless --path . --script res://tests/pr100_direction_gameplay_test.gd
godot --headless --path . --script res://tests/aden_boss_special_test.gd
python3 tests/eight_direction_coverage_audit_test.py
python3 tools/audit_eight_direction_coverage.py --root . --output-dir direction-audit
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results
python3 tools/verify_android_animation_export.py --apk /path/to/TWILIGHT.apk --godot /path/to/godot --android-sdk /path/to/android-sdk --output android-validation
```

소프트웨어 화면 캡처는 Xvfb 등 실제 OpenGL 디스플레이와 `LIBGL_ALWAYS_SOFTWARE=1`을 사용한다. `TWILIGHT_PR100_CAPTURE_DIR`는 실제 Main 방향 검사 화면의 저장 위치, `TWILIGHT_PR100_SECTION=boss`는 기존 보스만 검사하는 선택적 녹화 범위다. 생략하면 전체 검사를 실행한다. 사용자 저장을 보존하려면 각 검사에 별도의 `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`을 지정한다.
