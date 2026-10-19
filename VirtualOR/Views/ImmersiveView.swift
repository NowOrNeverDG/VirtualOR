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
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
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
            // 语言 / 训练模式在进沉浸之前就选好了，这里带进 ViewModel：
            // displayLanguage 影响 HUD 手持物文字；isTeachingMode 决定点击要不要弹说明气泡
            // （考核模式只留系统注视高亮，不给任何文字提示）。
            viewModel.displayLanguage = appModel.displayLanguage
            viewModel.isTeachingMode = appModel.trainingMode == .teaching

            // Load the OR scene
            guard let rootEntity = await viewModel.loadRoomIfNeeded() else {
                return
            }
            content.add(rootEntity)
            viewModel.prepareForRoom()

            // Load course and start the state machine
            if let course = await viewModel.loadCourseIfNeeded() {
                viewModel.runtime = runtime
                // 教学模式不限时：不启动课程倒计时，也就不会到点强制结束
                runtime.start(scene: viewModel, course: course, enforceTimeLimit: appModel.trainingMode == .assessment)
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

            // 手持物：视野正中偏下，和左下角生命体征分开
            if let holdingAttachment = attachments.entity(for: "holdingItem") {
                holdingAttachment.position = SIMD3<Float>(0, -0.22, -0.5)
                hudEntity.addChild(holdingAttachment)
            }

            // 课程倒计时：视野左上角
            if let countdownAttachment = attachments.entity(for: "countdown") {
                countdownAttachment.position = SIMD3<Float>(-0.40, 0.22, -0.5)
                hudEntity.addChild(countdownAttachment)
            }

            // 视频实体跟随头部，固定在视野右下角；只在 isVideoFloated 时才有内容
            hudEntity.addChild(videoEntity)
            videoEntity.position = videoFloatPos
            if let videoAttachment = attachments.entity(for: "breathingVideo") {
                videoEntity.addChild(videoAttachment)
            }

            // 进场引导：视野正中，10s 后随视频浮窗化消失
            if let introAttachment = attachments.entity(for: "courseIntro") {
                introAttachment.position = SIMD3<Float>(0, 0, -0.6)
                hudEntity.addChild(introAttachment)
            }

            // 剧情弹窗：跟随头部、视野正中。沉浸空间里 .alert 没有可挂载的窗口
            // （主 2D 窗口在视频浮窗化后已被 dismiss），所以用 attachment 渲染
            if let popupAttachment = attachments.entity(for: "coursePopup") {
                popupAttachment.position = SIMD3<Float>(0, 0, -0.5)
                hudEntity.addChild(popupAttachment)
            }

            // 教学模式点击说明气泡：挂在 rootEntity（场景空间）而不是 hudEntity，
            // 因为它要钉在被点物体正上方，不跟头转；朝向交给 BillboardComponent。
            // 具体位置由下面的 update 闭包根据 viewModel.descriptionBubble 动态更新。
            if let bubbleAttachment = attachments.entity(for: "descriptionBubble") {
                bubbleAttachment.components.set(BillboardComponent())
                bubbleAttachment.isEnabled = false
                rootEntity.addChild(bubbleAttachment)
            }
        } update: { content, attachments in
            // 教学模式点击气泡：有内容就摆到目标位置显示，没有就隐藏
            if let bubbleAttachment = attachments.entity(for: "descriptionBubble") {
                if let bubble = viewModel.descriptionBubble {
                    bubbleAttachment.position = bubble.localPosition
                    bubbleAttachment.isEnabled = true
                } else {
                    bubbleAttachment.isEnabled = false
                }
            }
        } attachments: {
            Attachment(id: "hudText") {
                // 生命体征：考核模式才显示——教学模式靠高亮 + 提示学操作，
                // 体征和时间压力会分散注意力（这两项本身就是考核的一部分）。
                if appModel.trainingMode == .assessment {
                    VStack(alignment: .leading, spacing: 4) {
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
            Attachment(id: "holdingItem") {
                if viewModel.holdingItem != "nothing" {
                    VStack(spacing: 2) {
                        Text(viewModel.holdingItem)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        // 下一步提示只在教学模式给；考核模式只留系统的注视高亮
                        if appModel.trainingMode == .teaching, let hint = viewModel.nextStepHint {
                            Text(hint)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            Attachment(id: "breathingVideo") {
                // 同一路视频，只在考核模式渲染；教学模式不需要这个浮窗
                if appModel.trainingMode == .assessment, appModel.isVideoFloated {
                    VideoPlayer(player: appModel.videoPlayer.player)
                        .frame(width: videoFloatSize.width, height: videoFloatSize.height)
                        .cornerRadius(12)
                }
            }
            Attachment(id: "countdown") {
                // 倒计时同理：只在考核模式给时间压力，教学模式不限时
                if appModel.trainingMode == .assessment {
                    Text(String(format: "%02d:%02d", runtime.remainingSeconds / 60, runtime.remainingSeconds % 60))
                        .font(.system(size: 18, weight: .semibold).monospacedDigit())
                        .foregroundStyle(runtime.remainingSeconds <= 60 ? .red : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .cornerRadius(8)
                }
            }
            Attachment(id: "courseIntro") {
                // 视频浮窗化（10s）之前显示；剧情弹窗弹出时让位
                if !appModel.isVideoFloated, runtime.activePopup == nil {
                    CourseIntroView(showsInteractionGuide: appModel.trainingMode == .teaching)
                        // 纯信息面板，不能挡住后面 3D 物体的点击
                        .allowsHitTesting(false)
                }
            }
            Attachment(id: "coursePopup") {
                if let popup = runtime.activePopup {
                    VStack(spacing: 14) {
                        Text(popup.type == "error" ? "错误" : "提示")
                            .font(.title3.bold())
                        Text(popup.message)
                            .font(.system(size: 15))
                            .multilineTextAlignment(.center)
                        Button("确定") {
                            // 错误 / 超时弹窗：确认后退出沉浸场景回主菜单。
                            // viewModel / runtime 都是本视图 @State，随沉浸空间销毁而重置，
                            // 下次进入即全新课程；音视频停止与主窗口重开由 onDisappear 统一处理。
                            let shouldExit = popup.type == "error" || popup.type == "timeout"
                            runtime.dismissPopup()
                            if shouldExit {
                                Task { await dismissImmersiveSpace() }
                            }
                        }
                    }
                    .padding(24)
                    .frame(width: 340)
                    .glassBackgroundEffect()
                }
            }
            Attachment(id: "descriptionBubble") {
                // 教学模式点击气泡：内容和位置都由 viewModel.descriptionBubble 驱动，
                // 位置的挂载在 update 闭包里（见上）。纯说明用，不拦截点击。
                if let bubble = viewModel.descriptionBubble {
                    Text(bubble.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: 220)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .bottom) {
                            BubbleTailShape()
                                .fill(.black.opacity(0.75))
                                .frame(width: 14, height: 7)
                                .offset(y: 7)
                        }
                        .allowsHitTesting(false)
                }
            }
        }
        .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
            viewModel.printWorldPosition(of: value.entity)
            viewModel.handleTapGesture(entity: value.entity)
        })
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

/// 说明气泡下方的小三角尾巴，指向被点的实体。
private struct BubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView().environment(AppModel())
}
