# 퀘스트·메뉴 지연과 이미지 보유 개선

기준 main: `b488fb367ac5dcf359861294581e32abeeb26c82`. PR #417 병합 `5f3af92043a44a9152495d044cf11febe3386c51`과 이후 장비 변경을 포함한다. 사용자가 APK에서 퀘스트를 누르다 종료된다고 알려 이번에는 메뉴 종료 문제도 조사했다. 거래소·캐릭터 생성·원본 리소스·저장 형식은 변경하지 않았다.

**실제 Android 종료 원인은 아직 확인하지 못했다.** 기기·해당 APK·logcat/종료 사유 없이 OOM, native crash, ANR 중 하나로 확정하지 않는다. 아래 관측은 코드 경로와 합성 Linux 재현이며, 사용자 화면의 이전 실행 12.432초 몬스터 배치 프레임을 다시 측정한 결과가 아니다.

## 확인한 비용과 변경

* 퀘스트 진입은 기존 `QuestUI.configure()`로 전체 목록을 준비한 뒤 원본 창이 다시 목록을 준비했다. 원본 창을 먼저 시도하고 성공할 때 기존 브라우저를 만들지 않는다. 원본 창 실패·미설치 때 기존 브라우저를 유지한다.
* `QuestService.entries_for_category()`는 기존 `entries()`와 같은 독립적인 상세 행을 반환하되, resident category를 먼저 확인한다. 다른 분류의 원본 행 읽기·gate·보상 계획 생성을 생략한다. 기존 전체 API와 보상 지급·일일 경계·세이브 동작은 유지한다. 원본 record 파일 전체 bulk 버퍼는 이번에 바꾸지 않았다.
* 동일 퀘스트 재선택은 재구축하지 않는다. 한 프레임의 선택·보상 후 시각 갱신은 한 번으로 합치고 마지막 선택·스크롤을 보존한다. 보상 콜백은 즉시 기존 경로로 실행한다. 닫기·다시 열기·분류 전환은 이전 deferred 갱신을 무효화한다.
* HUD가 오래 보유하는 `SourcePack._textures`는 무제한 strong Dictionary였다. 기존 `Source523TextureCache`를 재사용해 **pack별 32MiB decoded payload reserve/4096 metadata**와 weak 재사용으로 바꿨다. 활성 Sprite/글꼴의 외부 참조는 유지한다. bitmap font descriptor에 page texture를 저장하던 별도 우회 보유도 제거했다.
* 원본 메뉴를 닫으면 pack CPU 페이지 lease를 반환한다. 기존 48MiB 예산은 **idle 페이지에만** 적용되어, 종전의 닫힌 메뉴 페이지는 계속 live로 남아 예산을 초과할 수 있었다. 다른 활성 창의 텍스처는 그대로 유효하고 이후 decode는 페이지를 재취득한다.
* controller/HUD의 닫힌 메뉴 결과는 원본 텍스처를 포함할 수 있었다. 정상 종료와 unsupported inventory fallback 모두에서 presentation snapshot을 해제하고 HUD에는 단순 상태·사유만 남긴다. 인벤토리·선택·아이템·저장 데이터는 수정하지 않는다.

32MiB와 48MiB는 서로 다른 캐시의 payload 예산이며 **프로세스 전체 메모리, GPU 또는 RSS 상한이 아니다**. 활성 창·외부 texture 소유·글꼴·임시 decode·allocator는 따로 존재한다. 같은 메뉴 반복은 기존에도 안정적이었으며, 모든 닫기가 끝없는 누수를 만든다고 주장하지 않는다. 확인한 것은 새 메뉴 자산의 누적 보유와 같은 프레임의 교체 scene 피크다.

## 원본 합성 결과를 유지한 화면 복사 범위

원본 Sprite마다 선행 `BackBufferCopy`가 화면 전체를 복사했다. 기존 수동 Cocos blend shader와 순서를 유지하면서, 검증된 엔진에서는 화면 좌표의 Sprite AABB에 1픽셀 여유를 둔 영역만 복사한다. texture 교체·타임라인·카메라·CanvasLayer·화면 배율·스크롤 변경은 `frame_pre_draw`에서 반영한다. weak Sprite 참조와 tree-exit disconnect로 수명을 제한한다.

