# VirtualOR 工程规则

## 1. 开工前先读项目结构

接到任何关于本工程的任务（哪怕只是回答问题），第一步先 Read
[project_structure.md](project_structure.md)，再开始探索代码或动手。
该文档维护着当前代码库的目录布局、模块职责、关键状态机和实体命名约定，
能避免重复探索已经写明的内容。

## 2. push 之后更新项目结构

每次 `git push` 成功之后，如果本次推送的 commit 触及了下面任一项，必须同步更新
[project_structure.md](project_structure.md) 并在同一个分支上追加一个
`docs: sync project_structure` 的 commit（推或不推由用户决定）：

- 新增 / 删除 / 重命名了文件或目录
- 新增 / 删除了类、ViewModel、Service、enum
- 改了状态机、实体命名约定（`CollidableEntities` / `Drawer` / `Anes` 等）
- 改了网络层结构、Codable 模型形态
- 改了关键的数据流（HUD 绑定、ScenarioRuntime 行为等）

更新时保留文档顶部的"最后同步"日期与 commit hash，把它们改成最新值
（`git log -1 --format='%h %s'` 可以拿到当前 HEAD）。

纯改动（注释微调、空格、log 文案）不需要同步。

## 3. 构建命令

visionOS 26.4.1 模拟器 id：`FB652FE1-8226-4191-94BA-B378EE01059C`

```
xcodebuild -project /Users/geding/Documents/VirtualOR/VirtualOR.xcodeproj \
  -scheme VirtualOR \
  -destination 'platform=visionOS Simulator,id=FB652FE1-8226-4191-94BA-B378EE01059C' \
  build 2>&1 | tail -5
```

每次代码改完都跑一遍验证，只看 tail；或直接用 `/build`。

## 4. 关键文件速查

| 文件 | 职责 |
|---|---|
| [VirtualOR/ViewModels/ScenarioRuntime.swift](VirtualOR/ViewModels/ScenarioRuntime.swift) | 状态机：state 切换 / op 执行 / popup / branch 守门 / log |
| [VirtualOR/Models/ScenarioModel.swift](VirtualOR/Models/ScenarioModel.swift) | 后端 JSON 的 Codable struct（Scenario / Monitor / ValueChange 等） |
| [VirtualOR/ViewModels/ORSceneViewModel.swift](VirtualOR/ViewModels/ORSceneViewModel.swift) | 3D 场景 + HUD vitals + drawer 拿药 / pipe / 拿东西 |
| [VirtualOR/Models/ORSceneModel.swift](VirtualOR/Models/ORSceneModel.swift) | 实体命名 enum（`Drawer` / `Anes` / `Suction`）+ `CollidableEntities` + `DrugMap` |
| [VirtualOR/Views/ImmersiveView.swift](VirtualOR/Views/ImmersiveView.swift) | RealityKit 沉浸视图，连 viewModel + runtime + alert |

更深的细节问 [project_structure.md](project_structure.md)
（CLAUDE.md 是路标，project_structure 是地图）。

## 5. Logging 约定

- `os.Logger`，subsystem 固定 `com.app.VirtualOR`
- 关键状态变化用 `.info`，加 `[Tag]` 前缀（`[Tap]` `[Drawer]` `[Hold]` `[State]` 等）
- 内部细节用 `.debug`，意外路径（实体未找到等）用 `.warning`
- 不用 `print`

## 6. ScenarioRuntime 当前 Phase

提需求 / 写代码前先看下当前在哪个 phase，避免重复实现：

- **Phase 1 已交付**：状态切换、operation 触发、绝对值/delta、popup、targetState 跳转、操作日志、branchOperations 守门
- **Phase 2 待做**：state1 退化线性插值、`effect.duration` 临时 boost、`onNoOperation` 600s 超时、tick 循环
- **Phase 3 待做**：`autoVideo` 播放（10s 全屏 → floatWindow）、courseEnd 总结视图
