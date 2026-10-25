# PR122 batch15 — 복원·5개체 완료·SPX 원본 시간 재생

시작 HEAD는 `449d1c01652299b2cde55ab45cb51d6aedebb73b`입니다. 기존 브랜치와 PR/base/draft를 유지합니다. 최초 체크아웃에는 사용자 미커밋 변경이 없었습니다. 기존 승인394를 보존하고, 정확히 같은 프로젝트 아틀라스를 참조하는 바포메트·베레스·질투의 아타바크·알비노 피닉스·에바 왕국 상어전사5종을 로컬 계약 기준으로 완료했습니다. 새로 그린 원화/원본 프레임은0입니다. SPX 본체2는 이5종과 연결하지 않았습니다.

승인 누적은399, 잔여99=HOLD19+얼음여왕 제작중1+미제작79입니다. 상호 배타적인 현재 작업 상태는 정상385+기존 프레임보완14+HOLD19+제작중1+미제작79=498입니다. 기존14의 승인은 삭제하지 않았으며, 이번5종 승인과 별도로 보완 필요 상태를 유지합니다. 장부는 `all498-final-ledger.json`, 상태 분리는 `all498-production-status.json`, 개별 결정은 `individual-approvals.json`입니다. 과거398 보고를 완료 근거로 사용하지 않습니다.

5종은 기존 승인 원본104/112포즈, PNG·SpriteFrames·원본 셀을 재사용합니다. 실제 DB 속도와 표시 크기에 따른 보행 주기 및 방향별 폭 보정을 적용했습니다. 실제 이동속도/공격속도/HP/AC/명중/충돌/AI/피해 계산을 수정하지 않았습니다. 독립적인8방향 walk3/4프레임 검토와 실제 Main의 AI·전투·피격·사망·바닥 드랍·단일 수동 습득, 연속120Hz 재생202,948검사·전체528대상포즈를 확인했습니다. 연속 재생은 QA 시계이며 실시간 성능 또는 독립 인간 검수 주장이 아닙니다. 이 몬스터 계약에는 별도 run 원화가 정의되지 않아 새 run 제작으로 계산하지 않습니다.

바포메트/베레스는 다른 드랍이 남아 있어도 실제 선택 레코드 소멸과 정확한 인벤토리 증가를 확인하도록 QA 캡처를 수정했습니다. 피닉스의 첫 W 경로/특수효과 가림 실패는 보존했습니다. 기존 투사체 지면 투영 경로, 실제 충돌 폭과 전체8방향 가림 조건을 만족하는 QA 위치를 선택한 재실행만 통과로 채택했습니다. 지형·AI·전투 조건이나 검사 임계값을 낮추지 않았습니다.

## 보존 범위

기존 필수723시트/41,442프레임, 연결 리소스987개, PR122의 실제156PNG를 대조했습니다. 골렘·도구리·사신·가디언·여왕 및 실패 원본을 포함한156PNG는 원격 Git blob/SHA-256과 일치합니다. 기존 승인 아트는 덮어쓰지 않았습니다. 예전 미커밋 사신 PNG2개와 QA 초안은 여전히 UNRECOVERED입니다. 대형 과거 QA 압축물은 시작 Git tree에 그대로 보존하며 로컬 sparse 상태는 REMOTE_ONLY입니다. 이전11GB 전체 QA를 다시 변환하지 않았습니다.

새 Main 메타데이터와 전체120Hz JSON은 `Main-reports/`, `temporal-summary.json`, `temporal-reports.tar.gz`에 있습니다. 압축물에는 JSON만 있으며 이미지·음성·키·인증서가 없습니다. 새 프로젝트-source QA PNG 본문은 로컬에 보존하고 최종 CI의 `source-family-five-Main-<SHA>` 아티팩트로 재현합니다. 로컬에만 있는 PNG를 Git 전달로 계산하지 않습니다. SPX/CSB 원본이 보이는 캡처는 공개 아티팩트에 포함하지 않습니다.

## SPX 실제 결과와 제한

A2002/patch_1의 지정 SHA가 일치합니다. A3 평문 SHA는 `95b1afb8dc04c21075359026a6a42a99e109c96cd745c418e7014476cc35b84e`입니다. 서로 다른 버전의 동일성을 가정하지 않고 모든 참조를 대조했습니다. 1,700SPX/44그룹/14,534레코드/14,304이미지/230빈레코드를 확인했습니다. 본체2·그림자2·추가레이어4·효과36으로 구분합니다. 같은 SHA 캐시1,700개 재검증에서 디코더 호출은0입니다.

원본 순서·ticks·0tick 이벤트·타격 표시·runL/runR·오프셋·원본 타입을 유지합니다. 단일 시계로 레이어를 동기화하고 그림자는 본체 뒤에 둡니다. 양수 ticks는 Godot duration, 0tick은 별도 이벤트로 보존합니다. 공격 전체를 기존 공격 간격에 맞추되 상대 시간 비율을 유지하며 피해/타격 횟수는 기존 로직이 담당합니다. 소스 마커는 시각 이벤트입니다. 24tick/s는 검토 시계이며 원작 절대 속도 검증은 미완료입니다.

