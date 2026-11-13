# 등록·무게·상점 설치 로딩 최적화

## 최종 C4 및 최신 main 통합 결과

C4 독립 측정은 clean `fa42b02f64d278c56f88c0ace051c57de0bc04fd`(main `dd30440b` 포함), 최종 통합 측정은 clean `4963326161a566527911ab623a3f5f6c6b279050`(고정 main `c898afcee9f277bb63db86397372014ceb243b1c` 포함)이다. 최신 main의 loader·character·prepared-SP2 변경과 모든 검사를 보존했다. 이후 원격 게시 커밋은 같은 runtime과 최종 문서의 tree로 만들며 정확한 CI SHA는 PR에 기록한다.

**최종 통합 artifact의 첫 진입 추가 개선은 확인하지 못했다.** 통합 first 229.903초는 역사 C3 228.405초보다 느리다. 첫 로딩 목표의 이 한계와 남은 cold 작업을 유지한다.

Godot 4.7.2 official Linux headless, 동일 원본 정의·Land4 위치/manifest pin·조건 provider로 실제 `Loading.open(Main.tscn)`→readiness/finished를 측정했다. first는 빈 앱 프로필, next는 해당 arm의 성공한 first 프로필을 쓴 새 프로세스다. OS page cache·시스템 부하는 통제하지 않았다. 타이틀/캐릭터 화면을 포함하는 전체 사용자 실행 시간이나 Android/GPU 수치가 아니다.

| 실제 Main/Land4 process wall | 역사 C3 | C4 독립 fa42 | 최신 main 통합 |
|---|---:|---:|---:|
| first | 228.405초 | 225.129초 (-1.43%) | 229.903초 |
| next | 72.870초 | 67.888초 (-6.84%) | 65.721초 |

C4 독립 first 차이는 3.276초의 단일 관측이며 C2의 221.745초보다 여전히 느리다. first 개선을 일반화하지 않는다. 최신 통합 수치는 다른 main runtime 변경도 포함하므로 C4 패치만의 효과로 귀속하지 않는다. 통합 Loading.open→finished는 first 227.724996초/next 63.581333초, sampled peak RSS는 1998460/1736840KiB다. 메모리 감소를 주장하지 않는다.

두 통합 진입 모두 strict receipt 통과, readiness/source active=true, draw_commands=23442, unresolved_refs=0, 완료 전 100% 미표시를 확인했다. 프로필에 기존 플레이어 저장은 없었고 save_preservation/new_save_files는 빈 객체다. 실제 seeded Main 저장 보존은 필수 Core 검사와 별도 증거로 구분한다. 다섯 native/equipment `.bin` 및 17865924바이트 source-shop model SHA가 역사 C3와 동일했다. code-key metadata는 안전하게 달라지며 payload와 분리한다.

## 변경 및 독립 진단

- World의 일괄 무게 검증만 기존 guarded `_full_for_binding`을 사용한다. 공개 weight API는 원래 full/cache/snapshot 동작을 유지한다. 원본 archive/row 일치, 제외 선언, 0, 정책, overflow 검사를 생략하지 않는다. cached/generic/subclass/interning 경로는 원래 확장으로 fallback한다.
- Cash.install의 동기 수명에만 이름→첫 위치 인덱스를 사용한다. 실제 base World와 Main의 potion presentation adapter, 실제 Catalog 및 기본 quest/mastery/reset-ticket/template 소유자만 허용한다. 공개 resolve/box_record/일반 World lookup은 기존 경로다. 원래 source 순서·중복 우선순위·removed-name·source-ID·held quest/instance 복사 동작을 보존하고 알려진 두 append를 추적한다. 배열 identity/크기 변화·추적하지 않은 append·변한 indexed hit는 fallback한다. 종료 시 인덱스를 닫고 해제한다.
- 감사한 기본 install 경로는 await/신호/임의 callback 없이 기존 이름을 바꾸지 않는다. 임의 same-size 외부 rename을 탐지하는 일반 live-cache API가 아니며 그런 custom owner는 활성 조건에서 제외한다. 전역 forget_misses가 이 scope를 무효화한다고 주장하지 않는다.

