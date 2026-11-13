# Android 화면 복사와 프레임 잔여 시간 진단

기준 main은 `1c0d61f49690adb7f722e410071f86d4754f4414`다. #452의 source bank/view 준비 최적화와 독립된 브랜치이며, 지도·몬스터 배치·지역 이동·퀘스트 구현을 변경하지 않는다.

## 사진의 수치와 확인 범위

사용자의 523.430 화면은 지난 실행의 끊김 2,067회, 최악 프레임 4,264ms와 `그리기·엔진 3510ms`, `지도 그리기 574ms`, `캐릭터 135ms`를 표시한다. `sp2.pixel_render 5ms×8`, `sp2.texture_create 2ms×8`은 각각 8회 호출의 **합계** 5ms와 2ms다. 현재 로딩 시간이나 GPU 완료 시간은 아니다. 이전 setup 13.944초 사진과 실행이 다르므로 인과관계나 개선량으로 비교하지 않는다.

`other`는 두 probe 사이의 실제 경과 시간에서 등록된 section 합계를 뺀 값이다. 미계측 스크립트·CPU 그리기 제출·엔진/드라이버 대기·OS 스케줄링·기록 작업이 들어갈 수 있다. `map_renderer`는 renderer의 `_process_step`만 측정하며 `_draw_tiles`와 그 안의 사용 장부 기록은 별도 호출이다. 따라서 사진만으로 3510ms의 원인을 특정하지 않는다.

## 사용하지 않는 화면 복사 제거

기존 Android fixed shader는 화면 destination을 읽지 않지만 sprite/particle/panel의 BackBufferCopy는 계속 활성화될 수 있었다. 해당 factory에서 만든 **실제 활성 shader**가 화면을 읽지 않는 경우에만 복사를 끈다. 전역 Android 설정만 보고 판단하지 않는다.

- Shader의 개별 identity와 생성 시 표시를 확인한다. shader 변경 신호는 표시를 무효화한다. 알 수 없는 shader, 깊은 복제, 부모 material 상속은 보수적으로 복사를 유지한다.
- SourceMaterial의 일반 material 복제는 같은 shader를 사용하므로 동작을 유지한다. 뒤늦은 material 교체도 draw 직전에 확인한다.
- 화면을 읽는 기존 exact 경로, sprite의 검증된 copy rect, node 순서·개수, particle 수·시뮬레이션, texture와 shader의 픽셀 코드는 그대로다. particle 검사는 emitter당 하나의 draw callback으로 묶는다.
- 이 변경은 기존 Android fixed 표현의 불필요한 작업을 제거한다. 해당 표현이 원본 클라이언트와 완전히 같다는 새로운 주장은 아니다.

합성 Compatibility/llvmpipe 장면에서 fixed 경로의 활성 copy가 4개에서 0개로 줄었으며, 기존 강제 복사 경로와 RGBA 전체 바이트를 120회 비교해 모두 같았다. exact 경로는 4개, 알 수 없는 shader로 바꾼 경우는 필요한 copy를 유지한다. 이 장면의 개수를 실제 게임의 copy 수, 3510ms의 원인, Android 시간·메모리 절감량으로 전용하지 않는다.

## 프레임 구간 진단

화면의 `other` 표기를 `미계측 잔여`로 바꾼다. 100ms의 원래 wall-clock 기준, section과 중첩 detail 계산은 유지한다. 이전 schema 1 기록도 읽을 수 있다.

Probe는 RenderingServer의 pre/post draw callback 시각과 횟수를 고정 크기로 기록한다. main-thread probe에서 `is_on_render_thread()`로 실제 동기 render server 여부를 확인한다. 같은 probe 창 안의 순서가 맞는 단일 pre/post 쌍이며 동기 server일 때만 전/사이/후 wall 구간을 표시한다. 콜백 없음·누락·중복·역순·별도 render thread는 상태와 원시 표식만 남긴다. 별도 thread의 지연된 post 전달을 같은 draw의 완료로 해석하지 않는다.

이 값은 **GPU 시간이 아니다**. Godot의 pre callback 이전에도 SceneTree/deferred 그리기와 render 동기화가 실행될 수 있다. 두 callback 사이에는 다른 listener, CPU 제출과 swap 대기가 포함될 수 있다. 근거: [RenderingServer 신호 문서](https://docs.godotengine.org/en/latest/classes/class_renderingserver.html#signals), [사용 엔진의 RenderingServerDefault 구현](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/servers/rendering/rendering_server_default.cpp).

Probe의 기록·출력·자동 flush 비용은 다음 probe 구간에 별도 scalar로 남긴다. 외부 pause/focus flush도 기록하되 자동 flush와 이중 합산하지 않는다. 이를 section에 더하거나 raw hitch 시간에서 빼지 않는다. 강제 GPU 동기화, texture readback, 매 프레임 scene tree 순회는 추가하지 않는다.

## 검증과 남은 작업

`tests/source_ui_copy_policy_test.gd`는 활성 shader 교체, mutable/deep 복제, 상속, shader 변경, visibility와 callback 해제를 검증한다. `tests/source_ui_copy_policy_gl_test.gd`는 15 blend pair와 투명/불투명 viewport, fixed/exact 전환 및 알 수 없는 shader를 비교한다. GL 검사를 기존 PR pixel workflow에 추가했다. `tests/frame_hitch_draw_phases_test.gd`는 결정적 시간 입력과 실제 probe lifecycle로 경계·상태·기록 보존을 검증한다. 기존 frame-hitch 및 spawn-setup 검사도 유지한다.

로컬 Godot 4.7.2 검증: 새 copy 정책 88개, 새 프레임 진단 147개, 기존 Android blend 53개, frame-hitch 26개, spawn trace 12개, letterbox 6개 통과. GL 비교는 540개 검사/120개 전체 픽셀 비교를 통과했다. 새 두 headless suite를 core gate에 등록하여 기준 브랜치의 총 181개 suite에 포함했다. 규칙의 `tools/check_resource_integrity.py`는 현재 main에 없으며 현행 `check_no_legacy_resources.py --root .`의 추적 리소스 20개를 검증했다.

최종 check 수와 CI 상태는 해당 PR head의 검사 결과를 따른다. 원본 리소스·저장·시뮬레이션 충실도는 변경하지 않는다. 실제 기기의 UI copy 개수, frame/driver 비용, 맵 지연과 지역 이동 문제는 이 합성 검증으로 해결됐다고 판단할 수 없다. 지도 쪽에서는 draw 중 tile identity 반복 조회, 사용 장부의 동기 JSON 저장, 오브젝트 재구성·프레임별 노드 생성이 추가 계측 대상이며 다른 담당의 변경과 분리한다.
