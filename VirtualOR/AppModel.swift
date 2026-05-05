//
//  AppModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/9/30.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "AppModel")

@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    enum LoadingState {
        case idle
        case loading
        case loaded
        case failed(Error)
    }
    var loadingState = LoadingState.idle

    // MARK: - 病情视频（abnormal_breath.mp4）
    /// 共享视频播放器：开始时在 ContentView 的 2D 窗口里，10s 后切到 ImmersiveView 的浮窗
    let videoPlayer = BreathingVideoPlayer()
    /// false: 视频在 ContentView 的 2D 窗口；true: 在沉浸空间右下角浮窗
    var isVideoFloated: Bool = false
    private var floatTask: Task<Void, Never>?

    /// 进沉浸场景时调用：启动循环视频 + 10s 后切到右下角浮窗
    func startVideoOverlay() {
        videoPlayer.start(named: "abnormal_breath")
        isVideoFloated = false
        floatTask?.cancel()
        floatTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            isVideoFloated = true
        }
    }

    /// 退沉浸场景时调用：取消计时器、停止播放、复位
    func stopVideoOverlay() {
        floatTask?.cancel()
        floatTask = nil
        videoPlayer.stop()
        isVideoFloated = false
    }

    func fetchInitialData() async {
        guard case .idle = loadingState else { return }
        loadingState = .loading

        do {
            // TODO: Replace with actual endpoint and response model
            // let config: YourResponseModel = try await APIService.shared.request(
            //     APIEndpoint(path: "/config")
            // )
            loadingState = .loaded
        } catch {
            logger.error("Failed to fetch initial data: \(error.localizedDescription)")
            loadingState = .failed(error)
        }
    }
}
