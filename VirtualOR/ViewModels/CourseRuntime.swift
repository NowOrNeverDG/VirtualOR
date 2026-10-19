//
//  CourseRuntime.swift
//  VirtualOR
//
//  剧情状态机运行时（Phase 1 + Phase 2）：
//  - 状态切换（initial → state1 → state2/3/4/end）
//  - operation 触发（绝对值 / delta / popup / targetState / branch）
//  - 操作日志（只记录不展示）
//  - state1 退化线性插值（initial → degradeTo，按 degradeDuration 走，0.1s 一 tick）
//  - effect.duration 渐变（操作生效值按 duration 秒线性过渡；无 duration 则瞬间生效）
//  - onNoOperation 超时（state.duration 秒后若仍停留在该 state，自动 transition）
//
//  Phase 3 待加：courseEnd 总结视图（autoVideo 播放已在 AppModel/ImmersiveView 实现）
//

import Foundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "CourseRuntime")

@MainActor
@Observable
final class CourseRuntime {
    private(set) var currentStateId: String = ""
    private(set) var currentStateName: String = ""
    private(set) var activePopup: Popup?
    private(set) var pendingBranchParent: String?
    private(set) var log: [OperationLogEntry] = []
    private(set) var isCourseEnded: Bool = false
    /// 课程剩余秒数（从 course.totalDuration 起倒数，HUD 左上角倒计时绑定）
    private(set) var remainingSeconds: Int = 0

    private weak var scene: ORSceneViewModel?
    private var course: Course?
    private var currentMonitor: Monitor = .zero
    private var pendingTargetState: String?

    private var stateTimerTask: Task<Void, Never>?
    private var courseTimerTask: Task<Void, Never>?
    /// state3（肌松后无有效通气）停留 30s 还没有后续（state3 本身没有 operations，
    /// 走不出去）就强制结束课程。时长写死在这（取自需求文档），没有接进 resource.json；
    /// 后端 ready 后如需可调，再给 state3 加个类似 onNoOperation 的字段。
    private var state3EndTask: Task<Void, Never>?
    private static let state3EndDelay: TimeInterval = 30
    private var degradeCurve: DegradeCurve?
    private var activeEffect: EffectRamp?
    /// 无退化曲线（flat state）时渐变叠加的基线
    private var flatBase: Monitor = .zero

    /// state.monitor 是 .degradable 时的持续退化曲线：从 fromValue（会在 effect 渐变完成后被重置）
    /// 线性走到 toValue，deadline 是进入该 state 时就定死的绝对时间（不随 effect 变化）。
    private struct DegradeCurve {
        var fromValue: Monitor
        var fromTime: Date
        let toValue: Monitor
        let toTime: Date
    }

    /// 一次 operation effect 的渐变：触发时刻算出差值，按进度叠加到基线上。
    /// 同时只有一个渐变；新操作会打断进行中的渐变（已走的部分冻结保留，剩余丢弃）。
    private struct EffectRamp {
        let delta: MonitorDelta
        let fromTime: Date
        let duration: TimeInterval
        let onComplete: () -> Void
    }

    /// - Parameter enforceTimeLimit: 是否启用课程级倒计时强制结束（到点弹超时弹窗）。
    ///   教学模式不限时，传 false 就不会启动这个计时器；考核模式才要传 true。
    func start(scene: ORSceneViewModel, course: Course, enforceTimeLimit: Bool = true) {
        self.scene = scene
        self.course = course
        self.currentMonitor = course.initialState.monitor
        self.remainingSeconds = course.totalDuration
        if enforceTimeLimit {
            startCourseCountdown()
        }
        // Phase 1：没有 10s 倒计时，直接进入第一个 state（通常是 state1）
        if let firstState = course.states.first {
            transition(to: firstState.id)
        }
    }

