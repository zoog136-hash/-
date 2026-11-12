# Android 준비 비용 후속 조사 — 2026-11-12

기준은 PR #414 병합 후 main
`11df08720afdb988884ad1c2b316d937fb7dc64d`이며 작업 브랜치는
`feature/android-preparation-costs-20261112`이다. 앞선 끊김 표시의 해석과
실기기 절차는 [긴 프레임 조사와 재검증](performance-20261112.md)을 따른다.
여기서는 속성 검증·PNG 업로드 픽셀 준비·SP2 프레임 픽셀 생성의 CPU 비용을
다룬다. Android 실제 단말 및 비공개 원본팩의 실행 결과는 아직 없다.

검사·벤치마크의 입력 범위와 결과는
[기계 판독 증거](performance-preparation-20261112-evidence.json)에 보존했다.
최종 commit과 원격 CI 상태는 이 후속 draft PR의 head·checks를 확인한다.

## 적용 범위와 보존 계약

### action별 원본 속성 검증

[reference_sp2_bank.gd](../scripts/resources/reference_sp2_bank.gd)의
`_attributes()`는 같은 action의 frame·direction마다 동일한 원문 선언을
반복 검증했다. 새 `_load_action_attributes()`는 **각 action JSON을 읽을 때
만드는 로컬 memo**에서 `kind:sprite`별로 한 번 검증한다. 다음 action이나
다음 `load_bank()`로 memo를 넘기지 않는다.

반환값은 매번 `duplicate(true)`로 복사한다. 변환된 한 layer의 속성이나
선언 배열을 바꾸어도 다른 frame·action·원본 record를 바꾸지 않아야 한다.
속성의 순서·중복·`unresolved` 표시, 거절 이유, frame별 layer identity·주소·
reference binding 검사 및 기존 `client_null` 분기 위치를 유지한다.
이것은 원문 검증의 중복을 줄이는 TWILIGHT 구현이며 원본 클라이언트 API를
복원했다는 주장이 아니다.

### owner PNG의 Cocos PMA 준비

PNG consumer의 기존 Cocos 산술은 RGB 각 바이트에
`(channel * (alpha + 1)) >> 8`을 적용하고 alpha 바이트는 보존한다.
새 `cocos_premultiply_pixels.gd` helper는 R/B lane을 분리한 packed 정수
연산과 little-endian RGBA 쓰기로 같은 결과를 만든다.

최종 연결은 [source_asset_pixels.gd](../scripts/ui/original_ui/source_asset_pixels.gd)의
owner PNG 소비 경로와 [source_asset_pma_cache.gd](../scripts/ui/original_ui/source_asset_pma_cache.gd)의
파생 texture 재사용에 한정한다. 원본 Image를 복사한 뒤 필요 시 압축 해제·RGBA8
변환을 하므로 원본 texture의 저장 픽셀을 수정하지 않는다.

PMA 파생 캐시는 정확한 source ImageTexture의 weak identity, `changed`
세대, 타입과 float 비트까지 구분한 evidence, 변환 정책으로 재사용을 구분한다.
source 변경 후 옛 파생물을 새 요청에 돌려주지 않고, 파생 texture가 외부에서
변경돼도 재사용하지 않는다. 이전 파생물의 늦은 변경 신호가 같은 key의 새
texture를 지우지 않도록 현재 객체를 확인한다. 지원하지 않는 texture 구현이나
evidence는 기존 변환 경로로 진행한다.

이 캐시는 상한이 있는 strong/weak 소유권을 사용하며 이미지 owner의 파일·
출처 검증 뒤에 호출된다. cache hit이 owner 검증을 생략할 권한은 아니다.
decoded payload 추정량을 GPU 상주량·RSS·PSS로 보고하지 않는다.

[source_pack.gd](../scripts/ui/original_ui/source_pack.gd)는 기준 바이트를
유지한다. 기존 `Pack.cocos_premultiply()`와 atlas/page 변환은 그대로 사용한다.
따라서 **원본 atlas page의 최초 PMA 변환 비용은 남는다.** source pack의
약 250MB scene/layout metadata bake key를 억지로 고정하거나 예전 key로
우회하지 않고 생산 코드 바이트 보존으로 기존 key 조건을 유지한다.

