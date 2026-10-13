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

| 분류 | 실제 8방향 연속 프레임 연결 | 전체 | 적합한 원본 부족 |
|---|---:|---:|---:|
| 영웅 이상 변신 | 126 | 180 | 54 |
| 일반 몬스터 | 119 | 258 | 139 |
| 보스 | 31 | 60 | 29 |
| 기본 외형 | 4 | 4 | 0 |

기존 34개 확장 공용 외형과 기사·해골 표본 2개를 재사용했다. 이번에는 `class:1/2/3`을 기존 지팡이·활·단검 외형에 추가 연결했다. 새 이미지나 중복 atlas를 생성하지 않았다. 직업과 기본 외형의 독립 선택, 변신의 기존 정체성·장비 표현을 보존한다.

고정된 공개 소스의 377개 애니메이션 정의와 현재 로컬 자료를 확인했지만, 나머지 외형에 맞는 날개·마물·동물·특수 의상·창·총·이도류·클로·체인소드·낫 등의 8방향 원본은 확보하지 못했다. 서로 다른 몸체를 무리하게 대체하지 않았다. **남은 54/139/29종은 미완료**다. [정확한 ID·사유·원본 목록](evidence/pr100-direction-fix/coverage/missing-native-sources.json).

전체 413개 변신, 318개 몬스터/보스, 4개 기본 외형의 **735개 ID × 8방향 = 5,880행** [검증표](evidence/pr100-direction-fix/coverage/all-identities-eight-directions.csv)를 자동 생성했다. 실제 RGBA 고유 프레임과 재생 슬롯 수를 구분한다. `source_metadata_only`, `actual_gameplay=not_run`은 전수 화면 승인이 아니라는 뜻이다. 실제 플레이한 표본은 별도 [Main 실행 기록](evidence/pr100-direction-fix/gameplay.json)으로 제공한다.

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

## 다음 제작 범위

사용자 후속 지시에 따라 남은 222종은 각 대상의 현재 원본 이미지를 베이스로 자체 제작한다. 원본의 실루엣·팔레트·얼굴·장비·무기 특징을 유지하고, 원본 파일을 덮어쓰지 않는 별도 모션 리소스로 연결한다. 원본 경로·SHA-256과 새 리소스의 대응을 남긴다. 이 단계는 위 연결 수치에 아직 포함하지 않는다.

```sh
python3 tools/check_resource_integrity.py --root .
godot --headless --editor --path . --import
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
