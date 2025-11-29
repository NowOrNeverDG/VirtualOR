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
            if let roomEtt = try? await Entity(named: "ORScene", in: realityKitContentBundle) {
                roomEtt.generateCollisionShapes(recursive: true)
                content.add(roomEtt)
                roomEtt.components.set(InputTargetComponent())

                if let ventTrigManual = roomEtt.findEntity(named: "ventilate_trigger_manual") {
                    print("ORScene")
                }
            }
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            print(value.entity.name ?? "no name")
        })
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
