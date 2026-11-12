# 원본 정적 근거와 TWILIGHT 성능 개선의 구분 — 2026-11-12

비교 기준은 TWILIGHT `28f3084a903d1cff4dbbd45c3a1ca5a0ed0a52a2`다. 리니지M 자료는 기존 정적 분석 보고서, 제공된 XP Hero APK는 이번에 직접 읽은 IL2CPP 메타데이터다. 아래 근거는 성능 설계의 참고이며 Android 실행 시간·RAM·FPS 개선이나 원작 동등성의 측정 결과가 아니다. 구현과 테스트 결과는 [후속 성능 검증](performance-spawn-20261112.md)에 기록한다.

제공 APK는 `/workspace/xp-hero-reference/xp-hero-mod_27.0.0-apkvision.apk`, 193,056,556 bytes, SHA256 `0a6e034f04821218f20b156020d9635ce46fc07d2a97ad1e9761aaab614f443d`다. 크기와 SHA256을 독립 재확인했다. 같은 환경에서 ZIP 11,299개와 전체 CRC 검사도 정상이었다. 설치·실행은 하지 않았다. 이 경로는 현재 Work 환경의 조사 경로이며 다른 환경에서의 접근이나 영구 전달을 보장하지 않는다.

직접 읽은 `assets/bin/Data/Managed/Metadata/global-metadata.dat`는 19,756,888 bytes, SHA256 `3f16ec1226b7d896de52e8c13b4c35cdfb7a41540cbd40feb520098081b2cc22`, magic `0xfab11baf`, metadata v31이다. 다음 표의 offset은 이 메타데이터 파일 안의 바이트 위치다. 네이티브 함수 주소가 아니다.

| 메타데이터 표 | offset / bytes | record 크기 / 개수 |
|---|---:|---:|
| MethodDefinition | 4,902,960 / 5,440,644 | 36 / 151,129 |
| FieldDefinition | 13,723,892 / 1,204,380 | 12 / 100,365 |
| TypeDefinition | 16,301,792 / 1,905,024 | 88 / 21,648 |
| ImageDefinition | 18,206,816 / 5,480 | 40 / 137 |

각 표의 나눗셈 나머지는 0이고 파일 경계 안에 있다. `ImageDefinition`은 어셈블리 관련 레코드이며 이미지 텍스처 137개라는 뜻이 아니다. 메서드 개수는 선언 레코드 수이며 복구한 함수 본문 수가 아니다.

