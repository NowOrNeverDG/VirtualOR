# VirtualOR 项目结构分析

> 文档生成日期：2026-05-02
> 基于 commit：`62ae37e I can pick up instrument and display text about what I hold`
> 该文档反映当前代码库的实际状态，与历史的 [ProjectStructure.md](ProjectStructure.md) 存在差异（详见末尾"与旧版文档差异"小节）。

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

```
VirtualOR/
├── VirtualOR.xcodeproj/                       # Xcode 工程
├── Packages/
│   └── RealityKitContent/                     # 3D 资源 SwiftPM 包
│       ├── Package.swift
│       └── Sources/RealityKitContent/
│           ├── RealityKitContent.swift        # Bundle.module 访问入口
│           └── RealityKitContent.rkassets/    # Reality Composer Pro 场景资源
│               ├── Immersive.usda
│               ├── ORScene.usdz               # 主手术室场景（Git LFS）
│               ├── SkyDome.usdz
│               └── Ground/
│
└── VirtualOR/                                 # 主应用源码
    ├── Info.plist                             # NSWorldSensingUsageDescription 等
    ├── VirtualORApp.swift                     # @main 入口
    ├── AppModel.swift                         # 全局状态
    ├── ContentView.swift                      # 主菜单
    ├── ImmersiveView.swift                    # 沉浸式 3D 视图 + HUD
    ├── ToggleImmersiveSpaceButton.swift       # 沉浸空间开关
    ├── HeadTrackingManager.swift              # 头部位姿跟踪
    ├── AVPlayerView.swift                     # 视频播放视图（UIVCRepresentable）
    ├── AVPlayerViewModel.swift                # 视频播放逻辑
    │
    ├── ORSceneModel/
    │   └── ORSceneModel.swift                 # 实体枚举 + 器械分组定义
    │
    ├── ORSceneViewModel/
    │   ├── ORSceneViewModel.swift             # 场景交互核心
    │   └── ORSceneViewModel+Tools.swift       # DEBUG 调试工具
    │
    ├── Networking/
    │   ├── APIConfig.swift
    │   ├── APIEndpoint.swift
    │   ├── APIService.swift
    │   └── APIError.swift
    │
    └── Assets.xcassets/                       # AppIcon / AccentColor
```

---

## 3. 应用架构

### 3.1 模块关系图

