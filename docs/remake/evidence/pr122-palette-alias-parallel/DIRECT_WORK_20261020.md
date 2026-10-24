# PR122 색상·이름 파생 직접 작업 — 코드 구현 / 아트 완료 아님

## 실제 수행

Codex 호출 없이 별도 작업 공간에서 직접 코드를 작성하고 Python 회귀 테스트를 실행했다. 대상 브랜치는 `feature/pr122-palette-alias-20261020`, 작업 전 HEAD는 `855047df03d61ec6ba7de2c7d89a461391b3a5c1`이다. 기존 PR122 브랜치는 `500ac94f0826aeeb93a9eb325f72b15165c15382`, 확인한 main은 `8b9e8e31a0919d7739e8f331260254a6a2feea90`이다. main이나 기존 외형 제작 브랜치를 바꾸지 않는다.

- `tools/pr122_palette_alias_pipeline.py`: 실제 RGBA PNG에 명시적인 L 모드 부위 마스크를 적용해 색상 파생 시트와 SpriteFrames를 생성한다. 마스크 밖 픽셀 및 원본 알파는 그대로 유지한다. 원본 명암은 HSV value 기준으로 보존한다. PNG 경로를 제외한 SpriteFrames 텍스트가 같은지 역치환하여 검사한다. 이름 파생은 원본 SpriteFrames를 참조하고 PNG를 복제하지 않는다.
- 원형/모션/마스크 검토, 타깃·원형 레코드 해시, 전체 텍스처·마스크 SHA, 원형 의존 관계, 다른 작업자 소유권, 경로 탈출, 기존 출력 덮어쓰기를 검사한다. 공용 카탈로그는 자동 수정하지 않고 조건부 통합 패치만 생성한다. 기존 tint를 중복 적용하지 않도록 생성 패치의 color_tint는 흰색이다.
- `assets/actors/eight_direction/palette_alias_pr122/`: 랜스 마스터 레드179·블루182를 따로 인스턴스화하는 검토용 장면2개와 공통 재생 장면을 작성했다. 현재 공용 원본 SpriteFrames를 읽기 전용으로 참조하고 인스턴스별 색을 분리한다. 키보드 화살표로 트랙 변경, Space로 일시정지한다.
- `tests/pr122_palette_alias_test.py`: 합성 fixture 대상30개 테스트를 실제 실행하여 통과했다. 보호 픽셀·알파·명암·리소스 메타데이터 보존, 별칭 무복제, 해시 변경, 의존 순환, 소유권, 덮어쓰기 차단 등을 검사했다. 합성 테스트 아트는 납품 아트로 저장하지 않는다.
- `tests/pr122_palette_alias_smoke.gd`: 실제 저장소에서 실행할 전용 Godot 재생 검사도 작성했다. 현재 환경에서는 실행하지 않았다.

## 절대 구분할 것

검토용 레드·블루 장면은 **기존 전체 tint를 재생하는 비교 장면**이다. 새 부위 마스크 완성본이나 신규 모션 제작이 아니다. 기존54프로필에 이미 포함된 두 항목을 신규 연결·승인으로 중복 계산하지 않는다.

원격 원본 SpriteFrames의 텍스트에서 방향8개 × idle/walk/attack/hit/death = 40트랙, 프레임 참조104개를 확인했다. 방향당 프레임은2/3/3/2/3이다. walk는3프레임이고 run은 없다. donor transform:176의 이동 모션 보완 소유권과 기존 원형 미검증 상태를 유지한다. 원형·부위 마스크를 임의로 승인하지 않았다.

**현재 실적: 생성기 코드1개, Python 테스트30개 통과, 검토용 대상 장면2개 작성. 신규 모션0, 새 색상 PNG0, 새 게임 연결0, 신규 원작 외형 승인0.**

## 실행

```bash
python -m unittest discover -s tests -p 'pr122_palette_alias_test.py'
godot --path . assets/actors/eight_direction/palette_alias_pr122/Preview.tscn
godot --headless --path . --script tests/pr122_palette_alias_smoke.gd
```

완료된 동일 외형 근거와 부위 마스크가 있을 때만 recipe를 만들어 아래 생성기를 사용한다. 현재 두 검토 대상은 production_ready=false이므로 완료 대상으로 승격하지 않는다. 생성 전 최신 mythic/native 큐의 전체 소유 대상 ID 목록을 `--protected-targets`에 전달한다.

```bash
python tools/pr122_palette_alias_pipeline.py --root . --recipe reviewed_recipe.json --protected-targets latest_native_owners.json
```

출력 위치는 `assets/actors/eight_direction/palette_alias_pr122/generated/<slug>/`로 제한된다. `integration_patch.json`은 해당 폴더의 출력 작성 후 마지막에 게시되며 자동 게임 반영은 없다. 통합 담당자가 최신 레코드/모든 리소스 해시와 실제 Godot 재생을 재검증한 후에만 적용해야 한다. 시트 또는 원형이 바뀌면 예전 패치를 재사용하지 않는다.

## 검증 한계와 보존

이 환경에는 전체 저장소 체크아웃, Godot 실행기, 실제 원본 시트 바이트가 없다. GitHub 연결을 통한 원격 코드·리소스 메타데이터 읽기와 로컬 코드/합성 이미지 테스트만 수행했다. 정규 `check_resource_integrity.py --root .`, Godot import/재생, Main 렌더, Android 실기는 모두 NOT_RUN이다. source_frames_sha256은 기존 장부 값을 실행 시 검사하도록 고정한 것이며 이 환경에서 원본 바이너리 전체를 검증했다는 뜻이 아니다.

기존 공용 카탈로그·원본 SpriteFrames/PNG·native 큐·승인·맵·전투·AI·드랍·저장 파일은 변경하지 않는다. 전체 CI, 새 PR, main/PR122 병합, rebase, force push, 채팅 이미지 첨부를 요청하지 않았다. 이전 Codex 사용 한도 영수증은 기록으로 남기며, 이 작업을 Codex 착수로 변경하지 않는다.
