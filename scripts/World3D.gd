extends Node3D
# =========================================================
#  World3D：一个关卡的 3D 世界 + 运行时（蚁群/敌人/食物/孵化/队伍/胜负）
#  对应 HTML 的 S + levelUpdate + createLevel
# =========================================================
signal hud_update(info: Dictionary)
signal level_won()
signal level_lost()
signal toast(msg: String)

var terrain: TerrainGrid
var camera: Camera3D
var ants: Array = []
var enemies: Array = []
var foods: Array = []       # [{ node:Node3D, amount:float }]
var squads := {}            # i -> { marker:Vector3, allowAttack, allowCarry, max, count }
var queen_pos := Vector3.ZERO
var queen_hp := 500.0
var food_level := 35.0
var food_cap := 70.0
var level_idx := 0
var sel_squad := 0
var over := false
var _resupply_t := 0.0
var _hud_t := 0.0

func _ready() -> void:
	_set_env()
	terrain = TerrainGrid.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.ant_ready.connect(_on_ant_ready)
	terrain.enemy_spawned.connect(_on_enemy_spawned)
	terrain.food_spawned.connect(_on_food_spawned)
	queen_pos = Vector3(0, 0.2, 0)

func _set_env() -> void:
	# 相机（俯视微倾，看土壤六格）
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 120, -70)
	camera.fov = 42
	camera.rotation = Vector3(1.05, 0, 0)
	camera.rotation_x = -1.02
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	camera.make_current()
	# 世界环境：暗、雾
	var env := Environment.new()
	env.ambient_light_color = Color("#0a0806")
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color("#0c0a08")
	env.fog_density = 0.012
	var env_node := WorldEnvironment.new()
	env_node.environment = env
	add_child(env_node)
	# 顶光（很弱）
	var dl := DirectionalLight3D.new()
	dl.light_energy = 0.35
	dl.light_color = Color("#c9b58a")
	dl.position = Vector3(0, 60, 0)
	add_child(dl)
	# 蚁后巢心微光
	var pl := PointLight3D.new()
	pl.light_color = Color("#c9a055")
	pl.light_energy = 2.2
	pl.omni_range = 55.0
	pl.position = Vector3(0, 3, 0)
	add_child(pl)

func setup(idx: int) -> void:
	level_idx = idx
	# 清掉旧单位与 terrain，重建
	for a in ants: a.queue_free()
	for e in enemies: e.queue_free()
	for f in foods: (f.node as Node3D).queue_free()
	ants.clear(); enemies.clear(); foods.clear()
	if terrain and is_instance_valid(terrain):
		terrain.queue_free()
	terrain = TerrainGrid.new()
	terrain.name = "Terrain"
	terrain.level_def = Game.LEVELS[idx].duplicate(true)
	terrain.level_def["idx"] = idx
	add_child(terrain)   # _ready 会 _build_tiles + _plant_buried
	terrain.ant_ready.connect(_on_ant_ready)
	terrain.enemy_spawned.connect(_on_enemy_spawned)
	terrain.food_spawned.connect(_on_food_spawned)
	queen_pos = Vector3(0, 0.2, 0)
	queen_hp = 500.0
	food_cap = 70.0
	food_level = 35.0
	squads = {}
	for i in 5:
		squads[i] = { marker = Vector3.ZERO, allowAttack = true, allowCarry = true, max = 20, count = 0 }
	for i in 7:
		var p := Vector3(randf()*8-4, 0.2, randf()*8-4)
		var a: AntUnit = AntUnit.make("worker", p, 0, Game.color_idx)
		add_child(a)
		ants.append(a)
		squads[0].count += 1

func _eh_refresh() -> void:
	pass

# ---------- 信号 ----------
func _on_ant_ready(type: String, key: String, squad: int, level: int) -> void:
	var p := _tile_pos(key)
	var a: AntUnit = AntUnit.make(type, p, squad, Game.color_idx)
	a.hatch_key = key
	a.scale_stats(Game.hatch_stat_mul(level))
	add_child(a)
	ants.append(a)
	if squads.has(squad):
		squads[squad].count += 1

func _tile_pos(key: String) -> Vector3:
	var d := Game.parse_key(key)
	var p := Game.h2p(d.x, d.y)
	return Vector3(p.x, 0.2, p.y)

func _on_enemy_spawned(kind: String, pos: Vector3) -> void:
	var e: EnemyUnit = EnemyUnit.make(kind, pos)
	e.died.connect(func(k: String) -> void: _on_enemy_died(e, k))
	add_child(e)
	enemies.append(e)
	toast.emit("泥土里钻出了：敌人！")

func _on_enemy_died(e: EnemyUnit, kind: String) -> void:
	var reward: int = int(Game.ENEMIES[kind].get("food", 0))
	if reward > 0:
		food_level = minf(food_level + float(reward), food_cap)
	if kind == "sowbug":
		_spawn_food(e.position, 40.0)
	enemies.erase(e)
	e.queue_free()

func _on_food_spawned(pos: Vector3, amount: int) -> void:
	_spawn_food(pos, float(amount))

