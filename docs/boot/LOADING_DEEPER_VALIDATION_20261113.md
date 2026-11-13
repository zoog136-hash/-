# 등록 및 장비 규칙 생성 후속 최적화

통합 기준 main은 `3ea41de9dee65cf3cbe2c65c9f68e6d3cbaa5b45`, 아래 C2 측정 코드는 `7a0b1fca2286d1c05d8d63bbb557a0279b75436a`이다. PR #425의 실제 완료 작업 진행률과 최신 main의 타이틀·캐릭터·Android 수정을 유지한다. 최종 C3 코드는 `b879158c3930ed7e1737c04d4730ba03669fb9f6`이며 아래에 별도로 재측정했다.

## 변경

- 실제 native 등록의 검증된 reader와 아직 기억되지 않은 transient ID에서만 DTO가 소비하지 않는 Market 참조 그래프 생성을 줄인다. 첫 유효 그래프 한 개는 원래 경로로 만들어 테이블·인덱스를 준비한다. 일반 `describe`, `transient_definition`, `definition_id`, 알려진 ID와 다른 owner는 기존 동작을 유지한다.
- 등록 수명 안에서 스킬 바인딩 JSON 파싱을 재사용한다. 호출마다 원문을 다시 읽어 내용 변경을 확인하고 원래 비교·스캔을 유지한다. 중첩 등록·스레드·source reset·등록 종료 상태를 분리한다.
- 장비 이름 집계와 후보 ID/상태 필터에서 필요한 packed 필드만 읽는다. 필요한 레코드만 복원하고 4096개 캐시 상한과 누락 필드 fallback을 유지한다.
- 실제 효과가 입증되지 않은 packed shape shortcut과 HEAVY membership 인덱스 실험은 제외했다.

## 실제 원본 C2 비교

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

## 실험·검증 이력

- 원본 정의 ZIP 25031173바이트, 고정 SHA `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`, 1075개 CRC 통과. 지도 ZIP 8개 618196967바이트, 16221파일과 내부 S32 6570개·TI2 7557개 크기/SHA 검증 통과. 원본과 추출본은 비공개 로컬 입력으로 유지하며 Git에 포함하지 않는다.
- 초기 C1은 native 58.831→39.274초였지만 첫 Market 조회가 17.378→2812.522ms로 늦어졌다. 이를 그대로 채택하지 않고 첫 그래프 준비를 유지해 위 C2에서 재검증했다.
- 최초 Land4 시도는 원문 조건 provider 설정 누락으로 80%에서 실패했다. 실패 252.706초를 성공한 첫 진입 시간으로 계산하지 않는다. 이후 기존 `--patch523-world-links` 및 고정 SHA 실행 인자로 정상 조건 팩을 연결했다. 안전 검사나 readiness gate를 우회하지 않았다.
- C1 이전 로컬 Core 168개/보고 assertion 200719개와 Python CI 명령 18개 통과. 최종 Market 보완 후 scope 68개와 bounded 등록 46개 통과. shape shortcut 제외 후 packed 152358개, 카탈로그 6113개, 전체 cold compiler 1982개, binding fallback 61개 통과. 이후 추가 변경 검사는 별도 단계로 기록한다.
- 최신 main의 검사와 새 비교 두 개를 모두 보존한 필수 Core 수는 173개다. 게시된 정확한 SHA의 원격 CI를 최종 게이트로 확인해야 한다.
- `tools/check_resource_integrity.py`는 기준 main에 없다. 현행 `tools/check_no_legacy_resources.py --root .`의 추적 리소스 20개 검사는 통과했다. 외부 원본 전체 납품을 의미하지 않는다.

실행·동일 조건 비교 방법은 `ENTRY_BENCHMARK_HARNESS_20261113.md`를 참조한다. 원본 파일·생성 캐시·저장 파일·새 이미지는 이 변경에 포함하지 않는다. Android 실기기, GPU, 전체 원본 미디어 검증은 미완료다.

## 최종 C3 재측정

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
