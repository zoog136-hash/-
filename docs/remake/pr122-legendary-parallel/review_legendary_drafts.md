# Legendary staging playback viewer

최종 1,320개 초안을 저장한 뒤 사용할 읽기 전용 검토 뷰어입니다. 현재 준비한 도구이며 전체 재생·품질 검사·최종 승인을 수행한 기록은 아닙니다.

저장소 루트에서 Godot 4.7.2로 다음 장면을 실행합니다. 기존 플레이어 저장 데이터와 분리된 쓰기 가능한 XDG 경로를 사용합니다.

```bash
mkdir -p /tmp/twilight-legendary-review/data /tmp/twilight-legendary-review/cache /tmp/twilight-legendary-review/config
XDG_DATA_HOME=/tmp/twilight-legendary-review/data XDG_CACHE_HOME=/tmp/twilight-legendary-review/cache XDG_CONFIG_HOME=/tmp/twilight-legendary-review/config godot --path . res://docs/remake/pr122-legendary-parallel/review_legendary_drafts.tscn
```

`data/pr122_legendary_parallel_staging.json`의 40 ID와 각 `drafts` 항목을 읽습니다. 캐릭터·방향·동작을 선택하면 해당 SpriteFrames를 실제 AnimatedSprite2D로 재생하며, 원본 카탈로그 이미지를 옆에 표시합니다. PNG와 SpriteFrames는 기록된 SHA와 일치하는 전설 전용 경로에서 읽습니다. 없는 방향이나 파일을 대체 자산으로 채우지 않습니다.

- `This actor x33`: 선택 캐릭터의 8방향 IDLE/RUN/ATTACK/HIT와 S DEATH를 차례로 재생합니다.
- `All actors x33`: 같은 순서로 40종, 총 1,320개 구성을 재생합니다. 각 루프는 두 바퀴, 단발 동작은 한 번 재생합니다.
- DEATH는 S 원화 한 번 재생 후 마지막 프레임을 유지합니다. 순차 재생에서는 마지막 자세를 추가로 0.75초 보여준 뒤 다음 항목으로 이동합니다.
- `R`: 현재 동작을 명시적으로 다시 재생합니다. `Space`: 일시정지/계속. 좌우 화살표: 방향 변경.
- Speed는 재생 속도, Zoom은 화면 배율입니다. 동일 트랙의 모든 프레임에 같은 화면 배율을 적용하여 프레임별 크기·등록 차이를 숨기지 않습니다. PNG 픽셀은 바꾸지 않습니다.

신화급 `docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/generated_motion_draft_test_v02.gd`의 raw ImageTexture 생성·`take_over_path`·실제 AnimatedSprite2D 재생 방식을 재사용합니다. 참고한 파일의 SHA-256은 `86785a45d5089f46c448a6c3ce88eb8cf7666232a2b50145518d49c39ddf9952`입니다. 혼합 재사용 트랙은 기록된 모든 source_files를 같은 방식으로 연결하고 원래 프레임별 duration을 유지합니다.

뷰어는 원화·리소스·카탈로그·전투·플레이어 런타임·원장을 수정하지 않으며 승인이나 검사 PASS 파일을 만들지 않습니다. 순차 재생 완료도 품질 승인으로 집계하지 않습니다.
