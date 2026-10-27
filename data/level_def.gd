extends RefCounted
## 关卡定义基类：胜利条件、敌人、地面食物、蛛丝蜘蛛、敌方蚁群来袭、奖励。
class_name LevelDef

var id: String = "level"
var title: String = "关卡"
var radius: int = 8
var grid_hex_size: float = 30.0
## 场景是否有地面出口（敌对蚂蚁可从出口进入）
var has_exit: bool = false
## 胜利条件
##   {"type":"kill_all"}
##   {"type":"build", "soldier": int, "worker": int}  建造目标
var victory: Dictionary = {}
## 敌人布阵：[ {"type": str, "count": int} ]
var enemy_spawns: Array = []
## 蛛丝蜘蛛洞穴数量 & 每洞食物
var silk_spiders: int = 0
var silk_spider_food_each: float = 0.0
## 关卡开始时地面散落食物总量
var ground_food_total: float = 0.0
## 敌方蚁群来袭
var enemy_assault_interval: float = 0.0   # 0 = 无
var enemy_assault_steal: int = 0          # 每次来袭窃取幼蚁数
## 通关奖励（结算到家）
var rewards: Dictionary = {"food": 0.0, "jelly": 0}
## 初始工蚁数（蚁后室）
var initial_workers: int = 7
