# TWILIGHT CI 3차: 서비스 검사 통합 + 리소스 로딩 개선

기반: PR #163 `37d2f257a51bf293143dd14ecd1780edd7b4a3d1`. 먼저 #163을 검증·병합해야 하는 **스택형 PR**.

## CI 중복 비용 절감 (삭제 대신 안전한 실행 통합)

실제 `TWILIGHT Shop Buyback / item-buyback` 원본 잡은 **한 번의 Godot import** 이후
`shop_buyback_test.gd`, `local_crafting_test.gd`, `npc_teleport_test.gd`,
`warehouse_persistence_test.gd`, `shop_authority_test.gd`를 전부 실행하고
`BUYBACK_OK`, `CRAFT_OK`, `NPC_TELEPORT_OK`, `WAREHOUSE_OK`, `SHOP_AUTHORITY_OK`
다섯 증빙을 검증한다. 여기에 다른 원래 전용 잡의 `npc_dialogue_branching_test.gd`와 `NPC_DIALOGUE_OK`를 추가해 6개 실제 서비스 테스트로 확장했다. 기존 테스트·마커·실제 Main 부팅·결과 업로드는 제거하지 않았다.

동일한 서비스 검사를 다시 실행하던 다섯 개별 잡만 일반 PR에서 건너뛰도록 했다.

- `TWILIGHT Shop Authority / shop-authority`
- `TWILIGHT Warehouse Persistence / local-warehouse`
- `TWILIGHT NPC Teleport / npc-transit`
- `TWILIGHT Local Crafting / crafting`
- `TWILIGHT NPC Dialogue Branches / npc-dialogue`

**PR #157/#158 및 workflow_dispatch에서는 다섯 개별 잡이 이전 그대로 실행된다.**
이전 체크명과 수동 재검사 진입점도 남겼다. 따라서 GitHub에 표시되는
워크플로 실행 레코드 수는 5개 줄지 않지만, 일반 PR의 **중복 Godot 실행 잡/전체 import 최대 5개**를 없앨 수 있다.
성공 시간을 줄였다고 주장하는 것은 아니다.

원래 서비스 4개 워크플로가 지원하던 `pull_request.branches`의 합집합을
기준 Buyback 검사에 적용했으므로 기존 특수 base 브랜치도 놓치지 않는다.
Buyback에는 #163과 동일한 **main 작성 전용 import 캐시의 읽기 전용 복원 단계**를
추가했으며 PR #157/#158에서는 이 신규 단계도 실행하지 않는다.
캐시 부재/복원 실패는 테스트 단축·스킵 이유가 되지 않는다.

## 게임 리소스 로딩

**아덴 선택형 PNG 팩**은 이전에 configure 단계에서 SHA256 검증 및 이미지 디코드와
동시에 **전체 레이어 ImageTexture GPU 업로드**를 했고, 아직 보여주지 않은
지역의 텍스처도 잡고 있었다. 변경 후 같은 SHA/크기/측량/영역 검증을 수행하되
GPU 텍스처는 기존 `aden_png_chunk.texture()`가 그 레이어를 표시할 때 생성한다.
같은 configure 내 반복 파일은 `(path,SHA,size)` 검증 정보를 재사용하되
서로 다른 SHA는 거부한다. 새 계측값 `verified_png_decodes`는 configure마다 초기화되어 반복 파일의 PNG 디코드 횟수를 확인할 수 있다. 캐시는 호출 단위 지역 변수라 다음 검증에서
이전 파일 신뢰 상태를 상속하지 않는다. **미검증 PNG는 여전히 게임에 붙일 수 없다.**

**원본 지도 타일 이미지**는 128개 상한을 그대로 두고
FIFO 임의 삭제를 LRU로 변경한다. 뒤로 이동할 때 자주 쓰는
아틀라스를 우선 보존해 반복 디코드/로드를 줄이지만 실제 시간·메모리 개선율은
실기 및 대표 맵 이동 테스트 이후에만 확인할 수 있다.

## 검증·병합 게이트

- 기존 #160/#163 `tools/ci/validate_workflow_refactor.py` 계약 검사에
  허용된 다섯 잡의 조건문과 Buyback union-base/cache/대화 회귀 추가 단계만 예외로 추가.
  명령·테스트·마커·증빙·타임아웃을 바꾸면 계약 검사가 실패한다.
- `tools/ci/test_workflow_refactor.py`에 PR #157/#158 보호,
  누락된 테스트/마커/브랜치, 훼손된 코드 방어 단위 테스트 추가.
- `tests/aden_png_pack_test.gd`: SHA 충돌·지연 GPU 업로드·실제 표시 시
  원본 크기 및 레이어 로드 회귀 검증.
- `tests/source_texture_cache_test.gd`: 128개 LRU 한도, 최근 항목 생존,
  누락 항목 배제 테스트 (전체 `tools/test_project.py`가 자동 수집).
- 기존 CI 필수 검사·브랜치 보호 여부는 관리자 검토가 필요하며,
  병합 전 실제 Godot 테스트/성능 계측 필수. 브랜치 보호 GET은 403이라
  어떤 검사명이 정책상 필수인지 확인되지 않았다.
- 전체 CI 무작위 재실행, 타임아웃 완화, 실패 강제 통과 및 타 PR 변경 없음.

이 PR은 #163 이후 병합을 전제로 Draft 유지한다.
