//
//  OperationEntityMap.swift
//  VirtualOR
//
//  3D 实体名 → ScenarioOperation.id 的映射表。
//  资源里需要为每个 operation 准备一个可点击实体（药瓶、按钮贴片、器械等）；
//  实体名 ready 后填到下面的字典里即可，不需要改 ScenarioRuntime 逻辑。
//

import Foundation

enum OperationEntityMap {
    /// 主操作（state1.operations）+ branch 操作（muscleRelaxant.branchOperations）
    /// 都通过同一个映射；ScenarioRuntime 内部会判断当前是否处于 branch 选择阶段。
    /// state1 主操作：jawThrust / increaseOxygen / maskBagVentilation / propofolIV /
    ///                 muscleRelaxant / directIntubation / noEffectDrugs / antagonistDrugs
    /// muscleRelaxant 后的 branch：noActionAfterRelaxant / onlyBagAfterRelaxant / intubationAfterRelaxant
    static let entityToOperationId: [String: String] = [:]
}
