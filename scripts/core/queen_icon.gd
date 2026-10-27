extends Node2D
## 蚁后展示：优先用 res://assets/textures/queen.png（自生成贴图），
## 缺失时程序化回退（发光 + 简化蚁后轮廓），保证无贴图也能运行。
class_name QueenIcon

var _tex: Texture2D
var _glow_color := Color(0.55, 0.12, 0.12, 0.55)


func _init() -> void:
	_tex = _load()


func _load() -> Texture2D:
	for p in ["res://assets/textures/queen.svg", "res://assets/textures/queen.png"]:
		if ResourceLoader.exists(p):
			return load(p)
	return null


func set_glow(color: Color) -> void:
	_glow_color = color
	queue_redraw()


func _draw() -> void:
	# 底光
	draw_circle(Vector2.ZERO, 30.0, _glow_color)
	if _tex != null:
		var s := _tex.get_size()
		var sc := 40.0 / maxf(s.x, s.y)
		var ds := s * sc
		draw_texture_rect(_tex, Rect2(-ds.x * 0.5, -ds.y * 0.55, ds.x, ds.y), true)
	else:
		_proc()


func _proc() -> void:
	var c := Color(1.0, 0.85, 0.88)
	# 头 / 胸 / 腹
	draw_circle(Vector2(-9, 0), 5.0, c)
	draw_circle(Vector2(0, 0), 4.0, c)
	draw_circle(Vector2(11, 0), 8.0, c)
	# 触角
	draw_line(Vector2(-13, -2), Vector2(-20, -8), c, 1.2)
	draw_line(Vector2(-13, 2), Vector2(-20, 4), c, 1.2)
	# 腿
	for dx in [-6.0, 1.0, 8.0]:
		draw_line(Vector2(dx, 4), Vector2(dx - 3.0, 12.0), c, 1.0)
		draw_line(Vector2(dx, -4), Vector2(dx + 3.0, -12.0), c, 1.0)
	# 翅膀（带透明感）
	var wc := Color(0.9, 0.9, 1.0, 0.45)
	draw_polygon([Vector2(0, -2), Vector2(20, -16), Vector2(14, -2)], [wc, wc, wc])
	draw_polygon([Vector2(0, 2), Vector2(20, 14), Vector2(14, 2)], [wc, wc, wc])
