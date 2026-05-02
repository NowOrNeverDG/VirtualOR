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
    @State private var headTrackingManager = HeadTrackingManager()
    @State private var hudEntity = Entity()

    var body: some View {
        RealityView { content, attachments in
            // Load the OR scene
            guard let rootEntity = await viewModel.loadRoomIfNeeded() else {
                return
            }
            content.add(rootEntity)
            viewModel.prepareForRoom()

            // Load scenario mock data (populates HUD vitals from initialState.monitor)
            await viewModel.loadScenarioIfNeeded()

            // Add HUD entity (will track head position)
            content.add(hudEntity)

            // Attach the SwiftUI HUD text to the entity
            if let hudAttachment = attachments.entity(for: "hudText") {
                // Lower-left of field of view:
                //   x = -0.15  → 15cm left
                //   y = -0.12  → 12cm below center
                //   z = -0.50  → 50cm in front of eyes
                hudAttachment.position = SIMD3<Float>(-0.35, -0.22, -0.5)
                hudEntity.addChild(hudAttachment)
            }
        } update: { content, attachments in
            // No dynamic updates needed
        } attachments: {
            Attachment(id: "hudText") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hold: \(viewModel.holdingItem)")
                    Text("NIBP: \(viewModel.nibpSystolic)/\(viewModel.nibpDiastolic) mmHg")
                    Text("SPO2: \(viewModel.spo2)%")
                    Text("HR: \(viewModel.hr) 次/分")
                    Text("RR: \(viewModel.rr) 次/分")
                    Text(String(format: "体温: %.1f℃", viewModel.temperature))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6))
                .cornerRadius(8)
            }
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            viewModel.printWorldPosition(of: value.entity)
            viewModel.handleTapGesture(entity: value.entity)
        })
        .task {
            await headTrackingManager.start()

            // Update HUD position to follow head at ~60fps
            while !Task.isCancelled {
                if let headTransform = headTrackingManager.queryDeviceAnchor() {
                    hudEntity.transform = Transform(matrix: headTransform)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
