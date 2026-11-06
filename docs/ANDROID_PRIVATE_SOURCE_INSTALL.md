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
  원본 전용 경로에서는 `assets/**`와 과거 `external_map_packs/**`를 확장자만으로
  선택하지 않는다. 코드·장면·데이터 metadata를 먼저 선택하고 소스의 정확한 참조를
  읽어 엔진 폰트·shader 의존성을 추가한다. 자체 제작 이미지·음향·staging 팩을
  data catalog에서 자동 확장하지 않는다. 현재 코드가 폐기 대상 그림을 필수
  preload하는 경우에는 해당 호출을 표시하고 중단한다. 파일만 빼서 파싱 실패를
  숨기거나 옛 그림을 다시 받지 않으며, 해당 소비 코드의 정리가 필요하다.
  이는 정적 선택 경계이며 모든 동적 참조의 완전성이나 실행 성공을 뜻하지 않는다.
  작은 Git 경로는 `github-runtime-minimal-v1`과 별도 소유 영수증을 사용한다.
  이전 실패한 `github-runtime`은 자동 삭제·reset·prune하지 않는다. 이전 버전에는
  전용 소유 영수증이 없으므로 원격 origin 일치만으로 삭제 소유권을 추정하지 않는다.
  선택한 새 프로젝트 폴더가 없으면 빈 폴더를 만들고, 성공 영수증은 게시 후에만
  기록한다. Git 전송 전에 아직 받지 않은 압축 원본의 최소 필요 공간을 확인한다.
  완료된 묶음은 크기/SHA가 맞을 때만 이 계산에서 제외한다. 이 수치는 해제·코드
  체크아웃·staging·보존 중인 이전 버전의 추가 공간을 포함하지 않으며, 전체 설치
  공간이 충분하다는 보장은 아니다. 부족하면 자동 정리 없이 중단한다.
  data 아래의 조사 보고서·중간 모델도 일괄 선택하지 않는다. 코드의 정확한
  리소스 경로와 명시된 제한된 data namespace에 속한 metadata만 추가한다.
  동적 경로 전체의 완전성을 실행 검증한 것으로 표시하지 않는다.
- Drive 원본은 공식 묶음만 받는다. 전체 맵은 17조각을 순서대로 합쳐 전체 SHA를
  확인한다. 아직 합친 ZIP이 없다면 검증된 전송 조각을 seek 가능한 ZIP 뷰로 읽어
  별도 합본 파일을 만들지 않는다. 조각의 순서·크기와 합본 전체 SHA는 그대로
  확인하며 원본 조각을 보존한다. 이전에 검증한 합본이 있으면 그대로 재사용한다.
  이미지 18개는 각각 독립 ZIP이므로 이어붙이지 않고 같은 새 이미지
  루트에 푼다. dummy 선언 보충팩은 원본 manifest를 바꾸지 않고 추가한다.
- 묶음 동시 수는 기본 2개, 범위 1~3개다. 무제한 스트림·다른 계정·제한 우회는 없다.
  인증/권한/용량 제한은 중단 사유다. 실제 속도 개선은 측정하지 않았다.
- 완료된 묶음은 크기/SHA256을 다시 확인해 재사용한다. rclone 방식은 이미 받은
  조각은 재사용하고 진행 중이던 미완료 묶음만 다시 받는다. rclone copyid의 바이트
  이어받기를 보장하지 않는다.