Godot `Image.premultiply_alpha()`로 단순 교체하지 않는다. 합성 65,536픽셀
channel/alpha sweep에서 기존 Cocos 식과 94,848개 출력 바이트가 달랐다.
이 관찰은 해당 native 함수를 이 Cocos 호환 경로의 대체로 쓰지 않는 근거다.

### reference-bank SP2 픽셀 생성

새 [current523_sp2_frame_renderer.gd](../scripts/resources/current523_sp2_frame_renderer.gd)는
기존 decoder의 parse·geometry·placement 함수를 사용하면서 표본마다 RGBA
네 바이트를 따로 쓰던 부분을 packed RGBA 한 번 쓰기로 바꾼다.
`bit_replication`·`linear` RGB 정책과 `opaque_samples`·`index0_transparent`
alpha 정책을 모두 유지한다. 원문 reference 순서, 겹치는 표본의 덮어쓰기,
index0, 빈 frame, 음수 offset, canvas 경계와 오류 결과도 기존 renderer와
비교한다. `estimated` 표시는 그대로이며 native alpha·blend 의미를 새로
확정하지 않는다.

적용 지점은 reference bank의 `pixels=true` 경로다. identity pack·world
preview·static SPR·SP2 viewer 등 기존 `DECODER.render()` 호출 경로 전체를
교체하는 변경은 아니다.

## 캐시 키 범위

| 대상 | 이번 변경의 계약 |
| --- | --- |
| SP2 decoder 파일 | SHA-256 `b74a11f54e9e15e22d5671b67aca001c53f4fd399f183183822e0e70dec54f96`로 기준과 바이트 동일하다. |
| decoder-only code key | `f50e24f1aeb7c44b9eb6dd477952bc8e7054902090677a3b34057fb50c8d51ef`를 유지한다. |
| 기기 SP2 parse cache | `sp2_parse_cache.gd`와 decoder 바이트를 유지한다. 같은 원본 identity·크기·포맷·엔진 조건이면 기존 parse key를 유지한다. |
| 공유 parsed payload | 기존 manifest, SHA 또는 CRC/receipt/path domain과 decoder version 조건을 유지한다. |
| 공유 rendered texture | compositor version과 별도 renderer code hash를 포함한다. 렌더러가 바뀌면 새 texture key를 사용한다. |
| UI pack metadata bake | `source_pack.gd` 바이트와 manifest 등 기존 입력 조건을 유지한다. key 우회·캐시 migration은 추가하지 않는다. |
| global projection bake | `global_code_key()`는 `scripts`와 `data`의 모든 파일을 포함한다. 이번 신규·수정 script 때문에 일반 정책대로 무효화될 수 있다. |

그러므로 보존 범위는 **decoder 기반 SP2 parse key와 바이트를 유지한 UI pack
metadata key 조건**이다. 모든 bake나 모든 최초 준비 비용이 보존·제거됐다고
표현하지 않는다.

## 합성 Linux CPU 측정과 남은 비용

다음 값은 작업 중 얻은 **합성 입력의 Linux CPU 관찰값**이다. 원본팩·실제
Main·GPU 완료·Android frame time 측정이 아니다. 실행 순서·호출 수와
producer 범위가 다른 행을 더해 게임 전체 절감 시간으로 계산하지 않는다.
아래는 실제 생산 helper·consumer의 재현 벤치 결과다. 각 policy와 반복별 원시 시간은 evidence에 있다.

| 측정 범위 | 이전 → 변경 | 조건·한계 |
| --- | --- | --- |
| action 속성 검증, 64 tokens | 6,400회 → 15회; median 271.826 → 182.908ms | 5 actions·8 directions·3 layers, 5회 순서 교대. 원문 검증·출력 deep-copy를 포함한 warm `load_bank()` CPU 범위다. |
| action 속성 준비, 128 tokens | median 624.814 → 429.318ms | 같은 합성 bank, 호출 수 12,800→15회. |
| PMA 산술, 64×64 / 256×256 RGBA8 | 0.793→0.490ms / 12.968→7.627ms | unchanged Pack와 새 helper, 크기별 20회. 원본 PNG decode·업로드는 제외한다. |
| PMA 산술, 1024×1024 RGBA8 | 221.487 → 134.218ms | 크기별 6회. 단독 산술 비교이며 다음 consumer 비교와 실행·부가 비용이 다르다. |
| owner PNG consumer, 1024×1024 최초 | 236.198 → 130.527ms | 고정 원본 image에서 최초 소비 4회, cache clear는 측정 밖. **첫 변환 자체는 여전히 약 131ms**다. owner 파일 IO는 제외한다. |
| 같은 PNG/evidence의 반복 consumer | 0.040ms, 50회 추가 변환 0 | 같은 source 객체·세대·evidence 조건의 재사용. owner 파일 IO를 제외한 CPU/API 값이다. |
| strict owner 검증 + 반복 consumer, 1024×1024 | 14.751ms | 매번 파일·SHA 확인을 포함한 별도 관측이다. 검증 비용은 제거하지 않았다. |
| SP2 renderer, 961픽셀·800회 | 215.798 → 111.734ms | opaque/bit-replication 정책의 5회 중앙값. 800장 합계이며 한 frame 시간이 아니다. 나머지 3정책도 evidence에 있다. |
| SP2 renderer, 31×255픽셀·200회 | 231.865 → 117.820ms | 같은 정책의 200회 합계. CPU 픽셀 생성이며 texture upload는 제외한다. |

