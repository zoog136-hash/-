# 지도 오브젝트의 같은 시각 반복 계산 감소

기준 main은 `9958eca199d70d41f1a1757ccc422bdd3e7b7fc5`다. #458의 tile 출처 memo와 독립된 변경이다.

`current523_bank_objects._process_step`은 모든 배치가 같은 `_clock`과 sprite ID별 record를 쓰면서도 배치마다 `_frame_index`에서 duration 배열을 처음부터 순회했다. 한 갱신 안에서 ID별 결과를 공유해 같은 시각/트랙을 반복 순회하지 않도록 했다. `_show`는 이전 순서대로 모든 해당 배치에 호출한다. 메모는 매 갱신 새로 만들어지며 이전 프레임이나 교체된 record를 보유하지 않는다. static/unresolved/missing 제외, 음수 delta clamp, looping, zero-duration 및 presentation-duration 선택은 기존 함수를 그대로 사용한다.

텍스처·레이어·노드 생성·스타일·화질·게임 상태는 변경하지 않는다. 이것은 기존에 공유하던 지도 장식의 시계에 한정하며, 몬스터 개별 playback state를 공유하는 변경이 아니다. 원본/XP Hero의 공유 리소스 조사와 구분되는 자체 구현이다.

새 bounded hitch counter는 갱신당 방문 배치 수/시간선 계산 수와 실제 표시 프레임 변경/레이어 노드 생성 수를 기록한다. 아직 남은 `_show`의 노드 재생성과 refresh 시 전체 배치 재구성 비용을 다음 기기 기록에서 구분하기 위한 것이다. CPU section `map_objects`를 그대로 유지하며 GPU 시간으로 해석하지 않는다.

Godot 4.7.2 합성 회귀: 1,024개 배치(움직이는 768개, static/invalid/missing 포함)에서 기존 loop와 새 loop의 출력 순서/프레임/clock을 경계·음수 delta·여러 loop·record 교체 후 비교했다. 33개 기본 검사가 통과했고 시간선 계산은 768회에서 2회로 감소했다. 별도 benchmark 옵션의 5회 출력 검증까지 포함하면 38개다. 기존 bank objects 검사 2개는 원본 팩 없는 거부 경로이며 실제 원본 그림 검증이 아니다. 기존 frame hitch 26개, Python staging 14개, 추적 리소스 20개 검사도 통과했다.

합성 microbenchmark는 원본 대신 64-frame duration 배열과 `_show`를 결과 수집으로 바꾼 probe를 쓴다. 120갱신 × 5표본 중앙값은 기존 loop 911,861µs, 공유 loop 75,066µs였다. 호출 수 계측과 결과 배열 작성도 포함된다. 실제 렌더링·Android·원본 데이터·전체 FPS 또는 메모리 절감 실측이 아니며 속도 임계값을 CI에 넣지 않는다. 재현: `godot --headless --path <prepared-project> --script res://tests/current523_bank_object_timing_test.gd -- --benchmark`.

전체 Main/저장 회귀의 최종 상태는 PR CI를 확인한다. 기존 규칙의 `check_resource_integrity.py`는 main에서 없어서 현행 리소스 검사로 추적 파일을 검증했다. Android 실제 효과와 노드 재생성 비용은 아직 확인해야 한다.

## 반복 노드 생성과 UI uniform 갱신

지도 `_show`는 표시 프레임마다 모든 Sprite2D/material을 버리고 다시 만들었다. 이제 placement가 자신의 현재 유효 레이어 수만큼 노드를 재사용하고 texture/position/z/modulate/material을 갱신한다. 줄어든 레이어는 즉시 부모에서 떼고 deferred free하며, mix로 돌아오면 불필요한 material을 해제한다. 보이지 않는 high-water pool이나 공유 playback 노드는 추가하지 않는다. 레이어 순서·그림자 z·null/실패/숨김 정책과 `_texture` 경로는 그대로다.

Godot4.7.2에서 새 레이어 검사 122개, 실제 Compatibility/llvmpipe 158개 검사(36개 전체 RGBA 비교)를 통과했다. 20개 실제 엔진 갱신 경계를 거친 합성 fixture에서 새 Sprite2D identity는 60→3, material identity는 20→1이었다. 이는 할당 개수이며 Android 시간·전체 RAM 절감 수치가 아니다.

