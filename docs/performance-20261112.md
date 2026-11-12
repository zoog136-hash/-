# Android 긴 프레임 조사와 재검증 — 2026-11-12

기준 main은 `8634f931b6b749865c52dd6437b2d18d5f91c174`이다. 작업 브랜치는
`feature/android-frame-stalls-20261112`이며, 아래 계측 설명은 이 기준에서
작업 중인 변경을 포함한다. 최종 구현 SHA·실행 결과는 마지막 결과란에 기록한다.
Android 실제 단말에서 개선을 확인한 상태는 아니다.

## 입력과 해석

제공된 `1001112078.jpg`는 163,573바이트이며 SHA-256은
`bc6f0fa8a846a4ce9126db3c569345fda3ecf89e8ba850de28eac57157121eee`이다.
화면에는 버전 `523.384`, 지난 실행 끊김 1,303회, 최대 12,749ms,
몬스터 배치 12,432ms·캐릭터 141ms·맵 오브젝트 82ms가 표시된다.
이 이미지는 조사 입력이며 이 문서에 원본 파일을 포함하거나 다른 환경에
전달했다는 의미는 아니다.

이 문구는 [frame_hitch_log.gd](../scripts/boot/frame_hitch_log.gd)의
`previous_line()`이 이전 프로세스의 기록을 요약한 것이다.

- 1,303은 이전 실행에서 계측된 100ms 이상 프레임의 누적 횟수이다. 실행
  시간·총 프레임 수가 없으므로 발생률이나 평균 FPS로 바꿀 수 없다.
- 12,749ms는 가장 긴 프레임의 경과 시간이고, 괄호 안 항목은 그 프레임의
  상위 section이다. 현재 로딩 단계의 소요 시간이나 원본 클라이언트 실측이 아니다.
- `field_population`은 배치 처리 범위의 시간이다. 기존 표시만으로 원본 읽기,
  파싱, actor setup, 위치 검색 중 어느 호출이 길었는지 확정할 수 없다.
- 다른 프레임의 시간이 섞였다고 가정하거나 모든 시간을 SP2 파싱으로
  돌리지 않는다. 새 세부 계측과 같은 조건의 재현으로 원인을 좁힌다.

기준 main에는 이미 `sp2_parse_cache.gd`의 기기별 영구 파싱 캐시와
`reference_sp2_asset_service.gd`의 공유 parse/texture 저장소가 있다.
과거 16초 배치 문제에 대한 기존 파싱 캐시를 이번에 새로 만든 최적화로
계산하지 않는다. 원본팩·세이브·빌드가 확인되지 않은 과거 수치는 이번 변경의
전후 비교값으로 사용하지 않는다.

## 새 끊김 계측 읽기

[frame_hitch_log.gd](../scripts/boot/frame_hitch_log.gd)의 `frame()`은
첫 process probe 사이의 경과 시간을 재고 100ms 이상이면 기록한다.
`user://frame_hitch.json`은 최대 5초 간격 및 pause/quit 시 저장되며 다음
시작에서 `frame_hitch.prev.json`으로 이동한다. 정상 종료 여부와 별개로
마지막 저장 이후 구간이 파일에 없을 수 있으므로 수집 시점을 남긴다.

| 필드 | 의미와 주의점 |
| --- | --- |
| `frames`, `hitches`, `threshold_ms` | 프로세스의 계측 프레임 수, 임계값 이상 횟수, 임계값이다. 실행별로 구분한다. |
| `worst` | 가장 느린 12개 프레임만 보존한다. 모든 끊김의 목록이나 총 끊김 시간이 아니다. |
| `ms`, `map`, `at_s`, `frame` | 해당 프레임의 전체 경과 ms, 기록 시점의 맵 문맥, 프로세스 시계 초, 프레임 번호다. 맵 전환 경계에서는 앞뒤 동작 기록도 함께 본다. |
| `sections` | 상위 6개 section. `add_self()`는 이미 계측한 하위 section을 제외한다. 1ms 미만 항목은 개별 표시되지 않는다. |
| `details` | 각 행은 `[operation, total_ms, calls, max_ms]`. 해당 프레임의 호출 합계, 횟수, 가장 긴 한 호출이다. 총 1ms 이상인 operation을 표시한다. |
| `counters` | 해당 프레임에서 발생한 작업 횟수다. 매 프레임 초기화되며 프로세스 누적값이 아니다. |

