//
//  ORSceneViewModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/11/29.
//

import Foundation
import RealityKit
import RealityKitContent
import _RealityKit_SwiftUI
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "ORScene")

@MainActor
@Observable
class ORSceneViewModel {
    private(set) var rootEntity: Entity?
    var loadError: Error?
    
    private var isPipesExpanded: Bool = false
    /// 是否已插管（true：显示 masked 面罩；false：显示 unmasked 部件组）
    private var isIntubated: Bool = false

    /// 物品名显示语言（由 ImmersiveView 从 AppModel 带进来，进场后不变）
    var displayLanguage: DisplayLanguage = .chinese

    /// 当前手持的显示名，"nothing" 表示未持有。纯显示用，判定一律走 id / operationId。
    var holdingItem: String {
        if let heldDrug { return heldDrug.name(displayLanguage) }
        if currentHeldGroups.isEmpty { return "nothing" }
        return currentHeldGroups.map { $0.name(displayLanguage) }.joined(separator: " + ")
    }

    /// 当前正在隐藏（即手持）的器械组。可同时持有多组，规则见 CollidableEntities.coHoldableSets
    private var currentHeldGroups: [CollidableEntities.InstrumentGroup] = []
    /// 当前手持的药品。药品没有 3D 模型，和器械互斥。
    private var heldDrug: DrugMap.Drug?

    /// 是否教学模式（由 ImmersiveView 从 AppModel 带进来，进场后不变）。
    /// 只影响点击气泡（见 ORSceneViewModel+DescriptionBubble）—— 考核模式点击不弹说明。
    var isTeachingMode: Bool = false
    /// 教学模式下点击后弹出的说明气泡；nil 表示不显示。只应由
    /// ORSceneViewModel+DescriptionBubble.swift 写入——Swift 的 private 是按文件
    /// 划分的，那个逻辑在另一个文件里，所以这里没法标 private(set)。
    /// ImmersiveView 的 RealityView update 闭包读它来摆放/隐藏对应 attachment。
    var descriptionBubble: DescriptionBubble?
    @ObservationIgnored
    var bubbleHideTask: Task<Void, Never>?

    //MARK: Patient Vitals (HUD 实时显示)
    // 默认值与 mock initialState.monitor 保持一致，course 加载完成后会被 applyMonitor 重新覆盖
    var nibpSystolic: Int = 98       // 收缩压 mmHg
    var nibpDiastolic: Int = 56      // 舒张压 mmHg
    var spo2: Int = 100              // 血氧饱和度 %
    var hr: Int = 86                 // 心率 次/分
    var rr: Int = 20                 // 呼吸频率 次/分
    var temperature: Double = 36.8   // 体温 ℃

    //MARK: Course
    /// 剧情数据，由 loadCourseIfNeeded() 从 CourseRepository 拉取后赋值
    private(set) var course: Course?

    /// 状态机运行时（由 ImmersiveView 注入）。临床操作通过 handleTapGesture 路由到这里。
    @ObservationIgnored
    weak var runtime: CourseRuntime?

    /// 剧情数据访问（依赖注入）。默认 Mock（读 resource.json）；
    /// 后端 API ready 后构造时传 `LiveCourseRepository()` 即可，无需改本类。
    @ObservationIgnored
    private let repository: CourseRepository

    init(repository: CourseRepository = MockCourseRepository()) {
        self.repository = repository
    }

    /// 幂等加载剧情数据。加载完会用 initialState.monitor 覆盖 6 个 vital。
    @discardableResult
    func loadCourseIfNeeded() async -> Course? {
        if let course { return course }
        do {
            let s = try await repository.fetchCourse()
            self.course = s
            applyMonitor(s.initialState.monitor)
            logger.info("Loaded course: \(s.title)")
            return s
        } catch {
            logger.error("Failed to load course: \(error.localizedDescription)")
            return nil
        }
    }

    /// 把 Monitor 里的值塞进 HUD 用的 6 个 vital 变量。
    /// 后续状态切换 / operation effect 想刷新 HUD 都走这个入口。
    func applyMonitor(_ monitor: Monitor) {
        nibpSystolic = monitor.nibp.systolic
        nibpDiastolic = monitor.nibp.diastolic
        spo2 = monitor.spo2
        hr = monitor.hr
        rr = monitor.rr
        temperature = monitor.temperature
    }

