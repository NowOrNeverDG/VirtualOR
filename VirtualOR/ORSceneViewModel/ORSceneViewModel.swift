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
    
    private var drawerStates: [String: Bool] = [:]
    private let drawerOpenDistance: Float = 1
    
    private var isPipesExpanded: Bool = false

    /// 当前手持的器械显示名，"nothing" 表示未持有
    var holdingItem: String = "nothing"
    /// 当前正在隐藏的器械组（用于换器械时恢复）
    private var currentHeldGroup: CollidableEntities.InstrumentGroup?

    //MARK: Patient Vitals (HUD 实时显示)
    // 默认值与 mock initialState.monitor 保持一致，scenario 加载完成后会被 applyMonitor 重新覆盖
    var nibpSystolic: Int = 98       // 收缩压 mmHg
    var nibpDiastolic: Int = 56      // 舒张压 mmHg
    var spo2: Int = 100              // 血氧饱和度 %
    var hr: Int = 86                 // 心率 次/分
    var rr: Int = 20                 // 呼吸频率 次/分
    var temperature: Double = 36.8   // 体温 ℃

    //MARK: Scenario
    /// 剧情数据，由 loadScenarioIfNeeded() 从 ScenarioService 拉取后赋值
    private(set) var scenario: Scenario?

    /// 幂等加载剧情数据（mock）。加载完会用 initialState.monitor 覆盖 6 个 vital。
    func loadScenarioIfNeeded() async {
        guard scenario == nil else { return }
        do {
            let s = try await ScenarioService.fetchMockScenario()
            self.scenario = s
            applyMonitor(s.initialState.monitor)
            logger.info("Loaded scenario: \(s.title)")
        } catch {
            logger.error("Failed to load scenario: \(error.localizedDescription)")
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
            self.rootEntity = try await Entity(named: "ORScene", in: realityKitContentBundle)
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

        #if DEBUG
        printAllEntities()
        #endif

    }

    func handleTapGesture(entity: Entity) {
        let name = entity.name
        logger.debug("Tapped entity: \(name)")
        
        switch name {
        case "drawer_1", "drawer_2", "drawer_3", "drawer_4", "drawer_5":
            toggleDrawer(entity)
        case "bent_pipe":
            expandPipes()
        case "pipe_1", "pipe_2", "pipe_connection":
            collapsePipes()
        default:
            if CollidableEntities.pickableInstruments.contains(name) {
                pickUpInstrument(entity)
            }
        }
    }
    
    
    private func generateAllCollisionShapes() {
        makeEntitiesCollidable(CollidableEntities.suctionExpanded)
        makeEntitiesCollidable(CollidableEntities.suctionCollapsed)
        makeEntitiesCollidable(CollidableEntities.drawer)
        makeEntitiesCollidable(CollidableEntities.anesAdjustButton)
        makeEntitiesCollidable([CollidableEntities.mainScreen, CollidableEntities.submainScreen])
        makeEntitiesCollidable(CollidableEntities.pickableInstruments)
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
    
    //MARK: Instrument Pickup Logic
    private func pickUpInstrument(_ entity: Entity) {
        guard let newGroup = CollidableEntities.entityToGroup[entity.name] else { return }

        // 如果点击的是同一组器械，忽略
        if let current = currentHeldGroup, current.displayName == newGroup.displayName {
            return
        }

        // 恢复上一个器械组（显示回来）
        if let previous = currentHeldGroup {
            showEntities(previous.entityNames)
        }

        // 隐藏新器械的整组部件
        hideEntities(newGroup.entityNames)
        currentHeldGroup = newGroup
        holdingItem = newGroup.displayName
        logger.debug("Picked up instrument: \(self.holdingItem)")
    }

    //MARK: Drawer Logic
    private func toggleDrawer(_ entity: Entity) {
        let entityName = entity.name
        let isCurrentlyOpen = drawerStates[entityName] ?? false
        
        if isCurrentlyOpen {
            // 关闭 drawer
            closeDrawer(entity)
        } else {
            // 打开 drawer
            openDrawer(entity)
        }
    }
    
    private func openDrawer(_ entity: Entity) {
        let entityName = entity.name
        moveEntity(entity, axis: .z, delta: -drawerOpenDistance)
        drawerStates[entityName] = true
        logger.debug("[\(entityName)] Drawer opened")
    }
    
    private func closeDrawer(_ entity: Entity) {
        let entityName = entity.name
        moveEntity(entity, axis: .z, delta: drawerOpenDistance)
        drawerStates[entityName] = false
        logger.debug("[\(entityName)] Drawer closed")
    }
    

    private enum Axis { case x, y, z }
    
    private func moveEntity(_ entity: Entity, axis: Axis, delta: Float) {
        var transform = entity.transform
        switch axis {
        case .x: transform.translation.x += delta
        case .y: transform.translation.y += delta
        case .z: transform.translation.z += delta
        }
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
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
            
            if entity.components[CollisionComponent.self] == nil {
                let shape = ShapeResource.generateBox(size: .one)
                let collision = CollisionComponent(shapes: [shape])
                entity.components.set(collision)
            }
            
            if entity.components[InputTargetComponent.self] == nil {
                entity.components.set(InputTargetComponent())
            }
        }
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
