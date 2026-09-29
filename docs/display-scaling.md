# 显示与文字缩放

游戏关闭了 Godot 的窗口拉伸，视口大小直接跟随窗口像素尺寸。缩放分成三个独立的量：

| 量 | 来源 | 作用 |
| --- | --- | --- |
| 窗口尺寸 | 分辨率设置或当前屏幕 | 决定视口像素尺寸 |
| 界面倍率 `U` | 界面缩放设置，经视口最小尺寸限制 | 缩放 `ui_root` 的控件、图标和面板 |
| 文字倍率 `T` | 文字缩放设置 | 决定文字在屏幕上的目标像素大小 |

`Game._apply_ui_scales()` 计算实际界面倍率 `U`，设置 `ui_root.scale = U` 和 `ui_root.size = viewport_size / U`，然后调用 `RtsUiTypography.apply_tree()`。所有控件字号都以 `scripts/ui/typography.gd` 中的基础字号为起点；不要读取已经缩放过的字号作为新的基础字号。

| 文字所在位置 | 控件内字号 | 最终屏幕字号 |
| --- | --- | --- |
| 普通 UI、统计图、原生下拉菜单 | `round(base × T / U)` | 约为 `base × T` |
| 原生 Tooltip、独立光标、世界注释 | `round(base × T)` | `base × T` |

原生下拉菜单打开时，Godot 会把 `content_scale_factor` 设为 `U`。原生 Tooltip 的 `content_scale_factor` 是 1；其 `TooltipLabel` 从已经缩放过的默认主题继承字号，因此必须使用启动时记录的原始字号，不能再以继承值为基础乘一次 `T`。`RtsUiTypography.apply_tree()` 统一处理这两种弹窗。

镜头 `camera.zoom` 只用于世界画面。光标在独立的 `CanvasLayer` 中，使用屏幕字号；建筑和贸易站等世界标签在 2D、2.5D 视角下都用反向变换抵消镜头倍率，屏幕字号只由 `T` 决定。对局内的底部面板根据内容最小高度向上扩展，概要最多显示两行，完整属性可在“详情”中查看；顶部资源栏放不下时，工具按钮自动换到第二行。

`tests/typography_scale.gd` 覆盖多个 `U`/`T` 组合，并实际打开下拉菜单和 Tooltip 验证字号。显示布局测试见 `tests/display_settings.gd`、`tests/tech_tree_page.gd` 和 `tests/hud_resolution.gd`。
