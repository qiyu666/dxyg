extends Node3D
# =========================================================
#  EnemyUnit：3D 敌人（追踪 / 攻击 / 死亡掉落）
#  对应 HTML updateEnemies + makeEnemy
# =========================================================
signal died(kind: String)

var kind := "mealworm"
var hp := 22.0
var maxhp := 22.0
var atk := 2.0
var speed := 26.0
var size := 1.0
var cd := 0.0
var food_reward := 0
var body_root: Node3D
var _dead := false

static func make(kind: String, pos: Vector3) -> EnemyUnit:
	var e := EnemyUnit.new()
	e.kind = kind
	var d: Dictionary = Game.ENEMIES[kind]
	e.hp = float(d.hp); e.maxhp = float(d.hp)
	e.atk = float(d.atk); e.speed = float(d.speed); e.size = float(d.size)
	e.food_reward = int(d.get("food", 0))
	e.position = pos
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	match kind:
		"mealworm": mat.albedo_color = Color("#d8b070")
		"sowbug":   mat.albedo_color = Color("#8a7a5a")
		"beetle", "adultBeetle": mat.albedo_color = Color("#1a120c")
		"spider", "webSpider":  mat.albedo_color = Color("#1a1414")
		"enemyAnt": mat.albedo_color = Color("#3a2a14")
	# 危险敌人加暗红光晕（威胁感）
	if kind in ["beetle","adultBeetle","spider","webSpider"]:
		mat.emission_enabled = true
		mat.emission = Color("#5a1008")
		mat.emission_energy_multiplier = 0.6
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.5 * e.size; sm.height = 0.9 * e.size
	sm.material = mat
	m.mesh = sm
	m.position = Vector3(0, 0.3 * e.size, 0)
	root.add_child(m)
	e.add_child(root)
	e.body_root = root
	return e

func take(dmg: float) -> void:
	hp -= dmg
	if hp <= 0.0 and not _dead:
		_dead = true
		died.emit(kind)

func _process(dt: float) -> void:
	pass

func update(dt: float, w: Node) -> void:
	if hp <= 0.0:
		return
	cd -= dt
	# 目标：最近蚂蚁，否则蚁后
	var target_pos := w.queen_pos
	var target_ant: AntUnit = null
	var td := 1e9
	for a in w.ants:
		var d: float = a.position.distance_to(position)
		if d < td:
			td = d; target_ant = a
	if target_ant and td < 8.0:
		target_pos = target_ant.position
	var dir := target_pos - position
	dir.y = 0.0
	var d := dir.length()
	if d > 0.7 * size + 0.4:
		position += dir / d * speed * dt
		body_root.rotation.y = -atan2(dir.z, dir.x)
	else:
		if cd <= 0.0:
			cd = 0.8
			if target_ant:
				target_ant.take(atk)
			else:
				w.on_queen_hit(atk)

func take_by_ant(dmg: float) -> void:
	take(dmg)
