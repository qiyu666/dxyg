extends Node
## 主流程：首页菜单 <-> 主基地 <-> 关卡。持有当前"家"并管理场景切换。
class_name Main

var _menu: HomeMenu = null
var _view: GameView = null


func _ready() -> void:
	_show_menu()


func _show_menu() -> void:
	_clear_view()
	_menu = HomeMenu.new()
	add_child(_menu)
	_menu.new_game.connect(_on_new_game)
	_menu.load_home.connect(_on_load_home)
	_menu.delete_home.connect(_on_delete_home)


func _on_new_game(color: Color) -> void:
	var home := SaveSystem.new_home("", color)
	GameState.reset_home(str(home["id"]))
	_start_home_view()


func _on_load_home(id: String) -> void:
	GameState.reset_home(id)
	_start_home_view()


func _on_delete_home(id: String) -> void:
	SaveSystem.delete_home(id)


func _start_home_view() -> void:
	_clear_view()
	var v := GameView.new(GameState.home, null)
	add_child(v)
	_view = v
	_connect(v)


func _on_home_menu() -> void:
	_show_menu()


func _on_want_level(def: LevelDef) -> void:
	_clear_view()
	GameState.level_def = def
	var v := GameView.new(GameState.home, def)
	add_child(v)
	_view = v
	_connect(v)


func _on_finished(success: bool, rewards: Dictionary) -> void:
	if success:
		SaveSystem.settle_rewards(GameState.home, float(rewards.get("food", 0.0)), int(rewards.get("jelly", 0)))
		if not GameState.home.has("cleared_levels"):
			GameState.home["cleared_levels"] = []
		var lvl: LevelDef = GameState.level_def
		if lvl != null and not GameState.home["cleared_levels"].has(lvl.id):
			GameState.home["cleared_levels"].append(lvl.id)
		SaveSystem.save_home(GameState.home)
	_start_home_view()


func _connect(v: GameView) -> void:
	v.want_menu.connect(_on_home_menu)
	v.want_level.connect(_on_want_level)
	v.finished.connect(_on_finished)


func _clear_view() -> void:
	if _view != null:
		_view.queue_free()
		_view = null
	if _menu != null:
		_menu.queue_free()
		_menu = null