    @discardableResult
    func loadRoomIfNeeded() async -> Entity? {
        if rootEntity != nil { return rootEntity }

        do {
            self.rootEntity = try await Entity(named: SceneAsset.orScene, in: realityKitContentBundle)
            self.rootEntity?.generateCollisionShapes(recursive: true)
            return rootEntity
        } catch {
            logger.error("Failed to load ORScene: \(error.localizedDescription)")
            self.loadError = error
        }
        
        return nil
    }
    
    func getRoomEntity() -> Entity? {
        return rootEntity
    }
    
    func getWorldPosition(of entity: Entity) -> SIMD3<Float>? {
        return entity.position(relativeTo: nil)
    }
    
    func prepareForRoom() {
        generateAllCollisionShapes()
        initiatePipeStatus()
        initiateIntubationStatus()

        #if DEBUG
        printAllEntities()
        printTapTargetDiagnostics()
        printTappableEntities()
        #endif

    }

    func handleTapGesture(entity: Entity) {
        // tap 常命中子网格（如 Steve_001_1），注册名挂在父实体（steve_001）上，
        // 所以沿祖先链解析出第一个注册过的实体名再分发。
        let rawName = entity.name
        let name = resolveTapTargetName(from: entity) ?? rawName
        let chain = ancestorChain(of: entity)
        logger.info("[Tap] hit=\"\(rawName)\"\(name == rawName ? "" : " resolved→\"\(name)\"") chain=\(chain)")

        // 教学模式：点到已注册的实体就弹一个说明气泡，和下面的功能分发并行、不影响其判断
        if isTeachingMode, isKnownTapTarget(name) {
            showDescriptionBubble(for: name)
        }

        // 吸引器：bent_pipe 展开，其余三段折叠
        if let suction = Suction(rawValue: name) {
            switch suction {
            case .bentPipe:
                logger.info("[Tap] → expandPipes")
                expandPipes()
            case .pipeRollUpTop, .pipeRollUpBottom, .pipeConnection:
                logger.info("[Tap] → collapsePipes")
                collapsePipes()
            }
            return
        }

        // 抽屉：不再 3D 滑出，命中 DrugMap 就拿药（只是持有，服用要点人体衣服）
        if CollidableEntities.drawer.contains(name) {
            if let drug = DrugMap.drug(inDrawer: name) {
                logger.info("[Tap] → pickUpDrug from drawer \(name)")
                pickUpDrug(drug)
            } else {
                logger.info("[Tap] drawer \(name) 命中但 DrugMap 无此抽屉（drawer_001 属正常）")
            }
            return
        }

        // 插管：点未插管状态的面罩部件。持肌松药 → 插管成功（弹窗课程结束）；否则 directIntubation 错误弹窗
        if CollidableEntities.anesUnmasked.contains(name) {
            logger.info("[Tap] → performIntubation")
            performIntubation()
            return
        }

        // 拔管：点已插管的面罩 → 切回未插管显示（与插管互斥切换）
        if CollidableEntities.anesMasked.contains(name) {
            logger.info("[Tap] → extubate")
            extubate()
            return
        }

        // 服药：手持任意药品点人体衣服 → 触发对应 operation
        if name == OperationEntityName.patientClothes.rawValue {
            logger.info("[Tap] → administerHeldDrug")
            administerHeldDrug()
            return
        }

        // 人体：手持喉镜 + 气管导管点头 = 插管；否则落到下面的 OperationEntityMap（托下颌）
        if name == OperationEntityName.humanModel.rawValue, hasIntubationKit {
            logger.info("[Tap] → performIntubation（手持喉镜 + 气管导管）")
            performIntubation()
            return
        }

        // 面罩加压给氧（手捏球囊）：直接点麻醉机上接在面罩上的皮球，不需要先拿东西
        // —— 面罩本来就已经戴在患者脸上（见 initiateIntubationStatus）。
        // 同一个动作按肌松药是否已用分流：用过 → onlyBagAfterRelaxant（state4 恢复）。
        if name == AnesMonitor.rubberBall.rawValue {
            logger.info("[Tap] → squeezeBag")
            squeezeBag()
            return
        }

        if let opId = OperationEntityMap.operationId(for: name) {
            logger.info("[Tap] \"\(name)\" → runtime.perform(\(opId))")
            runtime?.perform(operationId: opId)
        } else if CollidableEntities.pickableInstruments.contains(name) {
            logger.info("[Tap] → pickUpInstrument")
            pickUpInstrument(named: name)
        } else {
            logger.warning("[Tap] no handler matched for \"\(name)\"")
        }
    }

