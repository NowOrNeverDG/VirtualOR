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
        VStack {
            switch appModel.loadingState {
            case .idle, .loading:
                ProgressView("Loading...")
            case .loaded:
                VStack(spacing: 24) {
                    // 沉浸空间打开后、视频未浮窗化前 → 在 2D 窗口里播视频
                    if appModel.immersiveSpaceState == .open && !appModel.isVideoFloated {
                        VideoPlayer(player: appModel.videoPlayer.player)
                            .frame(width: 480, height: 320)
                            .cornerRadius(12)
                    }
                    Text("这是一个模拟手术室环境，在这个环境中会出现临床危急情况，您是此次手术的麻醉医生，请根据患者出现的情况进行相应的处理。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    // 沉浸空间没开时才显示 Show 按钮；进沉浸后这个 2D 窗口很快会被 dismiss
                    if appModel.immersiveSpaceState != .open {
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
