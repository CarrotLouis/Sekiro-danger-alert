# Sekiro danger alert

《绝地潜兵 2》的 Bingus Shared Loader Lua 模组：以只狼风格的“危”动画与音效提示 Crusher 攻击。

依赖 [Bingus Shared Loader](https://github.com/CowboyBingus/BingusSharedLoader) 和 [Mod Options Menu](https://github.com/CowboyBingus/ModOptionsMenu) v1.2 / API 3。游戏内可独立调整提示音量，并立即试听。

当前版本为 **0.4.0 测试版**：普通重炮塔进入开火准备阶段，或 Crusher 开始已识别的非跺脚攻击，且有效 AI 实体目标是本机潜兵时播放提示。**两者都不再限制距离**。仅适配 Steam build 25480438。

使用已确认的 R2 双层“危”动画与音效，每帧跟随本机潜兵头部，位置、50%～300% 大小及音量可调。升级保留 GUID、资源路径和已有设置。

最后两份有效采集中的 313 条炮塔攻击样本支持识别普通重炮塔能力 1037。静态代码显示准备事件在能力时钟 1.0 秒、扣动武器扳机在 1.5 秒；按实际采样回放产生 10 次预警，每次比原生扳机事件早约 0.42～0.49 秒。这个时间不包含弹丸飞行，也不代表已验证飞扑成功率。详见 [0.4.0 验证记录](docs/VALIDATION-0.4.0.md)。

Crusher 保留 13 个已核对的非脚部攻击分支，排除 1409 / 1410 / 1423 跺脚。使用者已确认 0.3.2 在超过 16 只的场景正常预警；本版新增的“目标是本人”过滤仍需游戏验证。当前只信任本机拥有的敌人 AI；没有有效实体目标或只有未经验证的客机同步数据时不提示。普通重炮塔以外的机器人武器尚未启用。

自动检测改为有预算的攻击表扫描，超出单批预算会继续轮转，取消固定保留 16 个敌人的方案。可选的动作 / 索敌采集仍采用较小的观察范围；这些采集限制不参与自动预警。两种采集都记录自动检测的实际决策和 F8 时间差。详见 [测试说明](README-测试说明.txt) 和 [索敌研究](docs/ENEMY-TARGETING.md)。

## 开发

```sh
python -m pip install -r requirements.txt
python scripts/build.py
python scripts/test.py --mom-source /path/to/ModOptionsMenu
```

测试前设置 `HD2_LUA51_DLL` 指向本机游戏的 `bin/lua51.dll`。详见 [构建说明](BUILD.md)。

| 目录 | 内容 |
| --- | --- |
| `src/` | Lua 模块与版本限定的读取布局 |
| `config/` | 炮塔候选资源与只读采集指令校验 |
| `scripts/` | 素材处理、构建与测试入口 |
| `tests/` | 离线测试 |
| `assets/` | 50 张 512² 材质遮罩、效果参数与提示音；不包含字体文件 |
| `vendor/` | 必要的第三方辅助代码、许可证和来源记录 |
| `docs/` | 开发记录与验证范围 |
| `outputs/` | 本地产物，Git 忽略；由维护者自行发布 Release |
| `build/`, `work/`, `research/` | 本地缓存、参考仓库与原始研究数据，Git 忽略 |

修改经过检查后正常 commit / push。仓库不自动发布 Release，也不包含游戏 DLL、HUD Plus 源码或原始采集日志。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

第三方代码许可见 `vendor/`；素材来自用户提供的只狼视频，未声明拥有第三方素材版权。详见 [致谢](CREDITS.txt)。
