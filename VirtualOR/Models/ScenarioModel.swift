//
//  ScenarioModel.swift
//  VirtualOR
//
//  剧情数据 Codable 模型 —— 与后端 JSON 一一对应。
//

import Foundation

// MARK: - 顶层

struct Scenario: Codable {
    let version: String
    let title: String
    let totalDuration: Int
    let initialState: InitialState
    let states: [ScenarioState]
    let endState: EndState
}

struct InitialState: Codable {
    let id: String
    let duration: Int
    let monitor: Monitor
    let description: String
}

struct EndState: Codable {
    let id: String
    let type: String
}

// MARK: - State

struct ScenarioState: Codable {
    let id: String
    let name: String
    let description: String?
    let duration: Int
    let autoVideo: AutoVideo?
    let monitor: StateMonitor
    let onNoOperation: NextStateRef?
    let operations: [ScenarioOperation]?
    let targetState: String?
}

struct NextStateRef: Codable {
    let targetState: String
}

struct AutoVideo: Codable {
    let content: String
    let playDurationFirst: Int
    let modeAfter10s: String
}

/// state.monitor 在 JSON 里有两种形态：
///   1. 平铺：直接是一组 NIBP/SPO2/HR/RR/temperature
///   2. 带退化：{ initial: Monitor, degradeTo: Monitor, degradeDuration: Int }
enum StateMonitor: Codable {
    case flat(Monitor)
    case degradable(initial: Monitor, degradeTo: Monitor, degradeDuration: Int)

    private enum DegradeCodingKeys: String, CodingKey {
        case initial, degradeTo, degradeDuration
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DegradeCodingKeys.self),
           container.contains(.initial),
           container.contains(.degradeTo) {
            let initial = try container.decode(Monitor.self, forKey: .initial)
            let degradeTo = try container.decode(Monitor.self, forKey: .degradeTo)
            let duration = try container.decode(Int.self, forKey: .degradeDuration)
            self = .degradable(initial: initial, degradeTo: degradeTo, degradeDuration: duration)
        } else {
            let monitor = try Monitor(from: decoder)
            self = .flat(monitor)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .flat(let m):
            try m.encode(to: encoder)
        case .degradable(let initial, let degradeTo, let duration):
            var container = encoder.container(keyedBy: DegradeCodingKeys.self)
            try container.encode(initial, forKey: .initial)
            try container.encode(degradeTo, forKey: .degradeTo)
            try container.encode(duration, forKey: .degradeDuration)
        }
    }
}

// MARK: - Monitor

struct Monitor: Codable {
    let nibp: NIBP
    let spo2: Int
    let hr: Int
    let rr: Int
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case nibp = "NIBP"
        case spo2 = "SPO2"
        case hr = "HR"
        case rr = "RR"
        case temperature
    }
}

struct NIBP: Codable {
    let systolic: Int
    let diastolic: Int
}

// MARK: - Operation

/// 注：避开 Foundation.Operation 重名，命名为 ScenarioOperation。
struct ScenarioOperation: Codable {
    let id: String
    let name: String
    let effect: OperationEffect?
    let nextStep: String?
    let popup: Popup?
    let log: String?
    let targetState: String?
    let branchOperations: [ScenarioOperation]?
}

struct OperationEffect: Codable {
    let duration: Int?
    let monitorChange: MonitorChange
    let afterEffect: String?
}

struct Popup: Codable {
    let type: String
    let message: String
}

// MARK: - MonitorChange (混合类型: 绝对值 Int/Double 或增量字符串 "+10")

struct MonitorChange: Codable {
    let nibp: NIBPChange?
    let spo2: ValueChange?
    let hr: ValueChange?
    let rr: ValueChange?
    let temperature: ValueChange?

    enum CodingKeys: String, CodingKey {
        case nibp = "NIBP"
        case spo2 = "SPO2"
        case hr = "HR"
        case rr = "RR"
        case temperature
    }
}

struct NIBPChange: Codable {
    let systolic: ValueChange?
    let diastolic: ValueChange?
}

/// 监护仪数值变化：可能是绝对值（如 105）或字符串增量（如 "+10"、"-5"）。
enum ValueChange: Codable {
    case absolute(Double)
    case delta(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .absolute(Double(intVal))
        } else if let dblVal = try? container.decode(Double.self) {
            self = .absolute(dblVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .delta(strVal)
        } else {
            throw DecodingError.typeMismatch(
                ValueChange.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int/Double or String like \"+10\""
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .absolute(let v): try container.encode(v)
        case .delta(let s): try container.encode(s)
        }
    }
}