`details`는 **포함 시간(inclusive)** 이다. 예를 들어 `spawn.total` 안에
`spawn.setup`, 그 안에 `sp2.bank_load`와 `sp2.parse`가 들어갈 수 있다.
이 값들을 서로 더하거나 `sections`에 다시 더하면 중복 계산이다.
`calls`가 많아 합계가 긴 경우와 `max_ms` 한 호출이 긴 경우를 구분한다.
`other`는 전체 경과 시간에서 알려진 section을 뺀 잔여이며 그리기·물리·엔진
및 아직 계측하지 않은 작업이 함께 남을 수 있다.

| operation | 확인할 호출 범위 |
| --- | --- |
| `spawn.total` | `field_population.gd`의 슬롯 배치 요청 전체. 거절·탐색 실패를 포함할 수 있어 성공한 몬스터 수와 같지 않다. |
| `spawn.setup` | 배치 과정의 `monster.setup()` 호출. |
| `sp2.bank_load` | `reference_sp2_bank.gd`의 동기 `load_bank()` 전체. |
| `sp2.parse` | `sp2_parse_cache.gd`의 `parse()` 진입부터 반환까지. 디스크 hit 읽기·검증·복원도 포함하므로 순수 decoder 시간과 같지 않다. |
| `ui.inventory_stage` | 가방 갱신의 계측된 stage. 여러 프레임 작업의 총 UI 완료 시간은 입력 시각부터 별도로 잰다. |
| `ui.catalog_open` | 도감 열기의 동기 진입 범위. 이후 deferred 아이콘 채우기까지 모두 포함한다고 해석하지 않는다. |

| counter | 의미와 비교 방법 |
| --- | --- |
| `sp2.member_verify` | 한 bank load의 member별 메타데이터 준비에서 `_member()`를 호출한 횟수. 전체 파일 SHA 연산 횟수나 전체 프로세스의 member 접근 횟수가 아니다. |
| `sp2.layer_validate` | 원본 action/direction/frame의 layer 검증 횟수. 작업량 보존을 확인할 때 member 준비 횟수와 함께 본다. |
| `sp2.disk_hit` | 영구 파싱 캐시를 정상 복원한 횟수. 메모리 공유 캐시 hit와 구별한다. |
| `sp2.disk_miss` | 정상 복원된 영구 파싱 캐시가 없어 새 파싱으로 진행한 횟수. |
| `sp2.disk_reject` | 잘못된 기존 캐시 항목을 거부한 횟수. miss와 같은 요청에서 함께 증가할 수 있다. |

새 필드는 기존 `schema:1` 기록에 선택적으로 추가된다. 오래된 로그에
`details`·`counters`가 없는 것은 0회·0ms의 증거가 아니다. 새 필드도 100ms
미만 프레임에는 보존되지 않으므로 `worst`의 counter를 합해 전체 실행의
hit 비율이나 총 작업량을 계산하지 않는다. 전체 구간의 cache 통계가 필요하면
해당 캐시의 누적 metrics를 구간 시작·끝에 별도로 수집하고 차이를 기록한다.

## 원본 정적 분석과의 비교

비교 자료는 개인 Library의
`LineageM_Android_클라이언트_기능과_TWILIGHT_개선검토_20261110.docx`
(51,014바이트, 11쪽) 전체를 읽었다. 대상은 Android `1.10.18a`,
versionCode 500, ARM64이다. 보고서의 코드 주소는 ELF 가상주소이며
설명용 함수명·C 유사 코드는 재구성이다. 원 개발 소스를 입수하거나 원본
실행 성능을 측정했다는 의미는 아니다. 보고서의 저장소 검토 기준은
`5586258b932734ffb9515c0d7c4914380e7eb98a`이므로 아래 TWILIGHT 쪽은
이번 기준 main의 코드와 다시 대조했다.

