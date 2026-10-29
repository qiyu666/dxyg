extends Node
# =========================================================
#  Game 单例：常量 / 六边形数学 / 关卡数据 / 经济 / 存档
#  移植自 ant-kingdom/game.js（数值保持一致）
# =========================================================

const HEX := 34.0            # 六边形间距（像素/单位）
const LEVEL_RADIUS := 7
const HOME_RADIUS := 6

# 蚁体配色（对应 HTML COLORS，取几种；0 红 1 橙 2 黄 3 绿 4 紫 5 墨黑）
const ANT_COLORS := [
	{ name = "赤红", body = "#7a2a1c", dark = "#3a1208", head = "#8a3a2a" },
	{ name = "橘黄", body = "#b5642a", dark = "#5a2e10", head = "#c57840" },
	{ name = "明黄", body = "#c9a032", dark = "#6a5210", head = "#d8b848" },
	{ name = "苔绿", body = "#5a6a2a", dark = "#2a3410", head = "#6a7a34" },
	{ name = "紫晶", body = "#5a2e7a", dark = "#2a1240", head = "#6a3a8a" },
	{ name = "墨黑", body = "#35353f", dark = "#15151a", head = "#47474f" },
]

# 建筑：cost=建造食物，desc 用于 UI
const BUILD := {
	"worker":  { name = "工蚁孵化室", cost = 5,  icon = "🐜" },
	"soldier": { name = "兵蚁孵化室", cost = 50, icon = "⚔" },
	"storage": { name = "食物储存区", cost = 5,  icon = "🫙" },
	"speed":   { name = "加速方块",   cost = 5,  icon = "⚡" },
}

# 孵化方格生命周期（秒）：empty(取卵)→egg(卵)→larva(白幼虫)→pupa(黄蛹)→羽化(耗食物)
const HATCH_TIME := { "empty": 4.0, "egg": 5.0, "larva": 7.0 }

const ANTS := {
	"worker":  { hp = 25, atk = 3,  speed = 42, carryCap = 8 },
	"soldier": { hp = 70, atk = 10, speed = 52, carryCap = 8 },
}

const ENEMIES := {
	"mealworm":   { hp = 22,  atk = 2,  speed = 26, size = 0.9, food = 50 },
	"sowbug":     { hp = 48,  atk = 4,  speed = 30, size = 1.0, food = 0 },
	"beetle":     { hp = 75,  atk = 8,  speed = 30, size = 1.35, food = 0 },
	"adultBeetle":{ hp = 170, atk = 14, speed = 26, size = 1.9, food = 0 },
	"spider":     { hp = 95,  atk = 12, speed = 62, size = 1.4, food = 30 },
	"webSpider":  { hp = 90,  atk = 30, speed = 60, size = 1.2, food = 50 },
	"enemyAnt":   { hp = 42,  atk = 6,  speed = 56, size = 1.0, food = 0 },
}

const LEVELS := [
	{
		name = "第一章 · 第一关",
		kind = "clear",
		buried = ["mealworm","mealworm","mealworm","sowbug","sowbug","beetle","beetle","adultBeetle"],
		soilFood = 6,
		needSoldier = 0, needWorker = 0,
		raid = false,
	},
	{
		name = "第一章 · 第二关",
		kind = "expand",
		buried = ["spider","spider","spider","webSpider","webSpider","enemyAnt","enemyAnt"],
		soilFood = 22,
		needSoldier = 50, needWorker = 47,
		raid = true,
	},
]

var save_dir := "user://ants_saves/"
var color_idx := 0
var cleared := [false, false]
var points_spent := 0
var evolutions := { hp = 0, atk = 0, speed = 0, carry = 0, bigSoldier = false }
# 蚁丘家：tiles 由 TerrainGrid 在 3D 里持有；家资源存这里
var home := {}

func _ready() -> void:
	_dir_ensure()
	load_meta()

