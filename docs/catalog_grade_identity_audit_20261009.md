# TWILIGHT 아이템 도감 원본 등급·ID 검증 감사표 (2026-10-09)

기준: `zoog136-hash/-`의 `main` **82dbbdb18ec3088fcf521ce887af61c0c48c5a28**, 그리고 [리니지M 인벤 아이템 DB](https://lineagem.inven.co.kr/db/item/) 원본 ID / 추출 시 보존된 원본 이미지 URL.
이 문서는 도감 수정의 근거, **미확인 사항**, 데이터 손실 방지 범위를 기록합니다. 원작 스탯 또는 공식 아이템 등급 전수 확인이 완료됐다는 뜻이 아닙니다.

## 규모와 유지 보증

- 변신: **413**
- 마법인형: **166**
- 성물: **144**
- 아이템: **2129**
- 총 **2,852개** 도감 항목 중 아이템 **2,129개**.
- 이미지 경로와 `sourceId`를 건드리지 않고 등급 렌더링만 보정하며 원본 등급은 `grade_original`에 남깁니다.
- `sourceId`는 2,129개 아이템 전부 고유합니다. **이름**은 29종에서 중복하며 추가 동일이름 행은 44개입니다.
- 모든 비장비 도감과 저장 데이터의 이름 기반 레거시 키를 그대로 유지합니다.

## 장비 이미지 파일명으로 판정 가능한 잠정 등급 (32개)

아래 32개 항목은 원본 자료의 이미지 파일명에 명시적인 구분 토큰 `hero` 또는 `legend`가 있고 장비 슬롯인 경우만 등급을 복구합니다.
이는 **파일명 기준 추론**으로, 전체 아이템의 최종 원작 등급 확정이 아닙니다. 고유·신화 기존 등급은 덮어쓰지 않습니다.

| 원본 ID | 아이템 | 기존 등급 | 이미지 단서 등급 |
|---|---|---|---|
| [152722](https://lineagem.inven.co.kr/db/item/152722) | 영웅의 빛나는 민첩 티셔츠 | 일반 | 영웅 (`191204_bm_hero_t_dex`) |
| [233812](https://lineagem.inven.co.kr/db/item/233812) | 영웅의 빛나는 성장 티셔츠 | 일반 | 영웅 (`bm_tshirt_growup_hero`) |
| [152712](https://lineagem.inven.co.kr/db/item/152712) | 영웅의 빛나는 완력 티셔츠 | 일반 | 영웅 (`191204_bm_hero_t_str`) |
| [152732](https://lineagem.inven.co.kr/db/item/152732) | 영웅의 빛나는 지식 티셔츠 | 일반 | 영웅 (`191204_bm_hero_t_int`) |
| [233832](https://lineagem.inven.co.kr/db/item/233832) | 영웅의 빛나는 흑묘 티셔츠 | 일반 | 영웅 (`bm_tshirt_growup_rabbit_hero`) |
| [344421](https://lineagem.inven.co.kr/db/item/344421) | 진 기억의 망토 | 일반 | 전설 (`2025_12_memoryisland_cloak_legend`) |
| [344361](https://lineagem.inven.co.kr/db/item/344361) | 기억의 망토 | 희귀 | 영웅 (`2025_12_memoryisland_cloak_hero`) |
| [344481](https://lineagem.inven.co.kr/db/item/344481) | 봉인된 기억의 망토 | 희귀 | 영웅 (`20251217_sealed_memoryisland_cloak_hero`) |
| [344451](https://lineagem.inven.co.kr/db/item/344451) | 진 기억의 가더 | 일반 | 전설 (`2025_12_memoryisland_garder_legend`) |
| [344431](https://lineagem.inven.co.kr/db/item/344431) | 진 기억의 방패 | 일반 | 전설 (`2025_12_memoryisland_shield_legend`) |
| [344391](https://lineagem.inven.co.kr/db/item/344391) | 기억의 가더 | 희귀 | 영웅 (`2025_12_memoryisland_garder_hero`) |
| [344371](https://lineagem.inven.co.kr/db/item/344371) | 기억의 방패 | 희귀 | 영웅 (`2025_12_memoryisland_shield_hero`) |
| [344511](https://lineagem.inven.co.kr/db/item/344511) | 봉인된 기억의 가더 | 희귀 | 영웅 (`20251217_sealed_memoryisland_garder_hero`) |
| [344491](https://lineagem.inven.co.kr/db/item/344491) | 봉인된 기억의 방패 | 희귀 | 영웅 (`20251217_sealed_memoryisland_shield_hero`) |
| [276058](https://lineagem.inven.co.kr/db/item/276058) | 영웅의 빛나는 성장 견갑 | 일반 | 영웅 (`bm_spaulder_growup_hero`) |
| [276808](https://lineagem.inven.co.kr/db/item/276808) | 영웅의 빛나는 청룡 견갑 | 일반 | 영웅 (`bm_spaulder_growup_dragon_hero`) |
| [366478](https://lineagem.inven.co.kr/db/item/366478) | 마프르의 귀걸이 | 일반 | 전설 (`2609_earth_earring_legend`) |
| [366488](https://lineagem.inven.co.kr/db/item/366488) | 마프르의 귀걸이 (각인) | 일반 | 전설 (`2609_earth_earring_legend`) |
| [366458](https://lineagem.inven.co.kr/db/item/366458) | 사이하의 귀걸이 | 일반 | 전설 (`2609_wind_earring_legend`) |
| [366468](https://lineagem.inven.co.kr/db/item/366468) | 사이하의 귀걸이 (각인) | 일반 | 전설 (`2609_wind_earring_legend`) |
| [366438](https://lineagem.inven.co.kr/db/item/366438) | 에바의 귀걸이 | 일반 | 전설 (`2609_water_earring_legend`) |
| [366448](https://lineagem.inven.co.kr/db/item/366448) | 에바의 귀걸이 (각인) | 일반 | 전설 (`2609_water_earring_legend`) |
| [366498](https://lineagem.inven.co.kr/db/item/366498) | 파아그리오의 귀걸이 | 일반 | 전설 (`2609_fire_earring_legend`) |
| [366508](https://lineagem.inven.co.kr/db/item/366508) | 파아그리오의 귀걸이 (각인) | 일반 | 전설 (`2609_fire_earring_legend`) |
| [149373](https://lineagem.inven.co.kr/db/item/149373) | 데몬의 팔찌 | 일반 | 전설 (`2020_2_19_legend_daemon_bracelet`) |
| [149383](https://lineagem.inven.co.kr/db/item/149383) | 드래곤의 팔찌 | 일반 | 전설 (`2020_2_19_legend_dragon_bracelet`) |
| [149353](https://lineagem.inven.co.kr/db/item/149353) | 민첩의 팔찌 | 희귀 | 영웅 (`2020_2_19_hero_bracelet_dex`) |
| [152091](https://lineagem.inven.co.kr/db/item/152091) | 민첩의 팔찌 (각인) | 희귀 | 영웅 (`2020_2_19_hero_bracelet_dex`) |
| [149343](https://lineagem.inven.co.kr/db/item/149343) | 완력의 팔찌 | 희귀 | 영웅 (`2020_2_19_hero_bracelet_str`) |
| [152081](https://lineagem.inven.co.kr/db/item/152081) | 완력의 팔찌 (각인) | 희귀 | 영웅 (`2020_2_19_hero_bracelet_str`) |
| [149363](https://lineagem.inven.co.kr/db/item/149363) | 지식의 팔찌 | 희귀 | 영웅 (`2020_2_19_hero_bracelet_int`) |
| [152101](https://lineagem.inven.co.kr/db/item/152101) | 지식의 팔찌 (각인) | 희귀 | 영웅 (`2020_2_19_hero_bracelet_int`) |

## 동일 이름 / 서로 다른 Inven 원본 ID (29종)

이름이 같아도 다른 레코드를 삭제·합치지 않습니다. 장비는 테스트 지급 때 `sourceId`를 각 물리적 장비 인스턴스에 기록하고, 선택·장착·저장 후 재불러오기에서 우선 사용합니다.
비장비 동명이품은 구형 인벤토리의 이름별 수량 통합 위험 때문에 개발 테스트 지급을 제한합니다. 아이템 드랍·상점 등 기존 이름 전용 경로는 향후 전면 ID 기반 이전이 필요합니다.

| 이름 | 원본 ID들 |
|---|---|
| 헌팅 라이플 (각인) | [97794](https://lineagem.inven.co.kr/db/item/97794), [96864](https://lineagem.inven.co.kr/db/item/96864) |
| 전사단 투구 (각인) | [159521](https://lineagem.inven.co.kr/db/item/159521), [157381](https://lineagem.inven.co.kr/db/item/157381) |
| 제브 레퀴의 마안 (각인) | [8731](https://lineagem.inven.co.kr/db/item/8731), [645](https://lineagem.inven.co.kr/db/item/645) |
| 제브 레퀴의 송곳니 (각인) | [8741](https://lineagem.inven.co.kr/db/item/8741), [647](https://lineagem.inven.co.kr/db/item/647) |
| 7주년 기념 귀걸이 | [287102](https://lineagem.inven.co.kr/db/item/287102), [287473](https://lineagem.inven.co.kr/db/item/287473) |
| 희귀 마법인형 카드 상자 | [127604](https://lineagem.inven.co.kr/db/item/127604), [259513](https://lineagem.inven.co.kr/db/item/259513) |
| 희귀 변신 카드 상자 | [127594](https://lineagem.inven.co.kr/db/item/127594), [259503](https://lineagem.inven.co.kr/db/item/259503) |
| 다크엘프 병사의 배지 | [30651](https://lineagem.inven.co.kr/db/item/30651), [118692](https://lineagem.inven.co.kr/db/item/118692) |
| 다크엘프 장군의 배지 | [30661](https://lineagem.inven.co.kr/db/item/30661), [118702](https://lineagem.inven.co.kr/db/item/118702) |
| 룸티스의 귀걸이 교환 증서 | [161303](https://lineagem.inven.co.kr/db/item/161303), [99833](https://lineagem.inven.co.kr/db/item/99833) |
| 만능 충전석(각인) | [363598](https://lineagem.inven.co.kr/db/item/363598), [243651](https://lineagem.inven.co.kr/db/item/243651) |
| 스냅퍼의 반지 교환 증서 | [99843](https://lineagem.inven.co.kr/db/item/99843), [161293](https://lineagem.inven.co.kr/db/item/161293) |
| 룬 변환석 조각 | [167184](https://lineagem.inven.co.kr/db/item/167184), [215923](https://lineagem.inven.co.kr/db/item/215923) |
| 봉인된 희귀 방어구 제작 비법서 (각인) | [85282](https://lineagem.inven.co.kr/db/item/85282), [32332](https://lineagem.inven.co.kr/db/item/32332) |
| 공포의 지배석 (각인) | [323713](https://lineagem.inven.co.kr/db/item/323713), [323563](https://lineagem.inven.co.kr/db/item/323563), [323413](https://lineagem.inven.co.kr/db/item/323413) |
| 교만의 지배석 (각인) | [323793](https://lineagem.inven.co.kr/db/item/323793), [323643](https://lineagem.inven.co.kr/db/item/323643), [323493](https://lineagem.inven.co.kr/db/item/323493) |
| 분노의 지배석 (각인) | [323823](https://lineagem.inven.co.kr/db/item/323823), [323673](https://lineagem.inven.co.kr/db/item/323673), [323523](https://lineagem.inven.co.kr/db/item/323523) |
| 불멸의 지배석 (각인) | [323773](https://lineagem.inven.co.kr/db/item/323773), [323623](https://lineagem.inven.co.kr/db/item/323623), [323473](https://lineagem.inven.co.kr/db/item/323473) |
| 불사의 지배석 (각인) | [323743](https://lineagem.inven.co.kr/db/item/323743), [323593](https://lineagem.inven.co.kr/db/item/323593), [323443](https://lineagem.inven.co.kr/db/item/323443) |
| 불신의 지배석 (각인) | [323703](https://lineagem.inven.co.kr/db/item/323703), [323553](https://lineagem.inven.co.kr/db/item/323553), [323403](https://lineagem.inven.co.kr/db/item/323403) |
| 사신의 지배석 (각인) | [323833](https://lineagem.inven.co.kr/db/item/323833), [323683](https://lineagem.inven.co.kr/db/item/323683), [323533](https://lineagem.inven.co.kr/db/item/323533) |
| 어둠의 지배석 (각인) | [323763](https://lineagem.inven.co.kr/db/item/323763), [323613](https://lineagem.inven.co.kr/db/item/323613), [323463](https://lineagem.inven.co.kr/db/item/323463) |
| 오만의 지배석 (각인) | [323783](https://lineagem.inven.co.kr/db/item/323783), [323633](https://lineagem.inven.co.kr/db/item/323633), [323483](https://lineagem.inven.co.kr/db/item/323483) |
| 왜곡의 지배석 (각인) | [323693](https://lineagem.inven.co.kr/db/item/323693), [323543](https://lineagem.inven.co.kr/db/item/323543), [323353](https://lineagem.inven.co.kr/db/item/323353) |
| 잔혹의 지배석 (각인) | [323753](https://lineagem.inven.co.kr/db/item/323753), [323603](https://lineagem.inven.co.kr/db/item/323603), [323453](https://lineagem.inven.co.kr/db/item/323453) |
| 죽음의 지배석 (각인) | [323723](https://lineagem.inven.co.kr/db/item/323723), [323573](https://lineagem.inven.co.kr/db/item/323573), [323423](https://lineagem.inven.co.kr/db/item/323423) |
| 지옥의 지배석 (각인) | [323733](https://lineagem.inven.co.kr/db/item/323733), [323583](https://lineagem.inven.co.kr/db/item/323583), [323433](https://lineagem.inven.co.kr/db/item/323433) |
| 질투의 지배석 (각인) | [323813](https://lineagem.inven.co.kr/db/item/323813), [323663](https://lineagem.inven.co.kr/db/item/323663), [323513](https://lineagem.inven.co.kr/db/item/323513) |
| 탐욕의 지배석 (각인) | [323803](https://lineagem.inven.co.kr/db/item/323803), [323653](https://lineagem.inven.co.kr/db/item/323653), [323503](https://lineagem.inven.co.kr/db/item/323503) |

## 상세 옵션 미수록 644개

| 종류 | 옵션이 없는 레코드 수 |
|---|---:|
| 재료 | 331 |
| 상자 | 266 |
| 이동주문서 | 22 |
| 반지 | 7 |
| 티셔츠 | 4 |
| 목걸이 | 3 |
| 귀걸이 | 3 |
| 팔찌 | 3 |
| 망토 | 2 |
| 장갑 | 2 |
| 벨트 | 1 |
| **전체** | **644** |

옵션이 없는 아이템에 임의 스탯을 부여하지 않고 상세 보기에서 미수록이라고 표시합니다. 상자·재료·이동주문서는 원래 전투 옵션이 없을 수도 있으므로 **옵션 미수록=오류**라고 단정하지 않습니다.

## 구형 DB 등급 불일치 51개

구형 `data/game_db_v17.json`과 현재 상세 도감에서 같은 이름이지만 등급이 다르게 기록된 항목이 **51개**입니다.
과거 수기/테스트 DB와 최신 상세 도감 중 어느 쪽이 옳은지 단순 비교만으로 확정할 수 없으므로 **전량 자동 덮어쓰지 않습니다**.
예시: 생명의 단검, 군터의 단도, 오시리스의 단검, 아스테어의 단검, 달의 장궁.

## 남은 일

- 리니지M 인벤 목록의 원본 등급 표식을 ID로 확보하고 2,129개 장비·재료 전체 비교
- 비장비를 포함한 중복 이름의 수량·드랍·상점·소비 흐름을 `sourceId` 기반으로 변경 (구버전 저장 파일 이전 포함)
- 옵션 미수록 장비 25개의 상세 페이지 개별 검증
- 강화 수치·고유효과·각성·컬렉션은 별도 승인 범위로 유지