| 정적 근거 | TWILIGHT와 비교할 지점 |
| --- | --- |
| 보고서 4쪽: `0x5544460`은 경로 해석 후 cache hit이면 새 decode/upload 전에 기존 texture를 반환한다. `0x554494c`는 refcount getter `0x55143f8`의 count가 1인 항목만 제거하고, `0x55448b0`는 전체를 release/clear한다. | 식별자·소유권·미사용 정리·전체 비우기를 구분한다. C++ refcount 숫자를 Godot에 그대로 옮기지 않는다. 공유 SP2 캐시의 lease 및 이미지 캐시의 strong/weak 소유권과 비교한다. |
| 보고서 4쪽: `0x5543594 → 0x554389c → 0x5543c44`는 요청·worker·완료 처리이며 완료 때 cache를 재확인한다. | 같은 immutable 자원을 중복 준비하는 경로를 살피는 근거다. 이 관찰만으로 현재 동기 로더를 비동기로 바꾸거나 성능 향상을 단정하지 않는다. |
| 보고서 4쪽: `0x553ae80` 배칭은 호환되는 인접 명령과 허용 flags를 대상으로 한다. | draw call 감소만을 위해 투명도에 민감한 layer 순서를 바꾸지 않는다. |
| 보고서 6–7쪽: SP2 `0x326e144 → 0x2813d78 → 0x326b3d0 → 0x4dba628`. 모든 group metadata 뒤에 sample stream을 읽는다. Android palette marker 1은 정확히 한 항목이다. | [current523_sp2_decoder.gd](../scripts/resources/current523_sp2_decoder.gd)는 metadata/sample 순서를 지키며 Windows523 marker 1은 1/3 후보를 완전 파싱해 판별한다. Android 관찰만으로 Windows 호환 경로를 삭제하지 않는다. |
| 보고서 8쪽: SP2 packed key, remap, `Sprite/A-B.sp2`, 2500 단위 fallback 관찰. S32 `%04x%04x.s32` 및 일부 uppercase 재시도 관찰. | 상위 caller가 확인되지 않은 A/B 의미, 희소 mask bit와 vector index, shift만으로 지형 크기·맵ID·경로 알고리즘을 추정하지 않는다. 원본 byte identity와 기존 지리 계약을 유지한다. |

보고서 11쪽의 분석 바이너리는 `liblineage_sharedcpp.so`, 95,069,568바이트,
SHA-256 `0feda76118ad24f6e6143e44e267740d245b19be35e60211d08c5040f4c172d9`이다.
이번 조사에서는 보고서를 읽었으며 원본 바이너리나 원명령 파일을 새로
다운로드·실행하거나 독립 재분석하지 않았다.

Windows 쪽 [source_lock.json](../data/original_client/source_lock.json)과
[source_lock_m47_m123.json](../data/original_client/source_lock_m47_m123.json)은
코드 기원524·데이터525 및 `DESIGN_NOT_RECOVERED_API`를 명시한다.
`scripts/original_client/`의 계약 fixture PASS를 원본 실행·화면 일치·성능
동등성으로 해석하지 않는다. [sprite_cache.gd](../scripts/original_client/sprite_cache.gd)의
450/64MiB 모델은 전역 메모리 상한이나 실제 eviction 구현을 뜻하지 않는다.

기준 main에는 이미 32-atlas LRU, raw chunk 48개 제한, source/tile catalog
재사용, 공유 SP2 payload 저장소와 팩별 이미지 캐시가 있다. 11월 10일
보고서의 과거 상태나 현재 존재하는 캐시를 새 개선 성과로 반복 계산하지 않는다.
캐시 payload 추정 바이트는 GPU 상주량·RSS·PSS와 별도다.

## Android 실제 단말 재검증 절차

아래는 **실행 계획**이다. 이 Work의 PC headless 결과나 계약 테스트가
실제 Android 통과를 대신하지 않는다.

1. APK SHA·코드 SHA·원본팩 manifest SHA·기기/OS·Godot 버전·화면 해상도·
   FPS 제한·전원 상태를 기록한다. 발열 상태와 계측 설정도 전후 동일하게 맞춘다.
2. 동일 세이브의 별도 시험 복사본을 준비하고 각 반복 전에 복원한다.
   같은 맵·좌표·카메라·장비·변신·몬스터 수로 시작한다. 원본 세이브·팩은
   보존하고 파생캐시 초기화와 세이브 초기화를 혼동하지 않는다.
3. `process-cold`는 새 프로세스에서 시작하되 영구 파생캐시를 유지한다.
   `derived-cache-cold`는 격리 시험 데이터의 해당 파생캐시만 비운다.
   `warm`은 같은 프로세스에서 같은 구역을 재진입한다. OS 파일 캐시까지
   차갑다고 주장하지 않는다.
