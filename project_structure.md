# VirtualOR 项目结构文档

> 最后同步：2026-06-14
> 基于 commit：`a309afe docs: sync project_structure + CLAUDE.md to current state`（+ 未提交：实体名集中到 EntityName.swift）
> 该文档反映当前代码库的实际状态，含标准 MVVM 分层目录、ScenarioRuntime 状态机、AudioService 多轨循环、BreathingVideoPlayer 浮窗化、resource.json mock 数据链路，以及 OperationEntityMap 的协议化（POP）实体→操作映射。

---

## 1. 项目概述

**VirtualOR** 是一款基于 Apple Vision Pro 的沉浸式虚拟手术室模拟训练应用。用户在全沉浸式 3D 手术室环境中扮演**麻醉医生**，面对临床危急情况进行麻醉相关器械操作与患者生命体征监测训练。

### 1.1 平台支持

来源：[Package.swift](Packages/RealityKitContent/Package.swift)

| 平台 | 最低版本 |
|------|---------|
| visionOS | 2.0 |
| macOS | 15 |
| iOS | 18 |

### 1.2 核心技术栈

| 框架 | 用途 |
|-----|------|
| SwiftUI | 2D 主菜单 / HUD 文字 attachment |
| RealityKit | 3D 场景渲染、实体管理、手势交互 |
| RealityKit Content (Swift Package) | 3D 资源包（USDZ / Reality Composer Pro） |
| ARKit (`WorldTrackingProvider`) | 头部位姿跟踪（HUD 跟随视线） |
| AVKit | 视频播放（教学视频，目前 URL 未配置） |
| URLSession | 网络通信层 |
| `os.Logger` | 分类日志（subsystem: `com.app.VirtualOR`） |
| Swift 5.9 `@Observable` 宏 | 响应式状态管理（替代 ObservableObject） |

---

## 2. 目录结构

> 工程使用 Xcode **synchronized root group**（`PBXFileSystemSynchronizedRootGroup`），
> 磁盘上的文件夹结构即 Xcode 中的分组，移动/新增文件**不需要手改 pbxproj**。
> 唯一例外：`Info.plist` 因 `INFOPLIST_FILE = $(TARGET_NAME)/Info.plist` 写死，必须留在 `VirtualOR/` 根。

```
VirtualOR/
├── VirtualOR.xcodeproj/                       # Xcode 工程（synchronized groups）
├── CLAUDE.md                                  # 工程规则 + 关键文件速查 + Phase 进度
├── project_structure.md                       # 本文档
├── .claude/
│   ├── settings.local.json                    # 本地权限（不提交）
│   └── commands/
│       ├── build.md                           # /build slash 命令
│       └── sync-structure.md                  # /sync-structure slash 命令
├── Packages/
│   └── RealityKitContent/                     # 3D 资源 SwiftPM 包
│       ├── Package.swift
│       └── Sources/RealityKitContent/
│           ├── RealityKitContent.swift        # Bundle.module 访问入口
│           └── RealityKitContent.rkassets/    # Reality Composer Pro 场景资源
│               ├── Immersive.usda
│               ├── ORScene.usdz               # 主手术室场景
│               ├── SkyDome.usdz
│               └── Ground/
│
└── VirtualOR/                                 # 主应用源码（标准 MVVM 分层）
    ├── Info.plist                             # NSWorldSensingUsageDescription 等（必须留根）
    │
    ├── App/                                   # 应用入口 + 全局状态
    │   ├── VirtualORApp.swift                 # @main 入口（WindowGroup id="main" + ImmersiveSpace）
    │   └── AppModel.swift                     # 全局状态（含视频生命周期）
    │
    ├── Views/                                 # 纯视图层（SwiftUI / RealityView）
    │   ├── ContentView.swift                  # 主菜单 + 2D 窗口视频
    │   ├── ImmersiveView.swift                # 沉浸式 3D 视图 + HUD + 浮窗视频
    │   └── ToggleImmersiveSpaceButton.swift   # 沉浸空间开关
    │
    ├── ViewModels/                            # @Observable 视图模型
    │   ├── ORSceneViewModel.swift             # 场景交互核心 + HUD vitals
    │   ├── ORSceneViewModel+Tools.swift       # DEBUG 调试工具
    │   └── ScenarioRuntime.swift              # 临床状态机 VM（state 切换 / op / popup / log）
    │
    ├── Models/                                # 纯数据 / 领域模型 / 映射
    │   ├── EntityName.swift                   # 3D 实体名唯一注册处（Suction/Drawer/Anes/OperationEntityName/SceneAsset）
    │   ├── ScenarioModel.swift                # 后端 JSON Codable struct
    │   ├── Monitor+Apply.swift                # MonitorChange 应用（absolute / delta）
    │   ├── ORSceneModel.swift                 # 派生分组 CollidableEntities + DrugMap
    │   └── OperationEntityMap.swift           # POP 实体名 → operationId 映射
    │
    ├── Services/                              # 领域服务 / 系统能力封装
    │   ├── Scenario/                          # 剧情数据服务（protocol + Live + Mock）
    │   │   ├── ScenarioServicing.swift        #   protocol：fetchScenario() async throws
    │   │   ├── ScenarioService.swift          #   Live：走 APIService（占位 /placeholder）
    │   │   └── MockScenarioService.swift      #   Mock：读 bundle resource.json
    │   ├── AudioService.swift                 # 多轨循环音 + 总开关
    │   ├── BreathingVideoPlayer.swift         # AVPlayerLooper 无缝循环视频
    │   └── HeadTrackingManager.swift          # 头部位姿跟踪
    │
    ├── Networking/                            # 纯 HTTP 基础设施
    │   ├── APIConfig.swift
    │   ├── APIEndpoint.swift
    │   ├── APIError.swift
    │   └── APIService.swift
    │
    ├── Resources/
    │   ├── resource.json                      # mock 剧情数据（ScenarioService 从 bundle 读取）
    │   ├── Audio/
    │   │   ├── abnormal_breath.m4a            # 呼吸困难循环音
    │   │   └── background_music.m4a           # 背景音乐循环
    │   └── Video/
    │       └── abnormal_breath.mp4            # 呼吸困难视频（10s 后浮窗）
    │
    └── Assets.xcassets/                       # AppIcon / AccentColor
```

