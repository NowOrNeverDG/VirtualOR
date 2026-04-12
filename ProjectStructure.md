# VirtualOR 项目结构文档

## 1. 项目概述

**VirtualOR** 是一款基于 Apple Vision Pro 的沉浸式虚拟手术室模拟训练应用。应用面向医学教育场景，用户扮演**麻醉医生**角色，在全沉浸式 3D 手术室环境中面对临床危急情况，练习操作各种麻醉相关器械并监测患者生命体征。

### 1.1 目标平台

- **主平台**: visionOS 2+（Apple Vision Pro）
- **兼容平台**: macOS 15 / iOS 18（部分功能）

### 1.2 核心技术栈

| 技术框架 | 用途 |
|---------|------|
| SwiftUI | 2D 界面构建（主菜单、按钮等） |
| RealityKit | 3D 场景渲染、实体管理与交互 |
| RealityKit Content (Swift Package) | 3D 资源包，存放 USDZ/Reality Composer Pro 场景 |
| AVKit | 视频播放（手术教学场景） |
| URLSession | 网络通信层 |
| os.Logger | 统一日志系统 |

---

## 2. 目录结构

```
VirtualOR/
├── VirtualOR.xcodeproj/                    # Xcode 工程配置
├── Packages/
│   └── RealityKitContent/                  # 3D 资源 Swift Package
│       ├── Package.swift
│       └── Sources/RealityKitContent/
│           └── RealityKitContent.swift      # Bundle 访问入口
│
└── VirtualOR/                              # 主应用源码
    ├── Info.plist                           # 应用配置
    ├── VirtualORApp.swift                   # App 入口
    ├── AppModel.swift                       # 全局状态管理
    ├── ContentView.swift                    # 主菜单视图
    ├── ImmersiveView.swift                  # 沉浸式场景视图
    ├── ToggleImmersiveSpaceButton.swift     # 沉浸空间开关按钮
    ├── AVPlayerView.swift                   # 视频播放器视图
    ├── AVPlayerViewModel.swift              # 视频播放逻辑
    ├── BlackViewManager.swift               # 屏幕覆盖层管理器（ScreenOverlayManager）
    │
    ├── ORSceneModel/
    │   └── ORSceneModel.swift               # 场景实体枚举定义（领域模型）
    │
    ├── ORSceneViewModel/
    │   ├── ORSceneViewModel.swift           # 3D 场景核心交互逻辑
    │   └── ORSceneViewModel+Tools.swift     # 调试工具（实体层级打印等）
    │
    └── Networking/
        ├── APIConfig.swift                  # 网络配置（BaseURL、超时时间）
        ├── APIEndpoint.swift                # 请求端点构建器
        ├── APIService.swift                 # HTTP 客户端（单例）
        └── APIError.swift                   # 网络错误类型定义
```

---

