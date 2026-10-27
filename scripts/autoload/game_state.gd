extends Node
## 全局状态：当前激活的"家"数据与当前运行视图引用。
## 由主流程脚本（main.gd）在切换场景/场景内切换时写入。

## 当前激活的"家"字典（SaveSystem 格式）。空 = 未进入任何家。
var home: Dictionary = {}
## 当前正在运行的主视图（GameView），可能是主基地或关卡。
var active_view: Node = null
## 当前关卡定义（关卡运行时非空；主基地为空）。
var level_def: RefCounted = null


func clear() -> void:
	home = {}
	active_view = null
	level_def = null


func reset_home(home_id: String) -> void:
	home = SaveSystem.load_home(home_id)
	active_view = null
	level_def = null
