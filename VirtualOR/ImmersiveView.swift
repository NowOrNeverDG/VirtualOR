//
//  ImmersiveView.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @StateObject private var viewModel = ORSceneViewModel()

    var body: some View {
        RealityView { content in
            guard let rootEntity = await viewModel.loadRoomIfNeeded() else {
                return
            }
            content.add(rootEntity)
            
            if let wall = rootEntity.findEntity(named: "wall_1") {
                wall.components.remove(CollisionComponent.self)
                wall.isEnabled = false
            }
            
            
            if let cabinet = rootEntity.findEntity(named: "cabinet_1") {
                cabinet.components.remove(CollisionComponent.self)
                cabinet.isEnabled = false
            }

            
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            print("Moscot:\(value.entity.name)")
            guard let rootEntity = viewModel.getRoomEntity() else {
                return
            }
            print("Moscot:\(value.entity.position(relativeTo: rootEntity))")
        })
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
