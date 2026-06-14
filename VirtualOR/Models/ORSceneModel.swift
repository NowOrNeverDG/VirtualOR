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
    case drawer3 = "drawer_003"
    case drawer4 = "drawer_004"
    case drawer5 = "drawer_005"
    
    //面罩
    case maskPart1 = "face_shield_drawer_001"
    case maskPart2 = "face_shield_drawer_002"
    case maskPart3 = "face_shield_drawer_003"
    case maskPart4 = "face_shield_drawer_004"
    
    //听诊器
    case stethoscope1 = "stethoscope_001"
    case stethoscope2 = "stethoscope_002"
    case stethoscope3 = "stethoscope_003"
    case stethoscope4 = "stethoscope_004"
    case stethoscope5 = "stethoscope_005"
    case stethoscope6 = "stethoscope_006"
    case stethoscope7 = "stethoscope_007"

    //喉镜
    case laryngoscope1 = "laryngoscope_001"
    case laryngoscope2 = "laryngoscope_002"
    case laryngoscope3 = "laryngoscope_003"
    case laryngoscope4 = "laryngoscope_004"
    
    //咽口痛
    case oropTube1 = "orop_tube_001"
    case oropTube2 = "orop_tube_002"
    
    //呼吸气球
    case respBalloon1 = "balloom_001"
    case respBalloon2 = "balloom_002"
    case respBalloon3 = "balloom_003"
    case respBalloon4 = "balloom_004"
    case respBalloon5 = "balloom_005"

    case laryngealMask1 = "mask_001"
    case laryngealMask2 = "mask_002"
    case laryngealMask3 = "mask_003"
    case laryngealMask4 = "mask_004"
    
    case laryngealDuct1 = "duct_001"
    case laryngealDuct2 = "duct_002"
    case laryngealDuct3 = "duct_003"
    case laryngealDuct4 = "duct_004"
    case laryngealDuct5 = "duct_005"
}

enum Anes: String {
    case autoButton = "monitor_knob_001"
    case manualButton = "monitor_knob_005"
    case manualTrigger = "monitor_knob_trigger"
    case mainScreen = "monitor_screen"
    case submainScreen = "monitor_subscreen"
    case masked = "monitor_face_shield_mask"
    case unmaskedPipe = "monitor_SPO_003"
    case unmaskedPart1 = "face_shield_monitor_001"
    case unmaskedPart2 = "face_shield_monitor_002"
    case unmaskedPart3 = "face_shield_monitor_003"
    case unmaskedPart4 = "face_shield_monitor_004"

}

enum CollidableEntities {
    static var suctionExpanded: [String] = [Suction.pipeRollUpTop, Suction.pipeRollUpBottom, Suction.pipeConnection].map { $0.rawValue }
    static var suctionCollapsed: [String] = [Suction.bentPipe].map { $0.rawValue }
    static var drawer: [String] = [Drawer.drawer1,Drawer.drawer2,Drawer.drawer3, Drawer.drawer4, Drawer.drawer5].map { $0.rawValue }
    static var anesAdjustButton: [String] = [Anes.autoButton, Anes.manualButton].map{ $0.rawValue}
    static var mainScreen: String = Anes.mainScreen.rawValue
    static var submainScreen: String = Anes.submainScreen.rawValue
    static var anesMasked: [String] = [Anes.masked].map { $0.rawValue }
    static var anesUnmasked: [String] = [Anes.unmaskedPipe, Anes.unmaskedPart1, Anes.unmaskedPart2, Anes.unmaskedPart3, Anes.unmaskedPart4].map { $0.rawValue }

    /// 器械分组：每组包含显示名称和所有部件实体名
    struct InstrumentGroup {
        let displayName: String
        let entityNames: [String]
    }

    static let instrumentGroups: [InstrumentGroup] = [
        InstrumentGroup(displayName: "Stethoscope", entityNames:
            [Drawer.stethoscope1, .stethoscope2, .stethoscope3, .stethoscope4, .stethoscope5, .stethoscope6, .stethoscope7].map { $0.rawValue }),
        InstrumentGroup(displayName: "Laryngoscope", entityNames:
            [Drawer.laryngoscope1, .laryngoscope2, .laryngoscope3, .laryngoscope4].map { $0.rawValue }),
        InstrumentGroup(displayName: "Oropharyngeal Tube", entityNames:
            [Drawer.oropTube1, .oropTube2].map { $0.rawValue }),
        InstrumentGroup(displayName: "Breathing Balloon", entityNames:
            [Drawer.respBalloon1, .respBalloon2, .respBalloon3, .respBalloon4, .respBalloon5].map { $0.rawValue }),
        InstrumentGroup(displayName: "Laryngeal Mask", entityNames:
            [Drawer.laryngealMask1, .laryngealMask2, .laryngealMask3, .laryngealMask4].map { $0.rawValue }),
        InstrumentGroup(displayName: "Laryngeal Duct", entityNames:
            [Drawer.laryngealDuct1, .laryngealDuct2, .laryngealDuct3, .laryngealDuct4, .laryngealDuct5].map { $0.rawValue }),
    ]

    /// 所有可拾取的实体名（扁平列表，用于碰撞体生成）
    static var pickableInstruments: [String] = instrumentGroups.flatMap { $0.entityNames }

    /// 实体名 → 所属器械组（点击任一部件即可找到整组）
    static var entityToGroup: [String: InstrumentGroup] = {
        var map: [String: InstrumentGroup] = [:]
        for group in instrumentGroups {
            for name in group.entityNames {
                map[name] = group
            }
        }
        return map
    }()
}

/// 抽屉 → 药品的映射。打开对应抽屉即"拿起"该药品（HUD holdingItem 切换）。
/// 没有 3D 药品模型，所以拿药只更新 hold 文字 + 还原原本手持的器械（如果有）。
enum DrugMap {
    static let drawerToDisplayName: [String: String] = [
        Drawer.drawer2.rawValue: "Propofol 丙泊酚",
        Drawer.drawer3.rawValue: "Salbutamol 沙丁胺醇",
        Drawer.drawer4.rawValue: "Flumazenil/Naloxone 氟马西尼/纳洛酮",
        Drawer.drawer5.rawValue: "Muscle Relaxant 肌松药",
    ]
}
