# 원본 수호성 창 슬롯 배치 (TWILIGHT 추정)

원본 523 수호성 창(`UI/SkillTree/SkillTree_All.csb`)의 연결도는 클라이언트 코드가
`ScrollView_SkillTree` 안에 슬롯 아이콘과 연결선을 만들어 넣는다. 원본 자료에 있는 것:

| 원본 값 | 출처 |
| --- | --- |
| 슬롯 격자 좌표 `UIPosX` 1~12, `UIPosY` 1~5 | `SkillTreeSlot` 표 |
| 선행 슬롯 | `SkillTreeSlotPrerequisite` 표 |
| 스크롤 영역 888×430, 안쪽 크기 900×430(가로 스크롤) | `SkillTree_All` `ScrollView_SkillTree` |
| 슬롯 아이콘 86×86 (`Btn_Icon_Skill` / `Btn_Icon_Bonus`) | `SkillTree_Icon_Skill.csb` / `SkillTree_Icon_Bonus.csb` |
| 연결선 조각 32×8 (`SkillTree_Icon_Line.png`) | `Atlas_SkillTree` |

원본에 없는 것: 격자 한 칸의 화면 간격. TWILIGHT 추정(`data/growth/guardian_window_layout.json`
`"status":"TWILIGHT 추정"`, 이 파일 하나에서만 조정):

* 세로 간격 86 = 안쪽 높이 430 / 5줄 = 아이콘 높이 86 (원본 높이가 정확히 5칸).
* 가로 간격 118 = 아이콘 86 + 연결선 조각 한 개 32. 12칸 = 1,416으로 원본 안쪽 너비 900보다
  넓어 가로 스크롤(원본 ScrollView 방향과 같음).
* 첫 칸 중심 (59, 43): 첫 칸 왼쪽·위 여백 = 간격의 절반.
* 연결선: 원본 `SkillTree_Icon_Line` 조각을 두 슬롯 중심 사이 거리만큼 가로로 늘리고 그
  방향으로 돌린다(새 그림 없음). 두 슬롯이 모두 열리면 `Nd_Normal`, 아니면 `Nd_Disable`.
