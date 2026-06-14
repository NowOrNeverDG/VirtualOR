//
//  EntityName.swift
//  VirtualOR
//
//  3D 实体名的唯一注册处。Reality Composer Pro 里改了实体名，只动这个文件即可，
//  全工程其它地方都通过这些枚举的 rawValue 引用，不出现裸字符串。
//
//  - Suction              吸引器（展开 pipe_1/2/connection、卷起 bent_pipe）
//  - Drawer               5 个抽屉本体 + 抽屉内各类器械部件
//  - AnesMonitor          麻醉监护仪按钮 / 屏幕 / 面罩相关
//  - OperationEntityName   散装的操作触发实体（人体模型 / branch 占位）
//  - SceneAsset           RealityKitContent 里的场景资源名
//
//  派生的分组与映射（CollidableEntities / DrugMap）见 ORSceneModel.swift；
//  实体 → 剧情操作的 POP 映射见 OperationEntityMap.swift。
//

import Foundation

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

enum AnesMonitor: String {
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

/// 触发剧情 operation 的散装实体名（Drawer / AnesMonitor 已有归属的不在此列）。
enum OperationEntityName: String {
    case humanModel = "steve_001"               // 人体模型：托下颌

    // —— muscleRelaxant 之后 branch 三选一里「靠点击触发」的实体（占位，待补真实名）——
    case intubationTool = "TODO_intubation"     // 气管插管
    case bagDevice      = "TODO_bag_squeeze"    // 仅手捏球囊通气
    // noActionAfterRelaxant 是「肌松后不作为」的超时路径，无点击实体，故不收录
}

/// RealityKitContent 包里的场景资源名。
enum SceneAsset {
    static let orScene = "ORScene"
}
