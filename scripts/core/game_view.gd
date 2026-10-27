extends Node2D
## 主场景：主基地（家）与关卡共用的六边形殖民地。
## 承载六边形网格、资源、信息素队伍、蚂蚁/敌人模拟，以及 建筑/信息/信息素/进化/关卡 UI。
class_name GameView

signal finished(success: bool, rewards: Dictionary)   # 关卡结束
signal want_menu()                                      # 主基地返回主菜单
signal want_level(def: LevelDef)                        # 从主基地进入关卡

var home: Dictionary = {}
var level: LevelDef = null
var is_home: bool = true

var grid: HexGrid
var teams: Array = []
var ants: Array = []
var enemies: Array = []
var queen_icon: QueenIcon

## 资源
var food: float = 0.0
var storage_cap: float = 0.0
var queen_hp: float = 0.0

## 模拟参数
var max_ants: int = 150
var _corpse_timer: float = 0.0
var _assault_timer: float = 0.0
var _over: bool = false

## 蚁后产卵 / 孵化流水线
var queen_eggs: int = 0
var queen_egg_timer: float = 0.0
## 孵化室 -> 其名下活跃蚁数量
var hatch_alive: Dictionary = {}

## UI
var _top_bar: Control
var _food_label: Label
var _worker_label: Label
var _soldier_label: Label
var _dig_label: Label
var _toast_label: Label
var _tap_area: Control
var _panels: Dictionary = {}
var _team_chips: Array = []
var _chip_clicks: Dictionary = {}
var _selected_team: int = -1
var _mode: String = "build"          # build / info / pheromone / evolve
var _build_tool: String = GameConst.WORKER_HATCH
var _selected_hex: Vector2i = Vector2i(-99, -99)

## 输入
var _press_active: bool = false
var _press_time: int = 0
var _last_place_hex: Vector2i = Vector2i(-99, -99)


func _init(p_home: Dictionary, p_level: LevelDef) -> void:
	home = p_home
	level = p_level
	is_home = (p_level == null)


func _ready() -> void:
	_setup_grid()
	_setup_teams()
	_setup_food()
	_spawn_initial_ants()
	if not is_home:
		_spawn_level_enemies()
		_scatter_ground_food()
		queen_hp = 100.0
	_build_ui()
	_update_top_bar()
	_show_panel("build")
	_refresh_markers()


# ---------- 初始化 ----------
func _setup_grid() -> void:
	grid = HexGrid.new()
	grid.hex_size = (level.grid_hex_size if not is_home else 32.0)
	grid.radius = (level.radius if not is_home else 7)
	grid._build_tiles()   # 必须在 radius 确定后生成地块
	add_child(grid)
	# 让网格居中于顶部栏与底部栏之间的区域
	var vp := get_viewport().get_visible_rect().size
	grid.position = Vector2(vp.x * 0.5, vp.y * 0.45)

	if is_home:
		grid.has_dig_cap = true
		grid.dig_remaining = int(home.get("dig_cap", 40))
		grid.build_home_base()
	else:
		grid.has_dig_cap = false
		grid.build_home_base()
		grid.open_arena()
	# 蚁后图标（主基地与关卡都显示）
	queen_icon = QueenIcon.new()
	queen_icon.position = HexMath.hex_to_pos(grid.center, grid.hex_size)
	var cc := colony_color()
	queen_icon.set_glow(Color(cc.r, cc.g, cc.b, 0.25))
	grid.add_child(queen_icon)


func _setup_teams() -> void:
	for i in GameConst.TEAM_COUNT:
		teams.append(Pheromone.new(i))


func _setup_food() -> void:
	if is_home:
		food = float(home.get("food", 35.0))
		storage_cap = grid.base_storage() + grid.sum_food_cap()
	else:
		food = 35.0
		storage_cap = grid.base_storage() + grid.sum_food_cap()


func _spawn_initial_ants() -> void:
	var n := (level.initial_workers if not is_home else 7)
	for i in n:
		_spawn_ant(false, grid.center)


func _spawn_ant(is_soldier: bool, cell: Vector2i) -> Ant:
	if ants.size() >= max_ants:
		return null
	var a := Ant.new(is_soldier, colony_color())
	a.apply_evolutions(home)
	a.position = HexMath.hex_to_pos(cell, grid.hex_size) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	grid.add_child(a)
	ants.append(a)
	return a


func _colony_color() -> Color:
	var c: Array = home.get("color", [180, 120, 60, 255])
	var a: float = (c[3] / 255.0) if c.size() > 3 else 1.0
	return Color(float(c[0]) / 255.0, float(c[1]) / 255.0, float(c[2]) / 255.0, a)

func colony_color() -> Color:
	return _colony_color()


