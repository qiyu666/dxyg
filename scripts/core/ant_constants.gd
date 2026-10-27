extends RefCounted
## 全局游戏常量：建筑花费/效果、升级点数、进化、敌人属性。
## 数值均为初值，方便后续调平衡。
class_name GameConst

# ---- 建筑/地块类型（字符串 id，跨文件安全） ----
const SOIL := "soil"          # 未挖掘：阻挡
const OPEN := "open"          # 已挖掘/空地：可通行、可建造
const QUEEN := "queen"        # 蚁后室 7 格
const SOLDIER_HATCH := "soldier_hatch"
const WORKER_HATCH := "worker_hatch"
const SPEED_BLOCK := "speed"
const FOOD_STORAGE := "food_storage"

## 建造花费（食物）。升级消耗等于建造花费。
const BUILD_COST := {
	SOLDIER_HATCH: 50.0,
	WORKER_HATCH: 5.0,
	SPEED_BLOCK: 5.0,
	FOOD_STORAGE: 5.0,
}

## 可建造的格子（蚁后室/土块不可"建造"）
const BUILDABLE := {
	SOLDIER_HATCH: true,
	WORKER_HATCH: true,
	SPEED_BLOCK: true,
	FOOD_STORAGE: true,
}

## 可升级的建筑
const UPGRADEABLE := {
	SOLDIER_HATCH: true,
	WORKER_HATCH: true,
	SPEED_BLOCK: true,
	FOOD_STORAGE: true,
}

## 食物储存区储量：1/2/3 级
const FOOD_STORAGE_CAP := { 1: 10.0, 2: 30.0, 3: 50.0 }
## 加速方块移速加成：1/2/3 级
const SPEED_BONUS := { 1: 0.10, 2: 0.20, 3: 0.30 }
## 升级所需点数：2 级 / 3 级
const UPGRADE_POINTS_REQUIRED := { 2: 6, 3: 12 }
const MAX_LEVEL := 3

## 蚁后室自带基础食物储量
const QUEEN_BASE_STORAGE := 70.0
## 蚂蚁踩在孵化室上减速
const HATCHER_DECEL := 0.20

## 队伍相关
const TEAM_NAMES := ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ"]
const TEAM_COUNT := 5

# ---- 进化（消耗蚁皇浆） ----
const EVOLUTIONS := {
	"hp": "工蚁/兵蚁血量 +",
	"attack": "兵蚁攻击力 +",
	"speed": "全蚁移速 +",
	"carry": "搬运效率 +",
	"new_species_guard": "解锁新蚁种：御后卫士",
}
const EVOLUTION_JELLY_COST := {
	"hp": 1, "attack": 1, "speed": 1, "carry": 1, "new_species_guard": 3,
}

# ---- 敌人属性 ----
# 键：name(显示) hp speed damage(接触/攻击) death_food(直接掉落) corpse_food(每次分解) corpse_decomp(可分解次数)
const ENEMIES := {
	"beetle":       { "name": "甲虫",     "hp": 8.0,  "speed": 42.0,  "damage": 2.0, "death_food": 0.0, "corpse_food": 0.0, "corpse_decomp": 0 },
	"adult_beetle": { "name": "成年甲虫", "hp": 22.0, "speed": 55.0,  "damage": 4.0, "death_food": 0.0, "corpse_food": 0.0, "corpse_decomp": 0 },
	"isopod":       { "name": "活鼠妇",   "hp": 15.0, "speed": 65.0,  "damage": 3.0, "death_food": 0.0, "corpse_food": 40.0, "corpse_decomp": 2 },
	"bread_worm":   { "name": "面包虫",   "hp": 4.0,  "speed": 30.0,  "damage": 1.0, "death_food": 50.0, "corpse_food": 0.0, "corpse_decomp": 0 },
	"spider":       { "name": "蜘蛛",     "hp": 26.0, "speed": 80.0,  "damage": 5.0, "death_food": 0.0, "corpse_food": 0.0, "corpse_decomp": 0 },
	"silk_spider":  { "name": "蛛丝蜘蛛", "hp": 60.0, "speed": 70.0,  "damage": 99.0, "death_food": 0.0, "corpse_food": 0.0, "corpse_decomp": 0, "ambush": true },
	"enemy_ant":    { "name": "敌对蚂蚁", "hp": 10.0, "speed": 70.0,  "damage": 3.0, "death_food": 0.0, "corpse_food": 0.0, "corpse_decomp": 0 },
}

## 兵蚁/工蚁基础属性（进化会叠加）
const WORKER := { "hp": 8.0, "speed": 95.0, "damage": 1.0, "carry": 10.0, "cost_jelly": 0 }
const SOLDIER := { "hp": 16.0, "speed": 80.0, "damage": 4.0, "carry": 4.0, "cost_jelly": 0 }

# ---- 蚁后产卵 / 孵化流水线 ----
## 孵化室发育阶段：无 -> 卵 -> 白幼虫 -> 黄蛹 -> 羽化(活跃蚁)
const DEV_NONE := 0
const DEV_EGG := 1
const DEV_LARVA := 2   # 白色幼虫
const DEV_PUPA := 3    # 黄色蛹
## 阶段时长（秒）
const EGG_TO_LARVA_TIME := 6.0
const LARVA_TO_PUPA_TIME := 8.0
const PUPA_TO_HATCH_TIME := 6.0
## 蛹→活跃 需消耗食物；不足则停在蛹阶段
const HATCH_FOOD_COST := 5.0
## 蚁后产卵节奏（秒/枚）与排队上限
const QUEEN_EGG_INTERVAL := 4.0
const QUEEN_EGG_CAP := 4
## 活跃蚁死亡后，孵化室内在发育的蚁加速孵化（时长缩短）
const HATCH_FAST_FACTOR := 0.5
## 表示“无”六边形格的哨兵值（Vector2i 是值类型，不能为 null）
const NO_CELL := Vector2i(-9999, -9999)
