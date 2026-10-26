# 1ed0a0da Windows Aden 로드 실패 조사

대상 HEAD: `1ed0a0daa881f1e0887b0a20699c4dda366f48dd`. [Windows 실패 로그](https://github.com/zoog136-hash/-/actions/runs/40079308572/job/120829489364)의 실제 검사 커밋은 `43977934f1b61bd397c1523777cd0c296dbb6625`이며, main `e0a14f07`에 해당 HEAD를 합친 임시 merge다.

## 원인과 귀속

CI 복구 `b7c4cd2b`에서 공용 PNG 로더에 `apply_navigation_corrections()`가 추가됐다. 이 함수는 Aden을 포함한 모든 PNG 맵을 열기 전에 `domination_png_plan.json`의 **실제 바이트 SHA-256**을 검사한다. 기존 `.gitattributes`는 native/aden_faith 계획 파일만 보호했다. Windows의 Git `core.autocrlf=true` 체크아웃은 보호되지 않은 Domination 파일의 LF 695개를 CRLF로 바꿔 인증을 실패시킨다. 공용 계획이 비고 Aden 필드가 null이 되어 8방향 검사도 이어서 실패한다.

실패 메시지의 `index_exists=true definition_exists=true definition_sha_matches=true`는 이전 A3 정의 파일에 관한 진단이다. 현재 우선되는 PNG 계획 파일의 무결성 성공을 뜻하지 않는다. 이 실패를 main의 기존 문제나 성장 기능 자체의 회귀로 분류하지 않는다. PR154에 편입된 CI 복구의 Windows 체크아웃 호환성 문제다. [PR155 선행 수정 b2fd9602](https://github.com/zoog136-hash/-/commit/b2fd96021e28f343fe084be1a5379bb1c9a65791)는 원인 후보로 참고했으며 현재 파일과 로그로 별도 재현했다.

## 최소 재현과 수정

별도 임시 Git 저장소에 현재 속성과 인증 대상 계획 3개를 넣고, `core.autocrlf=true`로 실제 `checkout-index`를 실행했다. 손으로 CRLF 문자열을 합성한 결과가 아니다.

| Domination 체크아웃 | 바이트 | SHA-256 | 공용 계획 / Aden |
| --- | ---: | --- | --- |
| 수정 전, CRLF 695개 | 13,542 | `7dcc8b6f47e73b6509a29a7fe30b47e689fdd316a8d5ccf571d7ba23ed693a52` | 거부 / null |
| 수정 후, 원래 LF 유지 | 12,847 | `80db63cde9dba6dc0ca4b33e4f12d40c1f108a8f77a87a420fec0eb6e778fea4` | 성공 / 로드 |

수정은 루트 `.gitattributes`에 `data/maps/domination_png_plan.json -text`와 설명 한 줄을 추가하는 것뿐이다. 계획 JSON, 지도/로더/성장 코드, 기존 검사와 기준은 그대로다. 다른 PR의 지도나 기능 코드를 가져오지 않았다. 통제 재현 중 바꾼 계획 바이트도 원래 SHA로 복원했다.

## 집중 검증

- 수정 전 Git 체크아웃: native/aden_faith SHA 유지, Domination만 불일치.
- 수정 후 같은 Git 체크아웃: **3/3 SHA 일치**. `git check-attr`에서 Domination `text: unset` 확인.
- 체크아웃에서 얻은 CRLF 계획을 현재 코드에 적용: 변경하지 않은 `original_based_spear_captain_gameplay_test`에서 CI와 정확히 같은 **2개 실패**, 4개 단언만 실행된 조기 종료 재현.
- 원래 LF 계획으로 복원: 동일 검사 **1,440개 단언 PASS**, 플레이어 8방향/입력/전투/피격/사망/리스폰 검사 완료. 보고서 `incoming`도 8방향이며 실패 배열은 비었다.
- 별도 로더 진단에서 CRLF의 계획 거부/Aden null, LF의 계획 생성/Aden 로드를 각각 확인했다. 로더·필드·계획·기존 검사 7개 파일의 바이트가 대상 HEAD와 같은지 확인했다.
- 필수 리소스 검사 PASS: Git 추적 시트 723개, 41,442프레임, 233,420,026바이트. 이는 외부 원본 전체 전달을 뜻하지 않는다.

실행 환경은 Linux Godot 4.7.2 headless와 격리된 새 user data다. Windows의 Git 변환은 실제 재현했으나 **Windows Godot에서 수정 후 검사를 직접 실행한 것은 아니다**. 전체 CI와 나머지 Windows 캐릭터 검사 두 개를 반복하지 않았다. 새 SHA의 원격 Windows 결과는 별도로 확인해야 한다. 첫 로더 진단 helper의 잘못된 RefCounted 해제 때문에 중단한 실행은 검증 성공으로 세지 않았고, helper를 고쳐 두 바이트 조건을 다시 진단했다.

증거와 재현 스크립트: [evidence/windows-checkout-ci](evidence/windows-checkout-ci). main 병합은 하지 않았다.
