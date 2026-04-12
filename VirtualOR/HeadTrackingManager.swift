//
//  HeadTrackingManager.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/4/12.
//

import ARKit
import QuartzCore
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "HeadTracking")

@MainActor
@Observable
class HeadTrackingManager {
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()

    private(set) var isRunning = false

    func start() async {
        guard !isRunning else { return }

        do {
            try await session.run([worldTracking])
            isRunning = true
            logger.info("Head tracking started")
        } catch {
            logger.error("Failed to start head tracking: \(error.localizedDescription)")
        }
    }

    func queryDeviceAnchor() -> simd_float4x4? {
        guard isRunning,
              let anchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        return anchor.originFromAnchorTransform
    }
}
