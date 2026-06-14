//
//  ScenarioServicing.swift
//  VirtualOR
//
//  剧情数据服务接口。Live（真实 API）与 Mock（本地 resource.json）都遵守它，
//  调用方只依赖协议；切换实现 = 换注入的实例，调用点不变。
//

import Foundation

protocol ScenarioServicing: Sendable {
    /// 拉取一份剧情数据（结构见 ScenarioModel.Scenario）。
    func fetchScenario() async throws -> Scenario
}
