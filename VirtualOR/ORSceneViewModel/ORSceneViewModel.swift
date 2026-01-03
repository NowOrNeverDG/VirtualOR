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

class ORSceneViewModel: ObservableObject {
    @Published var rootEntity: Entity?
    
    // 记录每个 drawer 的打开状态
    private var drawerStates: [String: Bool] = [:]
    private let drawerOpenDistance: Float = 1  // 打开时的 Y 轴移动距离
    
    @discardableResult
    func loadRoomIfNeeded() async -> Entity? {
        if rootEntity != nil { return rootEntity }

        do {
            let room = try await Entity(named: "ORScene", in: realityKitContentBundle)
            await room.generateCollisionShapes(recursive: true)
            self.rootEntity = room
            return rootEntity
        } catch {
            print("Error:[ORSceneViewModel.loadRoomIfNeeded] Failed to load ORScene:", error)
        }
        return nil
    }
    
    func getRoomEntity() -> Entity? {
        return rootEntity
    }
    
    func getWorldPosition(of entity: Entity) -> SIMD3<Float>? {
        return entity.position(relativeTo: nil)
    }
    
    func generateAllCollisionShapes() {
        makeEntitiesCollidable(CollidableEntities.rollUpPipes)
        makeEntitiesCollidable(CollidableEntities.bentPipes)
        makeEntitiesCollidable(CollidableEntities.drawer)
        makeEntitiesCollidable(CollidableEntities.AnesAdjustButton)
    }
    
    func handleTapGesture(entity: Entity) {
        guard let name = entity.name as String? else { return }
        print("Tapped entity: \(name)")
        
        switch name {
        case "drawer_1", "drawer_2", "drawer_3", "drawer_4", "drawer_5":
            toggleDrawer(entity)
        case "pipe_1","pipe_2","pipe_connection":
            break
        default:
            break
        }
    }
    
    // 切换 drawer 的打开/关闭状态
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
    
    // 打开 drawer（Z 轴正方向移动）
    private func openDrawer(_ entity: Entity) {
        let entityName = entity.name
        moveZInWorld(entity, delta: -drawerOpenDistance)
        drawerStates[entityName] = true
        print("[\(entityName)] Drawer opened")
    }
    
    // 关闭 drawer（Z 轴负方向移动回原位）
    private func closeDrawer(_ entity: Entity) {
        let entityName = entity.name
        moveZInWorld(entity, delta: drawerOpenDistance)
        drawerStates[entityName] = false
        print("[\(entityName)] Drawer closed")
    }
    
    func moveXInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.x += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved X: \(oldPosition.x) -> \(transform.translation.x)")
    }
    
    func moveYInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.y += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved Y: \(oldPosition.y) -> \(transform.translation.y)")
    }
    
    func moveZInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.z += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved Z: \(oldPosition.z) -> \(transform.translation.z)")
    }
    
    func moveInWorld(_ entity: Entity, delta: SIMD3<Float>) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved: \(oldPosition) -> \(transform.translation)")
    }
}

extension ORSceneViewModel {
    private func makeEntitiesCollidable(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                print("⚠️ [ORSceneViewModel] Entity named \(name) not found under rootEntity")
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
}


/*
 展开：pipe_1 pipe_2 pipe_connection
 卷起：bent_pipe
 
 抽屉：drawer_1 drawer_2 drawer_3 drawer_4 drawer_5
 
 麻醉气体调节按钮：Knob_001
*/
struct CollidableEntities {
    static var rollUpPipes: [String] = ["pipe_1","pipe_2","pipe_connection"]
    static var bentPipes: [String] = ["bent_pipe"]
    
    static var drawer: [String] = ["drawer_1","drawer_2","drawer_3","drawer_4","drawer_5"]
    
    static var AnesAdjustButton: [String] = ["Knob_001"]
}
