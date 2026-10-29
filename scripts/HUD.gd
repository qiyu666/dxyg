extends Control
# =========================================================
#  HUD：顶部状态 + 底部直接操作按钮 + 队伍/信息素 + 提示
# =========================================================
signal act_mode(mode: String)   # "worker" "soldier" "storage" "speed" "dig" "pher"
signal act_squad(i: int)

var world: Node = null

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_top()
	_build_bottom()

func _build_top() -> void:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_TOP_WIDE)
	m.add_theme_constant_override("margin_left", 6); m.add_theme_constant_override("margin_top", 4); m.add_theme_constant_override("margin_right", 6)
	add_child(m)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	m.add_child(top)
	_lbls = {}
	for key in ["food","w","s","queen","threats"]:
		var l := Label.new(); l.text = "…"
		top.add_child(l); _lbls[key] = l
		if key == "threats":
			l.add_theme_color_override("font_color", Color("#e0785a"))
		elif key == "queen":
			l.add_theme_color_override("font_color", Color("#e6d8ba"))

var _lbls := {}

func set_status(d: Dictionary) -> void:
	_lbls["food"].text = "🌿%d/%d" % [int(d.food), int(d.food_cap)]
	_lbls["w"].text = "🐜%d/%d" % [int(d.w), int(d.wmax)]
	_lbls["s"].text = "⚔%d/%d" % [int(d.s), int(d.smax)]
	_lbls["queen"].text = "❤%d" % int(d.queen_hp)
	_lbls["threats"].text = "⚠威胁%d" % int(d.threats)

func _build_bottom() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	bar.add_child(col)
	add_child(bar)
	var row := HBoxContainer.new(); col.add_child(row)
	for pair in [["worker","工蚁"],["soldier","兵蚁"],["storage","仓"],["speed","速"],["dig","挖地道"]]:
		var b := Button.new(); b.text = String(pair[1])
		b.pressed.connect(_on_mode_btn.bind(String(pair[0])))
		row.add_child(b)
	var sqrow := HBoxContainer.new(); col.add_child(sqrow)
	for i in 5:
		var b := Button.new(); b.text = ["Ⅰ","Ⅱ","Ⅲ","Ⅳ","Ⅴ"][i]
		b.pressed.connect(func() -> void: act_squad.emit(i))
		sqrow.add_child(b)
	var hint := Label.new(); hint.text = "选工蚁/兵蚁→点泥土建孵化方格 · 挖地道→点泥土 · 点队伍号→再点通路放信息素"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

func _on_mode_btn(mode: String) -> void:
	act_mode.emit(mode)

func toast(msg: String) -> void:
	var t := Label.new()
	t.text = msg
	t.add_theme_color_override("font_color", Color("#f0e2c0"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(0, 60)
	add_child(t)
	var tw := create_tween()
	tw.tween_property(t, "modulate:a", 0.0, 1.5)
	tw.tween_callback(t.queue_free)
