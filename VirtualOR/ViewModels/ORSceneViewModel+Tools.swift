//
//  ORSceneViewModel+Tools.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/1/3.
//

import Foundation
import RealityKit
import os

private let toolsLogger = Logger(subsystem: "com.app.VirtualOR", category: "ORSceneTools")

extension ORSceneViewModel {
    func printWorldPosition(of entity: Entity) {
        if let position = getWorldPosition(of: entity) {
            toolsLogger.debug("\(entity.name) World position: \(String(describing: position))")
        } else {
            toolsLogger.warning("Cannot find world position for entity")
        }
    }
    
    #if DEBUG
    func printAllEntities() {
        guard let rootEntity = rootEntity else {
            toolsLogger.warning("Root entity is nil")
            return
        }
        print("========== All Entities in Room ==========")
        printEntityHierarchy(rootEntity, indent: "")
        print("========== End of Entities ==========")
    }
    
    func printEntityHierarchy(_ entity: Entity, indent: String) {
        print("\(indent) \(entity.name)")

        for child in entity.children {
            printEntityHierarchy(child, indent: indent + "  ")
        }
    }
    
    func printAllEntityNames() {
        guard let rootEntity = rootEntity else {
            toolsLogger.warning("Root entity is nil")
            return
        }
        
        var entityNames: [String] = []
        collectEntityNames(rootEntity, into: &entityNames)
        
        print("========== All Entity Names ==========")
        for name in entityNames {
            print("- \(name)")
        }
        print("========== Total: \(entityNames.count) entities ==========")
    }
    
    private func collectEntityNames(_ entity: Entity, into names: inout [String]) {
        if !entity.name.isEmpty {
            names.append(entity.name)
        }

        for child in entity.children {
            collectEntityNames(child, into: &names)
        }
    }

    /// 打印所有「tap 能检测到」的实体：同时具备 CollisionComponent 和 InputTargetComponent。
    /// 点击时手势返回的实体一定在这个列表里 —— 点了没反应就对照这里看命中的名字是谁。
    func printTappableEntities() {
        guard let rootEntity = rootEntity else {
            toolsLogger.warning("Root entity is nil")
            return
        }
        var lines: [String] = []
        collectTappable(rootEntity, into: &lines)
        print("========== Tappable Entities (collision + inputTarget) ==========")
        for line in lines {
            print("- \(line)")
        }
        print("========== Total: \(lines.count) tappable ==========")
    }

    private func collectTappable(_ entity: Entity, into lines: inout [String]) {
        let hasCollision = entity.components[CollisionComponent.self] != nil
        let hasInput = entity.components[InputTargetComponent.self] != nil
        if hasCollision {
            let name = entity.name.isEmpty ? "<unnamed>" : entity.name
            let inputMark = hasInput ? "input✓" : "input✗(靠祖先)"
            lines.append("\(name) [\(inputMark)]\(entity.isEnabled ? "" : " [DISABLED]")")
        }
        for child in entity.children {
            collectTappable(child, into: &lines)
        }
    }

    /// 点击没反应时先跑这个：逐一检查关键可点实体是否存在 / enabled / 有碰撞体 / 有 InputTarget。
    /// NOT FOUND = 实体名和场景对不上；collision✗ 或 input✗ = 组件没挂上，点了也不会命中。
    func printTapTargetDiagnostics() {
        guard let rootEntity = rootEntity else {
            toolsLogger.warning("[Diag] rootEntity is nil")
            return
        }
        let groups: [(label: String, names: [String])] = [
            ("drawer", CollidableEntities.drawer),
            ("opTrigger", OperationEntityMap.triggers.map(\.entityName)),
            ("suction", CollidableEntities.suctionCollapsed + CollidableEntities.suctionExpanded),
            ("condTrigger", [AnesMonitor.rubberBall.rawValue, OperationEntityName.patientClothes.rawValue]),
            ("intubation", CollidableEntities.anesUnmasked + CollidableEntities.anesMasked),
        ]
        print("========== Tap Target Diagnostics ==========")
        for (label, names) in groups {
            for name in names {
                guard let e = rootEntity.findEntity(named: name) else {
                    print("[Diag][\(label)] \(name): ❌ NOT FOUND")
                    continue
                }
                let hasCollision = e.components[CollisionComponent.self] != nil
                let hasInput = e.components[InputTargetComponent.self] != nil
                print("[Diag][\(label)] \(name): \(e.isEnabled ? "enabled" : "⚠️ DISABLED") \(hasCollision ? "collision✓" : "⚠️ collision✗") \(hasInput ? "input✓" : "⚠️ input✗") children=\(e.children.count)")
            }
        }
        print("========== End Diagnostics ==========")
    }
    #endif
}
