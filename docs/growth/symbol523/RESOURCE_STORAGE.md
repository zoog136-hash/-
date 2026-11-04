# PR242 문양 데이터팩 보관·실제 설치

최신 문양 적용 데이터와 원본 표 백업을 별도 비공유 Drive 폴더에 보관했다. **이48,630B 팩은 문양 데이터 패치이며 전체 게임 리소스·맵·실행본이 아니다.** Drive에 보관된 파일이 게임에 자동 적용되지는 않는다.

| 구분 | 파일·버전 | 크기 | 실제 보관처 |
| --- | --- | ---: | --- |
| 최신 문양 적용팩 | `TWILIGHT_PR242_SYMBOL523_RUNTIME_DATA_g35_e9_history1_v20261104_r2.zip` · PR242-symbol523-g35-e9-history1-20261104-r2 | 48,630B | [적용 ZIP](https://drive.google.com/file/d/1MO0QgtM9cAXv-Dc9MMATzhkS0aKQCM_Z/view?usp=drivesdk), [전용 적용 폴더](https://drive.google.com/drive/folders/116BtNCMBGVv9IIF1TZi9AyXQ66kHa9vL) |
| 원본 표 보존용 백업 | `lineagem_patch523_all_content_validated_and_508_520_deltas.zip` · 누적523 | 25,031,173B | [기존 원본 ZIP](https://drive.google.com/file/d/1EJGI2VV4u4P2yNlrMAlp0H2U28jjUH6K/view?usp=drivesdk), [원본 보존 폴더](https://drive.google.com/drive/folders/1BlB4_BIrvXJBMwngLbq0ZdFkeETYcC2V) |

최신 적용 ZIP SHA256: `a56a911718ee036c41aa4d63a9cd2fd8981f0daaba958983e1c9b2eea394dce7`.

원본 백업 ZIP SHA256: `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.

원본은 이미 있는 정상 사본을 내려받아 바이트·해시·전체 CRC와 절대 옵션 표46행을 확인했다. 중복 재업로드하거나 이전 사본을 삭제하지 않았다. 새 적용 ZIP은 올린 후 파일ID·부모 폴더·48,630B·비공유/소유자 전용 권한을 읽어 확인했다. 공유 권한을 넓히지 않았다. 원본·적용팩은 기존 `TWILIGHT_리소스_저장소` 안의 서로 다른 폴더다.

## 코드와 설치 방식

코드는 [기능 커밋b45fa2a85f147f723a8436966daae783011d8f18](https://github.com/zoog136-hash/-/commit/b45fa2a85f147f723a8436966daae783011d8f18), 기존 draft [PR242](https://github.com/zoog136-hash/-/pull/242)에 있다. 이후 보관 영수증 커밋은 문서/검증 로그만 추가한다. ZIP manifest는 이 기능 커밋을 요구하며 아래 실제 소비 파일4개와 각 SHA를 기록한다.

```text
<Godot 프로젝트>/data/growth/symbol_source523.json
<Godot 프로젝트>/data/growth/symbol_combat_policy.json
<Godot 프로젝트>/data/growth/symbol_travel_policy.json
<Godot 프로젝트>/data/growth/symbol_history_policy.json
```

필요 코드 커밋을 준비한 뒤 기존 데이터를 백업하고 ZIP의 `data/growth/`를 프로젝트 루트에 풀면 된다. `PACK_MANIFEST.json`은 설치 정보이며 게임 코드 대체물이 아니다. 기존 맵 팩은 `external_map_packs/source84_v3` 또는 `TWILIGHT_SOURCE_MAP_PACK` 인자로 별도 준비해야 한다. 문양 자체 근사9개 묶음과 자체 보관/복구·일일 정책의 기본값·조절 필드를 JSON에 명시한다.

## 기존 소비 폴더의 최신판 재설치 검증

Drive 정식 raw fetch가 반환한 파일 참조로 **다시 다운로드한** ZIP을 `/workspace/symbol-drive-consumer/runtime-history/`에 저장했다.48,630B·ZIP SHA·전체 CRC·manifest5개 엔트리·내부4파일의 바이트/SHA를 검사했다. 기존 검증 소비 폴더 `/workspace/symbol-drive-consumer/project/`를 최신 기능 Git 코드로 갱신하고, 이전 JSON3개를 `runtime/before-history/`에 백업해 제거한 뒤 다운로드 ZIP의 검증한4파일 바이트만 설치했다. 원본 파일/사용자 세이브를 덮어쓰지 않았다.

이 프로젝트에서 격리한 XDG 프로필과 Godot4.7.2로 실제 Main/current source-map/save32개, 새 보관/복구 단위39개 검사를 통과했다. 로드 후에도4개 데이터 SHA가 manifest와 같았다. `evidence/history/drive-main-load.txt`, `drive-history-load.txt`가 결과다. 실행 인자는 다음과 같다.

```sh
XDG_DATA_HOME=/tmp/symbol-drive-history-main/data \
XDG_CACHE_HOME=/tmp/symbol-drive-history-main/cache \
TWILIGHT_SOURCE_MAP_PACK=/workspace/symbol-core-map-pack \
/tmp/symbol-godot472/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --path /workspace/symbol-drive-consumer/project \
  --script res://tests/core_runtime_save_test.gd
```

새 프로젝트 폴더는 기존의 검증한 Git 자원/import cache를 복사했다. 새 머신·전체 재import·Drive에서 전체 맵/아트를 복원한 검증은 아니다. 다른 지역 UI29개와 후속 보관/복구 UI39개는 각각 패키징 전 실제 X11에서 통과했다. 최신 다운로드 후 검사는 headless Main/save32개와 보관/복구 단위39개다. 새 실행 환경이나 전체 게임 시계/시간대 변경은 없다.

## 로컬 보유와 미전달을 구분

- `/workspace/symbol-core-map-pack`: **LOCAL_ONLY**, 아덴/오만1층 검증용 기존 Git source84 부분집합618파일/731,147,235B. 정렬된 파일 경로/바이트/SHA 목록의 SHA는 `9df45683feb653566233d1c6a5df3b73ab2996a4b22007366d5dfdda1c2b779f`다. 오만의 추가 Git 선행파일14개/6,214,451B 중 레거시 의존성은 stage에 따로 있다. 이 자체 검증용 맵 사본을 새 Drive 전체 맵팩 전달로 세지 않는다.
- UI 캡처5개: `/workspace/symbol-validation/offline/screenshots/`에 **LOCAL_ONLY**. 이번에 새 외부 업로드하지 않았다.
- 심층 인계 ZIP149,581B: 기존 Library 파일 `libfile_3acd63a50c148191b10d669d77efd5e3`에서 검증한 입력. SHA `60fa306d6310cddd4b5eb042bbf59720e6dc732d92b3438cf54044815f76811f`. 이번에 Library 새 버전/Drive 보고서 업로드를 하지 않았다.
- 원본 전체 아트 장부와 과거 `a1.zip` 부재는 그대로다. 이 데이터 패치에 원본 아트 `--release-dir` 완료를 붙이지 않는다. 리니지M 엔진/APK/XAPK를 탐색·분석·전송하지 않았다.

세부 파일ID·SHA·내부 파일/설치 경로·범위·검증 결과는 `RESOURCE_STORAGE.json`에 기록했다. 이번 보관/다운로드에는401·승인 거절·불확실한 전송 결과가 없었다. main/다른 PR 병합과 원격 수동 CI는 수행하지 않았다.

이전3파일 [47,082B 적용 ZIP](https://drive.google.com/file/d/1vaeAmGEFPVXGHf2azUeg7p5Y-72cgk0i/view?usp=drivesdk)은 이전 버전으로 보존한다. SHA `f042ba2b1898c4a5f886d5509d0aad593c63ba61a46b12cb046a302a2dfbdb13`이며 최신 보관/복구 정책은 포함하지 않는다. 과거 검증은 `RESOURCE_STORAGE.json.previous_apply_pack`에 구분했다. 후속 캡처2개는 `/workspace/symbol-validation/history/screenshots/`에 LOCAL_ONLY로 보존한다.
