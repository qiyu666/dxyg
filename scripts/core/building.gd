extends RefCounted
## 建筑实例数据（纯数据，非节点）。节点侧由 HexGrid 渲染。
class_name Building

var type: String
var level: int = 1
## 蚁后室等会占用多格；普通建筑 1 格。
var cells: Array = []

## 孵化室被分配到的信息素队伍（-1 = 未分配）
var team_index: int = -1

## 孵化流水线（仅孵化室使用）
var dev_stage: int = 0     # GameConst.DEV_*
var dev_time: float = 0.0
var dev_fast: bool = false   # 活跃蚁死亡后加速补位
var dev_reserved: bool = false  # 工蚁正在往此孵化室搬运蚁卵


func _init(p_type: String) -> void:
	type = p_type


func max_level() -> int:
	if not BuildingData.is_upgradable(type):
		return 0
	return GameConst.MAX_LEVEL


func needs_upgrade() -> bool:
	return BuildingData.is_upgradable(type) and level < max_level()
