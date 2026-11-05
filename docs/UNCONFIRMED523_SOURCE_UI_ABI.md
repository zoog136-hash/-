# PR264 원본 UI 호출자 계약

이 모듈은 원본 UI 담당에게 데이터·액션·원자 저장 호출을 제공합니다. CSB 로더, 원본 렌더러, 화면·컨트롤·대체 이미지는 만들지 않습니다. 공개 `57e780845`의 화면 분리와 저장 계약을 보존한 후속입니다. 원본 CSB 안의 이벤트·노드와 실제 픽셀을 연결한 전체 실행은 아직 검증하지 못했습니다.

## 실제 연결된 호출자

World의 기존 인벤토리·퀵 아이템 경로는 `runtime.try_use()`를 통해 원본 아이템 ID를 전달합니다. `runtime.request_presentation(section, focus)`는 등록된 원본 UI 콜백을 부르기 전에 `runtime.source_ui`에 표시 모델을 준비합니다. 콜백은 영역 문자열 하나를 받고 `runtime.source_ui.snapshot()`에서 모델을 읽습니다. UI가 없으면 기존 `presentation_unavailable`과 무차감 handled를 유지합니다. 게임 코드에서 자체 폼을 불러오지 않습니다.

원본 메뉴 호출자는 `source_ui.request_menu(button_id)`를 사용할 수 있습니다. 현재 확정한 연결은 MainMenuUIButtons106→MainMenuType86/Asset372566의 출석, 116→Type96/Asset372696의 패스입니다. 각각 출석 또는 패스의 원본 행만 제공합니다. AssetType101의 `UI/CsbFile/` 접두와 AssetView의 `MainMenu/MainMenu_Attendance.csb`·`MainMenu/MainMenu_Pass.csb`를 원문대로 보존합니다. **이들은 메뉴 구성요소의 선언 경로이며 콘텐츠 화면의 루트 템플릿·픽셀 확보를 뜻하지 않습니다.**

일반 시련은 `source_ui.request_category("ALL_DUNGEON_TRYING_PAGE_ROOT")`로 연결합니다. UIDungeonCategory14→DungeonCategory21의 정확한 관계와 활성 플래그를 검사합니다. TrialTower·오림이나 다른 던전의 키로 확대하지 않습니다. 이 키를 임의의 CSB 파일명으로 바꾸지 않습니다.

## 데이터 모델

`open_section(section, focus={})` 및 `snapshot()`의 모델에는 영역, 원본 행·액션, 표시 당시 revision/fingerprint, 원본 ID별 소유 수량·재화와 기존 영역 진행이 있습니다. 세이브의 RNG 필드는 표시 모델에 포함하지 않습니다. 상태·원본·반환값은 깊은 사본으로 분리합니다. 이 모델 자체는 원본 UI가 렌더됐다는 증거가 아닙니다.

각 행의 `source_ui`에는 이름이나 화면 라벨을 파싱하지 않고 machine ID·실제 소유 UID로 대조한 원본 레코드, namespace/ID, Desc 참조, AssetView/AssetType 참조와 선언 경로를 제공합니다. PassSystem의 `PassImageNode`는 원문 값이며 실제 CSB에 해당 노드가 있는지는 원본 UI 담당의 검증이 필요합니다. 일반 시련의 활성 ID는 저장된 `active.challenge_id`에서만 가져옵니다. 확인되지 않은 성배 접두→아이콘 조합을 숫자 일치만으로 선택하지 않습니다.

화면을 그리는 코드나 노드 이벤트 이름은 이 ABI에 없습니다. 원본 UI 담당의 실제 렌더러 계약에 연결해야 하며 빈 컨테이너나 일반 Godot 폼으로 대신하지 않습니다.

## 액션·선택·확인

각 행의 `action_refs`는 불투명한 `action_ref`와 표시 데이터입니다. 원본 노드 이벤트는 선택한 참조를 `begin(action_ref)`에 전달합니다. 임의 request를 만들어 넘기지 않습니다. 현재 원본 행에 같은 액션이 정확히 하나 남아 있는지, 표시 당시 revision/fingerprint가 같은지 검사합니다. 비용 데이터는 기존 패스·성배·아이템 실행기의 원값을 사용합니다.

`begin`의 token과 choices를 사용해 `choose(token, key, option_indices)`를 호출합니다. 인덱스는 제공된 원본 후보의 위치입니다. 외부 후보·중복 인덱스·개수 오류를 거절합니다. `instance_id`는 원본 물리 개체 UID 문자열 하나이며 배열로 제출하지 않습니다. 보상 선택은 기존 `selection.<Reward/ComplexReward ID>` 배열을 유지합니다. 선택한 부모 가지에 필요한 자식 선택을 원본 `reward_choices`로 다시 계산하며, 미선택 가지의 보상을 모두 요구하거나 임의로 지급하지 않습니다. 추첨을 하지 않고 `deferred_random`을 보존합니다. 랜덤 이후 선택이 필요한 별도 원본 UI의 단계 계약은 여기서 새로 만들지 않습니다.

선택이 끝나면 원본 확인 이벤트가 `confirm(token)`을 부릅니다. token을 먼저 소모한 뒤 같은 원본 액션·자격을 재검사하고 기존 `runtime.execute()`에 저장된 request/revision/fingerprint를 넘깁니다. 실제 재료·재화·소유권·영수증·보상·난수는 기존 단일 World 저장 경계에서 처리합니다. 실패 결과를 성공으로 바꾸지 않습니다. 중복 확인, 표시 후 잔액 변경과 더 이상 제공되지 않는 액션은 거절합니다.

취소는 `cancel(token)`, 화면 종료는 `close()`입니다. 진행·비용·난수·세이브를 변경하지 않습니다. 재바인딩과 저장 복원에서도 남은 UI 확인을 폐기합니다. World가 파괴된 경우 오래 보관한 콜백으로 저장이나 fingerprint에 접근하지 않습니다. 원본 UI가 다시 열릴 때 새 모델과 액션 참조를 받아야 합니다.

## 현재 검증의 경계

원본 표의 데이터·자산 참조 검사, 중첩 선택·실패·취소 프로토콜, 실제 Main의 원본 비용·효과·원자 저장·재시작은 별도로 검사합니다. 소유 아이템은 명시한 시험 fixture이며 자연 획득 증명이 아닙니다. 검증 수치·SHA는 `unconfirmed523_validation.json`에 기록합니다.

원본 UI 카탈로그/파서 인계 ZIP과 부분 구현 ZIP은 Library에서 확인했지만 정식 수신 helper의 tools/list HTTP401로 다운로드 전에 실패했습니다. 재시도·우회하지 않았습니다. 따라서 여기서는 실제 CSB 템플릿의 노드·이벤트 계약과 픽셀 파일을 확보했다고 주장하지 않습니다. 원본 UI 담당의 로더/렌더러를 복제하지 않으며, 확보된 원본 노드 계약이 들어오면 위 호출자와 연결하는 경계가 남습니다. 현재 원본 용옥12종과 복합·최종 보상의 시험용·만료 제한도 유지합니다.
