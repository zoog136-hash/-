#!/usr/bin/env python3
"""Audit complete owner-held523 tables against the separate analysis report. No source uploads."""
import zipfile,json,hashlib,zlib,pathlib,collections,argparse
p=argparse.ArgumentParser()
p.add_argument("--source",type=pathlib.Path,required=True)
p.add_argument("--report-dir",type=pathlib.Path,required=True)
p.add_argument("--report-zip",type=pathlib.Path,required=True)
p.add_argument("--output",type=pathlib.Path,required=True,help="Private audit output containing source references; keep outside public Git")
args=p.parse_args()
root=args.report_dir
man=json.loads((root/'source_manifest523.json').read_text());archive=args.source
checks=[]
def check(x,label):
 checks.append({'ok':bool(x),'check':label})
 if not x:raise ValueError(label)
with zipfile.ZipFile(archive) as z:
 check(hashlib.sha256(archive.read_bytes()).hexdigest()==man['archive_sha256'],'exact original archive SHA')
 check(z.testzip() is None,'whole original ZIP CRC')
 for name,spec in man['loaded_table_integrity'].items():
  b=z.read(spec['member']);check(len(b)==spec['bytes'] and hashlib.sha256(b).hexdigest()==spec['sha256'] and f'{zlib.crc32(b):08x}'==spec['crc32'],name+' complete-table bytes/SHA/CRC')
 def rows(n):return json.loads(z.read('content/'+n+'.json'))['rows']
 def idx(n):return {r['ID']:r for r in rows(n)}
 stages=json.loads((root/'all25_ordered_stages_donation_benefits_and_appellations523.json').read_text())
 check(len(stages['stages'])==25,'25 report stages')
 for s in stages['stages']:
  for key,table in [('stage','SubTitle'),('donation','SubTitleDonation'),('donation_probability','SubTitleDonationProbability')]:
   r=s[key]['row'];check(idx(table)[r['ID']]==r,'report exact '+table+' '+str(r['ID']))
 chains=json.loads((root/'all128_last_attack_quest_goal_target_and_level_chains523.json').read_text())['chains']
 groups=collections.defaultdict(list)
 for r in rows('NpcClassForNpcGroup'):groups[r['NpcGroupID']].append(r)
 selected=set();npc_ids=set();group_ids=set()
 for c in chains:
  q=c['quest']['row'];qid=q['ID'];selected.add(qid)
  check(idx('QuestView')[qid]==q and q['TypeID']==58 and q['CannotReveal'] and q['LimitHours']==24,'complete trial '+str(qid))
  for g in c['goals']:
   goal=g['goal']['row'];check(idx('Goal')[goal['ID']]==goal,'exact goal '+str(goal['ID']))
   if goal['GoalTypeID']==261:npc_ids.add(goal['GoalClassID'])
   elif goal['GoalTypeID']==574:
    group_ids.add(goal['GoalClassID']);npc_ids.update(r['NpcClassID'] for r in groups[goal['GoalClassID']])
   else:raise ValueError('unexpected goal type')
  for p in c['prerequisites']:
   r=p['prerequisite']['row'];check(idx('Prerequisite')[r['ID']]==r and r['PrerequisiteTypeID']==1 and r['Value']==85,'minimum level85 '+str(qid))
 check(len(selected)==128 and len(npc_ids)==33 and len(group_ids)==57,'all128 trials33NPC57groups')
 check(not [r for r in rows('QuestReward') if r.get('QuestID') in selected],'no direct quest rewards')
 item=idx('ItemClass')[117544];category=idx('ItemCategory')[item['CategoryID']]
 check(category['Name']=='StackableItem' and category['IsStackable'] and not item['TestItem'],'actual material category; not Currency category')
 supply={}
 for table,col in [('NpcItemDropView','ItemClassID'),('MerchantGoods','ItemClassID'),('ItemCraftView','ItemClassID'),('ItemCraftInput','ItemClassID'),('ItemCraftOutputView','ItemClassID'),('LuckyBagEntityView','ItemClassID'),('MarketProduct','ClassID'),('Reward','RewardClassID')]:
  r=[x for x in rows(table) if x.get(col)==117544]
  supply[table]={'rows':len(r),'ids':[x.get('ID',x.get('ItemCraftID')) for x in r]}
 drops=[r for r in rows('NpcItemDropView') if r['ItemClassID']==117544]
 check(len(drops)==178 and all(r['Bless']==1 and r['RequiredQuestID']==0 for r in drops),'all178 powder drop rows are ordinary nonquest')
 # The report omitted the word payload; consume and audit the full locale table,
 # and distinguish its selection/match enum from the host execution policy.
 extra={}
 for name in ['NpcItemDropView','MerchantGoods','ItemCraftView','ItemCraftInput','ItemCraftOutputView','LuckyBagEntityView','MarketProduct','Reward','ItemCategory','ServerLimit']:
  b=z.read('content/'+name+'.json');extra[name]={'rows':len(rows(name)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'crc32':f'{zlib.crc32(b):08x}'}
  check(zlib.crc32(b)==z.getinfo('content/'+name+'.json').CRC,'additional complete table CRC '+name)
 personal=json.loads((root/'personal_name_threshold8colors_and_ColorTable_namespace523.json').read_text())
 for key,table in [('color_prerequisites','PersonalAppellationColor'),('correct_ColorTable','ColorTable')]:
  table_index=idx(table)
  for ref in personal[key]:check(table_index[ref['row']['ID']]==ref['row'],'exact personal '+table+' '+str(ref['row']['ID']))
 check('content/TextMatchingType.json' not in z.namelist(),'native text matching execution table unavailable; host match rule must remain labelled')
 dates_index=idx("DateTimes_Korean"); server_rows=rows("ServerLimit")
 trials=[]
 for c in chains:
  quest=c['quest']['row'];goal=c['goals'][0]['goal']['row'];target_ids=[goal['GoalClassID']] if goal['GoalTypeID']==261 else [r['NpcClassID'] for r in groups[goal['GoalClassID']]]
  trials.append({'quest_id':quest['ID'],'goal_id':goal['ID'],'goal_type_id':goal['GoalTypeID'],'native_target_ids':sorted(target_ids),'amount':goal['Amount'],'limit_hours':quest['LimitHours'],'source_quest_row':quest,'calendar_start':dates_index[quest['StartTime']],'calendar_end':dates_index[quest['EndTime']],'server_limit_rows':[r for r in server_rows if r['ServerLimitSetID']==quest['ServerLimitSetID']],'prerequisites':[r['prerequisite']['row'] for r in c['prerequisites']]})
 limited_ids=[q['quest_id'] for q in trials if q['source_quest_row']['ServerLimitSetID']]
 check(len(limited_ids)==21 and all(q['source_quest_row']['ServerLimitSetID'] in (0,762) for q in trials),'all21 server limited quests retain set762 membership and dates')
 dependencies={'server_limited_quest_ids':limited_ids,'trial_npc_ids':sorted(npc_ids),'all128_trials':trials,'all178_powder_drop_rows':drops,'powder_npc_ids':sorted({r['NpcClassID'] for r in drops}),'other_powder_reference_rows':{table:[r for r in rows(table) if r.get(col)==117544] for table,col in [('MerchantGoods','ItemClassID'),('ItemCraftView','ItemClassID'),('ItemCraftInput','ItemClassID'),('ItemCraftOutputView','ItemClassID'),('LuckyBagEntityView','ItemClassID'),('MarketProduct','ClassID'),('Reward','RewardClassID')]},'consumer_contract':{'actor':'source_m_npc_id plus complete immutable NpcClass source_m_original; equality checked before direct hit/death or drop acceptance; pooled life attribution reset per death','powder':'source snapshot523, class117544, sourceId m523:item:117544, native StackableItem, ordinary blessing1, no test item, unlocked stack; runtime.bind_material defines metadata only; ownership must come from actual provider floor/pickup or another validated domain transaction','placement':'no native coordinates invented; all128 trials and178 powder rows remain natural-play blocked without exact registered actor suppliers; fixture tests prove consumers only'},'unimplemented_domain_providers':'merchant/craft/bag/market/reward runtimes not duplicated; payment MasteryPointPayment52,62,72,82,92 is a separate consumer, not a title prerequisite'}
 policy=json.loads((pathlib.Path(__file__).resolve().parents[1]/"data/titles/local_policy523.json").read_text())
 report={'source_sha256':man['archive_sha256'],'source_bytes':archive.stat().st_size,'report_sha256':hashlib.sha256(args.report_zip.read_bytes()).hexdigest(),'complete_tables_verified':len(man['loaded_table_integrity']),'selected_tables':len(man['selected_rows_by_table']),'selected_rows':sum(man['selected_rows_by_table'].values()),'core_tables':14,'core_rows':362,'trial_count':128,'npc_count':33,'target_group_count':57,'powder_references':supply,'additional_complete_table_integrity':extra,'private_dependency_contract':dependencies,'implementation':{'all25_stages':'explicit sequence source ZIP runtime','all128_trials':'dedicated title trial state; direct exact native last hits; one selected goal','all41_benefits':'native values accumulated once; host combat consumers and explicit estimates','powder178_drops':'source membership/blessing/quest constraints; configurable chance/quantity; real floor pickup','other_powder_supply':'retained in owner ZIP; other domain providers not duplicated','personal_appellation':'all8 native colors and conditions, actual5-slot editor, actor badge, atomic save/reconnect; mixed-length and substring execution explicit host policy','excluded':'general quest system changes, clans, sieges, arena, ziggurat, pets, M engine/APK'},'host_policy':policy,'checks':len(checks),'failures':[x for x in checks if not x['ok']]}
 args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2))
 print(json.dumps({k:report[k] for k in ['complete_tables_verified','selected_rows','checks','failures']},ensure_ascii=False))
