extends LevelDef
## 第一章·第一关：完全地下、无出口。胜利：击败所有敌人。
## 敌人：甲虫、成年甲虫、活鼠妇（留尸体）、面包虫（死亡掉落 50 食物）。
class_name Level1

func _init() -> void:
	id = "ch1_l1"
	title = "第一章 · 第一关"
	radius = 8
	has_exit = false
	victory = {"type": "kill_all"}
	ground_food_total = 0.0
	enemy_spawns = [
		{"type": "beetle", "count": 6},
		{"type": "adult_beetle", "count": 3},
		{"type": "isopod", "count": 5},
		{"type": "bread_worm", "count": 8},
	]
	silk_spiders = 0
	rewards = {"food": 120.0, "jelly": 2}
	initial_workers = 7
