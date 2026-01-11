//
//  ORSceneViewModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/11/29.
//

import Foundation
import RealityKit
import RealityKitContent
import _RealityKit_SwiftUI

class ORSceneViewModel: ObservableObject {
    @Published var rootEntity: Entity?
    
    // 记录每个 drawer 的打开状态
    private var drawerStates: [String: Bool] = [:]
    private let drawerOpenDistance: Float = 1  // 打开时的 Z 轴移动距离
    
    // 记录管子的展开/卷起状态
    private var isPipesExpanded: Bool = false
    
    @discardableResult
    func loadRoomIfNeeded() async -> Entity? {
        if rootEntity != nil { return rootEntity }

        do {
            let room = try await Entity(named: "OR11299", in: realityKitContentBundle)
            await room.generateCollisionShapes(recursive: true)
            self.rootEntity = room
            printAllEntities()
            return rootEntity
        } catch {
            print("Error:[ORSceneViewModel.loadRoomIfNeeded] Failed to load ORScene:", error)
        }
        
        
        return nil
    }
    
    func getRoomEntity() -> Entity? {
        return rootEntity
    }
    
    func getWorldPosition(of entity: Entity) -> SIMD3<Float>? {
        return entity.position(relativeTo: nil)
    }
    
    func generateAllCollisionShapes() {
        makeEntitiesCollidable(CollidableEntities.rollUpPipes)
        makeEntitiesCollidable(CollidableEntities.bentPipes)
        makeEntitiesCollidable(CollidableEntities.drawer)
        makeEntitiesCollidable(CollidableEntities.AnesAdjustButton)
        makeEntitiesCollidable([CollidableEntities.mainScreen, CollidableEntities.submainScreen])
        // 初始状态：隐藏展开的管子，只显示卷起的管子
        hideEntities(CollidableEntities.rollUpPipes)
        showEntities(CollidableEntities.bentPipes)
        isPipesExpanded = false
    }
    
    func handleTapGesture(entity: Entity) {
        guard let name = entity.name as String? else { return }
        print("Tapped entity: \(name)")
        
        switch name {
        case "drawer_1", "drawer_2", "drawer_3", "drawer_4", "drawer_5":
            toggleDrawer(entity)
        case "bent_pipe":
            // 点击卷起的管子，展开它
            expandPipes()
        case "pipe_1", "pipe_2", "pipe_connection":
            // 点击任意展开的管子，卷起所有管子
            collapsePipes()
        default:
            break
        }
    }
    
    // 展开管子
    private func expandPipes() {
        if !isPipesExpanded {
            hideEntities(CollidableEntities.bentPipes)
            showEntities(CollidableEntities.rollUpPipes)
            isPipesExpanded = true
            print("[Pipes] Expanded")
        }
    }
    
    // 卷起管子
    private func collapsePipes() {
        if isPipesExpanded {
            hideEntities(CollidableEntities.rollUpPipes)
            showEntities(CollidableEntities.bentPipes)
            isPipesExpanded = false
            print("[Pipes] Collapsed")
        }
    }
    
    // 切换 drawer 的打开/关闭状态
    private func toggleDrawer(_ entity: Entity) {
        let entityName = entity.name
        let isCurrentlyOpen = drawerStates[entityName] ?? false
        
        if isCurrentlyOpen {
            // 关闭 drawer
            closeDrawer(entity)
        } else {
            // 打开 drawer
            openDrawer(entity)
        }
    }
    
    // 打开 drawer（Z 轴正方向移动）
    private func openDrawer(_ entity: Entity) {
        let entityName = entity.name
        moveZInWorld(entity, delta: -drawerOpenDistance)
        drawerStates[entityName] = true
        print("[\(entityName)] Drawer opened")
    }
    
    // 关闭 drawer（Z 轴负方向移动回原位）
    private func closeDrawer(_ entity: Entity) {
        let entityName = entity.name
        moveZInWorld(entity, delta: drawerOpenDistance)
        drawerStates[entityName] = false
        print("[\(entityName)] Drawer closed")
    }
    
