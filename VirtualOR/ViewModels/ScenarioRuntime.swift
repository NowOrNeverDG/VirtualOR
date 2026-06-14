//
//  ScenarioRuntime.swift
//  VirtualOR
//
//  剧情状态机运行时（Phase 1）：
//  - 状态切换（initial → state1 → state2/3/4/end）
//  - operation 触发（绝对值 / delta / popup / targetState / branch）
//  - 操作日志（只记录不展示）
//
//  Phase 2 待加：state1 退化线性插值、effect.duration boost、onNoOperation 超时、tick 循环
//  Phase 3 待加：autoVideo 播放、courseEnd 总结视图
//

import Foundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "ScenarioRuntime")

@MainActor
@Observable
final class ScenarioRuntime {
    private(set) var currentStateId: String = ""
    private(set) var currentStateName: String = ""
    private(set) var activePopup: Popup?
    private(set) var pendingBranchParent: String?
    private(set) var log: [OperationLogEntry] = []
    private(set) var isCourseEnded: Bool = false

    private weak var scene: ORSceneViewModel?
    private var scenario: Scenario?
    private var currentMonitor: Monitor = .zero
    private var pendingTargetState: String?

    func start(scene: ORSceneViewModel, scenario: Scenario) {
        self.scene = scene
        self.scenario = scenario
        self.currentMonitor = scenario.initialState.monitor
        // Phase 1：没有 10s 倒计时，直接进入第一个 state（通常是 state1）
        if let firstState = scenario.states.first {
            transition(to: firstState.id)
        }
    }

    func perform(operationId: String) {
        guard !isCourseEnded else {
            logger.debug("Course ended, ignoring \(operationId)")
            return
        }
        guard activePopup == nil else {
            logger.debug("Popup active, ignoring \(operationId)")
            return
        }
        guard let op = resolveOperation(id: operationId) else {
            logger.warning("Operation not available in current state/branch: \(operationId)")
            return
        }
        applyOperation(op)
    }

    func dismissPopup() {
        activePopup = nil
        if let next = pendingTargetState {
            pendingTargetState = nil
            transition(to: next)
        }
    }

    // MARK: - Private

    private func resolveOperation(id: String) -> ScenarioOperation? {
        guard let state = currentScenarioState() else { return nil }
        if let parentId = pendingBranchParent {
            let parent = state.operations?.first { $0.id == parentId }
            return parent?.branchOperations?.first { $0.id == id }
        }
        return state.operations?.first { $0.id == id }
    }

    private func applyOperation(_ op: ScenarioOperation) {
        log.append(OperationLogEntry(opId: op.id, timestamp: Date(), stateId: currentStateId))
        logger.debug("Perform op: \(op.id) (\(op.name))")

        if let change = op.effect?.monitorChange {
            currentMonitor = currentMonitor.applying(change)
            scene?.applyMonitor(currentMonitor)
        }

        if op.branchOperations != nil {
            pendingBranchParent = op.id
            return
        }

        if let popup = op.popup {
            activePopup = popup
            pendingTargetState = op.targetState
            pendingBranchParent = nil
            return
        }

        if let target = op.targetState {
            pendingBranchParent = nil
            transition(to: target)
            return
        }

        // 普通操作（无 branch / popup / target），结束 branch 模式（如果在）
        pendingBranchParent = nil
    }

    private func transition(to stateId: String) {
        currentStateId = stateId
        if stateId == scenario?.endState.id {
            currentStateName = "课程结束"
            isCourseEnded = true
            return
        }
        guard let state = scenario?.states.first(where: { $0.id == stateId }) else {
            logger.warning("State not found: \(stateId)")
            return
        }
        currentStateName = state.name
        let monitor: Monitor
        switch state.monitor {
        case .flat(let m):
            monitor = m
        case .degradable(let initial, _, _):
            monitor = initial
        }
        currentMonitor = monitor
        scene?.applyMonitor(monitor)
    }

    private func currentScenarioState() -> ScenarioState? {
        scenario?.states.first { $0.id == currentStateId }
    }
}

struct OperationLogEntry {
    let opId: String
    let timestamp: Date
    let stateId: String
}

// MARK: - 操作触发入口
//
// 每个临床操作一个方法，方便外部调用方按自己的触发方式（3D tap / 语音 / 手势 / 按钮）
// 直接调用对应方法。底层都走 perform(operationId:)，分支守门、popup、状态切换、
// 日志记录都由 perform 统一处理。
//
// 调用合法性（当前状态是否允许、是否处于 branch 模式、是否被 popup 阻塞）由 perform
// 自动判断，调用方不需要预检。

extension ScenarioRuntime {
    /// 托下颌 —— NIBP +10/+5、HR +20、RR +3
    func triggerJawThrust() { perform(operationId: "jawThrust") }

    /// 提高吸氧浓度（面罩吸氧）—— SPO2 +3、HR -5
    func triggerIncreaseOxygen() { perform(operationId: "increaseOxygen") }

    /// 面罩加压给氧（手捏球囊）—— SPO2 -5、HR +10
    func triggerMaskBagVentilation() { perform(operationId: "maskBagVentilation") }

    /// 静脉注射丙泊酚 —— NIBP -10/-5、SPO2 -5、HR -10、RR -2
    func triggerPropofolIV() { perform(operationId: "propofolIV") }

    /// 使用肌松药（罗库溴铵 / 顺阿曲库铵）—— 进入 branch 选择阶段
    func triggerMuscleRelaxant() { perform(operationId: "muscleRelaxant") }

    /// 不使用肌松药直接气管插管 —— 弹错误弹窗 + 记违规日志
    func triggerDirectIntubation() { perform(operationId: "directIntubation") }

    /// 沙丁胺醇 / 甲泼尼龙 / 地塞米松 —— 无效药物，生命体征无变化
    func triggerNoEffectDrugs() { perform(operationId: "noEffectDrugs") }

    /// 氟马西尼 / 纳洛酮（拮抗药）—— 无效，生命体征无变化
    func triggerAntagonistDrugs() { perform(operationId: "antagonistDrugs") }

    // MARK: - muscleRelaxant 之后的 branch（必须先 triggerMuscleRelaxant）

    /// 未进行插管 / 捏球囊 —— 跳 state3（呼吸抑制）
    func triggerNoActionAfterRelaxant() { perform(operationId: "noActionAfterRelaxant") }

    /// 仅手捏球囊通气 —— 跳 state4（生命体征恢复）
    func triggerOnlyBagAfterRelaxant() { perform(operationId: "onlyBagAfterRelaxant") }

    /// 气管插管（含球囊通气）—— 弹成功弹窗 + 课程结束
    func triggerIntubationAfterRelaxant() { perform(operationId: "intubationAfterRelaxant") }
}

private extension Monitor {
    static let zero = Monitor(
        nibp: NIBP(systolic: 0, diastolic: 0),
        spo2: 0,
        hr: 0,
        rr: 0,
        temperature: 0
    )
}
