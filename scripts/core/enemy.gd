extends Unit
## 敌人。普通敌人追踪蚂蚁/蚁后；蛛丝蜘蛛(silk_spider)埋伏于洞穴，
## 有蚂蚁进入触发圈即"抱走"（高伤、通常一击致命），随后进入冷却。
class_name Enemy

var etype: String = "beetle"
var ambush: bool = false
var grid_hex: Vector2i = Vector2i.ZERO
var death_food: float = 0.0
var corpse_food: float = 0.0
var corpse_decomp: int = 0
var damage: float = 2.0
var home_cell: Vector2i = Vector2i.ZERO  # 蛛丝蜘蛛洞穴位置

var _grab_cd: float = 0.0
var _attack_cd: float = 0.0


func _init(p_type: String) -> void:
	etype = p_type
	var def: Dictionary = GameConst.ENEMIES.get(p_type, {})
	hp = float(def.get("hp", 5.0))
	max_hp = hp
	speed = float(def.get("speed", 50.0))
	ambush = bool(def.get("ambush", false))
	death_food = float(def.get("death_food", 0.0))
	corpse_food = float(def.get("corpse_food", 0.0))
	corpse_decomp = int(def.get("corpse_decomp", 0))
	damage = float(def.get("damage", 2.0))
	radius = 6.0
	_set_color()


func _set_color() -> void:
	match etype:
		"beetle":
			color = Color(0.5, 0.35, 0.2)
		"adult_beetle":
			color = Color(0.35, 0.22, 0.14)
		"isopod":
			color = Color(0.5, 0.55, 0.35)
		"bread_worm":
			color = Color(0.85, 0.75, 0.5)
		"spider":
			color = Color(0.2, 0.2, 0.25)
		"silk_spider":
			color = Color(0.9, 0.9, 0.95)
		"enemy_ant":
			color = Color(0.15, 0.15, 0.15)
		_:
			color = Color(0.6, 0.2, 0.2)


func update(dt: float, view) -> void:
	if not alive:
		return
	grid_hex = view.grid.screen_to_hex(global_position)
	_grab_cd = maxf(0.0, _grab_cd - dt)
	_attack_cd = maxf(0.0, _attack_cd - dt)
	if ambush:
		_ambush(view)
		return
	_seek(view, dt)
	_contact(view)
	queue_redraw()


func _ambush(view) -> void:
	# 触发圈：1.5 格。有蚂蚁进入即抱走（冷却内不重复）
	if _grab_cd > 0.0:
		return
	var trigger_px: float = view.grid.hex_size * 1.5
	var victim: Ant = view.nearest_ant(global_position, trigger_px)
	if victim != null and victim.alive:
		victim.take_damage(99.0)   # 高伤、通常一击致命
		if not victim.alive:
			view.ant_died(victim)
		_grab_cd = 3.0


func _seek(view, dt: float) -> void:
	var target: Vector2i = view.enemy_target_hex(self)
	var goal: Vector2 = HexMath.hex_to_pos(target, view.grid.hex_size)
	var to: Vector2 = goal - position
	var step: float = speed * dt
	if to.length() <= step or to.length() == 0.0:
		position = goal
	else:
		position += to.normalized() * step


func _contact(view) -> void:
	if _attack_cd > 0.0:
		return
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	var victim: Ant = view.enemy_near_ally_ant(c, 1)
	if victim != null and victim.alive:
		victim.take_damage(damage)
		_attack_cd = 0.8
		if not victim.alive:
			view.ant_died(victim)
