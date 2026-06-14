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