- 병렬 전송 오류는 마지막 진행 로그 대신 실제 실패 future의 SHA prefix·안전한
  파일명·크기·동시 수로 식별한다. rclone은 매 명령 1회만 호출하며 실패 시 자동으로
  다른 계정·다른 경로·직렬 전송으로 바꾸지 않는다. 로컬 `help flags`로 지원을
  확인한 경우 각 명령의 오류를 새 0600 임시 로그에 격리하고, 제한된 마지막 부분을
  오류 범주로만 변환한 뒤 해당 임시 로그를 닫아 제거한다. 기존 로그·cache는
  읽거나 지우지 않는다. 반환 코드·스트림/로그 길이·지원 flag·로깅 환경 변수의
  이름만 표시하며 환경값·오류 원문·인증정보는 표시하지 않는다. stdin은 닫고
  TTY를 사용하지 않는다. stdout/stderr가 비었다는 사실만으로 인증·쿼터 실패를
  추정하지 않으며, 격리된 로그도 비어 있으면 원인 미확정으로 남긴다.
  격리 캡처 수준은 `NOTICE`다. 현재 공식 rclone은 backend가 반환한 최종 오류도
  `fs.Logf`(NOTICE)로 기록하므로 `ERROR` 필터만 쓰면 오류 원인까지 숨길 수 있다.
  이를 보완해도 실제 전송 오류가 해결됐다는 뜻은 아니다. 원문은 계속 비공개로
  분류하고, 원래 returncode와 실패 조각을 그대로 보고한다. `copyid remote: ID
  <로컬 파일>` 계약·계정·원본 ID·목적지·동시 수·재시도 횟수는 바꾸지 않는다.
  별도 `--diagnose-bundle=<전체 SHA256>`은 반드시 이미 보유한 `--plan`과 정확한
  `--plan-sha256`을 요구한다. 같은 `--project`에서 기존 캐시 경로를 계산하여
  그 plan의 정확한 한 ID에 `copyid --dry-run`을 1회 수행한다. 메타데이터와 로컬
  목적지 초기화만 확인하며 Git checkout·미디어 수신·marker 작성·설치·정리는
  수행하지 않는다. 이 모드의 shell 진입점은 package 설치·저장소 권한 요청·새
  rclone 인증 설정을 시작하지 않는다. 성공은 media 수신 검증이 아니며, 실패는
  기존 정제된 범주로만 보고하고 자동 재시도하지 않는다.
  새 오류에서 공식 reason 형식이 관측됐을 때만 고정 허용 목록의 코드를 출력한다:
  `downloadQuotaExceeded`, `rateLimitExceeded`, `userRateLimitExceeded`,
  `dailyLimitExceeded`, `storageQuotaExceeded`, `quotaExceeded`. 일반 quota 문구나
  HTTP403만으로 구체 reason을 추정하지 않는다. 다운로드 제한은 해제 시각을
  단정하지 않고 대기한다. 요청 속도 제한은 실제 Retry-After가 있으면 준수하고,
  이후 재개 전에 지수 backoff를 적용해야 한다. 일일 프로젝트 제한이나 Drive
  저장 한도는 각각 구분하며 폰 용량 부족으로 해석하거나 사용자 파일을 지우지 않는다.
  Retry-After는 캡처에 문자열이 관측됐는지만 보고한다. 정상 NOTICE 오류는 HTTP
  헤더를 생략할 수 있으므로 `not_observed`는 헤더 부재 증거가 아니다. 원문·헤더
  dump를 켜지 않고 과거 로그를 읽지 않으며 제한 해제 시간을 만들어내지 않는다.
  실패가 확인되면 새 묶음 예약을 중단한다. 이미 진행 중인 다른 작업은 끝날 수
  있고 완료 캐시는 보존된다. 이후 사용자가 대기 후 같은 명령으로 재개할 때만
  미완료 묶음을 다시 시도하며, 설치기는 자체적인 반복 다운로드를 시작하지 않는다.
  일반 실패 후속 안내도 분류된 quota에는 즉시 재실행을 권하지 않는다. provider
  제한 대기·실제 Retry-After/backoff 준수·같은 캐시의 추후 재개를 안내한다.
  접근 거절이나 미분류 HTTP403은 quota라고 단정하지 않고 제한 원인 확인 전
  반복·인증 초기화를 권하지 않는다. 이 메시지 분기는 다운로드 동작을 바꾸지 않는다.
  공식 googleapi 오류가 `Details` 여러 줄 JSON 뒤에 단일 reason을 별도 줄로
  붙이는 형식도 검사한다. 그래도 `ErrorItem.Reason`이 없거나 HTML/일반 body만
  전달됐다면 구체 코드를 복원할 수 없다. `not_observed`는 reason 미관측이며
  quota 부재·특정 다운로드 제한·해제 시각의 증거가 아니다. 이 형식 보완은
  provider 제한을 해제하거나 기존 실패 원인을 소급 확정하는 수정이 아니다.