> 注：遗留 stub `AVPlayerView.swift` / `AVPlayerViewModel.swift` 已删除（视频功能改用 `BreathingVideoPlayer`）。

---

## 3. 应用架构

### 3.1 模块关系图

```
┌──────────────────────────────────────────────────────────────────┐
│                       VirtualORApp (@main)                        │
├─────────────────────────────┬────────────────────────────────────┤
│   WindowGroup(id:"main")    │       ImmersiveSpace                │
│  ┌──────────────────────┐   │  ┌──────────────────────────────┐  │
│  │      ContentView     │   │  │        ImmersiveView         │  │
│  │  - VideoPlayer 0-10s │   │  │  RealityView + Attachments   │  │
│  │  - ToggleImmSpcBtn   │   │  │  - hudText (vitals + state)  │  │
│  └──────────┬───────────┘   │  │  - breathingVideo (10s 后)   │  │
│             │ environment   │  └──────┬───────────────────────┘  │
│  ┌──────────┴───────────┐   │         │ env (AppModel)            │
│  │      AppModel        │◄──┼─────────┘                           │
│  │ immersiveSpaceState  │   │  ┌──────────────────────────────┐  │
│  │ videoPlayer          │───┼──┤  ORSceneViewModel            │  │
│  │ isVideoFloated       │   │  │  rootEntity / drawer 拿药    │  │
│  │ loadingState         │   │  │  isPipesExpanded             │  │
│  └──────────────────────┘   │  │  holdingItem / heldGroup     │  │
│                              │  │  scenario / weak runtime     │  │
│                              │  └──┬───────────────────────────┘  │
│                              │     │                              │
│                              │  ┌──┴────────────┐                 │
│                              │  │ScenarioRuntime│                 │
│                              │  │ stateId / log │                 │
│                              │  │ branch / popup│                 │
│                              │  └───────────────┘                 │
│                              │  ┌────────────┐ ┌────────────────┐│
│                              │  │AudioService│ │HeadTrackingMgr ││
│                              │  │ multi loop │ │ARKit + WorldTrk││
│                              │  └────────────┘ └────────────────┘│
├─────────────────────────────┴────────────────────────────────────┤
│                       Services / Networking Layer                 │
│  ORSceneViewModel → scenarioService.fetchScenario()  (注入)        │
│   Mock → Bundle resource.json → JSONDecoder → Scenario            │
│   Live → APIService.request → Scenario（占位 /placeholder）        │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 设计模式

- **MVVM + 分层目录**：`App/`（入口+全局）、`Views/`（纯视图）、`ViewModels/`（@Observable VM）、`Models/`（数据/领域）、`Services/`（领域服务+系统封装）、`Networking/`（HTTP 基础件）。
- **`AppModel` 管全局**；`ORSceneViewModel` 管 3D 场景与 HUD vitals；`ScenarioRuntime` 管临床状态机；视图层（`ContentView` / `ImmersiveView`）保持薄。
- **`@Observable` + `@MainActor`**：所有 ViewModel / Service 用 `@Observable` 宏，跑在 `@MainActor`。
- **Environment 注入**：`AppModel` 通过 `.environment(appModel)` 注入；视图通过 `@Environment(AppModel.self)` 取。
- **Service 类**：`AudioService` / `BreathingVideoPlayer` / `ScenarioService` / `HeadTrackingManager` 各管一个独立领域。
- **Weak 注入**：`ORSceneViewModel.runtime` 是 `weak var`（避免环），由 `ImmersiveView` 在 start 时回填。
- **Swift Package 化资源**：3D 资源独立成 `RealityKitContent` 包；音视频 / mock JSON 放主 bundle 的 `Resources/`。
- **POP 映射**：`OperationEntityMap` 用 `OperationTrigger` 协议把"点击实体 → operationId"统一抽象，可扩展（见 §4.16）。
- **Sendable 安全**：`APIService` 标记 `final … Sendable`，泛型 `request<T: Decodable & Sendable>`。

---

## 4. 文件级详解

### 4.1 [VirtualORApp.swift](VirtualOR/App/VirtualORApp.swift) — 应用入口

定义两个 Scene：

1. **`WindowGroup(id: "main")`**：渲染 `ContentView`（含 `.environment(appModel)`）。`id` 是 `dismissWindow` / `openWindow` 操作所需。
2. **`ImmersiveSpace`**（id `"ImmersiveSpace"`，`.full` 沉浸式）：
   - `onAppear`：将 `appModel.immersiveSpaceState` 置 `.open`。
   - `onDisappear`：置 `.closed`。

> 旧的 `isPlaying ? AVPlayerView : ContentView` 遗留分支与 `avPlayerViewModel` 已随 AVPlayer stub 删除清理。

### 4.2 [AppModel.swift](VirtualOR/App/AppModel.swift) — 全局状态

| 属性 | 类型 | 说明 |
|------|------|------|
| `immersiveSpaceID` | `String` | `"ImmersiveSpace"` |
| `immersiveSpaceState` | `ImmersiveSpaceState` | `.closed` / `.inTransition` / `.open` |
| `loadingState` | `LoadingState` | `.idle` / `.loading` / `.loaded` / `.failed(Error)` |
| `videoPlayer` | `BreathingVideoPlayer` | 共享视频播放器实例 |
| `isVideoFloated` | `Bool` | `false`：视频在 ContentView 2D 窗口；`true`：在 ImmersiveView 右下角浮窗 |

**视频生命周期方法**：

| 方法 | 行为 |
|------|------|
| `startVideoOverlay()` | 启动 `videoPlayer.start("abnormal_breath")`；spawn 一个 10s 倒计时 Task，倒计时结束置 `isVideoFloated = true` |
| `stopVideoOverlay()` | 取消计时器 + 停 player + `isVideoFloated = false` |

`fetchInitialData()` 仍是占位（直接置 `.loaded`）。

### 4.3 [ContentView.swift](VirtualOR/Views/ContentView.swift) — 主菜单 + 2D 窗口视频

按 `loadingState` 分支渲染。`.loaded` 时的 VStack 增加了视频与按钮的条件渲染：

| 条件 | 显示 |
|------|------|
| `immersiveSpaceState == .open && !isVideoFloated` | 480×320 的 `VideoPlayer(player: appModel.videoPlayer.player)` |
| `immersiveSpaceState != .open` | `ToggleImmersiveSpaceButton`（沉浸开了之后就藏起来） |

`.task { await appModel.fetchInitialData() }` 不变。

### 4.4 [ImmersiveView.swift](VirtualOR/Views/ImmersiveView.swift) — 沉浸式视图

`RealityView` + `attachments`，承载 3D 场景、HUD 文字、右下角浮窗视频，以及 popup alert。

**注入的 env / state**：

| 名称 | 类型 | 用途 |
|------|------|------|
| `appModel` | `AppModel` (env) | 访问共享 `videoPlayer` / `isVideoFloated` |
| `dismissWindow` / `openWindow` | env values | 浮窗化时关 main window；退场时重开 |
| `viewModel` | `ORSceneViewModel` (state) | 3D 场景与 HUD vitals |
| `runtime` | `ScenarioRuntime` (state) | 临床状态机 |
| `audioService` | `AudioService` (state) | 双轨循环音 |
| `hudEntity` / `videoEntity` | `Entity` (state) | 跟随头部的 HUD 容器 |

**初始化（`make` 闭包）**：
1. 加载场景、加载 scenario，回填 `viewModel.runtime = runtime` 并 `runtime.start(...)`。
2. `hudEntity` 加入 content；`hudText` attachment 定位 `(-0.40, -0.22, -0.5)`（左下）。
3. `videoEntity` 挂为 `hudEntity` 子节点，定位 `(0.42, -0.18, -0.5)`（右下）；`breathingVideo` attachment 仅在 `appModel.isVideoFloated == true` 时渲染 `VideoPlayer`。

**两个 Attachment**：

| id | 内容 | 大小 |
|---|---|---|
| `hudText` | State / Hold / NIBP / SPO2 / HR / RR / 体温 七行文字 | 自适应 |
| `breathingVideo` | `VideoPlayer(player: appModel.videoPlayer.player)`（条件渲染） | 220×145 |

**手势 / Alert**：

- `.gesture(TapGesture().targetedToAnyEntity()...)` → `viewModel.handleTapGesture(...)`。
- `.alert(...)` 绑定 `runtime.activePopup` —— popup 的 type 决定标题，OK 调 `runtime.dismissPopup()`。

**生命周期**：

| 钩子 | 动作 |
|------|------|
| `.task`（主） | `audioService.startLoop("background_music", volume: 0.5)`、`audioService.startLoop("abnormal_breath")`、`appModel.startVideoOverlay()`；启动 head tracking 60FPS 循环 |
| `.onChange(of: isVideoFloated)` | 变 true 时 `dismissWindow(id: "main")` |
| `.onDisappear` | `audioService.stopAll()` + `appModel.stopVideoOverlay()` + `openWindow(id: "main")`（避免 app 退） |

### 4.5 [HeadTrackingManager.swift](VirtualOR/Services/HeadTrackingManager.swift) — 头部跟踪

封装 `ARKitSession + WorldTrackingProvider`：

| 方法 / 属性 | 功能 |
|------------|------|
| `start()` | 异步启动 ARKit session，运行 `WorldTrackingProvider` |
| `isRunning` | 只读，会话是否已启动 |
| `queryDeviceAnchor() -> simd_float4x4?` | 在当前媒体时间戳下查询设备锚点的 `originFromAnchorTransform` |

需要 `Info.plist` 中的 `NSWorldSensingUsageDescription` 授权（已配置）。

### 4.6 实体名与领域模型

> **实体名集中化**：所有 3D 实体名枚举集中在 [Models/EntityName.swift](VirtualOR/Models/EntityName.swift)
> —— `Suction` / `Drawer` / `Anes` / `OperationEntityName` / `SceneAsset`。改 Reality Composer Pro
> 里的实体名只动这一个文件，全工程其它地方都通过 rawValue 引用，不出现裸字符串
> （`handleTapGesture` 的吸引器分支已用 `Suction(rawValue:)`、场景加载用 `SceneAsset.orScene`）。
>
> [Models/ORSceneModel.swift](VirtualOR/Models/ORSceneModel.swift) 现在只放**派生**的实体分组
> `CollidableEntities` 与抽屉→药品映射 `DrugMap`（都引用上面的枚举）。

下面列出各枚举内容（定义位于 EntityName.swift）。

#### 4.6.1 `enum Suction`（吸引器）

| Case | rawValue | 说明 |
|------|----------|------|
| `pipeRollUpTop` | `pipe_1` | 展开 - 上管 |
| `pipeRollUpBottom` | `pipe_2` | 展开 - 下管 |
| `pipeConnection` | `pipe_connection` | 展开 - 连接件 |
| `bentPipe` | `bent_pipe` | 卷起状态 |

#### 4.6.2 `enum Drawer`（抽屉与器械）

5 个抽屉本体，rawValue 命名不统一（历史原因）：`drawer_1` / `drawer_2` / `drawer_003` / `drawer_004` / `drawer_005`。`handleTapGesture` 以 `CollidableEntities.drawer.contains(name)` 判断。

抽屉内器械按类别枚举（数量与 rawValue 前缀）：

| 类别 | 数量 | rawValue 前缀 |
|------|------|---------------|
| 面罩部件 (`maskPart1~4`) | 4 | `face_shield_drawer_00x` |
| 听诊器 (`stethoscope1~7`) | 7 | `stethoscope_00x` |
| 喉镜 (`laryngoscope1~4`) | 4 | `laryngoscope_00x` |
| 口咽管 (`oropTube1~2`) | 2 | `orop_tube_00x` |
| 呼吸气球 (`respBalloon1~5`) | 5 | `balloom_00x` |
| 喉罩 (`laryngealMask1~4`) | 4 | `mask_00x` |
| 喉管 (`laryngealDuct1~5`) | 5 | `duct_00x` |

#### 4.6.3 `enum Anes`（麻醉监护仪）

| Case | rawValue | 说明 |
|------|----------|------|
| `autoButton` / `manualButton` | `monitor_knob_001` / `monitor_knob_005` | 自动/手动模式按钮 |
| `manualTrigger` | `monitor_knob_trigger` | 手动触发器 |
| `mainScreen` / `submainScreen` | `monitor_screen` / `monitor_subscreen` | 主/副屏幕 |
| `masked` | `monitor_face_shield_mask` | 已戴面罩状态 |
| `unmaskedPipe` | `monitor_SPO_003` | 未戴面罩 - SPO2 管路 |
| `unmaskedPart1~4` | `face_shield_monitor_00x` | 未戴面罩 - 面罩部件 |

> `Anes.autoButton.rawValue`（`monitor_knob_001`）被 `OperationEntityMap` 复用为 increaseOxygen 的触发实体。

#### 4.6.4 `enum CollidableEntities`（实体分组工具）

静态命名空间，承载交互所需的"实体组"：

```swift
static var suctionExpanded   // 吸引器展开态需要的实体名数组
static var suctionCollapsed  // 吸引器折叠态
static var drawer            // 5 个抽屉
static var anesAdjustButton  // 监护仪可调按钮
static var mainScreen / submainScreen
static var anesMasked / anesUnmasked
```

**`InstrumentGroup` 结构体 + `instrumentGroups` 数组**：定义 6 大类可拾取器械（Stethoscope / Laryngoscope / Oropharyngeal Tube / Breathing Balloon / Laryngeal Mask / Laryngeal Duct），每组带 `displayName` 和组内所有部件 `entityNames`。

派生属性：

- `pickableInstruments: [String]` — 所有可拾取实体扁平列表（用于批量生成碰撞体）。
- `entityToGroup: [String: InstrumentGroup]` — 反向映射，O(1) 查找点击实体所属组。

#### 4.6.5 `enum DrugMap`（抽屉 → 药品）

点对应抽屉即"拿起"该药品（HUD `holdingItem` 切换），药品没有 3D 模型：

| Drawer | 药品 |
|---|---|
| `drawer_2` | Propofol 丙泊酚 |
| `drawer_003` | Salbutamol 沙丁胺醇 |
| `drawer_004` | Flumazenil/Naloxone 氟马西尼/纳洛酮 |
| `drawer_005` | Muscle Relaxant 肌松药 |

`drawer_1` 不映射任何药品（也无操作）。这 4 个抽屉的药品语义与 `OperationEntityMap` 的操作一一对应（见 §4.16）。

### 4.7 [ORSceneViewModel.swift](VirtualOR/ViewModels/ORSceneViewModel.swift) — 场景交互核心

#### 状态属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `rootEntity` | `Entity?` | 加载后的 ORScene 根 |
| `loadError` | `Error?` | 加载失败原因 |
| `isPipesExpanded` | `Bool` | 当前管道是否处于展开态 |
| `holdingItem` | `String = "nothing"` | 当前手持的显示名（HUD 绑定，可能是器械或药品） |
| `currentHeldGroup` | `InstrumentGroup?` | 当前正被"持有"（隐藏中）的器械组；持药品时为 nil |
| `nibpSystolic / nibpDiastolic / spo2 / hr / rr / temperature` | Int / Double | 6 个生命体征（HUD 绑定） |
| `scenario` | `Scenario?` | 加载到的剧情数据 |
| `runtime` | `weak ScenarioRuntime?` | 状态机引用（`@ObservationIgnored`，由 ImmersiveView 回填） |

#### 关键方法

| 方法 | 行为 |
|------|------|
| `loadRoomIfNeeded()` | 幂等异步加载 `ORScene`（来自 `realityKitContentBundle`） |
| `loadScenarioIfNeeded() async -> Scenario?` | 幂等加载 mock scenario，把 `initialState.monitor` 应用到 HUD vital；返回剧情对象给调用方 |
| `applyMonitor(_ monitor: Monitor)` | Monitor → 6 个 vital 属性的唯一入口；状态机 + 拿药效果都走这里 |
| `prepareForRoom()` | 生成碰撞体 + 初始化管道状态，DEBUG 下打印实体树 |
| `handleTapGesture(entity:)` | 实体名分发：`bent_pipe` → expand；`pipe_*` → collapse；**drawer 命中 DrugMap → 直接 `pickUpDrug`（不再 3D 滑出抽屉）**；`OperationEntityMap.operationId(for:)` 命中 → `runtime?.perform(opId)`；`pickableInstruments` → `pickUpInstrument`；其它 → warning |
| `pickUpInstrument(_:)` | 通过 `entityToGroup` 找组；显示旧组、隐藏新组、更新 holdingItem |
| `pickUpDrug(displayName:)` | 显示旧器械组（如有）→ `currentHeldGroup = nil` → `holdingItem = displayName` |
| `expandPipes / collapsePipes` | `isPipesExpanded` 守卫 + 切换实体可见性 |
| `ancestorChain(of:)` | 返回实体的祖先链字符串（最多 5 层），调试 [Tap] 命中用 |

> **抽屉行为变更**：原 `toggleDrawer / openDrawer / closeDrawer / moveEntity / Axis` 以及 `drawerStates` / `drawerOpenDistance` 已删除。点击 drawer 不再做 Z 轴 3D 滑出，而是命中 `DrugMap` 时直接 `pickUpDrug`（左下 HUD 显示药品 + viewModel 记录），随后 `OperationEntityMap` 命中则触发对应临床操作。

#### 工具方法（`extension`，`private`）

- `makeEntitiesCollidable(_ names:)` — 为命名实体添加 `CollisionComponent`（`generateBox(size: .one)`）+ `InputTargetComponent`，使其可被点击。
- `hideEntities / showEntities` — 通过 `entity.isEnabled` 切换可见性。

### 4.8 [ORSceneViewModel+Tools.swift](VirtualOR/ViewModels/ORSceneViewModel%2BTools.swift) — 调试工具

| 方法 | 编译条件 | 功能 |
|------|----------|------|
| `printWorldPosition(of:)` | 始终 | 打印实体世界坐标 |
| `printAllEntities()` | `#if DEBUG` | 树形打印整个场景实体层级 |
| `printAllEntityNames()` | `#if DEBUG` | 列出全部实体名与总数 |

