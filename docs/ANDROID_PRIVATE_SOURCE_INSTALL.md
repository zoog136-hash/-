# Android 새 원본 자동 설치 — 구현 상태, 미검증

빈 Termux 게임 폴더의 최초 설치와 이후 업데이트에 같은 진입점
`tools/android/install_private_sources.sh`를 사용한다. 기준 main은
`4d18a44cd3fa3eccbc49ef661b9e09ea8706eaa8`이다. 기존 ZIP 업데이터와
PR267/269/270/271/272의 소스는 수정하지 않는다.

사용자 지시로 구문 검사, 추가 테스트, 설치 실행, 게임 부팅, 렌더, CI를
실행하지 않았다. 이 문서는 코드 구현과 기존 공식 인계 확인만 기록한다.
Android 동작, 속도, 전체 원본 적용 성공을 검증한 결과가 아니다.
main에는 `.agents/skills`가 존재하지 않아 해당 로컬 스킬은 읽을 수 없었다.
AGENTS.md와 프로젝트/리소스 보존 규칙을 읽었고 검사는 사용자 금지에 따라 생략했다.

## 한 번의 설치/업데이트 명령

비공개 원본 때문에 휴대폰에서 사용자 자신의 Google Drive 인증이 필요하다.
기존 rclone 원격 `twilight-drive`를 재사용한다. 없으면 같은 명령 중
`rclone config`가 열리며 해당 이름의 Google Drive **읽기 전용** 연결을 만든다.
계정 인증까지 대신하거나 Work의 연결 토큰을 휴대폰으로 복사하지 않는다.
Termux 저장소 권한도 처음 한 번 Android에서 허용해야 한다.

아래 `PRIVATE_INLINE_PLAN`은 사용자에게 별도로 제공하는 정확한 기존 팩의
비공개 metadata 인수다. 실제 명령에는 값까지 들어 있으므로 설치 파일이나
JSON을 따로 다운로드하거나 선택하지 않는다. 이 문서에는 사용자 원본의
비공개 ID·파일 목록·개인 경로를 싣지 않는다.

```bash
pkg install -y curl && twilight_entry="$(mktemp)" && curl --proto '=https' --proto-redir '=https' -fL --retry 2 -o "$twilight_entry" "https://raw.githubusercontent.com/zoog136-hash/-/feature/android-private-source-bootstrap-20261105/tools/android/install_private_sources.sh" && bash "$twilight_entry" --plan-inline 'PRIVATE_INLINE_PLAN'
```

동일 명령은 최신 **main**의 코드를 설치한다. 설치기 자체는 feature 브랜치의
불변 SHA를 먼저 확인해 세 파일을 같은 SHA에서 받는다. 미병합 다른 기능 PR을
자동 병합하지 않는다. main에 설치기 병합 후에는
`TWILIGHT_INSTALLER_REF=main`을 사용할 수 있다.
inline 인계는 명령에 포함된 원본 버전 목록이다. 이 명령을 다시 실행하면
최신 main 코드와 해당 원본을 동기화한다. 이후 새로운 원본 팩 ID가 공급되면
inline 인수를 갱신해야 한다. 같은 짧은 명령으로 원본 목록의 향후 변경까지
따르려면 별도로 승인된 비공개 Drive 인계 ID를 `--plan-id`로 사용한다.

완료 후 Godot Android Editor에서 `Download/TWILIGHT_Play/project.godot`을
처음 한 번 가져온다. 각 맵·타일·이미지 폴더와 해시를 사용자가 고르는 과정은
startup bridge가 처리한다. 이것은 APK 생성/설치 또는 Android 앱 자체 업데이트가 아니다.
설치/업데이트 중에는 Godot를 종료해야 한다.

## 다운로드 단위와 재개

- GitHub 코드는 shallow partial clone과 sparse checkout의 **Git object pack**으로
  일괄 전송한다. 수만 개 raw 파일 URL을 순회하지 않는다. 트리 조회에 `--long`을
  사용하지 않아 누락 blob 크기 조회가 파일별 lazy fetch를 유발하지 않게 한다.
  문서·조사·테스트 출력은 sparse scope에서 제외하고 기존 게임 실행 파일만 받는다.