func _spawn_food(pos: Vector3, amount: float) -> void:
	var node := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radius = 0.25; m.height = 0.4
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("#8a6a30")
	m.material = mat
	node.mesh = m
	node.position = Vector3(pos.x, 0.15, pos.y)
	add_child(node)
	foods.append({ node = node, amount = amount })

# ---------- UI 接口 ----------
func order_dig(key: String) -> void:
	# 派最近空闲工蚁去挖
	if not terrain.start_dig(key):
		toast.emit("需挨着已有区域挖掘")
		return
	var p := _tile_pos(key)
	var best: AntUnit = null
	var bd := 1e9
	for a in ants:
		if a.kind != "worker" or a.hp <= 0 or a.carry > 0 or a.dig_key != "":
			continue
		var d: float = a.position.distance_to(p)
		if d < bd:
			bd = d; best = a
	if best:
		best.dig_key = key
		best.dig_pos = p
		best.goal = Vector3.ZERO
	else:
		toast.emit("没有空闲工蚁去挖掘")

func build(key: String, type: String) -> void:
	if food_level < float(Game.BUILD[type].cost):
		toast.emit("食物不足"); return
	food_level -= float(Game.BUILD[type].cost)
	if type in ["worker", "soldier"]:
		terrain.set_squad(key, sel_squad)
	terrain.build_building(key, type)
	_recompute_food_cap()

func _recompute_food_cap() -> void:
	food_cap = 70.0
	for k in terrain.tiles:
		if terrain.tiles[k].type == "storage":
			food_cap += 30.0 * float(terrain.tiles[k].level)

func set_squad(key: String, squad: int) -> void:
	terrain.set_squad(key, squad)
	# 更新队伍 count
	_recount_squads()

func place_pheromone(squad: int, world_pos: Vector3) -> void:
	sel_squad = squad
	var sq := squads[squad]
	sq.marker = world_pos
	# 该队每只蚁取 marker 周围随机目标位（散开）
	for a in ants:
		if a.squad != squad:
			continue
		var ang := randf() * 6.28
		var rad := 0.4 + randf() * 1.1
		a.goal = world_pos + Vector3(cos(ang) * rad, 0, sin(ang) * rad)

func _recount_squads() -> void:
	for i in 5:
		squads[i].count = 0
	for a in ants:
		if a.hp > 0 and squads.has(a.squad):
			squads[a.squad].count += 1

# ---------- 逐帧 ----------
func _physics_process(dt: float) -> void:
	if over:
		return
	_resupply_t += dt
	var interval := 6.0 if level_idx == 1 else 12.0
	if _resupply_t >= interval and foods.size() < (45 if level_idx == 1 else 20):
		_resupply_t = 0.0
		var ring := Game.p2h(randf()*120-60, randf()*120-60)
		_spawn_food(Vector3(Game.h2p(ring.x, ring.y).x, 0.15, Game.h2p(ring.x, ring.y).y), 30.0)
	# 孵化流水线
	var idle_w := 0
	for a in ants:
		if a.kind == "worker" and a.hp > 0 and a.carry <= 0 and a.dig_key == "":
			idle_w += 1
	var by := {}
	for i in 5:
		by["%d" % i] = squads[i].max
		by["_n%d" % i] = squads[i].count
	by["idle"] = idle_w
	var spend := terrain.tick_hatch(dt, idle_w, ants.size(), food_level, by)
	if spend > 0:
		food_level = maxf(0.0, food_level - spend)
	# 蚁
	for a in ants:
		a.update(dt, self)
	# 敌
	for e in enemies:
		e.update(dt, self)
	# 清死亡
	var dead := []
	for a in ants:
		if a.hp <= 0:
			dead.append(a)
	for a in dead:
		if a.hatch_key != "":
			terrain.hatch_on_death(a.hatch_key)
		ants.erase(a)
		a.queue_free()
	_recount_squads()
	terrain._refresh_markers()
	_hud_t += dt
	if _hud_t >= 0.25:
		_hud_t = 0.0
		_pop_hud()
	# 胜负
	if level_idx == 0 and Game.threats_left(enemies, terrain.buried) == 0:
		over = true
		level_won.emit()
	elif level_idx == 1:
		var c := terrain.hatchery_counts()
		if c.soldier >= 50 and c.worker >= 47:
			over = true
			level_won.emit()
	if queen_hp <= 0.0:
		over = true
		level_lost.emit()

func _pop_hud() -> void:
	var pop := terrain.active_population()
	hud_update.emit({
		food = int(food_level), food_cap = int(food_cap),
		w = pop.w, s = pop.s, wmax = pop.wMax, smax = pop.sMax,
		queen_hp = int(queen_hp), threats = Game.threats_left(enemies, terrain.buried),
		sel = sel_squad, squad_counts = [squads[0].count, squads[1].count, squads[2].count, squads[3].count, squads[4].count],
	})

func on_food_carried(amt: float) -> void:
	food_level = minf(food_level + amt, food_cap)

func on_queen_hit(dmg: float) -> void:
	queen_hp = maxf(0.0, queen_hp - dmg)

func idle_workers_count() -> int:
	var n := 0
	for a in ants:
		if a.kind == "worker" and a.hp > 0 and a.carry <= 0 and a.dig_key == "":
			n += 1
	return n