### 4.9 [ToggleImmersiveSpaceButton.swift](VirtualOR/Views/ToggleImmersiveSpaceButton.swift) — 沉浸空间开关

封装 `openImmersiveSpace` / `dismissImmersiveSpace` 两个 SwiftUI Environment 值的切换：

- 进入/退出过渡期间，`immersiveSpaceState` 置 `.inTransition`，按钮自动 `disabled`。
- 关闭时**不**在按钮逻辑里设置 `.closed`，而是统一交给 `ImmersiveView.onDisappear`，避免多路径下状态不一致（代码注释明确说明此约定）。
- `openImmersiveSpace` 失败时（`.userCancelled` / `.error`）回滚为 `.closed`。

### 4.10 [AudioService.swift](VirtualOR/Services/AudioService.swift) — 多轨循环音

`@MainActor @Observable`，包装 `AVAudioPlayer`，支持多个命名轨道并发循环。

| 公开 API | 说明 |
|---|---|
| `var isSoundEnabled: Bool` | 总开关，set 时 didSet 自动 pause/resume 所有已注册的循环 |
| `var registeredLoops: [String]` | 已注册的轨道名（调试用） |
| `func toggleSound()` | `isSoundEnabled.toggle()` 便捷入口 |
| `func startLoop(named:fileExtension:volume:)` | 幂等注册并按当前 isSoundEnabled 启动；找不到文件打 warning 不抛 |
| `func stop(named:)` | 停并卸载单个 |
| `func stopAll()` | 退场时全停 |

