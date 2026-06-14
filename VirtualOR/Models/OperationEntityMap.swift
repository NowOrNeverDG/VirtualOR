//
//  OperationEntityMap.swift
//  VirtualOR
//
//  3D 实体名 → ScenarioOperation.id 的映射（协议化 / POP）。
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
    /// 对应的 ScenarioOperation.id（state1 主操作或 branch 子操作）
    var operationId: String { get }
}

/// state1 主操作的可点实体绑定。
enum StateOneOperationTrigger: CaseIterable, OperationTrigger {
    case jawThrust
    case increaseOxygen
    case propofolIV
    case noEffectDrugs
    case antagonistDrugs
    case muscleRelaxant

    var operationId: String {
        switch self {
        case .jawThrust:        "jawThrust"
        case .increaseOxygen:   "increaseOxygen"
        case .propofolIV:       "propofolIV"
        case .noEffectDrugs:    "noEffectDrugs"
        case .antagonistDrugs:  "antagonistDrugs"
        case .muscleRelaxant:   "muscleRelaxant"
        }
    }

    var entityName: String {
        switch self {
        case .jawThrust:        OperationEntityName.humanModel.rawValue   // steve_001
        case .increaseOxygen:   AnesMonitor.autoButton.rawValue           // monitor_knob_001
        case .propofolIV:       Drawer.drawer2.rawValue                   // drawer_2     → Propofol
        case .noEffectDrugs:    Drawer.drawer3.rawValue                   // drawer_003   → Salbutamol
        case .antagonistDrugs:  Drawer.drawer4.rawValue                   // drawer_004   → 氟马西尼/纳洛酮
        case .muscleRelaxant:   Drawer.drawer5.rawValue                   // drawer_005   → 肌松药
        }
    }
}

/// muscleRelaxant 之后 branch 三选一里「靠点击实体触发」的两个选项。
/// runtime 在点过 muscleRelaxant 后进入 branch 守门（pendingBranchParent），
/// 此时点击这两个实体之一即被解析为对应 branch 子操作 → 决定走 state4 / end。
/// （第三个 noActionAfterRelaxant 是不作为超时，无点击实体。）
enum MuscleRelaxantBranchTrigger: CaseIterable, OperationTrigger {
    case intubation   // 气管插管（含球囊）→ 成功弹窗 → 课程结束
    case onlyBag      // 仅手捏球囊通气     → state4（生命体征恢复）

    var operationId: String {
        switch self {
        case .intubation:  "intubationAfterRelaxant"
        case .onlyBag:     "onlyBagAfterRelaxant"
        }
    }

    var entityName: String {
        switch self {
        case .intubation:  OperationEntityName.intubationTool.rawValue
        case .onlyBag:     OperationEntityName.bagDevice.rawValue
        }
    }
}

enum OperationEntityMap {
    /// 所有「实体 → operation」绑定的唯一来源。
    /// 接新操作：新增遵守 OperationTrigger 的类型，map 成 existential 后并进来。
    static let triggers: [any OperationTrigger] =
        StateOneOperationTrigger.allCases.map { $0 as any OperationTrigger } +
        MuscleRelaxantBranchTrigger.allCases.map { $0 as any OperationTrigger }

    /// 反查：被点实体名 → operationId（无绑定返回 nil）。
    static func operationId(for entityName: String) -> String? {
        triggers.first { $0.entityName == entityName }?.operationId
    }
}
