extends RefCounted
## 사용자 목록 4: the level growth rewards (GrowthMotivation / GrowthMotivationReward,
## the former 96레벨 보상 screen) listed in the original quest window's 업적 tab.
## The original 523 Achievement / LvAchievement quests carry other rewards (e.g.
## "96 레벨 달성": 아우라키아의 상자 ...), none of these rows, so they are added
## as their own achievement rows (TWILIGHT 근사: GrowthMotivation.DescID is 0, the
## title is made from its Level and Percent). Claims stay with world.growth96
## (quote -> execute, its saved receipts): a point already received is shown
## complete and is never paid again.
const PREFIX: String="growth96:"

static func is_row(id: String) -> bool:
	return id.begins_with(PREFIX)

static func title(level: int, percent: int) -> String:
	return "%d 레벨 경험치 %d%% 달성" % [level,percent]

## The quest-window rows (same shape as the quest service rows) of every
## growth point, in level / percent order. Empty without the original tables.
static func rows(runtime: Object) -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	if runtime==null or runtime.get("source")==null or not bool(runtime.source.ready):return out
	for point: Dictionary in runtime.snapshot().get("points",[]):
		var rewards: Array=[]
		for reward: Dictionary in point.get("rewards",[]):
			var raw: Dictionary=runtime.source.rewards.get(str(reward.id),{})
			if raw.is_empty():continue
			rewards.append({"RewardEnhancementTypeID":1,"Amount":int(reward.amount),"source_item":{"ItemClassID":int(raw.RewardClassID)},"name":str(reward.name)})
		var reached: bool=bool(point.reached)
		var claimed: bool=bool(point.claimed)
		out.append({"id":PREFIX+str(point.id),"source_id":0,"category":"achievement","title":title(int(point.level),int(point.percent)),
			"completed":claimed,"available":reached and not claimed,"progress":1 if reached else 0,"objective":{"count":1},
			"status_reason":"" if reached else "레벨 %d · 경험치 %d%%부터 받을 수 있습니다" % [int(point.level),int(point.percent)],
			"source_rewards":rewards,"growth96_point":str(point.id)})
	return out

## Receives one growth point through the growth96 owner (save included).
static func claim(runtime: Object, id: String) -> Dictionary:
	if runtime==null or not is_row(id):return {"ok":false,"message":"성장 보상을 찾을 수 없습니다."}
	var point: String=id.trim_prefix(PREFIX)
	var offer: Dictionary=runtime.quote("claim",point)
	if not offer.get("ok",false):return offer
	return runtime.execute("claim",point,int(offer.revision))