ImmersiveView `.task` 启两条：`background_music`（volume 0.5）+ `abnormal_breath`（默认 1.0）。

### 4.11 [BreathingVideoPlayer.swift](VirtualOR/Services/BreathingVideoPlayer.swift) — 无缝循环视频

`@MainActor @Observable`，用 `AVQueuePlayer + AVPlayerLooper` 做真正无 gap 循环。

| 公开 API | 说明 |
|---|---|
| `let player: AVQueuePlayer` | 暴露给 SwiftUI `VideoPlayer(player:)` 用 |
| `var isReady: Bool` | 是否已 prepare |
| `func start(named:fileExtension:)` | 默认 `.mp4`；幂等；默认 `isMuted = true`（避开和 audio loop 重复发声）|
| `func stop()` | 暂停 + 卸载 |

实例由 `AppModel` 持有，ContentView 与 ImmersiveView 共享渲染。

### 4.12 [Models/ScenarioModel.swift](VirtualOR/Models/ScenarioModel.swift) — 后端 JSON Codable

与后端 JSON 一一对应的纯数据 struct：

| 类型 | 角色 |
|---|---|
| `Scenario` | 顶层（version / title / totalDuration / initialState / states / endState） |
| `InitialState` | 初始 10s 状态 |
| `ScenarioState` | state1/2/3/4 等节点（含 autoVideo / monitor / onNoOperation / operations / targetState）|
| `StateMonitor` | enum：`.flat(Monitor)` / `.degradable(initial, degradeTo, degradeDuration)` |
| `Monitor` / `NIBP` | 6 个生命体征基础值 |
| `ScenarioOperation` | 操作（含 effect / popup / log / targetState / branchOperations）|
| `OperationEffect` / `MonitorChange` / `NIBPChange` | 效果应用 |
| `ValueChange` | enum：`.absolute(Double)` / `.delta("+10")` —— 自定义 init(from:) 支持双形态 |
| `Popup` | type ("success"/"error") + message |
| `EndState` | 课程结束 |