추가 탐색에서 4MB 합성 manifest의 cold 준비는 448.8ms, 기존 disk index
재사용은 45.1ms, 같은 프로세스 재사용은 0.016ms였다. 이 결과는 처음
index를 만드는 비용이 남는다는 뜻이다. 단순 prebake로 그 일을 게임 진입에서
로딩 화면으로 옮기는 것은 전체 준비량의 제거가 아니며 이번 변경에 포함하지 않았다.

150-card/6-node 합성 scene 구성 probe는 생성 노드 4,050개에서 94–109ms였다.
원본 선택 창의 full refresh 비용은 아직 남아 있다. 이 수치를 실제 카드팩의
scene 수나 실기기 창 열기 시간으로 해석하지 않는다.

## 정확성 검사와 재검증

관련 검사는 합성 입력으로 구현의 동등성을 확인한다. 테스트 코드가 있다는
사실과 최종 SHA에서 PASS했다는 결과를 구분하고 실행 결과를 아래에 기록한다.

- [reference_sp2_attribute_memo_test.gd](../tests/reference_sp2_attribute_memo_test.gd):
  action별 memo 분리, 순서·중복·unresolved·provenance·거절 이유, 출력의
  독립적인 깊은 복사를 이전 경로와 비교한다.
- [original_ui_premultiply_exact_test.gd](../tests/original_ui_premultiply_exact_test.gd):
  모든 channel/alpha 조합, 고정 seed 임의 RGBA8, 합성 PNG decode 입력에서
  Cocos scalar 식과 모든 바이트·alpha·입력 불변을 비교한다.
- [current523_sp2_frame_renderer_test.gd](../tests/current523_sp2_frame_renderer_test.gd):
  RGB565 전 범위와 네 RGB/alpha 조합, 희소 방향·빈 frame·음수 배치·중첩
  덮어쓰기·오류 결과·입력 불변 및 parse/texture key 범위를 비교한다.
- [benchmark_reference_sp2_attributes.gd](../tests/benchmark_reference_sp2_attributes.gd)와
  [benchmark_original_ui_premultiply.gd](../tests/benchmark_original_ui_premultiply.gd)는
  재현용 관찰 도구다. 속도 임계값을 CI 통과 조건으로 만들지 않는다.

