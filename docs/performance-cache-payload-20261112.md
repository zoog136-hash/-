# 파싱 캐시 비용과 UI·퀘스트 임시 작업량

비교 기준은 PR #419의 검증된 구현 `4c78a97a7218728c324ce0788112f3f3502e2b0f`다. 원본 데이터·decoder·parse cache 형식·renderer·카드 수·화질·저장 형식은 변경하지 않는다. Android 기기와 해당 APK는 이 환경에 없으므로 종료 원인이나 기기 성능 개선 완료를 뜻하지 않는다.

## 원본 분석 자료의 사용 범위

Library에서 `TWILIGHT_Android_시작메모리_구현인계서_20261110.docx`와 기존 `LineageM_Android_클라이언트_기능과_TWILIGHT_개선검토_20261110.docx`의 본문을 읽었다. 전자는 이전 main을 대상으로 작성된 인계서여서 현재 코드 진단을 그대로 재사용하지 않고 독립적으로 확인했다.

* Windows 기원524/데이터525의 정적 수명 분석 요약은 raw·decoded·외부 owner를 분리하고 공유 블록을 재사용한다. RawSpriteFile의 64MiB는 특정 byte vector 캐시 기준이며 최소 한 항목과 외부 소유권 예외가 있다. 이를 Godot 전체 RAM 상한이나 Android 목표로 옮기지 않았다.
* Android 1.10.18a 보고서의 `0x5544460`은 hit에서 재디코딩 전에 반환하고, `0x554494c`는 미사용 항목만 제거하며 `0x55448b0`의 전체 release와 구분된다. `0x5544dfc`의 bpp×크기 통계도 전체 프로세스 메모리가 아니다. 이 소유권·비용 구분을 아래 캐시 회계와 대조했다. C++ refcount 숫자를 Godot에 복제하지 않았다.
* `TWILIGHT_memory_worker_handoff_20261109.zip`, `TWILIGHT_클라이언트_01-123_소스구현참조_20261109.zip`, `Android_native_recovery_verified_20261110.zip` 등 원문 후보의 Library 존재는 확인했다. 이번 실행에서는 지원 전송의 인증 오류(HTTP401)로 ZIP 내부 bytes를 읽지 못했고 native ZIP read에도 본문이 없었다. **이번에 raw ASM/복호화 소스를 재검증했다고 주장하지 않는다.** 원본 C++ 개발 소스나 원본 실행 성능 측정으로 표현하지 않는다.

Quest의 원본 whole-file/seek 방식과 ListView의 실제 보이는 행 재활용은 이번 자료 접근으로 입증하지 못했다. 아래 Quest 읽기·UI 복사 개선은 현재 TWILIGHT의 동작을 보존한 자체 최적화다. 원본 목록 구현을 추정해 가상화하거나 콘텐츠를 줄이지 않았다.

## SP2의 누락된 packed 비용

기존 shared parse 비용은 `raw + body`만 셌고, bank의 로컬 32MiB working set은 `body`만 셌다. 실제 파싱은 palette, frame raw_bounds, block commands/runs/indices를 별도 packed 배열로 만든다.

새 `sp2_parsed_payload.gd`는 현재 decoder 형식에 맞춰 이 배열의 논리 바이트를 합산한다. FE의 raw/body COW 공유는 한 번, Brotli의 별도 압축 입력과 풀린 body는 각각 센다. 파싱 결과에 필드를 넣거나 저장 형식을 바꾸지 않는다. 게시 때 한 번 측정하고, shared entry의 기존 `entry_bytes()`와 bank의 정수 sidecar를 재사용한다. warm hit는 전체 파싱 트리를 다시 순회하지 않는다. 모든 drop/release/reconfigure/predelete 경로에서 sidecar도 정리한다.

기존 32MiB와 3멤버 정책을 같은 비용으로 적용한다. lease가 있는 live entry와 외부 owner를 강제로 없애지 않고, 현재 요청한 단일 oversize 멤버는 기존처럼 사용할 수 있다. idle store만 예산에 맞춰 회수한다. 이 산정은 **packed 논리 payload 하한**이며 Dictionary/Array/Variant, 여유 capacity·allocator, GPU/RSS/PSS를 포함한 전체 메모리 상한이 아니다.

합성 FE(8groups×200frames×31rows) 한 개는 이전 1,666,155B에서 packed 하한 4,222,379B로 정확하게 산정된다. 9개의 이전 idle 재현은 표시상 14,995,395B라 퇴출하지 않았지만 packed 하한은 38,001,411B였다. 새 실제 bank 회귀는 **7개 유지·2개 퇴출**을 확인한다. 비용 순회 20표본 중앙값은 Linux 730µs이고 첫 게시 때만 실행한다. 직렬화로 재는 방식은 같은 탐색 fixture에서 임시 6,809,560B와 약 26.4ms를 만들어 채택하지 않았다.

## 버릴 UI 하위 트리의 깊은 복사 제거

`source_node_scope.select/_prune`는 선택된 node를 만들고도 전체 원본 nodeTree와 각 retained ancestor의 모든 후손을 deep copy한 뒤 즉시 교체했다. 이제 shallow 사본에서 교체할 자리를 먼저 비우고 나머지 메타데이터만 deep copy한다. 선택된 후손은 이미 독립적으로 만든 결과를 연결한다.

