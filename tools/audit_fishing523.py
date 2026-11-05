"""Audit every fishing and exchange row without publishing original tables."""
import collections
import json
import sys
from import_fishing523 import build

pack = build(sys.argv[1])
t = pack['tables']
report = {'version':523,'tables':{},'reference_failures':[],'inactive_pools':[], 'execution_boundaries':{}}
for name, rows in t.items():
    report['tables'][name] = {'rows':len(rows),'fields':sorted({k for r in rows for k in r})}
for table, field, target in [('FishDistribution','FishTerritoryID','FishTerritory'),('FishDistribution','FishPoolID','FishPool'),('FishPoolProbability','FishID','Fish'),('FishPoolProbability','FishPoolID','FishPool'),('Fish','FishSizeID','FishSize'),('Fish','MiniGameAIType','FishMiniGameAIType'),('FishMiniGameAI','FishAIType','FishMiniGameAIType'),('FishMiniGameAI','FishDifficulty','FishMiniGameDifficulty'),('FishMiniGameAIList','FishMiniGameAI','FishMiniGameAI'),('FishContest','FishSiteID','FishSite'),('FishContestRule','FishContestID','FishContest'),('FishContestRule','FishID','Fish'),('FishContestRule','RuleTypeID','FishContestRuleType'),('FishContestRank','FishContestID','FishContest'),('FishContestRankReward','FishContestRankID','FishContestRank'),('FishContestRankReward','RewardID','Reward'),('ExchangeSystemRule','InputID','ExchangeSystemInput'),('ExchangeSystemOutput','RuleID','ExchangeSystemRule'),('ExchangeSystemOutput','ItemClassID','ItemClass'),('FishTerritory','TerritoriesID','Territories')]:
    targets={r['ID'] for r in t[target]}
    for row in t[table]:
        if row[field] not in targets: report['reference_failures'].append([table,row['ID'],field,row[field],target])
used={r['FishPoolID'] for r in t['FishDistribution']}
report['inactive_pools']=[r['ID'] for r in t['FishPool'] if r['ID'] not in used]
report['pool_weight_sums']=dict(collections.Counter())
for r in t['FishPoolProbability']:
    key=str(r['FishPoolID']);report['pool_weight_sums'][key]=report['pool_weight_sums'].get(key,0)+r['Probability']
report['exchange_systems']={}
for r in t['ExchangeSystemRule']:
    outputs=[o for o in t['ExchangeSystemOutput'] if o['RuleID']==r['ID']]
    report['exchange_systems'][str(r['SystemTypeID'])+':'+str(r['ID'])]={'guaranteed_ids':[o['ID'] for o in outputs if o['IsGuaranteed']],'extra_ids':[o['ID'] for o in outputs if not o['IsGuaranteed']]}
report['execution_boundaries']={
 'source_preserved':'All fishing tables and all six ExchangeSystem tables are preserved in the private runtime pack. Original archive bytes are retained separately.',
 'system13':'Preserved and audited; intentionally excluded from fishing execution.',
 'coordinates':'Territory rectangles are retained as source metadata; no original water cell or teleport is asserted.',
 'server_rank_schedule':'Original schedule and rank definitions are retained. The host tournament is explicitly a local solo event, not a server leaderboard.',
 'rng':'Independent exchange rolls and denominators are host policy. Original weights and guaranteed amounts remain unchanged.',
 'simulation':'Gauge integration, automatic catch interpolation and length generation are host policies, not a recovered original engine.'}
print(json.dumps(report,ensure_ascii=False,indent=2))