```
┌──────────────────────────────────────────────────────────────────┐
│                          VirtualORApp (@main)                     │
├──────────────────────────────┬───────────────────────────────────┤
│         WindowGroup           │         ImmersiveSpace             │
│  ┌──────────────────────┐     │  ┌─────────────────────────────┐  │
│  │ avPlayerVM.isPlaying │     │  │       ImmersiveView         │  │
│  │   ? AVPlayerView     │     │  │  ┌────────┐  ┌──────────┐   │  │
│  │   : ContentView      │     │  │  │RealityV│  │SwiftUI   │   │  │
│  │                      │     │  │  │ + 3D   │  │HUD attach│   │  │
│  └──────────┬───────────┘     │  │  └───┬────┘  └────┬─────┘   │  │
│             │ environment     │  └──────┼────────────┼─────────┘  │
│  ┌──────────┴───────────┐     │         │            │            │
│  │      AppModel        │◄────┼─────────┘            │            │
│  │ immersiveSpaceState  │     │                      │            │
│  │ loadingState         │     │  ┌───────────────────┴─────────┐  │
│  └──────────────────────┘     │  │     ORSceneViewModel        │  │
│                                │  │ rootEntity / drawerStates   │  │
│  ┌──────────────────────┐     │  │ isPipesExpanded             │  │
│  │ AVPlayerViewModel    │     │  │ holdingItem / heldGroup     │  │
│  └──────────────────────┘     │  └───────┬─────────────────────┘  │
│                                │          │                       │
│                                │  ┌───────┴────────┐              │
│                                │  │HeadTrackingMgr │              │
│                                │  │ ARKitSession + │              │
│                                │  │ WorldTracking  │              │
│                                │  └────────────────┘              │
├──────────────────────────────┴───────────────────────────────────┤
│                          Networking Layer                         │
│            APIConfig → APIEndpoint → APIService → APIError        │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 设计模式

- **MVVM**：`AppModel` 管理全局状态；`ORSceneViewModel` / `AVPlayerViewModel` / `HeadTrackingManager` 各管理子领域；视图层（`ContentView` / `ImmersiveView` / `AVPlayerView`）保持薄。
- **`@Observable` + `@MainActor`**：所有 ViewModel 使用 Swift 5.9 的 `@Observable` 宏，并在 `@MainActor` 上运行，避免 UI 线程问题。
- **Environment 注入**：`AppModel` 通过 `.environment(appModel)` 注入到 SwiftUI 视图层级。
- **单例**：`APIService.shared`。
- **Swift Package 化资源**：3D 资源独立成 `RealityKitContent` 包，主工程通过 `realityKitContentBundle` 访问。
- **Sendable 安全**：`APIService` 标记 `final … Sendable`，泛型 `request<T: Decodable & Sendable>`。

---

## 4. 文件级详解

### 4.1 [VirtualORApp.swift](VirtualOR/VirtualORApp.swift) — 应用入口

定义两个 Scene：

1. **`WindowGroup`**：根据 `avPlayerViewModel.isPlaying` 切换 `AVPlayerView` 或 `ContentView`。
2. **`ImmersiveSpace`**（id `"ImmersiveSpace"`，`.full` 沉浸式）：
   - `onAppear`：将 `appModel.immersiveSpaceState` 置 `.open`，并调用 `avPlayerViewModel.play()`。
   - `onDisappear`：置 `.closed`，调用 `reset()`。

### 4.2 [AppModel.swift](VirtualOR/AppModel.swift) — 全局状态

| 属性 | 类型 | 取值 | 说明 |
|------|------|------|------|
| `immersiveSpaceID` | `String` | `"ImmersiveSpace"` | 沉浸空间标识 |
| `immersiveSpaceState` | `ImmersiveSpaceState` | `.closed` / `.inTransition` / `.open` | 沉浸空间生命周期 |
| `loadingState` | `LoadingState` | `.idle` / `.loading` / `.loaded` / `.failed(Error)` | 启动数据加载状态 |

`fetchInitialData()` 是异步占位实现 — 注释中预留了真实端点调用 `APIService.shared.request(APIEndpoint(path: "/config"))`，目前直接置为 `.loaded`。

### 4.3 [ContentView.swift](VirtualOR/ContentView.swift) — 主菜单

按 `loadingState` 分支渲染：

| 状态 | UI |
|------|-----|
| `.idle` / `.loading` | `ProgressView("Loading...")` |
| `.loaded` | 中文操作说明（"模拟手术室环境……请根据患者出现的情况进行相应的处理"）+ `ToggleImmersiveSpaceButton` |
| `.failed` | "Failed to load data" + Retry 按钮（重新调用 `fetchInitialData()`） |

`.task { await appModel.fetchInitialData() }` 确保进入主菜单即触发加载。

### 4.4 [ImmersiveView.swift](VirtualOR/ImmersiveView.swift) — 沉浸式视图

使用 `RealityView` + `attachments` 同时承载 3D 实体和 SwiftUI HUD。

**初始化（`make` 闭包）：**
1. `await viewModel.loadRoomIfNeeded()` 异步加载 `ORScene`。
2. `viewModel.prepareForRoom()`：生成碰撞体、初始化管道状态、(DEBUG) 打印实体树。
3. 添加独立的 `hudEntity` 用于跟随头部。
4. 取出 SwiftUI Attachment（id `"hudText"`），定位在头部坐标系下 `(-0.35, -0.22, -0.5)` —— 视野左下方约 50cm 处。

**Attachment 内容：**

```swift
Text("Hold: \(viewModel.holdingItem)")
    .padding(...).background(.black.opacity(0.6))
    .cornerRadius(8)
