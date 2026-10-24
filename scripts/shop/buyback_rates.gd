extends RefCounted

# Shared local values only. Do not preload shop/catalog/transaction code here.
# Both stock construction and buyback read this table without a preload cycle.
const GRADE_BUYBACK = {"일반":40,"고급":200,"희귀":800,"영웅":4500,"전설":10000,"신화":30000,"유일":80000}