두 본체768논리트랙과36효과그룹 트랙을 Godot4.7.2에서 전수 검사했습니다. 최종58,394검사 실패0입니다. 실제 Main에서는 두 본체112트랙과36효과그룹, CSB3개의 검토 재생·반복·종료 정리443검사가 통과했습니다. 36그룹은 독립 스킬36종을 뜻하지 않습니다. 기존 스킬 DB와 정확한 동일성이 확정되지 않아 실전 스킬 연결0입니다. 유사한 포우 슬레이어를 Force 효과와 동일하다고 연결하지 않았습니다.

CSB7개는 읽을 수 있는 FlatBuffer만 분석했고 UI4개는 미완성 후보로 유지했습니다. PLIST4개151프레임 중 단일 Sprite/FileData 구조인 CSB3개를 AnimationPlayer 장면으로 재현했습니다. OGG10827–10830은 원본 참조 이벤트에서 실제 로드하며, 10831/10832 및18개 본체 음성 참조는 미확보로 유지합니다. 소리가 없어도 재생은 끝납니다. 보호된 XML/JSON/BIN을 해제하거나 원본 실행 파일을 실행하지 않았습니다.

모든 레이어를 Additive로 만들지 않았습니다. 원본 속성과 타입은 남기고, 검증된 혼합 모드만 실전 활성화할 수 있습니다. 현재 혼합·가림과 실제 부착점은 HOLD이며 normal 검토 화면을 원작 합성 승인으로 계산하지 않습니다. 44그룹 전체 RGBA는 약767MiB라서3,108개의 동작별 지연 리소스와96MiB 강한 참조 캐시 제한을 추가했습니다. 최대 활성 합성의 RGBA 추정은 본체 약79.4MiB/효과 약65.5MiB입니다. 이는 Android 실측 또는 전체 프로세스 메모리가 아닙니다.

새 제3자 SPX/PNG/CSB/OGG는 저장소 밖 `/workspace/private-spx`에서만 검증했습니다. 재배포 권한은 HOLD입니다. 공개 PR은 코드·테스트·SHA/타이밍 메타데이터와 재현 방법만 전달합니다. 원본 Drive는 사용자가 지정한 A2002/A3/검증키트 폴더이며 신규 원본 팩 공개 전달은0입니다. 기존6ZIP 전체 검사 중 `a1.zip`은 현재 환경에 없었습니다. 이번에 실제 확보·검사한 A2002/A3/patch_1의 무결성은 별도 원장으로 증명하며 다른 ZIP을 확보했다고 주장하지 않습니다.

## 재현

허가된 비공개 장소에서 분할 A2002를 순서대로 연결하고 지정 SHA를 대조합니다. ZIP의 `connector/patch/patch_1.zip`에서 SPX·CSB·PNG·PLIST·OGG만, A3에서는 평문 `tool/spritor/list.spz`만 데이터로 추출합니다. 인증서/키/실행 파일은 입력에서 제외합니다. 검증키트의 `audit/frame_metadata.json`을 `--audit`에 사용합니다.

```sh
python tools/l1j/build_spx_source_pack.py --source /private/input --actions /private/list_a3_plain.spz --audit /private/frame_metadata.json --cache /private/cache --output /private/generated --report /private/batch.json --direction-map 6,5,4,3,2,1,0,7
python tools/l1j/verify_spx_source_pack.py --pack /private/generated --source /private/input --audit /private/frame_metadata.json --report /private/pixels.json
python tools/l1j/inspect_csb_assets.py --source /private/input --output /private/csb.json --private-output /private/generated
```

`--output`은 저장소 밖이어야 합니다. 개인 검증 프로젝트에만 생성된 assets/data를 설치한 뒤 Godot4.7.2로 임포트합니다. `tests/validate_private_spx_source_pack.gd`는 원본 입력이 필수인 명시적 검사이며 일반 CI fixture 검사를 원본 성공으로 대체하지 않습니다. `tests/run_private_spx_main_review.gd`는 실제 OpenGL Main과 별도 격리 사용자 디렉터리, `TWILIGHT_SPX_MAIN_REPORT`, `TWILIGHT_SPX_MAIN_CAPTURES`를 요구합니다. 공개 CI에 개인 원본을 설치하지 않습니다.

최종 CI는 최종 원격 HEAD의 기존33개 워크플로와 추가5종 job으로 확인합니다. APK 빌드와 Android 실기기를 구분하며 실기기는 NOT_RUN입니다. 최종 CI 결과는 PR 본문/해당 HEAD Checks가 권위 있는 후속 기록입니다. main 병합·force push·rebase 또는 다른 PR 수정은 하지 않습니다.
