# 실제 8방향 스프라이트 재구축 — PR #100

## 후속 수정: 이동과 반대 방향을 바라보는 오류

사용자의 모션 품질에 대한 긍정적인 피드백과 방향 오류 지적을 반영했다. 초기 검토에서 원본 방향을 180도 반대로 해석한 오류가 있었다. 실제 원본 순서는 **W / SW / S / SE / E / NE / N / NW**이고, 게임의 E / SE / S / SW / W / NW / N / NE에는 원본 번호 **4 / 3 / 2 / 1 / 0 / 7 / 6 / 5**를 연결해야 한다.

runtime 수정 SHA **`292c80363fbc88d18a004277f740749b86b7fd71`**에서 기존 두 본체의 5동작을 올바른 방향과 장비 layer 순서로 다시 합성했다. 이동 입력·좌표계·ActorMotion·피해 계산은 바꾸지 않았다. 변환기가 같은 오류를 다시 생성하지 않도록 원본 순서도 고쳤다.

- 수정 전 해골의 방향별 픽셀 reference 40건 실패를 재현했다. 기사 8시점 reference도 추가한 최종 검사 **1,362 assertions PASS**, 기존 타격 lifecycle **158 checks PASS**, catalog / restore PASS.
- 실제 Main에서 **8방향 이동 화면 모두** 이동 화살표와 몸의 방향이 일치하는 것을 검토했다. 대표 해골 AI 추적/공격, 기사 9타격, 피격·사망·바닥 드랍·수동 습득·변신 왕복도 통과. 몬스터의 전 방향 시각 검증과는 구분한다.
- [수정 후 실제 게임 영상](https://drive.google.com/file/d/1yK6vMn9c8FhdTpnv1Zhr1JcFFmilvcnM/view): **23.733초 / 712프레임**. 화살표와 방향/원본 번호는 선택적 QA 표시이며 평상시 게임에는 나타나지 않는다.
- [픽셀 오류 재현·회귀·Main 로그 및 리소스 해시](evidence/direction-correction/) 보존. 처음 import의 sandbox 로컬 TCP 생성 오류는 별도 기록하고, 네트워크 권한이 제공된 실행에서 ERROR 없이 import를 완료했다.
- 현재 10장 아틀라스의 원시 RGBA 합계는 **15.375MiB**다. 아래의 15.516MiB 측정 및 영상 링크는 방향 수정 전 `fe0cef3`의 기록이다.

아래 초기 기록은 보존한다. 방향 판정과 현재 게임 영상은 이 후속 수정 기록을 기준으로 한다.

이 변경은 **흑기사(변신 ID 46)와 해골 근위병 2본체**의 실제 연속 프레임을 기존 TWILIGHT에 적용한다. 전체 캐릭터/몬스터 완료가 아니다. 최초 main `434b904`에서 시작했고, 작업 중 갱신된 main `8007649`(PR #96/#97/#98)를 보존하여 merge했다. [PR #100](https://github.com/zoog136-hash/-/pull/100)은 `feature/twilight-animation-20261013`의 draft이며 main에 병합하지 않았다. 실제 영상·깨끗한 clone 검증의 runtime SHA는 `fe0cef3106442b4369852b08ba82e5e790fa7ecb`이다.

영상: [전후 나란히 비교](https://drive.google.com/file/d/1SrBIY5QfJRwjnS-Kaxh77tQYIUkCzzMm/view) · [변경 전 전체 화면](https://drive.google.com/file/d/1dTxRtYMemnxMILpLMfpbN9UYM5EkdTRA/view) · [변경 후 전체 화면](https://drive.google.com/file/d/1fdgRWQPNUGajtYQUXXeyQ9m2WTI5PQLK/view). 비교 영상은 같은 실제 Main 녹화의 중앙을 잘라 나란히 놓은 것이며 새 장면이 아니다. 후반 전투의 세부 사건은 각 전체 영상/JSON에서 확인한다.

## 바뀐 모습과 실제 적용 수

| 대상 | 이전 | 현재 | 범위 |
|---|---|---|---|
| 흑기사 `transform:46` | 한 시점 원화를 변형한 atlas | 독립된 8시점, 걷는 다리와 검을 휘두르는 팔/무기 연속 프레임 | 변신 **1/413** |
| 해골 근위병 | 정적 외형 + 절차적 방향/동작 | 검·방패를 유지하는 8방향 이동/공격/피격/넘어짐 | 일반 몬스터 **1/258** |
| 기본 sprite 외형 `class:0` | 4방향 class sheet | 기사와 같은 공통 SpriteFrames | 기본 시트 **1/4**. 13개 직업의 대표 신화 변신과는 별도 |
| 보스 | 기존 유지 | 이번에 신규 적용 없음 | **0/60** |

본체별 방향당 대기 4, 이동 8, 공격 4, 피격 2, 사망 6개의 실제 자세가 있다. 80개 동작/방향 track, 384개의 동작 프레임 슬롯, **동작 간 공유를 제거한 고유 픽셀 이미지 352개**다. 대기 왕복 재생은 기존 자세 참조를 반복하며 새 프레임으로 세지 않는다. 방향을 만들기 위한 이미지 회전/반전은 없다.

413개 변신의 유효한 표시/교체 경로 검사는 전용 연속 모션 보유율과 다르다. 남은 변신 412종, 일반 몬스터 257종, 보스 60종은 각자의 기존 외형과 대체 동작을 유지한다. 같은 기사/해골 본체를 다른 ID에 덮어쓰지 않았다. 전수 장부는 기존 `data/resource_delivery_ledger.json`에 갱신했다.

## 입력과 권리

- 기존 class sheet, 변신 DB/atlas, 몬스터 family art, 기존 ActorMotion / AnimationCatalog / Player / Monster 호출 경로를 조사했다.
- 제공된 소스 키트 SHA-256 `99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98`는 PC 계열 남녀 용기사 21624/21653이다. 기사/해골에 대응하지 않으며 재배포 권리도 확인되지 않아 이번 runtime에 넣지 않았다. 기존 해시/CRC/추출 기록을 재사용했다.
- 실제 사용: Flare Game `af6eee6d339ac98011864bfe89da837fe7769c28`의 공개된 **2D PNG**와 프레임 rectangle/offset 정의, 방향별 장비 layer 순서. CC BY-SA 3.0, Misha의 해골 검 concept CC BY 3.0. [출처/이용 조건](../../assets/actors/eight_direction/ATTRIBUTION.md)에 변경 내용을 명시했다. 새 3D 모델·장면·렌더를 만들지 않았다. 기존 삽화의 세부 장식까지 동일하게 복원한 것은 아니다.
- 공식 영상 `taitan.mp4` 7.0 → 7.2–7.3 → 7.4–7.6초의 준비/접촉/복귀 구분을 참고했다. 60fps 인코딩을 원작 모션 FPS로 사용하지 않았다. Flare duration과 TWILIGHT 타격 비율은 원작 시간값이라는 주장이 아니다.

## 구현

기존 `ActorMotion` 한 개가 이동 벡터 → E/SE/S/SW/W/NW/N/NE → 상태별 SpriteFrames를 선택한다. 원본의 개별 발 offset으로 장비를 합성하고, `AtlasTexture.margin`으로 고정된 256×256 발 캔버스를 복원한다. 새 두 대상에는 root 흔들기/회전/비율 변형과 가짜 방향 shader를 적용하지 않는다. 그림자가 이미 있는 프레임에는 이중 그림자를 표시하지 않는다.

공격 수치·공격 간격·피해 계산을 바꾸지 않았다. 기존 타격 사건과 frame 2 접촉 자세가 같은 타임라인을 따른다. 원본 준비/접촉/복귀 순서는 유지하고 기존 공격 속도에 맞춰 시간을 배분한다. 몬스터는 0.8초 사망 프레임 후 마지막 자세를 유지하며 fade하고 기존 제거/보상 경로를 따른다.

플레이어 사망은 **기존 즉시 부활 + 사망 위치의 corpse VFX** 흐름을 유지한다. 새 사망 frames가 이 경로에 연결되지만 카메라가 부활 위치로 이동하므로, 부활 전 죽는 동작을 화면에 끝까지 보여주는 기능은 이번 변경에 포함되지 않는다. 전용 시전/특수 공격 art도 이번 범위 밖이다.

## 검증과 한계

- Godot **4.7.2**, Compatibility, Linux Xvfb + Mesa llvmpipe. 사용자 세이브를 쓰지 않는 별도 XDG 경로.
- `python3 tools/check_resource_integrity.py --root .`: 기존 723 atlas / 41442 cell 무결성 통과. 이 수치는 새 원본 모션 수가 아니다.
- `tests/eight_direction_animation_test.gd`: **1,314 assertions, 0 failures**. 8방향 5동작, 비어 있지 않은 고유 프레임, 발 offset, 반전/회전 없음, 0.18/0.72/1.44초 공격 및 큰 시간 건너뜀 검증.
- `actor_motion_test`, `authored_state_motion_test`, `monster_motion_test`, `animation_catalog_test`, `animation_restore_test`: 통과. 최신 main 타격 검사 `combat_timeline_lifecycle_test`: **158 checks 통과**. 기존 테스트의 고정된 `attack`/frame 3 가정은 새 실제 profile/방향 track을 검사하도록 바꿨으며 판정 검사를 제거하지 않았다.
- `authored_frames_test`, `full_visual_manifest_test`: 통과. `animation_presentation_test`: **76,231 checks, 변신 413 / 몬스터 318 통과**. 이는 전수 재생 경로 검사이며 전수 시각 승인이나 전용 모션 보유 수가 아니다. 새 해골의 0.8초 사망 자세가 끝나는 바로 그 시점에 fade를 기대한 기존 검사 1건은 실패했고, profile의 동작 길이 이후를 검사하도록 수정한 후 통과했다. 실패 로그와 수정 후 로그를 함께 보존한다. 5프레임 legacy fixture도 기본 class 변경에 영향을 받지 않도록 실제 legacy sheet를 명시했다.
- `capture_eight_direction_play.gd`: **실제 Main.tscn**의 아덴 맵에서 흑기사 장착, 키 입력 8방향 이동, 자연 스폰 해골 AI 추적/공격, 연속 기본 공격 9회, 몬스터 사망, 실제 바닥 드랍 2개, 수동 습득, 변신 왕복을 검증한다. 별도 게임/HTML/3D 렌더러가 아니다. 자세 식별을 위해 실제 Camera2D를 1.8배 확대하고, 장면의 다른 몬스터만 검사 중 멈췄다. 다수 몬스터 성능 시험으로 제시하지 않는다.
- 캐릭터 모든 방향의 공격/피격/사망은 리소스 및 재생기 검사다. 실제 전투 영상은 대표 방향의 교전이며 전 방향 전 개체 시각 검증은 아니다. 사용자 시각 승인을 받았다고 기록하지 않는다.
- 처음 선택한 검사 동선이 벽을 통과하여 실패한 뒤 실제 스폰 후보와 왕복 통행 경로를 사용했다. 추가 PNG 임포트 완료 전 검사 및 120초 임포트 timeout 실패도 구분해 보존했다. 수정 후 완료된 로그만 통과로 사용한다.
- Android SDK/build-tools·실기기 검증은 없음. Android 빌드/부팅/플레이 성공을 주장하지 않는다. 전체 프로젝트의 기존 실패 항목은 이전 main 기준 보고서와 구분하며 이번 변경과 무관한 전체 기능을 다시 수정하지 않았다.

| 품질 항목 | 판정 | 근거/범위 |
|---|---|---|
| 몸·발·무기 정렬 | 표본 통과 | 실제 Main 화면, 원본 offset/레이어 순서, 패킹 전후 가시 픽셀 일치 |
| 동작 식별 | 표본 통과 | 8시점 이동, 준비/검 휘두르기/복귀, 해골의 넘어짐 확인 |
| 타격 동기 | 통과 | 공통 타임라인 1,314 assertions 및 lifecycle 158 checks, 실제 9타격 교전 |
| 지형/보스 회피/전체 UI | 이번 범위 미검증 | 기존 기능 유지, 별도 리메이크 성과로 세지 않음 |
| 성능 | 부분 검증 | 아틀라스 픽셀량/용량 감소 확인. 60fps·p50/p95·실기기 미검증 |

## 메모리와 전달

투명 여백 제거 전후 동일 384프레임의 가시 픽셀과 alpha를 복원 비교하여 **차이 0**을 확인했다. 10장 원시 RGBA 텍스처 합계는 **100,663,296 → 16,269,312 bytes (96 → 15.516MiB, 83.84% 감소)**다. 이는 GPU 업로드 대상 픽셀량 계산이며 실제 프로세스 메모리 피크가 아니다. Atlas 최대 폭 1024, 높이 640 이하. 실제 전체 게임 60fps, frame time p50/p95, Android 성능은 미검증이다. 소프트웨어 렌더러 녹화 시간을 실기기 성능으로 보고하지 않는다.

추가 runtime art는 약 3.7MiB이며 Git에 포함된다. 연구용 원본 PNG/ZIP/영상은 프로젝트에 넣지 않았다. 프레임 해시는 [resource-sha256.json](evidence/eight-direction/resource-sha256.json), 패킹 검증은 [atlas-packing-proof.json](evidence/eight-direction/atlas-packing-proof.json)에 있다.

`fe0cef3`을 GitHub에서 새로 clone한 환경에서 .godot 캐시 없이 import **244.949초**, headless boot 검사 **13.536초**, native-frame 검사 **0.737초**, 저장/변신 복원 검사 **16.979초**에 통과했다. boot 시간은 `--quit-after 60` 실행 전체 시간이며 첫 조작 가능 시점 측정이 아니다. import와 소프트웨어 영상 녹화가 겹쳤으므로 성능 전후 비교에 사용하지 않는다. [깨끗한 clone 실행 기록](evidence/eight-direction/clean-execution.json) 참조.

최종 패킹본 Main 녹화는 **23.7초 / 711프레임 / 실패 0**이다. [실제 실행 사건 기록](evidence/eight-direction/after/play-evidence.json)과 [렌더 로그](evidence/eight-direction/final-play.log)를 포함했다. V-Sync 변경을 지원하지 않는 llvmpipe 경고가 있으며 스크립트/리소스 오류는 없다. 이 장면의 느린 소프트웨어 녹화로 60fps 달성을 주장하지 않는다.

Drive 영상 3개 업로드 후 전체 전/후 영상의 메타데이터·크기를 확인했다. 비교 영상은 연결된 계정으로 실제 다시 내려받아 SHA-256 `656c774a6954db430a93b28efce36805b0caec6f9f6e1dcb65b305dda782d83c` 일치를 확인했다. 익명 공개 공유 및 브라우저 플레이어 재생 여부는 미검증이다. 크기·시간·전체 SHA는 [video-files.json](evidence/eight-direction/video-files.json), 전달 확인 범위는 [video-delivery.json](evidence/eight-direction/video-delivery.json)에 있다.

실행: PR #100 브랜치를 clone하고 Godot 4.7.2로 `project.godot`을 import한 뒤 `Main.tscn` 실행. **메뉴 → 변신 → 고급 ‘흑기사’ → 변신/적용**을 선택해야 새 변신을 볼 수 있다. 시작 시 자동 선택되는 ‘신화-기사(여)’에는 이번 모션이 적용되지 않는다. WASD/방향키 이동, Space 공격. 해골 근위병은 아덴 용의 계곡의 기존 스폰을 사용한다.

```sh
git clone --branch feature/twilight-animation-20261013 https://github.com/zoog136-hash/-.git TWILIGHT
cd TWILIGHT
# 아래 경로를 설치한 Godot 4.7.2 실행 파일로 지정한다.
GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT_BIN" --headless --editor --path . --import
python3 tools/check_resource_integrity.py --root .
"$GODOT_BIN" --headless --path . --script res://tests/eight_direction_animation_test.gd
"$GODOT_BIN" --path .
```

임포트 캐시·연구 폴더는 복원할 필요가 없다. 새로 사용되는 PNG/TRES/라이선스는 Git에 포함되어 있다. 이번 단계 커밋은 `291b082`(조사), `985ccec`(대기/이동/공격), `23b371c`(피격/사망), `5a4a48e`(최신 main 보존), `fe0cef3`(가시 픽셀 손실 없는 패킹)이다. 변경 파일은 `assets/actors/eight_direction/`, `data/combat_animation_profiles.json`, 기존 단일 `data/resource_delivery_ledger.json`, `scripts/animation/{actor_motion,animation_catalog,animation_profile}.gd`, `scripts/{player,monster}.gd`, 관련 애니메이션 테스트 및 변환 도구다. 피해 수식·아이템·맵·HUD 코드는 이번 PR의 main 대비 변경 대상이 아니다.

다음 작업은 남은 ID별 정체성·무기·재배포 조건이 맞는 연속 프레임 확보이며, 이 두 본체 복제로 전체 적용률을 올리지 않는다. 재개 위치와 명령은 [REMAKE_CHECKPOINT.md](REMAKE_CHECKPOINT.md)에 유지한다.