## 3. 应用架构

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────────┐
│                     VirtualORApp                         │
│                    (App 入口)                             │
├──────────────────────┬──────────────────────────────────┤
│                      │                                   │
│    WindowGroup       │       ImmersiveSpace              │
│   ┌──────────────┐   │      ┌────────────────────┐       │
│   │ ContentView  │   │      │   ImmersiveView    │       │
│   │  (主菜单)     │   │      │  (沉浸式 3D 场景)   │       │
│   └──────┬───────┘   │      └────────┬───────────┘       │
│          │           │               │                   │
│   ┌──────┴───────┐   │      ┌────────┴───────────┐       │
│   │  AppModel    │   │      │ ORSceneViewModel   │       │
│   │ (全局状态)    │◄──┼──────│  (场景交互逻辑)     │       │
│   └──────────────┘   │      └────────┬───────────┘       │
│                      │               │                   │
│   ┌──────────────┐   │      ┌────────┴───────────┐       │
│   │ AVPlayerView │   │      │ScreenOverlayManager│       │
│   │ (视频播放)    │   │      │ (屏幕覆盖层管理)    │       │
│   └──────────────┘   │      └────────────────────┘       │
│                      │                                   │
├──────────────────────┴──────────────────────────────────┤
│                   Networking Layer                        │
│         APIService / APIEndpoint / APIConfig              │
└─────────────────────────────────────────────────────────┘
```

### 3.2 设计模式

- **@Observable 响应式状态管理**: AppModel、ORSceneViewModel、AVPlayerViewModel 均采用 Swift 5.9 的 `@Observable` 宏，替代传统的 ObservableObject
- **@MainActor 线程安全**: 所有 ViewModel 标记为 `@MainActor`，确保 UI 状态更新在主线程执行
- **单例模式**: APIService 使用 `static let shared` 单例提供全局网络访问
- **Environment 注入**: AppModel 通过 SwiftUI `.environment()` 在视图层级间传递

---

## 4. 核心文件详解

### 4.1 VirtualORApp.swift — 应用入口

应用的 `@main` 入口点，定义了两个 Scene：

1. **WindowGroup**: 根据 `avPlayerViewModel.isPlaying` 状态切换显示：
   - `AVPlayerView` — 视频正在播放时显示
   - `ContentView` — 默认显示主菜单
2. **ImmersiveSpace**: 全沉浸式空间（`.full` 模式），进入时自动播放视频，退出时重置

```swift
ImmersiveSpace(id: appModel.immersiveSpaceID) {
    ImmersiveView()
        .onAppear  { avPlayerViewModel.play() }
        .onDisappear { avPlayerViewModel.reset() }
}
.immersionStyle(selection: .constant(.full), in: .full)
```

### 4.2 AppModel.swift — 全局状态管理

管理两类核心状态：

| 状态 | 类型 | 可选值 | 说明 |
|-----|------|-------|------|
| `immersiveSpaceState` | `ImmersiveSpaceState` | `.closed` / `.inTransition` / `.open` | 沉浸空间生命周期 |
| `loadingState` | `LoadingState` | `.idle` / `.loading` / `.loaded` / `.failed(Error)` | 初始数据加载状态 |

提供 `fetchInitialData()` 异步方法，用于启动时获取远程配置（当前为占位实现，标记有 TODO）。

### 4.3 ContentView.swift — 主菜单视图

根据 `loadingState` 显示不同 UI：

| 状态 | 显示内容 |
|------|---------|
| `.idle` / `.loading` | 加载指示器 `ProgressView("Loading...")` |
| `.loaded` | 操作说明文字 + 进入沉浸空间按钮 |
| `.failed` | 错误提示 + 重试按钮 |

说明文字为中文："这是一个模拟手术室环境，在这个环境中会出现临床危急情况，您是此次手术的麻醉医生，请根据患者出现的情况进行相应的处理。"

### 4.4 ImmersiveView.swift — 沉浸式场景视图

通过 `RealityView` 加载 3D 手术室场景，核心流程：

1. **加载场景**: 调用 `viewModel.loadRoomIfNeeded()` 异步加载 `ORScene` 实体
2. **准备场景**: 调用 `viewModel.prepareForRoom()` 初始化碰撞体、管道状态、屏幕覆盖层
3. **手势处理**: 注册 `TapGesture` 监听所有可交互实体的点击事件

```swift
.gesture(TapGesture().targetedToAnyEntity().onEnded { value in
    viewModel.handleTapGesture(entity: value.entity)
})
```

### 4.5 ORSceneModel.swift — 领域模型定义

定义了手术室中所有可交互 3D 实体的枚举映射，每个 case 的 rawValue 对应 Reality Composer Pro 中的实体命名。

#### 4.5.1 Suction（吸引器）

| 枚举值 | 实体名 | 说明 |
|-------|--------|------|
| `bentPipe` | `bent_pipe` | 折叠/卷起状态 |
| `pipeRollUpTop` | `pipe_1` | 展开状态 - 上管 |
| `pipeRollUpBottom` | `pipe_2` | 展开状态 - 下管 |
| `pipeConnection` | `pipe_connection` | 展开状态 - 连接件 |

#### 4.5.2 Drawer（抽屉及器械）

5 个抽屉 (`drawer_001` ~ `drawer_005`)，内含以下器械：

| 器械类型 | 数量 | 实体名前缀 |
|---------|------|-----------|
| 面罩（Face Shield） | 4 件 | `face_shield_drawer_00x` |
| 听诊器（Stethoscope） | 7 件 | `stethoscope_00x` |
| 喉镜（Laryngoscope） | 4 件 | `laryngoscope_00x` |
| 口咽管（Oropharyngeal Tube） | 2 件 | `orop_tube_00x` |
| 呼吸球囊（Breathing Balloon） | 5 件 | `balloom_00x` |
| 喉罩（Laryngeal Mask） | 4 件 | `mask_00x` |
| 喉管（Laryngeal Duct） | 5 件 | `duct_00x` |

#### 4.5.3 Anes（麻醉监护仪）

| 枚举值 | 实体名 | 说明 |
|-------|--------|------|
| `autoButton` | `monitor_knob_001` | 自动模式按钮 |
| `manualButton` | `monitor_knob_005` | 手动模式按钮 |
| `manualTrigger` | `monitor_knob_trigger` | 手动触发器 |
| `mainScreen` | `monitor_screen` | 主监护屏幕 |
| `submainScreen` | `monitor_subscreen` | 副监护屏幕 |
| `masked` | `monitor_face_shield_mask` | 面罩已佩戴状态 |
| `unmaskedPipe` | `monitor_SPO_003` | 未戴面罩 - SPO2 管路 |
| `unmaskedPart1~4` | `face_shield_monitor_00x` | 未戴面罩 - 面罩部件 |

#### 4.5.4 CollidableEntities（可碰撞实体集合）

静态属性，将上述枚举按交互类型分组，用于批量设置碰撞体和输入目标组件。

### 4.6 ORSceneViewModel.swift — 场景交互核心

这是整个应用最重要的文件，负责管理 3D 场景中的所有交互逻辑。

#### 核心属性

| 属性 | 类型 | 说明 |
|-----|------|------|
| `rootEntity` | `Entity?` | 场景根实体 |
| `drawerStates` | `[String: Bool]` | 记录每个抽屉的开关状态 |
| `isPipesExpanded` | `Bool` | 吸引器管道是否展开 |
| `screenOverlayManager` | `ScreenOverlayManager?` | 屏幕覆盖层管理器 |

#### 核心方法

| 方法 | 功能 |
|-----|------|
| `loadRoomIfNeeded()` | 异步加载 `ORScene` 3D 场景，自动生成碰撞形状 |
| `prepareForRoom()` | 场景加载后的初始化：生成碰撞体、初始化管道状态、创建屏幕覆盖层、添加黑色遮挡面板 |
| `handleTapGesture(entity:)` | 点击事件分发：根据实体名称路由到对应交互逻辑 |
| `toggleDrawer(_:)` | 切换抽屉开关，沿 Z 轴平移动画 |
| `expandPipes()` / `collapsePipes()` | 切换吸引器展开/折叠状态（显示/隐藏对应实体） |
| `setupScreenOverlays()` | 在主屏幕和副屏幕上创建患者生命体征显示 |
| `showBlackViewInFrontOfMainScreen()` | 在主屏幕上方添加黑色遮挡面板 |

#### 手势路由逻辑

```swift
func handleTapGesture(entity: Entity) {
    switch entity.name {
    case "drawer_1" ~ "drawer_5":  toggleDrawer(entity)
    case "bent_pipe":               expandPipes()
    case "pipe_1", "pipe_2", "pipe_connection": collapsePipes()
    default: break
    }
}
```

#### 实体工具方法（Extension）

- `makeEntitiesCollidable(_:)` — 为实体添加 `CollisionComponent` + `InputTargetComponent`，使其可被点击
- `hideEntities(_:)` / `showEntities(_:)` — 通过 `entity.isEnabled` 控制实体显示/隐藏

### 4.7 BlackViewManager.swift (ScreenOverlayManager) — 屏幕覆盖层管理

负责在 3D 监护仪屏幕上创建和管理文字覆盖层，用于显示患者生命体征。

#### 数据结构

- **PanelConfig**: 面板配置（宽高、偏移、旋转、颜色）
- **LabelConfig**: 文字标签配置（ID、文本、位置、字号、颜色）

#### 当前显示的生命体征

**主屏幕 (monitor_screen)**:

| 指标 | 数值 | 颜色 |
|-----|------|------|
| HR（心率） | 86次/分 | 绿色 |
| SPO2（血氧饱和度） | 100% | 青色 |
| NIBP（无创血压） | 98/56mmHg | 白色 |

**副屏幕 (monitor_subscreen)**:

| 指标 | 数值 | 颜色 |
|-----|------|------|
| RR（呼吸频率） | 20次/分 | 黄色 |
| 体温 | 36.8℃ | 白色 |

#### 核心方法

| 方法 | 功能 |
|-----|------|
| `createOverlay(for:panel:labels:)` | 在指定屏幕实体上创建覆盖层（面板 + 文字标签） |
| `updateLabel(screenEntityName:labelId:newText:)` | 动态更新指定标签的文本和样式 |
| `removeOverlay(for:)` / `removeAllOverlays()` | 移除覆盖层 |
| `setHidden(_:for:)` | 显示/隐藏覆盖层 |

文字使用 `MeshResource.generateText()` 生成 3D 文字网格，采用 `UnlitMaterial`（不受光照影响）确保在任何角度下清晰可读。

### 4.8 AVPlayerView.swift + AVPlayerViewModel.swift — 视频播放

#### AVPlayerView

SwiftUI 视图，通过 `UIViewControllerRepresentable` 桥接 `AVPlayerViewController`。

#### AVPlayerViewModel

| 属性/方法 | 说明 |
|----------|------|
| `isPlaying` | 当前是否正在播放 |
| `videoURL` | 视频资源 URL（当前返回 `nil`，待配置） |
| `play()` | 开始播放视频 |
| `reset()` | 停止播放并清理资源 |

实现了 `AVPlayerViewControllerDelegate`，在全屏播放结束时自动调用 `reset()`。

### 4.9 ToggleImmersiveSpaceButton.swift — 沉浸空间切换按钮

封装了沉浸式空间的打开/关闭逻辑：

- 使用 `@Environment(\.openImmersiveSpace)` 和 `@Environment(\.dismissImmersiveSpace)` 两个 visionOS 环境值
- 在状态为 `.inTransition` 时禁用按钮，防止重复操作
- 关闭时不在此处设置 `.closed`，而是统一在 `ImmersiveView.onDisappear()` 中处理（避免多路径状态不一致）

### 4.10 ORSceneViewModel+Tools.swift — 调试工具

仅在 `#if DEBUG` 编译条件下可用：

