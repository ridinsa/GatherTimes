-- zhCN_help.lua : 帮助面板的简体中文文本 (每个主题一段, 参见 UI/Panels/PanelHelp.lua)
local _, GT = ...
GT.locales = GT.locales or {}
GT.locales.zhCN = GT.locales.zhCN or {}
GT.helpText = GT.helpText or {}

-- topic tab captions (the buttons are ~54 px wide: keep them short)
GT.locales.zhCN["Start"] = "开始"
GT.locales.zhCN["Panels"] = "面板"
GT.locales.zhCN["Tips"] = "提示"
GT.locales.zhCN["HUD"] = "HUD"
GT.locales.zhCN["Cmds"] = "命令"
GT.locales.zhCN["Credits"] = "鸣谢"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "小地图 HUD" .. E .. [[

将真实小地图扩展为横跨屏幕的大型半透明地图，可选显示圆环、罗盘字母、朝向、优先就绪节点和路线进度。你的采集标记仍会显示。

]] .. H .. "开启 / 关闭" .. E .. [[

- 在主窗口中左键点击“小地图 HUD”按钮。
- 输入 /gt hud（或 /gthud）。
- 使用按键：HUD 设置 > 地图标签 > 按键绑定（点击按键按钮后按下一个键；Esc 取消，清除可移除绑定）。也可在按键设置 > 插件 > GatherTimes 中设置。
- 可选：采集追踪启用时自动开启（HUD 设置 > 选项）。

]] .. H .. "HUD 设置（右键点击 HUD 按钮）" .. E .. [[

- 地图：HUD 大小、地图不透明度（0% = 地图空白，只显示标记；100% = 完全不透明；分 10 档）、小地图缩放、按键绑定。
- 圆环：圆环半径、第二个圆环、粗细、平滑度、圆环样式（线条、条纹或圆点：按钮可循环切换）、密度、圆环颜色（点击“圆环颜色...”打开拾色器：每个圆环各有滑块，并为当前标签的圆环提供随机颜色按钮）、罗盘字母（N E S W）、朝向读数、优先就绪采集读数（最近的就绪节点，否则显示最近的刷新点）以及路线进度读数（当前计划路线步骤）。每项读数都可单独启用或关闭。
- 追踪：HUD 开启时的追踪按钮（大小 20-80 px 和位置），以及 HUD 关闭时的按钮行为（自动、自己的或默认）。
- 选项：地图随玩家旋转、玩家箭头、骑乘时隐藏 HUD、采集追踪启用时自动开启、/reload 或登录后恢复 HUD、隐藏小地图插件皮肤、诊断。
- 配置档：保存多种外观、切换或删除。所有角色共享配置档；每个角色分别记住自己的选择。
- 重置配置档会恢复默认设置。]]

T.credits = H .. "GatherTimes 0.24.4" .. E .. [[

作者：miRidinsa
网站：https://github.com/ridinsa/
许可证：GNU GPL v3 或更高版本（参见插件文件夹中的 LICENSE）。

]] .. H .. "库" .. E .. [[

- Nevcairiel 编写的 HereBeDragons-2.0 和 HereBeDragons-Pins-2.0：用于小地图和世界地图上的标记位置。
- LibStub 和 CallbackHandler-1.0（WoW Ace 库）：用于加载库和处理回调。

]] .. H .. "随机名称" .. E .. [[

内置 HideUnitNames 模块的副本（也支持独立的同名插件：加载时，本副本会停用）。

]] .. H .. "辅助插件" .. E .. [[

- HereBeDragons：显示标记所需。
- GatherMate2：可导入其节点数据。
- TomTom：为箭头和路线提供路径点。

]] .. H .. "翻译" .. E .. [[

语言文件位于 Locales 文件夹。感谢所有帮助翻译以及提交调试报告的人。]]

