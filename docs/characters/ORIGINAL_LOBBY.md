# 원본 캐릭터 로비 입력과 연출

계정 로비에서 선택한 원본 직업·성별의 전후 효과를 실제 CSB renderer에 연결한다. 캐릭터 본체의 Spine 3.6.52 평가·mesh renderer는 아직 없다. 따라서 이 변경은 **원작 로비 전체 복원 완료가 아니다**. 이미지·스프라이트·애니메이션 이름을 새로 만들거나 다른 캐릭터로 대신하지 않는다.

## 원문 관계와 독립 입력

`lobby_source_catalog.gd`는 검증된 current523 정의의 `ClassAssets → UISpine → AssetView → AssetType`을 원본 ID로 조회한다. 본체는 type 22 Spine이고 전후 효과는 type 101 CSB다. 파일명이 비슷하다는 이유로 두 형식을 혼동하지 않는다. `OffsetX`, `OffsetY`, `Flip`은 출처로 보존한다. 원작 host 좌표·시작 animation·반복 정책은 이 표에 없어 추정 적용하지 않는다.

`lobby_source_selection.gd`는 Main UI·초상화 입력과 별개로 다음 옵션을 받는다. 둘 중 하나만 주거나 pin/원문 신원이 틀리면 거부하고 다른 팩으로 돌아가지 않는다.

```sh
TWILIGHT_SOURCE_LOBBY=/absolute/path/to/verified-lobby-pack
TWILIGHT_SOURCE_LOBBY_SHA256=<original_ui.json의 SHA-256>
```

동일 CLI는 `--source-lobby=PATH`, `--source-lobby-sha256=SHA256`다. generic original UI pack의 파일 크기·SHA 검증에 더해 `lobby_source.kind=twilight.source523.lobby-input.v1`, `source_snapshot=patch523`, 정의 ZIP과 files_info의 정확한 pin을 요구한다. 기존 계정 저장과 선택된 Main UI 팩은 변경하지 않는다.

- 정의 ZIP: 25,031,173 bytes, SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
- current523 `files_info.json.523`: 860,721 bytes, SHA-256 `fefb29fb8126f106e4d127b59a81459efc576d5a6eab8456b4c4988ae390f4dc`.
- 원본 25조합 팩 manifest SHA-256: `c9dc3ff88e11ef6435b13c44790756e9e31c79dcec3d7517ccf5a0cff909a62d`.

완성 입력과 검증 기록은 비공개 Library의 `TWILIGHT_current523_all25_lobby_original_input_and_validation_20261112.zip`에 보존했다. ZIP은 73,991,212 bytes, SHA-256 `d06972e04fd79f1881bf471ae945a36f1de1af1bad11718f83b6fe6f25aa0f70`이며 원본 175파일의 해시를 압축 안에서 전수 재검증했다. 이 비공개 입력은 본체 재생 SDK를 포함하지 않으며, 접근 식별자와 다운로드 주소는 공개 문서에 게시하지 않는다.

공개 Git에는 코드·테스트·문서만 넣는다. 사용자가 제공한 원본과 그에 명시된 원본 아카이브에서 복원한 제3자 아트는 공개 저장소에 포함하지 않는다.

## 확인한 원본 범위

현재 files_info의 SHA-1·크기, 제공 묶음의 SHA-256, DAT 내부 ZIP CRC와 멤버 해시를 검증했다. 옛 아카이브에 있더라도 현재 파일과 해시가 일치할 때만 사용했다. 크기가 같아도 해시가 다른 예전 UI131은 거부했다. atlas는 원문 페이지 이름을 그대로 읽고 명시적인 `lobby_spines` 연결만 사용한다.

| 입력 | 확인한 범위 |
| --- | --- |
| 본체 JSON·atlas | 생성 가능한 25/25 직업·성별, 전부 Spine 3.6.52 |
| atlas 페이지 | 원문이 선언한 PNG 78/78, 이미지 decode·pixel load·선언 크기 일치 |
| 효과 CSB | 원문에서 연결 가능한 고유 16개, 각 dependency closure 완료 |
| 전체 원문 연결 | 21/25 조합; 나머지 4조합은 원문 효과 ID 관계가 불완전 |
| 팩 | 원본 파일 175개, 107,286,414 bytes; 원문 바이트 변경 0 |

현재 AssetView에 없는 효과 ID는 `84513, 84523, 84533, 84543, 166222, 166232`다. 이것은 파일을 확보한 것만으로 해결되는 연결이 아니며 다른 연도 표나 이름이 비슷한 CSB를 대신 쓰지 않는다. 없는 효과는 해당 layer의 `missing_reference`로 유지한다. 팩의 원본 확보는 전체 본체가 화면에 재생됐다는 증거가 아니다.