| 方法 | 功能 |
|-----|------|
| `printWorldPosition(of:)` | 打印实体的世界坐标位置 |
| `printAllEntities()` | 以树形结构打印整个场景的实体层级 |
| `printAllEntityNames()` | 列出场景中所有实体的名称和总数 |

---

## 5. 网络层

### 5.1 架构设计

```
APIConfig (配置) ──► APIEndpoint (请求构建) ──► APIService (发送请求)
                                                      │
                                                 APIError (错误处理)
```

### 5.2 APIConfig — 网络配置

- 通过 `#if DEBUG` 区分开发/生产环境的 BaseURL
- 统一超时时间：30 秒

### 5.3 APIEndpoint — 请求端点构建器

支持配置：路径 (path)、HTTP 方法 (GET/POST/PUT/DELETE)、请求头 (headers)、查询参数 (queryItems)、请求体 (body)。

使用 `AnyEncodable` 包装器实现类型擦除，支持任意 `Encodable` 类型作为请求体。

### 5.4 APIService — HTTP 客户端

- 单例模式 (`shared`)
- JSON 解码策略：snake_case 自动转换 + ISO 8601 日期格式
- 提供两个 `request` 重载：
  - `request<T: Decodable>(_:) -> T` — 返回解码后的响应对象
  - `request(_:)` — 无返回值（仅检查状态码）