func _spawn_level_enemies() -> void:
	# 蛛丝蜘蛛：洞穴 + 大量食物
	for i in level.silk_spiders:
		var cell := _random_open_cell(2)
		grid.add_food(cell, level.silk_spider_food_each)
		var sp := Enemy.new("silk_spider")
		sp.home_cell = cell
		sp.grid_hex = cell
		sp.position = HexMath.hex_to_pos(cell, grid.hex_size)
		grid.add_child(sp)
		enemies.append(sp)
	# 普通敌人
	for spn in level.enemy_spawns:
		var cnt: int = spn.get("count", 0)
		for i in cnt:
			var cell := _random_open_cell(1)
			var e := Enemy.new(spn.get("type", "beetle"))
			e.grid_hex = cell
			e.position = HexMath.hex_to_pos(cell, grid.hex_size)
			grid.add_child(e)
			enemies.append(e)


func _scatter_ground_food() -> void:
	if level.ground_food_total <= 0.0:
		return
	var spots := 50
	var per := level.ground_food_total / float(spots)
	for i in spots:
		grid.add_food(_random_open_cell(0), per)


func _random_open_cell(min_dist: int) -> Vector2i:
	for _i in 40:
		var q := randi_range(-grid.radius + 1, grid.radius - 1)
		var r := randi_range(-grid.radius + 1, grid.radius - 1)
		var c := Vector2i(q, r)
		if not grid.has(c):
			continue
		if grid.type_at(c) != GameConst.OPEN and grid.type_at(c) != GameConst.SOIL:
			continue
		if HexMath.distance(grid.center, c) < min_dist:
			continue
		return c
	return grid.center


# ---------- 模拟 ----------
func _process(delta: float) -> void:
	if _over:
		return
	var dt := minf(delta, 0.05)
	_queen_egg_progress(dt)
	_develop_hatches(dt)
	_apply_deployment()
	for a in ants:
		a.update(dt, self)
	for e in enemies:
		e.update(dt, self)
	_cleanup_dead()
	_corpse_progress(dt)
	if not is_home:
		_assault_progress(dt)
		_queen_hp_check()
	_check_end()
	_update_top_bar()


# ---------- 蚁后产卵 / 孵化流水线 ----------
## 蚁后按节奏产卵（排队，上限 QUEEN_EGG_CAP）
func _queen_egg_progress(dt: float) -> void:
	if queen_eggs >= GameConst.QUEEN_EGG_CAP:
		return
	queen_egg_timer += dt
	if queen_egg_timer >= GameConst.QUEEN_EGG_INTERVAL:
		queen_egg_timer = 0.0
		queen_eggs += 1


## 孵化室发育：卵 -> 白幼虫 -> 黄蛹 -> 羽化(需食物)
func _develop_hatches(dt: float) -> void:
	for k in grid.buildings:
		var b: Building = grid.buildings[k]
		if not BuildingData.is_hatcher(b.type):
			continue
		if b.dev_stage == GameConst.DEV_NONE:
			continue
		var factor: float = GameConst.HATCH_FAST_FACTOR if b.dev_fast else 1.0
		b.dev_time += dt / factor
		match b.dev_stage:
			GameConst.DEV_EGG:
				if b.dev_time >= GameConst.EGG_TO_LARVA_TIME:
					b.dev_stage = GameConst.DEV_LARVA
					b.dev_time = 0.0
			GameConst.DEV_LARVA:
				if b.dev_time >= GameConst.LARVA_TO_PUPA_TIME:
					b.dev_stage = GameConst.DEV_PUPA
					b.dev_time = 0.0
			GameConst.DEV_PUPA:
				# 蛹 -> 活跃蚁需食物；不足则停在蛹阶段
				if b.dev_time >= GameConst.PUPA_TO_HATCH_TIME and food >= GameConst.HATCH_FOOD_COST:
					food -= GameConst.HATCH_FOOD_COST
					_hatch_hatch(b, k)
		if b.dev_stage == GameConst.DEV_NONE:
			b.dev_fast = false


## 蛹羽化为活跃蚁，补位到孵化室
func _hatch_hatch(b: Building, key: String) -> void:
	var is_soldier: bool = b.type == GameConst.SOLDIER_HATCH
	var cell := HexMath.unkey(key)
	var a := _spawn_ant(is_soldier, cell)
	if a != null:
		a.hatch_key = key
		if b.team_index >= 0 and b.team_index < teams.size():
			a.team = teams[b.team_index]
		var cnt: int = int(hatch_alive.get(key, 0))
		hatch_alive[key] = cnt + 1
	b.dev_stage = GameConst.DEV_NONE
	b.dev_time = 0.0
	b.dev_fast = false
	_recompute_cap()
	_update_top_bar()


