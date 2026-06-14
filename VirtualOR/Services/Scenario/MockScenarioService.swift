//
//  MockScenarioService.swift
//  VirtualOR
//
//  Mock 剧情数据服务：从主 bundle 的 resource.json 解码，结构与真实 API 一致。
//  后端 API ready 前用它联调；切到真实 API 只需把注入实例换成 ScenarioService。
//

import Foundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "MockScenarioService")

struct MockScenarioService: ScenarioServicing {
    func fetchScenario() async throws -> Scenario {
        guard let url = Bundle.main.url(forResource: "resource", withExtension: "json") else {
            logger.error("resource.json not found in bundle")
            throw APIError.invalidURL
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(Scenario.self, from: data)
        } catch {
            logger.error("Failed to decode mock scenario: \(error.localizedDescription)")
            throw error
        }
    }
}
