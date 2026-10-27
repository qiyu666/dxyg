extends LevelDef
## 第一章·第二关：有地面出口，敌对蚂蚁可进入。
## 胜利：额外建造 50 兵蚁孵化室 + 47 工蚁孵化室（蚁后室初始 7 工蚁不计入）。
## 蛛丝蜘蛛埋伏于洞穴，洞穴内大量食物；蚂蚁数量足够时压制蜘蛛。
## 敌对蚂蚁每 120 秒来袭一次，每次窃取 10 只幼蚁；无幼蚁则转攻蚁后。
## 关卡开始时地面约 500 点食物。
class_name Level2

func _init() -> void:
	id = "ch1_l2"
	title = "第一章 · 第二关"
	radius = 9
	has_exit = true
	victory = {"type": "build", "soldier": 50, "worker": 47}
	ground_food_total = 500.0
	enemy_spawns = [
		{"type": "spider", "count": 8},
		{"type": "enemy_ant", "count": 15},
	]
	silk_spiders = 6
	silk_spider_food_each = 80.0
	enemy_assault_interval = 120.0
	enemy_assault_steal = 10
	rewards = {"food": 300.0, "jelly": 5}
	initial_workers = 7
