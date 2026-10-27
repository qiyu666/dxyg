extends RefCounted
## 建筑静态工具：花费/储量/加速/升级点数规则。
class_name BuildingData


static func build_cost(type: String) -> float:
	return GameConst.BUILD_COST.get(type, 0.0)


static func food_cap(level: int) -> float:
	return GameConst.FOOD_STORAGE_CAP.get(level, 10.0)


static func speed_bonus(level: int) -> float:
	return GameConst.SPEED_BONUS.get(level, 0.0)


static func upgrade_points_required(target_level: int) -> int:
	return GameConst.UPGRADE_POINTS_REQUIRED.get(target_level, 999)


static func can_build(type: String) -> bool:
	return GameConst.BUILDABLE.get(type, false)


static func is_upgradable(type: String) -> bool:
	return GameConst.UPGRADEABLE.get(type, false)


static func is_hatcher(type: String) -> bool:
	return type == GameConst.SOLDIER_HATCH or type == GameConst.WORKER_HATCH


## 升级点数（假设解读）：
## 基础 1 点 + 相邻同类建筑 ×1 + （非加速方块时）相邻加速方块 ×1。
## 到 2 级需 6 点，到 3 级需 12 点。
static func upgrade_points(center: Vector2i, type: String, tiles: Dictionary) -> int:
	var pts := 1
	for n in HexMath.neighbors(center):
		var k := HexMath.key(n)
		if not tiles.has(k):
			continue
		var nt: String = tiles[k]["type"]
		if nt == GameConst.QUEEN or nt == GameConst.SOIL:
			continue
		if nt == type and type != GameConst.SPEED_BLOCK:
			pts += 1
		if nt == GameConst.SPEED_BLOCK and type != GameConst.SPEED_BLOCK:
			pts += 1
	return pts
