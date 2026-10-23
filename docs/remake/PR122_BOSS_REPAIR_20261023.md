# PR122 보스 실제 보완 제작 — 2026-10-23

일반 258종(기승인 221 포함)의 현재 runtime 필수 8,514 요청은 프레임 누락 0이다. 기존 WALK→RUN 재사용 2,064건을 포함한다. 이번 보스 작업에서도 일반 258개의 프로필·분류 행과 기존 몬스터 runtime 자산 642개의 바이트/SHA를 보존했다. 일반 외형은 재심사하지 않았다. 별도 신규 초안의 놀31·알비노몽크32 미제작 클립은 현재 runtime 누락과 구분한다.

보스 4종에 실제 신규 원화 98 PNG(실패본 포함)를 생성하고, 최종 선택 117클립·401개 고유 RGBA 자세를 SpriteFrames/NativeMotionProfile에 연결했다. 필수33클립을 갖춘 후보2종, 부분후보2종이다. 품질 HOLD가 남아 신규 승인·기본 게임 카탈로그 교체는 0건이다.

| 보스 | 선택 클립 | 새 고유 자세 | 실제 보완 | HOLD / 미완성 |
| --- | ---: | ---: | --- | --- |
| 얼음 여왕 | 32/33 | 102 | E/S 지지 교대, NE 후방사선, SW 방향, 방향별 크기 등록, W/SW HIT와 S 전방 공격 보완 | N RUN 미선택. N 의상/slit 좌우 연속성, 일부 사선 카메라·실제 지지/접촉 검토 잔여. |
| 죽음의 좀비 로드 | 33/33 | 116 | 거대한 배·사슬·주먹·맨발 복원, E/SW 카메라 및 S 반대발 지지 보완 | S 지지 교대는 보완. E 등 일부 RUN의 같은 다리 반복/가려진 지지 교대가 남음. |
| 알비노 데몬 | 33/33 | 107 | 붉은 근육·쌍뿔·가시 갑옷·도끼 복원, S 반대발 지지와 NW 도끼손 보완 | S 지지·NW 오른손 도끼 보완. E의 SE성 몸통/같은 지지발, NW 공격 접촉·일부 방향 검토 잔여. |
| 커츠 | 19/33 | 76 | 큰 가시 갑옷·붉은 망토·대검 복원, S RUN 반대 부츠 지지 및 SW 대검 동작 보완 | 필수14클립 미제작. W/NW 카메라 및 일부 공격손·지지/접촉 검토 잔여. |

## 검증과 보존

각 배치는 실제 PNG·alpha·프레임 수·AtlasTexture 범위·RGBA·SpriteFrames 로드와 원본 ActorMotion/Godot 4.7.2 재생을 검사했다. 여왕은 RUN/전투 입력296파일을 SHA 대조한 뒤 32트랙의 원본 프레임 순서·FPS·loop·duration·방향별 논리 캔버스를 보존해 합쳤다. N RUN은 `unavailable`이며 과거 잘못된 N 소스로 폴백하지 않는다.

최신4종은 실제 DB 이동속도와 reference_speed, native pixel_scale·offset·canvas metadata를 사용해 speed_scale1/카메라1배의 Xvfb/llvmpipe 진단 arena에서 렌더링했다. 이 검사는 실제 Main의 전투·물리 접촉 최종 승인이 아니다. [렌더링 영수증](evidence/pr122-monsters-20261023/boss-repair-session/arena-r002/receipt.json)

좀비로드 r001의 E/S 지지 반복은 독립 실물 검토에서도 확인해 HOLD로 남겼으며, r002는 S의 해부 RIGHT×3→LEFT×3 지지열을 새6포즈로 교체했다. E 반복은 미해결이다. 알비노데몬 E는 추가 원화와 관절가이드 실험도 실제 생성했으나 카메라/발/무기손 목표를 충족하지 못해 실패본으로 보존했다. 해당 실험을 선택 포즈나 신규 완료로 계산하지 않았다.

기존 승인·PNG·WALK·다방향 DEATH·과거 후보·실패본을 삭제하지 않았다. 일반 완료221/잔여37, 보스 기존 승인43/잔여17은 유지했다. 알비노데몬은 실제 소스 제작으로 미제작에서 제작 중으로 이동했다. 기존 원본 승인 장부와 기본 runtime 카탈로그는 변경하지 않았다. 전체 CI는 반복하지 않았고 제작 커밋은 `[skip ci]`로 저장했다.

새 선택은 [보스 staging ledger](../../data/pr122_monster_boss_repair_staging.json), 전체 수치·해시·검토 범위는 [세션 결과](evidence/pr122-monsters-20261023/boss-repair-session/session-summary.json)에 있다. 대표 실제 PNG4개 8,835,038바이트를 GitHub에서 다시 다운로드하여 모두 로컬과 SHA가 일치했다. 다른 파일도 커밋 전 실제 파일/핀을 검증한다. 채팅 이미지/Base64 출력은 하지 않았다.

재현: `collect_candidates.py` → `tools/reclassify_pr122_monsters.py --check` → `verify_preservation.py` → `summarize_repairs.py`. 렌더링은 `boss-fix-runtime/run.py`와 저장된 `arena-cases-r002.json`을 사용한다. source 기준 커밋: `88516cfcb303b9c8f288abf72d1cc477aed62ebf`.
