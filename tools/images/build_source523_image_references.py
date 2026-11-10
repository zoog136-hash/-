#!/usr/bin/env python3
"""Private source523 image adapter audit. No payload decoding or repository writes.

Only schema-named AssetID columns and the explicit exceptions listed below are
examined as image links. Arbitrary integer columns are never probed as AssetIDs.
Source JSON and source ordering remain unchanged; row indexes locate raw inputs.
"""
import argparse
import collections
import gzip
import hashlib
import json
import pathlib

IMAGE_TYPES = {3, 5, 6, 7, 9, 10, 11, 82, 143, 161}
# Curated source-schema contracts. An unfamiliar column, integer, name, filename
# or source table cannot opt itself into this registry by matching a heuristic.
# The source spelling DisplayBaseAsserID is intentional.
IMAGE_FIELD_CONTRACTS = {
    'BuffCard': ['DisplayBaseAssetID','DisplayScreenAssetID','DisplayDecoAssetID','IllustrationAssetID','HidedIllustrationAssetID'],
    'BuffCardByClass': ['DisplayBaseAssetID','DisplayScreenAssetID','DisplayDecoAssetID','IllustrationAssetID','HidedIllustrationAssetID'],
    'BuffCardSpriteCustomizingOption': ['DisplayBaseAssetID','DisplayScreenAssetID'],
    'CastleClass': ['AssetID'],
    'Challenge': ['MiniAssetID','FullAssetID','CutSceneAssetID'],
    'ClanBossRaidView': ['MiniAssetID'],
    'ClanQuestType': ['SymbolAssetId'],
    'Companion': ['DisplayAssetID'],
    'CompetitionDungeonAsset': ['EntranceAssetId','HelpBoxAssetId','HudAlarmAssetId','HotTimeHudAlarmAssetId','WarZoneTimeHudAlarmAssetId'],
    'CompetitionDungeonView': ['CurrencyAssetId'],
    'Currency': ['AssetID','LockedAssetID'],
    'DominationStoneFloor': ['AssetID'],
    'ElfForestDefenseGrade': ['AssetID'],
    'GoalType': ['SymbolAssetId'],
    'GradeTier': ['AssetID'],
    'MapBackgroundView': ['CloudAssetId','SkyAssetId'],
    'MarketPurchase_Korean': ['AssetID'],
    'MasteryWeaponType': ['AssetID'],
    'MiniGame': ['BgAssetID'],
    'MiniGameSupporter': ['IconAssetID','NameTitleAssetID','BgAssetID'],
    'MiniGameSupporterGroup': ['IconAssetID'],
    'NpcClass': ['IllustAssetID'],
    'NpcClassBuffCardMapping': ['DisplayBaseAsserID','DisplayScreenAssetID','DisplayDecoAssetID'],
    'NpcNavigationView': ['IconAssetID'],
    'OrimsTrailCharacter': ['PortraitAssetID'],
    'OrimsTrailNpcType': ['AssetID'],
    'PartyDungeonAsset': ['EntranceAssetId','PopupAssetId','CutSceneAssetId'],
    'PartyDungeonMenu': ['AssetID'],
    'PassSystem': ['PassBackgroundAssetID','PassNameAssetID','PassRewardAssetID'],
    'Portal': ['AssetID'],
    'Promotion': ['BackgroundAssetID','TitleDescAssetID','BaseRewardAssetID','LeftImageAssetID','RightImageAssetID'],
    'RankAsset': ['SymbolAssetId'],
    'ScreenEffect': ['EffectAssetId'],
    'SeasonDungeon': ['AssetID'],
    'SiegeHelper': ['SiegeAssetID'],
    'SiegeHelperType': ['AssetID'],
    'SkillTreeCategory': ['CardAssetID','EmblemAssetID'],
    'SpecialDungeon': ['EntranceAssetID','HelpBoxAssetID'],
    'TeamType': ['AssetID'],
    'ToDoListUICategory': ['IconAssetId','RecommandBoardAssetId','CustomBoardAssetId','SettingBoardAssetId'],
    'Totem': ['EnchantBGImageAssetID','ClosedAltarImageAssetID','OpenedAltarImageAssetID'],
    'UIAuthProviderIcon': ['SmallAssetId','BigAssetId'],
    'UIBattleArenaGrade': ['AssetID'],
    'UIBuffCardDummyImagePath': ['AssetID'],
    'UICastleInfo': ['EmblemAssetID','MarkAssetID'],
    'UIChallengeExtraRewardList': ['RewardIconID'],
    'UIMapAreaType': ['ImageID'],
    'UIMapImageInfo': ['ImageID'],
    'UIMapSpecialImageInfo': ['AssetID'],
    'UIMapWorld': ['TitleImageID'],
    'UINpcClassAssetMapping': ['ScreenMessageImgAssetId','ImmediatelyCombinationImgAssetId'],
    'UIOmanTower': ['AssetID'],
    'UIOrimsTrailCharacter': ['CharacterImageAssetID'],
    'UIOrimsTrailStage': ['StageBgAssetID'],
    'UISlotImage': ['AssetId'],
    'WorldBossRaidView': ['MiniAssetID','NameSpriteAssetID'],
    'WorldEventNpcIcon': ['AssetID','HudAlarmAssetId'],
}
JOIN_SPECS = [
    ('MarketDisplay', 'PurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('MarketPurchaseGroup', 'PurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('UIMarketPurchase', 'MarketPurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('MarketPurchaseProduct', 'MarketPurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('CompetitionDungeonAsset', 'CompetitionDungeonId', 'CompetitionDungeonView', 'ID'),
    ('PartyDungeonAsset', 'DungeonType', 'PartyDungeonType', 'ID'),
    ('BuffCardByClass', 'BuffCardID', 'BuffCard', 'ID'),
    ('BuffCardByClass', 'ClassID', 'Class', 'ID'),
    ('BuffCardByClass', 'Gender', 'Gender', 'ID'),
    ('BuffCardSpriteCustomizingOption', 'BuffCardID', 'BuffCard', 'ID'),
    ('NpcClassBuffCardMapping', 'NpcClassID', 'NpcClass', 'ID'),
    ('UINpcClassAssetMapping', 'NpcClassID', 'NpcClass', 'ID'),
    ('NpcNavigationView', 'UIMapAreaEarthObjectTypeID', 'UIMapAreaEarthObjectType', 'ID'),
    ('PassSystem', 'PassSystemTypeID', 'PassSystemType', 'ID'),
    ('PassSystem', 'MarketPurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('PassSystem', 'PremiumMarketPurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('AttendanceVersion', 'AttendanceTypeID', 'AttendanceType', 'ID'),
    ('AttendanceReward', 'AttendanceVersionID', 'AttendanceVersion', 'ID'),
    ('AttendanceWeeklyBonus', 'MarketPurchaseID', 'MarketPurchase_Korean', 'ID'),
    ('UIMapWorld', 'MapImageInfoID', 'UIMapImageInfo', 'ID'),
    ('UIMapWorld', 'LandID', 'Land', 'ID'),
    ('UIMapArea', 'MapImageInfoID', 'UIMapImageInfo', 'ID'),
    ('UIMapArea', 'WorldID', 'UIMapWorld', 'ID'),
    ('UIMapArea', 'TypeID', 'UIMapAreaType', 'ID'),
    ('UIMapArea', 'SpecialImageInfoID', 'UIMapSpecialImageInfo', 'ID'),
    ('UIMapArea', 'TerritoryID', 'Territories', 'ID'),
    ('UIMapSiege', 'UIMapImageInfoID', 'UIMapImageInfo', 'ID'),
]


def digest(path):
    return {'path': str(path), 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def require(condition, message):
    """Validation must remain active under python -O."""
    if not condition:
        raise ValueError(message)


def validate_output_destination(output, tables, inventory, script_path):
    """Keep compiled source metadata outside inputs and a public checkout."""
    destination=output.resolve()
    for label, protected in [('source table directory',tables),('inventory handoff',inventory)]:
        require(not destination.is_relative_to(protected.resolve()),
                'Output must be outside the '+label)
    for ancestor in script_path.resolve().parents:
        if (ancestor/'project.godot').is_file():
            require(not destination.is_relative_to(ancestor),
                    'Output must be outside the public project containing this tool')


def load_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def load_lines(path):
    with gzip.open(path, 'rt', encoding='utf-8') as stream:
        return [json.loads(line) for line in stream]


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def write_lines(path, values):
    # mtime=0 makes reruns byte-reproducible when the input metadata is unchanged.
    with path.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as zipped:
            for value in values:
                zipped.write((json.dumps(value, ensure_ascii=False, separators=(',', ':'))+'\n').encode())


def lane(table):
    if table.startswith('MarketPurchase'): return 'shop_BM'
    if table in {'Challenge','CompetitionDungeonAsset','CompetitionDungeonView','PartyDungeonAsset',
                 'PartyDungeonMenu','SpecialDungeon','SeasonDungeon','ClanBossRaidView',
                 'WorldBossRaidView','UIChallengeExtraRewardList'}: return 'mission'
    if table in {'BuffCard','BuffCardByClass','BuffCardSpriteCustomizingOption',
                 'NpcClassBuffCardMapping','UIBuffCardDummyImagePath','Companion'}: return 'card_portrait'
    if table in {'NpcClass','UINpcClassAssetMapping','NpcNavigationView'}: return 'NPC'
    if table == 'PassSystem': return 'pass'
    if table == 'Promotion': return 'attendance_promotion'
    if table == 'MapBackgroundView': return 'MapBG'
    if table.startswith('UIMap') or table == 'Portal': return 'map_image'
    if table == 'SpriteAnimationAsset': return 'emoticon'
    return 'general_image'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tables', dest='source', type=pathlib.Path, required=True, help='Source JSON table directory; inputs remain read-only')
    parser.add_argument('--inventory', dest='handoff', type=pathlib.Path, required=True, help='Inventory handoff directory with source-bindings/ and audit/ metadata')
    parser.add_argument('--output', dest='out', type=pathlib.Path, required=True, help='Private output directory, outside source tables, inventory and the public project')
    args = parser.parse_args()
    validate_output_destination(args.out,args.source,args.handoff,pathlib.Path(__file__))
    args.out.mkdir(parents=True, exist_ok=True)
    cache, schemas, fingerprints = {}, {}, {}

    def rows(table):
        if table not in cache:
            path = args.source/(table+'.json')
            data = load_json(path)
            values = data['rows']
            require(isinstance(values,list),table+' must contain a rows list')
            cache[table] = values
            fingerprints[table] = digest(path)
            fields = list(dict.fromkeys(key for row in values for key in row))
            schemas[table] = {'rows':len(values), 'fields_in_original_first_seen_order':fields,
                              'row_key_shape_variants':len({tuple(row) for row in values})}
            if values and 'ID' in values[0]:
                ids = collections.Counter(row['ID'] for row in values)
                schemas[table]['duplicate_ID_values'] = {str(key):n for key,n in ids.items() if n > 1}
        return cache[table]

    assets = {r['AssetId']:r for r in rows('AssetView')}
    types = {r['ID']:r for r in rows('AssetType')}
    asset_indexes = {r['AssetId']:i for i,r in enumerate(rows('AssetView'))}
    type_indexes = {r['ID']:i for i,r in enumerate(rows('AssetType'))}
    require(len(assets)==len(rows('AssetView')),'Duplicate AssetView key')
    require(len(types)==len(rows('AssetType')),'Duplicate AssetType key')
    binding_path = args.handoff/'source-bindings/all42968_asset_bindings523.jsonl.gz'
    retained_path = args.handoff/'audit/current523_retained_images_lineage_diff.jsonl.gz'
    binding_rows=load_lines(binding_path)
    bindings = {r['asset_id']:r for r in binding_rows}
    retained = load_lines(retained_path)
    retained_by_path = {r['path']:r for r in retained}
    require(len(assets)==len(bindings)==len(binding_rows),'Binding and AssetView counts or uniqueness differ')
    require(len(retained)==len(retained_by_path),'Retained manifest has duplicate member paths')
    for key, asset in assets.items():
        require(key in bindings,'Missing binding for AssetView key '+str(key))
        require(bindings[key]['row']==asset,'Binding raw row differs for AssetView key '+str(key))
        require(asset['AssetTypeId'] in types,'Missing AssetType key '+str(asset['AssetTypeId']))
        require(bindings[key]['path']==types[asset['AssetTypeId']]['Path']+asset['FilePath'],
                'Binding typed path differs for AssetView key '+str(key))

    # Only the curated field contracts are considered. Non-image AssetTypes
    # are recorded as routing exclusions, never image coverage.
    field_specs = []
    candidate_columns = []
    missing_schema_contracts=[]
    for table, fields in sorted(IMAGE_FIELD_CONTRACTS.items()):
        if not (args.source/(table+'.json')).exists():
            missing_schema_contracts.append(table)
            continue
        values = rows(table)
        for field in fields:
            require(all(field in row for row in values),'Missing curated source field '+table+'.'+field)
            counts = collections.Counter(assets.get(row[field], {}).get('AssetTypeId', 'missing') for row in values if row[field])
            selected = any(t in IMAGE_TYPES for t in counts)
            candidate_columns.append({'table':table,'field':field,'nonzero_type_counts':dict(counts),
                                      'selected_image_field':selected})
            # Audit even an all-zero or wholly broken curated field. Otherwise
            # a missing AssetView key could silently remove its own contract.
            field_specs.append((table,field,None))

    # Emoticon tables are cut from the game (user decision 2026-11-10): never read.
    emoticons = []
    emoticon_animation_ids = {r['SpriteAnimationID'] for r in emoticons}
    frames = [(i,r) for i,r in enumerate(rows('SpriteAnimationAsset')) if r['SpriteAnimationID'] in emoticon_animation_ids] if emoticons else []
    require(all(r['AssetID'] in assets and assets[r['AssetID']]['AssetTypeId']==9 for _,r in frames),
            'Emoticon frames must resolve to exact image AssetType contracts')
    if frames: field_specs.append(('SpriteAnimationAsset','AssetID',{i for i,_ in frames}))
    references, missing_source_rows, summaries, covered_by_lane = [], [], [], collections.defaultdict(set)
    for table, field, selected_indexes in field_specs:
        values = rows(table)
        indexes = [i for i in range(len(values)) if selected_indexes is None or i in selected_indexes]
        status_rows, status_ids, target_types = collections.Counter(), collections.defaultdict(set), collections.Counter()
        image_ids, missing_ids, outside_scope_ids = set(), set(), set()
        for i in indexes:
            row = values[i]
            key = row[field]
            if not key:
                status_rows['zero_sentinel'] += 1
                continue
            if key not in assets:
                status_rows['missing_AssetView_key'] += 1
                missing_ids.add(key)
                missing_source_rows.append({'lane':lane(table),'table':table,'row_index_zero':i,
                                            'source_ID':row.get('ID'),'source_table_sha256':fingerprints[table]['sha256'],
                                            'field':field,'asset_id':key,'binding_status':'missing_AssetView_key',
                                            'source_raw':row,'current_pixels_verified_by_this_audit':False,
                                            'pixel_evidence':'unresolved_current_member'})
                continue
            asset = assets[key]
            target_types[asset['AssetTypeId']] += 1
            if asset['AssetTypeId'] not in IMAGE_TYPES:
                outside_scope_ids.add(key)
                status_rows['outside_audited_image_type_scope'] += 1
                continue
            binding = bindings[key]
            status = binding['status']
            status_rows[status] += 1
            status_ids[status].add(key)
            image_ids.add(key)
            name = binding['path']
            reference = {'lane':lane(table),'table':table,'row_index_zero':i,'source_ID':row.get('ID'),
                         'source_table_sha256':fingerprints[table]['sha256'],
                         'field':field,'asset_id':key,'asset_type_id':asset['AssetTypeId'],
                         'path':name,'binding_status':status,
                         'retained_current_inventory_member':name in retained_by_path,
                         'current_pixels_verified_by_this_audit':False,
                         'pixel_evidence':'inherited_retained_member_metadata' if name in retained_by_path and status=='exact_catalog_path' else 'unresolved_current_member',
                         'AssetView':{'table_sha256':fingerprints['AssetView']['sha256'],'row_index_zero':asset_indexes[key],'raw':asset},
                         'AssetType':{'table_sha256':fingerprints['AssetType']['sha256'],'row_index_zero':type_indexes[asset['AssetTypeId']],'raw':types[asset['AssetTypeId']]}}
            # Literal node / selection / exclusion flags remain raw source data.
            reference['source_context'] = {k:v for k,v in row.items() if
                k in {'Name','TestNPC','IsActive','IsEnabled','ClassID','Gender','GenderID','GenderId',
                      'BuffCardID','NpcClassID','PassImageNode','ImageNodeName','PortraitNode','Order','SpriteAnimationID'}
                or k.endswith('DateTimeID')}
            references.append(reference)
            if name in retained_by_path:
                require(status=='exact_catalog_path',
                        'Retained inventory conflicts with binding status for '+table+'.'+field+' key '+str(key)+': '+status)
                covered_by_lane[lane(table)].add(name)
        summaries.append({'table':table,'field':field,'chain':f'{table}.{field} -> AssetView.AssetId -> AssetView.AssetTypeId -> AssetType.ID -> AssetType.Path + AssetView.FilePath',
                          'lane':lane(table),'source_table_rows':len(values),'examined_rows':len(indexes),
                          'row_status_counts':dict(status_rows),'nonzero_type_counts':dict(target_types),
                          'unique_image_asset_ids':len(image_ids),'image_asset_ids':sorted(image_ids),
                          'unique_image_assets_by_binding_status':{s:len(v) for s,v in status_ids.items()},
                          'missing_AssetView_ids':sorted(missing_ids),'outside_audited_image_type_scope_asset_ids':sorted(outside_scope_ids)})

    joins, selection_references = [], []
    for table, field, target, target_field in JOIN_SPECS:
        if not all((args.source/(name+'.json')).exists() for name in [table,target]): continue
        source_values, target_values = rows(table), rows(target)
        target_counts = collections.Counter(r[target_field] for r in target_values)
        target_indexes=collections.defaultdict(list)
        for i,r in enumerate(target_values): target_indexes[r[target_field]].append(i)
        unresolved = [(i,r[field]) for i,r in enumerate(source_values) if r[field] and r[field] not in target_counts]
        for i,r in enumerate(source_values):
            selection_references.append({'source_table':table,'source_table_sha256':fingerprints[table]['sha256'],
                                         'source_row_index_zero':i,'source_field':field,'value':r[field],
                                         'source_raw':r,'target_table':target,'target_table_sha256':fingerprints[target]['sha256'],
                                         'target_field':target_field,'target_row_indexes_zero':target_indexes.get(r[field],[]) if r[field] else [],
                                         'status':'zero_sentinel' if not r[field] else 'exact_static_key_match' if r[field] in target_counts else 'missing_target_key'})
        joins.append({'source':f'{table}.{field}','target':f'{target}.{target_field}',
                      'source_rows':len(source_values),'zero_sentinel_rows':sum(not r[field] for r in source_values),
                      'nonzero_rows':sum(bool(r[field]) for r in source_values),
                      'missing_target_rows':[{'row_index_zero':i,'value':v} for i,v in unresolved],
                      'multiple_target_IDs_referenced':sorted({r[field] for r in source_values if r[field] and target_counts[r[field]]>1})})

    animations = {r['ID']:r for r in rows('SpriteAnimation')} if emoticons else {}
    mappings = rows('EmoticonTypeClassLink') if emoticons else []
    chains = []
    for i, emoticon in enumerate(emoticons):
        matching_frames = [(j,r) for j,r in frames if r['SpriteAnimationID']==emoticon['SpriteAnimationID']]
        ordered = sorted(matching_frames,key=lambda pair:(pair[1]['Order'],pair[0]))
        require(len({r['Order'] for _,r in matching_frames})==len(matching_frames),
                'Duplicate source frame Order for emoticon '+str(emoticon['ID']))
        chains.append({'emoticon_row_index_zero':i,'emoticon_raw_image_fields':{'ID':emoticon['ID'],'SpriteAnimationID':emoticon['SpriteAnimationID']},
                       'class_gender_mappings':[{'row_index_zero':j,'raw':r} for j,r in enumerate(mappings) if r['EmoticonID']==emoticon['ID']],
                       'animation_raw':animations[emoticon['SpriteAnimationID']],
                       'delay_unit_and_runtime_playback_formula':'unresolved; raw numeric Delay preserved, no conversion',
                       'ordered_frames':[{'row_index_zero':j,'raw':r,'asset_raw':assets[r['AssetID']],
                                          'path':bindings[r['AssetID']]['path'],'binding_status':bindings[r['AssetID']]['status']}
                                         for j,r in ordered]})

    def totals(paths):
        # Retained manifest is one row per distinct container/member path.
        records = [retained_by_path[p] for p in sorted(paths)]
        keys = {(r['container'],r['path']) for r in records}
        require(len(keys)==len(records),'Duplicate retained container/member identity')
        return {'files':len(records),'stored_encrypted_member_bytes':sum(r['encrypted_bytes'] for r in records),
                'decoded_file_bytes_metadata':sum(r['plain_bytes'] for r in records)}

    all_paths = set(retained_by_path)
    scope_paths = {r['path'] for r in retained if not r['historical_card_pack_lineage']}
    covered = set().union(*covered_by_lane.values())
    referenced_ids = {r['asset_id'] for r in references}
    referenced_paths = {r['path'] for r in references}
    uncovered_records = []
    for path in sorted(scope_paths-covered):
        r = retained_by_path[path]
        uncovered_records.append({k:r[k] for k in ('container','path','category','encrypted_bytes','plain_bytes','sha256')})
    category_coverage = {}
    for category in sorted({r['category'] for r in retained}):
        paths = {r['path'] for r in retained if r['category']==category}
        category_coverage[category] = {'retained':totals(paths),'audited_static_references':totals(paths&covered),
                                       'scope14964':totals(paths&scope_paths),'scope14964_with_audited_static_references':totals(paths&scope_paths&covered)}

    # These are named candidate roles, but the input JSON has no declared FK
    # metadata proving their target; do not promote integer collisions to coverage.
    class_role_candidates = []
    for table, fields in [('ClassAssets',['HUD','Icon','MainHUDPortraitID','BigHUD']),
                          ('PortraitModEvent',['PortraitID'])]:
        if not (args.source/(table+'.json')).exists(): continue
        values=rows(table)
        for field in fields:
            nonzero=[r[field] for r in values if r[field]]
            class_role_candidates.append({'table':table,'table_sha256':fingerprints[table]['sha256'],
                                          'field':field,'nonzero_rows':len(nonzero),
                                          'matching_AssetView_keys':sum(v in assets for v in nonzero),
                                          'decision':'not counted; require data/UI owner confirmation of exact role target contract'})
    # Read these schemas to document the actual absence of direct image fields.
    attendance_tables=[table for table in ['AttendanceType','AttendanceVersion','AttendanceReward','AttendanceWeeklyBonus','PromotionAttendanceReward'] if (args.source/(table+'.json')).exists()]
    for table in attendance_tables:
        if (args.source/(table+'.json')).exists(): rows(table)
    map_contract_path = args.handoff/'map-image-contracts/all331_current_file_identity_and_pixel_anchor_contracts523.json'
    map_contract = load_json(map_contract_path) if map_contract_path.exists() else None
    map_raw_match = all(c['image_info']['raw']==rows('UIMapImageInfo')[c['image_info']['row_index_zero']] for c in map_contract['image_infos']) if map_contract else None
    require(map_raw_match is not False,'Map contract raw rows differ from source table')
    image_summaries=[s for s in summaries if s['unique_image_asset_ids']]
    result = {
        'kind':'private-source523-image-adapter-static-join-audit',
        'source_root':str(args.source),'source_fingerprints':fingerprints,
        'input_fingerprints':{'bindings':digest(binding_path),'retained_manifest':digest(retained_path),'map_contract':digest(map_contract_path) if map_contract else None},
        'qualifications':[
            'Static schema-named source references only; JSON supplies no formal declared foreign-key metadata or runtime selection precedence.',
            'Coverage counts deduplicate retained inventory by (container,path); asset aliases and repeated consumers do not inflate files or encrypted bytes.',
            'Stored encrypted member bytes are inherited original-member metadata, not DAT container bytes, new pixel receipt/decoding, or fresh CRC/SHA verification.',
            'Inactive/test/excluded source content is preserved. Static links, catalog identity, loading, test rendering and actual runtime use remain separate.',
            'Uncovered means no reference in these audited image adapter fields; it does not establish that the file is unused.',
            'Item/skill/buff icon routes are excluded; card artwork fields are included. Actor motions, SP2, Sound, CSB/Spine payloads are excluded.',
            'AssetType 1 icon/ is outside this audited image-type scope; excluded types are not claims that the referenced resource is non-image.',
        ],
        'asset_path_contract':{'AssetView_rows':len(assets),'AssetType_rows':len(types),'all_binding_rows_equal_exact_source':True,
                               'image_types':{str(k):types[k] for k in sorted(IMAGE_TYPES) if k in types}},
        'consumer_fields':image_summaries,'all_curated_field_audits':summaries,
        'missing_AssetView_key_fields':[s for s in summaries if s['missing_AssetView_ids']],
        'explicit_selection_joins':joins,
        'curated_schema_asset_columns':candidate_columns,'missing_schema_contract_tables':missing_schema_contracts,
        'coverage':{'retained_all':totals(all_paths),'scope14964':totals(scope_paths),
                    'audited_static_references_in_retained':totals(covered),
                    'audited_static_references_in_scope14964':totals(covered&scope_paths),
                    'scope14964_without_audited_static_reference':totals(scope_paths-covered),
                    'unique_referenced_image_assets':len(referenced_ids),'unique_referenced_image_paths':len(referenced_paths),
                    'referenced_paths_outside_retained_inventory':len(referenced_paths-all_paths),
                    'unique_assets_by_binding_status':dict(collections.Counter(bindings[k]['status'] for k in referenced_ids)),
                    'by_lane':{k:totals(v) for k,v in sorted(covered_by_lane.items())},'by_category':category_coverage},
        'source_flags':{table+'_'+field:dict(collections.Counter(str(r[field]) for r in rows(table)))
                        for table,field in [('NpcClass','TestNPC'),('PassSystem','IsActive'),('Promotion','IsEnabled')]
                        if (args.source/(table+'.json')).exists()},
        'emoticon':{'class_gender_mapping_rows':len(mappings),'emoticon_rows':len(emoticons),
                    'referenced_animations':len(emoticon_animation_ids),'image_frame_rows':len(frames),
                    'class_raw_identities':[{'ID':r['ID'],'Name':r['Name']} for r in rows('Class')] if (args.source/'Class.json').exists() else [],
                    'delay_unit_and_runtime_playback_formula':'unresolved; original numeric Delay preserved'},
        'map_contract':{'source_raw_rows_all_match':map_raw_match,'summary':map_contract['summary'] if map_contract else None,
                        'MapBG_fields':'MapBackgroundView.CloudAssetId / SkyAssetId are explicit image roles; ID-to-Land selection is not asserted from same-integer collisions.',
                        'geometry':'Preserve Ratio/BaseLocX/BaseLocY/BasePixelX/BasePixelY; owner source rows and pixel anchors remain in inherited map contracts.'},
        'unconfirmed_named_role_candidates':class_role_candidates,
        'attendance_tables_without_direct_image_fields':attendance_tables,
        'blockers':[
            'Replaced current image containers remain opaque until reviewed directory/payload decoding; historical records cannot establish their current pixels.',
            'Missing member catalog references require exact current member/pixel evidence; never synthesize image files or guess keys.',
            'Attendance type/version/reward to UI/CSB/node assignment requires exact UI-owner contract; Promotion Image/Attendance asset roles are separately explicit.',
            'ClassAssets HUD/MainHUDPortraitID/BigHUD and PortraitModEvent.PortraitID exact role target contracts and MapBackgroundView ID selection require owner confirmation before counting.',
            'Emoticon Delay units, playback formula and source selection precedence require runtime/owner evidence.',
            'No loading or actual runtime-use observations were collected in this audit.',
        ],
    }
    # rows() above may add schema fingerprints; include the completed cache.
    result['source_fingerprints']=fingerprints
    write_json(args.out/'image_source_join_audit.json',result)
    write_json(args.out/'source_schemas.json',schemas)
    write_json(args.out/'emoticon_ordered_image_chains.json',chains)
    write_lines(args.out/'image_source_references.jsonl.gz',references)
    write_lines(args.out/'source_selection_references.jsonl.gz',selection_references)
    write_lines(args.out/'scope14964_without_audited_static_reference.jsonl.gz',uncovered_records)
    write_lines(args.out/'unresolved_image_source_references.jsonl.gz',
                [r for r in references if r['binding_status']!='exact_catalog_path']+missing_source_rows)
    report = ['# Private source523 image adapter audit','',
              'Static source joins only. No source edits, image generation, payload decoding, repository changes, loading, or actual-use observations.','',
              '`source.field → AssetView.AssetId → AssetView.AssetTypeId → AssetType.ID → AssetType.Path + AssetView.FilePath`','',
              '## Deduplicated retained inventory coverage','',
              '| Measure | Files | Stored encrypted member bytes |','|---|---:|---:|']
    for key in ['retained_all','scope14964','audited_static_references_in_retained','audited_static_references_in_scope14964','scope14964_without_audited_static_reference']:
        v=result['coverage'][key];report.append(f'| {key} | {v["files"]:,} | {v["stored_encrypted_member_bytes"]:,} |')
    report += ['', 'Counts are source mappings against inherited retained-member metadata. Repeated source rows and AssetID aliases are deduplicated. Uncovered files can still have UI/node or runtime consumers outside this audit.','',
               '## Concrete source image fields','',
               '| Table.field | Rows examined | Image refs | Unique image assets | Exact / replaced / missing assets |','|---|---:|---:|---:|---:|']
    for s in image_summaries:
        counts=s['unique_image_assets_by_binding_status'];n=sum(s['row_status_counts'].get(k,0) for k in ('exact_catalog_path','current_replaced_image_member_unverified','not_in_available_member_catalog'))
        report.append(f'| `{s["table"]}.{s["field"]}` | {s["examined_rows"]} | {n} | {s["unique_image_asset_ids"]} | {counts.get("exact_catalog_path",0)} / {counts.get("current_replaced_image_member_unverified",0)} / {counts.get("not_in_available_member_catalog",0)} |')
    report += ['', '## Preserved contracts and limits','',
               '- Market purchase artwork stays separate from purchase products and item icons. Zero asset sentinels and missing purchase keys remain separately visible in machine-readable output.',
               '- Source typo `NpcClassBuffCardMapping.DisplayBaseAsserID` is intentional. Card base/screen/deco/illustration/hidden illustration roles remain separate.',
               '- `WorldBossRaidView.ID` is repeated across schedules; preserve source row index and scheduling context. Source ID alone is not a unique row key.',
               '- NPC test flags and inactive pass/promotion rows remain in source counts. They establish no runtime use.',
               '- AttendanceType/Version/Reward/WeeklyBonus/PromotionAttendanceReward expose no direct image field. Promotion artwork has explicit Image/Attendance asset fields; it must not be conflated with attendance reward/UI assignment.',
               '- Emoticons use class/gender mapping → Emoticon → SpriteAnimation → SpriteAnimationAsset ordered by explicit Order. Source row indexes, raw Class identities and raw Delay values are saved. Filenames are preserved verbatim. Delay units/playback remain unresolved.',
               '- Map geometry and original pixel anchors remain in inherited 331-row contracts. UIMapWorld.CanShowMiniMap is a source flag, not a resource fallback. MapBackgroundView has explicit cloud/sky assets; its ID selection is not inferred.',
               '- Literal PassImageNode/ImageNodeName/PortraitNode values remain source context. CSB/Spine resources route to UI ownership; actor SpriteIDs and Sound remain excluded.',
               '- ClassAssets.HUD/MainHUDPortraitID/BigHUD and PortraitModEvent.PortraitID remain uncounted until their exact owner contracts are confirmed. Numeric coincidence does not establish a foreign key.',
               '', '## Remaining blockers', ''] + ['- '+b for b in result['blockers']]
    report += ['', '## Reproduction','', '`python build_source523_image_references.py --tables TABLE_DIRECTORY --inventory INVENTORY_HANDOFF --output PRIVATE_OUTPUT_DIRECTORY`','',
               'Machine-readable outputs include source fingerprints/schemas, every image reference with original row index, unresolved references, and ordered emoticon image chains.','']
    (args.out/'REPORT.md').write_text('\n'.join(report))
    print(json.dumps({'out':str(args.out),'consumer_fields':len(image_summaries),'all_curated_fields':len(summaries),'reference_occurrences':len(references),
                      'coverage':{k:v for k,v in result['coverage'].items() if k not in {'by_lane','by_category'}},
                      'output_files':sorted(p.name for p in args.out.iterdir())},ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