```

**手势绑定：**

```swift
.gesture(TapGesture().targetedToAnyEntity().onEnded { value in
    viewModel.printWorldPosition(of: value.entity)
    viewModel.handleTapGesture(entity: value.entity)
})
```

**HUD 跟随头部：**

进入 `.task` 后启动 `HeadTrackingManager`，并以 ~60 FPS（`sleep 16ms`）轮询 `queryDeviceAnchor()`，将矩阵直接赋给 `hudEntity.transform`。该循环靠 `Task.isCancelled` 终止。

### 4.5 [HeadTrackingManager.swift](VirtualOR/HeadTrackingManager.swift) — 头部跟踪

封装 `ARKitSession + WorldTrackingProvider`：

| 方法 / 属性 | 功能 |
|------------|------|
| `start()` | 异步启动 ARKit session，运行 `WorldTrackingProvider` |
| `isRunning` | 只读，会话是否已启动 |
| `queryDeviceAnchor() -> simd_float4x4?` | 在当前媒体时间戳下查询设备锚点的 `originFromAnchorTransform` |

需要 `Info.plist` 中的 `NSWorldSensingUsageDescription` 授权（已配置）。

### 4.6 [ORSceneModel.swift](VirtualOR/ORSceneModel/ORSceneModel.swift) — 领域模型

将 Reality Composer Pro 中实体名抽象成 Swift 枚举，便于类型安全地引用。

#### 4.6.1 `enum Suction`（吸引器）

| Case | rawValue | 说明 |
|------|----------|------|
| `pipeRollUpTop` | `pipe_1` | 展开 - 上管 |
| `pipeRollUpBottom` | `pipe_2` | 展开 - 下管 |
| `pipeConnection` | `pipe_connection` | 展开 - 连接件 |
| `bentPipe` | `bent_pipe` | 卷起状态 |

#### 4.6.2 `enum Drawer`（抽屉与器械）

5 个抽屉本体：`drawer_001` ~ `drawer_005`。⚠️ **注意**：`handleTapGesture` 的 switch 分支匹配的是 `drawer_1` ~ `drawer_5`（无前导零），与枚举 rawValue 不一致 —— 这是潜在的 Bug 或暗示场景中实际存在两套命名（详见 §7 待确认问题）。

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

### 4.7 [ORSceneViewModel.swift](VirtualOR/ORSceneViewModel/ORSceneViewModel.swift) — 场景交互核心

#### 状态属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `rootEntity` | `Entity?` | 加载后的 ORScene 根 |
| `loadError` | `Error?` | 加载失败原因 |
| `drawerStates` | `[String: Bool]` | 每个抽屉的开/闭状态 |
| `drawerOpenDistance` | `Float = 1` | 抽屉沿 Z 轴位移 |
| `isPipesExpanded` | `Bool` | 当前管道是否展开 |
| `holdingItem` | `String = "nothing"` | 当前手持器械的 displayName（HUD 绑定） |
| `currentHeldGroup` | `InstrumentGroup?` | 当前正被"持有"（隐藏中）的器械组 |

#### 关键方法

| 方法 | 行为 |
|------|------|
| `loadRoomIfNeeded()` | 幂等异步加载 `ORScene`（来自 `realityKitContentBundle`），调用 `generateCollisionShapes(recursive: true)` |
| `prepareForRoom()` | 调用 `generateAllCollisionShapes()` + `initiatePipeStatus()`，DEBUG 下 `printAllEntities()` |
| `handleTapGesture(entity:)` | 按实体名分发：抽屉 → toggle；`bent_pipe` → expand；`pipe_1/2/connection` → collapse；命中 `pickableInstruments` → `pickUpInstrument` |
| `pickUpInstrument(_:)` | 通过 `entityToGroup` 找到组；若已持有不同组则**显示**旧组实体、**隐藏**新组实体；更新 `holdingItem` |
| `toggleDrawer / openDrawer / closeDrawer` | 沿 Z 轴位移（`±drawerOpenDistance`），并记录状态 |
| `expandPipes / collapsePipes` | 通过 `entity.isEnabled` 切换两组实体可见性 |
| `getWorldPosition(of:)` | 转发 `entity.position(relativeTo: nil)` |

#### 工具方法（`extension`，`private`）

- `makeEntitiesCollidable(_ names:)` — 为命名实体添加 `CollisionComponent`（`generateBox(size: .one)`）+ `InputTargetComponent`，使其可被点击。
- `hideEntities / showEntities` — 通过 `entity.isEnabled` 切换可见性。

### 4.8 [ORSceneViewModel+Tools.swift](VirtualOR/ORSceneViewModel/ORSceneViewModel%2BTools.swift) — 调试工具

| 方法 | 编译条件 | 功能 |
|------|----------|------|
| `printWorldPosition(of:)` | 始终 | 打印实体世界坐标 |
| `printAllEntities()` | `#if DEBUG` | 树形打印整个场景实体层级 |
| `printAllEntityNames()` | `#if DEBUG` | 列出全部实体名与总数 |

