//
//  File.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/1/3.
//

import Foundation
import RealityKit

extension ORSceneViewModel {
    func printWorldPosition(of entity: Entity) {
        if let position = getWorldPosition(of: entity) {
            print("[printWorldPosition]: \(entity.name) World position: \(position)")
        } else {
            print("⚠️ [printWorldPosition] Can't not find World position")
        }
    }
    
    func printAllEntities() {
        guard let rootEntity = rootEntity else {
            print("⚠️ [printAllEntities] Root entity is nil")
            return
        }
        print("========== All Entities in Room ========== [printAllEntities]")
        printEntityHierarchy(rootEntity, indent: "")
        print("========== End of Entities ========== [printAllEntities]")
    }
    
    func printEntityHierarchy(_ entity: Entity, indent: String) {
        print("[printEntityHierarchy]\(indent)📦 \(entity.name)")

        for child in entity.children {
            printEntityHierarchy(child, indent: indent + "  ")
        }
    }
    
    func printAllEntityNames() {
        guard let rootEntity = rootEntity else {
            print("⚠️ [printAllEntityNames] Root entity is nil")
            return
        }
        
        var entityNames: [String] = []
        collectEntityNames(rootEntity, into: &entityNames)
        
        print("========== All Entity Names ========== [printAllEntityNames]")
        for name in entityNames {
            print("- \(name)")
        }
        print("========== Total: \(entityNames.count) entities ========== [printAllEntityNames]")
    }
    
    func collectEntityNames(_ entity: Entity, into names: inout [String]) {
        if !entity.name.isEmpty {
            names.append(entity.name)
        }
        
        for child in entity.children {
            collectEntityNames(child, into: &names)
        }
    }
}
