# 지도 그리기 출처 조회와 CPU 비용 계측

기준 main `9958eca199d70d41f1a1757ccc422bdd3e7b7fc5`는 #452와 #457의 병합을 포함한다.

지도 타일 draw는 서로 다른 subimage마다 `source_usage_identity(tile_id)`를 호출했다. baked tile pack의 해당 경로는 `_row`의 파일 seek/get_var까지 도달할 수 있다. 이번 변경은 한 draw의 관찰 목록에서 tile ID별로 한 번만 출처를 읽는다. 기존 subimage 관찰 순서와 단위, 빈 출처 거부, actual Main 조건과 장부 검증은 유지한다. 메모는 호출이 끝나면 해제되며 팩 교체나 다음 draw의 변경 검증을 건너뛰는 전역 캐시가 아니다. 그리기 명령, 텍스처, 화질, 시뮬레이션과 저장 데이터는 변경하지 않는다.

합성 검사에서 3개 tile ID × 256개 subimage의 출처 조회가 768회 대신 3회다. 유효한 두 tile의 관찰 512개와 순서를 유지하며 빈 출처, 다음 draw의 identity 변경, 팩 교체, 빈 입력을 검증한다. 실제 기기 시간·메모리 절감 수치가 아니다.

기존 `map_renderer` section은 `_process_step`만 감쌌다. 이제 타일과 정적 오브젝트 `_draw`의 CPU 경과 시간을 각각 `map_floor_draw`, `map_object_draw`로 기록한다. 출처 조회/장부 관찰은 `map.floor_usage`, 장부 최초 읽기와 동기 JSON/파일 쓰기는 `map.usage_load`, `map.usage_write` detail로 구분한다. detail은 section에 포함되므로 합산하지 않는다. 이 계측은 GPU 완료 시간을 측정하지 않는다. 장부의 원자 저장, 실패 처리, 1초 dirty gate와 종료 flush는 그대로 유지한다. 타일 identity 조회 수와 관찰 ref 수는 해당 프레임의 bounded counter로 남긴다.

사용자의 523.430 사진에 있는 3510ms는 미계측 잔여이며, 574ms는 기존 process section이다. 이 변경이 어느 지연을 해결했는지는 다음 실제 APK 기록으로 확인해야 한다. 원본 Android/Windows의 캐시 소유권 분리와 읽기 재사용은 조사 참고이며, draw-local memo는 자체 구현이다. 원본 또는 XP Hero 실행 성능을 측정했다는 뜻이 아니다.

로컬 Godot 4.7.2: 새 batch 검사 9개, 기존 지도 renderer 106개/options 74개/controller 25개, frame hitch 26개/draw phases 147개 통과. Python staging 14개와 추적 리소스 20개 검증 통과. 최초 editor import는 기본 config/cache 경로 권한 오류가 있어 격리한 XDG 경로로 다시 실행했다. 규칙의 `tools/check_resource_integrity.py`는 main에 없으며 현행 리소스 검사를 사용했다. 전체 실행·저장 검증과 최종 head 상태는 PR CI를 따른다. 실제 Android/GPU 검증과 동기 장부 쓰기의 실제 비용 확인은 남아 있다.