### 4.13 [ViewModels/ScenarioRuntime.swift](VirtualOR/ViewModels/ScenarioRuntime.swift) — 状态机 VM

`@MainActor @Observable`。Phase 1 已交付：

| 公开 API / 状态 | 说明 |
|---|---|
| `currentStateId / currentStateName` | 当前状态 |
| `activePopup: Popup?` | 弹窗，绑定 SwiftUI .alert |
| `pendingBranchParent: String?` | 处于 branch 选择阶段时的父 op id（三选一流程的"记录"靠这个守门）|
| `log: [OperationLogEntry]` | 操作日志（opId / timestamp / stateId）|
| `isCourseEnded: Bool` | 进入 endState 后置 true，拒绝后续 perform |
| `func start(scene:scenario:)` | 入口；进 first state |
| `func perform(operationId:)` | 总分发；branch 守门 + popup 阻塞 + 日志 |
| `func dismissPopup()` | popup 关闭后若有 `pendingTargetState` 再 transition |
| 11 个 `triggerXxx()` extension | 给每个 operation 一个具名入口（jawThrust / propofolIV / muscleRelaxant 等），底层都走 `perform(operationId:)` |

应用 effect 时 `currentMonitor = currentMonitor.applying(change)` → `scene?.applyMonitor(currentMonitor)`，HUD 自动刷新。

