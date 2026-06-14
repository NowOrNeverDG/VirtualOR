//
//  ImmersiveView.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import RealityKit
import RealityKitContent
import AVKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = ORSceneViewModel()
    @State private var runtime = CourseRuntime()
    @State private var audioService = AudioService()
    @State private var headTrackingManager = HeadTrackingManager()
    @State private var hudEntity = Entity()
    /// 视频实体（hudEntity 的子节点，跟随头部）。固定在视野右下角
    @State private var videoEntity = Entity()

    // floatWindow 位置（右下角）。x 越大越靠右；y 越小越靠下；z 越小越远。
    private let videoFloatPos = SIMD3<Float>(0.42, -0.18, -0.5)
    private let videoFloatSize = CGSize(width: 220, height: 145)

    var body: some View {
        RealityView { content, attachments in
            // Load the OR scene
            guard let rootEntity = await viewModel.loadRoomIfNeeded() else {
                return
            }
            content.add(rootEntity)
            viewModel.prepareForRoom()

            // Load course and start the state machine
            if let course = await viewModel.loadCourseIfNeeded() {
                viewModel.runtime = runtime
                runtime.start(scene: viewModel, course: course)
            }

            // Add HUD entity (will track head position)
            content.add(hudEntity)

            // Attach the SwiftUI HUD text to the entity
            if let hudAttachment = attachments.entity(for: "hudText") {
                // Lower-left of field of view:
                //   x ↑ 越靠右；y ↓ 越靠下；z ↓ 越远
                hudAttachment.position = SIMD3<Float>(-0.40, -0.22, -0.5)
                hudEntity.addChild(hudAttachment)
            }

            // 视频实体跟随头部，固定在视野右下角；只在 isVideoFloated 时才有内容
            hudEntity.addChild(videoEntity)
            videoEntity.position = videoFloatPos
            if let videoAttachment = attachments.entity(for: "breathingVideo") {
                videoEntity.addChild(videoAttachment)
            }
        } update: { content, attachments in
            // No dynamic updates needed
        } attachments: {
            Attachment(id: "hudText") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("State: \(runtime.currentStateName)")
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
            Attachment(id: "breathingVideo") {
                if appModel.isVideoFloated {
                    VideoPlayer(player: appModel.videoPlayer.player)
                        .frame(width: videoFloatSize.width, height: videoFloatSize.height)
                        .cornerRadius(12)
                }
            }
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            viewModel.printWorldPosition(of: value.entity)
            viewModel.handleTapGesture(entity: value.entity)
        })
        .alert(
            runtime.activePopup?.type == "error" ? "错误" : "提示",
            isPresented: Binding(
                get: { runtime.activePopup != nil },
                set: { if !$0 { runtime.dismissPopup() } }
            ),
            actions: { Button("确定") { } },
            message: { Text(runtime.activePopup?.message ?? "") }
        )
        .task {
            // 进沉浸场景就启动两条循环音 + 视频
            // background_music 调低一点，避免压过呼吸音
            audioService.startLoop(named: "background_music", volume: 0.5)
            audioService.startLoop(named: "abnormal_breath")
            appModel.startVideoOverlay()

            await headTrackingManager.start()

            // Update HUD position to follow head at ~60fps
            while !Task.isCancelled {
                if let headTransform = headTrackingManager.queryDeviceAnchor() {
                    hudEntity.transform = Transform(matrix: headTransform)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        .onChange(of: appModel.isVideoFloated) { _, isFloated in
            // 视频浮窗化（10s 后）→ 关掉 2D 主窗口
            if isFloated {
                dismissWindow(id: "main")
            }
        }
        .onDisappear {
            audioService.stopAll()
            appModel.stopVideoOverlay()
            // 退沉浸 → 重新打开 2D 主窗口（否则没有可见 scene，app 会退）
            openWindow(id: "main")
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
