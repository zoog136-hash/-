# 523 획득처 안내 · 혈맹 문장 — 표에 없는 세부 규칙

원본 523 표(`tables/source.zip`, 기존 로더 `current523_definition_rows`)로 구현한 범위와,
표에 없어서 **지어내지 않고** 거부·보존한 규칙의 목록이다.

## (A) 획득처 안내 (`scripts/acquisition523/item_acquisition523.gd`)

### 표로 확인된 것 (구현)

| 원본 표 | 쓰는 값 | 화면 |
| --- | --- | --- |
| ItemAcquisition(65행) → ItemAcquisitionSubCategory(8) → ItemAcquisitionCategory(2) | ItemCategoryID → 하위 분류(EtcCurrency, ScrollEnchant …) → 분류(Etc / Scroll) | 인벤토리 상세의 "원본 획득 분류" 줄 |
| NpcItemDropView | ItemClassID → NpcClassID | 원본 팝업 `몬스터` 열 |
| NpcClass(TestNPC 제외) · NpcCategory.IsShowDropInfo | 드롭 정보를 보여 줄 몬스터 | 드롭 목록 필터 |
| NpcSpawnPackNpcClassView(IsSpawn 1) → NpcSpawnPackTerritory → Territories(ShowInSourceList, DescID) | 몬스터가 나오는 구역 이름 | `획득 장소` 열 |
| ItemCraftInputSource(5행, SourceOrder, DescID) | 드롭이 아닌 출처 문구(시련 던전, 월드 보스, 파티던전(오림)) | `획득 방법` 목록 |
| ItemClass.GettablePlaceID → TooltipMarketDisplayCategory → MarketDisplayCategoryType(DescID) | 상점 탭 이름(패키지, 데일리 …) | `획득 방법` "상점 · 탭" → 상점 창 |
| ItemDropBySpecialDungeonView → SpecialDungeon → LandTeleportTerritories → Territories | 특수 던전 이름 | `획득 방법` "던전 · 이름" → 던전 창 |
| ItemCraftOutputView(ItemClassID) | 그 아이템을 만드는 ItemCraftID | 제작 목록 → 제작 창의 해당 제작식(`patch523:<ID>`가 게임에 있을 때만) |

원본 UI: `Production/Production_Popup_Source.csb`(제목 "재료 아이템 출처") +
`Production_List_Source` / `Production_List_Acquirement` / `Production_List_Source_Text_Set` /
`Production_List_Source_Text` / `CommonUi/Common_Slot`.

### 표에 없는 규칙 (지어내지 않음)

1. **ItemAcquisition 표의 용도.** 행은 아이템 분류(ItemCategoryID)를 Etc/Scroll 하위 분류로
   묶을 뿐 장소·상점·몬스터를 가리키지 않는다. DescID도 없어 한글 분류명이 없다. 영문 원본 이름
   그대로 보여 주며, 어떤 화면(획득 알림 필터 등)에서 쓰는지는 표에 없다.
2. **GettablePlaceID의 뜻.** 0~24 값의 이름 표가 없다. TooltipMarketDisplayCategory에 있는 7개 값
   (2,3,4,5,6,7,24)만 상점 탭으로 연결했다. 1·8·9·10 등 나머지 값의 의미는 보존(표시 안 함).
3. **상점 탭으로 바로 이동.** 원본 상점 창(Shop_All)에 MarketDisplayCategoryType 탭 선택이 아직
   연결돼 있지 않아 상점 창 전체를 연다(탭 선택 없음).
4. **여러 종류의 출처가 있을 때 어떤 목록을 보일지.** 팝업은 목록을 하나만 보인다. 순서 규칙이 표에
   없어 ItemCraftInputSource 행 → 몬스터 드롭 → 그 밖의 획득 방법 → 제작 순으로 고른다
   (ItemCraftInputSource는 드롭이 아닌 출처만 적는 표라 그 행이 있으면 우선).
5. **목록 정렬과 최대 개수.** 원본 정렬 규칙이 없어 표 순서를 따른다. 몬스터 80행, 제작 40개까지
   만들고 전체 수는 따로 보고한다.
6. **장소가 없는 몬스터.** 스폰 표에 ShowInSourceList 구역이 없는 몬스터(보스·이벤트 등)는 장소를
   "-"로 둔다. 원본이 이런 몬스터를 숨기는지 표에 없다.
7. **NpcItemDropView.RequiredQuestID, Bless.** 표시 조건으로 쓰이는지 표에 없어 걸러 내지 않는다.
8. **ItemCraftOutputView.ItemCraftOutputTypeID(0/1/2/12/22/32/42).** 이름 표가 없다. 출력 종류와
   상관없이 그 아이템을 내는 제작식을 모으고, 게임에 실제 제작식이 있는 것만 연결한다.
