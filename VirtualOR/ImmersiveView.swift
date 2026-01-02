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

            viewModel.generateAllCollisionShapes()
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            print("Moscot:\(value.entity.name)")
            guard let rootEntity = viewModel.getRoomEntity() else {
                return
            }
            viewModel.printWorldPosition(of: value.entity)
        })
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
