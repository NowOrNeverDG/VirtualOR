//
//  Monitor+Apply.swift
//  VirtualOR
//
//  把 MonitorChange 应用到 Monitor 上：absolute 覆盖，delta（"+10"/"-5"）叠加。
//

import Foundation

extension Monitor {
    func applying(_ change: MonitorChange) -> Monitor {
        Monitor(
            nibp: NIBP(
                systolic: applyInt(change.nibp?.systolic, current: nibp.systolic),
                diastolic: applyInt(change.nibp?.diastolic, current: nibp.diastolic)
            ),
            spo2: applyInt(change.spo2, current: spo2),
            hr: applyInt(change.hr, current: hr),
            rr: applyInt(change.rr, current: rr),
            temperature: applyDouble(change.temperature, current: temperature)
        )
    }

    /// 按 t（0...1）在 from → to 之间线性插值，用于退化曲线 / effect.duration 渐变。
    static func lerp(_ from: Monitor, _ to: Monitor, _ t: Double) -> Monitor {
        let t = min(max(t, 0), 1)
        return Monitor(
            nibp: NIBP(
                systolic: lerpInt(from.nibp.systolic, to.nibp.systolic, t),
                diastolic: lerpInt(from.nibp.diastolic, to.nibp.diastolic, t)
            ),
            spo2: lerpInt(from.spo2, to.spo2, t),
            hr: lerpInt(from.hr, to.hr, t),
            rr: lerpInt(from.rr, to.rr, t),
            temperature: from.temperature + (to.temperature - from.temperature) * t
        )
    }
}

private func lerpInt(_ from: Int, _ to: Int, _ t: Double) -> Int {
    Int((Double(from) + (Double(to) - Double(from)) * t).rounded())
}

/// Monitor 的逐项差值。effect 渐变以此表达「本次操作带来的变化量」，
/// 多个渐变可各自按进度叠加到基线上（操作可累加）。
struct MonitorDelta {
    let systolic: Double
    let diastolic: Double
    let spo2: Double
    let hr: Double
    let rr: Double
    let temperature: Double
}

extension Monitor {
    /// self → target 的逐项差值
    func delta(to target: Monitor) -> MonitorDelta {
        MonitorDelta(
            systolic: Double(target.nibp.systolic - nibp.systolic),
            diastolic: Double(target.nibp.diastolic - nibp.diastolic),
            spo2: Double(target.spo2 - spo2),
            hr: Double(target.hr - hr),
            rr: Double(target.rr - rr),
            temperature: target.temperature - temperature
        )
    }

    /// 按 scale（0...1，即渐变进度）叠加一份差值
    func adding(_ d: MonitorDelta, scale: Double) -> Monitor {
        let s = min(max(scale, 0), 1)
        return Monitor(
            nibp: NIBP(
                systolic: nibp.systolic + Int((d.systolic * s).rounded()),
                diastolic: nibp.diastolic + Int((d.diastolic * s).rounded())
            ),
            spo2: spo2 + Int((d.spo2 * s).rounded()),
            hr: hr + Int((d.hr * s).rounded()),
            rr: rr + Int((d.rr * s).rounded()),
            temperature: temperature + d.temperature * s
        )
    }
}

extension ValueChange {
    func resolve(against current: Double) -> Double {
        switch self {
        case .absolute(let v):
            return v
        case .delta(let s):
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            if let n = Double(trimmed) {
                return current + n
            }
            return current
        }
    }
}

private func applyInt(_ change: ValueChange?, current: Int) -> Int {
    guard let change else { return current }
    return Int(change.resolve(against: Double(current)).rounded())
}

private func applyDouble(_ change: ValueChange?, current: Double) -> Double {
    guard let change else { return current }
    return change.resolve(against: current)
}