## 蚁后是否有可取卵
func queen_has_egg() -> bool:
	return queen_eggs > 0


## 空孵化室数量（无在发育蚁且未被预留）
func empty_hatch_count() -> int:
	var n := 0
	for k in grid.buildings:
		var b: Building = grid.buildings[k]
		if not BuildingData.is_hatcher(b.type):
			continue
		if b.dev_stage == GameConst.DEV_NONE and not b.dev_reserved:
			n += 1
	return n


## 预留一个空孵化室并消耗一枚蚁后卵（工蚁正在往那里送卵）
func reserve_empty_hatch() -> String:
	if queen_eggs <= 0:
		return ""
	for k in grid.buildings:
		var b: Building = grid.buildings[k]
		if not BuildingData.is_hatcher(b.type):
			continue
		if b.dev_stage == GameConst.DEV_NONE and not b.dev_reserved:
			b.dev_reserved = true
			queen_eggs -= 1
			return k
	return ""


func unreserve_hatch(key: String) -> void:
	var b: Building = grid.buildings.get(key, null)
	if b != null:
		b.dev_reserved = false


## 把卵放入孵化室（仅在仍空时；失败则退回一枚卵）
func deposit_egg(key: String) -> bool:
	var b: Building = grid.buildings.get(key, null)
	if b == null:
		return false
	if b.dev_stage != GameConst.DEV_NONE:
		b.dev_reserved = false
		queen_eggs += 1   # 退回预留时扣的卵
		return false
	b.dev_stage = GameConst.DEV_EGG
	b.dev_time = 0.0
	b.dev_reserved = false
	grid.queue_redraw()
	return true


## 孵化室 key 对应的格坐标
func hatch_hex(key: String) -> Vector2i:
	return HexMath.unkey(key)


func _apply_deployment() -> void:
	# max_mobilize 约束：每队最多出动 N 只，其余待命
	for t in teams:
		if t.max_mobilize <= 0:
			for a in ants:
				if a.team == t:
					a.deployed = true
			continue
		var idx := 0
		for a in ants:
			if a.team == t and a.alive:
				if idx < t.max_mobilize:
					a.deployed = true
				else:
					a.deployed = false
				idx += 1


func _cleanup_dead() -> void:
	var i := ants.size() - 1
	while i >= 0:
		if not ants[i].alive:
			_on_ant_removed(ants[i] as Ant)
			ants[i].queue_free()
			ants.remove_at(i)
		i -= 1
	i = enemies.size() - 1
	while i >= 0:
		if not enemies[i].alive:
			enemies[i].queue_free()
			enemies.remove_at(i)
		i -= 1


## 蚁死亡后的善后：归还卵预留、孵化室活跃蚁计数、加速补位
func _on_ant_removed(a: Ant) -> void:
	if a.carrying_egg and a._egg_target != "":
		unreserve_hatch(a._egg_target)
	if a.hatch_key != "":
		var k := a.hatch_key
		var cnt: int = int(hatch_alive.get(k, 0)) - 1
		hatch_alive[k] = maxi(0, cnt)
		if cnt <= 0:
			var b: Building = grid.buildings.get(k, null)
			if b != null and b.dev_stage != GameConst.DEV_NONE:
				b.dev_fast = true


func _corpse_progress(dt: float) -> void:
	_corpse_timer -= dt
	if _corpse_timer > 0.0:
		return
	_corpse_timer = 1.0
	for c in grid.corpse_cells():
		if _any_ally_on(c):
			grid.decompose_corpse(c)


func _any_ally_on(c: Vector2i) -> bool:
	for a in ants:
		if not a.alive:
			continue
		if a.is_soldier:
			continue
		if grid.screen_to_hex(a.global_position) == c:
			return true
	return false


func _assault_progress(dt: float) -> void:
	if level.enemy_assault_interval <= 0.0:
		return
	_assault_timer += dt
	if _assault_timer >= level.enemy_assault_interval:
		_assault_timer = 0.0
		_do_assault()


func _do_assault() -> void:
	# 派一队敌对蚂蚁从出口进入
	for _i in 3:
		var cell := _random_edge_cell()
		var e := Enemy.new("enemy_ant")
		e.grid_hex = cell
		e.position = HexMath.hex_to_pos(cell, grid.hex_size)
		grid.add_child(e)
		enemies.append(e)
	var alive := _alive_ants()
	if alive.size() >= level.enemy_assault_steal:
		for i in level.enemy_assault_steal:
			var victim: Ant = alive[i]
			victim.alive = false
		_toast("敌对蚂蚁来袭：窃走了 %d 只蚁！" % level.enemy_assault_steal)
	else:
		queen_hp -= 40.0
		_toast("无幼蚁可窃，敌对蚂蚁攻击蚁后！")
		if queen_hp <= 0.0:
			_lose()