4. 빌드별·조건별로 최소 3회 반복한다. 가능하면 전후 빌드를 번갈아 측정하고
   발열이 누적되면 식힌 뒤 진행한다. 다른 빌드로 설치할 때도 시험 세이브와
   원본팩이 의도대로 보존·선택됐는지 확인한다.
5. 아래 구간을 각각 기록한다. 최초 작업과 반복 작업을 합쳐 평균내지 않는다.

| 구간 | 고정할 작업 | 함께 확인할 항목 |
| --- | --- | --- |
| 시작·맵 진입 | 첫 조작 가능한 프레임까지 | boot 단계·맵 진입 시간, 첫 배치의 `spawn.total/setup`, `sp2.bank_load/parse` |
| 정지 60초 | 같은 화면에서 입력 없이 대기 | 주기적 리젠·실패 재시도·HUD 끊김, actor 수 |
| 이동 60초 | 같은 경로·속도로 청크 경계 통과 | 지도·오브젝트·새 배치 시간, raw read와 atlas 상태 |
| 가방 | 첫 열기, 같은 페이지 5회 재열기 | `ui.inventory_stage`, 선택·스크롤 보존, 모든 아이콘 완료까지 시간 |
| 변신 | 같은 보유 변신의 첫 적용과 반복 전환 | `ui.catalog_open`, 필요한 bank load, 몸체·그림자·옷·방향·모션 누락 |
| warm 재진입 | 같은 구역으로 돌아오기 | 반복 파싱·검증 수, 공유 cache 재사용, 기존 actor/레이어 보존 |

각 구간 전후의 누적 cache metrics는 **차이**로 비교한다. 새 per-frame
counter와 섞지 않는다. 제공되는 범위에서 parse hit/miss/write/reject,
공유 캐시 live/idle/pending, 이미지 resident/weak hit·eviction,
raw read·cached chunk·atlas 수를 남긴다. 수집되지 않은 값은 `미수집`으로
기록한다. logcat의 전체 `FRAME_HITCH` 줄은 파일의 worst12 밖 기록을
보완할 수 있지만 수집 중단·유실 여부를 함께 기록한다.

기존 `frame_hitch.json`·`frame_hitch.prev.json`은 다음 실행 전에 실행
식별자와 함께 보존한다. 새 process·같은 process의 구간·APK 버전이 섞이지
않도록 파일과 로그에 구간 시작·끝 시각을 남긴다. 실제 frame trace가 없으면
평균 FPS와 p50/p95/p99는 `미수집`이다. 100ms 미만 반복 끊김은 이 logger만으로
검출할 수 없다. 자동저장·pause/resume·알림·발열 변화가 발생한 구간은 표시한다.

개선 여부는 같은 작업량에서 긴 프레임과 반복 준비 비용이 줄었는지로 판단한다.
몬스터·오브젝트·layer·애니메이션을 빠뜨려 빨라진 경우는 개선으로 인정하지
않는다. 세이브의 진행도·장비 개체·컬렉션·보스 상태도 별도로 보존됐는지 확인한다.

## 구현과 검증 결과

[기계 판독 결과](performance-20261112-evidence.json)에 합성 입력·검사 수·전후 작업량을 기록했다.
원본 이미지·맵·모션 데이터는 변경하지 않았다.

- SP2 bank load 내부의 동일 member 메타데이터를 한 번만 검증하고 compact geometry만 공유한다.
  raw/body/blocks나 별도 장기 cache를 추가하지 않는다. 최종 member·metadata 검증과 실제 draw 검증을 유지한다.
- 가방 한 번의 stage/selection refresh에 한 owner snapshot과 opaque physical reference 색인을 공유한다.
  선택·사용 시에는 최신 소유·필터를 다시 검사한다.
- 변신·인형의 원본 창을 먼저 시도하고 처리된 경우 기존 browser 생성을 생략한다.
  browser 검색·선택·스크롤을 유지하며 숨겨진 browser의 ownership/icon 갱신을 막는다.

