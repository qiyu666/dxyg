extends Node3D
# =========================================================
#  TerrainGrid：土壤六格（3D）+ 埋藏内容 + 孵化流水线 + 挖掘 + 建筑 + 蚁后
#  对应 HTML 的 S.tiles / S.buried / drawHexGrid / 孵化
# =========================================================
signal ant_ready(type: String, key: String, squad: int, level: int)
signal food_spawned(pos: Vector3, amount: int)
signal enemy_spawned(kind: String, pos: Vector3)

var tiles := {}        # key -> { type, level, squad, dig:{progress,need}, hatch:{stage,t,fast}, node:MeshInstance3D, marker:Label3D }
var buried := {}       # key -> { enemy:"beetle" } | { food:30 }
var level_def: Dictionary = {}
var radius := Game.LEVEL_RADIUS
var food_cap := 70

func _ready() -> void:
	# 地面基底（一大片暗土）
	var base := MeshInstance3D.new()
	var bm := PlaneMesh.new(); bm.size = Vector2(220, 220)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("#140f0a")
	bm.material = mat
	base.mesh = bm
	add_child(base)
	_build_tiles()

func _build_tiles() -> void:
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if not Game.in_radius(q, r, radius):
				continue
			var k := Game.hkey(q, r)
			var t := { type = "empty", level = 1, squad = -1, node = null, marker = null }
			tiles[k] = t
			_make_tile_mesh(t, q, r)
	# 蚁后巢
	for d in [Vector2i.ZERO, Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)]:
		var k := Game.hkey(d.x, d.y)
		tiles[k].type = "queen"
		_retile(k)
	# 埋藏内容
	_plant_buried()

func _make_tile_mesh(t: Dictionary, q:int, r:int) -> void:
	var p := Game.h2p(q, r)
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = Game.HEX * 0.58
	cyl.bottom_radius = Game.HEX * 0.58
	cyl.height = 0.35
	cyl.radial_segments = 6
	m.mesh = cyl
	m.position = Vector3(p.x, -0.18, p.y)
	m.rotation.y = 0.523  # 让六边形边对齐
	t.node = m
	add_child(m)
	_retile_by_type(t)

func _retile(k: String) -> void:
	var t := tiles[k]
	_retile_by_type(t)
	if t.get("marker"):
		if t.marker and is_instance_valid(t.marker): t.marker.queue_free()
		t.marker = null
	_refresh_markers()

func _retile_by_type(t: Dictionary) -> void:
	var m: MeshInstance3D = t.node
	if not m or not m.material:
		return
	var col := Color("#241a11")
	match t.type:
		"empty": col = Color("#241a11")
		"dirt":  col = Color("#2a1d12")
		"tunnel":col = Color("#0e0906")
		"queen": col = Color("#33240f")
		"worker":col = Color("#2c3418")
		"soldier":col = Color("#3a1c12")
		"storage":col = Color("#2c2414")
		"speed": col = Color("#142a26")
	var mat := m.material
	if mat is StandardMaterial3D:
		mat.albedo_color = col
	else:
		mat = StandardMaterial3D.new(); mat.albedo_color = col; m.material = mat

func _plant_buried() -> void:
	var used := {}
	var put := func(obj: Dictionary) -> void:
		for i in 60:
			var rng := Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
			if Game.hdist(rng, Vector2i.ZERO) < 2:
				continue
			var key := Game.hkey(rng.x, rng.y)
			if not tiles.has(key) or tiles[key].type != "empty":
				continue
			if used.has(key):
				continue
			used[key] = true
			buried[key] = obj
			return
	var amt := 30 if level_def.get("idx", 0) == 0 else 40
	for kind in level_def.get("buried", []):
		put.call({ enemy = kind })
	for i in int(level_def.get("soilFood", 0)):
		put.call({ food = amt })

func is_frontier(k: String) -> bool:
	var d := Game.parse_key(k)
	if not Game.in_radius(d.x, d.y, radius):
		return false
	var t := tiles.get(k)
	if t and t.type not in ["empty", "dirt", "tunnel"]:
		return false
	for dir in Game.DIRS:
		var nk := Game.hkey(d.x + dir[0], d.y + dir[1])
		var nt := tiles.get(nk)
		if nt and nt.type not in ["empty", "dirt"]:
			return true
	return false