func _random_edge_cell() -> Vector2i:
	var ring_cells := HexMath.ring(grid.center, grid.radius)
	return ring_cells[randi() % ring_cells.size()]


func _queen_hp_check() -> void:
	if queen_hp <= 0.0 and not _over:
		_lose()


func _alive_ants() -> Array:
	var out: Array = []
	for a in ants:
		if a.alive:
			out.append(a)
	return out


# ---------- 结束判定 ----------
func _check_end() -> void:
	if is_home or _over:
		return
	match level.victory.get("type", ""):
		"kill_all":
			if enemies.is_empty():
				_win()
		"build":
			if grid.count_type(GameConst.SOLDIER_HATCH) >= int(level.victory.get("soldier", 0)) \
					and grid.count_type(GameConst.WORKER_HATCH) >= int(level.victory.get("worker", 0)):
				_win()
	# 死锁判定：无活蚁且无孵化室 -> 无法再行动
	if not is_home:
		if _alive_ants().is_empty() and grid.count_type(GameConst.WORKER_HATCH) == 0 \
				and grid.count_type(GameConst.SOLDIER_HATCH) == 0:
			_lose()


func _win() -> void:
	_over = true
	_toast("关卡通过！结算奖励到家。")
	finished.emit(true, level.rewards)


func _lose() -> void:
	_over = true
	_toast("蚁后失守……关卡失败。")
	finished.emit(false, {})


# ---------- 视图供单位使用的方法 ----------
func speed_mult() -> float:
	return 1.0


func storage_cell() -> Vector2i:
	for k in grid.buildings:
		if grid.buildings[k].type == GameConst.FOOD_STORAGE:
			return HexMath.unkey(k)
	return grid.center


func home_cell() -> Vector2i:
	return grid.center


func can_carry_more() -> bool:
	return food < storage_cap - 0.01


func deposit(amt: float) -> void:
	food = minf(food + amt, storage_cap)
	_recompute_cap()


func _recompute_cap() -> void:
	storage_cap = grid.base_storage() + grid.sum_food_cap()


func enemy_near(c: Vector2i, d: int) -> Enemy:
	var best: Enemy = null
	var bd: int = 999
	for e in enemies:
		if not e.alive:
			continue
		var dist: int = HexMath.distance(c, grid.screen_to_hex((e as Enemy).global_position))
		if dist <= d and dist < bd:
			bd = dist
			best = e
	return best


func nearest_enemy(c: Vector2i) -> Enemy:
	return _nearest_in(c, enemies) as Enemy


func nearest_ant(world: Vector2, within_px: float) -> Ant:
	var best: Ant = null
	var bd: float = within_px
	for a in ants:
		if not a.alive:
			continue
		var d: float = (a as Ant).global_position.distance_to(world)
		if d < bd:
			bd = d
			best = a
	return best


func enemy_near_ally_ant(c: Vector2i, d: int) -> Ant:
	var best: Ant = null
	var bd: int = 999
	for a in ants:
		if not a.alive:
			continue
		var dist: int = HexMath.distance(c, grid.screen_to_hex((a as Ant).global_position))
		if dist <= d and dist < bd:
			bd = dist
			best = a
	return best


func enemy_target_hex(e: Enemy) -> Vector2i:
	var c: Vector2i = e.grid_hex
	var a: Node2D = _nearest_in(c, ants)
	if a != null:
		return grid.screen_to_hex(a.global_position)
	var f: Vector2i = nearest_food(c)
	if f != GameConst.NO_CELL:
		return f
	return home_cell()


func nearest_food(c: Vector2i) -> Vector2i:
	var best: Vector2i = GameConst.NO_CELL
	var bd: int = 999
	for fc in grid.food_cells():
		var cell: Vector2i = fc
		var d: int = HexMath.distance(c, cell)
		if d < bd:
			bd = d
			best = cell
	return best


func _nearest_in(c: Vector2i, list: Array) -> Node2D:
	var best: Node2D = null
	var bd: int = 999
	for u in list:
		if not u.alive:
			continue
		var unode: Node2D = u
		var uhex: Vector2i = grid.screen_to_hex(unode.global_position)
		var d: int = HexMath.distance(c, uhex)
		if d < bd:
			bd = d
			best = unode
	return best


func enemy_died(e: Enemy) -> void:
	# 掉落食物/尸体；数组与节点清理统一在 _cleanup_dead（避免重复 erase）
	if e.death_food > 0.0:
		grid.add_food(e.grid_hex, e.death_food)
	if e.corpse_decomp > 0:
		grid.add_corpse(e.grid_hex, e.corpse_food, e.corpse_decomp)