T.start = H .. "欢迎使用 GatherTimes" .. E .. [[

追踪你所在区域的草药和矿石何时重新刷新，记住节点出现的位置，并显示在主窗口、小地图和世界地图上。

]] .. H .. "快速开始" .. E .. [[

1. 输入 /gt 打开窗口。
2. 点击节点（底部），勾选你采集的草药 / 矿石。
3. 开始采集。只要你拾取了某个节点的战利品，计时器就会开始。
4. 查看主窗口的表格。节点就绪时，你会收到屏幕提示和声音，靠近时还会有提示音。

]] .. H .. "主窗口" .. E .. [[

- 下拉列表（顶部）：显示所有已勾选的节点，或只显示一个。
- 展开的物品下拉列表中，右侧会显示背包数量；关闭状态下选中的物品不显示数量。
- 表格：每组相邻节点占一行。G1、G2……是你在地图上也能看到的组号。
- 状态：Waiting = 所有节点仍在倒计时。2/3 up = 部分节点已刷新。Ready = 全部已刷新。Idle = 没有运行中的计时器。
- 节点刷新后会保持一段时间的 Ready 状态，然后变为 Idle（时长在 设置 > 常规 > 就绪状态持续时间 中选择）。
- 每个计时器的提示只发送一次。距离在 设置 > 常规 中调整；在 节点 > Alert 中可以为每种资源开启或关闭提示。
- 小地图 HUD 开关按钮：左键切换 HUD 开启或关闭，右键打开 HUD 设置。HUD 开启时文字为绿色，关闭时为灰色。
- 服务器和游戏模式标签显示在计时器表格下方。
- 底部的 5 个按钮用于打开各个面板。再次点击同一按钮可关闭该面板。
- 拖动标题栏可以移动窗口。标题会显示你当前所在的区域。
- 标题栏中的 ? 按钮打开本帮助。
- 标题栏中的 - 按钮会把窗口收起为屏幕顶部的一条细栏。右键打开最小化设置。细栏上有物品下拉列表、每组一个小方块、本次会话金币和 "+" 按钮（用于恢复窗口）。连续右键点击两次金币可重置会话（重置前会先把统计输出到聊天框）。

]]