    func moveXInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.x += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved X: \(oldPosition.x) -> \(transform.translation.x)")
    }
    
    func moveYInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.y += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved Y: \(oldPosition.y) -> \(transform.translation.y)")
    }
    
    func moveZInWorld(_ entity: Entity, delta: Float) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation.z += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved Z: \(oldPosition.z) -> \(transform.translation.z)")
    }
    
    func moveInWorld(_ entity: Entity, delta: SIMD3<Float>) {
        var transform = entity.transform
        let oldPosition = transform.translation
        transform.translation += delta
        entity.move(to: transform, relativeTo: entity.parent, duration: 0, timingFunction: .linear)
        print("[\(entity.name)] Moved: \(oldPosition) -> \(transform.translation)")
    }
}

extension ORSceneViewModel {
    private func makeEntitiesCollidable(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                print("⚠️ [ORSceneViewModel] Entity named \(name) not found under rootEntity")
                continue
            }
            
            entity.isEnabled = true
            
            if entity.components[CollisionComponent.self] == nil {
                let shape = ShapeResource.generateBox(size: .one)
                let collision = CollisionComponent(shapes: [shape])
                entity.components.set(collision)
            }
            
            if entity.components[InputTargetComponent.self] == nil {
                entity.components.set(InputTargetComponent())
            }
        }
    }
    
    private func hideEntities(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                print("⚠️ [ORSceneViewModel] Entity named \(name) not found for hiding")
                continue
            }
            entity.isEnabled = false
        }
    }
    
    private func showEntities(_ names: [String]) {
        guard let rootEntity = rootEntity else { return }
        
        for name in names {
            guard let entity = rootEntity.findEntity(named: name) else {
                print("⚠️ [ORSceneViewModel] Entity named \(name) not found for showing")
                continue
            }
            entity.isEnabled = true
        }
    }
    
    
    
    // 打印所有 room 的 entity 及其层级结构
    func printAllEntities() {
        guard let rootEntity = rootEntity else {
            print("⚠️ [ORSceneViewModel] Root entity is nil")
            return
        }
        print("========== All Entities in Room ==========")
        printEntityHierarchy(rootEntity, indent: "")
        print("========== End of Entities ==========")
    }
    
    // 递归打印 entity 层级（简洁版本）
    private func printEntityHierarchy(_ entity: Entity, indent: String) {
        print("\(indent)📦 \(entity.name)")
        
        // 递归打印子 entity
        for child in entity.children {
            printEntityHierarchy(child, indent: indent + "  ")
        }
    }
    
    // 打印所有子件的名称列表（平铺版本）
    func printAllEntityNames() {
        guard let rootEntity = rootEntity else {
            print("⚠️ [ORSceneViewModel] Root entity is nil")
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
    
    // 收集所有 entity 的名称
    private func collectEntityNames(_ entity: Entity, into names: inout [String]) {
        if !entity.name.isEmpty {
            names.append(entity.name)
        }
        
        for child in entity.children {
            collectEntityNames(child, into: &names)
        }
    }
}


/*
 展开：pipe_1 pipe_2 pipe_connection
 卷起：bent_pipe
 
 抽屉：drawer_1 drawer_2 drawer_3 drawer_4 drawer_5
 
 麻醉气体调节按钮：Knob_001
*/
struct CollidableEntities {
    static var rollUpPipes: [String] = ["pipe_1","pipe_2","pipe_connection"]
    static var bentPipes: [String] = ["bent_pipe"]
    
    static var drawer: [String] = ["drawer_1","drawer_2","drawer_3","drawer_4","drawer_5"]
    
    static var AnesAdjustButton: [String] = ["Knob_001"]
    static var mainScreen: String = "Monitor_1_003"
    static var submainScreen: String = "Monitor_1_004"
}