func _refresh_markers() -> void:
	# 只有前线泥土显示 ！/食 标记
	for k in tiles:
		if tiles[k].get("marker") and is_instance_valid(tiles[k].marker):
			tiles[k].marker.queue_free()
			tiles[k].marker = null
	for k in buried:
		if not is_frontier(k):
			continue
		var d := Game.parse_key(k)
		var p := Game.h2p(d.x, d.y)
		var lb := Label3D.new()
		lb.text = "!" if buried[k].has("enemy") else "食"
		lb.modulate = Color("#e0785a") if buried[k].has("enemy") else Color("#d2b45a")
		lb.position = Vector3(p.x, 0.6, p.y)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.004
		add_child(lb)
		tiles[k].marker = lb

# ---------- 挖掘 ----------
func start_dig(k: String) -> bool:
	var t := tiles.get(k)
	if not t or t.type not in ["dirt", "empty", "tunnel"] or t.type == "queen":
		return false
	if t.type == "empty":
		t.type = "dirt"
		_retile(k)
	t.dig = { progress = 0.0, need = 8.0 }
	_retile(k)
	return true

func dig_progress(k: String, dt: float) -> void:
	var t := tiles.get(k)
	if not t or not t.has("dig"):
		return
	t.dig.progress += dt
	if t.dig.progress >= t.dig.need:
		t.type = "tunnel"
		t.dig = {}
		_retile(k)
		reveal(k)

func reveal(k: String) -> void:
	if not buried.has(k):
		return
	var b := buried[k]
	buried.erase(k)
	var d := Game.parse_key(k)
	var p := Game.h2p(d.x, d.y)
	var pos := Vector3(p.x, 0.2, p.y)
	if b.has("enemy"):
		enemy_spawned.emit(b.enemy, pos)
	elif b.has("food"):
		food_spawned.emit(pos, b.food)

# ---------- 孵化流水线 ----------
func tick_hatch(dt: float, idle_workers: int, ants_count: int, food: float, by_squad: Dictionary) -> float:
	# 返回本次消耗的食物（蛹→活跃）
	var spend := 0.0
	for k in tiles:
		var t := tiles[k]
		if t.type not in ["worker", "soldier"]:
			continue
		if not t.has("hatch"):
			t.hatch = { stage = "empty", t = 0.0, fast = false }
		var h := t.hatch
		if h.stage == "active":
			continue
		var squad := int(t.squad)
		if squad < 0:
			continue
		var fm := 0.5 if h.fast else 1.0
		match h.stage:
			"empty":
				if food < 0 or not _can_carry(idle_workers, ants_count):
					h.t = 0.0
					continue
				h.t += dt * fm
				if h.t >= Game.HATCH_TIME.empty:
					h.stage = "egg"; h.t = 0.0
			"egg":
				h.t += dt * fm
				if h.t >= Game.HATCH_TIME.egg:
					h.stage = "larva"; h.t = 0.0
			"larva":
				h.t += dt * fm
				if h.t >= Game.HATCH_TIME.larva:
					h.stage = "pupa"; h.t = 0.0
			"pupa":
				var cost := Game.hatch_cost(t.type, t.level)
				var smax := int(by_squad.get("%d" % squad, 20))
				var sants := int(by_squad.get("_n%d" % squad, 0))
				if sants >= smax or ants_count >= 150:
					continue
				if food >= cost:
					spend += cost
					ant_ready.emit(t.type, k, squad, t.level)
					h.stage = "active"; h.t = 0.0; h.fast = false
	return spend

func _can_carry(idle_workers:int, ants_count:int) -> bool:
	return idle_workers > 0 and ants_count < 150

func hatch_on_death(k: String) -> void:
	var t := tiles.get(k)
	if t and t.has("hatch"):
		t.hatch = { stage = "empty", t = 0.0, fast = true }

func build_building(k: String, type: String) -> bool:
	var t := tiles.get(k)
	if not t or t.type not in ["empty", "dirt", "tunnel"]:
		return false
	t.type = type
	t.level = 1
	if type in ["worker", "soldier"]:
		t.hatch = { stage = "empty", t = 0.0, fast = false }
		_retile(k)
	return true

func set_squad(k: String, squad: int) -> void:
	var t := tiles.get(k)
	if t and t.type in ["worker", "soldier"]:
		t.squad = squad

func active_population() -> Dictionary:
	var w := 0; var s := 0; var wm := 0; var sm := 0
	for k in tiles:
		var t := tiles[k]
		if t.type == "worker": wm += 1
		elif t.type == "soldier": sm += 1
		if t.has("hatch") and t.hatch.stage == "active":
			if t.type == "worker": w += 1
			else: s += 1
	return { w = w, s = s, wMax = wm, sMax = sm, active = w + s, maxp = wm + sm }

func hatchery_counts() -> Dictionary:
	var c := { soldier = 0, worker = 0 }
	for k in tiles:
		if tiles[k].type == "soldier": c.soldier += 1
		elif tiles[k].type == "worker": c.worker += 1
	return c
