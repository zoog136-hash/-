# 지도 오브젝트의 같은 시각 반복 계산 감소

기준 main은 `9958eca199d70d41f1a1757ccc422bdd3e7b7fc5`다. #458의 tile 출처 memo와 독립된 변경이다.

`current523_bank_objects._process_step`은 모든 배치가 같은 `_clock`과 sprite ID별 record를 쓰면서도 배치마다 `_frame_index`에서 duration 배열을 처음부터 순회했다. 한 갱신 안에서 ID별 결과를 공유해 같은 시각/트랙을 반복 순회하지 않도록 했다. `_show`는 이전 순서대로 모든 해당 배치에 호출한다. 메모는 매 갱신 새로 만들어지며 이전 프레임이나 교체된 record를 보유하지 않는다. static/unresolved/missing 제외, 음수 delta clamp, looping, zero-duration 및 presentation-duration 선택은 기존 함수를 그대로 사용한다.

텍스처·레이어·노드 생성·스타일·화질·게임 상태는 변경하지 않는다. 이것은 기존에 공유하던 지도 장식의 시계에 한정하며, 몬스터 개별 playback state를 공유하는 변경이 아니다. 원본/XP Hero의 공유 리소스 조사와 구분되는 자체 구현이다.

새 bounded hitch counter는 갱신당 방문 배치 수/시간선 계산 수와 실제 표시 프레임 변경/레이어 노드 생성 수를 기록한다. 아직 남은 `_show`의 노드 재생성과 refresh 시 전체 배치 재구성 비용을 다음 기기 기록에서 구분하기 위한 것이다. CPU section `map_objects`를 그대로 유지하며 GPU 시간으로 해석하지 않는다.

Godot 4.7.2 합성 회귀: 1,024개 배치(움직이는 768개, static/invalid/missing 포함)에서 기존 loop와 새 loop의 출력 순서/프레임/clock을 경계·음수 delta·여러 loop·record 교체 후 비교했다. 33개 기본 검사가 통과했고 시간선 계산은 768회에서 2회로 감소했다. 별도 benchmark 옵션의 5회 출력 검증까지 포함하면 38개다. 기존 bank objects 검사 2개는 원본 팩 없는 거부 경로이며 실제 원본 그림 검증이 아니다. 기존 frame hitch 26개, Python staging 14개, 추적 리소스 20개 검사도 통과했다.

합성 microbenchmark는 원본 대신 64-frame duration 배열과 `_show`를 결과 수집으로 바꾼 probe를 쓴다. 120갱신 × 5표본 중앙값은 기존 loop 911,861µs, 공유 loop 75,066µs였다. 호출 수 계측과 결과 배열 작성도 포함된다. 실제 렌더링·Android·원본 데이터·전체 FPS 또는 메모리 절감 실측이 아니며 속도 임계값을 CI에 넣지 않는다. 재현: `godot --headless --path <prepared-project> --script res://tests/current523_bank_object_timing_test.gd -- --benchmark`.

전체 Main/저장 회귀의 최종 상태는 PR CI를 확인한다. 기존 규칙의 `check_resource_integrity.py`는 main에서 없어서 현행 리소스 검사로 추적 파일을 검증했다. Android 실제 효과와 노드 재생성 비용은 아직 확인해야 한다.