무게 진단은 실제 World 33980개 입력과 33172개 최종 index를 같은 프로세스에서 2쌍 교대 비교했다. 평균 9.494610→6.674383초(-29.70%)이며 전체 입력 SHA `86f0affe8cf1d02bc15a26d919b30f67706787bcb650e830631bc7f83ddea447`, index SHA `22d5ebf245ad47da14a8e81f69c705f0bfc53e931c58ee5675d48a41e53f6fa7`가 같았다. 전체 게임 진입 시간이 아니다.

유효 Cash 비교는 같은 준비 프로필의 별도 복사에서 수행했으며 초기 파일 SHA manifest를 보존했다. 후보 code-key 재준비 138.630초는 fresh first나 warm 수치로 사용하지 않는다. warm install은 6.507893→2.424732초(-62.74%), 553개 lookup 합계 3.957179초→4.036ms, 전체 miss scan 336→0이었다. 29 bindings(23608바이트), catalog(34421012바이트), item_db(432544바이트)의 전체 Variant SHA가 각각 동일했다. 임시 이름 인덱스는 33596개/2 sources, 생성 시 Godot static allocation delta 2760204바이트이며 process peak RSS와 다른 지표다.

상점 최초 열기는 같은 프로세스의 실제 HUD→원본 shop panel 경로다. 437개 entry/filtered가 같고 동기 call 1.558841→1.583472초(+24.631ms), 두 프레임 포함 1.577526→1.601908초였다. 이 한 관측에서 수초의 비용 이동은 보이지 않았다. 계측 전체 process wall은 66.268→65.817초로 다른 단계의 변동도 있으므로 install 구간의 4.083초 절감이 전체 시간에 그대로 나타났다고 주장하지 않는다. 이 진단은 fa42 단계이며 후속 최신-main 통합 first/next와 별도다.

## 검증 범위와 실패 이력

- 독립 C4 focused 4개, 최신-main 통합 focused 6개(기존 lookup 2개·Cash 35 assertions·weight 13 assertions·upstream loader/prepared-bank)가 모두 통과했다. 기존 173 Core+신규 2개+upstream 1개를 보존해 필수 Core는 176개다. 정확한 게시 head의 원격 Core/resource 결과는 PR에 기록한다.
- 최초 실제 weight 60 guard는 공개 호출이 먼저 cache를 채운 조건이었다. 후속 실제 fresh 비교는 105/105 출력 일치, 65개 fresh 호출, 정상 3개/실제 0 무게 1개/late reject 62개/원문 제외 3개, index SHA 보존을 확인했다. 다만 선택한 큰 numerator 9007199254740991이 기존 정수 정책에서 먼저 거절되어 overflow 도달 counter 0으로 harness strict 실패했다. 이를 통과로 계산하지 않았다.
- 별도 실제 원문 ItemClass230/Weight5000 fresh TemplateStore 검사에서 3/1→15000 정상, 기존 큰 값의 early reject, 정확히 표현 가능한 2^52 multiplier의 실제 multiplication overflow 거절을 public/bulk 모두 동일하게 확인했다(exit0, 차이0). 초기 실패와 이 보강 단계의 로그/종료 상태를 모두 보존했다.
- 최초 두 Cash 후보는 기능 SHA는 같았지만 scope가 꺼져 있었다. nested GDScript의 빈 resource_path, 실제 Main의 potion adapter 누락을 수정하고 실제 Main 양성 unit과 준비 프로필의 실제 store/catalog/quest/mastery/reset-ticket 전체 10조건 diagnostic을 통과시켰다. inactive 결과를 성능 증거에서 제외했다. 최종 비교는 scope 활성·553 lookup·miss0을 필수 assertion으로 요구했다.
- upstream prepared-SP2는 opt-in immutable 경로이며 기존 mutable full API를 유지하고 pin/member proof와 cache-forget 정리를 확인했다. 이번 통합은 해당 새 Core fixture와 실제 Main 호환 검증이며 원본 SP2 전체 미디어나 전체 아트 동등성 재승인이 아니다.

