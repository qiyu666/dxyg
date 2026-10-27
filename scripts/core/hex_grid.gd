extends Node2D
## 六边形网格：承载地块/建筑/地面食物/尸体数据，并程序化绘制。
## 网格本身不跑模拟；模拟由 GameView 驱动。单位(蚂蚁/敌人)作为独立节点。
class_name HexGrid

## 圆盘半径（决定可玩区域大小）
var radius: int = 7
## 单格像素半径
var hex_size: float = 34.0
## 网格中心轴向坐标（恒为原点）
var center := Vector2i(0, 0)

## key("q,r") -> 地块字典
var tiles: Dictionary = {}
## key -> Building（蚁后室建在中心 key，其余按格）
var buildings: Dictionary = {}
var queen: Building = null

## 主基地受挖掘方块上限约束；关卡不受约束
var has_dig_cap: bool = true
var dig_remaining: int = 0

## 蚁后室是否已铺设
var has_queen: bool = false

## 当前选中的信息素队伍标记（供绘制）
var active_markers: Array = []
var marker_color: Color = Color(0.9, 0.5, 0.9)

signal changed


func _init() -> void:
	# 地块在半径确定后由 _build_tiles() 生成（GameView 在设好 radius 后调用）
	pass


## 依据当前 radius 重建全部地块（在设置 radius/hex_size 之后调用）
func _build_tiles() -> void:
	tiles.clear()
	for c in HexMath.disc(center, radius):
		tiles[HexMath.key(c)] = _empty_tile()


func _empty_tile() -> Dictionary:
	return {
		"type": GameConst.SOIL,
		"food": 0.0,          # 地面散落食物（关卡内采集）
		"corpse": 0,         # 尸体剩余可分解次数
		"corpse_food": 0.0,   # 每次分解得多少食物
		"building": null,     # Building
	}


# ---------- 布局 ----------
## 主基地：蚁后室占 7 格（中心 + 一环绕盘）。
func build_home_base() -> void:
	has_queen = true
	var cells: Array = [center]
	for c in HexMath.ring(center, 1):
		cells.append(c)
	for c in cells:
		tiles[HexMath.key(c)] = _queen_tile()
	queen = Building.new(GameConst.QUEEN)
	queen.cells = cells
	buildings[HexMath.key(center)] = queen


func _queen_tile() -> Dictionary:
	var t := _empty_tile()
	t["type"] = GameConst.QUEEN
	return t


## 关卡：把除蚁后室外的所有格开成空地（可通行/可建造/可放食物）。
func open_arena() -> void:
	for c in HexMath.disc(center, radius):
		var t: Dictionary = tiles[HexMath.key(c)]
		if t["type"] != GameConst.QUEEN:
			t["type"] = GameConst.OPEN
	queue_redraw()


# ---------- 查询 ----------
func key(c: Vector2i) -> String:
	return HexMath.key(c)


func has(c: Vector2i) -> bool:
	return tiles.has(key(c))


func type_at(c: Vector2i) -> String:
	var t: Dictionary = tiles.get(key(c), {})
	return t.get("type", "")


func building_at(c: Vector2i) -> Building:
	var t: Dictionary = tiles.get(key(c), {})
	return t.get("building", null)


func food_at(c: Vector2i) -> float:
	return tiles.get(key(c), {}).get("food", 0.0)


func is_walkable(c: Vector2i) -> bool:
	var t := type_at(c)
	return t != GameConst.SOIL


func is_open_buildable(c: Vector2i) -> bool:
	return type_at(c) == GameConst.OPEN


## 世界坐标 -> 轴向格。调用方传入的全局坐标，内部先转到本地绘制坐标。
func screen_to_hex(world_pos: Vector2) -> Vector2i:
	return HexMath.pos_to_hex(to_local(world_pos), hex_size)


# ---------- 挖掘 ----------
func can_dig(c: Vector2i) -> bool:
	if not has(c) or type_at(c) != GameConst.SOIL:
		return false
	if has_dig_cap and dig_remaining <= 0:
		return false
	return true


func dig(c: Vector2i) -> bool:
	if not can_dig(c):
		return false
	tiles[key(c)]["type"] = GameConst.OPEN
	if has_dig_cap:
		dig_remaining -= 1
		changed.emit()
	queue_redraw()
	return true