**branch 三选一守门机制**：点 `muscleRelaxant` 后 `pendingBranchParent = "muscleRelaxant"`；此后 `resolveOperation` 只在该父操作的 `branchOperations` 里解析。用户点击 branch 触发实体（见 §4.16）→ 对应 opId → perform → 走 state3/state4/end。无需额外跟踪状态，分支选择即由 `pendingBranchParent` + `log` 记录。

### 4.14 [Models/Monitor+Apply.swift](VirtualOR/Models/Monitor%2BApply.swift) — MonitorChange 应用

`Monitor.applying(_ change: MonitorChange) -> Monitor`：absolute 覆盖、delta（"+10"/"-5"）叠加；nil 字段保持不变。`ValueChange.resolve(against:)` 解析双形态。Int 字段 round 取整，Double（temperature）保留小数。

### 4.15 [Models/OperationEntityMap.swift](VirtualOR/Models/OperationEntityMap.swift) — POP 实体名 → operationId

> §4.16 是同一文件的展开说明，保留本条作为索引。

### 4.16 OperationEntityMap 的 POP 结构

[OperationEntityMap.swift](VirtualOR/Models/OperationEntityMap.swift) 用协议化（POP）把"点击 3D 实体 → 触发剧情 operation"统一抽象，替代了原来的空字典占位：

| 类型 | 角色 |
|---|---|
| `protocol OperationTrigger` | `{ entityName; operationId }`——一个实体→操作绑定 |
| `enum StateOneOperationTrigger` | state1 的 6 个主操作绑定（遵守 `OperationTrigger`，`CaseIterable`）|
| `enum MuscleRelaxantBranchTrigger` | muscleRelaxant 后 2 个 touch 分支（`intubation` / `onlyBag`）|
| `enum OperationEntityMap` | `triggers: [any OperationTrigger]` 汇总全部绑定；`operationId(for:) -> String?` 反查 |

当前映射（drawer 部分与 `DrugMap` 药品语义对齐）：

| 实体 | operationId | 备注 |
|---|---|---|
| `steve_001` | jawThrust | 人体模型，托下颌 |
| `monitor_knob_001` | increaseOxygen | 复用 `Anes.autoButton` |
| `drawer_2` | propofolIV | Propofol |
| `drawer_003` | noEffectDrugs | Salbutamol |
| `drawer_004` | antagonistDrugs | 氟马西尼/纳洛酮 |
| `drawer_005` | muscleRelaxant | 肌松药（branch 父操作）|
| `TODO_intubation` | intubationAfterRelaxant | 占位，待补真实实体名 → end |
| `TODO_bag_squeeze` | onlyBagAfterRelaxant | 占位，待补真实实体名 → state4 |

`handleTapGesture` 在 default 分支调 `OperationEntityMap.operationId(for: name)`，命中就 `runtime?.perform(opId)`。接入新操作只需新增一个遵守 `OperationTrigger` 的类型并并入 `triggers`，路由逻辑零改动。

**未映射**：`maskBagVentilation` / `directIntubation`（缺实体）；`noActionAfterRelaxant`（肌松后不作为超时，无点击实体，属 Phase 2 `onNoOperation`）。

---

## 5. 网络层与数据服务

### 5.1 数据流

```
APIConfig.baseURL ──┐
                    ▼
              APIEndpoint.urlRequest()  ──► APIService.request<T>()
                                                   │
                                                   ▼
                                             APIError

MockScenarioService.fetchScenario()  ──► Bundle resource.json ──► Scenario
ScenarioService.fetchScenario()      ──► APIService.request   ──► Scenario（占位）
```