func ant_died(_a: Ant) -> void:
	# 阵亡蚂蚁仅记录；节点/数组由 _cleanup_dead 清理
	pass


# ---------- 输入 ----------
func _on_tap_input(event: InputEvent) -> void:
	var pos: Vector2
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = event.position
		if event.pressed:
			_on_press(pos)
		else:
			_on_release(pos)
	elif event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			_on_press(pos)
		else:
			_on_release(pos)
	elif event is InputEventScreenDrag:
		if event.pressed:
			_on_drag(event.position)


func _on_press(pos: Vector2) -> void:
	_press_active = true
	_press_time = Time.get_ticks_msec()
	_last_place_hex = grid.screen_to_hex(pos)


func _on_drag(pos: Vector2) -> void:
	if not _press_active:
		return
	var hex := grid.screen_to_hex(pos)
	if hex == _last_place_hex:
		return
	_last_place_hex = hex
	_place_now(hex, false)


func _on_release(pos: Vector2) -> void:
	_press_active = false
	var hex := grid.screen_to_hex(pos)
	var dur := Time.get_ticks_msec() - _press_time
	_place_now(hex, dur > 450)


func _place_now(hex: Vector2i, long_press: bool) -> void:
	if not grid.has(hex):
		return
	match _mode:
		"pheromone":
			_pheromone_tap(hex, long_press)
		"build":
			_build_tap(hex)
		"info":
			_selected_hex = hex
			_refresh_info()
		"evolve":
			pass


func _pheromone_tap(hex: Vector2i, long_press: bool) -> void:
	if _selected_team < 0:
		return
	var t: Pheromone = teams[_selected_team]
	# 点击孵化室 -> 分配给该队
	var b := grid.building_at(hex)
	if b != null and BuildingData.is_hatcher(b.type):
		if long_press:
			b.team_index = -1
			t.clear_hatches()
			_toast("已清空队伍 %s 的孵化室" % t.label())
		else:
			t.assign_hatch(hex)
			b.team_index = _selected_team
			_toast("孵化室已分配给队伍 %s" % t.label())
		_refresh_markers()
		return
	# 点击/拖拽放信息素标记
	if long_press and t.marker_at(hex):
		t.remove_marker(hex)
		_toast("删除信息素标记")
	else:
		if not t.marker_at(hex):
			t.add_marker(hex)
	_refresh_markers()


func _build_tap(hex: Vector2i) -> void:
	match _build_tool:
		"dig":
			if grid.can_dig(hex):
				grid.dig(hex)
			else:
				_toast("无法挖掘（非土块或超出挖掘上限）")
		"upgrade":
			_try_upgrade(hex)
		_:
			var cost := BuildingData.build_cost(_build_tool)
			if not grid.can_place(_build_tool, hex):
				_toast("此处无法建造")
				return
			if food < cost:
				_toast("食物不足（需 %d）" % int(cost))
				return
			food -= cost
			grid.place(_build_tool, hex)
			_recompute_cap()
			_update_top_bar()


func _try_upgrade(hex: Vector2i) -> void:
	var b := grid.building_at(hex)
	if b == null:
		_toast("该格没有可升级建筑")
		return
	if not grid.can_upgrade(hex):
		var need := BuildingData.upgrade_points_required(b.level + 1)
		_toast("点数不足（需 %d 点，当前 %d 点）" % [need, BuildingData.upgrade_points(hex, b.type, grid.tiles)])
		return
	var cost := BuildingData.build_cost(b.type)
	if food < cost:
		_toast("升级消耗 %d 食物，不足" % int(cost))
		return
	food -= cost
	grid.do_upgrade(hex)
	_recompute_cap()
	_update_top_bar()


# ---------- UI ----------
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var vp := get_viewport().get_visible_rect().size

	# 触摸区（网格区域）
	_tap_area = Control.new()
	_tap_area.name = "TapArea"
	_tap_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_tap_area.offset_top = 56.0
	_tap_area.offset_bottom = -(168.0)
	_tap_area.gui_input.connect(_on_tap_input)
	ui.add_child(_tap_area)

	# 顶栏
	_top_bar = Control.new()
	_top_bar.name = "TopBar"
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.offset_bottom = 56.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(_top_bar)
	_build_top_bar(vp)

	# 面板区（建筑/信息/信息素/进化）
	for p in ["build", "info", "pheromone", "evolve"]:
		var panel := _make_panel(vp)
		_panels[p] = panel
		ui.add_child(panel)
	_build_build_panel()
	_build_pheromone_panel()
	_build_evolve_panel()

	# 底栏
	var bottom := Control.new()
	bottom.name = "BottomBar"
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -(168.0)
	bottom.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(bottom)
	_build_bottom_bar(vp, bottom)

	# toast
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.position = Vector2(vp.x * 0.5 - 200, 64)
	_toast_label.size = Vector2(400, 40)
	_toast_label.modulate.a = 0.0
	_toast_label.text = ""
	ui.add_child(_toast_label)