# ---------- 建造 ----------
## 在 c 建造 type。土块需先挖掘（消耗挖掘方块）；空地/已挖掘可直接建造。
func can_place(type: String, c: Vector2i) -> bool:
	if not BuildingData.can_build(type):
		return false
	var cur := type_at(c)
	if cur != GameConst.SOIL and cur != GameConst.OPEN:
		return false
	if cur == GameConst.SOIL and (has_dig_cap and dig_remaining <= 0):
		return false
	return true


func place(type: String, c: Vector2i) -> bool:
	if not can_place(type, c):
		return false
	if type_at(c) == GameConst.SOIL:
		dig(c)  # 内部已处理 dig_remaining
	var b := Building.new(type)
	b.cells = [c]
	var k := key(c)
	tiles[k]["type"] = type
	tiles[k]["building"] = b
	buildings[k] = b
	changed.emit()
	queue_redraw()
	return true


## 升级（校验点数与等级）；食物消耗由 GameView 扣除。
func can_upgrade(c: Vector2i) -> bool:
	var b := building_at(c)
	if b == null or not b.needs_upgrade():
		return false
	return BuildingData.upgrade_points(c, b.type, tiles) >= BuildingData.upgrade_points_required(b.level + 1)


func do_upgrade(c: Vector2i) -> bool:
	var b := building_at(c)
	if not can_upgrade(c):
		return false
	b.level += 1
	changed.emit()
	queue_redraw()
	return true


# ---------- 食物储量 / 加速（供 GameView） ----------
func sum_food_cap() -> float:
	var cap := 0.0
	for b in buildings.values():
		if b.type == GameConst.FOOD_STORAGE:
			cap += BuildingData.food_cap(b.level)
	return cap


func base_storage() -> float:
	return GameConst.QUEEN_BASE_STORAGE if has_queen else 0.0


## 全局蚂蚁移速加成（取等级最高加速方块）
func speed_bonus() -> float:
	var best := 0.0
	for b in buildings.values():
		if b.type == GameConst.SPEED_BLOCK:
			best = maxf(best, BuildingData.speed_bonus(b.level))
	return best


func count_type(type: String) -> int:
	var n := 0
	for b in buildings.values():
		if b.type == type:
			n += 1
	return n


func hatches_of_type(type: String) -> Array:
	var out: Array = []
	for b in buildings.values():
		if b.type == type:
			out.append(b)
	return out


# ---------- 尸体分解（第二关/第一关鼠妇） ----------
func add_corpse(c: Vector2i, food_per: float, times: int) -> void:
	if not tiles.has(key(c)):
		return
	var t: Dictionary = tiles[key(c)]
	t["corpse"] = times
	t["corpse_food"] = food_per
	changed.emit()
	queue_redraw()


## 地面食物增删（传负值即拾取）
func set_food(c: Vector2i, amt: float) -> void:
	if tiles.has(key(c)):
		tiles[key(c)]["food"] = amt
		queue_redraw()


func add_food(c: Vector2i, delta: float) -> void:
	if not tiles.has(key(c)):
		return
	tiles[key(c)]["food"] = maxf(0.0, float(tiles[key(c)].get("food", 0.0)) + delta)
	queue_redraw()


func food_cells() -> Array:
	var out: Array = []
	for k in tiles:
		if float(tiles[k].get("food", 0.0)) > 0.0:
			out.append(HexMath.unkey(k))
	return out


func corpse_cells() -> Array:
	var out: Array = []
	for k in tiles:
		if int(tiles[k].get("corpse", 0)) > 0:
			out.append(HexMath.unkey(k))
	return out


## 工蚁分解尸体一次：该格 +corpse_food，次数 -1
func decompose_corpse(c: Vector2i) -> bool:
	if not tiles.has(key(c)):
		return false
	var t: Dictionary = tiles[key(c)]
	if int(t.get("corpse", 0)) <= 0:
		return false
	t["corpse"] -= 1
	t["food"] = maxf(0.0, float(t.get("food", 0.0)) + float(t.get("corpse_food", 0.0)))
	if int(t["corpse"]) <= 0:
		t["corpse_food"] = 0.0
	changed.emit()
	queue_redraw()
	return true


