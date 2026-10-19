//
//  OperationEntityMap.swift
//  VirtualOR
//
//  3D 实体名 → CourseOperation.id 的映射（协议化 / POP）。
//
//  设计：每个「点击实体 → 触发 operation」绑定都遵守 OperationTrigger 协议，
//  统一收在 OperationEntityMap.triggers。要接入新的可点操作，只需新增一个遵守
//  OperationTrigger 的类型并 append 到 triggers，路由逻辑（handleTapGesture →
//  runtime.perform）完全不用改。
//
//  实体名（含 OperationEntityName 占位）集中在 EntityName.swift；本文件只做映射逻辑。
//

import Foundation

/// 一个「点击 3D 实体 → 触发剧情 operation」的绑定。
protocol OperationTrigger {
    /// 被点击的 3D 实体名
    var entityName: String { get }
    /// 对应的 CourseOperation.id（state1 主操作或 branch 子操作）
    var operationId: String { get }
}

/// state1 主操作的可点实体绑定（点击即触发，无前置条件）。
/// 有前置条件的操作不在此列，由 ORSceneViewModel 守门后调 runtime：
///   - 四种药（propofolIV / noEffectDrugs / antagonistDrugs / muscleRelaxant）：
///     抽屉拿药只是持有，手持药品点人体衣服（steve_clothes_002）才"服用"触发（DrugMap）
///   - maskBagVentilation / onlyBagAfterRelaxant：点球囊（monitor_rubber_ball），按肌松药是否已服用分流
///   - intubationAfterRelaxant / directIntubation：手持喉镜 + 气管导管点人体（steve_001），按肌松药是否已服用分流
enum StateOneOperationTrigger: CaseIterable, OperationTrigger {
    case jawThrust
    case increaseOxygen

    var operationId: String {
        switch self {
        case .jawThrust:        "jawThrust"
        case .increaseOxygen:   "increaseOxygen"
        }
    }

    var entityName: String {
        switch self {
        case .jawThrust:        OperationEntityName.humanModel.rawValue   // steve_001
        case .increaseOxygen:   AnesMonitor.autoButton.rawValue           // monitor_knob_001
        }
    }
}

enum OperationEntityMap {
    /// 所有「实体 → operation」绑定的唯一来源。
    /// 接新操作：新增遵守 OperationTrigger 的类型，map 成 existential 后并进来。
    static let triggers: [any OperationTrigger] =
        StateOneOperationTrigger.allCases.map { $0 as any OperationTrigger }

    /// 反查：被点实体名 → operationId（无绑定返回 nil）。
    static func operationId(for entityName: String) -> String? {
        triggers.first { $0.entityName == entityName }?.operationId
    }
}