### 5.2 [APIConfig.swift](VirtualOR/Networking/APIConfig.swift)

```swift
#if DEBUG  → "https://api-dev.example.com/v1"
#else      → "https://api.example.com/v1"
timeoutInterval = 30
```

⚠️ 占位 URL，部署前需替换。

### 5.3 [APIEndpoint.swift](VirtualOR/Networking/APIEndpoint.swift)

- `HTTPMethod` 枚举：GET / POST / PUT / DELETE。
- `APIEndpoint` 字段：`path`、`method`、`headers`、`queryItems`、`body: Encodable?`。
- `urlRequest()`：组装 `URLComponents`、序列化 body、统一 `Content-Type: application/json`。
- 文件内私有结构 `AnyEncodable`：以闭包方式擦除 `Encodable` 类型，规避 Swift 中 `Encodable` 不能直接作为存储字段的限制。

### 5.4 [APIService.swift](VirtualOR/Networking/APIService.swift)

- `final class APIService: Sendable`，单例 `shared`。
- `URLSession` 自定义 timeout，`JSONDecoder` 配 `convertFromSnakeCase` + `iso8601`。
- 两个重载：
  - `request<T: Decodable & Sendable>(_:) async throws -> T`
  - `request(_:) async throws`（仅校验状态码）
- 全流程接入 `os.Logger`（subsystem `com.app.VirtualOR`，category `APIService`）。
- 状态码非 2xx 抛 `.httpError(statusCode:data:)`；解码失败抛 `.decodingError`；连接失败抛 `.networkError`。

### 5.5 [APIError.swift](VirtualOR/Networking/APIError.swift)

`LocalizedError`，5 个 case：`invalidURL` / `invalidResponse` / `httpError(statusCode, data)` / `decodingError(Error)` / `networkError(Error)`。

### 5.6 [Services/Scenario/](VirtualOR/Services/Scenario) — 剧情数据服务（protocol + Live + Mock）

剧情数据服务（已从 `Networking/` 移到 `Services/Scenario/`，属领域数据访问层）。协议化后 Live 与 Mock 共享同一接口、统一方法名 `fetchScenario()`：

| 文件 | 角色 |
|---|---|
| [ScenarioServicing.swift](VirtualOR/Services/Scenario/ScenarioServicing.swift) | `protocol ScenarioServicing: Sendable { func fetchScenario() async throws -> Scenario }` |
| [ScenarioService.swift](VirtualOR/Services/Scenario/ScenarioService.swift) | Live：走 `APIService.request`，path 占位 `"/placeholder"`，待后端 ready |
| [MockScenarioService.swift](VirtualOR/Services/Scenario/MockScenarioService.swift) | Mock：从主 bundle 的 [resource.json](VirtualOR/Resources/resource.json) 读取并解码；找不到抛 `APIError.invalidURL` |

> 原先内嵌的硬编码 `scenarioJSON` 字符串已删除，改为从 `Resources/resource.json` 加载（synchronized group 自动进 Copy Bundle Resources）。

**依赖注入**：`ORSceneViewModel(scenarioService: ScenarioServicing = MockScenarioService())`，`loadScenarioIfNeeded()` 调 `scenarioService.fetchScenario()`。后端 API ready 后构造时传 `ScenarioService()` 即可，调用点与 VM 内部零改动。

---

## 6. 数据流 / 关键场景

### 6.1 启动流程

```
App 启动
  ↓
ContentView 显示 → .task { fetchInitialData() }
  ↓
loadingState: .idle → .loading → .loaded   (当前是空操作占位)
  ↓
显示中文说明 + ToggleImmersiveSpaceButton
  ↓
用户点 Show → openImmersiveSpace → immersiveSpaceState .closed → .inTransition → .open
  ↓
ImmersiveView 加载（make 闭包）：
  ├ loadRoomIfNeeded()                    异步加载 ORScene.usdz
  ├ loadScenarioIfNeeded()                 scenarioService.fetchScenario（Mock 读 resource.json），初始 monitor 应用到 HUD
  │   └ runtime.start(scene:scenario:)     transition(to: state1)，HUD 切到 state1.initial
  ├ prepareForRoom()                       generateAllCollisionShapes + initiatePipeStatus
  ├ hudEntity 加 hudText attachment       (-0.40, -0.22, -0.5)
  └ videoEntity (子节点) 在 (0.42, -0.18, -0.5)；breathingVideo attachment 条件渲染
  ↓
.task：
  ├ audioService.startLoop("background_music", volume: 0.5)
  ├ audioService.startLoop("abnormal_breath")
  ├ appModel.startVideoOverlay() → videoPlayer.start("abnormal_breath")
  │                              + 10s Task → 倒计时结束置 isVideoFloated = true
  └ HeadTrackingManager.start + 60 FPS HUD 跟随循环
  ↓
同时 ContentView (2D 窗口):
  ├ 0–10s: 渲染 480×320 VideoPlayer，按钮已隐藏（state == .open）
  └ 10s 后: VideoPlayer 条件失败不渲染；ImmersiveView .onChange → dismissWindow("main")
  ↓
浮窗化后 ImmersiveView 右下角 220×145 视频继续循环
```

### 6.2 交互流程

