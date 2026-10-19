//
//  ContentView.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import RealityKit
import AVKit

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel
        return VStack {
            switch appModel.loadingState {
            case .idle, .loading:
                ProgressView("Loading...")
            case .loaded:
                VStack(spacing: 24) {
                    // 沉浸空间打开后、视频未浮窗化前 → 在 2D 窗口里播视频。
                    // 只在考核模式显示：教学模式不需要这层病情视频提示。
                    // 注：底层 appModel.startVideoOverlay() 仍照常跑（见 ImmersiveView），
                    // 10s 后 isVideoFloated 翻转、dismissWindow("main") 的窗口管理逻辑两种模式一致，
                    // 这里只是不渲染画面。
                    if appModel.trainingMode == .assessment
                        && appModel.immersiveSpaceState == .open && !appModel.isVideoFloated {
                        VideoPlayer(player: appModel.videoPlayer.player)
                            .frame(width: 480, height: 320)
                            .cornerRadius(12)
                    }
                    Text("这是一个模拟手术室环境，在这个环境中会出现临床危急情况，您是此次手术的麻醉医生，请根据患者出现的情况进行相应的处理。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    // 沉浸空间没开时才显示模式选择 + Show 按钮；进沉浸后这个 2D 窗口很快会被 dismiss
                    if appModel.immersiveSpaceState != .open {
                        VStack(spacing: 8) {
                            Picker("训练模式", selection: $appModel.trainingMode) {
                                ForEach(AppModel.TrainingMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 320)

                            Text(appModel.trainingMode == .teaching
                                 ? "注视高亮 + 拿起物品后提示下一步"
                                 : "只保留注视高亮，不给任何提示")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ToggleImmersiveSpaceButton()
                    }
                }
            case .failed:
                VStack(spacing: 16) {
                    Text("Failed to load data")
                    Button("Retry") {
                        Task { await appModel.fetchInitialData() }
                    }
                }
            }
        }
        .task {
            await appModel.fetchInitialData()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
