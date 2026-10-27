extends Unit
## 蚂蚁：受信息素队伍指挥。目标优先级：
## 送食物 -> 信息素标记(附带开关控制的攻击/搬运) -> 默认(采集/防御/回巢)。
class_name Ant

var is_soldier: bool = false
var team: Pheromone = null   # 可为 null（未被分配，走默认行为）
var damage: float = 1.0
var carry_cap: float = 10.0
var base_speed: float = 95.0
var carrying: float = 0.0
var deployed: bool = true     # 受 max_mobilize 约束；false 时在巢附近待命

var _attack_cd: float = 0.0
var _want_carry: bool = false
## 孵化室产卵：产生本蚁的孵化室 key（蚁后初始工蚁为 ""）
var hatch_key: String = ""
## 工蚁携卵（兵蚁不参与）
var carrying_egg: bool = false
var _egg_target: String = ""


func _init(p_soldier := false, p_color := Color(0.8, 0.5, 0.2)) -> void:
	is_soldier = p_soldier
	var def: Dictionary = GameConst.SOLDIER if p_soldier else GameConst.WORKER
	hp = float(def["hp"])
	max_hp = hp
	base_speed = float(def["speed"])
	damage = float(def["damage"])
	carry_cap = float(def["carry"])
	color = p_color
	radius = 7.0 if p_soldier else 5.0


## 应用进化加成（视图在生成时调用一次）
func apply_evolutions(home: Dictionary) -> void:
	for e in home.get("evolutions", []):
		match e:
			"hp":
				max_hp *= 1.4
				hp = max_hp
			"attack":
				damage *= 1.5
			"speed":
				base_speed *= 1.15
			"carry":
				carry_cap *= 1.5


func update(dt: float, view) -> void:
	if not alive:
		return
	_attack_cd = maxf(0.0, _attack_cd - dt)

	# 未出动（超出 max_mobilize）：留在巢附近待命
	if team != null and team.max_mobilize > 0 and not deployed:
		_idle_at_home(view)
		return

	var spd := _effective_speed(view)
	_combat(view)
	# 已带食物：优先送回
	if carrying > 0.0:
		_carry(view)
		_move(view, dt, spd)
		queue_redraw()
		return
	# 工蚁携卵：送往目标孵化室
	if carrying_egg:
		_move(view, dt, spd)
		_on_arrive_hatch(view)
		queue_redraw()
		return
	# 空手：工蚁取卵 / 拾取食物 / 信息素标记 / 默认
	_egg_fetch(view)
	_carry(view)
	_move(view, dt, spd)
	queue_redraw()


func _effective_speed(view) -> float:
	var s := base_speed * (1.0 + view.grid.speed_bonus()) * view.speed_mult()
	if _on_hatcher(view):
		s *= (1.0 - GameConst.HATCHER_DECEL)
	return s


func _on_hatcher(view) -> bool:
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	var b := view.grid.building_at(c)
	return b != null and BuildingData.is_hatcher(b.type)


func _can_attack() -> bool:
	return team == null or team.allow_attack


func _can_carry() -> bool:
	return team == null or team.allow_carry


## 攻击：格内/相邻敌人
func _combat(view) -> void:
	if not _can_attack() or _attack_cd > 0.0:
		return
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	var e: Enemy = view.enemy_near(c, 1)
	if e != null and e.alive:
		e.take_damage(damage)
		_attack_cd = 0.8
		if not e.alive:
			view.enemy_died(e)


## 拾取 / 送回
func _carry(view) -> void:
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	if _want_carry:
		# 到达储存点卸货
		if c == view.storage_cell():
			view.deposit(carrying)
			carrying = 0.0
			_want_carry = false
			view.grid.set_food(c, 0.0)  # 无副作用保险
		return
	if carrying > 0.0:
		_want_carry = true
		return
	# 拾取：开关允许 + 储量未满 + 该格有食物
	if _can_carry() and carrying <= 0.0 and view.can_carry_more():
		var avail := view.grid.food_at(c)
		if avail > 0.0:
			var amt := minf(avail, carry_cap)
			view.grid.add_food(c, -amt)
			carrying += amt
			_want_carry = true


func _move(view, dt: float, spd: float) -> void:
	var target := _choose_target(view)
	if target == null:
		return
	var goal := HexMath.hex_to_pos(target, view.grid.hex_size)
	var to := goal - position
	var step := spd * dt
	if to.length() <= step or to.length() == 0.0:
		position = goal
	else:
		position += to.normalized() * step


func _choose_target(view) -> Variant:
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	# 送食物优先
	if carrying > 0.0:
		return view.storage_cell()
	# 携卵：去目标孵化室
	if carrying_egg:
		return view.hatch_hex(_egg_target)
	# 工蚁取卵：有卵可取且有空孵化室 -> 回蚁后处
	if _should_fetch_egg(view):
		return view.home_cell()
	# 信息素标记
	if team != null and not team.markers.is_empty() and (team.allow_attack or team.allow_carry):
		return _nearest_marker(view)
	# 默认行为
	if view.can_carry_more():
		var f: Vector2i = view.nearest_food(c)
		if f != null and not f == Vector2i(0, 0):
			return f
	var e: Enemy = view.nearest_enemy(c)
	if e != null and _can_attack():
		return e.grid_hex
	return view.home_cell()


func _should_fetch_egg(view) -> bool:
	if is_soldier:
		return false
	if carrying_egg or carrying > 0.0:
		return false
	return view.queen_has_egg() and view.empty_hatch_count() > 0


## 到达蚁后处且满足条件 -> 取一枚卵并预留一个空孵化室
func _egg_fetch(view) -> void:
	if is_soldier:
		return
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	if c != view.home_cell():
		return
	if not view.queen_has_egg() or view.empty_hatch_count() <= 0:
		return
	var k := view.reserve_empty_hatch()
	if k != "":
		carrying_egg = true
		_egg_target = k


## 到达目标孵化室 -> 将卵放入
func _on_arrive_hatch(view) -> void:
	if _egg_target == "":
		return
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	if HexMath.key(c) != _egg_target:
		return
	view.deposit_egg(_egg_target)
	carrying_egg = false
	_egg_target = ""


func _nearest_marker(view) -> Vector2i:
	var c: Vector2i = view.grid.screen_to_hex(global_position)
	var best: Vector2i = team.markers[0]
	var bd := HexMath.distance(c, best)
	for m in team.markers:
		var d := HexMath.distance(c, m as Vector2i)
		if d < bd:
			bd = d
			best = m
	return best


func _idle_at_home(_view) -> void:
	# 待命：原地站立（不主动行动、不战斗、不搬运）
	queue_redraw()
