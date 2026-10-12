# PR #86 선택 이식 최종 범위 — 2026-10-12

기준 main: `9fbcd1a02505a2d9685507411faff577c7e236f6` (#91 UI + #92 타격 효과 포함).
반영 PR: #93, `feature/twilight-pr86-selective-port-20261012`.
사용자 요청: 적용할 가치와 호환성을 판단하여 선택 반영하고 병합. #86 전체 UI를 덮어쓰지 않는다.

## 선택한 기능

| 기능 | 구현과 범위 |
|---|---|
| 뒤로가기 | 기존 #91 창에 Back 버튼과 화면 이동 기록. 기존 Escape 상세→목록 동작 보존 |
| 인벤토리·스킬 상태 복원 | 검색·필터·정렬·정확한 아이템 참조/스킬 ID·상세/목록·스크롤 복원. 재생성된 창도 script 경로로 식별 |
| 안전한 복원 | 임의 OptionButton 신호 재실행 제거. 요정 속성 선택, 소환수 명령, 거래 수량, 설정 저장을 화면 복원으로 실행하지 않음 |
| 전투 기록 | 열린 기록창 실시간 갱신, 기존 최근 120줄 제한, 닫힌 창 참조 제거 |
| 메뉴 접근 | 주 창 헤더의 메뉴 복귀 버튼. 메뉴 헤더의 지역 이동 버튼은 기존 텔레포트 안내로 연결하며 열기만으로 비용 차감/이동하지 않음 |
| 모바일 안전 영역 | `safe_area.gd`를 #91 RenewalWindow 배치에 연결. 화면 좌표 변환·클리핑·빈 영역 fallback. PC 기준 폭은 유지 |
| 착지 좌표 | 실제 AStarGrid2D region과 비영점 원점으로 무작위/비상 착지 후보 제한. 소환 위치는 요청 반경 및 도달 가능한 경로 확인 |
| 입력 정리 | 창 교체 시 스크롤 제스처와 드래그 참조 제거, 숨겨진 창은 입력 처리하지 않음 |

### 이전 초안에서 수정한 결함

초기 #93의 범용 snapshot은 자동 생성 노드 이름을 포함한 NodePath와 목록 index를 저장했다. 또한 모든 OptionButton.item_selected를 재실행하여 화면이 아닌 게임 상태를 바꿀 가능성이 있었다. 현재 코드는 인벤토리·스킬의 UI 필드만 명시적으로 복원하고, 정확한 ID를 사용한다. 소유하지 않거나 판매한 물리 아이템 대신 다른 아이템을 선택하지 않는다. 카탈로그는 #91의 기존 별도 기억 로직을 유지한다. 지연 스크롤은 navigation revision 및 노드 유효성을 검사한다.

## 월드 수정의 분리와 보존

#86의 `411effaf1b20a84fc910562817714712e5f52cb2`에서 `scripts/world.gd`의 `_random_walkable_position`, `_spawn_position_fallback` 변경만 이식했다. 최종 world diff는 +18/-12이다.

#94는 임시 integration 브랜치 두 개 사이에서 이 변경만 3-way 적용하기 위한 보조 PR이다. 해당 병합 결과의 tree를 #93의 정상 parent에 연결한 `efef2d1e61147dc355d891f4421ab28300189faf`가 실제 이식 커밋이다. #86/보조 브랜치의 과거 이력이나 구형 UI를 main의 parent로 추가하지 않았다.

원본 맵 adapter 경로, 맵/지형/자산 데이터, 저장 처리 및 나머지 world 코드는 보존했다. 좌표 샘플링 범위가 바뀌므로 RNG 추출 횟수/시퀀스까지 이전과 동일하다고 주장하지 않는다. 모든 셀이 막혔거나 이동 격자가 없는 경우의 기존 마지막 fallback은 유지했으며, 불가능한 맵에서도 항상 정상 착지한다고 주장하지 않는다.

## 유지·제외한 기능

- #91의 50개 바인딩·독립 페이지·pointer_transfer, 화면별 UI·캐릭터 24부위, #92 전투 이펙트 유지.
- #86의 24칸 제어기, 480px 통합 HUD 전체, 30개 메뉴 일괄 복원, 미지원 성장/컬렉션/친구/우편/랭킹/이벤트 안내창 제외.
- 삭제한 PvP·퀘스트·혈맹·거래 기능 복원 없음.
- 별도 50칸 일괄 관리 화면, 던전 신규 서비스, Android 하드웨어 Back 연결, 목적지 사전 선택은 이번 추가 범위가 아님.
- 안전 영역 적용은 RenewalWindow 창 범위다. 전체 HUD·조이스틱·모든 확인창의 실기기 노치 대응 완료를 뜻하지 않는다.
- 기존 퀵슬롯 등록창의 모든 복귀 시나리오를 새로 완성했다고 주장하지 않는다.

## 실제로 수행한 검증

컨테이너에서 Godot 실행 파일이 없고 외부 DNS도 실패했다. 아래 정적 검사를 Godot 컴파일/실행 검사로 취급하지 않는다.

GDScript 문법 파서: Scony/godot-gdscript-toolkit의 Lark grammar/indenter 방식을 이용한 비엔진 구문 검사. 엔진 타입 검사·씬 import·렌더링을 수행하지 않는다.

| 검사 단위 | 결과 | Git blob 또는 추출 단위 해시 |
|---|---|---|
| navigation_memory.gd 전체 | PASS | `dbedacd30411044a730a24d6d62c8de787d8f2cf` |
| safe_area.gd 전체 | PASS | `bdc726b5cb16bf4af23faf2cdfd59b80531d14de` |
| pr93_landing_bounds_test.gd 전체 | PASS | `11a1557d55cd8d0f8384bd132a76b8c9db979c2c` |
| ui_navigation_preservation_test.gd 전체 | PASS | `536e6f8c54ab0d2c5abd4075ead4af54f40088e1` |
| world 착지 함수 2개 추출 | PASS | `7ae9d51e59d920c9a2d3cb572c5e3b7f9966deca` (전체 world 해시 아님) |
| window 변경 함수 추출 | PASS | `24b4105aee99b2a4490903a89dc8328a0ebb8561` (전체 window 해시 아님) |
| 집중 CI YAML | PASS | `82e6454d7aec1e3869ffadf0dcae0ed37d8f7b90` |
| CI run 스크립트 3개 bash -n | PASS | 실행 검사가 아닌 셸 문법 검사 |

## 추가한 실행 검사와 미확인 상태

집중 CI에 다음 6개 Godot 검사를 연결했다: ui_navigation_preservation_test, pr93_landing_bounds_test, ui_pointer_transfer_test, quickslot_smoke_test, ui_renewal_integration_test, ui_fidelity_regression_test.

테스트마다 별도 XDG_DATA_HOME, import/개별 실행 시간 제한, 오류 로그·비정상 종료·성공 마커 누락 시 실패 판정, 항상 로그 업로드를 적용한다. PR뿐 아니라 main push에서도 집중 CI가 실행되도록 했다. 기존 전체 UI/통합 워크플로를 삭제하거나 실패를 무시하도록 바꾸지 않았다.

작성 시점 원격 Actions는 대기 중이다. Godot 실행·전체 회귀·OpenGL 캡처·Windows/Android 실기기 검증 성공을 보고하지 않는다. 사용자 승인에 따른 코드 병합 여부는 #93의 GitHub merged 상태로, 원격 검증 결과는 해당 최종 SHA의 Actions로 구별해서 확인해야 한다.
