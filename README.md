# The Ants · 小小蚁国 — Godot 4 / 安卓 3D 原生移植

这是 `ant-kingdom`（HTML 版）的 **Godot 4 原生安卓 3D 移植**：同样的玩法与系统（六边形土壤、
挖地道、孵化方格、5 支信息素队伍、埋藏敌人、暗色压迫风），改成 3D 场景 + 原生触屏。

> ⚠️ 本目录里**没有 .apk**：导出安卓需要**桌面版 Godot 4 + Android SDK**。
> 本容器（PRoot/安卓机）没有 Godot/Java 工具链，无法直接编译。你拿到电脑后用 Godot 打开本目录导出即可。

## 目录结构
```
project.godot          # 工程（GL Compatibility 渲染器，移动端可用）
icon.svg
autoload/Game.gd       # 常量/六边形数学/关卡数据/经济/孵化参数/存档（数值与 HTML 一致）
scenes/Main.tscn       # 入口场景
scripts/Main.gd        # 菜单→关卡流程 + 触屏点选（射线拾取）+ 模式路由
scripts/World3D.gd     # 一个关卡的 3D 世界 + 运行时（蚁群/敌人/食物/孵化/队伍/胜负）
scripts/TerrainGrid.gd # 土壤六格(3D) + 埋藏内容 + 孵化流水线 + 挖掘 + 建筑 + 蚁后 + 标记
scripts/AntUnit.gd     # 3D 蚂蚁（移动/挖地道/搬食/战斗/队伍/信息素/兵蚁守蚁后）
scripts/EnemyUnit.gd   # 3D 敌人（追踪/攻击/死亡掉落/威胁光晕）
scripts/HUD.gd         # 顶部状态 + 底部操作按钮 + 队伍/信息素 + 提示
export_presets.cfg     # 安卓导出预设（起点）
```

## 导出安卓 APK
**最快：用仓库自带的 Actions 工作流** `.github/workflows/android-apk.yml`
（Godot 4.7.1 + 非 Gradle 直接导出 + apksigner 签名，推 main 或手动触发都会跑，产物在 Artifacts → `TheAnts-debug`）。

要在本地/CI 手动出包，需桌面 **Godot 4.7.x** + Android SDK + JDK 17：装好 Android 导出模板后
`项目 → 导出 → Android` → 选 `Android` → 导出。首台真机安装。

## 怎么在编辑器里跑
1. 安装 [Godot 4.7.x](https://godotengine.org/download)（非 .NET 版即可；CI 用 4.7.1）。
2. 打开本目录（`ants-godot` 的 `project.godot`）。
3. 按 `F5` 在桌面窗口运行：菜单 → 选颜色 → 第一/第二关。
   - 触屏操作在桌面用鼠标左键模拟（代码同时处理 ScreenTouch 与 MouseButton）。

## 导出安卓 APK（关键步骤，需桌面）
1. 安装 **Android Studio**（含 SDK）+ **JDK 17**。
2. Godot 里安装 **Android 导出模板**：`编辑器 → 管理导出模板 → 下载全部`。
3. `编辑器 → 项目设置 → 导出 → Android`：填 SDK/JDK 路径、`keystore`（可用 debug）。
4. 在代码里把包名/签名按 `export_presets.cfg` 改（`package/unique_name` 等）。
5. `项目 → 导出 → Android` → 选 `Android` → 导出 `ants.apk`。
6. 真机/模拟器安装。横竖屏：工程已设竖屏（`window/handheld/orientation=1`）。

## 已移植（与 HTML 一致的系统）
- ✅ 六边形土壤网格 + **挖地道**（工蚁走过去把进度挖满才变通道，非点击瞬挖）
- ✅ **埋藏敌人/食物**：开局 0 敌人，挖到才钻出；前线泥土显示「！危险 / 食」标记；点泥土=探查
- ✅ **孵化方格流水线**：取卵→卵→白幼虫→黄蛹→耗食物羽化（工2/兵5）；蚁死后快速补
- ✅ **人口上限=孵化方格数**；只有工蚁能取卵/建造/挖掘；兵蚁默认守蚁后附近
- ✅ 5 支信息素队伍 Ⅰ–Ⅴ + 信息素点 + 攻/搬 + 每队最大出动
- ✅ 暗色压迫风：暗环境 + 雾 + 巢心微光 + 敌人威胁光晕
- ✅ 两关数据（第一关清威胁 / 第二关扩建 50兵+47工）、食物经济、蚁后血量

## 简化 / 需补完（如实说明）
- 🟡 3D 蚁/敌用**基础体素（球体组合）**代替模型；可换成 `Gltf` 低模更真实。
- 🟡 蚁丘"家"（home 建造/升级/进化/存档换丘）未做成独立界面——直接进关卡；存档框架在 `Game.gd`。
- 🟡 「到地面」地表视图未做（蜘蛛洞=食物巢）；可加一个地表 3D 场景。
- 🟡 音效未接（Godot 自带 AudioStreamPlayer 即可补）。
- 🟡 第二关 50+47 扩建目标偏大，可在 `Game.LEVELS[1]` 调小数值。
- 首次打开若有个别脚本报错，按 Godot 的红色提示逐条修（此工程未经真机/编辑器验证，逻辑与数值对齐 HTML，但 3D 细节需你在编辑器里跑一遍确认）。

## 想对齐 HTML 的哪一块
直接改 `autoload/Game.gd`（数值/关卡/孵化参数）或对应 `scripts/*.gd`。所有系统都对应 HTML `game.js` 的函数。
