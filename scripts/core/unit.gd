extends Node2D
## 单位基类（蚂蚁/敌人）。位置为网格本地坐标（grid 的子节点）。
class_name Unit

var hp: float = 1.0
var max_hp: float = 1.0
var speed: float = 60.0   # 像素/秒
var alive: bool = true
var color := Color(0.9, 0.9, 0.9)
var radius: float = 6.0


func _init() -> void:
	pass


func take_damage(d: float) -> void:
	if not alive:
		return
	hp -= d
	if hp <= 0.0:
		alive = false


func on_hatcher() -> bool:
	# 由 GameView 依据所处格决定；此处默认 false
	return false


func _draw() -> void:
	if not alive:
		return
	draw_circle(Vector2.ZERO, radius, color)
	# 血量指示
	var w := 14.0
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2, -radius - 5.0, w * ratio, 2.0), Color(0.2, 0.9, 0.3))
	draw_rect(Rect2(-w / 2, -radius - 5.0, w, 2.0), Color(0.0, 0.0, 0.0, 0.4))