### 4.9 [ToggleImmersiveSpaceButton.swift](VirtualOR/ToggleImmersiveSpaceButton.swift) — 沉浸空间开关

封装 `openImmersiveSpace` / `dismissImmersiveSpace` 两个 SwiftUI Environment 值的切换：

- 进入/退出过渡期间，`immersiveSpaceState` 置 `.inTransition`，按钮自动 `disabled`。
- 关闭时**不**在按钮逻辑里设置 `.closed`，而是统一交给 `ImmersiveView.onDisappear`，避免多路径下状态不一致（代码注释明确说明此约定）。
- `openImmersiveSpace` 失败时（`.userCancelled` / `.error`）回滚为 `.closed`。

### 4.10 [AVPlayerView.swift](VirtualOR/AVPlayerView.swift) + [AVPlayerViewModel.swift](VirtualOR/AVPlayerViewModel.swift)

- `AVPlayerView`：薄壳 `UIViewControllerRepresentable`。
- `AVPlayerViewModel`：
  - `videoURL` 当前**硬编码为 `nil`**（注释提示 `Bundle.main.url(forResource: "MyVideo", withExtension: "mp4")`），意味着 `play()` 实际会立即返回 —— 视频教学功能尚未启用。
  - 实现 `AVPlayerViewControllerDelegate.willEndFullScreenPresentationWithAnimationCoordinator`，全屏退出时 `reset()`。

---

## 5. 网络层 (`Networking/`)

### 5.1 数据流

```
APIConfig.baseURL ──┐
                    ▼
              APIEndpoint.urlRequest()  ──► APIService.request<T>()
                                                   │
                                                   ▼
                                             APIError
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

---

## 6. 数据流 / 关键场景

### 6.1 启动流程

```
App 启动
  ↓
ContentView 显示 → .task { fetchInitialData() }
  ↓
loadingState: .idle → .loading → .loaded   (当前是空操作占位，未发起真实请求)
  ↓
显示中文说明 + ToggleImmersiveSpaceButton
  ↓
用户点击 → openImmersiveSpace
  ↓
immersiveSpaceState: .closed → .inTransition → .open
  ↓
ImmersiveView 加载：
  ├ loadRoomIfNeeded()        异步加载 ORScene.usdz
  ├ prepareForRoom()          generateAllCollisionShapes + initiatePipeStatus
  ├ 添加 HUD attachment        固定头部坐标系下偏移
  ├ HeadTrackingManager.start ARKit WorldTrackingProvider
  └ 60 FPS HUD 跟随循环        sleep 16ms
同时：avPlayerViewModel.play()（videoURL=nil 时空跑）
```

### 6.2 交互流程

```
TapGesture 点击 3D 实体
  ↓
viewModel.handleTapGesture(entity:)
  ├ drawer_1~5            → toggleDrawer  → Z 轴位移 ±1
  ├ bent_pipe             → expandPipes   → 隐藏折叠组、显示展开组
  ├ pipe_1/2/connection   → collapsePipes → 反向
  └ pickableInstruments   → pickUpInstrument
       ├ 同组 → 忽略
       ├ 切组 → 显示前一组、隐藏新组
       └ 更新 holdingItem  →  HUD Text 通过 @Observable 自动刷新