| 직접 확인한 타입 | type index / record offset | 필드·메서드 선언의 예 |
|---|---:|---|
| `DevilHunterIdle.Common.EnemyPoolManager` | 6619 / 16,884,264 | `_pool`, `_stageBossPool`, `_dungeonEnemyPool`, `_loadedCacheKeys`, `_bundleToPrefabKeys`; `InitTargetPool`, `TrySkipInitWhenCommonPoolHealthy`, `Co_EnsureEnemyBundlesInMemory`, `Get`, `Return`, `ReturnAll`, `ReleaseCommonEnemyPoolsForBundle`, `ReleaseOpportunisticEnemyPoolsAndBundles` |
| `DevilHunterIdle.AssistantSystem.ResourceManager` | 3046 / 16,569,840 | `_cache`, `_bundleCacheKeys`; `LoadAsync`, `SpawnAsync`, `Despawn`, `TryGetCached`, `Co_LoadAsync`, `Co_SpawnAsync`, `ReleaseBundle` |
| `DevilHunterIdle.AssistantSystem.AddressablesLoader` | 2962 / 16,562,448 | `_handlesByCacheKey`, `_locationCache`, `_locationCacheLru`, `_locationCacheLruNodes`; `Co_InstantiateAsync`, `TryAcquireExistingHandle`, `TryAcquireExistingResult`, `GetAssetRefCount`, `ReleaseBundle`, `EvictOldestLocationCacheEntry` |
| `Supercent.Util.PoolBase<T>` (``PoolBase`1``) | 8364 / 17,037,824 | `Limit`, `actives`, `inactives`, `<Capacity>k__BackingField`; `Prepare`, `TrimExcess`, `Resize`, `Get`, `Return`, `ReturnAll` |

클래스와 선언 목록은 부모가 먼저 식별한 뒤 이번 조사에서 타입별 field/method 범위를 직접 읽어 대조했다. `ResourceManager`는 `System.Resources`와 `UnityEngine.ResourceManagement`에도 있으므로 게임의 namespace를 생략하면 안 된다. 선언 이름은 풀·캐시·참조·해제 인터페이스의 존재를 증명한다. 실제 호출 순서, 초기화 생략 조건, 풀의 상한 값, 객체 재사용 시 상태 초기화, LRU 정책의 본문, 비동기 처리의 실제 실행 방식은 이 메타데이터만으로 확정하지 않는다. `lib/arm64-v8a/libil2cpp.so`의 존재와 크기 90,037,632 bytes는 확인했으나 이번 문서에서 함수 본문을 디컴파일하거나 실행하지 않았다.

리니지M과 대응할 수 있는 근거는 다음 범위다.

| 출처·범위 | 확인된 사실 | 적용할 원칙과 한계 |
|---|---|---|
| Android 1.10.18a 정적 보고서, `0x5544460` | 경로 해석 후 texture cache hit이면 새 디코드·업로드 전에 기존 텍스처 반환 | 정확한 원본 identity와 픽셀 정책으로 재사용한다. 실제 cache hit율·지연 감소는 별도 측정이다. |
| 같은 보고서, `0x554494c` → `0x55143f8`; `0x55448b0` | 참조 수 1인 미사용 항목 제거와 전체 cache clear가 분리됨 | 활성 owner와 idle cache의 수명을 구분한다. C++ refcount 숫자를 Godot lease에 그대로 이식하지 않는다. |
| 같은 보고서, `0x5543594` → `0x554389c` → `0x5543c44` | 비동기 요청·읽기 worker·완료 처리, 완료 시 cache 재확인과 임시 객체 정리 | 같은 결과의 중복 생성을 줄일 설계 근거다. XP Hero 메타데이터만으로 동일 호출 흐름을 확인한 것은 아니다. |
| Windows 기원524·데이터525 분석을 요약한 시작메모리 인계서 | 필요한 파일·방향 요청, raw/decoded/외부 owner 분리, 공유 블록·CPU surface 재사용; RawSpriteFile 64MiB에는 최소 한 항목·외부 owner 예외 | 지연 생성·불변 데이터 공유·명확한 반환을 참고한다. 64MiB는 전체 RAM 상한이나 Android 목표가 아니다. |

Android 보고서의 SP2 경로 `0x326e144` → 읽기/Brotli `0x2813d78` → wrapper `0x326b3d0` → parser `0x4dba628`도 정적 근거다. 이것은 TWILIGHT의 CRC32 구현, warm parse의 Brotli 생략, raw/body 조기 해제를 원작에서 확인했다는 근거가 아니다. XP Hero 메타데이터에서도 리니지M의 SP2·RGB565·팔레트 처리 방식은 확인하지 않았다.

이번 후속 작업의 구분은 다음과 같다. 모두 **TWILIGHT 자체 구현·검증 대상**이며 위 원본들의 코드를 복사하거나 동작을 완전히 복원한 결과로 표현하지 않는다.

- **CRC32 계산 개선:** 기준 main `reference_sp2_bank.gd`의 바이트별 CRC와 `_read_verified` 원본 검증 경로가 대상이다. 계산 비용을 줄이되 동일 CRC32 값, 모든 입력 바이트, 잘못된 원본 거부, SHA/receipt 도메인을 보존해야 한다. 원작의 CRC 함수 주소나 알고리즘을 이번에 확인한 것은 아니다.
- **하위 작업 계측:** 원본 읽기·검증·parse·pixel render·texture 생성과 spawn setup을 나눠 병목을 확인한다. 기존 `frame_hitch` detail은 `[operation,total_ms,calls,max_ms]`인 inclusive 시간이고 counters는 프레임 단위다. detail을 부모 detail이나 sections와 합산하면 안 된다. 계측 추가 자체는 속도 개선의 증거가 아니다.
- **선택적 bank probe:** 같은 원본 bank를 불필요하게 미리 여는 작업을 줄인 자체 개선이다. 필수 admission·identity·제외 규칙과 실제 사용 시 검증을 유지해야 한다. XP Hero의 `TrySkipInitWhenCommonPoolHealthy`라는 선언만으로 TWILIGHT의 생략 조건이 옳다고 판단하지 않는다.
- **퀵슬롯 snapshot 중복 제거:** 한 번의 동기 화면 refresh/stage 안에서 같은 detached snapshot을 공유하는 자체 개선이다. 클릭·행 식별 검증은 최신 상태를 다시 읽고, 순서·페이지·수량·쿨다운·자동 사용 상태와 원본 노드 연결을 보존해야 한다. 원본 Android QuickSlot 주기나 XP Hero의 UI 구현을 이식한 변경이 아니다.

인수 증거에는 CRC oracle·손상 거부, 필수 검증 유지, snapshot/클릭 상태 변경 회귀, 세이브 보존, cold/warm cache와 첫 spawn/재사용 spawn을 구분한 결과가 필요하다. Linux 합성 벤치는 Android 기기 성능과 구분한다. 기기·APK·원본 팩·세이브 복사본을 고정한 실기기 로그가 없으면 첫 로딩·긴 프레임·메모리 개선 수치를 확정하지 않는다. 거래소·캐릭터 생성·종료 문제는 이번 비교의 검증 범위에 포함하지 않는다.

출처: `LineageM_Android_클라이언트_기능과_TWILIGHT_개선검토_20261110.docx` (Library `libfile_c83fde99d69c8191a370aef6129b0025`, file `file_000000009ff881f6b31e562ddf80e489`, 144–161행 및 473–495행); `TWILIGHT_Android_시작메모리_구현인계서_20261110.docx` (Library `libfile_45fe8ab423f08191a6f1013f1bedcdee`, file `file_00000000d7b481f7a2d20f84d03006b9`, 129–136행 및 194–200행). 두 보고서의 당시 TWILIGHT 코드 진단은 현재 main에 그대로 적용하지 않았다. 이전 raw 분석 ZIP 전송 시도는 HTTP 401로 끝났지만, 이번에 명시된 별도 분석 ZIP은 아래와 같이 이 환경에서 직접 읽었다. 이를 모든 원본 바이너리의 접근·재추출 성공으로 확장하지 않는다. 비공개 바이너리·원본 아트·복호 키는 이 문서나 공개 저장소에 포함하지 않는다.

추가 직접 확인: `TWILIGHT_Faithful_Implementation_Analysis_KO_20261110.zip`(Library `libfile_d4bf4a4e1ec881919bdba0a043ca45e8`)을 지원 materialize 경로로 현재 환경에 확보했다. 실제 파일은 17,524,852 bytes, SHA256 `ee7fe088f39fd3d317631c66bddf4d436d55d08046081e267f934c4e3802716c`, ZIP 5,603 entries, CRC 오류 없음이다. 다른 환경의 경로를 공유한다고 가정하지 않았다.

Astra가 P10 `SPRITE_CACHE_LIFETIME_REPORT_KO.md`, `FUNCTION_INDEX.json`, 선택 asm을 직접 읽었다. 보고서가 고정한 복원 Windows EXE는 97,366,016 bytes, SHA256 `9f9c3b9c9a49fb598899b3da308b4776cbbc47cbb98dbe4b4aa368cce519019d`이며 EXE/DLL 기원은 524다. 이번 확인은 ZIP 안의 정적 추적 자료 대조이며 그 EXE를 다시 추출·실행한 것이 아니다.

- Raw hit `01C74B9E–01C74C06`은 LRU 연결 이동·strong 참조 증가 뒤 반환으로 가며 reader/parser를 우회한다.
- lazy `01C71706–01C7171D`는 graphics 존재·음수 방향 인덱스·failed 상태면 반환한다. graphics가 있으면 raw 재획득도 없다.
- `lineagem_s32_world_sections_20261109/consumers/CONSUMERS_KO.md` 13행은 `01CC2220`/`01CC1F10` 분할 queue, 56–59행은 `01CBCF50` shared ref 해제·placement pool 반환·`+4A` 중복 recycle guard의 보고서 근거다. 이 S32 부분은 이번에 asm까지 별도 대조하지 않았다. placement는 pooled draw entry이며 gameplay monster spawn과 동일한 객체가 아니다.

| 직접 읽은 P10 증거 | SHA256 |
|---|---|
| `SPRITE_CACHE_LIFETIME_REPORT_KO.md` | `7c8ce9f68f7018e80b332ad09e176096b23ab1f6e65585372fae3ec33286fff6` |
| `FUNCTION_INDEX.json` | `03fc94fb5c85503eec05db8b3b3cc24e2f35c1ed3c67da68ad99d17f94f0fc65` |
| `EXE_01C74AB0.asm.txt` | `b1c2c735f5a6891f052bec72dcbf1a67ac47d852ccc4b59a06a9b3793cea2189` |
| `EXE_01C716E0.asm.txt` | `e260e00bcf7c99a966c99acc869da4d1b783183c33242ac25b82b78ecefc4a1f` |

Astra는 선택 asm의 명령 바이트와 인덱스 해시도 대조했다. 이것은 ZIP 내부 증거의 정합성 확인이며 원본 EXE에서 재추출한 검증이 아니다. 이 근거를 Android gameplay spawn 예산, 전체 캐시의 thread safety 또는 이번 코드의 성능·메모리 실측으로 해석하지 않는다. 이후 11/11 사용자의 changed-file 재검증 결정과 현재 main 계약이 이전 보고서의 무결성 정책 제안보다 우선한다. ZIP과 보고서·asm 원문은 공개 저장소에 복사하지 않는다.
