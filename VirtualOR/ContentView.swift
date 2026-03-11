//
//  ContentView.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack {
            switch appModel.loadingState {
            case .idle, .loading:
                ProgressView("Loading...")
            case .loaded:
                VStack(spacing: 24) {
                    Text("这是一个模拟手术室环境，在这个环境中会出现临床危急情况，您是此次手术的麻醉医生，请根据患者出现的情况进行相应的处理。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    ToggleImmersiveSpaceButton()
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