### 5.5 APIError — 错误类型

| Case | 说明 |
|------|------|
| `invalidURL` | URL 构建失败 |
| `invalidResponse` | 非 HTTP 响应 |
| `httpError(statusCode:data:)` | HTTP 状态码非 2xx |
| `decodingError(Error)` | JSON 解码失败 |
| `networkError(Error)` | 网络连接错误 |

---

## 6. 数据流

### 6.1 应用启动流程

```
App 启动
  │
  ▼
ContentView.task { fetchInitialData() }
  │
  ▼
loadingState: .idle → .loading → .loaded
  │
  ▼
显示操作说明 + "Show Immersive Space" 按钮
  │
  ▼ (用户点击按钮)
  │
openImmersiveSpace() → immersiveSpaceState: .inTransition → .open
  │
  ▼
ImmersiveView 加载
  │
  ├── loadRoomIfNeeded()     ← 异步加载 ORScene 3D 场景
  ├── prepareForRoom()       ← 初始化碰撞体、管道、屏幕覆盖层
  └── avPlayerViewModel.play() ← 开始播放视频
```

### 6.2 用户交互流程

```
用户点击 3D 实体
  │
  ▼
TapGesture.onEnded
  │
  ▼
handleTapGesture(entity:)
  │
  ├── drawer_001~005  → toggleDrawer() → 沿 Z 轴平移开/关
  ├── bent_pipe        → expandPipes()  → 隐藏折叠态，显示展开态
  └── pipe_1/2/conn    → collapsePipes() → 隐藏展开态，显示折叠态
```

---

## 7. 当前开发状态

| 模块 | 状态 | 备注 |
|-----|------|------|
| 3D 场景加载与渲染 | ✅ 已完成 | ORScene 场景正常加载 |
| 抽屉交互（开/关） | ✅ 已完成 | 5 个抽屉均可交互 |
| 吸引器交互（展开/折叠） | ✅ 已完成 | 管道状态切换正常 |
| 监护仪屏幕覆盖层 | ✅ 已完成 | 主屏 + 副屏生命体征显示 |
| 视频播放器 | ⚠️ 基础完成 | 框架就绪，`videoURL` 待配置 |
| 网络层 | ⚠️ 基础完成 | 架构已搭建，`fetchInitialData()` 为占位实现 |
| 麻醉监护仪按钮交互 | ❌ 待实现 | `Anes` 枚举已定义，手势路由尚未处理 |
| 面罩佩戴/摘除交互 | ❌ 待实现 | `masked`/`unmasked` 实体已定义 |
| 抽屉内器械拾取交互 | ❌ 待实现 | 器械枚举已定义，交互逻辑尚未实现 |
| 生命体征动态更新 | ❌ 待实现 | `updateLabel()` 方法已就绪，但尚未接入数据源 |
