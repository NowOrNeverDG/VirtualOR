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
        case "drawer_1":
            moveXInWorld(entity, delta: 0.1)
        default:
            break
        }
    }
    
    func moveXInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.x += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved X: \(oldPosition.x) -> \(transform.translation.x)")
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