이 구현은 **공식 Godot 4.7.2 hash `ed1daf0bf001b61586d9930840f2f1394092c079` + Compatibility**에서만 활성화한다. 다른 엔진/렌더러, physics interpolation, CanvasGroup/clip-children 그룹, 비정상 변환은 기존 전체 복사로 돌아간다. Godot 4.7.2 GLES가 로컬 `rect`를 직접 소비하는 특성 때문에 viewport 변환을 포함한 좌표를 제공한다. 엔진 guard를 넓히려면 GL 차분 검사를 다시 해야 한다.

native premultiplied blend로 바꾸는 방안은 기각했다. Compatibility의 opaque target alpha 처리와 혼합 factor 순서에서 픽셀이 달랐다. 수동 shader 산술·모든 15개 factor pair·투명도 순서를 보존한다. 원본 owner API 실험에서 드러난 optional `source_asset_scene` metadata 두 곳의 누락 접근도 명시적으로 검사하게 고쳤다.

이는 render target의 공유 backbuffer 할당 크기를 줄이는 변경이 아니다. 복사 면적·트래픽을 줄인다. Sprite마다 별도의 전체 화면 버퍼가 할당된다는 주장은 하지 않는다.

Godot 일차 근거: [GLES copy/blend](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_canvas_gles3.cpp), [canvas culling](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_canvas_cull.cpp), [viewport transform](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/canvas_item.cpp), [공유 backbuffer](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/storage/texture_storage.cpp).

## 재현 관측

합성 PNG/quest만 사용했다. Linux CPU·Godot 할당·llvmpipe 결과이며 실제 Android의 FPS·종료율·전체 RSS 개선율을 뜻하지 않는다. 속도 기준을 테스트 통과 조건으로 사용하지 않았다.

| 작업 | 이전 | 변경 후 |
| --- | --- | --- |
| 32개 고유 1024×512 RGBA 이미지를 보고 모두 닫은 pack의 live CPU pages | 64MiB / lease 32개 | 0 / lease 0개 |
| 같은 시점 pack frame strong reserve | 32개, 상한 없음 | 16개, 32MiB |
| 같은 실행 idle CPU pages | 0 | 48MiB |
| 합성 3621행 상세화·gate·reward plan / 선택 분류 | 3621회 | 906회 |
| 같은 quest 작업 warm 관측 | 159.647ms | 45.824ms |
| 같은 quest 행 상주 Godot allocation 증가 | 약 83.80MB | 약 20.95MB |
| 실제 SpriteScene, 합성 Sprite 150개, frame wall median 범위 | 79.09–83.89ms | 26.68–28.69ms |

메뉴 메모리 실험은 서로 분리된 최소 프로젝트/프로필로 동일 픽셀과 pack 검증을 실행했다. 이전/이후 각각 179조건을 통과했다. 메뉴 노드는 해제되고, 같은 첫 8개 자산 5회 재열기는 양쪽 모두 안정적이었다. 관측 RSS는 이전 71,920→137,708KiB, 변경 후 72,372→123,840KiB였다. allocator high-water가 남으므로 캐시 payload 수치를 RSS 절감으로 더하거나 일반화하지 않는다. headless texture monitor 0은 GPU 메모리 0의 증거가 아니다.

quest 실험의 전체 bulk 파일 버퍼 8,863,968B는 양쪽에 남는다. 전체 행을 해제하면 Godot allocation은 기준 근처로 돌아왔지만 Linux RSS는 allocator 때문에 높게 남았다.

렌더 실험은 640×480, full/rect/rect/full 순서, warmup 10프레임·각 24표본이다. 변경 후 모든 helper callback 합계는 약 0.84–0.89ms/프레임이었다. 비교 baseline에도 비활성 helper callback 약 0.31ms가 포함된다. software OpenGL query의 CPU/GPU 시간은 wall time과 합산하지 않는다. 실제 GPU/Android 검증은 남아 있다.

재현 스크립트: `tools/benchmarks/benchmark_original_ui_menu_retention.gd`, `benchmark_quest_category_entries.gd`, `benchmark_original_ui_sprite_copy.gd`. 메모리 이전 재현은 기준 main의 SourcePack과 `--close-hook=none`, 이후는 새 pack과 `--close-hook=release`를 사용한다. 자세한 입력·관측 및 원본 로그 SHA는 [구조화 증거](performance-menu-memory-20261112-evidence.json)에 기록한다.

## 검사와 한계

