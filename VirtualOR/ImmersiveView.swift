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
    @State private var viewModel = ORSceneViewModel()

    var body: some View {
        RealityView { content in
            guard let rootEntity = await viewModel.loadRoomIfNeeded() else {
                return
            }
            content.add(rootEntity)
            viewModel.prepareForRoom()
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            viewModel.printWorldPosition(of: value.entity)
            viewModel.handleTapGesture(entity: value.entity)
        })
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
