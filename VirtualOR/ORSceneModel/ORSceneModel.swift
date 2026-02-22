//
//  ORSceneModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/2/1.
//

import Foundation
/*
 吸引器
 展开：pipe_1 pipe_2 pipe_connection
 卷起：bent_pipe
 
 抽屉
 drawer_1 drawer_2 drawer_3 drawer_4 drawer_5
*/

enum Suction: String {
    case pipeRollUpTop = "pipe_1"
    case pipeRollUpBottom = "pipe_2"
    case pipeConnection = "pipe_connection"
    case bentPipe = "bent_pipe"
}

enum Drawer: String {
    case drawer1 = "drawer_1"
    case drawer2 = "drawer_2"
    case drawer3 = "drawer_3"
    case drawer4 = "drawer_4"
    case drawer5 = "drawer_5"
}

enum Anes: String {
    case autoButton = "knob.001"//knob.001=旋转钮，knob=扳机钮
    case manualButton = "knob"
    case mainScreen = "Monitor_1.003"
    case submainScreen = "Monitor_1.004"
    case masked = "Knob_1.002"
    case unmasked = "Knob_1.001"
}

enum CollidableEntities {
    static var suctionExpanded: [String] = [Suction.pipeRollUpTop, Suction.pipeRollUpBottom, Suction.pipeConnection].map { $0.rawValue }
    static var suctionCollapsed: [String] = [Suction.bentPipe].map { $0.rawValue }
    static var drawer: [String] = [Drawer.drawer1,Drawer.drawer2,Drawer.drawer3, Drawer.drawer4, Drawer.drawer5].map { $0.rawValue }
    static var anesAdjustButton: [String] = [Anes.autoButton, Anes.manualButton].map{ $0.rawValue}
    static var mainScreen: String = Anes.mainScreen.rawValue
    static var submainScreen: String = Anes.submainScreen.rawValue
    static var anesMasked: [String] = [Anes.masked].map { $0.rawValue }
    static var anesUnmasked: [String] = [Anes.unmasked].map { $0.rawValue }
}