9. **제작 목록이 "이 재료로 만드는 아이템"인지 "이 재료를 만드는 제작식"인지.** UI 문구만 있고 표가
   없다. 출처(재료를 얻는 곳) 팝업이므로 그 아이템을 **만드는** 제작식으로 연결했다.
10. **토템 목록(Totem/Totem_List_Source.csb).** 같은 팝업의 토템 출처 행은 어떤 표가 채우는지
    확인되지 않아 연결하지 않았다.
11. **몬스터/장소 행 터치 이동.** 원본 행(Production_List_Source)에 버튼이 없어 이동하지 않는다.
    ItemCraftInputSource 문구(시련 던전·월드 보스 …)도 목적지 ID가 없어 문구만 보인다.

## (B) 혈맹 문장 (`scripts/emblem523/emblem523.gd`)

### 온라인 전용 사실

리니지M의 문장(Emblem)은 **혈맹 문장**이다. 혈맹 군주가 고르고(Clan_Popup_Symbol), 혈맹 레벨에
따라 열리며(Emblem.OpenGrade = ClanExperience 레벨 1~20, 99), 혈맹원 이름 옆(UIOverhead "Emblem",
NameCard_AllianceLayout)에 보인다. TWILIGHT에는 혈맹이 없으므로 혈맹 생성·가입·혈맹 레벨·다른
플레이어 표시·연합(Coalition) 문장·텍스트 문장은 온라인 전용으로 제외했다.

### 표로 확인된 것 (구현)

| 원본 표 | 쓰는 값 |
| --- | --- |
| EmblemSelectionRegion_Korean(298행, LanguageID = Korean) | 한국 선택 목록과 순서 |
| Emblem(388행) | EmblemLargeID / EmblemSmallID / Type / OpenGrade / descID |
| AssetView · AssetType #111 "Emblem"(Path UI/Emblem/) | 원본 PNG(Guild_*), 523 UI 팩에 원본 그대로 포함 |
| EmblemType | Predefined / Userdefined / Systemdefined / Coalition_* |
| DescData_Korean | 문장 이름(일반 01, 특수 11 …) |
| ClanExperience | 혈맹 레벨 1~20 (OpenGrade 잠금 숫자) |
| ClanPolicies "EmblemChangeCommission" | 변경 수수료 Value 0 (ItemClassID 26 아데나) → 무료 |

원본 UI: `Clan/Clan_Popup_Symbol.csb`(이미지 문장 탭, 미리 보기, 확인/닫기),
`Clan_Tab_Mark` → `Clan_Mark_FlagSlot_Set`(5칸) → `Clan_Mark_FlagSlot`(그림, 이름, 잠금 표시 Label_Help).
선택은 저장(`emblem523` = {schema 1, emblem_id})되고 다시 불러와도 유지된다.

### 표에 없는 규칙 (지어내지 않음)

1. **로컬 혈맹 레벨.** 오프라인에는 혈맹 레벨이 없다. TWILIGHT 결정: ClanExperience의 첫 레벨(1)과
   같은 OpenGrade의 **Predefined** 문장(42개)만 고를 수 있고, 나머지는 원본 잠금 표시(Label_Help에
   OpenGrade)로 둔다. 혈맹 레벨을 올리는 규칙은 만들지 않았다.
2. **Userdefined(특수 문장) 해금 방법.** 특수 문장을 여는 조건(구매·이벤트 등)이 표에 없다. 잠금 유지.
3. **Systemdefined(붉은기사단 등) · Coalition 문장.** 시스템/연합 전용이며 사용 조건이 표에 없다. 잠금 유지.
4. **문장 효과.** 어떤 표에도 문장의 능력치·버프 열이 없다. 효과 없음(표시용).
5. **문장이 보이는 곳.** 원본은 혈맹원 이름표(UIOverhead SlotID 24)에 보인다. 혈맹이 없는 로컬
   캐릭터 이름표에 붙일지는 원본 규칙이 없어 이름표에는 붙이지 않았다(선택 창 미리 보기에만 보임).
6. **텍스트 문장(Clan_Tab_Mark_Request).** 혈맹이 입력하는 글자 문장으로 표 행이 없다. 연결 안 함.
7. **변경 쿨타임·권한(군주만 변경).** 표에 없다(권한은 혈맹 전용). 수수료가 0이 아니게 바뀌면 지불
   경로가 없으므로 거부한다.
8. **CompanionEmblem(5행) · SiegeCompetitionEmblem(9행).** 동료 NPC 문장 그림 / 공성 경쟁 문장으로,
   각각 동료 표시·공성(온라인 전용) 화면에 속한다. 이번 선택 창과 무관해 연결하지 않았다.
9. **ItemCategory "Emblem"(10654) 아이템 211개.** 이름은 "문장"이지만 휘장류 이벤트 아이템(카네이션,
   태극기 등)으로 Emblem 표와 연결 고리가 없다.
