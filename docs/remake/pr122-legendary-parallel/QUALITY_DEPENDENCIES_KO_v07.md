# 신규 부모 증거에 따른 의존 작업

이 helper는 이미 승인된 제작 범위 안에서 중복 호출과 잘못된 부모 참조를 막는 내부 실행 조건이다. 사용자에게 새 승인을 요구하지 않는다.

`prepare_quality_dependencies_v07.py`는 원래 미호출 106개의 역사 목록을 보존한다. 현재 별도 producer가 담당하는 최초 READY71은 이 의존 큐에서 전부 제외한다. qc063/qc098은 frozen 원문이 중간 네 자세를 정상으로 명시한 guard-only 대상이므로 이미지 호출이 영구 0이다. qc110의 중간 자세는 정상으로 추론하지 않는다. 245 NW/NE와 338 N의 이미 시도한/HOLD 부모 세 건은 재호출하지 않는다.

`quality-v03/dependency-evidence-v07.json`은 실제 active 부모 record/TRES/registration, 카메라·외형·살아있는 대기 guard0/5 시각 근거, 최소 Godot 6프레임 PASS와 REMOTE_SAVED 영수증의 정확 SHA를 연결한다. 부모 증거가 부족한 행은 독립 WAIT로 남긴다. 기존 정상 guard 두 자세와 부모의 원래 texture canvas/anchor/scale를 보존하고 부족한 중간 네 자세만 요청한다. 새 가상 캔버스 중심으로 guard를 다시 등록하지 않는다.

실행 전 root는 마지막 71개 결과와 신규 부모 근거를 확인해 새 버전 plan을 준비한다. 기존 plan/request/receipt는 수정하지 않는다. producer `generate_correction_once_v04.js`를 `qualityGenerateOnceV04`에 로드하고 `correction_generation_queue_v06.js`에 새 plan 경로를 전달한다. 기본 동시 실행 수는 5이고 최대 20이다. 실제 이미지 요청은 root만 실행한다. request 실제 stem 및 모든 이전 버전 receipt/claim과 canonical once lock으로 중복을 막는다. 지원하지 않는 reasoning 옵션과 별도 유료 API는 없다.

현재 준비된 plan-v07의 309/310은 부모가 정확히 검증된 10행이며 모두 guard2 + 신규4 구조다. 추가 부모가 통과하면 새 plan 버전과 아직 미호출인 행만 준비한다. 여기서 최초71의 성공이나 카메라 HOLD를 다시 호출하지 않는다. 이미지 없는 qc063의 재결속 선택은 별도 `guard-only-ready-qc063-v07.json`이다. 최종 승인 및 전체 corpus audit은 별도 최종 gate 전까지 0이다.