원본 UI의 `bind_display`는 private material을 만든 뒤 매번 같은 bound/color 값을 다시 설정했다. 이제 실제 현재 parameter를 조회해 같을 때만 setter를 생략한다. 별도 color memo를 만들지 않아 외부 값 변경과 material/shader 교체를 계속 반영한다. 하위 노드 순회·색 계산·shader 픽셀 코드는 바꾸지 않는다. 근거는 사용 엔진의 [ShaderMaterial setter/getter](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/scene/resources/material.cpp#L390)와 [GLES3 material_set_param](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/storage/material_storage.cpp#L2339)이다. 동일 scalar/color setter도 uniform dirty 작업을 예약하므로 실제 중복 작업을 줄인다. 전체 UI 시간 또는 기기 지연의 원인이라고 단정하지 않는다.

UI uniform 회귀는 headless 27개와 GL 51개(24개 전체 RGBA 비교)가 통과했다. 공유 prototype/인스턴스 격리, PMA·투명 viewport, 동일 값 반복, 색 변경, 외부 parameter 변경, material/shader 교체를 기존 무조건 setter 경로와 비교했다. 새 레이어·UI 픽셀 검사는 기존 SP2 pixel workflow에 추가한다.

## 긴 미계측 공백의 구분

현재 로딩 화면 버전과 이전 실행 기록의 빌드가 다를 수 있어, 저장된 최악 프레임의 build를 우선 표시한다. 저장된 draw callback이 없거나 여러 번/다른 스레드/순서 불일치로 구간 해석이 불가능한 경우도 짧게 표시한다. 이를 GPU 시간이나 원인으로 추측하지 않는다.

Probe와 같은 process group에서 가장 늦은 priority의 자식 callback 표식을 추가했다. 같은 probe 창 안의 유효한 단일 표식일 때 전/후 wall 구간을 기록하고, 기존 동기 pre-draw 표식과 순서가 맞을 때만 추가 구간을 기록한다. 다른 thread group·physics·deferred 작업·모든 노드의 완료를 보장하는 표식은 아니다. 이 구간도 기존 section/callback 구간과 겹치므로 합산하지 않는다.

앱 pause/resume/focus-out/focus-in은 네 개 고정 카운터와 첫/마지막 timestamp 및 관찰된 상태로 기록한다. 알림이 없는 상태는 미상이며 플랫폼 정지 시간을 추정하거나 원래 hitch 시간에서 제외하지 않는다. 기록 순간의 static allocation bytes/node/object count도 남기되 peak·GPU 메모리·GC 시간으로 해석하지 않는다. 강제 GPU 동기화나 매 프레임 트리 순회는 추가하지 않았다. 205개 진단 검사, 기존 hitch 26개와 spawn trace 12개를 검증했다.

실제 523.435 로딩 사진의 이전 실행 최대 10,971ms 중 미계측 잔여 10,626ms는 원인이 확인되지 않았다. 이전 기록 build와 callback/lifecycle 상태가 사진에 없어 현재 APK의 동일 실행 또는 특정 CPU/GPU/GC 비용이라고 단정할 수 없다. 현재 변경의 합성 결과를 그 10초의 해결 또는 실제 기기 개선량으로 전용하지 않는다.

## UI 타임라인 중복 해석 제거

`sprite_scene._seek_frame`는 같은 live frame 목록을 두 번 union decode하여 이전/다음 키프레임을 찾았다. 한 번 순회하면서 두 후보를 고른다. 이전 후보의 동점은 마지막 항목, 다음 후보의 동점은 첫 항목이라는 기존 규칙과 unordered index를 보존한다. 영구 캐시·정렬·리소스 변경 없이 매 호출의 live 데이터를 읽으므로 런타임 데이터 교체도 그대로 반영된다. tween/easing/이벤트/중첩 clip/색 전파는 변경하지 않는다.

실제 seek_frame과 옛 두-pass 블록을 복원한 test-only script를 196개 사례에서 비교했고 1,773개 검사가 통과했다. unordered/duplicate/fractional/negative 경계, 입력 변경, 누락 tag/action 및 거부 계약을 포함한다. 두 트랙×64프레임 fixture에서 선택 가능한 이전 키가 있으면 union decoder 호출이 256→128이며, 첫 키 이전에는 두 경로 모두 128회다. 원본 파일/기기 프레임 시간이 아닌 합성 호출 수다. 기록 순간 메모리 값은 빌드의 모니터 제공 여부에도 영향을 받으므로 미지원 값을 RAM 0 또는 peak로 해석하지 않는다.