    /// 从命中实体沿祖先链向上（含自身），返回第一个「注册过的」实体名；全都不认识返回 nil。
    private func resolveTapTargetName(from entity: Entity) -> String? {
        var current: Entity? = entity
        while let e = current {
            if isKnownTapTarget(e.name) { return e.name }
            current = e.parent
        }
        return nil
    }

    /// 实体名是否是任一 tap handler 的注册名。
    private func isKnownTapTarget(_ n: String) -> Bool {
        Suction(rawValue: n) != nil
            || CollidableEntities.drawer.contains(n)
            || CollidableEntities.anesUnmasked.contains(n)
            || CollidableEntities.anesMasked.contains(n)
            || n == OperationEntityName.patientClothes.rawValue
            || n == AnesMonitor.rubberBall.rawValue
            || OperationEntityMap.operationId(for: n) != nil
            || CollidableEntities.pickableInstruments.contains(n)
    }

    /// 返回从被点实体往上的 ancestor 链（最多 5 层），方便排查命中的是不是子实体
    private func ancestorChain(of entity: Entity) -> String {
        var names: [String] = [entity.name.isEmpty ? "<unnamed>" : entity.name]
        var current: Entity? = entity.parent
        var depth = 0
        while let e = current, depth < 5 {
            names.append(e.name.isEmpty ? "<unnamed>" : e.name)
            current = e.parent
            depth += 1
        }
        return names.joined(separator: " ← ")
    }
    
    
    private func generateAllCollisionShapes() {
        makeEntitiesCollidable(CollidableEntities.suctionExpanded)
        makeEntitiesCollidable(CollidableEntities.suctionCollapsed)
        makeEntitiesCollidable(CollidableEntities.drawer)
        makeEntitiesCollidable(CollidableEntities.anesAdjustButton)
        makeEntitiesCollidable([CollidableEntities.mainScreen, CollidableEntities.submainScreen])
        makeEntitiesCollidable(CollidableEntities.pickableInstruments)
        makeEntitiesCollidable(CollidableEntities.anesMasked)
        makeEntitiesCollidable(CollidableEntities.anesUnmasked)
        makeEntitiesCollidable([
            OperationEntityName.humanModel.rawValue,
            OperationEntityName.patientClothes.rawValue,
            AnesMonitor.rubberBall.rawValue,
        ])

        // 必须放在最后：drawer 那一批刚被批量加了 InputTarget，这里再把 drawer_001 摘掉
        makeEntitiesTapTransparent(CollidableEntities.tapTransparent)
    }


    //MARK: PiPes Logic
    private func initiatePipeStatus() {
        hideEntities(CollidableEntities.suctionExpanded)
        showEntities(CollidableEntities.suctionCollapsed)
        isPipesExpanded = false
    }

    private func expandPipes() {
        guard !isPipesExpanded else { return }
        hideEntities(CollidableEntities.suctionCollapsed)
        showEntities(CollidableEntities.suctionExpanded)
        isPipesExpanded = true
    }

    private func collapsePipes() {
        guard isPipesExpanded else { return }
        hideEntities(CollidableEntities.suctionExpanded)
        showEntities(CollidableEntities.suctionCollapsed)
        isPipesExpanded = false
    }

    //MARK: Intubation Logic
    private func initiateIntubationStatus() {
        showEntities(CollidableEntities.anesMasked)
        hideEntities(CollidableEntities.anesUnmasked)
        isIntubated = false
        logger.info("[Intubation] 初始化：masked 显示（吸氧面罩已戴在脸上），unmasked 隐藏")
    }

    /// 拔管：切回未插管显示。不做 isIntubated 守卫（幂等），
    /// 万一场景默认把 masked 和 unmasked 同时显示，点一下 masked 也能自愈到正确状态。
    private func extubate() {
        hideEntities(CollidableEntities.anesMasked)
        showEntities(CollidableEntities.anesUnmasked)
        isIntubated = false
        logger.info("[Intubation] 拔管，unmasked 已恢复")
    }

    /// 插管器械是否已备齐（喉镜 + 气管导管同时握在手上）。
    private var hasIntubationKit: Bool {
        CollidableEntities.intubationKit.isSubset(of: heldGroupNames)
    }

    /// 当前手持器械组的身份标识集合（InstrumentGroup.id，与语言无关）
    private var heldGroupNames: Set<String> {
        Set(currentHeldGroups.map(\.id))
    }

    /// 肌松药是否已服用且尚在 branch 选择窗口（服用后 runtime 进入 branch 守门）。
    private var isRelaxantAdministered: Bool {
        runtime?.pendingBranchParent == "muscleRelaxant"
    }