각 first/next의 상위 5개 BOOT end stage와 선택된 세부 단계는 `c4-integrated/comparison-summary.json`에 기록한다. 부모/자식 중첩 시간을 포함하므로 합산하지 않는다. 추가 최적화 실험은 이번 게시 범위에 포함하지 않는다.

로컬 증거: `twilight-improve-results-20261113/c4/`(독립 측정), `c4-integrated/`(최신-main 통합), `c4-cash-profile-active/`(유효 진단), `twilight-world-weight-fresh-guards-combined-summary-20261113.json`(실패/보강 구분). 공개 변경은 source/test/docs만이며 원본 ZIP/지도/미디어·추출물·캐시·저장·새 이미지를 포함하지 않는다. Android 실기기, GPU/pixel, 원본 전체 미디어 및 원본 팩 영구 납품은 미완료다. PR은 draft로 유지하며 병합하지 않는다.

## 이전 C1–C3 검증 이력

통합 기준 main은 `3ea41de9dee65cf3cbe2c65c9f68e6d3cbaa5b45`, 아래 C2 측정 코드는 `7a0b1fca2286d1c05d8d63bbb557a0279b75436a`이다. PR #425의 실제 완료 작업 진행률과 최신 main의 타이틀·캐릭터·Android 수정을 유지한다. 최종 C3 코드는 `b879158c3930ed7e1737c04d4730ba03669fb9f6`이며 아래에 별도로 재측정했다.

### 변경

- 실제 native 등록의 검증된 reader와 아직 기억되지 않은 transient ID에서만 DTO가 소비하지 않는 Market 참조 그래프 생성을 줄인다. 첫 유효 그래프 한 개는 원래 경로로 만들어 테이블·인덱스를 준비한다. 일반 `describe`, `transient_definition`, `definition_id`, 알려진 ID와 다른 owner는 기존 동작을 유지한다.
- 등록 수명 안에서 스킬 바인딩 JSON 파싱을 재사용한다. 호출마다 원문을 다시 읽어 내용 변경을 확인하고 원래 비교·스캔을 유지한다. 중첩 등록·스레드·source reset·등록 종료 상태를 분리한다.
- 장비 이름 집계와 후보 ID/상태 필터에서 필요한 packed 필드만 읽는다. 필요한 레코드만 복원하고 4096개 캐시 상한과 누락 필드 fallback을 유지한다.
- 실제 효과가 입증되지 않은 packed shape shortcut과 HEAVY membership 인덱스 실험은 제외했다.

### 실제 원본 C2 비교

같은 Godot 4.7.2 Linux headless 환경에서 두 arm을 순차 실행했다. first는 빈 애플리케이션 캐시이며 OS page cache·시스템 부하는 통제하지 않았다. next는 각 arm 자신의 첫 성공 프로필로 새 프로세스를 실행했다. 한 쌍의 관측이며 Android/GPU 수치가 아니다.

| 항목 | 기준 main | C2 | 변화 |
|---|---:|---:|---:|
| 실제 Land4 첫 진입 process wall | 249.778초 | 221.745초 | -11.22% |
| 같은 프로필 다음 진입 | 70.358초 | 71.199초 | +1.20%, 개선 확인 못함 |
| native cold 등록 | 64.432초 | 40.966초 | -36.42% |
| native same-process warm | 3.187초 | 2.854초 | -10.44% |
| 장비 cold 생성 | 47.027초 | 42.784초 | -9.02% |
| 장비 same-process warm | 1.370초 | 1.555초 | +13.55%, 0.186초 증가 |
| 첫 public Market 조회 | 18.673ms | 19.237ms | +0.564ms |
| Market 대상 4669개 전체 생성 CPU 경과 | 26.923초 | 28.084초 | +4.31% |

