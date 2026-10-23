# TWILIGHT UI 샘플 v2

리니지M의 실제 가이드·플레이 캡처를 보고 1280×720 가로 게임 UI로 다시 구성한 독립 브라우저 샘플입니다. 본게임 저장·계정·APK와 연결하지 않습니다. 기존 Site v1과 기존 자산을 보존했습니다.

- 전면 카드창 3종, 장비/카드 컬렉션, 우측 4열 가방과 상세 선반, 좌측 장비창 24슬롯/2페이지, 전면 스탯 배분·스킬 관리, 강화, 제작, 창고, 상점, 설정.
- 카드 36장: 기존24+최신 본게임 사본에서 대조한12. 이름·등급·원본 Git 해시는 `research/additional-cards.json`.
- 선택/적용, 합성 재료→확인→진행→결과, 장비 실물 등록, 스탯 임시 배분, 스킬/퀵슬롯, 강화, 수량 제작·보관·구매를 연결했습니다.
- 데이터는 탭 메모리에만 있고 새로고침하면 초기화됩니다. 수량·효과·가격·레시피·결과는 시연값입니다.

## 실행

외부 런타임 의존성이나 빌드 과정이 없는 HTML/CSS/ES Modules입니다.

저장소 루트에서 `cd samples/twilight-ui` 후 실행합니다. Godot는 이 디렉터리의 `.gdignore`로 샘플 자산을 가져오지 않습니다. `dist/`는 배포본 소스 커밋 `9f1304f6e6c449e0fc5f03642d43afa3c1d73191`에서 그대로 보존했습니다. 병합 범위와 출처는 `MERGE_PROVENANCE.json`에 있습니다.

```sh
python3 -m http.server 8080 --directory dist
npm test
```

`http://localhost:8080/`에서 실행합니다. 제출 캡처·비교·검증 기록은 `/review.html`입니다.

상태 검사는 Node.js 24에서 `npm test`로 실행합니다. 브라우저 검증은 `npm ci`, `npx playwright install --with-deps chromium` 후 `python3 -m http.server 4173 --directory dist`를 실행한 상태에서 `npm run test:browser`를 사용합니다. 기존 시스템 Chromium을 쓰려면 `CHROMIUM_PATH=/usr/bin/chromium`을 지정합니다. 검증 스크립트는 `evidence/`에 새 결과를 기록하며 과거 제출 기록은 `dist/review/`에 유지됩니다.

## 근거와 검증

`research/REFERENCES.md`에 화면별 실제 구조·크기·시기 예외를 기록했습니다. 공통 기준은 한국2022–2023 캡처이며 성물2023/창고2025 등 예외를 구별합니다. 촬영 빌드가 확인되지 않은 자료를 최신 단일 버전이라고 표시하지 않습니다. 원작 참고 이미지를 게임용 스킨으로 사용하지 않았습니다.

`evidence/`의 JSON과 실행 스크립트에 17개 상태 검사, 데스크톱/모바일 각12개 흐름, 143개 메뉴 위치 클릭, 5개 해상도 입력 대조, 실제 Chromium 캡처 기록이 있습니다. 폰 크기에서 완전히 표시된 버튼의 최소48 CSS px를 측정했으며 기기 물리 mm/Android dp/Godot 좌표와 동일하다고 해석하지 않습니다. 실기기 터치·DPI·모든 원작 팝업·세부 텍스처의 일치 검증은 미완료입니다.

기란 배경은 본게임 `a6fc6dec49f4f9a05c1e82df9a4e021b4cbe44ec`의 실제 플레이 캡처에서 월드 영역만 잘라 사용한 정적 배경입니다. 실시간 맵 시뮬레이션이 아닙니다. 캐릭터는 기존148×116 첫 대기 프레임을 정확한5×5 시트 비율로 표시합니다.

스킬은 기존 TWILIGHT의 Game-icons 대체 아이콘이며 원작 스킬 그림이 아닙니다. Lorc/Delapouite, CC BY3.0, 파일별 출처는 `dist/data.js`와 샘플 설정에 있습니다. https://game-icons.net/ · https://creativecommons.org/licenses/by/3.0/
