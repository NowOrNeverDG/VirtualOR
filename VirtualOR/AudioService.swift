//
//  AudioService.swift
//  VirtualOR
//
//  音频服务（Phase 1）：用 AVAudioPlayer 跑 stereo 循环，
//  适合心跳 / 呼吸生理音的基础播放。
//
//  Phase 2 待加：HR / RR 同步（speed 倍率）、空间化（迁到 RealityKit
//  AudioFileResource + 患者实体上的 SpatialAudioComponent）、多轨混音。
//

import AVFoundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "Audio")

@MainActor
@Observable
final class AudioService {
    /// 总开关：false 时所有已注册的循环都暂停（不丢播放位置），true 时恢复
    var isSoundEnabled: Bool = true {
        didSet {
            guard oldValue != isSoundEnabled else { return }
            if isSoundEnabled {
                for (name, player) in players where !player.isPlaying {
                    player.play()
                    logger.info("[Audio] resumed \(name) (sound enabled)")
                }
            } else {
                for (name, player) in players where player.isPlaying {
                    player.pause()
                    logger.info("[Audio] paused \(name) (sound disabled)")
                }
            }
        }
    }

    /// 切换声音开关。等同于 isSoundEnabled.toggle()，提供便捷调用入口。
    func toggleSound() {
        isSoundEnabled.toggle()
    }

    /// 当前注册了哪些循环（用于 UI 调试 / 状态显示）
    var registeredLoops: [String] { Array(players.keys).sorted() }

    private var players: [String: AVAudioPlayer] = [:]

    /// 启动循环。`name` 为不带扩展名的文件名（默认 .m4a），文件位于主 bundle。
    /// 注册成功就保留，`isSoundEnabled == false` 时只 prepare 不 play。
    /// 已注册的同名循环 idempotent：再次调用不会重复加载，只确保按当前开关状态运行。
    func startLoop(named name: String, fileExtension: String = "m4a", volume: Float = 1.0) {
        if let existing = players[name] {
            if isSoundEnabled, !existing.isPlaying {
                existing.play()
                logger.info("[Audio] resumed \(name)")
            }
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            logger.warning("[Audio] file not found in bundle: \(name).\(fileExtension)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = volume
            player.prepareToPlay()
            if isSoundEnabled { player.play() }
            players[name] = player
            logger.info("[Audio] registered \(name) (playing=\(self.isSoundEnabled))")
        } catch {
            logger.error("[Audio] failed to load \(name): \(error.localizedDescription)")
        }
    }

    /// 停止并卸载单个循环
    func stop(named name: String) {
        players[name]?.stop()
        players.removeValue(forKey: name)
        logger.info("[Audio] stopped \(name)")
    }

    /// 停止并卸载所有循环（沉浸场景退出时调用）
    func stopAll() {
        for (name, player) in players {
            player.stop()
            logger.info("[Audio] stopped \(name)")
        }
        players.removeAll()
    }
}