- Drive 원본은 공식 묶음만 받는다. 전체 맵은 17조각을 순서대로 합쳐 전체 SHA를
  확인한다. 이미지 18개는 각각 독립 ZIP이므로 이어붙이지 않고 같은 새 이미지
  루트에 푼다. dummy 선언 보충팩은 원본 manifest를 바꾸지 않고 추가한다.
- 묶음 동시 수는 기본 2개, 범위 1~3개다. 무제한 스트림·다른 계정·제한 우회는 없다.
  인증/권한/용량 제한은 중단 사유다. 실제 속도 개선은 측정하지 않았다.
- 완료된 묶음은 크기/SHA256을 다시 확인해 재사용한다. rclone 방식은 이미 받은
  조각은 재사용하고 진행 중이던 조각 하나는 다시 받는다. rclone copyid의 바이트
  이어받기를 보장하지 않는다.
- 별도 `--token-file`로 명시한 로컬 OAuth access token을 사용하는 경우에만 정확한
  HTTP206/Content-Range 응답을 확인해 바이트 이어받기를 한다. 서버가 Range를
  무시하면 그 묶음만 처음부터 받는다. 인증정보는 로그·캐시·공개 저장소에 넣지 않는다.
  일반 사용자는 rclone의 정상 인증/갱신을 사용하면 된다.

