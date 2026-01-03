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
            print("\(entity.name) World position: \(position)")
        } else {
            print("Error: [ORSceneViewModel.printWorldPosition] Can't not find World position")
        }
    }
}
