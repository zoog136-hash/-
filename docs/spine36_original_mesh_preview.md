# 원본 Spine 3.6 mesh 미리보기

이 문서는 원본 로비 본체를 공식 Spine 3.6 평가기로 계산하고 Godot에서 mesh로 표시하는 별도 미리보기 경로를 설명한다. [기존 로비 문서](characters/ORIGINAL_LOBBY.md)의 원본 확보·CSB 연결 기록과 구분한다. 실행한 데이터 검증과 미실행인 화면·기기 검증은 아래에서 구분한다. 코드나 입력 파일이 존재한다는 이유로 원작 재생 완료를 선언하지 않는다.

## 라이선스와 SDK 경계

사용자는 이번 작업에 필요한 Spine SDK 라이선스 보유를 확인했다. 평가기는 공식 [spine-runtimes](https://github.com/EsotericSoftware/spine-runtimes/tree/654c20e5b0e523040b6366bbd1042510d2645134)의 3.6 커밋 `654c20e5b0e523040b6366bbd1042510d2645134`를 별도로 설치해 사용한다. 원본 본체 25개는 모두 export 버전 3.6.52이며, 다른 major/minor의 최신 runtime으로 호환을 가정하지 않는다.

SDK 소스는 이 저장소에 vendoring하지 않는다. `bake_mesh.py`는 외부 SDK의 정확한 HEAD와 깨끗한 작업 트리, include/src 및 라이선스 파일을 확인한 뒤 이 저장소의 C wrapper를 빌드한다. SDK·wrapper·실행 파일·컴파일러의 신원을 proof에 남기며 fast-math를 사용하지 않는다. [도구 안내](../tools/spine36/README.md)와 [보존한 라이선스 고지](../tools/spine36/SPINE_RUNTIME_LICENSE.txt)를 따른다. SDK 사용 허가는 원본 게임 아트나 그 파생물의 공개 재배포 허가와 별개다.

## 원본 입력과 파생 packet

고정 원본 팩은 JSON·atlas 각 25개, atlas가 실제 선언한 PNG 78개, 연결 가능한 효과 CSB 및 의존 파일을 포함한 **175파일, 107,286,414 bytes**다. `original_ui.json` pin은 다음과 같다.

```text
c9dc3ff88e11ef6435b13c44790756e9e31c79dcec3d7517ccf5a0cff909a62d
```

이 pin은 보존할 원본 입력 manifest의 신원이다. 원본 바이트·atlas 페이지 closure 검증은 JSON attachment와 atlas region의 의미적 연결, GPU 출력 또는 원작 배치 검증과 다른 단계다. 원본 파일과 manifest를 다시 쓰거나 다른 직업의 atlas·이미지로 대체하지 않는다. 이미지·스프라이트를 새로 생성하지 않는다.

파생 mesh 출력은 원본 팩 밖의 별도 비공개 디렉터리에 쓴다. 원본 JSON·atlas·PNG의 SHA256과 크기, SDK pin, 실제 클립 이름·duration·샘플 시간이 파생 데이터의 provenance로 연결된다. shared geometry 변환은 동일한 page/UV/index를 공유하고 모든 위치·색·시각 값을 보존하며 양자화하지 않는다. inline 결과와 proof를 유지하고, 디스크에 쓴 compact 결과를 binary64 의미 digest로 다시 비교한다.

미리보기 설치도 명시적인 opt-in이다. 별도로 조립한 preview packet은 원본과 파생 파일의 신원을 유지하고 `lobby_spines[원본 JSON 경로].mesh_bake`에 `path`, `bytes`, `sha256`, `compression`을 명시한다. 현재 factory가 허용하는 파생 경로는 `derived/spine/*.mesh.json`, compression은 `none`이다. 이 preview packet의 manifest pin은 새로 계산하며 고정 원본 pin을 재사용하지 않는다. 원본 175파일의 바이트는 그대로 보존한다. 별도 적용 팩은 이 신원을 유지해 조립하며 원본 입력 팩을 덮어쓰지 않는다.

로비 선택 옵션은 기존 `--source-lobby=PATH`, `--source-lobby-sha256=SHA256` 또는 `TWILIGHT_SOURCE_LOBBY`, `TWILIGHT_SOURCE_LOBBY_SHA256` 쌍이다. 파생 packet을 사용할 때는 그 packet의 경로와 새 manifest pin을 함께 선택한다. `mesh_bake`가 없고 별도 factory도 없으면 본체는 `missing_runtime`으로 남는다. 선택된 파생 파일의 크기·SHA·원본 JSON/atlas/page 신원·SDK 버전·클립 집합이 다르면 오류를 반환하며, 다른 그림으로 대신 성공 처리하지 않는다.

## 평가·재생의 호스트 정책

`--fps 60`은 이 미리보기의 **초당 60개 mesh 샘플 정책**이다. 원본 클라이언트의 프레임 주기나 기기에서의 60 FPS를 증명하지 않는다. 프로젝트의 실제 화면 FPS 상한과도 별개다. 각 애니메이션은 setup pose에서 독립적으로 평가하며 원본 duration의 마지막 샘플을 한 번만 보존한다. 같은 시각의 중복 샘플은 제거해 시간이 엄격히 증가하도록 한다. player는 현재 시간 이하의 마지막 샘플을 표시하며 샘플 사이의 새 pose를 추정하지 않는다.

가중 mesh, linked mesh와 deform, IK·transform·path constraint, attachment 변경·색·draw order 및 clipping은 외부의 고정 공식 SDK가 평가한다. Godot player는 계산된 mesh와 원본 PNG를 소비한다. `spBone_setYDown(1)`은 Godot 미리보기 좌표 정책이며 원본 호스트 offset·Flip·크기를 복원했다는 뜻이 아니다. 이벤트를 원본 게임 callback으로 실행하거나 다른 애니메이션을 섞지 않는다.

현재 exporter는 `premultiplied_alpha=false`인 straight-alpha 호스트를 명시한다. 원본 PNG를 수정하거나 원작의 texture upload/PMA 정책을 확정한 결과가 아니다. light color는 skeleton×slot×attachment, dark RGB는 3.6 Cocos의 skeleton×attachment×slot-dark 관계를 사용한다. 파생 dark의 네 번째 성분은 이 straight-alpha 호스트에서 0이며, SDK가 6자리 dark RGB를 읽을 때 사용하는 `-1` sentinel을 shader alpha로 넘기지 않는다.

Godot player는 normal·additive·multiply·screen을 `blend_disabled` shader에서 source와 목적지 색으로 계산한다. 각 mesh batch 직전의 `BackBufferCopy`로 목적지를 읽는다. 사각형 복사 최적화는 Godot 4.7.2 커밋 `ed1daf0bf001b61586d9930840f2f1394092c079`의 `gl_compatibility`, 유효한 변환·경계, interpolation 비활성 및 CanvasGroup/부모 clipping 등이 없는 조건에 한정한다. 그 밖에는 전체 viewport 복사로 돌아간다. 이는 Godot 호스트의 합성·성능 정책이며 원작 GPU 출력의 동일성 증거가 아니다. Android GPU에서의 정확도·비용은 별도로 측정해야 한다.

설정만으로 자동 재생하지 않는다. 대소문자를 구분하는 실제 source clip과 명시적인 반복 인수로 `play_source_animation(name, repeat)`를 호출한다. 기본 반복 값은 false다. 기존 원본 효과 CSB의 수동 1회 재생과 본체 mesh 재생도 각자의 클립 체계를 유지한다.

## 누락된 미사용 attachment 선언의 제한된 처리

동일 stem의 JSON→atlas region 검사에서 **23쌍은 stock loader의 region 연결 조건을 충족**했다. 나머지 두 쌍에는 다음 선언이 하나씩 누락돼 stock SDK가 로드에 실패한다.

| 원본 JSON | skin / slot / attachment / path | 누락 |
| --- | --- | --- |
| `Spine_Knight_Male.json` | `default / Face / Face / Face` | atlas region `Face` |
| `Spine_Elf_Male_2nd.json` | `default / zuobi1 / zuobi1 / zuobi1` | atlas region `zuobi1` |

두 선언 모두 default setup에서 선택되지 않고, 제공된 전체 35개 source clip의 attachment 및 deform/FFD timeline에 참조가 없으며 linked-mesh parent도 아니다. 이것은 이 player가 사용하는 setup·명시 클립·linked-mesh graph 범위의 도달 불가 증명이다. 외부 클라이언트가 임의로 `setAttachment`를 호출하지 않는다는 전역 주장은 아니다.

`bake_mesh.py`는 각 누락 경로에 이 조건을 다시 증명한 뒤에만 wrapper에 전달한다. wrapper는 공식 AttachmentLoader의 **NULL 반환 + 오류 없음 → 해당 선언 건너뛰기** 계약을 사용한다. 원본 JSON·atlas를 삭제·수정하거나 region을 새로 만들지 않는다. setup·클립·deform·linked parent에서 참조되는 누락이면 즉시 실패한다. 실제 건너뛴 개수와 `source.unreferenced_missing_attachments`를 proof·SDK log에서 대조한다.

보관된 native SkeletonJson 코드에도 조건부 NULL/no-error skip 분기는 있다. 하지만 원작 attachment callback 본문이 제공되지 않아 원작이 `Face`나 `zuobi1`을 같은 정책으로 처리했다고 단정할 수 없다. 이 경로는 TWILIGHT가 검증 범위를 명시한 독립 호스트 정책이다. 공식 계약은 [AttachmentLoader.h](https://github.com/EsotericSoftware/spine-runtimes/blob/654c20e5b0e523040b6366bbd1042510d2645134/spine-c/spine-c/include/spine/AttachmentLoader.h)를 참고한다.

## 효과 6개와 원본 호스트의 확인 범위

현재523 `ClassAssets`는 아래 여섯 효과 ID를 참조하지만 실제 42,968행 `AssetView`에는 해당 ID가 없다. 다른 표·이름이 비슷한 CSB·다른 용도의 Prince/Berserker 효과를 대체 연결로 쓰지 않는다.

| 효과 ID | 원본 역할 |
| --- | --- |
| `84513 / 84523` | ClassID 8, GenderID 2 뒤 / 앞 효과 |
| `84533 / 84543` | ClassID 8, GenderID 1 뒤 / 앞 효과 |
| `166222 / 166232` | ClassID 5, GenderID 1 및 2 뒤 / 앞 효과 |

현행 files_info와 크기·SHA1이 일치하는 UI1.dat에서 로비 호스트 CSB 8개를 확인했다. Create/Select에는 뒤 효과 → `ChracterAppear` → 앞 효과 순서가 있으며, 앞·뒤 ProjectNode는 원본 1200×675 기준 `(600,337.5)`, 빈 파일명이다. `ChracterAppear`의 본체 노드는 `(-7,0)`에 있고 `Char_Ani_Start` 클립 구간은 5..45다. action.duration=39와 클립 구간을 혼동하지 않는다.

이 구조 확인만으로 원작의 최종 본체 위치·크기·효과 연결·시작 클립·반복 정책을 복원했다고 주장하지 않는다. 호스트 CSB의 `currentAnimationName`이나 clip 존재도 자동 실행 증거가 아니다. 제공된 Create/Select 생성자 이후의 이벤트·helper 본문에 공백이 있어 최종 호출 관계가 미확정이다. 몸체의 FX 이름 슬롯도 누락된 외부 효과를 대체한다는 증거가 아니다. 여섯 역할은 `missing_reference`로 유지한다.

## 실제 CLI로 재현

다음은 저장소 루트에서 실행하는 Bash 예다. 경로는 각자의 실제 비공개 원본·SDK·출력 경로로 바꾼다. 출력은 원본 팩 밖이어야 한다. `--body`를 생략하면 manifest의 명시적 25개 본체 전체가 대상이다. 특정 본체만 평가하려면 `--body UI/Spine/원본파일명.json`을 반복한다.

```bash
python3 tools/spine36/bake_mesh.py \
  --pack /absolute/verified-original-lobby-pack \
  --manifest-sha256 c9dc3ff88e11ef6435b13c44790756e9e31c79dcec3d7517ccf5a0cff909a62d \
  --sdk /absolute/spine-runtimes-3.6 \
  --output /absolute/derived-inline \
  --fps 60

mesh_inputs=()
for mesh_input in /absolute/derived-inline/*.mesh.json; do
  mesh_inputs+=(--input "$mesh_input")
done
python3 tools/spine36/compact_mesh.py \
  "${mesh_inputs[@]}" \
  --output /absolute/derived-compact \
  --pack /absolute/verified-original-lobby-pack \
  --manifest-sha256 c9dc3ff88e11ef6435b13c44790756e9e31c79dcec3d7517ccf5a0cff909a62d

python3 tools/spine36/verify_compact.py \
  --directory /absolute/derived-compact \
  --pack /absolute/verified-original-lobby-pack \
  --manifest-sha256 c9dc3ff88e11ef6435b13c44790756e9e31c79dcec3d7517ccf5a0cff909a62d
```

`bake-summary.json`과 개별 `.mesh.proof.json`은 평가·원본 신원 증거다. compact 출력의 `final-summary.json`은 정확한 전체 본체 집합, 원본 불변, 엄격한 시간·색·유한 geometry·triangle 범위 및 inline/compact 의미 일치를 다시 검사한 최종 데이터 gate다. subset 평가 결과를 전체 25개 검증 결과로 쓰지 않는다. 각 파일의 hash와 실제 전달 상태도 별도로 남긴다.

## 적용 및 검증 범위

| 단계 | 이 문서의 상태 |
| --- | --- |
| 원본 175파일 보존·입력 pin | 확보 기록과 바이트 검증 범위 확인 |
| 23 stock-compatible / 2 미참조 누락 선언 | 위 제한 범위의 의미 검사 근거 확인 |
| 최종 exporter 25개 실행 수·클립·샘플·용량 | 25본체·35클립·14,574프레임, mesh 1,236,829,873B. 최대 개별 122,785,859B. |
| compact 최종 디스크 검증·preview packet 신원·전달 | 전체 25개 데이터 gate 통과. 원본 175개·107,286,414B 불변. 별도 팩 manifest SHA256 `5a252befd85166b587e067fbd0839a90a774c162fab598da500959d9682a6700`. |
| player fixture·실제 전체 packet 소비 | player fixture 258, factory fixture 271 통과. 실제 여성 기사 inline/compact 각 17통과, 세 프레임의 packed geometry/UV/index/tint/blend SHA와 extent 동일. 전체25개 Godot 소비는 미실행. |
| 실제 GUI의 본체 움직임·합성·반복 및 성능 | 여성 기사 inline→compact parse+configure 11.281→3.524초, 최대 RSS 1,395,572→793,912kB(동일 Linux headless 환경). 전체 GUI·GPU·Android 성능은 미실측. |
| 원작 pixel 출력·최종 로비 배치·자동 연출 | **미검증** |
| Android 기기 실행·화면·메모리·FPS | **미검증** |

`original_render_verified`와 `original_lobby_layout_verified`는 계속 false다. 공식 SDK 계산 성공, 데이터 gate 통과, Godot 표시, 원작 동등성 및 Android 실측을 서로 다른 상태로 기록한다. 원본과 파생 아트는 비공개로 보존하고 공개 문서에는 접근 URL·Library 식별자를 적지 않는다.