func _make_panel(vp: Vector2) -> Control:
	var p := Control.new()
	p.anchor_left = 0.0
	p.anchor_right = 1.0
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_top = -(168.0 + 150.0)
	p.offset_bottom = -(168.0)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.visible = false
	return p


func _build_top_bar(vp: Vector2) -> void:
	_food_label = _add_label(_top_bar, "食物 0/0", Vector2(12, 14))
	_worker_label = _add_label(_top_bar, "工蚁 0", Vector2(170, 14))
	_soldier_label = _add_label(_top_bar, "兵蚁 0", Vector2(330, 14))
	_dig_label = _add_label(_top_bar, "", Vector2(470, 14))

	if is_home:
		_add_button(_top_bar, "进化", Vector2(vp.x - 320, 8), 90, 40, func() -> void: _show_panel("evolve"))
		_add_button(_top_bar, "关卡", Vector2(vp.x - 220, 8), 90, 40, func() -> void: _open_level_picker())
		_add_button(_top_bar, "菜单", Vector2(vp.x - 120, 8), 90, 40, func() -> void: want_menu.emit())
	else:
		var cb_abandon := func():
			_over = true
			_save_home_if_needed()
			finished.emit(false, {})
		_add_button(_top_bar, "放弃", Vector2(vp.x - 120, 8), 90, 40, cb_abandon)


func _build_bottom_bar(vp: Vector2, parent: Control) -> void:
	var y := 16.0
	var w := vp.x / 3.0
	_add_button(parent, "建筑", Vector2(4, y), w - 8, 56, func() -> void: _show_panel("build"))
	_add_button(parent, "信息", Vector2(w + 4, y), w - 8, 56, func() -> void: _show_panel("info"))
	_add_button(parent, "信息素", Vector2(w * 2 + 4, y), w - 8, 56, func() -> void: _show_panel("pheromone"))
	# 进化按钮（关卡/家都可）
	_add_button(parent, "进化", Vector2(4, y + 64), vp.x / 2 - 8, 44, func() -> void: _show_panel("evolve"))
	# 帮助
	_add_button(parent, "说明", Vector2(vp.x / 2 + 4, y + 64), vp.x / 2 - 8, 44, func() -> void: _toast("蚁后产卵→工蚁取卵进空孵化室→卵→白幼虫→黄蛹→耗食物羽化；兵蚁不搬卵"))


func _build_build_panel() -> void:
	var p: Control = _panels["build"]
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(vb)
	var row1 := HBoxContainer.new()
	vb.add_child(row1)
	for t in [GameConst.SOLDIER_HATCH, GameConst.WORKER_HATCH, GameConst.SPEED_BLOCK, GameConst.FOOD_STORAGE]:
		var btn := _tool_button(_label_for_tool(t))
		var tool: String = t
		var cb_tool := func():
			_build_tool = tool
			_mark_tool(btn)
			_refresh_active_tool()
		btn.pressed.connect(cb_tool)
		row1.add_child(btn)
	var dig := _tool_button("挖掘")
	var cb_dig := func():
		_build_tool = "dig"
		_mark_tool(dig)
		_refresh_active_tool()
	dig.pressed.connect(cb_dig)
	row1.add_child(dig)
	var up := _tool_button("升级")
	var cb_up := func():
		_build_tool = "upgrade"
		_mark_tool(up)
		_refresh_active_tool()
	up.pressed.connect(cb_up)
	row1.add_child(up)
	var hint := _add_label(p, "点选工具后在地图上操作。食物：兵蚁50/工蚁5/加速5/储存5；升级=建造花费", Vector2(8, 56))
	hint.add_theme_font_size_override("font_size", 16)


func _build_pheromone_panel() -> void:
	var p: Control = _panels["pheromone"]
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(vb)
	var row := HBoxContainer.new()
	vb.add_child(row)
	for i in GameConst.TEAM_COUNT:
		var chip := _tool_button("队%s" % GameConst.TEAM_NAMES[i])
		_chip_clicks[i] = 0
		chip.pressed.connect(func() -> void: _team_chip_pressed(i, chip))
		row.add_child(chip)
		_team_chips.append(chip)
	var opt_row := HBoxContainer.new()
	vb.add_child(opt_row)
	var atk := _tool_button("攻击:开")
	atk.pressed.connect(func() -> void: _toggle_team_opt("attack", atk))
	opt_row.add_child(atk)
	var carry := _tool_button("搬运:开")
	carry.pressed.connect(func() -> void: _toggle_team_opt("carry", carry))
	opt_row.add_child(carry)
	var maxl := Label.new()
	maxl.text = "出动:不限"
	maxl.add_theme_font_size_override("font_size", 18)
	opt_row.add_child(maxl)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 40
	slider.value = 0
	slider.custom_minimum_size = Vector2(0, 30)
	var cb_ph := func(v: float):
		if _selected_team >= 0:
			teams[_selected_team].max_mobilize = int(v)
		maxl.text = "出动:不限" if int(v) == 0 else ("出动:%d" % int(v))
	slider.value_changed.connect(cb_ph)
	vb.add_child(slider)
	_ph_slider = slider
	_ph_atk = atk
	_ph_carry = carry
	_ph_max_label = maxl