- 별도 `--token-file`로 명시한 로컬 OAuth access token을 사용하는 경우에만 정확한
  HTTP206/Content-Range 응답을 확인해 바이트 이어받기를 한다. 서버가 Range를
  무시하면 그 묶음만 처음부터 받는다. 인증정보는 로그·캐시·공개 저장소에 넣지 않는다.
  일반 사용자는 rclone의 정상 인증/갱신을 사용하면 된다.

공식 동작 근거: [Drive 다운로드와 Range](https://developers.google.com/workspace/drive/api/guides/manage-downloads),
[rclone copyid의 로컬 목적지](https://rclone.org/drive/#copyid),
[Git partial clone](https://git-scm.com/docs/partial-clone).

## 이미 압축해제한 수동 배포 연결

`--manual-resources`는 `TWILIGHT_Play_Source523_Manual/source523_resources`에
풀어 놓은 정식 구성요소를 그 자리에 두고 최소 GitHub main 코드만 추가한다.
일반 설치기의 비관리 폴더 거부 규칙은 그대로다. 이 모드는 정확한 새 루트 이름,
명시한 `--manual-bootstrap-sha256`, 비공개 bootstrap index의 schema/완성 상태,
고정 plan SHA, 실제 구성요소별 ZIP 이름·bytes·SHA와 전체 해제 수량을 검증한다.
받아 둔 ZIP은 기본적으로 프로젝트 상위 Download 폴더에 그대로 보관한다.
다른 보관 위치는 명시적인 `--manual-archives`로만 지정하며 주변 파일을 검색하지 않는다.

압축파일은 SHA를 확인하고 central directory만 읽는다. 실제 해제 파일은 경로·
종류·크기·CRC를 해당 인증된 ZIP과 대조한다. ZIP을 다시 해제하거나 원본 8GB를
새 코드 staging에 복사하지 않는다. 경로 중복·symlink·보호 경로·미해제/변경 파일은
중단 사유다. 이후 기존 manifest/CSB/원문 SHA와 실제 main의 필수 소비 경계도
확인한다. 원문 manifest나 icon 선택 JSON은 재작성하지 않는다.

수동 모드의 shell은 rclone 설치/존재 검사/listremotes/인증 설정을 하지 않는다.
Drive plan·리소스 수신도 없고 패키지 설치나 저장소 권한 흐름을 시작하지 않는다.
필요한 python3/git/curl이 없으면 중단한다. 네트워크는 고정된 GitHub helper와
기존 packed-code의 최소 sparse/blob 전송에만 사용한다. 비공개 plan/index/원문
리소스 bytes와 배포 Drive ID 목록은 공개 저장소가 아니라 비공개 Bootstrap ZIP에 둔다.

새 root에는 검증된 source523_resources만 있을 때 최초 코드 채택이 가능하다.
업데이트는 별도의 `.twilight_manual_code_state.json`이 소유한 변경되지 않은 코드만
교체한다. 개인/수정 파일 충돌은 보존하고 중단한다. 코드만 staging/이전 사본에
두는 journal로 중단 복구하며 리소스 디렉터리는 이동·교체·정리하지 않는다.
공통 twilight_private_install.json은 이 코드 경로가 한 번 작성하고, 모든 원본
경로는 프로젝트 기준 상대경로로 저장한다. 기존 bridge의 pins·owner·기존 명시
선택/cfg 보존은 유지하며 수동 모드에서는 과거 고정 경로용 tables ZIP 사본도 만들지 않는다.

배포 구성요소가 모두 갖춰지고 연결 코드가 게시되기 전에는 사용자 실행 명령을
완성으로 제공하지 않는다. 이 구현은 설치/게임/Android 실행·컴파일·렌더·CI를
검증했다는 뜻이 아니다. 새 배포 포장도 provider 다운로드 제한 해제를 보장하지 않는다.

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

공식 v8은 기존 단일 선택 계약으로 v7/v6 입력과 원본 AutoMessage Text124를
함께 공급한다. 새 설치 목록은 이 결합 root와 정확한 ZIP/manifest pin을 사용할 수
있으며 이전 팩이나 사용자의 명시 선택을 대체하지 않는다. v8의38원본/21장면/
20부분범위도 전체560 완료를 뜻하지 않는다. 원문 parent-retention metadata는
변경하지 않는다. v8의 실제 extends_manifest_sha256 값은 공개 인계에 없으므로
이전 버전 pin을 추측해 채우지 않고, 공급된 manifest 전체 pin으로 원문을 보존한다.
정확한 확장 선언이 별도로 공급된 버전만 expected_composition으로 추가 비교한다.

인계의 main_ui.code_components는 해당 팩이 요구하는 기존 owner 코드 조건을
기록한다. v8은 default_primary_stats/native_main_buttons/auto_message를 요구한다.
기존 v6 조건에 실제 MD/AC 정수 상태·원본 버튼 touch·전용 auto_enabled bool과
Text124 소비 경계를 더하며, 새 renderer·일반 메시지·타이머·clip 재생 정책을 만들지
않는다. 명시 선택 보존과 실제 설치 코드의 정적 조건은 유지한다. 이 추가 입력도
알려지지 않은 CSB-root 등록 관계나 실제 표시·애니메이션 실행을 입증하지 않는다.

공식 v14도 같은 단일 선택 계약으로 공급된다.53원본/33장면/32부분범위가
그 팩 안에 있으며 이전 버전을 설치 의존성으로 추가하지 않는다. 이전 원본과 명시
선택·cfg·세이브는 보존한다. v14의 실제 extends 값도 추정하지 않고 정확한 manifest
전체 pin으로 원문 metadata를 보존한다. 새 payload와 기존에 반영된 v8 설치 목록은
서로 다른 승인 대상이며, 이전 파일 교체 승인을 새 payload로 확대하지 않는다.

main_ui.feature_code_requirements는 추가 UI owner의 공개 scripts/*.gd 함수·문자열
경계를 제한된 데이터 목록으로 전달한다. 설치기는 그 코드를 실행하거나 표현식을
평가하지 않고 실제 stage의 파일 SHA와 API 존재 근거만 기록한다. 이 근거는 기존
main/world 활성 조건에 합치지 않는다. 캐릭터·대화·시스템 메시지·이름 헤더와
선택적 NPC 초상화의 코드 준비 여부 및 실제 입력·표시는 별도 상태로 남긴다.

NPC 초상화는 기존 bind_original_npc_dialogue_portrait의 실제 context/image 콜백을
요구한다. 설치기는 L1J 대화 ID·이름·Sprite·DescID에서 모바일 NpcClass.ID를 만들거나
콜백을 등록하지 않는다. 실제 관계와 원본 static Texture2D/provenance를 owner들이
공급해야 하며, 미공급은 초상화만 보류한다. 텍스트·닫기·허용된 단일 다음 선택은
기존 소비자 정책을 따른다. CSB-root 등록·AnimatedTexture·새 반복 정책·편집기 샘플
대체 그림은 추가하지 않는다. 입력 전달과 실제 설치·게임 사용을 같은 완료로 세지 않는다.

공식 v15는 v14 전체와 원본 미니맵 Text13992 범위를 같은 단일 팩에 공급하며
53원본/33장면/32부분범위 수는 유지한다. 새 cfg나 이전 버전 설치를 요구하지 않는다.
미니맵 label 코드는 기존 World가 이미 만든 정확한 안전 지역 접미사만 Text13992로
분리한다. Normal/PvP enum이나 원작 지역 규칙을 추정하지 않는다. 활성 팩에13992가
없거나 선택적 부착·갱신이 실패하면 기존 owner의 전체 이름을 그대로 표시한다.
해당 producer/receiver API는 독립 코드 근거로 기록하고 맵 지형·이미지·클릭·이동·
세이브 계약에는 추가 조건을 만들지 않는다. 성공한 v14 목록과 새 v15 payload는
별도 버전으로 보존하고 새 파일 교체 승인은 그 실제 payload를 대상으로 받는다.

공식 v17도 단일 결합 root/pin을 사용한다. v16 강화 버튼 입력과 원본 인벤토리
검색을 함께 공급하며56원본/36장면/35부분범위가 이전 팩 설치를 요구하지 않는다.
검색은 기존 bag.search_line과 query/filter를 재사용한다. 원본 입력 제한을 넘는
기존 query는 자르거나 초기화하지 않으며, 원래 parent·설정·focus·선택 상태를
돌려주는 코드 경계를 독립 근거로 기록한다. 추가 키보드 설정이나 입력창을 만들지
않는다. 검색 결과 행·clear·정렬 동작을 추정하지 않으며 지원하지 않는 행은 기존
완전한 가방 UI에 맡긴다. 실제 IME·touch·문자 표시 동작은 실행 검증하지 않는다.

진행 중 UI/Sprite 계약은 로컬 누적 초안에만 반영한다. 중간 버전마다 파일 교체
승인을 요청하지 않고, 최종 공식 UI·Sprite 입력을 통합할 때 정확한 최종 payload와
한 번의 기존 Drive 목록 교체 승인을 묶는다. 그 전에는 현재 hosted 목록을 유지한다.

UI 최종 전달 입력 v19는 v18 퀘스트 탭/닫기와 실제 선택 아이템의 원본 잠금 제어를
포함한 단일 팩이다.60원본/38장면/37부분범위는 전체560 또는 실기 완료 수치가 아니다.
잠금은 기존 boolean 상태·선택 참조·동일 버튼/disabled를 다시 확인하고 기존
_toggle_lock만 호출한다. 퀘스트도 기존 _select(category)와 workspace 닫기만 사용한다.
저장 성공·보상·다른 아이템 행동은 설치기가 추정하지 않는다. alpha0 제목 생략은
원본 alpha/timeline의 엄격한 근거가 있을 때만 허용하며 새 폰트나 불투명 제목을 만들지
않는 기존 renderer 계약을 기록한다. 공유 workspace 입력 경계는 이전 강화 전용
함수 대신 _route_workspace_source_actions를 사용한다.

UI owner의 최종 입력/병합 인계는 전체 설치 목록 확정과 별개다. Sprite 후속 입력과
통합 코드 준비가 남으면 누적 목록은 계속 보류하고, 중간 업로드·승인 요청을 하지 않는다.

PR269의 main 병합 `44eb4f581603610ec0644dcb6a0f7d86e5720572`와 PR278의
main 병합 `5db920332f9298b4fc1f70713dde11740c91a7d2`는 코드 통합 기록이다.
기존 은행 소비자 계약과 현재 원문 item reader 경계는 유지되지만, 병합만으로 최신
은행의 비공개 배포 ID·크기·ZIP SHA·manifest pin·실제 추출 경로가 생기지는 않는다.
PR279의 문서 한 개도 새 원본 수신·등록·호출 또는 새 배포 증거로 취급하지 않는다.

PR278 Core는 분리된 CI 환경의 정확한 원문 정의 ZIP 미공급으로 실패한 기록을
유지한다. 다른 검사나 병합을 Core 통과로 바꾸지 않는다. Termux 설치 목록에는
기존 공식 원문 ZIP을 한 번 수신해 첫 reader 전에 환경 경로로 공급하는 계약이 있다.
이는 승인된 private Actions 공급 경로가 있다는 뜻이 아니며, 설치기가 CI 자격증명을
만들거나 원본을 공개하거나 검증 조건을 낮추지 않는다. 고정 user 경로 복사는 이전
소비자 호환용이며 현재 reader는 공통 ZIP 하나를 사용한다.

기존 은행 cfg의 tables_zip이 이전 리소스 버전을 계속 가리킬 수 있으므로 원문 ZIP의
그 경로도 정리에서 보존한다. 새 receipt는 명시 table 경로를 보존 목록에 기록하고,
구 receipt에도 정확한 고정 원문 바이트/해시를 사용하는 ZIP 보존을 적용한다.
cfg를 새 경로로 고쳐 쓰지 않는다. source_bank.caller_code_requirements의 추가
근거는 병합된 피격·Death receiver·성공한 소비 이벤트·보류 지면 호출 경계만 기록한다.
최신 은행 공급·admission·저장 성공·실제 재생과 독립된 상태이며, 실행 검증은 하지 않는다.

공식 추가 델타는 pinned_delta의 별도 멤버 목록 pin과 함께 적용할 수 있다.
새 staging에 정확한 기반을 조립한 뒤 독립 ZIP 순서·모든 멤버 크기/SHA·metadata
교체 소유권·raw/actor 새 경로를 확인하고, 마지막 manifest만 최종 단계에서 반영한다.
기존 활성 은행이나 하드링크를 덮지 않는다. 설정 template 대신 공급된 원본 설정
계약 pin을 사용할 수 있으며, 실제 소비자의 MAX_JSON보다 큰 manifest는 cfg 활성
준비로 표시하지 않는다. 설치기 metadata 읽기 한도와 게임 로더 한도는 별개다.

v23의 새 소비 기능은 PR280 코드와 별도 호환 조건을 요구한다. 이전 scope 소비를
새 기능 전체 완료로 표시하지 않는다. 알려진 필수 소스 문제가 있는 후보는
mandatory_source_blockers로 다운로드·설치 전에 중단한다. 해당 조건이 해소된 공식
코드와 정확한 최종 목록을 확인한 뒤에만 한 번의 게시/목록 교체 대상으로 확정한다.

선택된 최신 계약은 원본 ZIP 다운로드 전에 실제 main의 세 manifest reader와
32MiB/16MiB 분리 한도, UI identity-before-validation 및 거절 시 원복 경계를 읽기로
대조한다. 공개 PR commit의 존재를 main 통합이나 실행 성공으로 대신하지 않는다.
설치기가 PR을 합치지 않으며 기존 실행본을 바꾸기 전에 미충족 계약으로 중단한다.
현재 승인 후보는 v23을 유지하며 선택적 v29로 자동 변경하지 않는다.

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

최종 승인 후보는 전달받은 단일 결합 UI 버전에 고정하며, 이후 공개된 더 큰 팩을
자동 추적하지 않는다. 누적 팩의 축복·던전·작업창 같은 추가 범위는 기존
`feature_code_requirements`의 제한된 owner 경계로 명시한다. 원본 컴포넌트의
실제 표시·현재 화면 소유자 검사 등 필요한 후속 코드도 실제 설치 코드에서
확인하며, 공개 PR에 있다는 이유로 main에 포함됐다고 취급하지 않는다.
같은 PR에 더 최신 팩용 선택 기능이 함께 들어있어도 그 팩을 자동 선택하지 않는다.
기존 UI 선택·설정·세이브와 이전 원본은 보존한다.

공식 v30 manifest pin과 배포된 과거 `character_stats`/`inventory_search` 요구
목록이 정확히 일치하면, 설치기는 현재 owner 리팩터링의 동등한 경계를 검사한다.
CharacterView는 `configure`에서 생성·등록하고 열기 함수는 그 인스턴스를 사용한다.
검색창은 inventory/crafting 설정에 따른 실제 editor와 project 경로를 확인하며,
원본 CSB/SHA·IME·현재 owner·편집기 반환 검사도 유지한다. 다른 버전이나 다른
요구 목록은 이 호환 처리를 적용하지 않는다. 사전 검사와 최종 descriptor는 같은
검사를 사용하고 적용한 호환 계약을 기록한다. 원본 설치 목록·pin·게임 코드는
변경하지 않으며, 이 정적 경계 확인은 설치·게임 실행 검증을 뜻하지 않는다.

게시 승인은 코드·대상 HEAD와 비공개 설치 목록의 정확한 바이트 크기·SHA를
함께 고정한 뒤 요청한다. `[skip ci]`는 `pull_request_target` 보조 workflow를
막지 않으며, main 병합의 push workflow도 별도 고려해야 한다. 보조 cleanup의
성공은 Core 검사 통과나 보호 규칙 충족의 증거가 아니다. 이 설치기는 보호
설정을 바꾸거나 PR을 자동 병합하지 않는다.
