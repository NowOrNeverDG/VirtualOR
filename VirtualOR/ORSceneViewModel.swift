//
//  ORSceneViewModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/11/29.
//

import Foundation
import RealityFoundation
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
}

// Mark:  Private function
extension ORSceneViewModel {

}