```

---

## 7. 当前状态盘点 / 已知问题

### 7.1 模块完成度

| 模块 | 状态 | 备注 |
|------|------|------|
| 3D 场景加载 | ✅ | `ORScene.usdz` 通过 Git LFS 管理 |
| 抽屉开关交互 | ⚠️ | 见下方"命名不一致" |
| 吸引器展开/折叠 | ✅ | |
| 器械拾取（HUD 显示） | ✅ | 单组持有，切换时自动复位 |
| 头部跟踪 HUD | ✅ | 60 FPS 跟随，左下视野 |
| 麻醉监护仪按钮交互 | ❌ | `Anes` 枚举已定义，`handleTapGesture` 未处理 |
| 面罩佩戴/摘除 | ❌ | `masked` / `unmasked` 已定义，无交互逻辑 |
| 监护仪屏幕生命体征显示 | ❌ | 历史 `BlackViewManager` / `ScreenOverlayManager` 已在 commit `b047014` 移除，待重新设计 |
| 视频播放 | ⚠️ | `videoURL = nil`，框架就绪但未启用 |
| 网络层 | ⚠️ | 架构完整，`fetchInitialData` 为占位 |

### 7.2 待确认问题（建议人工核对）

1. **抽屉命名不一致**
   - `Drawer` 枚举 rawValue：`drawer_001` ~ `drawer_005`
   - `handleTapGesture` switch 匹配：`drawer_1` ~ `drawer_5`
   - `CollidableEntities.drawer` 由枚举 rawValue 派生（即 `drawer_001` 等）
   - 当前点击不会命中 switch 的字面字符串，建议要么统一为 `drawer_001` ~ `drawer_005`，要么核实场景里是否同时存在两套命名（父/子层级）。

2. **`isPipesExpanded` 未被读取**
   - 仅写入逻辑缺失（`expandPipes` / `collapsePipes` 也未更新该属性）。可以删除或补全状态机。

3. **`generateAllCollisionShapes` 中的占位 `ShapeResource`**
   - 所有可点击实体都被赋予 `generateBox(size: .one)` 的 1×1×1 米碰撞盒，可能与实际几何不匹配（命中区域过大）。`loadRoomIfNeeded` 已经调用过 `generateCollisionShapes(recursive: true)`，理论上 RealityKit 会基于 mesh 生成碰撞，这里的强制覆盖是否必要值得复审。

4. **APIConfig 的占位 URL** — 上线前必须替换。

5. **`AVPlayerViewModel.videoURL = nil`** — 当前 `play()` 是空操作，需补 bundle 内或远端视频 URL。

6. **未来日期注释** — 多个文件 `Created by Ge Ding on 2026/x/x`，符合当前系统日期 2026-05-02，仅为提示。

---

## 8. 与旧版 [ProjectStructure.md](ProjectStructure.md) 的差异

旧文档以 2026-04-12 之前的代码为基线，主要差异：

| 项 | 旧文档 | 当前代码 |
|----|--------|----------|
| 监护仪屏幕覆盖层 | 描述了 `BlackViewManager` / `ScreenOverlayManager`、HR/SPO2/NIBP/RR/体温 等生命体征显示 | 该文件已被删除（commit `b047014 remove black view`），相关功能整体下线 |
| 头部跟踪 HUD | 未提及 | 新增 `HeadTrackingManager` + `ImmersiveView` HUD attachment |
| 器械拾取 | 列为"❌ 待实现" | 已实现：`InstrumentGroup` 分组 + `pickUpInstrument` + HUD 显示 holdingItem |
| `ORSceneModel` | 仅枚举 | 增加 `InstrumentGroup` 结构体、`instrumentGroups` / `pickableInstruments` / `entityToGroup` |
| `prepareForRoom` 步骤 | 包含"创建屏幕覆盖层 / 添加黑色遮挡面板" | 仅 `generateAllCollisionShapes` + `initiatePipeStatus` |

如需保留单一权威文档，可考虑用本文件替换旧版，或将旧版归档为 `ProjectStructure_v1.md`。
