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
            print("Error:[ORSceneViewModel] Failed to load ORScene:", error)
        }
        return nil
    }
    
    func getRoomEntity() -> Entity? {
        return rootEntity
    }
    
    
}

/*
 展开：pipe_1 pipe_2 pipe_connection
 卷起：bent_pipe
 
 抽屉：drawer_1 drawer_2 drawer_3 drawer_4 drawer_5
 
 麻醉气体调节按钮：Knob_001
*/