네 게임 진입 모두 readiness=true, source active=true, 렌더 명령 23442개, unresolved_refs=0, 완료 전 100% 미표시를 확인했다. 이 격리 프로필에 기존 플레이어 저장은 없었으므로 빈 저장 비교를 실제 저장 바이트 보존 증거로 계산하지 않는다. 저장 보존은 별도의 실제 Main/seeded-save Core 검사에서 확인한다. 첫 진입 sampled peak RSS는 기준 1986204KiB, C2 1988080KiB로 메모리 감소를 주장하지 않는다. headless 렌더 명령 수는 실제 픽셀·GPU·전체 원본 미디어 검증이 아니다.

전체 등록 결과와 native/equipment 캐시 5개 데이터 SHA가 동일하다. public Market 4669개는 full Variant 1777460716바이트 및 Market-only 1738795152바이트의 스트리밍 SHA가 동일하다. 전체 public 조회 검증의 직렬화·SHA 비용은 생성 시간과 별도 기록했으며 첫 진입 단축 수치에 포함하지 않는다.

### 실험·검증 이력

- 원본 정의 ZIP 25031173바이트, 고정 SHA `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`, 1075개 CRC 통과. 지도 ZIP 8개 618196967바이트, 16221파일과 내부 S32 6570개·TI2 7557개 크기/SHA 검증 통과. 원본과 추출본은 비공개 로컬 입력으로 유지하며 Git에 포함하지 않는다.
- 초기 C1은 native 58.831→39.274초였지만 첫 Market 조회가 17.378→2812.522ms로 늦어졌다. 이를 그대로 채택하지 않고 첫 그래프 준비를 유지해 위 C2에서 재검증했다.
- 최초 Land4 시도는 원문 조건 provider 설정 누락으로 80%에서 실패했다. 실패 252.706초를 성공한 첫 진입 시간으로 계산하지 않는다. 이후 기존 `--patch523-world-links` 및 고정 SHA 실행 인자로 정상 조건 팩을 연결했다. 안전 검사나 readiness gate를 우회하지 않았다.
- C1 이전 로컬 Core 168개/보고 assertion 200719개와 Python CI 명령 18개 통과. 최종 Market 보완 후 scope 68개와 bounded 등록 46개 통과. shape shortcut 제외 후 packed 152358개, 카탈로그 6113개, 전체 cold compiler 1982개, binding fallback 61개 통과. 이후 추가 변경 검사는 별도 단계로 기록한다.
- 최신 main의 검사와 새 비교 두 개를 모두 보존한 필수 Core 수는 173개다. 게시된 정확한 SHA의 원격 CI를 최종 게이트로 확인해야 한다.
- `tools/check_resource_integrity.py`는 기준 main에 없다. 현행 `tools/check_no_legacy_resources.py --root .`의 추적 리소스 20개 검사는 통과했다. 외부 원본 전체 납품을 의미하지 않는다.

실행·동일 조건 비교 방법은 `ENTRY_BENCHMARK_HARNESS_20261113.md`를 참조한다. 원본 파일·생성 캐시·저장 파일·새 이미지는 이 변경에 포함하지 않는다. Android 실기기, GPU, 전체 원본 미디어 검증은 미완료다.

### 최종 C3 재측정

C3는 `TemplateStore` 내부 binding fast path에서 `get_var()`가 매번 새로 복원한 중첩 값을 다시 깊은 복사하지 않고 넘긴다. 공개 조회, 다른 subclass/reader, intern된 캐시 경로는 기존 동작을 유지한다. 변경된 값이 다음 조회·원본·형제 record에 전파되지 않는지 `equipment_binding_fusion_test.gd`로 검사했다.

기준 main과 C2 결과는 보존하고 C3만 새 catalog 및 Land4 first 프로필로 순차 측정했다. 같은 원본·Godot·동일 옵션/조건 provider를 사용했으며 stage/runtime 1057개 파일의 바이트 일치와 C3 clean revision을 receipt에 기록했다. first 성공 후 같은 C3 프로필의 별도 next 프로세스를 실행했다.

