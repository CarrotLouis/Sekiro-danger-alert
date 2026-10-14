# Enemy Spawner 0.1.0：来源和验证范围

本工具是独立测试 addon，公开名称 `Sekiro danger alert - Enemy Spawner`，GUID `e2481445-39ce-5af2-9ff2-5052a6a76fd4`，入口 `mods/peril_warning/enemy_spawner`。原警报身份与选项 ID 保持稳定。

## 资源与变体

解码引用来自 FileDiver commit `6bf7c1ccc4be465a35b4bc9d41087781b47034e6`，实体文件 SHA-256 `21377252b81fdbc670eba1e59a8ab64b170323df208f175e708992e4c1fb515e`，类型库 SHA-256 `4d04870d0a0d4dc1284998c72cdfa6f8ff6d21aba0e36b6f758c6f73dd0417a4`。完整文件、字典、原始日志和模块截取不入库。

`EnemyPackageComponentData` 为组件索引 77，316 个索引槽、158 个 32 字节记录；记录 +8 为主 package，+16 为子实体 package，+24 为被包含的 Wwise 资源，**不是另一项 package 请求**。原生 `0x4F8AF0` 读取世界 +`0xF126E0`，索引 16 字节、记录 32 字节；`0xABDA25` / `0xABDA43` 分别把 +8 / +16 交给包收集流程。工具请求这些原生包，而非把模型文件临时替换为敌人。

目录包括 14 类敌人和 31 项本体 / 挂载单元引用。穿刺虫的子实体包也被保留，其触手由原生 AI 生成。挂载定义与 UnitPath 在生成前再次核对，避免其他改动把未加载的单元引入原生创建调用。

| 用户名称 | 实体资源 | 行为 ID |
| --- | --- | --- |
| 强袭虫 | `1a7fcdff98c664b0` | 104 |
| 孢子强袭虫 | `6b202392f4ab605e` | 105 |
| 巨兽强袭虫 | `a05bd1ec67b3ac4c` | 104 |
| 钻地强袭虫 | `0ab7b92b131c228c` | 106 |
| 穿刺虫 | `dcf8e74212fbee3b` | 113 |
| 吐酸泰坦 | `9e2e17f2ccccafdd` | 133 |
| 蟑龙 | `960b48a421a3faaa` | 108 |
| 孢裂泰坦 | `ef04cb84d097a497` | 134 |
| 巨型者 | `3e0537d606438fea` | 56 |
| 移动工厂 | `d37e8d120d2836e3` | 97 |
| 强化纵步者 | `9076eeed17fcee35` | 96 |
| 湮灭坦克 | `53d8919d7b8abd67` | 76 |
| 铁幕坦克 | `63df3d07b7424588` | 78 |
| 巨型炙焰者 | `e44ec9f9b3fe1d2a` | 57 |

新确认的强化纵步者路径 `content/fac_cyborgs/vehicles/cyborg_walker_scout/cyborg_walker_scout_tier2` 与未知实体键精确哈希匹配；共享普通纵步者模型，但拥有四项武器挂载。巨型炙焰者路径 `content/fac_cyborgs/cha_lieutenant/cha_lieutenant_assault_jumppack` 同样精确匹配，挂载普通锯、喷火器和 `lieutenant_jetpack`。`lieutenant_ivory_legion_assault` 为另一个变体，不再当作喷射背包变体的采集身份。对应 Wiki 名称仍须实际外观 / 行为验证，不能把结构证据当作实机观察。

## 原生请求与门禁

HD2Runtime 的公开通用实体 spawn 仍标为 blocked；本工具未调用该 API，也未把 Pelican 专用函数简单改为任意资源。依据保留的本机构建代码，独立核对了通用创建链和所有参数：

- `0xFD9710(out u32*, entity resource u64, descriptor*)`：完整 184 字节入口核对；准备默认 modifiers，调用 `0xFDC0C0`。
- `0xFDC0C0`：创建 root unit，再调用 `0xFDC140` 创建全部组件与行为。后者完整 457 字节核对。
- descriptor 88 字节，+0 owned、+4 未分配网络 ID `0x7FFF`、+8 为 4×4 姿态、+`0x48` 为上下文指针、+`0x50` 默认 modifiers 空指针。
- 上下文为 Lua 自持有的对齐 2208 字节零块，仅设置 +`0x66C` 目标实体和 +`0x670` 目标位置。`0x8425F6` 读取这些字段并初始化 Behavior；没有行为 override、关联对象或非零指针。
- 世界默认上下文必须为全零；所有指令与文件 SHA 匹配；只在游戏更新链中调用，初始化 20 秒内和菜单回调中均不调用。
- RefcountedPackageSystem 使用 HD2Runtime 已核对的 `request(instance, ids, count)` ABI，指令重新与本机保留代码匹配。请求与引用计数只通过游戏 API 完成，没有直接写内存、改变保护或安装钩子。
- 资源请求必须来自经验证的 EnemyPackage 记录，引用表和引擎加载队列留有空间；持有引用至本次进程结束。引擎 package 的全部 part 必须为 state 4，再核对每项 Unit 资源已可查询。
- 保持至少 64 个空实体描述符，空值由 `0xFDC1F6` 实际读取的 global `0x348456C` 取得。不能套用其他子系统的 invalid 常量。
- 原生创建返回后，核对 Health 身份、owned、Unit、Behavior ID 及初始本人目标；不吻合则停止当前任务继续生成。

只读检查单次最多 4000 次 / 1 MiB，复用警报模块读取也有其独立 2500 次 / 1 MiB 上限。资源状态每 0.25 秒检查，超时 90 秒；每次意图只执行一次，每任务最多 32 次。资源引用最多 32 项，自持有上下文最多 256 个。任务类型必须是所选敌人的原生阵营，且玩家数为 1、模式实体由本机拥有、潜兵仍存活。

## 离线检查与实机待验

使用安装游戏的 `lua51.dll` 编译封包源码，在真实 ModOptionsMenu v1.2 / API 3 上检查两个选项与 14 项选择。合成内存边界重放生产门禁，验证部分 package 未加载时零次 spawn、重复请求不重复增加引用、版本不符 / 多玩家 / 单元未加载时拒绝。生成 descriptor 检查对齐、64 位实体 ID、姿态、目标字段及其余零值。控制流程覆盖等待、精确一次、死亡 / 换场景取消、超时、间隔及创建失败停止。

这些测试不调用真实游戏创建入口。**原生敌人生成效果尚未实测**，包括 14 种模型、武器、AI 移动和完整招式；保持测试版标记。地图落点没有地形射线校准，20m 水平位置采用当前高度，请使用开阔平地。若原生调用 begin 无 returned，请保留日志，停止重复操作并反馈。

Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime

FileDiver component source: https://github.com/xypwn/filediver/tree/6bf7c1ccc4be465a35b4bc9d41087781b47034e6/datalibrary
