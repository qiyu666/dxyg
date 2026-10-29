extends Node3D
# =========================================================
#  AntUnit：3D 蚂蚁（移动/挖地道/搬食/战斗/队伍/信息素/兵蚁守蚁后）
#  对应 HTML updateAnts 的分支
# =========================================================
var kind := "worker"
var hp := 25.0
var maxhp := 25.0
var atk := 3.0
var speed := 42.0
var carry_cap := 8
var carry := 0.0
var squad := 0
var phase := 0.0
var cd := 0.0
var dig_key := ""
var dig_pos := Vector3.ZERO
var hatch_key := ""
var goal := Vector3.ZERO
var wander := Vector3.ZERO
var body_root: Node3D

const BODY_COLORS := ["#7a2a1c","#b5642a","#c9a032","#5a6a2a","#5a2e7a","#35353f"]

static func make(kind: String, pos: Vector3, squad: int, color_idx: int) -> AntUnit:
	var a := AntUnit.new()
	a.kind = kind
	a.squad = squad
	var b: Dictionary = Game.ANTS[kind]
	a.hp = float(b.hp); a.maxhp = float(b.hp)
	a.atk = float(b.atk); a.speed = float(b.speed)
	a.carry_cap = int(b.carryCap)
	a.position = pos
	var root := Node3D.new()
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(BODY_COLORS[color_idx % BODY_COLORS.size()])
	var abdomen := MeshInstance3D.new()
	var am := SphereMesh.new(); am.radius = 0.5; am.height = 0.9
	am.material = mat
	abdomen.mesh = am
	abdomen.position = Vector3(-0.5, 0.15, 0)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.28; hm.height = 0.5
	hm.material = mat
	head.mesh = hm
	head.position = Vector3(0.5, 0.12, 0)
	root.add_child(abdomen); root.add_child(head)
	a.add_child(root)
	a.body_root = root
	return a

func scale_stats(mul: float) -> void:
	maxhp *= mul
	hp = maxhp
	speed *= (1.0 + 0.1 * (mul - 1.0))

func take(dmg: float) -> void:
	hp -= dmg

func update(dt: float, w: Node) -> void:
	if hp <= 0.0:
		return
	phase += dt * 12.0
	cd -= dt
	var sq: Dictionary = w.squads.get(squad, {})
	# 挖地道
	if dig_key != "":
		if not w.terrain.tiles.get(dig_key, {}).has("dig"):
			dig_key = ""
		else:
			if dig_pos.distance_to(position) > 0.6:
				_move_to(dig_pos, speed, dt)
			else:
				w.terrain.dig_progress(dig_key, dt)
				if not w.terrain.tiles.get(dig_key, {}).has("dig"):
					dig_key = ""
		return
	# 携食回巢
	if carry > 0.0:
		if w.queen_pos.distance_to(position) < 0.9:
			w.on_food_carried(carry)
			carry = 0.0
		else:
			_move_to(w.queen_pos, speed, dt)
		return
	# 搬运：捡食物
	if bool(sq.get("allowCarry", true)) and w.food_level < w.food_cap and w.foods.size() > 0:
		var best: Dictionary = {}
		var bd := 0.9
		for fd in w.foods:
			var dist: float = (fd.node as Node3D).position.distance_to(position)
			if dist < bd:
				bd = dist; best = fd
		if not best.is_empty():
			carry += minf(0.6, float(carry_cap - carry))
			best.amount -= 0.6
			if best.amount <= 0.0:
				w.foods.erase(best)
				(best.node as Node3D).queue_free()
			return
	# 攻击
	var enemy: EnemyUnit = null
	var ed := 1e9
	for e in w.enemies:
		var edd: float = e.position.distance_to(position)
		if edd < ed:
			ed = edd; enemy = e
	if bool(sq.get("allowAttack", true)) and enemy and ed < 2.0:
		_face(enemy.position)
		if cd <= 0.0:
			cd = 0.6
			enemy.take(atk)
		return
	# 信息素目标
	if sq.get("marker", null) != null:
		var mx: Vector3 = goal if goal != Vector3.ZERO else (sq["marker"] as Vector3)
		if position.distance_to(mx) > 0.35:
			_move_to(mx, speed, dt)
		else:
			_set_wander(w.queen_pos, 4.0)
		return
	# 待机：兵蚁守蚁后，工蚁巢口游走
	var spread := 1.2 if kind == "soldier" else 4.0
	var frac := 0.5 if kind == "soldier" else 0.45
	_wander_near(w.queen_pos, spread, speed * frac, dt)

func _move_to(target: Vector3, spd: float, dt: float) -> void:
	var dir := target - position
	dir.y = 0.0
	var d := dir.length()
	if d < 0.01:
		return
	var step := minf(d, spd * dt)
	position += dir / d * step
	_face(target)

func _face(target: Vector3) -> void:
	var dir := target - position
	dir.y = 0.0
	if dir.length() > 0.01:
		body_root.rotation.y = -atan2(dir.z, dir.x)

func _set_wander(center: Vector3, spread: float) -> void:
	wander = center + Vector3(randf() - 0.5, 0.0, randf() - 0.5) * spread
	goal = Vector3.ZERO

func _wander_near(center: Vector3, spread: float, spd: float, dt: float) -> void:
	if wander == Vector3.ZERO or position.distance_to(wander) < 0.3 or randf() < 0.02:
		wander = center + Vector3(randf() - 0.5, 0.0, randf() - 0.5) * spread
	.goal = Vector3.ZERO
	_move_to(wander, spd, dt)