| 확인 | 실제 결과와 범위 |
| --- | --- |
| Godot import | 공식 4.7.2, headless import 완료; script/resource 오류 없음 |
| 새 SP2 memo 검사 | 31조건 PASS. 합성 layer 160회의 member 호출 160→3, pin 검사 161→1. 전체 결과·트랙·출처·픽셀·오프셋 동등, 희소/빈 프레임 및 사전·도중 변조 거부 |
| 새 가방 snapshot 검사 | 983조건 PASS. 물리 참조·중복·필터·정렬·선택/사용의 최신 소유 확인·4/8열·스크롤 유지 |
| 변신/native 우선 경로 | 53조건 PASS. 처리됨/거절/팩 없음의 fallback, 숨은 browser 갱신 방지·상태 보존. 실제 원본 UI 입력 검증은 미실행 |
| 끊김 로그 | 25조건 PASS. 같은 프레임의 total/calls/max, counters 초기화, exclusive sections와 분리, 이전 schema 읽기 |
| 실제 Main·세이브 | 33조건 PASS. 격리된 새 XDG profile에서 저장·재불러오기·진행/장비/컬렉션 보존·누락팩 거부. 원본523팩 없어 지도 통행은 미검증 |
| 실제 OpenGL 부팅 | Xvfb, Mesa llvmpipe/OpenGL 4.5 Compatibility, `--quit-after 60`, exit 0. script/resource 오류 없음. 원본523팩 부재의 안전 처리이며 게임 원본픽셀 검증 아님 |
| 확장 관련 회귀 | 12개 중 9 PASS, 아래 기존 실패 3개. 신규 회귀 3개 별도 PASS |
| Python/리소스 | Python compile, `test_ci_core.py` 10개, 현재 리소스 검사 및 검사 자체 2개 PASS |
| 자동 gate | 새 회귀 2개를 `tools/ci_core.py`에 등록. 정확한 commit·원격 gate 상태는 이 변경의 draft PR checks에 기록 |
| Android 실기기/APK | 미실행·미빌드. 기기별 cold/warm frames/hitches/latency·FPS는 미수집 |

확장 검사 실패는 같은 엔진·격리 profile의 수정 전 main에서도 모두 재현했다.
`monster_pool_retirement_test`는 `monster.gd:254`의 기존 `bool` 호출 runtime error,
`monster_spawn_physics_sync_test`와 `monster_visual_parking_test`는 원본523팩 없는
현재 환경에서 population 0을 전제로 한 실패다. 이 실패를 통과로 집계하거나
테스트의 요구를 낮추지 않았다. 전체 과거 visual/gameplay suite를 통과했다고 주장하지 않는다.

가방 CPU 참고 비교는 [benchmark_inventory_snapshot.gd](../tests/benchmark_inventory_snapshot.gd)의
동일한 합성 inventory를 **4열·8열 두 계약으로 각각 생성한 합계**다. 256개 소유 항목에서
owner 조회는 513→1회, 이 Linux 실행 1회의 경과 시간은 5592.537→14.175ms였다.
64개에서는 129→1회, 105.358→2.807ms였다. 실제 화면에 512개 슬롯이 있다는 뜻이 아니며,
원본 CSB scene 구축·이미지 렌더·휴대폰 가방 2초를 측정한 결과가 아니다. 시간 임계값은
회귀 통과 조건으로 사용하지 않는다. 재현 명령은 benchmark 소스 주석에 있다.

남은 동기 비용 후보는 최초 SP2 manifest split/bake, device-cache miss의 decoder parse,
action JSON 검증·트랙 확장, 최초 픽셀 해석·텍스처 upload다. 배치의 호출 간 예산은 단일
긴 setup을 중단하지 않는다. 선택 후 source UI 재생성·이미지의 의도된 바이트/SHA 재검증,
카드 최대 150개 동기 구축, quickslot snapshot 반복도 남아 있다. 지도 controller는
동일 manifest의 catalog를 재사용하므로 정지 증상을 지도 전체 재생성으로 확정하지 않았다.
차가운 chunk/atlas 로딩과 renderer miss는 실제 단말에서 따로 확인해야 한다.

저장소 지침의 사전검사 `python3 tools/check_resource_integrity.py --root .`는 이 main에
도구가 없어 exit 2였으며 `data/resource_delivery_ledger.json`도 없다. 현재 필수 workflow는
`check_no_legacy_resources.py`로 교체되어 있어 해당 검사와 자체 회귀 2개를 실행했다.
예전 검사 실패를 PASS로 바꾸거나 삭제하지 않았다. 원본팩의 새 변환·업로드·전달은 없으며,
기존 원본 리소스 완료 상태를 변경하지 않는다. 거래소·캐릭터 생성과 종료/크래시 조사는
이번 변경에 포함하지 않는다.