공식 동작 근거: [Drive 다운로드와 Range](https://developers.google.com/workspace/drive/api/guides/manage-downloads),
[rclone copyid의 로컬 목적지](https://rclone.org/drive/#copyid),
[Git partial clone](https://git-scm.com/docs/partial-clone).

## 배치와 보존

프로젝트는 `Download/TWILIGHT_Play`, 확장된 새 리소스는 같은 Download의
`.TWILIGHT_Play.resources/<팩 구성 해시>/`에 둔다. 자격증명 없는 다운로드
캐시는 Termux HOME의 `.cache/twilight-private-install`에 둔다. ZIP 원본과
검증된 조각은 재사용을 위해 보존한다. Drive 파일/폴더/권한은 변경하지 않는다.

새 코드는 형제 staging 폴더에 준비하고 Git blob SHA로 확인한다. ZIP은
크기/SHA·CRC를 확인하고 traversal, 링크, 특수 파일, 중복/충돌 경로를 거부한다.
일반 업데이트는 모두 준비된 후 기존 폴더를 이전 버전으로 rename하고 새 폴더를
같은 이름으로 rename한다. 두 rename 사이의 짧은 간격은 존재하므로 전체를
단일 원자적 연산이라고 주장하지 않는다. journal로 다음 실행에서 이전 실행본을
복원하거나 새 실행본의 전체 관리 파일을 재확인하고 완료한다.

성공한 전환 뒤에는 이전 영수증의 경로·크기·SHA가 모두 일치하는 관리 파일만
자동 삭제한다. 관리 폴더도 기록된 빈 폴더만 제거한다. 비관리 파일·빈 사용자
폴더·변경된 관리 파일·기존 Godot 설정/cache는 보존한다. 새 코드와 사용자
수정이 충돌하면 덮지 않고 중단한다. 이 설치기의 소유 기록이 없는 기존 프로젝트는
자동 인수하지 않는다. 이전 비관리 자료가 남으면 이전 폴더를 보존하고 위치를 알린다.
세이브는 기존 Godot `user://` 그대로이며 설치기는 저장 형식을 바꾸지 않는다.

## Godot 연결 계약

설치기는 로컬 `project.godot`에 첫 autoload를 추가하고
`res://twilight_private_install.json`을 만든다. 공개 main의 `project.godot`이나
다른 담당 코드에 설치용 경로를 커밋하지 않는다. Termux 환경 변수는 다른 Android
앱에 전달되지 않으므로 bridge가 Godot 안에서 다음 경로를 준비한다.

| 입력 | 기존 소비 계약 |
| --- | --- |
| 맵 source523/tiles523 + 양쪽 manifest SHA | `user://current523_aden_play.cfg` `[play]` raw_root/tile_root/source_manifest_sha256/tile_manifest_sha256/native_land_id |
| 원본 포탈·입장 정의 world-links | `user://current523_source_definitions.cfg` `[definitions]` directory/manifest_sha256/enabled |
| 맵 전용989 SP2 + 전역30 SPR 선언 | `user://current523_map_static_spr.cfg` `[display]` source_root/declaration_path/enabled |
| 공통523 원문 ZIP | `TWILIGHT_PATCH523_CONTENT`, growth/death/title/relic의 기존 `user://` 원본 ZIP 위치 |
| 새 이미지 manifest + dummy 보충 원문 | `TWILIGHT_SOURCE523_IMAGES`, `TWILIGHT_SOURCE523_IMAGES_SHA256` |
| 별도로 공급된 메인 HUD 원본 부분팩 | `TWILIGHT_SOURCE_UI`, `TWILIGHT_SOURCE_UI_SHA256`; root/original_ui.json |
| 원본 월드맵 관계와 명시적 offer | 없을 때만 `user://current523_world_map.cfg` `[world_map]` 준비; 기존 파일 보존 |
| 실제 UI 부분팩과 selection JSON이 모두 있을 때 | `TWILIGHT_SOURCE523_UI_ICONS`, `TWILIGHT_SOURCE523_UI_ICONS_SHA256` |
| 새 Sprite 은행이 실제 공급됐을 때 | `user://current523_source_bank.json` schema1의 tables_zip/manifest_path/manifest_sha256/overlay_whitelist_* |

공통523은 `index.json`과 `content/<Table>.json`을 담은 정의 ZIP이다.
`TWILIGHT_PATCH523_CONTENT`에는 압축을 푼 폴더가 아니라 ZIP 파일 경로를 전달한다.
PR269의 공개 `007910fa85967a6e50dd8ea7d6e17a7f11c8c857` 이후 현재 원문
reader·DTO·drop/craft 등록·schema4 catalog 소비 코드가 실제 설치 대상에 있으면
이 ZIP을 새 설치의 정식 아이템 입력으로 사용한다. 기존 table 바인딩과 첫 autoload의
환경 변수·동일 ZIP 경로 준비를 재사용한다. 설치 중 파생 모델·BIN을 만들지 않는다.
schema4는 실제 원문 출처와 projection을 보존하며 예전 BIN의 식별자나 수량을 만들지 않는다.
원문 바이트 준비와 설치 대상 코드 조건은 별도 evidence로 기록한다. 이것이 실제
catalog 등록·아이템 효과·세이브 전환을 검증하지는 않는다.

이전 `--patch523-drop-root`의 monster_drops.bin과136개 items/NNNN.bin은
이 새 소비 경로의 필수 최종 입력이 아니다. 역사적 BIN·조각·설정·세이브는 보존하고,
이전 reader의 참조 경로를 현재 원문 ZIP으로 위장하지 않는다. 호환 코드가 아직 없으면
그 코드 통합을 대기로 기록하며 구 카드·몬스터 그래픽 팩을 의존성으로 추가하지 않는다.
제작 규칙·퀘스트 payload·스킬v3의 기존 명시 입력도 그대로 둔다. 제작 전용
`TWILIGHT_PATCH523_CRAFT_CATALOG_BIN`을 전체 reader의 선택으로 확대하지 않는다.

원본 manifest·선택 JSON은 재작성하지 않는다. 초기 Land4는 공식 인계의 자체
시작 프로필 선택이며, 카탈로그의 실제 비제외 Land임을 확인해야 한다. 좌표를
만들지 않고 기존 runtime의 입장 판정에 맡긴다. 같은 맵 pin에서는 나중에 사용자가
바꾼 활성 여부·지역·navigation profile·커서를 유지한다. 설정 변경 전 이전 바이트를
고유 백업에 보관한다. 메인 HUD는 `main_ui` binding의 원본 팩 root와 manifest
pin만 전달하고 기존 지연 선택·binding consumer에 맡긴다. 이 입력은 PR270의
`ui_icons` 선택과 다르다. manifest는 기존 loader와 같은128MiB 제한 및 schema,
scenes/files/atlases/blockers 계약을 확인한다. UI267의 화면 mount나 binding
factory는 추정하지 않는다. 메인 HUD 부분팩의 전체 parent metadata가 다른 노드
활성화나 전체560UI 완료를 뜻하지 않는다.

정식 Combined v6 인계가 공급되면 새 설치·명시적 설치기 업데이트의 기본 UI 입력은
그 단일 결합 팩이다. 같은 선택기로 HUD·월드맵·normal4/expanded8·퀵슬롯·장착/잠금
표시를 기존 owner들이 소비한다. 설치기는 후보 manifest를 합치거나 UI를 새로 만들지
않는다. 원문 selection_contract의 schema/mode/v5 확장 pin과 보존 필드 존재를
확인하되 retained_base_files/retained_base_node_scopes의 내부 형태는 추측하거나
다시 쓰지 않는다. 정확한 내용은 공식 원문 manifest pin으로 보존한다.

기존 `--source-ui` pair나 `TWILIGHT_SOURCE_UI` pair가 있으면 기본값으로 덮지
않으며, 한쪽만 명시된 불완전한 pair도 다른 기본값으로 완성하지 않는다. 다른
명시 선택을 유지할 때에는 그 선택과 맞지 않는 새 월드맵 cfg도 만들지 않는다.
이전 v5와 후보·아이콘의 원본 경로는 리소스 버전 정리에서도 보존한다.
공식 v6의37원본/20장면/19부분범위는 공급 입력 범위이며 전체560UI 완료 수치가 아니다.
동시 소비·원본 장착/잠금·native touch의 실제 설치 코드 선행 조건도 별도로
확인하며, 이미지와 실시간 상태의 준비·표시 전환은 기존 원자적 component 소비자에 맡긴다.

UI267의 후속 공개 체크포인트
`8486e6f59358d0066baad2163ff428cda6ed6d31`도 같은 v6 ZIP과 manifest pin을
사용한다. CSB 아이콘의 부착·해제·동일 장면 재사용은 기존 UI/image owner의
`bind_original_icon_scene_provider`, `source_asset_scene.prepare`,
`sprite_scene.set_bound_source_visual_result` 및
`reuse_bound_source_scene_from` 계약에 맡긴다. 설치기는 별도 provider를 등록하거나
새 장면 부착기를 만들지 않는다. 이 코드의 존재 여부는 아이콘 선택 metadata에
별도로 기록하며 정적 HUD/월드맵의 활성 조건에 섞지 않는다.
두 원본 CSB 부분팩이 내려받아졌다는 사실만으로 아이콘별 원본 등록 위치·근거나
재생 정책이 공급됐다고 보지 않는다. 명시된 원본 재생 선언이 없으면 seek/play/loop를
추가하지 않는 기존 소비자 정책을 유지하며, 추정한1회 재생을 원본 선언으로 바꾸지 않는다.
같은 장면 인스턴스의 실제 상태 보존과 동시 게임 표시는 미실행이다.

월드맵의 등록·문맥·입력·이동은 기존 map owner의
`configure_from_settings(world)`가 처리한다. 설치기는 등록기를 만들거나 호출하지
않고 기존 cfg의7개 키만 준비한다: enabled, contract_path, contract_sha256,
offered_worlds, coordinate_policy, ratio_scale, source_anchor_offset.
기존 cfg는 유효성·활성 상태와 관계없이 읽거나 덮어쓰지 않는다. 새 설치용 활성
선택이 명시돼 있고 실제 설치 코드·원본 조건이 모두 갖춰지면 enabled=true로 만든다.
코드가 없거나 입력이 부족하면 cfg 자체를 만들지 않는다. 비활성 placeholder가
이후 자동 활성화를 막지 않도록 하며, 나중에 같은 명령으로 호환 코드를 받았을 때
기존 cfg가 없으면 이 조건을 다시 적용한다. 명시적 활성 선택이 없는 경우에도
cfg 생성을 보류한다. 기존 false/true 설정은 설치기가 만든 과거 파일이라도 보존한다.
offered_worlds는 10진 문자열 Land ID와 명시적 UIMapWorld.ID를 그대로 전달한다.
선택적 label은 실제 원문 World.Name만 사용하고, 생략하면 기존 소비자가 읽는다.
Land를 World로 대신하거나 첫 후보를 자동 선택하지 않는다.

`OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1`, ratio_scale=1.0,
source_anchor_offset=[0.5,0.5]는 전달된 TWILIGHT 자체 정책이다. 원작 M의
공식 좌표 공식으로 표시하지 않는다. 기존 소비자가 원본 UI의 실제 선택 후에만
이미지를 표시하고, 필드·관계·세션·입력 판정을 수행한다. UI v5, 이미지18ZIP,
관계 JSON과 cfg는 별도 입력이다. 경로 준비가 실제 표시·보행 성공을 뜻하지 않는다.

코드 준비 여부는 실제 설치 대상 Git stage에서 기존 owner의 startup·등록·입력·
보행·Object 필드 경계·이미지 선택 API를 읽어 판정한다. PR 번호나 모듈 파일명만으로
통합됐다고 가정하지 않는다. 이는 정적 계약 확인이며 Godot 실행 검증이 아니다.
공급된 v5 맵 노드 scope, 모든 UI 원본, 이미지 manifest·dummy 선언과 명시 World의
실제 PNG 입력도 확인한다. 시작 시 확인했던 코드·입력 SHA를 다시 대조한다.
Android에서 원본 행 버튼을 실제 선택할 경로도 필요하다. 설치기는 touch emulation을
변경하지 않으며, native touch가 없는 mouse-only 코드와 emulation=false 조합은
자동 활성화 조건을 충족하지 않는다. 다른 그림이나 새 입력기로 대체하지 않는다.

새 cfg의 관계 경로는 공유 저장소의
`.TWILIGHT_Play.resources/pinned-contracts/<원문 SHA>/`에 고정한다. 이 원본은
이전 실행 리소스 정리와 분리해 보존한다. 기존 사용자 cfg가 과거 버전 경로를
참조할 수도 있으므로 과거 버전의 같은 관계 원문·출처도 정리에서 보존한다.
기존 cfg를 새 경로로 고쳐 쓰거나, 관계 JSON을 재작성해 pin을 바꾸지 않는다.

## 비공개 인계 schema1

설치기는 `--plan-inline`을 사용한 같은 명령 안의 비공개 인계, `--plan` 로컬
인계, `--plan-id` 인증된 Drive 인계를 받는다. inline은 compact UTF-8 JSON을
zlib/URL-safe base64로 보관하며 최대2MiB까지만 복원하고 추가 stream·trailing
data를 거부한다. 토큰과 원본 자산은 포함하지 않는다. 이 입력은 Drive 업로드가
아니며, 해당 명령을 외부에 게시하면 metadata가 노출되므로 사용자에게만 전달한다.
팩 ID·SHA·경로가 없는 항목은 만들거나 다른 팩으로 대체하지 않는다.
`--plan-sha256`은 특정 인계 버전을 고정할 때만 사용한다. 생략하면 같은 Drive
인계 ID의 정상 owner 업데이트를 따르므로 이후에도 같은 명령을 재사용할 수 있다.

인계의 `packs`는 공급된 것만 순서대로 나열하며, 각 항목은 id/format/files/
install_root를 갖는다. format은 `joined-zip`, `zip`, `file`이다. files는 각각
공식 file_id/name/bytes/sha256을 갖고 joined-zip은 order와 전체 bytes/sha256도
필요하다. depends_on은 이미 설치한 새 팩만 참조한다. `bindings`는
maps/map_definitions/map_static_spr/tables/images/main_ui/world_map/ui_icons/source_bank의 공식 상대 경로와 pin만 사용한다.
include_prefixes는 `/`로 끝나면 폴더 하위 전체, 그 외는 정확한 ZIP member만
추출한다. PR230 전달 ZIP에서는 world-links만 설치해 동봉된 구형 monsters는
의존성에 넣지 않는다. SP2/SPR도 소비자에 필요한 원문과 metadata만 추출한다.
`pending_packs`는 내려받거나 활성화하지 않는다. 미확정은 blockers에 남긴다.

확인된 현 인계는 전체 맵·포탈/입장 정의·맵989 SP2·30 SPR 선언·공통523·이미지18ZIP·dummy 보충팩까지다. UI 아이콘
선택 metadata만으로 실제 두 CSB 부분팩이 존재한다고 간주하지 않는다. 설치기는
두 원본 부분팩의 실제 Drive ID·크기·SHA와 manifest pin이 인계에 모두 있을 때만
선택 설정을 활성화한다. PR272 은행의 공식 비공개 전달 목록이 공급되면 그 목록의
기존 ZIP·전송 조각·델타 순서를 사용한다. 목록·은행 경로·내용·pin은 공개 저장소에
넣지 않는다. 실제 ZIP 접두사는 추측하지 않고 선언된 manifest pin에 맞는 유일한
추출 파일을 찾는다. 기존 로더가 그 파일의 부모를 은행 루트로 사용한다.

은행은 새 비공개 staging에만 조립한다. 기반·중간·최종 checkpoint마다 pinned
manifest와 원문이 선언한 domain metadata를 확인한다. 델타에서 원자 교체할 수 있는
것은 이전 checkpoint의 소유가 확인된 manifest·선언된 domain metadata·같은 pin의
정식 설정 template뿐이다. 원본 raw/actor 파일의 충돌은 거부하고, 원본 ZIP·receipt·
제외 선언은 보존한다. 추출된 과거 은행도 기존 설정에서 계속 선택할 수 있도록 보존한다.
별도 공급된 보존·후속 구성 입력은 비활성 자료로 유지하며 전달만으로 등록하지 않는다.

기존 Sprite cfg나 CLI 선택은 읽거나 고쳐 쓰지 않는다. 새 설치에서는 기존 schema1,
source_snapshot, tables_zip, manifest_path, manifest_sha256 계약을 사용한다.
정식 template·최종 은행 입력·실제 설치된 owner 코드와 명시 활성 선택이 모두
준비됐을 때에만 새 cfg를 만든다. 준비가 부족하면 cfg를 만들지 않아 이후 호환
업데이트가 이어갈 수 있게 한다. 전달 완료·복원 준비·코드 통합·실제 배우 admission과
게임 표시는 별도 상태이며, 이 설치 작업은 후자의 실행을 하지 않는다.
별도 인벤토리 원본 후보는 기존 `main_ui` 선택과 교체 가능한 후보로만 기록한다.
현재 공개 계약은 같은 `TWILIGHT_SOURCE_UI`/`TWILIGHT_SOURCE_UI_SHA256` 또는
`--source-ui`/`--source-ui-sha256` 쌍을 사용하며 별도 인벤토리 선택기가 아니다.
따라서 후보가 v5와 사용자 선택을 자동 교체하거나 두 manifest를 합치지 않고,
정확한 후보 폴더·manifest·Drive 입력과 코드/노드 선행 조건을 pending으로 둔다.
normal4 인벤토리 후보를 확장8·PageView 퀵슬롯 후보의 입력으로 계산하지 않는다.
확장8·퀵슬롯 원본 후보도 별도 폴더·manifest·배포 신원으로 보존한다. 두 후보의
파일 수나 scope를 합산하지 않으며, 같은 주 선택기를 쓰는 동안 병렬 선택이나
자동 교체 계약을 만들지 않는다. 원본 가방/퀵슬롯의 실제 모델·페이지·아이템 상태와
외부 Slot_Skill 등 실제 이미지가 모두 준비돼야 하는 기존 owner 조건을 유지한다.
공개 체크포인트 이후 연결 중인 상태 표시·노드 계약이나 미게시 코드를 이미
설치 대상 main에 포함됐다고 가정하지 않는다. 정확한 후속 인계 전에는 후보를 채택하지 않는다.
전체 가방 모델·기존 물리 참조/PointerTransfer·실제 PR270 원본 아이콘을 요구하는
소비 조건을 유지하며, 일부 행으로 자르거나 샘플 그림으로 채우지 않는다.
미수신22,028개 요청 목록 ZIP은 원본 자산이 아니다. 전역 SPR 원문 ZIP도 PR272
새 은행으로 대체 사용하지 않는다. 기존 카드·몬스터 구팩은 설치 의존성에 없다.
별도 기능 PR의 미병합 상태는 입력 전달과 분리해 보고한다.