## 실제 소비 동작과 본체 제약

`lobby_source_presentation.gd`는 뒤 효과 → 본체 → 앞 효과 순으로 노드를 소유한다. CSB는 기존 `sprite_scene.gd`로 원본 transform·timeline·particle dependency를 소비한다. 실제 원문 animation key만 버튼으로 제공하고 사용자가 누르면 1회 재생한다. 기사 남성의 실제 CSB key는 `Loop_On`이다. 다른 캐릭터의 시작 key·loop 정책을 여기서 추정하지 않는다.

미리보기 맞춤은 표시 가능한 실제 Sprite2D quad의 경계로 host만 축소·이동한다. 원본 노드 좌표는 변경하지 않는다. 선택·재생·크기 변경 후 최대 4 frame만 다시 측정한다. 선택 세대가 바뀌면 이전 콜백과 버튼은 무효가 된다. `stop()` 콜백 재진입에서도 이전 소유자와 페이지 lease를 먼저 분리하여 최신 선택을 보존한다.

본체는 JSON·atlas·실제 page SHA와 skeleton version까지 읽은 뒤 `missing_runtime`을 보고한다. 주입 가능한 `spine_factory`는 동일 원본 SHA, major/minor 호환 버전, 자동 시작 비활성 및 실제 animation 재생 API를 증명해야 한다. 현재 기본 실행에는 이 factory를 설치하지 않았다. 원본 25조합 중 path constraint 25개 조합, IK 21개 조합, transform constraint 20개 조합이 있어 단순 bone/sprite 대체로 원본 재생을 주장할 수 없다.

Spine 공식 문서는 export와 runtime의 major/minor 일치를 요구한다. 최신 [공식 Godot runtime](https://en.esotericsoftware.com/spine-godot)을 설치하는 것만으로 3.6.52 호환이 증명되지는 않는다. [버전 안내](https://en.esotericsoftware.com/spine-versioning)에 맞는 실제 평가·mesh renderer 연결이 필요하다. 현재 SDK를 공개 코드에 복사하거나 라이선스 보유를 추정하지 않았다.

`rendered`, `original_render_verified`, `original_lobby_layout_verified`는 계속 false다. 원문 offset을 호스트 미리보기에 적용해 원작 배치로 가장하지 않는다. 원본 미설치·깨진 pin·없는 SDK는 안내를 표시하며 유효한 계정/캐릭터 생성을 막거나 저장을 쓰지 않는다. 초상화 helper와 CSB renderer는 해당 입력이 필요할 때 로드한다.

## 검증과 재개 지점

기준 엔진은 Godot 4.7.2 (`ed1daf0bf`), 사용자 저장과 분리한 XDG profile이다.

| 검사 | 결과 | 의미 |
| --- | --- | --- |
| 원문 관계 catalog | 89/89 fixture, 원문 opt-in 298/298 | ID·형식·25조합·누락 참조; 렌더 검사가 아님 |
| 독립 pack selector | 23/23 | 입력 pair·pin·provenance·Main UI 경계 |
| presentation consumer | 538/538 | lease·재진입·교체·정확한 clip·fit 경계; factory fixture 포함 |
| 계정 로비 UI | 42/42 | 연출 실패 시 생성 허용·선택 콜백 보호 등 |
| 실제 기사 남성 팩 | 31/31 | 실제 CSB mount/명시 재생·2 atlas pages·body runtime 부재·원본 파일 불변 |
| 실제 전체 25조합 팩 | 542/542 | 25 body/78page·16CSB 소비·6누락ID·다른 저장 namespace 불변; SDK 부재 |
| Linux 실제 화면 | 기사 남성 원본 전후 효과 움직임 확인 | 1,050×820 OpenGL Mesa llvmpipe, Dummy audio |

최종 실제 기사 검사에서 script/resource/Unicode 오류 0, 실행 중 source hash 변경 0이었다. Linux 화면에서는 이름 입력·캐릭터 생성 없이 실제 선택 로비의 원문 clip 버튼을 사용했다. 원작 본체 재생·원작 배치 일치·Android 기기 성능은 검증하지 않았다.

기본 core gate는 최신 main `8d030bb5`의 추가 9개 검사를 보존하여 129개 스크립트다. 원본은 공개 CI에 넣지 않으며 원문 opt-in 결과와 CI fixture 결과를 구분한다. 남은 작업은 (1) 실제 Spine 3.6 호환 evaluator/mesh renderer 설치·연결, (2) 원문에서 없는 6개 효과 ID의 검증 가능한 연결 증거, (3) 원작 배치/자동 연출 증거와 Android 실측이다.
