//
//  LiveScenarioRepository.swift
//  VirtualOR
//
//  Live 剧情数据访问：走 APIService 拉后端数据。
//

import Foundation

struct LiveScenarioRepository: ScenarioRepository {
    /// TODO: path 暂定 "/placeholder"，等后端确定真实端点后替换；
    ///       如有必要也要更新 APIConfig.baseURL。
    func fetchScenario() async throws -> Scenario {
        try await APIService.shared.request(
            APIEndpoint(path: "/placeholder")
        )
    }
}