    /// 确保肌松药已服用：已在 branch 窗口直接过；手持肌松药但还没服用则自动补一次服用
    /// （兼容「拿了药直接去插管/捏球囊」的操作习惯，不强制先点衣服）。
    private func ensureRelaxantAdministered() -> Bool {
        if isRelaxantAdministered { return true }
        if heldDrug?.operationId == "muscleRelaxant" {
            logger.info("[Administer] 手持肌松药未服用，自动服用")
            runtime?.perform(operationId: "muscleRelaxant")
            return isRelaxantAdministered
        }
        return false
    }

    /// 插管：肌松药已服用 → 切换到 masked 显示 + 触发 intubationAfterRelaxant（成功弹窗、课程结束）；
    /// 未服用 → 不动 3D 状态，走 directIntubation（错误弹窗 + 违规日志）。
    private func performIntubation() {
        guard ensureRelaxantAdministered() else {
            logger.info("[Intubation] 肌松药未服用 → directIntubation")
            runtime?.triggerDirectIntubation()
            return
        }
        guard !isIntubated else { return }
        hideEntities(CollidableEntities.anesUnmasked)
        showEntities(CollidableEntities.anesMasked)
        isIntubated = true
        logger.info("[Intubation] 插管完成，masked 面罩已显示")
        runtime?.triggerIntubationAfterRelaxant()
    }

    /// 捏球囊：点麻醉机上接在面罩上的皮球（面罩初始就戴在脸上，不需要先拿东西）。
    /// 同一个动作按肌松药分流 —— 已用肌松药走 state4 恢复，没用就是普通的面罩加压给氧。
    private func squeezeBag() {
        if isRelaxantAdministered {
            logger.info("[Bag] 肌松药已用 → onlyBagAfterRelaxant")
            runtime?.triggerOnlyBagAfterRelaxant()
        } else {
            logger.info("[Bag] → maskBagVentilation")
            runtime?.triggerMaskBagVentilation()
        }
    }

    /// 服药：手持任意药品（drawer_002~005 拿取）点人体衣服 → 触发该药对应的 operation。
    private func administerHeldDrug() {
        guard let drug = heldDrug else {
            logger.info("[Administer] 未持药品（当前 \(self.holdingItem)），忽略衣服点击")
            return
        }
        logger.info("[Administer] \(self.holdingItem) → \(drug.operationId)")
        runtime?.perform(operationId: drug.operationId)
    }
    
    //MARK: Instrument Pickup Logic
    private func pickUpInstrument(named name: String) {
        guard let newGroup = CollidableEntities.entityToGroup[name] else { return }

        // 已经拿在手上，忽略
        if heldGroupNames.contains(newGroup.id) { return }

        // 和手上现有的东西凑不成一个「可同时手持」的组合 → 先全部放回场景
        if !canHold(newGroup, alongsideHeld: heldGroupNames) {
            releaseHeldGroups()
        }

        heldDrug = nil
        hideEntities(newGroup.entityNames)
        currentHeldGroups.append(newGroup)
        logger.info("[Hold] picked up instrument: \(self.holdingItem)")
    }

    /// newGroup 能否和手上已有的一起拿：两者合起来必须完整落在某一个 coHoldable 组合里。
    private func canHold(_ newGroup: CollidableEntities.InstrumentGroup, alongsideHeld held: Set<String>) -> Bool {
        if held.isEmpty { return true }
        let combined = held.union([newGroup.id])
        return CollidableEntities.coHoldableSets.contains { combined.isSubset(of: $0) }
    }

    /// 放下手上所有器械组（部件显示回场景）
    private func releaseHeldGroups() {
        for group in currentHeldGroups {
            showEntities(group.entityNames)
        }
        currentHeldGroups.removeAll()
    }

    /// 拿起药品：药品没有 3D 模型，只换持有状态，并把手上的器械全部还原显示。
    private func pickUpDrug(_ drug: DrugMap.Drug) {
        if heldDrug?.operationId == drug.operationId {
            logger.debug("[Hold] already holding \(drug.operationId), ignore")
            return
        }

        releaseHeldGroups()
        heldDrug = drug
        logger.info("[Hold] picked up drug: \(self.holdingItem)")
    }

}

extension ORSceneViewModel {
    private func makeEntitiesCollidable(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                logger.warning("Entity named \(name) not found under rootEntity")
                continue
            }
            
            entity.isEnabled = true