    func perform(operationId: String) {
        guard !isCourseEnded else {
            logger.info("[Op] 课程已结束，忽略 \(operationId)")
            return
        }
        guard activePopup == nil else {
            logger.info("[Op] popup 阻塞中，忽略 \(operationId)")
            return
        }
        guard let op = resolveOperation(id: operationId) else {
            logger.warning("[Op] 当前不可用：\(operationId)（state=\(self.currentStateId), branch=\(self.pendingBranchParent ?? "nil")）")
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

    private func resolveOperation(id: String) -> CourseOperation? {
        guard let state = currentCourseState() else { return nil }
        if let parentId = pendingBranchParent {
            let parent = state.operations?.first { $0.id == parentId }
            return parent?.branchOperations?.first { $0.id == id }
        }
        return state.operations?.first { $0.id == id }
    }

    private func applyOperation(_ op: CourseOperation) {
        log.append(OperationLogEntry(opId: op.id, timestamp: Date(), stateId: currentStateId))
        logger.info("[Op] perform \(op.id) (\(op.name))")

        let now = Date()
        // 新操作打断进行中的渐变：已走的部分冻结折入基线，剩余丢弃。必须无条件打断——
        // 哪怕新操作自己没有 effect（比如插管成功只有 popup+targetState），也要把上一个
        // 还在跑的渐变（比如捏球囊那 30s）停掉，否则它会在自己 30s 走完后再 finishOperation
        // 一次，把已经弹出来的插管成功框顶掉。
        interruptActiveEffect(at: now)

        guard let effect = op.effect else {
            finishOperation(op)
            return
        }

        let target = currentMonitor.applying(effect.monitorChange)
        let duration = TimeInterval(effect.duration ?? 0)
        let delta = currentMonitor.delta(to: target)

        // 渐变依赖 tick 循环；无时长或当前 state 没有 tick（flat 且无超时）→ 立即生效并折入基线
        guard duration > 0, stateTimerTask != nil else {
            if degradeCurve != nil {
                let base = degradeValue(at: now) ?? target
                degradeCurve?.fromValue = base.adding(delta, scale: 1)
                degradeCurve?.fromTime = now
            } else {
                flatBase = flatBase.adding(delta, scale: 1)
            }
            currentMonitor = target
            scene?.applyMonitor(target)
            finishOperation(op)
            return
        }

        activeEffect = EffectRamp(
            delta: delta,
            fromTime: now,
            duration: duration,
            onComplete: { [weak self] in self?.finishOperation(op) }
        )
    }

    /// 冻结进行中的渐变：把已完成进度的差值折入基线，丢弃剩余部分。
    /// 被打断的操作不再走 onComplete（其 branch / popup / targetState 不生效）。
    private func interruptActiveEffect(at now: Date) {
        guard let ramp = activeEffect else { return }
        let progress = min(now.timeIntervalSince(ramp.fromTime) / ramp.duration, 1)
        let base = degradeValue(at: now) ?? flatBase
        let newBase = base.adding(ramp.delta, scale: progress)
        if degradeCurve != nil {
            degradeCurve?.fromValue = newBase
            degradeCurve?.fromTime = now
        } else {
            flatBase = newBase
        }
        activeEffect = nil
        currentMonitor = newBase
        logger.info("[Op] 渐变被打断，冻结在 \(Int(progress * 100))% 进度")
    }

    /// effect 渐变（如果有）走完之后，才处理 branch / popup / targetState —— 避免状态切换打断正在播放的渐变。
    private func finishOperation(_ op: CourseOperation) {
        if op.branchOperations != nil {
            pendingBranchParent = op.id
            logger.info("[Op] 进入 branch 选择：\(op.id)")
            if op.id == "muscleRelaxant" {
                // 「不插管/不捏球囊」不是用户点出来的操作，是默认路径：给完肌松药立刻
                // 起一个 30s 渐变（noActionAfterRelaxant.effect.duration），朝 state3 数值走。
                // 期间学员真去捏球囊 / 插管，那次 perform 会按 interruptActiveEffect 把这个
                // 渐变冻结打断，正常走各自的分支——不需要额外的守卫代码。
                // 没被打断，30s 走完自然 finishOperation → targetState: state3。
                perform(operationId: "noActionAfterRelaxant")
            }
            return
        }

        if let popup = op.popup {
            activePopup = popup
            pendingTargetState = op.targetState
            pendingBranchParent = nil
            logger.info("[Op] popup(\(popup.type)): \(popup.message)")
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

    /// state3 停留 30s 还是没有后续（state3 本身没有 operations，走不出去）就强制结束课程。
    private func scheduleState3EndTimeout() {
        state3EndTask?.cancel()
        state3EndTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.state3EndDelay))
            guard let self, !Task.isCancelled, !self.isCourseEnded else { return }
            logger.info("[State] state3 持续 \(Int(Self.state3EndDelay))s 无转归 → 强制结束课程")
            self.isCourseEnded = true
            self.currentStateName = "课程结束"
            self.activePopup = Popup(type: "timeout", message: "患者呼吸抑制未能及时处理，本次课程结束")
        }
    }

    private func transition(to stateId: String) {
        stateTimerTask?.cancel()
        stateTimerTask = nil
        degradeCurve = nil
        activeEffect = nil

        currentStateId = stateId
        if stateId == course?.endState.id {
            currentStateName = "课程结束"
            isCourseEnded = true
            logger.info("[State] → end（课程结束）")
            return
        }
        guard let state = course?.states.first(where: { $0.id == stateId }) else {
            logger.warning("[State] not found: \(stateId)")
            return
        }
        currentStateName = state.name
        logger.info("[State] → \(stateId) (\(state.name))")

        let entryTime = Date()
        switch state.monitor {
        case .flat(let m):
            currentMonitor = m
            flatBase = m
            scene?.applyMonitor(m)
        case .degradable(let initial, let degradeTo, let degradeDuration):
            currentMonitor = initial
            flatBase = initial
            scene?.applyMonitor(initial)
            degradeCurve = DegradeCurve(
                fromValue: initial,
                fromTime: entryTime,
                toValue: degradeTo,
                toTime: entryTime.addingTimeInterval(TimeInterval(degradeDuration))
            )
        }

        if degradeCurve != nil || state.onNoOperation != nil {
            startStateTimer(stateId: stateId, entryTime: entryTime, duration: TimeInterval(state.duration), onNoOperation: state.onNoOperation)
        }

        // state3 没有 operations、也没有 onNoOperation，走不出去，靠这个单独的超时兜底结束课程
        if stateId == "state3" {
            scheduleState3EndTimeout()
        }
    }

    /// 课程级倒计时：1s 一跳，totalDuration 走完不论当前在哪个 state 都强制结束课程 + 超时弹窗。
    /// 课程提前结束（如插管成功）则循环自行退出，倒计时冻结在当时的值。
    private func startCourseCountdown() {
        courseTimerTask?.cancel()
        courseTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, !self.isCourseEnded else { return }
                self.remainingSeconds = max(0, self.remainingSeconds - 1)
                if self.remainingSeconds == 0 {
                    self.handleCourseTimeout()
                    return
                }
            }
        }
    }

    private func handleCourseTimeout() {
        logger.info("[State] 课程 \(self.course?.totalDuration ?? 0)s 到时，强制结束")
        stateTimerTask?.cancel()
        stateTimerTask = nil
        degradeCurve = nil
        activeEffect = nil
        pendingBranchParent = nil
        pendingTargetState = nil
        isCourseEnded = true
        currentStateName = "课程结束"
        activePopup = Popup(type: "timeout", message: "课程时间已到，本次课程结束")
    }

    /// 0.1s 一 tick：驱动 effect 渐变 / 退化曲线，并在 state.duration 到期且用户仍未离开该 state 时按
    /// onNoOperation 自动 transition。
    private func startStateTimer(stateId: String, entryTime: Date, duration: TimeInterval, onNoOperation: NextStateRef?) {
        stateTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                self.tick(now: Date())

                if let onNoOperation, duration > 0,
                   self.currentStateId == stateId,
                   Date() >= entryTime.addingTimeInterval(duration) {
                    self.transition(to: onNoOperation.targetState)
                    return
                }
            }
        }
    }

    private func tick(now: Date) {
        guard degradeCurve != nil || activeEffect != nil else { return }

        // 基线（退化曲线当前值或 flat 基线）+ 进行中渐变按进度叠加
        let base = degradeValue(at: now) ?? flatBase
        var m = base
        var completedRamp: EffectRamp?
        if let ramp = activeEffect {
            let progress = min(now.timeIntervalSince(ramp.fromTime) / ramp.duration, 1)
            m = m.adding(ramp.delta, scale: progress)
            if progress >= 1 { completedRamp = ramp }
        }

        // 走完的渐变把差值永久折入基线，退化曲线以新起点继续
        if completedRamp != nil {
            if degradeCurve != nil {
                degradeCurve?.fromValue = m
                degradeCurve?.fromTime = now
            } else {
                flatBase = m
            }
            activeEffect = nil
        }

        currentMonitor = m
        scene?.applyMonitor(m)

        // onComplete 可能触发 popup / transition，放在状态更新之后
        completedRamp?.onComplete()
    }

    /// 退化曲线在 now 时刻的值；无退化曲线返回 nil
    private func degradeValue(at now: Date) -> Monitor? {
        guard let curve = degradeCurve else { return nil }
        let total = curve.toTime.timeIntervalSince(curve.fromTime)
        let elapsed = now.timeIntervalSince(curve.fromTime)
        return total > 0 ? Monitor.lerp(curve.fromValue, curve.toValue, elapsed / total) : curve.toValue
    }

    private func currentCourseState() -> CourseState? {
        course?.states.first { $0.id == currentStateId }
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

extension CourseRuntime {
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
