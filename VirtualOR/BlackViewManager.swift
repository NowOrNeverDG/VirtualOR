//
//  BlackViewManager.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/1/4.
//

import Foundation
import RealityKit
import UIKit
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "ScreenOverlay")

@MainActor
class ScreenOverlayManager {

    struct PanelConfig {
        var width: Float = 0.4
        var height: Float = 0.3
        var offset: SIMD3<Float> = SIMD3(0, 0, 0.01)
        var rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        var color: UIColor = .black
    }

    struct LabelConfig {
        let id: String
        let text: String
        var position: SIMD3<Float> = .zero
        var fontSize: CGFloat = 0.025
        var color: UIColor = .green
    }

    private weak var rootEntity: Entity?
    private var overlays: [String: Entity] = [:]

    init(rootEntity: Entity?) {
        self.rootEntity = rootEntity
    }

    func createOverlay(
        for screenEntityName: String,
        panel: PanelConfig = PanelConfig(),
        labels: [LabelConfig] = []
    ) {
        guard let rootEntity,
              let screenEntity = rootEntity.findEntity(named: screenEntityName) else {
            logger.warning("Screen entity \(screenEntityName) not found")
            return
        }

        removeOverlay(for: screenEntityName)

        let container = Entity()
        container.name = "Overlay_\(screenEntityName)"

        let mesh = MeshResource.generatePlane(width: panel.width, height: panel.height)
        var material = UnlitMaterial()
        material.color = .init(tint: panel.color)

        let panelEntity = ModelEntity(mesh: mesh, materials: [material])
        panelEntity.name = "Panel_\(screenEntityName)"
        container.addChild(panelEntity)

        for label in labels {
            addTextEntity(to: container, config: label)
        }

        screenEntity.addChild(container)
        container.position = panel.offset
        container.orientation = panel.rotation

        overlays[screenEntityName] = container
        logger.debug("Created overlay for \(screenEntityName), panelSize=\(panel.width)x\(panel.height)")
    }

    func updateLabel(
        screenEntityName: String,
        labelId: String,
        newText: String,
        fontSize: CGFloat = 0.025,
        color: UIColor = .green
    ) {
        guard let overlay = overlays[screenEntityName] else { return }

        let labelName = "Label_\(labelId)"
        guard let existing = overlay.findEntity(named: labelName) else { return }

        let position = existing.position
        existing.removeFromParent()

        addTextEntity(
            to: overlay,
            config: LabelConfig(id: labelId, text: newText, position: position, fontSize: fontSize, color: color)
        )
    }

    func removeOverlay(for screenEntityName: String) {
        overlays[screenEntityName]?.removeFromParent()
        overlays.removeValue(forKey: screenEntityName)
    }

    func removeAllOverlays() {
        for (_, overlay) in overlays {
            overlay.removeFromParent()
        }
        overlays.removeAll()
    }

    func setHidden(_ hidden: Bool, for screenEntityName: String) {
        overlays[screenEntityName]?.isEnabled = !hidden
    }

    private func addTextEntity(to parent: Entity, config: LabelConfig) {
        let mesh = MeshResource.generateText(
            config.text,
            extrusionDepth: 0.001,
            font: .monospacedSystemFont(ofSize: config.fontSize, weight: .bold),
            containerFrame: .zero,
            alignment: .left,
            lineBreakMode: .byClipping
        )

        var material = UnlitMaterial()
        material.color = .init(tint: config.color)

        let textEntity = ModelEntity(mesh: mesh, materials: [material])
        textEntity.name = "Label_\(config.id)"
        textEntity.position = config.position

        parent.addChild(textEntity)
    }
}
