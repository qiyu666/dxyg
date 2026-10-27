extends RefCounted
## 信息素队伍。每支队伍：可分配多个孵化室、可放多个信息素标记、
## 两个独立开关（允许攻击 / 允许搬运）、最大出动数量。
class_name Pheromone

var index: int
var allow_attack: bool = true
var allow_carry: bool = true
## 最大出动数量；0 = 不限。超出数量的蚂蚁留在孵化室附近待命。
var max_mobilize: int = 0
## 分配到本队的孵化室位置（Vector2i，格子坐标）
var hatches: Array = []
## 信息素标记位置（Vector2i）
var markers: Array = []
## 当前已出动计数（模拟用，待命/出动切换）
var deployed: int = 0


func _init(p_index: int) -> void:
	index = p_index


func label() -> String:
	return GameConst.TEAM_NAMES.get(index, "?")


func assign_hatch(c: Vector2i) -> void:
	if not hatches.has(c):
		hatches.append(c)


func clear_hatches() -> void:
	hatches.clear()


func add_marker(c: Vector2i) -> void:
	if not markers.has(c):
		markers.append(c)
		markers.sort()


func remove_marker(c: Vector2i) -> void:
	markers.erase(c)


func marker_at(c: Vector2i) -> bool:
	return markers.has(c)


func is_assigned_to(c: Vector2i) -> bool:
	return hatches.has(c)
