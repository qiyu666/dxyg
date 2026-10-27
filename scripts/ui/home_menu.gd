extends Control
## 首页主菜单：创建新存档 / 查看存档 / 蚁群颜色选择 / 敬请期待。
## 布局参考"图 2"风格，但蚁后使用自生成贴图（缺失时回退为占位文字）。
class_name HomeMenu

signal new_game(color: Color)
signal load_home(id: String)
signal delete_home(id: String)

var _list: Panel
var _palette_selected: int = 1
var _sel_labels: Array = []

## 颜色板（蚁群外观标识色）
var _swatches: Array = [
	Color(0.72, 0.16, 0.16), Color(0.85, 0.45, 0.15), Color(0.80, 0.62, 0.15),
	Color(0.85, 0.78, 0.30), Color(0.35, 0.60, 0.28), Color(0.15, 0.55, 0.55),
	Color(0.18, 0.45, 0.75), Color(0.35, 0.35, 0.75), Color(0.55, 0.30, 0.70),
	Color(0.75, 0.35, 0.65), Color(0.45, 0.35, 0.20), Color(0.40, 0.48, 0.28),
	Color(0.55, 0.55, 0.55), Color(0.72, 0.66, 0.55), Color(0.30, 0.30, 0.30),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_style(bg)

	var vp := get_viewport().get_visible_rect().size

	# 标题
	_title("Empire Ants · 蚁穴帝国", Vector2(40, 40), 40)

	# 蚁后（自生成贴图；缺失则占位）
	var qr: Control
	var tx := _load_queen()
	if tx != null:
		var tr := TextureRect.new()
		tr.texture = tx
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2(vp.x * 0.30, vp.y * 0.30)
		tr.size = Vector2(vp.x * 0.4, vp.y * 0.4)
		qr = tr
	else:
		qr = _placeholder_queen(vp)
	add_child(qr)

	# 左侧：创建新存档 / 存档
	var cb_new := func():
		new_game.emit(selected_color())
	var newbtn := _button("＋ 创建新存档", Vector2(40, vp.y * 0.14), 260, 64, cb_new)
	_style(newbtn, Color(0.3, 0.7, 0.35))
	var saves := _button("▣ 存档", Vector2(40, vp.y * 0.14 + 84), 260, 64, func() -> void: _show_list())
	_style(saves, Color(0.5, 0.4, 0.2))
	add_child(newbtn)
	add_child(saves)

	# 敬请期待
	var coming := _button("敬请期待", Vector2(40, vp.y - 120), 240, 64, func() -> void: _toast("更多蚁种与关卡制作中…"))
	_style(coming, Color(0.7, 0.6, 0.2))
	add_child(coming)

	# 颜色板（右上）
	_build_palette(vp)

	# 存档列表
	_list = Panel.new()
	_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list.visible = false
	add_child(_list)
	_style(_list)


func _load_queen() -> Texture2D:
	for p in ["res://assets/textures/queen.svg", "res://assets/textures/queen.png"]:
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _placeholder_queen(vp: Vector2) -> Control:
	var l := Label.new()
	l.text = "蚁后"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	l.position = Vector2(vp.x * 0.35, vp.y * 0.42)
	l.size = Vector2(vp.x * 0.3, 120)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_palette(vp: Vector2) -> void:
	var panel := Panel.new()
	panel.position = Vector2(vp.x * 0.5, 40)
	panel.size = Vector2(vp.x * 0.48, 150)
	_style(panel)
	add_child(panel)
	_sel_labels.clear()
	var cols := 7
	var pad := 10.0
	var cell := (panel.size.x - pad * 2.0) / cols
	for i in _swatches.size():
		var r := i / cols
		var c := i % cols
		var sw := ColorRect.new()
		sw.color = _swatches[i]
		sw.position = Vector2(pad + c * cell, pad + r * (cell + pad))
		sw.size = Vector2(cell - 8, cell - 8)
		panel.add_child(sw)
		var bd := Button.new()
		bd.position = sw.position
		bd.size = sw.size
		bd.flat = true
		bd.clip_text = false
		bd.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		bd.pressed.connect(func() -> void: _select_swatch(idx))
		panel.add_child(bd)
		var sel := Label.new()
		sel.text = "✓"
		sel.add_theme_font_size_override("font_size", 24)
		sel.add_theme_color_override("font_color", Color(0, 0, 0, 0.85))
		sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sel.position = bd.position
		sel.size = bd.size
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel.visible = (i == _palette_selected)
		panel.add_child(sel)
		_sel_labels.append(sel)


func _select_swatch(i: int) -> void:
	_palette_selected = i
	for j in _sel_labels.size():
		_sel_labels[j].visible = (j == i)


func selected_color() -> Color:
	if _palette_selected >= 0 and _palette_selected < _swatches.size():
		return _swatches[_palette_selected]
	return Color(0.85, 0.45, 0.15)


func _show_list() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 10)
	_list.add_child(vb)

	var head := _button("◀ 返回菜单", Vector2(40, 40), 220, 56, func() -> void: _list.visible = false)
	_style(head)
	_list.add_child(head)

	var homes := SaveSystem.list_homes()
	if homes.is_empty():
		var l := _label("（暂无存档）", Vector2(40, 120), 24)
		_label_style(l)
		_list.add_child(l)
	for h in homes:
		var row := HBoxContainer.new()
		vb.add_child(row)
		var cc := _color_of_home(h)
		var sw := ColorRect.new()
		sw.color = cc
		sw.custom_minimum_size = Vector2(28, 28)
		row.add_child(sw)
		var label := _label("%s　食物%d　蚁皇浆%d" % [h.get("name", "家"), int(h.get("food", 0)), int(h.get("royal_jelly", 0))], Vector2.ZERO, 22)
		_label_style(label)
		row.add_child(label)
		var btn := _button("进入", Vector2.ZERO, 120, 44, func() -> void: load_home.emit(str(h.get("id"))))
		_style(btn, Color(0.3, 0.6, 0.5))
		row.add_child(btn)
		var cb_del := func():
			delete_home.emit(str(h.get("id")))
			_show_list()
		var del := _button("删除", Vector2.ZERO, 100, 44, cb_del)
		_style(del, Color(0.6, 0.3, 0.3))
		row.add_child(del)

	_list.visible = true


func _color_of_home(h: Dictionary) -> Color:
	var c: Array = h.get("color", [180, 120, 60, 255])
	return Color(float(c[0]) / 255.0, float(c[1]) / 255.0, float(c[2]) / 255.0, 1.0)


func _toast(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	var vp := get_viewport().get_visible_rect().size
	l.position = Vector2(vp.x * 0.5 - 160, vp.y * 0.5)
	l.size = Vector2(320, 40)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(l.queue_free)


# ---------- 组件辅助 ----------
func _title(text: String, pos: Vector2, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


func _button(text: String, pos: Vector2, w: float, h: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _style(_c: Control, _accent: Color = Color(0.15, 0.18, 0.22)) -> void:
	pass


func _label(text: String, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _label_style(l: Label) -> void:
	l.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	l.position = Vector2(40, 120)
