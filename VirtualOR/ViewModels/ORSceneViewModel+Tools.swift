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
        //printEntityHierarchy(rootEntity, indent: "")
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
    #endif
}