# ---------- 绘制 ----------
func _draw() -> void:
	for c in HexMath.disc(center, radius):
		var t: Dictionary = tiles[HexMath.key(c)]
		var pos := HexMath.hex_to_pos(c, hex_size)
		var col := _tile_color(t["type"], c)
		draw_colored_polygon(_hex_points(pos, hex_size * 0.94), col)
		# 地面食物
		if t.get("food", 0.0) > 0.0:
			draw_circle(pos, 4.0, Color(0.85, 0.65, 0.25, 1.0))
		# 尸体
		if t.get("corpse", 0) > 0:
			draw_circle(pos + Vector2(0, 6), 5.0, Color(0.4, 0.3, 0.35, 1.0))
		# 建筑标记（蚁后由 QueenIcon 贴图/回退；此处画简单符号）
		_draw_building_marker(t, pos)

	# 选中队伍的信息素标记
	for m in active_markers:
		var p := HexMath.hex_to_pos(m as Vector2i, hex_size)
		draw_circle(p, 9.0, Color(marker_color.r, marker_color.g, marker_color.b, 0.9))
		draw_arc(p, 13.0, 0.0, TAU, 24, Color(marker_color.r, marker_color.g, marker_color.b, 0.5), 2.0)


func _draw_building_marker(t: Dictionary, pos: Vector2) -> void:
	var type: String = t["type"]
	match type:
		GameConst.SOLDIER_HATCH:
			_label(pos, "兵", Color(0.85, 0.35, 0.35))
		GameConst.WORKER_HATCH:
			_label(pos, "工", Color(0.4, 0.75, 0.95))
		GameConst.SPEED_BLOCK:
			_label(pos, "快", Color(0.95, 0.8, 0.35))
		GameConst.FOOD_STORAGE:
			_label(pos, "储", Color(0.6, 0.8, 0.45))
		_:
			pass
	var b: Building = t.get("building", null)
	if b != null and BuildingData.is_hatcher(b.type):
		# 发育阶段小点：卵(白)/幼虫(白)/蛹(黄)
		var off := pos + Vector2(10.0, -10.0)
		match b.dev_stage:
			GameConst.DEV_EGG:
				draw_circle(off, 3.0, Color(1.0, 1.0, 0.95, 0.95))
			GameConst.DEV_LARVA:
				draw_circle(off, 4.0, Color(0.95, 0.95, 0.9, 1.0))
			GameConst.DEV_PUPA:
				draw_circle(off, 4.5, Color(0.9, 0.78, 0.2, 1.0))
			_:
				pass


func _label(pos: Vector2, text: String, col: Color) -> void:
	var s := 22.0
	draw_string(ThemeDB.fallback_font, pos + Vector2(-s / 2, s / 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, s, col)


func _tile_color(type: String, c: Vector2i) -> Color:
	match type:
		GameConst.SOIL:
			return Color(0.16, 0.15, 0.13)
		GameConst.OPEN:
			return Color(0.30, 0.27, 0.22)
		GameConst.QUEEN:
			return Color(0.45, 0.15, 0.15)
		GameConst.SOLDIER_HATCH:
			return Color(0.35, 0.18, 0.18)
		GameConst.WORKER_HATCH:
			return Color(0.18, 0.26, 0.35)
		GameConst.SPEED_BLOCK:
			return Color(0.4, 0.35, 0.18)
		GameConst.FOOD_STORAGE:
			return Color(0.24, 0.33, 0.2)
		_:
			return Color(0.2, 0.2, 0.2)


func _hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := PI / 180.0 * (60.0 * i - 90.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * size)
	return pts


# ---------- 信息素标记绘制（由 GameView 传入） ----------
func _draw_markers(markers: Array) -> void:
	for m in markers:
		var p := HexMath.hex_to_pos(m as Vector2i, hex_size)
		draw_circle(p, 8.0, Color(0.9, 0.5, 0.9, 0.9))
		draw_arc(p, 12.0, 0.0, TAU, 24, Color(0.9, 0.5, 0.9, 0.5), 2.0)