func _dir_ensure() -> void:
	var d := DirAccess.open("user://")
	if d and not d.dir_exists("ants_saves"):
		d.make_dir("ants_saves")

# ---------- 六边形数学（axial，pointy-top 近似；与 HTML 一致用 h2p 映射到 x/z） ----------
const DIRS := [[1,0],[1,-1],[0,-1],[-1,0],[-1,1],[0,1]]

static func hkey(q:int, r:int) -> String:
	return "%d,%d" % [q, r]

static func parse_key(k:String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))

# 六格 -> 平面坐标（x=右, 返回 Vector2 当 x,z 用）
static func h2p(q:float, r:float) -> Vector2:
	var x := HEX * (1.5 * q + 0.5 * r)
	var z := HEX * (sqrt(3.0) * r)
	return Vector2(x, z)

static func p2h(x:float, z:float) -> Vector2i:
	var qf := (2.0/3.0 * x) / HEX
	var rf := (sqrt(3.0)/3.0 * z - 1.0/3.0 * x) / HEX
	return hex_round(qf, rf)

static func hex_round(qf:float, rf:float) -> Vector2i:
	var x := qf; var z := rf; var y := -x - z
	var rq: int = int(round(x)); var rz: int = int(round(z)); var ry: int = int(round(y))
	var dx: float = absf(rq - x); var dz: float = absf(rz - z); var dy: float = absf(ry - y)
	if dx > dz and dx > dy:
		rq = -rz - ry
	elif dz > dy:
		rz = -rq - ry
	return Vector2i(rq, rz)

static func hdist(a:Vector2i, b:Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

static func in_radius(q:int, r:int, rad:int) -> bool:
	return hdist(Vector2i(q, r), Vector2i.ZERO) <= rad

# 剩余威胁 = 活跃敌人 + 仍埋土的敌人
static func threats_left(active_enemies: Array, buried: Dictionary) -> int:
	var n := active_enemies.size()
	for k in buried:
		if buried[k].has("enemy"):
			n += 1
	return n

# ---------- 孵化 ----------
func hatch_cost(type:String, level:int) -> int:
	var base := 5 if type == "soldier" else 2
	return int(round(float(base) * (1.0 + 0.25 * float(level - 1))))
func hatch_stat_mul(level:int) -> float:
	return 1.0 + 0.35 * (level - 1)

# ---------- 存档 / 读档 ----------
func _save_path(kind:String, id:String) -> String:
	return save_dir + kind + "_" + id + ".json"

func save_home(h:Dictionary) -> void:
	var f := FileAccess.open(_save_path("home", h.get("id","0")), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(h)); f.close()

func load_home(id:String) -> Dictionary:
	var f := FileAccess.open(_save_path("home", id), FileAccess.READ)
	if not f:
		return {}
	var js := JSON.new()
	if js.parse(f.get_as_text()) != OK:
		return {}
	var d: Dictionary = js.data if js.data is Dictionary else {}
	f.close()
	return d

func save_meta() -> void:
	var f := FileAccess.open(_save_path("meta","main"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ color_idx = color_idx, cleared = cleared, points_spent = points_spent, evolutions = evolutions }))
		f.close()

func load_meta() -> void:
	var f := FileAccess.open(_save_path("meta","main"), FileAccess.READ)
	if not f:
		return
	var js := JSON.new()
	if js.parse(f.get_as_text()) == OK and js.data is Dictionary:
		var d: Dictionary = js.data
		color_idx = int(d.get("color_idx", 0))
		cleared = d.get("cleared", [false,false])
		points_spent = int(d.get("points_spent", 0))
		evolutions = d.get("evolutions", {})
	f.close()

func list_home_saves() -> Array:
	var out := []
	var d := DirAccess.open(save_dir)
	if d:
		d.list_dir_begin()
		var fn := d.get_next()
		while fn != "":
			if fn.begins_with("home_") and fn.ends_with(".json"):
				out.append(fn.replace("home_","").replace(".json",""))
			fn = d.get_next()
	return out
