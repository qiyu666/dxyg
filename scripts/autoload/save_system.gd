extends Node
## 存档系统：管理多个"家"。每个"家"独立存档为 user://saves/home_<id>.json。
## 只保存长期成长数据；关卡内的临时状态不在此持久化。

const SAVE_DIR := "user://saves/"

# 一个"家"的默认值（与需求对应：7 工蚁、35 食物、70 储量）
const DEFAULT_DIG_CAP := 40
const DEFAULT_STORAGE := 70.0
const DEFAULT_FOOD := 35.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# 新"家"。color 为蚁群外观标识色（不影响关卡地图/敌人/地块配色）。
func new_home(p_name: String, p_color: Color) -> Dictionary:
	var id := _new_id()
	var home := {
		"id": id,
		"name": p_name if p_name != "" else ("家 #%d" % (list_homes().size() + 1)),
		"color": [int(p_color.r * 255), int(p_color.g * 255), int(p_color.b * 255), int(p_color.a * 255)],
		"food": DEFAULT_FOOD,
		"storage_cap": DEFAULT_STORAGE,
		"dig_cap": DEFAULT_DIG_CAP,
		"royal_jelly": 0,          # 蚁皇浆：用于进化
		"evolutions": [],          # 已解锁进化 id
		"cleared_levels": [],      # 已通关关卡 id
		"created_at": int(Time.get_unix_time_from_system()),
	}
	save_home(home)
	return home


func save_home(home: Dictionary) -> void:
	var f := _file(home["id"])
	var file := FileAccess.open(f, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(home, "\t"))
		file.close()


func load_home(id: String) -> Dictionary:
	var f := _file(id)
	if not FileAccess.file_exists(f):
		return {}
	var file := FileAccess.open(f, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func list_homes() -> Array:
	var out: Array = []
	var da := DirAccess.open(SAVE_DIR)
	if da == null:
		return out
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		if f.ends_with(".json"):
			var home := load_home(f.replace(".json", ""))
			if not home.is_empty():
				out.append(home)
		f = da.get_next()
	da.list_dir_end()
	# 最新在前
	out.sort_custom(func(a, b): return int(a.get("created_at", 0)) > int(b.get("created_at", 0)))
	return out


func delete_home(id: String) -> void:
	if FileAccess.file_exists(_file(id)):
		DirAccess.remove_absolute(_file(id))


# 关卡奖励结算到"家"（食物入库、解锁进化、记录通关）。
func settle_rewards(home: Dictionary, food: float, jelly: int) -> void:
	home["food"] = clampf(float(home.get("food", 0.0)) + food, 0.0, float(home.get("storage_cap", DEFAULT_STORAGE)))
	home["royal_jelly"] = int(home.get("royal_jelly", 0)) + jelly
	save_home(home)


func _new_id() -> String:
	randomize()
	return "h%06x" % randi()


func _file(id: String) -> String:
	return SAVE_DIR + "home_%s.json" % id
