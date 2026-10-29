extends Node
# =========================================================
#  Main：菜单 → 关卡流程；触屏点选（射线到 y=0 平面）→ 按模式路由
# =========================================================
var menu: CanvasLayer
var world: Node = null
var hud: Node = null
var cam: Camera3D = null
var mode := ""
var sel_squad := 0

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var c := CenterContainer.new(); c.set_anchors_preset(PRESET_FULL_RECT); menu.add_child(c)
	var panel := PanelContainer.new()
	var col := VBoxContainer.new(); col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	c.add_child(panel)
	var t := Label.new(); t.text = "The Ants · 小小蚁国（3D 安卓）"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	for i in Game.ANT_COLORS.size():
		var btn := Button.new(); btn.text = Game.ANT_COLORS[i].name
		btn.pressed.connect(_pick_color.bind(i)); col.add_child(btn)
	var b1 := Button.new(); b1.text = "▶ 第一章 · 第一关"; b1.pressed.connect(func(): _start(0)); col.add_child(b1)
	var b2 := Button.new(); b2.text = "▶ 第一章 · 第二关"; b2.pressed.connect(func(): _start(1)); col.add_child(b2)

func _pick_color(i: int) -> void:
	Game.color_idx = i
	Game.save_meta()

func _start(idx: int) -> void:
	if menu: menu.queue_free(); menu = null
	world = World3D.new()
	add_child(world)
	world.setup(idx)
	cam = world.get_node("Camera3D") if world.has_node("Camera3D") else null
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/HUD.gd").new()
	hud.name = "HUD"
	hud.world = world
	layer.add_child(hud)
	world.hud_update.connect(hud.set_status)
	world.toast.connect(hud.toast)
	world.level_won.connect(func(): hud.toast("已通关！"))
	world.level_lost.connect(func(): hud.toast("蚁巢陷落"))
	hud.act_mode.connect(func(m: String) -> void: mode = m)
	hud.act_squad.connect(func(i: int) -> void: sel_squad = i; world.sel_squad = i; mode = "pher")
	Game.save_home({ id = "c%d" % idx })

func _unhandled_input(event: InputEvent) -> void:
	if not world or world.over:
		return
	var tap: Vector2 = Vector2.ZERO
	var has := false
	if event is InputEventScreenTouch and event.pressed:
		tap = event.position; has = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap = event.position; has = true
	if not has:
		return
	var camn: Camera3D = world.get_node_or_null("Camera3D") as Camera3D
	if not camn:
		return
	var origin := camn.project_ray_origin(tap)
	var dir := camn.project_ray_normal(tap)
	if absf(dir.y) < 0.0001:
		return
	var t := -origin.y / dir.y
	if t < 0:
		return
	var wp: Vector3 = origin + dir * t
	var hr := Game.p2h(wp.x, wp.z)
	var key := Game.hkey(hr.x, hr.y)
	match mode:
		"worker","soldier","storage","speed":
			world.build(key, mode)
		"dig":
			world.order_dig(key)
		"pher":
			world.place_pheromone(sel_squad, Vector3(wp.x, 0.2, wp.z))
		_:
			_inspect(key, hud)

func _inspect(key: String, hud: Node) -> void:
	if not world:
		return
	var b: Dictionary = world.terrain.buried.get(key, {})
	if b.has("enemy"):
		hud.toast("⚠ 这片土里有：敌人，小心挖掘")
	elif b.has("food"):
		hud.toast("🍯 有食物，挖开收集")
	else:
		hud.toast("普通泥土，可安全挖掘")
