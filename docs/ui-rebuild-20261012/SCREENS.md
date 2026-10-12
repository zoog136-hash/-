# 화면·연결·검증 대조표

참조 ID는 [공식 자료 목록](reference-sources.json)의 파일 식별자다. 구현 파일은 `scripts/ui/` 아래다. 아래의 완료는 실제로 연결한 기능의 상태이며, 원작 전체 외형 동일성은 [남은 차이](REFERENCES.md)에 따로 기록했다.

| 화면 | 참조 | 구현 경로 | 실제 진입·연결 | 실행 증거 | 상태·남은 차이 |
| --- | --- | --- | --- | --- | --- |
| HUD | 메뉴 및 UI 소개 0-0 | renewal_hud | 기본 게임 → 상점·가방·스킬·메뉴 | hud PNG, UI 회귀 | 완료. 기존 아트·폰트 차이, 원작 고정 요소 전수 좌표 검증은 확인 필요 |
| 전체 메뉴 | 같은 가이드 메뉴 화면 | renewal_hud | 우상단 메뉴 → 유지 서비스 | menu PNG, side smoke | 완료. 삭제 정책의 빈 자리 없음 |
| 가방 | 아이템 소개 0-0 | renewal_inventory / reference_layout | 가방 → 필터·검색·정렬 | inventory PNG, 입력 회귀 | 완료. 4열·외곽 좌표 대조; 개별 테두리·아이콘 차이 |
| 가방 확장 | 동일 버전 직접 참조 미확보 | renewal_inventory / renewal_window | 가방 → 확장 | inventory-expanded PNG | 동작 완료 / 참조 확인 필요 |
| 아이템 상세 | 가이드 관련 설명, 개별 동일 상태 미확보 | renewal_inventory | 정보·장비 클릭 → 사용·해제·잠금·등록 | inventory-detail PNG, 입력 회귀 | 동작 완료 / 외형 참조 확인 필요. 일반 아이템 삭제 미구현 |
| 스킬 목록·상세 | 메뉴 및 UI 소개 1-28 | renewal_skills | 스킬 → 검색·습득·사용·등록 | skills / skill-detail PNG, provenance / 입력 회귀 | 완료. 긴 원작 검증 정보는 상세 스크롤 |
| 퀵슬롯 | 메뉴 및 UI 소개 1-25/26/27 | pointer_transfer / renewal_hud / world | 등록·이동·교환·해제·AUTO·페이지·저장 | 입력 회귀 49, quickslot smoke | 완료. 두 묶음 독립 페이지, 느린 프레임의 길게 누르기 및 중복 에뮬레이션 검사 |
| 변신 | 메뉴 및 UI 소개 1-10 | renewal_hud catalog | 메뉴 → 변신 → 선택 → 확인 → 적용 | catalog-detail-변신 PNG, 카드 정책·통합 검사 | 기존 적용 동작 완료. 소유·중복·합성·컬렉션 서비스 미구현 |
| 마법인형 | 메뉴 및 UI 소개 1-17 | renewal_hud catalog | 메뉴 → 인형 → 선택 → 확인 → 소환 | catalog-detail-마법인형 PNG, 입력 회귀 | 기존 소환 동작 완료. 소유 서비스는 위와 같음 |
| 성물 | 성물 시스템 1-0/1/2 | renewal_hud catalog | 메뉴 → 성물 → 선택 → 확인 → 적용 | catalog-detail-성물 PNG, 카드 정책 검사 | 기존 적용 동작 완료. 2026 가이드와 전체 스킨·배치 일치 확인 필요 |
| 캐릭터 장비 | 메뉴 및 UI 소개 3-0 | renewal_character | 캐릭터 → 24부위 두 페이지·상세·해제 | character / character-equipment-2 PNG, 물리 ID 회귀 | 완료. 추가 12부위는 기존 게임 규칙을 노출하는 UI 확장 |
| 기본 스탯 | 메뉴 및 UI 소개 3-3 | renewal_character | 캐릭터 → 스탯 → 기존 포인트 증가 | character-stats PNG, UI 회귀 | 완료. 기본+추가=최종, 원래 포인트 조건 유지 |
| 상세 스탯 | 메뉴 및 UI 소개 3-4 | renewal_status | 캐릭터 → 상세 스테이터스 | detailed-stats PNG, snapshot 연결 | 완료. 실제 계산 필드만 표시, 전체 행 배치 일치 확인 필요 |
| 일반 상점 | 메뉴 및 UI 소개 1-9 | renewal_shop | 상단 상점 → 상품·수량·합계·확인 | shop / purchase-confirm PNG, 거래 회귀 | 완료. 프로젝트 아데나 상품만 표시 |
| NPC 구매 | 동일 버전 직접 참조 미확보 | renewal_shop, npc_mode | 월드 NPC → 별도 목록 구매 | npc-shop PNG, reviewed_shop / Aden 검사 | 동작 완료 / 외형 참조 확인 필요 |
| 판매 | 동일 버전 직접 참조 미확보 | renewal_sell | NPC 판매·메뉴 → 가방 드래그 → 수량 → 금액 확인 | sell PNG, 잠금·상점 서비스 회귀 | 동작 완료 / 외형 참조 확인 필요 |
| 창고 | 동일 버전 직접 참조 미확보 | renewal_warehouse | 창고+가방 → 양방향 드래그 → 수량 확인 | warehouse PNG, 입력·저장 회귀 | 동작 완료 / 외형 참조 확인 필요 |
| 제작 | 동일 버전 직접 참조 미확보 | renewal_crafting | 메뉴 → 기존 제작식 → 비용 확인 → 제작 | crafting PNG, crafting_atomic 등 전체 검사 | 동작 완료 / 외형 참조 확인 필요 |
| 강화 | 동일 버전 직접 참조 미확보 | renewal_forge | 주문서 → 물리 장비 → 비용·확률 확인 | forge-target PNG, item_instance / 잠금 회귀 | 동작 완료 / 외형 참조 확인 필요 |
| 지도·자동사냥·설정·로그 | 공식 HUD와 기존 유지 기능 | renewal_hud, 기존 서비스 | 메뉴 → 각 유지 화면 | 102캡처의 map / auto / settings / log | 연결 완료 / 개별 원작 외형 참조 확인 필요 |
| 수량·확인 | 개별 동일 상태 미확보 | renewal_confirmation | 거래·카드·제작·강화의 마지막 단계 | purchase-confirm PNG, 취소·중복 확정 검사 | 동작 완료 / 원작 외형 참조 확인 필요 |
| 삭제 대상 기능 | 사용자 정책 | 메뉴·바인딩 검증 | 진입 경로 제공하지 않음 | side smoke, 원작 스킬·카드 정책 검사 | 프로젝트 정책상 제외 |
| Windows·Android 실기기 | 해당 없음 | 공통 Godot 입력 | 실제 기기 | 이번 환경은 Linux | 실행 미검증 |

이전 가로 스와이프 즉시 장착 대신 정확한 장비 부위 드롭을 사용한다. 가방 수동 순서·장비 부위 드롭·창고/판매 드롭은 사용자 요청에 따른 확장 동작이다. 정렬 버튼은 선택한 정렬을 우선하며, 수동 드롭을 하면 수동 순서 모드로 전환한다. 물리 ID·수량·강화·잠금은 변하지 않는다.