Android 재검증은 [기존 절차](performance-20261112.md#android-실제-단말-재검증-절차)의
동일팩·동일 세이브 복사본·cold/warm·정지·이동·가방·변신 구간을 그대로 사용한다.
이번에는 최초 큰 PNG 준비와 반복 PNG 재사용, 최초 SP2 texture 생성과 공유
texture hit, action 속성 검증을 구분해 본다. 새 `sp2.attribute_validate`
counter, `sp2.pixel_render`·`sp2.texture_create` detail 및
`sp2.texture_created` counter를 기존 per-frame 기록과 함께 수집한다.
`sp2.texture_create`는 API 호출 경과 시간이며 GPU 완료 fence가 아니다.
포함 시간인 detail을 서로 또는 section에 더하지 않는다.

## 원본 정적 분석의 경계

앞 문서의 Android 1.10.18a 보고서 4쪽은 texture 재사용 `0x5544460`,
미사용 정리 `0x554494c`, 전체 clear `0x55448b0`, 완료 시 cache를 재확인하는
`0x5543594 → 0x554389c → 0x5543c44`를 구분한다. 6–8쪽의 SP2 관찰도
파일 읽기·구조 파싱·픽셀 해석·상위 caller의 의미를 구분한다.

이 정적 근거는 수명과 단계를 비교할 자료다. 이번 packed 산술, action memo,
파생 PMA cache는 TWILIGHT의 자체 최적화이며 원본에서 같은 알고리즘이나
같은 성능을 확인한 결과가 아니다. Windows 코드524·데이터525 계약과
Windows523 리소스 호환, Android1.10.18a 관찰도 버전별로 유지한다.

## 검증 결과와 한계

사전 `python3 tools/check_resource_integrity.py --root .`는 이 기준 main에
도구가 없어 exit 2였다. 현재 workflow의 `check_no_legacy_resources.py`와
그 자체 회귀 2개는 통과했다. 예전 검사 실패를 PASS로 바꾸거나 assertion을 낮추지 않았다.
비공개 원본팩·Android 기기는 없으며 content·화질·저장 형식·게임플레이 값,
거래소·캐릭터 생성·종료 문제는 이번 변경 범위가 아니다.

| 확인 | 결과·실제 범위 |
| --- | --- |
| SP2 frame renderer | 2,775조건 PASS. 모든 RGB565·네 정책·희소/빈/겹친 frame·음수·bounds·오류·read-only 입력을 원 renderer와 비교 |
| action 속성 memo | 85조건 PASS. 6,400→15회, action/proof 분리·deep-copy·순서·중복·null/unresolved·거부 이유·변조 검출 |
| PMA 산술 / 파생 cache | 36조건·1,250,265픽셀 및 cache 52조건 PASS. 원본 byte/format·provenance·weak/budget·변경 신호·수명·검증 거부 |
| 기존 관련 회귀 | 새 회귀 포함 focused 8/8와 pixel 5/5, 실제 Main/UI/shared-resource 5/5 PASS. 일부 검사 중복이며 합산 검사 수로 보고하지 않는다. |
| 정상 OpenGL 부팅 | 60 frame 실행 exit 0, script/resource 오류 없음. 원본팩 부재의 안전 경로이며 게임 원본 픽셀 검증 아님 |
| 실제 Main 저장·누락팩 | 33조건 PASS. 격리 XDG profile, 진행·장비·컬렉션 저장/재불러오기 및 누락팩 안전 경로. 실제 원본팩 지도 통행 검증 아님 |
| Compatibility 실제 readback | Xvfb/Mesa llvmpipe/OpenGL 4.5에서 합성 texture 10조건 PASS. source/derived update·set_image 후 모든 RGBA byte 확인. Android GPU 또는 원본 UI 검사 아님 |
| 기존 cache의 별도 프로세스 재사용 | source-mode old producer→new consumer에서 hit=1/miss=0/write=0, parse 전체 값·decoder/code key·UI metadata key 동일 |
| 파일 보존 | decoder, parse-cache 및 source-pack 파일은 base와 바이트 동일. 실제 이전 Android export의 `.gdc` 파일을 별도 비교한 결과는 아님 |
| Python·현재 리소스 검사 | compile, core runner Python 10개, 리소스 검사 및 자체 2개 PASS |
| 필수 core CI | 새 정확성 회귀 4개 등록. 총 112개를 등록한 최종 head의 전체 실행 결과는 PR checks에 기록하며 실행 중을 PASS로 표기하지 않는다. |
| 원본팩 / Android | NOT_RUN. 원본팩 Main·실기기 시각·APK·cold/warm frame·입력 latency 미수집 |

`sp2.attribute_validate`는 한 action에서 실제 `_attributes()`를 검증한 횟수다.
`sp2.pixel_render`·`sp2.texture_create`는 포함 시간이며 서로 또는 상위 section에
더하지 않는다. texture create는 API 시간이지 GPU 완료 시간은 아니다. PMA cache의
`conversions`는 성공적으로 등록한 파생 변환 수이며 bypass 변환 전체를 뜻하지 않는다.
32MiB는 strong decoded payload 예산이며 외부 scene 소유·metadata·GPU/RSS 전체 상한은 아니다.

기존 SP2 parse 및 UI metadata key를 보존해도 최초 대형 PNG·atlas page 변환,
manifest split/bake, action 트랙 확장과 150-card scene 생성은 남는다.
합성 CPU 절감치를 사진의 12.432초에서 빼거나 실기기 해결률로 환산하지 않는다.