var _ph_slider: HSlider
var _ph_atk: Button
var _ph_carry: Button
var _ph_max_label: Label


func _build_evolve_panel() -> void:
	var p: Control = _panels["evolve"]
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(vb)
	var head := _add_label(p, "蚁皇浆：%d（通关关卡获得）" % int(home.get("royal_jelly", 0)), Vector2(8, 6))
	head.add_theme_font_size_override("font_size", 18)
	var list := VBoxContainer.new()
	vb.add_child(list)
	for key in GameConst.EVOLUTIONS:
		var cost: int = GameConst.EVOLUTION_JELLY_COST[key]
		var unlocked: bool = home.get("evolutions", []).has(key)
		var b := _tool_button("%s  [%d浆]%s" % [GameConst.EVOLUTIONS[key], cost, " 已解锁" if unlocked else ""])
		b.disabled = unlocked
		b.pressed.connect(func() -> void: _try_evolve(key, cost))
		list.add_child(b)


# ---------- 面板/工具辅助 ----------
func _show_panel(name: String) -> void:
	_mode = name if name == "build" or name == "info" else name
	# "evolve"/"build"/"info" 显示对应面板；"pheromone" 是底栏模式
	_mode = name
	for k in _panels:
		_panels[k].visible = (k == name)
	_refresh_active_tool()
	_refresh_info()
	if name == "pheromone":
		_refresh_markers()
	_refresh_ph_panel()


func _refresh_active_tool() -> void:
	# 高亮当前选中工具按钮（简化：仅切换显示，样式略）
	pass


func _mark_tool(btn: Control) -> void:
	# 简单高亮
	if btn is Button:
		btn.modulate = Color(1.2, 1.2, 1.0)
		for b in get_tree().get_nodes_in_group("toolbtn"):
			if b != btn:
				b.modulate = Color.WHITE


func _tool_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_content_margin_override("margin", 4.0)
	b.add_to_group("toolbtn")
	return b


