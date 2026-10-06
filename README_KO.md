# 황혼의 기사 · Offline RPG V20 LINEAGE HUD Full Native

V17 HTML 안에 포함되어 있던 실제 게임 자원을 추출해 V18의 Godot 네이티브 구조에 다시 연결한 풀버전입니다.

## 복원된 V17 자원
- HTML `data:image` 발생 2,313건 / 고유 이미지 2,307개: **누락 0개**
- 인벤/도감 이미지 2,165개
- 상세 도감 DB: 변신 413 / 마법인형 166 / 성물 144 / 아이템 2,129
- 방향 아트: 변신 78 / 마법인형 59
- 원본 캐릭터 스프라이트시트 1536×1024
- 원본 몬스터 스프라이트시트 1536×1024
- 원본 UI 참고 시트 1536×872 및 실제 HUD 아이콘 크롭
- V17 월드/플레이어/고스트/버그 이미지

## Godot 네이티브 기능
- `CharacterBody2D` 플레이어/몬스터 물리 이동
- `CollisionShape2D` + `StaticBody2D` 맵 충돌
- `AStarGrid2D` + `NavigationAgent2D` 길찾기/자동사냥
- `TileMapLayer` 충돌 디버그
- `AnimatedSprite2D` 캐릭터 4종 방향/공격 애니메이션
- `CanvasLayer` / `Control` 기반 HUD
- 변신·마법인형·성물·아이템 도감 UI
- 변신 장착 시 실제 방향 아트로 캐릭터 외형 변경
- 마법인형 장착 시 플레이어 추적 동행
- 성물 장착 시 캐릭터 주변 표시
- 아이템 인벤토리에 실제 이미지 표시
- 몬스터 원본 스프라이트시트에서 6종 비주얼 사용
- 25개 맵 + 충돌/스폰/이미지 데이터 유지

## 메뉴
우측 상단 `≡ 메뉴`에서 캐릭터/장비, 변신, 마법인형, 성물, 아이템 정보, 월드맵, 저장/불러오기를 사용할 수 있습니다.

## Android 실행
1. ZIP 압축 해제
2. Godot 4.7.x Android Editor 실행
3. `Import`
4. `project.godot` 선택
5. `Import & Edit`
6. ▶ 실행

## Godot 4.7.2 실제 엔진 검증
- 공식 Godot 4.7.2 stable로 headless editor 파싱 **PASS**
- `Main.tscn` 실제 headless 기동 **PASS**
- GDScript Parse Error / Failed to load script / Node not found 검출 **0**
- 별도 검증 기록: `V19_VALIDATION.txt`

## 검증 정보
`data/v19_extraction_manifest.json`에 원본 HTML에서 추출한 이미지 SHA-256, 경로, 개수 및 누락 검증 결과가 기록되어 있습니다.


## V19.1 FIXED 변경점
- Godot 4.7.2 경고 5개 수정: 정수 나눗셈 3개, `exp` 내장 함수명 충돌 2개
- 변신 4방향 × 4프레임 AnimatedSprite2D 적용
- 마법인형 4방향 × 4프레임 AnimatedSprite2D 동행 적용
- 성물 장착/표시 연결
- 아이템 획득 및 무기/방어구/장신구 장착, 스탯 반영 연결
- 캐릭터 패널에 장착 상태/유효 스탯 표시
- 리소스 import 중 기본 캐릭터 애니메이션이 비어도 런타임 오류가 나지 않도록 방어 처리
- Godot 4.7.2 자동 기능 테스트 통과


## V19.3 FIXED 변경점
- `albino12.png`가 PNG 확장자이면서 실제 내용은 JPEG였던 문제 수정: 실제 PNG로 변환
- `faith4.png`도 동일한 확장자/포맷 불일치 수정
- 전체 이미지 2,360개 디코드 검사 및 확장자 시그니처 검사: 오류 0
- 25개 맵 `image_path` 존재 검사: 누락 0
- Android에서 ItemList 첫 항목만 선택 상태로 남는 문제 수정
- `InputEventScreenTouch` 좌표로 실제 행을 직접 찾고 선택하도록 모바일 터치 처리 추가
- `item_clicked`, `item_selected`, native touch를 모두 지원
- Godot 4.7.2 자동 테스트에서 변신/마법인형/성물/아이템 각각 3번째 항목 터치 선택 PASS


## V19.3 도감 페이지 수정
- 변신/마법인형/성물/아이템 도감에 `처음 / ◀ / 현재 페이지 / ▶ / 끝` 버튼 추가
- 페이지당 40개 표시
- 검색 결과에도 페이지 이동 적용
- Android 터치 행 선택 유지


## V20 LINEAGE HUD 변경점
- 프로젝트 내 `assets/original_sheets/reference_ui.jpg`를 기준으로 인게임 HUD 전면 재배치
- 좌상단: 캐릭터 초상 / 레벨 / HP / MP / 공격·방어 상태
- 상태창 옆: HP 물약 / 가속 아이템 퀵 슬롯 및 수량 표시
- 좌측: 버프 아이콘 행 + 퀘스트/파티/선택대상 패널
- 중앙 상단: 현재 맵 + 선택 몬스터 HP 타깃 HUD
- 우상단: 상점 / 가방 / 스킬 / 퀘스트 / 메뉴
- 우측 전투: SELF / 대상 / AUTO / 대형 공격 버튼
- 하단: EXP / 매크로·채팅·설정 / 스킬 6칸 / 물약·귀환 퀵슬롯
- 기존 V19.3 변신·마법인형·성물·아이템 도감/장착/페이지 기능 유지
- 퀘스트 처치 수치와 퀵아이템 수량을 실제 월드 상태에 연동
- 몬스터 화면 표시 크기 및 근거리 이름/HP 표시 정리

## V20 Godot 4.7.2 검증
- 공식 Godot 4.7.2 stable headless editor 파싱: PASS
- V20 HUD 생성: PASS
- AUTO ON/OFF UI: PASS
- 타깃 이름/HP 표시 및 해제: PASS
- HP 물약/가속 아이템 수량 연동: PASS
- 퀘스트 진행 `(3/9)` 갱신: PASS
- 기존 Android 도감 터치 선택 회귀 테스트: PASS
- 기존 도감 페이지 이동 회귀 테스트: PASS
- 상세 기록: `V20_VALIDATION.txt`