필드 순서, offset/ancestor/track 순서, 메타데이터의 독립성, 기존 Resource identity 의미, 오류 코드는 유지한다. 원본 입력을 바꾸지 않고 기존 결과 전체의 encoded bytes와 비교한다. published 합성 20회 평균은 156노드 **0.8384→0.2244ms**, 781노드 **4.83445→1.12805ms**였다. 최종 결과의 Godot 할당량은 양쪽이 같다. 실제 CSB/원본 UI 지연이나 GPU 측정이 아니다.

## 카테고리 조회의 전체 Quest 파일 버퍼 생략

#419의 분류 선필터 뒤에도 `source.begin_bulk()`는 전체 record 파일을 복사했다. category 조회는 이미 열린 검증된 `RecordFile.read/get_var()`로 필요한 행만 읽는다. 전체 `entries()`는 기존 bulk 경로를 유지한다. 새로운 byte cap이나 async 동작을 도입하지 않는다. 행·보상·순서·일일 상태·저장 처리는 그대로이며, caller가 열어둔 outer bulk는 category 조회가 소유하거나 닫지 않는다.

published 합성 3,621행/분류906행의 round2 관측이다. 실행 순서를 교차하고 입력·출력 digest와 실제 RecordFile 호출을 확인했다. 속도 임계값은 없다.

| 전체 record 파일 | sampled Godot static peak 이전→이후 | CPU 관측 이전→이후 |
| --- | --- | --- |
| 8,849,200B | 71.121→62.270MB | 68.569→44.540ms |
| 11,630,128B | 76.675→65.042MB | 49.888→51.730ms |
| 22,753,840B | 98.829→76.073MB | 63.505→57.112ms |

메모리 관측에서는 전체 bulk 크기만큼의 추가 버퍼가 사라졌다. CPU는 한 경우 약 1.84ms 늘어나는 등 변동하며, 모든 조건에서 빨라졌다고 주장하지 않는다. RSS는 allocator 때문에 높게 남을 수 있다. 906개의 논리 record 요청량은 전체 파일 읽기와 구분하며 실제 저장장치 IO 바이트로 해석하지 않는다. 전체 API의 bulk와 최종 반환906행 자체의 메모리는 남는다.

## 결과·키·저장 보존 검증

* 새 SP2 회귀 79조건: 독립 recursive packed oracle, FE와 실제 합성 Brotli 입력, 실제 bank·idle eviction, active/external 픽셀 유지, warm hit 재측정0, local budget/oversize, sidecar 정리, 기존 v1 cache payload·키·파일·픽셀 보존.
* UI scope 26조건: 전체 encoded 결과·입력·nested metadata·packed 값·track/field 순서·Resource 의미·오류 동등성. 기존 Change Window53/Quest Preparation38도 통과했다.
* Quest 읽기32/기존 category64조건: 실제 검증된 RecordFile·읽기 횟수·독립 행·nested 보상·순서·outer bulk·불완전 buffer fallback·custom provider·저장 bytes/state 보존. 이전 category 테스트의 내부 bulk 호출 기대 한 곳만 새 정책 0/0으로 바꿨고 모델 검사는 유지했다.
* 이전419 프로세스가 쓴 SP2 cache를 새 프로세스에서 hit1/miss0/write0으로 읽었다. 파싱 전체 typed 값과 canonical JSON SHA가 같다. decoder key, Quest producer code key, UI pack metadata key도 같다. 이는 source-mode 비교이며 이전 Android `.gdc`와 실제 private pack의 재사용 검증은 아니다. 일반 global projection 키는 기존 정책대로 무효화될 수 있다.

decoder, parse cache, renderer, source_pack, manifest index, SourceQuest/BAKE/producer 파일을 바꾸지 않았다. 원본 멤버·SHA/CRC/receipt·제외 규칙을 우회하지 않는다. 입력·출력과 데이터 수명만 확인해 카드150개와 퀘스트60행 등 기존 화면 범위를 줄이지 않았다.

전체 core·OpenGL 및 원격 CI의 최종 상태는 PR 설명에 기록한다. 문서에 남은 과거 `check_resource_integrity.py`는 기준 소스에 없어 exit2이며 통과로 세지 않는다. 현행 `check_no_legacy_resources.py`는 tracked=20으로 통과한다. 실제 원본팩·단말 검증 및 APK 배포 완료를 뜻하지 않는다.

## 재현·남은 비용

`tools/benchmarks/benchmark_sp2_parsed_payload.gd`, `benchmark_original_ui_node_scope.gd`, `benchmark_quest_category_record_reads.gd`를 제공한다. 비교 benchmark는 실제419의 baseline 스크립트 경로가 필요하며 없으면 명시적으로 실패한다. 격리 XDG와 합성 사용자 폴더만 사용하고 시간 임계값으로 통과 여부를 결정하지 않는다. [구조화 증거](performance-cache-payload-20261112-evidence.json)에 fixture·로그 SHA·관측을 기록한다.

cold SP2 parse/pixel upload, 최초 manifest JSON/bake, 전체 Quest 조회의 bulk, 150개 카드의 동기 scene 생성은 남는다. 캐시 회계 수정은 최초 parse를 async로 바꾸거나 모든 live 메모리를 제한하지 않는다. 이전 사진의 단일 몬스터 배치12.432초나 APK 종료가 모두 해소됐다는 주장은 하지 않는다. 실제 단말에서는 같은 APK/data로 cold/warm·메뉴 왕복과 `MENU_MEMORY`/frame hitch/Android 종료 사유를 함께 수집해야 한다.
