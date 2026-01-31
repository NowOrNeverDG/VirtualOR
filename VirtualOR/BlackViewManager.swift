//
//  BlackViewManager.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/1/4.
//

import Foundation
import RealityKit
import UIKit

class BlackViewManager {
    private weak var rootEntity: Entity?
    private var blackView: ModelEntity?
    
    private let size: SIMD3<Float>
    private let offsetZ: Float
    private let color: UIColor
    
    init(rootEntity: Entity?, size: SIMD3<Float> = [1.0, 1.0, 0.01], offsetZ: Float = 5.0, color: UIColor = .black) {
        self.rootEntity = rootEntity
        self.size = size
        self.offsetZ = offsetZ
        self.color = color
    }
    
    func showBlackView(inFrontOf entity: Entity) {
        guard let rootEntity else { return }
        removeBlackView()
        
        let mesh = MeshResource.generateBox(size: size)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.metallic = .init(floatLiteral: 0.0)
        
        let blackView = ModelEntity(mesh: mesh, materials: [material])
        blackView.name = "BlackView"
        
        rootEntity.addChild(blackView)
        
        let targetPos = entity.position(relativeTo: nil) + SIMD3(0, 0, offsetZ)
        blackView.setPosition(targetPos, relativeTo: nil)
        
        self.blackView = blackView
    }
    
    func removeBlackView() {
        blackView?.removeFromParent()
        blackView = nil
    }
    
    func setHidden(_ hidden: Bool) {
        blackView?.isEnabled = !hidden
    }
    
    func updatePosition(inFrontOf entity: Entity) {
        guard let blackView else { return }
        let targetPos = entity.position(relativeTo: nil) + SIMD3(0, 0, offsetZ)
        blackView.setPosition(targetPos, relativeTo: nil)
    }
    
    func cleanup() {
        removeBlackView()
    }
}
