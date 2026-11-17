# 环境美术：Hi-bit 暮色版本

保持原有森林、沙漠、火山、雪山的内容、布置和经营规则，仅重绘表现风格。参考图只用于像素笔触和氛围照明，不引入温室、废墟或其他参考图建筑。

- `props_hd.png`：使用内置 imagegen 生成的透明环境图集，含松树、阔叶树、仙人掌、砂岩、玄武岩、枯树、雪松、冰晶。完整提示词在 `generation-prompt.txt`。
- `scripts/world/scenery.gd`：图集区域、原场景植物替换、程序化像素材质、灯笼、冷暖光源和氛围光束。
- `assets/shaders/environment_grade.gdshader`：原分辨率3D采样，只做轻量暗角和亮部扩散。已移除整屏降采样和全局色阶量化；像素色块来自素材本身。
- `assets/shaders/environment_water.gdshader`：世界坐标像素波纹与条带状环境反光。
- `assets/shaders/environment_glow.gdshader`：光晕、地面光池、伪体积光束。

伪光追由辅助轮廓光、灯笼局部光、着色器反光及光晕组合实现，沿用Compatibility渲染器。原11×11地块、机械、UI布局和玩法继续保留；本轮不是整套机械/UI美术重绘。

通过一次四地区渲染检查，并按后续要求降低场景采样分辨率后再次查看四地区画面。实际画面保存在 `docs/environment_forest.png`、`environment_desert.png`、`environment_volcano.png`、`environment_snow.png` 和 `environment-overview.png`。修改前备份为 `.backup-before-hibit-environment/`。

## 清晰度修正

标题菜单固定绘制在场景后处理上层，正文17px、按钮18px，并加深不透明面板以提高对比度。所有小标签至少13px。六种地块重新生成256×256原生材质，使用4px及以上的有组织色块、阶梯纹路、窄描边；减少单像素碎点，保留六面块体和纯黑底面。原生256像素材质并不等于降低屏幕分辨率。恢复2×MSAA，改善几何边缘。

生成入口：tools/make_terrain_textures.cjs（调用 make_terrain_textures_hd.cjs），再运行 tools/build_terrain_models.gd。1920×1080标题和游戏画面在 docs/title-hd-clarity.png 与 docs/game-hd-clarity.png；一次实际渲染检查通过，日志 clarity-preview.log。
