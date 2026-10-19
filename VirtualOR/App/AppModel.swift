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

    /// 训练模式。进沉浸空间之前在 ContentView 选，进去之后不变。
    /// - teaching：注视高亮 + 手持物下一步提示
    /// - assessment：只保留注视高亮，不给任何提示
    enum TrainingMode: String, CaseIterable, Identifiable {
        case teaching = "教学模式"
        case assessment = "考核模式"
        var id: String { rawValue }
    }
    var trainingMode = TrainingMode.teaching

    /// 物品名（器械 / 药品）的显示语言。**没有 UI 开关，改这一行即可全局切换。**
    /// 只影响 3D 名牌和 HUD 手持物上的物品名；引导语、提示语、生命体征标签固定中文。
    var displayLanguage = DisplayLanguage.chinese

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
