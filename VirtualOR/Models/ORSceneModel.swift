//
//  ORSceneModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/2/1.
//

import Foundation

// 实体名枚举（Suction / Drawer / Anes / OperationEntityName / SceneAsset）集中在
// EntityName.swift。本文件只放派生的实体分组（CollidableEntities）与抽屉→药品映射（DrugMap）。

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
