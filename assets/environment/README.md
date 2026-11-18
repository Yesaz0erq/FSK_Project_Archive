# 环境美术素材

本目录保存早期版本的四张地区远景、台地纹理、景物剪影和绘制提示词，供后续美术参考。

当前游戏通过 `scripts/world/district_land.gd` 生成河谷网格，`district_props.gd` 布置立体植被与岩体，`river_crossing.gd` 根据两岸位置生成步桥。六类可操作地块与外围近岸共用 `assets/terrain/` 的地区纹理。实时投影、天气粒子和最终的像素采样在 `scenery.gd` 中组装。
