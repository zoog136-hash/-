# 원본 Sprite framebuffer 복사 범위 — 2026-11-12

`source_sprite_back_buffer.gd`는 기존 Sprite 앞의 BackBufferCopy와 수동 GL
blend shader를 유지하고, 검증한 Compatibility 엔진에서만 복사 영역을
Sprite의 화면 AABB로 제한한다. 그림·해상도·표본·노드 개수·그리는 순서는
줄이지 않는다. 공통 viewport backbuffer의 **할당 크기는 그대로**다.

## 공식 엔진 근거와 제한

검증한 엔진은 Godot **4.7.2 official**,
`ed1daf0bf001b61586d9930840f2f1394092c079`이다. 다음은 해당 공식 소스의
함수와 검토 시 줄 위치다.

| 근거 | 관찰 |
| --- | --- |
| [GLES3 canvas renderer, 413–420](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_canvas_gles3.cpp#L413) | 영역 copy에 `copy_back_buffer->rect`를 직접 사용한다. |
| [canvas culler, 193–194](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_canvas_cull.cpp#L193) | 별도로 transformed `screen_rect`를 계산한다. Compatibility의 직접 rect 사용과 구분해야 한다. |
| [CanvasItem, 1660–1668](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/main/canvas_item.cpp#L1660) | `get_viewport_transform()`에는 viewport 최종 변환과 canvas/CanvasLayer 변환이 포함된다. |
| [TextureStorage, 3657–3687](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/storage/texture_storage.cpp#L3657) | render target의 backbuffer를 필요할 때 한 번 생성하고 요청 영역을 복사한다. Sprite마다 full viewport texture를 새로 할당하는 구조가 아니다. |
| [GLES3 blend state, 791–798](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/gles3/rasterizer_canvas_gles3.cpp#L791) | native PMALPHA는 비투명 target에서 목적지 alpha를 보존한다. 기존 수동 GL factor 계산의 일반적인 대체가 아니다. |

따라서 helper는 위 엔진 hash와 `gl_compatibility`를 모두 확인한다. 다른
엔진/renderer, physics interpolation, CanvasGroup/clip-children group,
유효하지 않은 변환에는 기존 전체 복사를 사용한다. 엔진이 rect 처리를
수정하면 현재 화면 좌표 보정이 중복 변환될 수 있으므로 guard를 임의로
넓히지 않는다.

화면 영역은 `(sprite.get_viewport_transform() * sprite.get_global_transform())
* sprite.get_rect()`의 AABB를 floor/ceil하고 화면 1픽셀 여유를 준다.
그리기 직전 `frame_pre_draw`에서 계산하여 첫 프레임, 카메라/스크롤/부모
변환, viewport stretch, texture 크기 변경을 반영한다. null/숨겨진 Sprite는
복사를 끄고 복구되면 다시 계산한다. copy 노드마다 WeakRef 하나와 수명에
맞춰 연결/해제하는 callback 하나만 사용하며 전역 등록부는 없다.

기존 build·BlendFunc·FileData·owner texture 교체의 material 선택은 그대로다.
추가 검사에서 드러난 optional `source_asset_scene` 메타데이터 접근 두 곳은
`has_meta()`로 보호했다. 누락을 정상 null로 처리하며 오류를 숨기지 않는다.

## GL 동등성 검사

[original_ui_sprite_copy_region_test.gd](../tests/original_ui_sprite_copy_region_test.gd)는
실제 `SpriteScene.configure()`를 사용하고, 대조군의 helper를 기존 전체-copy
노드로 교체한다. Godot 4.7.2 Compatibility + Mesa llvmpipe에서 **6,495 검사 /
1,080 전체 RGBA 비교 / 실패 0 / runtime ERROR 0**을 확인했다.

15종 blend, 투명/비투명 target, source PMA, 분수 위치, 회전/스큐,
음수·비균일 scale, clip, flip, z order, CanvasLayer, camera에 해당하는
canvas transform, viewport stretch, 부분/전체 화면 밖 위치, 실제
BlendFunc/FileData timeline, owner 교체·거절·null·복구, guard와 callback
수명을 검사한다. 앞선 독립 합성 matrix 3,120 비교도 RGBA 바이트가 같았다.
이는 원본팩 시각 승인이나 Android GPU 검증이 아니다. 해당 검사는
headless/dummy renderer에서 exit 2로 거부한다.

```bash
godot --path . --script res://tests/original_ui_sprite_copy_region_test.gd
```

## 선택적 성능 관찰

[benchmark_original_ui_sprite_copy.gd](../tools/benchmarks/benchmark_original_ui_sprite_copy.gd)는
실제 생산 helper callback을 포함한 150 Sprite·640×480 합성 장면을
full/rect/rect/full 순서로 측정한다. 각 행은 warm-up 10회 후 24회 median이다.
전체-copy 기준도 비활성 helper callback을 유지하므로 그 비용을 명시한다.
측정 임계값은 CI 성공 조건으로 사용하지 않는다.

| 합성 Linux llvmpipe 관찰 | 전체 copy | guarded rect |
| --- | --- | --- |
| 화면 안 frame wall median | 79.09–83.89ms | 26.68–28.69ms |
| 화면 안 viewport CPU query median | 80.00–81.03ms | 23.31–24.92ms |
| 화면 안 viewport GPU query median | 79.78–80.82ms | 23.02–24.72ms |
| 화면 안 callback 총 median | 0.297–0.328ms | 0.842–0.885ms |
| 전체 화면 밖 frame wall median | 23.66–24.34ms | 3.38–4.72ms |

각 결과의 RGBA는 동일했다. GPU query는 **소프트웨어 llvmpipe driver 값**이며
물리 Android GPU 성능이 아니다. query는 비동기일 수 있으므로 CPU/GPU/wall
시간을 서로 더하지 않는다. 복사 대역폭 감소 관찰을 여러 메뉴 종료 원인
확정이나 viewport buffer 메모리 감소로 표현하지 않는다.

```bash
godot --path . --script res://tools/benchmarks/benchmark_original_ui_sprite_copy.gd \
  -- --output=/tmp/sprite-copy-benchmark.json
```

출력 경로를 생략하면 stdout으로만 결과를 출력한다. 원본팩·실기기 검증과
최종 SHA의 필수 CI 결과는 이 문서의 합성 관찰과 별도로 기록해야 한다.
