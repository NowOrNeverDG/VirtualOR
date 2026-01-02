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
            await room.components.set(InputTargetComponent())
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
    
    func printWorldPosition(of entity: Entity) {
        if let position = getWorldPosition(of: entity) {
            print("World position: \(position)")
        } else {
            print("Error: [ORSceneViewModel.printWorldPosition] Can't not find World position")
        }
    }
    
    func generateAllCollisionShapes() {
        makeEntitiesCollidable(CollidableEntities.rollUpPipes)
        makeEntitiesCollidable(CollidableEntities.bentPipes)
        makeEntitiesCollidable(CollidableEntities.drawer)
        makeEntitiesCollidable(CollidableEntities.AnesAdjustButton)
    }
}

extension ORSceneViewModel {
    private func makeEntitiesCollidable(_ names: [String]) {
        for str in names {
            if let wall = rootEntity?.findEntity(named: str) {
                wall.components.remove(CollisionComponent.self)
                wall.isEnabled = false
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