* 새 core 검사: menu retirement 12조건, quest routing/coalescing/fallback 38조건, category API 64조건, pack/두 창/bitmap font/TTF/cache lifetime 210조건, embedded particle reserve 14조건, trace 27조건.
* 실제 Main 저장·재불러오기/누락 원본팩 거부 33조건 통과. 원본팩이 없어 실제 맵 이동·원본 퀘스트 UI 및 사용자 APK를 재현한 검사는 아니다.
* 실제 Compatibility/Mesa llvmpipe GL: **6495조건·1080개 전체 RGBA 비교**, 실패·runtime error 0. 15개 blend pair, opaque/transparent, 변환·clip·flip·z-sort·CanvasLayer·viewport stretch·화면 밖, FileData/BlendFunc 타임라인, owner 교체/거부/null/복구, guard·수명을 확인했다. headless는 이 검사를 통과 처리하지 않고 exit 2로 거부한다.
* Python core runner 10개·현행 resource checker 자체 2개 통과. `check_no_legacy_resources.py --root .`는 tracked=20으로 통과. 문서에 남은 과거 `check_resource_integrity.py`는 기준 main에 없어 exit 2이며 통과로 집계하지 않는다. `.agents/skills`는 이 체크아웃에 없다.
* 초기 테스트의 Variant 추론, 잘못된 PanelContainer fixture, 명시 map-pack 환경 변수 누락은 실패로 기록하고 fixture/호출을 고친 뒤 재실행했다. 오류가 있는 marker-only 결과를 통과로 사용하지 않았다.

전체 필수 core 및 원격 CI의 최종 결과는 PR에 기록한다. historical 전체 기능·원본 시각 검사를 실행하지 않은 상태는 통과가 아니다.

SourcePack 코드가 바뀌므로 기존 정책대로 **UI metadata bake key가 바뀌고 첫 실행은 다시 bake**할 수 있다. 약 250MB metadata의 최초 parse/split, cold SP2 parse·pixel decode/upload, action track 확장, 많은 카드의 최초 scene 구축 및 source record bulk 버퍼는 남는다. 이번 변경을 위해 integrity key를 고정하거나 낮추지 않았다. 이전 단계가 원본 decoder/SP2 parse key를 보존한 사실과 이번 UI bake 무효화를 구분한다.

원본 Android 1.10.18a ARM64 정적 보고서의 캐시 hit 재사용 `0x5544460`, 미사용 캐시 회수 `0x554494c`/전체 release `0x55448b0`, 읽기·파싱·소유권 분리와 비교했다. Godot에서 C++ refcount==1을 복제하지 않았다. 이번 bounded reserve·페이지 lease·quest category projection·복사 범위·trace는 TWILIGHT 자체 개선이며, 원본 개발 소스/원본 실행 성능 실측이 아니다.

## APK 재현 시 수집

새 코드가 포함된 APK에서 퀘스트 열기→분류 전환→연속 선택→보상→닫기와 가방/변신 왕복을 확인한다. Git 병합만으로 설치된 APK/OTA가 갱신됐다고 간주하지 않고 실제 실행 revision을 확인한다. 이번 PR은 새 APK나 원본팩의 배포를 의미하지 않는다.

`user://menu_memory_trace.json`과 다음 실행의 `menu_memory_trace.prev.json`은 최근 24이벤트/최대 32KiB만 보존한다. Quest 전체 handler, 원본 가방/변신/상점/캐릭터 handler의 begin/end와 OS pause/focus/close 알림 때 메모리를 기록한다. per-frame 디스크 쓰기는 없다. 지원하지 않는 값은 -1이며 static/RSS/render payload를 구분한다. 저장 실패는 메뉴 진행을 막지 않고 더 쓰지 않는다. 이 이벤트 기록에도 소량의 동기 IO 비용은 있다.

logcat의 `MENU_MEMORY`, Godot 오류, Android `ActivityManager`/`lmkd`/native tombstone/ANR 시각을 함께 비교해야 한다. 미완료 `menu_begin`은 마지막 저장 이벤트일 뿐 크래시·OOM 확정이 아니다. 진단에는 퀘스트 ID·인벤토리·세이브·텍스처 내용을 넣지 않는다. 렌더 API elapsed는 GPU 완료 fence가 아니며 trace의 handler elapsed는 자체 begin/end 기록 IO를 제외한다.