T.panels = H .. "计时" .. E .. [[

所有正在运行的计时器（就绪的排在前面：Grp、节点、时间），以及本次会话的汇总。Clear waypoint 清除箭头。Show summary 在可复制的文本框中打开本次统计（物品、金币价值和每小时金币）。Reset session 先输出统计，然后重新开始会话计时并清零计数。

]] .. H .. "节点" .. E .. [[

选择要追踪的内容以及方式。
- On：勾选以追踪某种草药 / 矿石。
- Min：刷新时间（分钟）。输入新数字后按 Enter。
- Col：节点在地图和列表中的颜色。左键 = 下一个颜色，右键 = 上一个颜色。
- Alert：开启或关闭该资源的就绪提示。该检查与该资源是否显示在主下拉列表中无关。
- Sound：提示音。点击 = 下一个（播放预览），右键 = 上一个。
- Dropdown：全部 / 草药 / 矿石。List all：显示所有节点，而不仅是当前区域的节点。
- Nodes per group：多少个相邻节点组成一组（G1、G2……）。
- Nodes up per group：至少多少个节点刷新后，该组才算就绪。
- Select All、Select None、Reset（恢复默认时间）。
- 主窗口中展开的物品下拉列表也会显示背包中该资源的数量；被选中的按钮不显示数量。

]] .. H .. "导航" .. E .. [[

- 路线：选择一种已启用的草药 / 矿石，或所有已启用的资源，然后 Build route 规划经过活动计时器的路径。Next step 前进到下一步，Clear route 清除路线。选项包括：仅包含就绪节点、在地图上绘制路线、自动箭头、最大节点数和时间窗口。若要优先采集库存低的资源，请使用"优先低库存资源"（仅统计背包）。
- 标记：在地图和小地图上显示刷新点、显示组标签（G1、G2……）、其他物品显示为小点、隐藏本次会话已采集的地点、右键地点打开组菜单、采集时的节点偏移，以及 Refresh pins。重置会话时，已采集地点的筛选会被清除。
- 箭头：TomTom 集成、指向最近节点的箭头、路线中自动切换到下一个节点、箭头距离、Waypoint to nearest。需要 TomTom 插件。

]] .. H .. "时间" .. E .. [[

每个节点：Now = 当前使用的刷新时间。Learned (n) = 根据你自己的访问测得的范围，即较快的典型值（例如 10.5-12.0），n = 样本数（少于 5 个为橙色，5-9 个为黄色，10 个及以上为绿色；绿色的学习时间表示典型值比 Now 更快；* = Per zone 模式下显示的整个物品的数值）。刷新时间会有波动，因此请预期值会落在该范围内。Apply / auto-apply 使用右侧的典型值。Taken = 节点被发现为空的频率。
- Learned times：Per item（每种草药 / 矿石一个学习时间，默认）或 Per zone（当你所在的区域有 5 个样本时，使用该区域的数值）。
- One shared timer per group、Detect empty nodes、Use game messages、Auto-adjust learned times（可缩短或延长，但不超过出厂时间的两倍）。区域开关位于 设置 > 常规。
- Apply all faster 将学习时间复制到 Now。Reset learned timings 清除学习时间。

]] .. H .. "设置" .. E .. [[

- 常规：屏幕提示和 Alert time、就绪提示的最小与最大距离（0 表示不限制该端）、聊天公告维护时的提示（闪烁颜色 1-7）、低血量警告（硬核模式）、就绪状态持续时间，以及仅显示我所在区域的计时器和标记。
- 显示：地图文字大小、窗口大小、移动时半透明、保持窗口可见（ESC 不会关闭它们），以及鼠标悬停时的物品提示。语言下拉列表位于 Look 中，需重新加载界面后生效（显示为 "w/reload"）。
- Look：语言、Frame skin（窗口和提示的配色主题；Pastel Pink 和 Sakura 使用深色文字并带细边框）、Font（Friz Quadrata、Arial Narrow、Skurri、Morpheus，或客户端已有的 Friends）和 Font size（80% 至 130%）。韩语、中文、日语和俄语保留各自的字体，因此对这些语言，字体选择会被一条说明替代。
- 工具：插件及其辅助插件的状态、Import GatherMate2、Clear learned spawn points、Export my spots / Import spots（与好友分享地点）、Copy debug report（用于错误报告的文本块）、Reset timers、Start a new session at login，以及错误日志。

]] .. H .. "背包与会话统计" .. E .. [[

展开的物品下拉列表会在每个物品旁边显示背包数量；选中的物品按钮会隐藏该数量。计时面板显示会话汇总。Show summary 打开相同的统计；Reset session 先输出统计，然后清零计数并重新开始会话计时。只有可识别的采集战利品会被计入。Reset session 还会清除仅限本次会话的已采集地点筛选。

]] .. H .. "随机名称" .. E .. [[

在主窗口中右键点击设置按钮即可打开（再次右键关闭）。它会在你的屏幕上隐藏你自己的名字，适用于直播或截图。其他玩家仍然看到你的真实名字。
- Disguise names：开启或关闭伪装。开启时，其他玩家的名字也会被隐藏（通过游戏的名称设置实现，关闭时会恢复）。
- Hide party / raid names：单独隐藏屏幕上的小队和团队名称标签。
- Fake player name / Fake pet name：用于替代显示的名字。输入名字后按 Enter 或点击 Apply。最多 12 个字符。
- Randomize Names：选择新的随机名字和假等级。Random level range 滑块设置最高等级。Opacity 会让窗口背景变得透明，同时保持文字清晰可读。
- 显示位置：你的单位框体（包括你选中自己或宠物时）、单位提示、角色窗口标题和聊天。开启伪装后，物品提示中匹配的角色名也会被隐藏。
- 命令：/hun（开启或关闭伪装）、/hun player <n>、/hun pet <n>、/hun random、/hun status、/hun help。
- 如果已加载独立的 HideUnitNames 插件，这里的随机名称会被关闭。请使用该插件。

]]

