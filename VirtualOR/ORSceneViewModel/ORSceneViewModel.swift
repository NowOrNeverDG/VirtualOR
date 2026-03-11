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
    private var screenOverlayManager: ScreenOverlayManager?
    
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
        debugMarkScreens()
        #endif

        setupScreenOverlays()
    }

    #if DEBUG
    private func debugMarkScreens() {
        guard let rootEntity else { return }
        for name in [CollidableEntities.mainScreen, CollidableEntities.submainScreen] {
            guard let entity = rootEntity.findEntity(named: name) else { continue }
            let mesh = MeshResource.generateBox(size: SIMD3<Float>(1, 1, 1))
            var material = UnlitMaterial()
            material.color = .init(tint: .red)
            let box = ModelEntity(mesh: mesh, materials: [material])
            box.name = "DEBUG_\(name)"
            entity.addChild(box)
            box.position = .zero
            let worldPos = entity.position(relativeTo: nil)
            logger.info("DEBUG: \(name) worldPos=\(String(describing: worldPos))")
        }
    }
    #endif
    
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
            break
        }
    }
    
    
    private func generateAllCollisionShapes() {
        makeEntitiesCollidable(CollidableEntities.suctionExpanded)
        makeEntitiesCollidable(CollidableEntities.suctionCollapsed)
        makeEntitiesCollidable(CollidableEntities.drawer)
        makeEntitiesCollidable(CollidableEntities.anesAdjustButton)
        makeEntitiesCollidable([CollidableEntities.mainScreen, CollidableEntities.submainScreen])
    }
    
    
    //MARK: PiPes Logic
    private func initiatePipeStatus() {
        hideEntities(CollidableEntities.suctionExpanded)
    }
    
    private func expandPipes() {
        hideEntities(CollidableEntities.suctionCollapsed)
        showEntities(CollidableEntities.suctionExpanded)
    }
    
    private func collapsePipes() {
        hideEntities(CollidableEntities.suctionExpanded)
        showEntities(CollidableEntities.suctionCollapsed)
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
    
    //MARK: - Screen Overlay
    private func setupScreenOverlays() {
        guard let rootEntity else {
            logger.error("setupScreenOverlays: rootEntity is nil")
            return
        }

        let manager = ScreenOverlayManager(rootEntity: rootEntity)
        self.screenOverlayManager = manager

        let standUp = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        let rotateZ = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))

        let mainPanelConfig = ScreenOverlayManager.PanelConfig(
            width: 3,
            height: 2,
            offset: SIMD3(0, 0, 0),
            rotation: rotateZ * standUp
        )

        let mainLabels: [ScreenOverlayManager.LabelConfig] = [
            .init(id: "hr",   text: "HR: 86次/分",        position: SIMD3(-1.2,  0.5, 0.05), fontSize: 0.2, color: .green),
            .init(id: "spo2", text: "SPO2: 100%",         position: SIMD3(-1.2,  0,   0.05), fontSize: 0.2, color: .cyan),
            .init(id: "nibp", text: "NIBP: 98/56mmHg",    position: SIMD3(-1.2, -0.5, 0.05), fontSize: 0.2, color: .white)
        ]

        manager.createOverlay(
            for: CollidableEntities.mainScreen,
            panel: mainPanelConfig,
            labels: mainLabels
        )

        let subPanelConfig = ScreenOverlayManager.PanelConfig(
            width: 3,
            height: 2,
            offset: SIMD3(0, 0, 0),
            rotation: standUp
        )

        let subLabels: [ScreenOverlayManager.LabelConfig] = [
            .init(id: "rr",   text: "RR: 20次/分",        position: SIMD3(-1.2,  0.3, 0.05), fontSize: 0.2, color: .yellow),
            .init(id: "temp", text: "体温: 36.8℃",        position: SIMD3(-1.2, -0.3, 0.05), fontSize: 0.2, color: .white)
        ]

        manager.createOverlay(
            for: CollidableEntities.submainScreen,
            panel: subPanelConfig,
            labels: subLabels
        )
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
