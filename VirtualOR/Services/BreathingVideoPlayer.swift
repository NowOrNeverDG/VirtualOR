//
//  BreathingVideoPlayer.swift
//  VirtualOR
//
//  无缝循环的嵌入式视频播放器（SwiftUI VideoPlayer 用）。
//  用 AVQueuePlayer + AVPlayerLooper 实现真正的无 gap 循环。
//

import AVKit
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "Video")

@MainActor
@Observable
final class BreathingVideoPlayer {
    /// 暴露给 SwiftUI VideoPlayer(player:) 用
    let player = AVQueuePlayer()

    private var looper: AVPlayerLooper?
    private(set) var isReady: Bool = false

    /// 启动循环。`name` 不带扩展名；文件需在主 bundle。
    /// 幂等：重复调用不会重新加载。
    func start(named name: String, fileExtension: String = "mp4") {
        if isReady {
            player.play()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            logger.warning("[Video] file not found: \(name).\(fileExtension)")
            return
        }
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true   // 避免和 AudioService 的循环声音重叠；要原声把这行去掉
        player.play()
        isReady = true
        logger.info("[Video] loop started: \(name)")
    }

    func stop() {
        player.pause()
        player.removeAllItems()
        looper = nil
        isReady = false
        logger.info("[Video] stopped")
    }
}