| 항목 | 기준 main | C2 | 최종 C3 | C3 대 기준 |
|---|---:|---:|---:|---:|
| 실제 Land4 첫 진입 process wall | 249.778초 | 221.745초 | 228.405초 | -8.56% |
| 같은 프로필 다음 진입 | 70.358초 | 71.199초 | 72.870초 | +3.57% |
| native cold 등록 | 64.432초 | 40.966초 | 38.987초 | -39.49% |
| native same-process warm | 3.187초 | 2.854초 | 2.977초 | -6.58% |
| 장비 cold 생성 | 47.027초 | 42.784초 | 41.086초 | -12.63% |
| 장비 same-process warm | 1.370초 | 1.555초 | 1.447초 | +5.68% |
| 첫 public Market 조회 | 18.673ms | 19.237ms | 17.996ms | -0.677ms |
| Market 4669개 전체 생성 CPU 경과 | 26.923초 | 28.084초 | 27.555초 | +2.35% |

C3 첫 진입은 기준보다 빨랐지만 C2보다 6.660초 느렸다. 한 번씩의 관측과 통제하지 않은 OS page cache·시스템 부하로 C3가 전체 진입을 추가 단축했다고 주장하지 않는다. next와 장비 warm도 개선을 확인하지 못했다. C3 Loading.open→finished는 first 226.058963초, next 71.042762초였다. first/next sampled peak RSS는 1987924/1736256KiB이며 메모리 개선을 주장하지 않는다.

C3 두 진입 모두 strict receipt 통과, readiness=true, source active=true, 원본 Land4 677개 source 배치, draw_commands=23442, unresolved_refs=0, 완료 전 100% 미표시를 확인했다. first/next의 `save_preservation`과 `new_save_files`는 모두 빈 객체다. 기존 저장이 없는 벤치 프로필의 결과이며 실제 저장 보존 증거는 focused `core_runtime_save_test`와 필수 원격 Core gate로 구분한다. 원본 지도 실행은 저장/조건/provider 안전 검사를 그대로 통과했다.

최종 catalog 비교는 `equivalent=true`, 차이 0개이며 native/equipment 데이터 캐시 5개 SHA가 기준과 동일했다. public Market 4669개 전체 Variant 1777460716바이트 SHA `a42c38ec738963adcd6a8285216062728fd51204584e91901de3703a94143797`, Market-only 1738795152바이트 SHA `45ae1f3d15e095922bc3fc20cad590a8481dcb4de81e62cd273d1c16ae7a2244`가 일치했다. 전체 직렬화·SHA 43.671초는 생성 CPU 경과 27.555초와 분리했다.

별도 진단에서는 실제 32460개 binding을 같은 프로세스에서 원래 경로/C3 경로로 교대 2쌍 측정했다. 초기 warmup을 제외한 평균 14.624288→13.252487초(-9.38%)였고, 149231176바이트 binding SHA `4996ee293c8185ffd3e11f2156d0471aff9ce6addddf83c0ced2c6b3c4216846` 및 전체 packed Variant SHA `2e148ca16a80fc8ba9d53785643894d8bd0a3a540aabff729fe5afa1644d7176`가 모두 같았다. 계측 비용·재사용된 raw-table 캐시를 포함하는 내부 진단이며 전체 게임 진입 단축 수치가 아니다.

최종 로컬 focused 20개 검사가 모두 통과했다. 새/변경 Core, packed field/lookup, binding 분리, 등록 scope·bounded, 실제 cold compiler, 실제 Main 저장 보존, 로딩 readiness, 원본 prebake, Orim/minigame 경로를 포함한다. 최종 소스만 20개 파일이며 원본 ZIP/추출물·캐시·플레이어 저장·새 이미지·벤치 출력은 공개 PR에 포함하지 않는다. 정확한 게시 SHA의 필수 Core 173개 및 resource CI가 최종 게이트이며 원격 결과는 PR에 남긴다.

로컬 evidence: `twilight-improve-results-20261113/c3/catalog/{final.json,final-receipt.json,comparison.json}`, `c3/entry/source-land4-{first,next}{,-receipt}.json`, `c3/comparison-summary.json`. 실제 원본 전체 미디어·GPU·Android 실기기 검증과 원본 팩의 영구 납품은 미완료다.