T.tips = H .. "分组" .. E .. [[

相邻的节点会被视为一组，因此你可以看到整组何时刷新，而不必逐个查看节点。开启 One shared timer per group（时间面板）后，每组只有一个计时器。

]] .. H .. "修正节点（世界地图）" .. E .. [[

在世界地图上右键点击计时器文字或节点标记，即可打开一个小菜单（在 导航 > 标记 中开启）：
- 此节点为空：已被其他人拾取。
- 整组被他人拾取：整组已被采集。
- 将此节点移入其他组：放入另一个组（1、2、3……或 New）。
- 输入简短备注后点击 Save note，即可为该节点添加提醒。将鼠标悬停在节点上可查看备注。备注会随节点一起保存。
小地图从不打开此菜单。你可以在 导航 > 标记 中关闭它。

]] .. H .. "刷新时间如何学习" .. E .. [[

每当节点刷新并且你拾取了它的战利品，就会记录从其所属战利品到现在的时间（如果一组中多个节点同时刷新，则使用最近战利品中最早的那个，而不是最新的）。插件会忽略过短和过长的间隔，然后在时间面板中显示从最快四分位数到你的样本中位数（典型值）之间的数值，并四舍五入到 15 秒。Apply 和 auto-apply 使用中位数。显示数值需要 3 个样本，自动应用需要 5 个。

]] .. H .. "与好友分享地点" .. E .. [[

设置 > 工具 > Export my spots（或 /gt export）会把你自己的地点显示为一行文本。点击文本框，按 Ctrl+C 复制后发给好友。好友使用 Import spots（或 /gt import），按 Ctrl+V 粘贴后点击 Import。只会分享物品、区域和位置，不包括计时器或计数。好友已有的地点会保持不变，途中被截断的文本会被拒绝导入，而不会只导入一半。

]] .. H .. "辅助插件" .. E .. [[

- HereBeDragons：显示地图和小地图标记所必需。请安装。
- GatherMate2：设置 > 工具 > Import GatherMate2 会添加它已知的节点位置。
- TomTom：使箭头和路线路径点能够显示。

]] .. H .. "出现问题？" .. E .. [[

- 没有标记：安装 HereBeDragons。设置 > 工具会显示已找到的内容。
- 计时器未开始：输入 /gt debug，然后拾取一个节点的战利品，插件会打印它所看到的内容。
- 错误会列在 设置 > 工具 > Error log 中（点击，Ctrl+A，Ctrl+C 复制）。
- 报告问题或与其他插件的冲突：设置 > 工具 > Copy debug report（或 /gt report），复制文本并粘贴到报告中。
- 节点或组错误：在世界地图上右键点击它。]]

T.cmds = H .. "斜杠命令" .. E .. [[

/gt - 打开或关闭主窗口
/gt list - 在聊天中显示活动计时器
/gt stats - 在聊天中显示会话汇总
/gt yield - 按区域和物品显示已保存的产出（前 10 个区域）
/gt yield current - 当前区域的产出汇总
/gt debug - 开启或关闭战利品检测消息
/gt profile start | stop | report - 分析计时器循环
/gt hud - 小地图 HUD（见下文）
/gt min - 最小化为细栏，或恢复窗口
/gt dock - 细栏将游戏顶部的框体下移（开启）或仅覆盖它们（关闭）
/gt export - 将你的地点显示为可分享的文本
/gt import - 从好友的文本导入地点
/gt report - 可粘贴到错误报告中的调试报告
/gthud - 与 /gt hud 相同
/hun - 随机名称（见 面板 > 设置 > 随机名称）

]] .. H .. "HUD 命令" .. E .. [[

/gthud - 开启或关闭 HUD
/gthud on | off
/gthud config - 打开 HUD 设置
/gthud size 800 - HUD 大小（150 到 1400）
/gthud alpha 0.5 - 地图不透明度（0 到 1）
/gthud zoom 3 - 小地图缩放（0 到 5）
/gthud rotate - 随玩家旋转 开 / 关
/gthud ring 150 - 圆环半径（px，0 = 关闭）
/gthud ring2 300 - 第二个圆环
/gthud ringthick 2 - 圆环粗细（1 到 10）
/gthud ringseg 96 - 圆环平滑度（8 到 256）
/gthud ringstyle solid | stripes | dots - 圆环样式
/gthud ringdensity 24 - 圆环周围的条纹或点数（4 到 128）
/gthud ringcolor 1 1 1 0.8 - 红 绿 蓝 不透明度
/gthud ringcolor2 1 1 1 0.8 - 第二个圆环的颜色
/gthud dirs - 罗盘字母 开 / 关
/gthud heading - 朝向显示 开 / 关
/gthud tracking - 追踪按钮 开 / 关
/gthud tracksize 50 - 追踪按钮大小（20 到 80）
/gthud trackpos 0 0 - 当前 HUD 状态下追踪按钮的偏移
/gthud trackmode auto | own | stock - HUD 关闭时的追踪按钮
/gthud arrow - 玩家箭头 开 / 关
/gthud addons - 隐藏小地图插件的皮肤 / 按钮 开 / 关
/gthud scan - 深度扫描小地图插件 开 / 关
/gthud mountfade - 骑乘时隐藏 HUD 开 / 关
/gthud autogather - 随采集追踪自动开启 开 / 关
/gthud restore - 在 /reload 或登录后恢复 HUD 开 / 关
/gthud profile - 列出配置文件；/gthud profile <n> 切换或创建
/gthud profile delete <n> - 删除配置文件（Default 和当前配置文件不能删除）
/gthud status | info | frames | debug - 状态、诊断或调试消息
/gthud reset - 重置当前配置文件
/gthud help - 显示命令帮助]]

GT.helpText.zhCN = T