            // generateCollisionShapes(recursive:) 已给所有网格生成贴合碰撞体，命中子网格后由
            // resolveTapTargetName 解析回注册名。只有整棵子树都没有碰撞体时才补一个包围盒——
            // 不能无脑给父实体加大盒子：steve_001 的全身盒会把脸上的面罩、身上的衣服全遮住。
            if entity.components[CollisionComponent.self] == nil && !hasCollidableDescendant(entity) {
                let bounds = entity.visualBounds(relativeTo: entity)
                let extents = bounds.extents
                guard extents.min() > 0 else {
                    logger.warning("[Collision] \(name) visualBounds 为空，跳过碰撞体生成")
                    continue
                }
                let shape = ShapeResource.generateBox(size: extents).offsetBy(translation: bounds.center)
                entity.components.set(CollisionComponent(shapes: [shape]))
                logger.debug("[Collision] \(name) fitted box extents=\(String(describing: extents))")
            }
            
            if entity.components[InputTargetComponent.self] == nil {
                entity.components.set(InputTargetComponent())
            }

            applyHoverEffect(to: entity)
        }
    }

    /// 注视高亮（visionOS 系统渲染，app 拿不到眼动数据）。两种模式都开着，
    /// 它是用户判断「什么能点」的唯一即时反馈。挂在整棵子树上——碰撞体和
    /// ModelComponent 都在子 Mesh 上，只挂父 Xform 不一定渲染得出来。
    ///
    /// 用 .spotlight + .mask：spotlight 是视角相关的边缘光（越贴近轮廓越亮），
    /// mask 只在这圈边缘范围内显示效果，不会像默认的 .full 那样把整个表面
    /// 铺一层高亮色导致分不清边界。
    private func applyHoverEffect(to entity: Entity) {
        if entity.components[HoverEffectComponent.self] == nil {
            let style = HoverEffectComponent.SpotlightHoverEffectStyle(strength: 1.0, opacityFunction: .mask)
            entity.components.set(HoverEffectComponent(.spotlight(style)))
        }
        for child in entity.children {
            applyHoverEffect(to: child)
        }
    }
    
    /// 让实体整棵子树不参与点击命中：摘掉 CollisionComponent 和 InputTargetComponent，
    /// 射线直接穿过去打到后面的物体。用于挡住内容物的容器（见 CollidableEntities.tapTransparent）。
    private func makeEntitiesTapTransparent(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }

        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                logger.warning("Entity named \(name) not found for tap-transparent")
                continue
            }
            removeInteraction(from: entity)
            logger.debug("[Collision] \(name) 已设为点击透明")
        }
    }

    private func removeInteraction(from entity: Entity) {
        entity.components.remove(CollisionComponent.self)
        entity.components.remove(InputTargetComponent.self)
        entity.components.remove(HoverEffectComponent.self)
        for child in entity.children {
            removeInteraction(from: child)
        }
    }

    private func hasCollidableDescendant(_ entity: Entity) -> Bool {
        for child in entity.children {
            if child.components[CollisionComponent.self] != nil { return true }
            if hasCollidableDescendant(child) { return true }
        }
        return false
    }

    private func hideEntities(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                logger.warning("Entity named \(name) not found for hiding")
                continue
            }
            entity.isEnabled = false
        }
    }
    
    private func showEntities(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                logger.warning("Entity named \(name) not found for showing")
                continue
            }
            entity.isEnabled = true
        }
    }
}

// MARK: - 教学模式提示文案
//
// 下一步提示的全部话术集中在这里，改文案只动这一块。当前是占位版，等医生过完稿
// 直接替换字符串即可；提示只在 AppModel.TrainingMode.teaching 下渲染（见 ImmersiveView）。

extension ORSceneViewModel {
    /// 手持物下方的下一步提示；nil = 不显示。
    /// 只在「已经拿起东西」之后才提示，避免变成答案册。
    var nextStepHint: String? {
        // 手上是药 → 去给药
        if heldDrug != nil {
            return "点击病人身体给药"
        }

        // 插管套件：齐了提示插管，缺件提示还差什么
        let missing = CollidableEntities.intubationKit.subtracting(heldGroupNames)
        if missing.isEmpty {
            return "点击病人头部进行气管插管"
        }
        if missing.count < CollidableEntities.intubationKit.count {
            let names = missing.map { CollidableEntities.groupName(id: $0, language: displayLanguage) }
            return "还需要拿起" + names.sorted().joined(separator: "、")
        }

        return nil
    }
}
