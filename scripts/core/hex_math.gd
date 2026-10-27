extends RefCounted
## 六边形数学：尖顶(pointy-top) 轴向坐标 (q, r)。
## 全部为纯静态计算，供网格渲染、寻路、相邻判定复用。
class_name HexMath

const SQRT3 := 1.7320508075688772
## 尖顶六边形的六个轴向邻居偏移
const NEIGHBORS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


static func hex_to_pos(a: Vector2i, size: float) -> Vector2:
	var x := size * (SQRT3 * a.x + 0.5 * SQRT3 * a.y)
	var y := size * 1.5 * a.y
	return Vector2(x, y)


static func pos_to_hex(world_pos: Vector2, size: float) -> Vector2i:
	var qf: float = (SQRT3 / 3.0 * world_pos.x - (1.0 / 3.0) * world_pos.y) / size
	var rf: float = (2.0 / 3.0 * world_pos.y) / size
	return _axial_round(qf, rf)


static func _axial_round(qf: float, rf: float) -> Vector2i:
	var sf: float = -qf - rf
	var qx: float = round(qf)
	var rx: float = round(rf)
	var sx: float = round(sf)
	var qd: float = absf(qx - qf)
	var rd: float = absf(rx - rf)
	var sd: float = absf(sx - sf)
	if qd > rd and qd > sd:
		qx = -rx - sx
	elif rd > sd:
		rx = -qx - sx
	return Vector2i(int(qx), int(rx))


## 六边形距离
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## 返回 a 到 b 的直线六格序列（含两端），用于信息素标记/路径绘制。
static func line(a: Vector2i, b: Vector2i) -> Array:
	var n := distance(a, b)
	if n == 0:
		return [a]
	var step_a := _hex_lerp(a, b, 1.0 / float(n + 0.0))
	var step_b := step_a - a
	var line_result: Array = []
	for i in range(n + 1):
		var cur := a + step_b * i
		line_result.append(cur)
	return line_result


static func _hex_lerp(a: Vector2i, b: Vector2i, t: float) -> Vector2i:
	return Vector2i(
		round((1.0 - t) * a.x + t * b.x),
		round((1.0 - t) * a.y + t * b.y)
	)


static func neighbors(v: Vector2i) -> Array:
	var out: Array = []
	for d in NEIGHBORS:
		out.append(v + d)
	return out


## 半径 n 的圆盘内所有格（含中心）。用于主基地/关卡生成土壤。
static func disc(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for q in range(-radius, radius + 1):
		var r_lo := maxi(-q - radius, -radius)
		var r_hi := mini(-q + radius, radius)
		for r in range(r_lo, r_hi + 1):
			out.append(center + Vector2i(q, r))
	return out


## 六边形外环（用于校验建筑 7 格占据）。
static func ring(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	var cursor := center + Vector2i(0, -radius)
	for side in range(6):
		var step: Vector2i = NEIGHBORS[side]
		for _i in range(radius):
			out.append(cursor)
			cursor += step
	return out


static func key(a: Vector2i) -> String:
	return "%d,%d" % [a.x, a.y]


static func unkey(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1]))