func _add_label(parent: Control, text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(l)
	return l


func _add_button(parent: Control, text: String, pos: Vector2, w: float, h: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _label_for_tool(t: String) -> String:
	match t:
		GameConst.SOLDIER_HATCH:
			return "兵蚁孵化室"
		GameConst.WORKER_HATCH:
			return "工蚁孵化室"
		GameConst.SPEED_BLOCK:
			return "加速方块"
		GameConst.FOOD_STORAGE:
			return "食物储存区"
		_:
			return t


# ---------- 队伍交互 ----------
func _team_chip_pressed(i: int, chip: Button) -> void:
	var now := Time.get_ticks_msec()
	var last: int = _chip_clicks.get(i, 0)
	if now - last < 350:
		# 双击清空该队孵化室分配
		var t: Pheromone = teams[i]
		for c in t.hatches:
			var b := grid.building_at(c)
			if b != null:
				b.team_index = -1
		t.clear_hatches()
		_chip_clicks[i] = 0
		_toast("已清空队伍 %s 的孵化室" % t.label())
		_refresh_markers()
		return
	_chip_clicks[i] = now
	_selected_team = i
	_refresh_markers()
	_refresh_ph_panel()


func _toggle_team_opt(which: String, btn: Button) -> void:
	if _selected_team < 0:
		_toast("请先选择一支队伍")
		return
	var t: Pheromone = teams[_selected_team]
	if which == "attack":
		t.allow_attack = not t.allow_attack
		btn.text = "攻击:开" if t.allow_attack else "攻击:关"
	else:
		t.allow_carry = not t.allow_carry
		btn.text = "搬运:开" if t.allow_carry else "搬运:关"


func _selected_team_ref() -> Pheromone:
	return teams[_selected_team] if _selected_team >= 0 else null


## 刷新信息素面板的开关显示（切换队伍时）
func _refresh_ph_panel() -> void:
	if _selected_team < 0:
		return
	var t: Pheromone = teams[_selected_team]
	_ph_atk.text = "攻击:开" if t.allow_attack else "攻击:关"
	_ph_carry.text = "搬运:开" if t.allow_carry else "搬运:关"
	_ph_max_label.text = "出动:不限" if t.max_mobilize == 0 else ("出动:%d" % t.max_mobilize)
	_ph_slider.value = t.max_mobilize


func _refresh_markers() -> void:
	if _selected_team >= 0:
		var t: Pheromone = teams[_selected_team]
		grid.active_markers = t.markers
		grid.marker_color = Color(0.9, 0.5, 0.9)
	else:
		grid.active_markers = []
	grid.queue_redraw()


func _try_evolve(key: String, cost: int) -> void:
	var jelly := int(home.get("royal_jelly", 0))
	if jelly < cost:
		_toast("蚁皇浆不足")
		return
	if home.get("evolutions", []).has(key):
		return
	home["royal_jelly"] = jelly - cost
	if not home.has("evolutions"):
		home["evolutions"] = []
	(home["evolutions"] as Array).append(key)
	# 给现存蚂蚁即时应用
	for a in ants:
		a.apply_evolutions(home)
	_toast("进化解锁：" + GameConst.EVOLUTIONS[key])
	if is_home:
		SaveSystem.save_home(home)


# ---------- 关卡入口 ----------
func _open_level_picker() -> void:
	_toast("点击「关卡」选择第一关或第二关")
	# 简化：默认进入未通关的第一关；已通关进入第二关
	if not home.get("cleared_levels", []).has("ch1_l1"):
		_start_level("ch1_l1")
	else:
		_start_level("ch1_l2")


func _start_level(id: String) -> void:
	# 由主流程接管场景切换
	var def: LevelDef
	if id == "ch1_l1":
		def = Level1.new()
	else:
		def = Level2.new()
	_save_home_if_needed()
	want_level.emit(def)


# ---------- 存档 ----------
func _save_home_if_needed() -> void:
	if is_home:
		home["food"] = food
		SaveSystem.save_home(home)


func _to_msg() -> String:
	return ""


# ---------- 顶栏刷新 ----------
func _update_top_bar() -> void:
	var w := 0
	var s := 0
	for a in ants:
		if a.alive:
			if a.is_soldier:
				s += 1
			else:
				w += 1
	_food_label.text = "食物 %d/%d" % [int(food), int(storage_cap)]
	_worker_label.text = "工蚁 %d" % w
	_soldier_label.text = "兵蚁 %d" % s
	if is_home:
		_dig_label.text = "挖掘 %d" % grid.dig_remaining
	else:
		_dig_label.text = ""


func _refresh_info() -> void:
	# 简化：在信息面板显示选中格信息
	var p: Control = _panels["info"]
	for ch in p.get_children():
		ch.queue_free()
	var lines: Array = []
	lines.append("蚁后可取卵 %d（兵蚁不搬卵；蛹羽化需 %d 食物）" % [queen_eggs, int(GameConst.HATCH_FOOD_COST)])
	if _selected_hex == Vector2i(-99, -99) or not grid.has(_selected_hex):
		lines.append("点击地图选择一个格子/建筑。")
	else:
		var b := grid.building_at(_selected_hex)
		var t := grid.type_at(_selected_hex)
		lines.append("格 %d,%d  类型 %s" % [_selected_hex.x, _selected_hex.y, t])
		if b != null:
			lines.append("等级 %d   队伍 %s" % [b.level, ("-" if b.team_index < 0 else teams[b.team_index].label())])
			if BuildingData.is_hatcher(b.type):
				lines.append("孵化室：产出%s蚂蚁，可在信息素模式分配给队伍" % ("兵" if b.type == GameConst.SOLDIER_HATCH else "工"))
				lines.append("发育：%s%s" % [_dev_stage_name(b), "  [加速补位]" if b.dev_fast else ""])
		var pts := BuildingData.upgrade_points(_selected_hex, t, grid.tiles)
		lines.append("升级点数 %d" % pts)
		lines.append("食物 %d  尸体可分解 %d" % [int(grid.food_at(_selected_hex)), int(grid.tiles[grid.key(_selected_hex)].get("corpse", 0))])
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	for ln in lines:
		var l := Label.new()
		l.text = ln
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		vb.add_child(l)
	p.add_child(vb)


func _dev_stage_name(b: Building) -> String:
	match b.dev_stage:
		GameConst.DEV_EGG:
			return "卵"
		GameConst.DEV_LARVA:
			return "白色幼虫"
		GameConst.DEV_PUPA:
			return "黄色蛹"
		_:
			return "空"


# ---------- toast ----------
func _toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.position.x = get_viewport().get_visible_rect().size.x / 2.0 - 220.0
	_toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_toast_label, "modulate:a", 0.0, 1.6)


# 退出前保存
func _exit_tree() -> void:
	_save_home_if_needed()