```
TapGesture 点击 3D 实体
  ↓
viewModel.handleTapGesture(entity:)         [Tap] log: hit + ancestor chain
  ├ bent_pipe             → expandPipes   (守卫:!isPipesExpanded)
  ├ pipe_1/2/connection   → collapsePipes (守卫: isPipesExpanded)
  ├ default →
  │   ├ drawer 命中 DrugMap → pickUpDrug(displayName)   (不再 3D 滑出抽屉)
  │   ├ OperationEntityMap.operationId(for:name)
  │   │     → runtime?.perform(operationId:)
  │   │         ├ branch 守门：pendingBranchParent != nil 时只接 branch 子项
  │   │         ├ effect.monitorChange → currentMonitor.applying → scene.applyMonitor → HUD 刷
  │   │         ├ branchOperations? → pendingBranchParent = op.id（等用户点 branch 触发实体）
  │   │         ├ popup? → activePopup（SwiftUI alert）；pendingTargetState 暂存
  │   │         ├ targetState? → transition(to:)，新 state.monitor 应用到 HUD
  │   │         └ log.append OperationLogEntry
  │   └ pickableInstruments → pickUpInstrument（显示旧组、隐藏新组、改 holdingItem）
  └ 其它 → [Tap] no handler matched (warning)
```

> drawer_2~005 同时命中 DrugMap 与 OperationEntityMap：先 `pickUpDrug`（HUD 显示药品），再 `runtime.perform` 对应操作。

### 6.3 退场流程

```
用户按数字表冠 / dismissImmersiveSpace
  ↓
ImmersiveView .onDisappear:
  ├ audioService.stopAll()           两条循环音停
  ├ appModel.stopVideoOverlay()      取消 10s 计时 + 停 video + isVideoFloated=false
  └ openWindow(id:"main")            重开 2D 窗口（避免无可见 scene 时 app 退出）
  ↓
ImmersiveSpace.onDisappear → immersiveSpaceState = .closed
  ↓
ContentView 重新显示按钮（state != .open 触发条件）
```

---

## 7. 当前状态盘点 / 已知问题

### 7.1 模块完成度

| 模块 | 状态 | 备注 |
|------|------|------|
| 3D 场景加载 | ✅ | `ORScene.usdz`（之前 LFS 已停用） |
| 抽屉拿药 | ✅ | 点 drawer 命中 DrugMap → 直接 pickUpDrug（不再 3D 滑出） |
| 吸引器展开/折叠 | ✅ | `isPipesExpanded` 状态机 + 幂等守卫 |
| 器械拾取 | ✅ | 单组持有，切换时自动复位（含药品互斥） |
| 头部跟踪 HUD | ✅ | 60 FPS 跟随，左下视野 |
| mock 数据链路 | ✅ | resource.json → MockScenarioService.fetchScenario → ViewModel（注入）|
| 实体→操作映射 (POP) | ✅ | OperationTrigger 协议 + 注册表；6 主操作已接，2 branch 占位 |
| ScenarioRuntime Phase 1 | ✅ | state 切换、绝对值/delta、popup、targetState、log、branch 守门 |
| ScenarioRuntime Phase 2 | ❌ | state1 退化插值、effect.duration boost、onNoOperation 超时、tick 循环 |
| ScenarioRuntime Phase 3 | ⚠️ | autoVideo 已实现（10s → 浮窗），courseEnd 总结视图未做 |
| 音频循环 | ✅ | AudioService 多轨 + toggleSound |
| 视频循环 + 浮窗化 | ✅ | BreathingVideoPlayer + AppModel.startVideoOverlay |
| 麻醉监护仪按钮交互 | ⚠️ | `monitor_knob_001` 已接 increaseOxygen；其余 `Anes` 按钮未处理 |
| 面罩佩戴/摘除 | ❌ | `masked` / `unmasked` 已定义，无交互逻辑 |
| 监护仪屏幕生命体征显示 | ❌ | 当前只通过 HUD 文字显示，未投影到 3D 屏幕 |
| 沉浸内 3D 退出按钮 | ❌ | 浮窗化后 2D 窗口被 dismiss，目前只能数字表冠退出 |
| 真实后端接入 | ⚠️ | `ScenarioService.fetchScenario` 路径占位；`fetchInitialData` 占位 |

### 7.2 待确认 / 历史遗留

1. **`generateAllCollisionShapes` 中的占位 `ShapeResource`**
   所有可点击实体被赋予 `generateBox(size: .one)` 的 1×1×1 米碰撞盒，可能与实际几何不匹配（命中区域过大）。`loadRoomIfNeeded` 已调用过 `generateCollisionShapes(recursive: true)`，强制覆盖是否必要值得复审。

2. **APIConfig 的占位 URL** — 上线前必须替换。`ScenarioService.fetchScenario` 的 `/placeholder` path 同样待定。

3. **OperationEntityMap 的占位实体名**
   branch 两个 touch 操作用 `TODO_intubation` / `TODO_bag_squeeze` 占位，资源里有真实实体后只改 `OperationEntityName`。仍缺实体的主操作：`maskBagVentilation`、`directIntubation`。

4. **Drawer 枚举 rawValue 命名不统一**
   `drawer_1` / `drawer_2` / `drawer_003` / `drawer_004` / `drawer_005` 混用一/三位数字，DrugMap 与 OperationEntityMap 均按 rawValue 引用，改名需同步三处。

5. **沉浸里没有退出按钮**
   视频浮窗化后 `dismissWindow("main")` 把 2D 窗口连同 Hide 按钮都关了；用户只能数字表冠退。如果要做内置退出，可在 HUD attachment 里加一个 SwiftUI Button 调 `dismissImmersiveSpace`，或加一个 3D 按钮 entity。
