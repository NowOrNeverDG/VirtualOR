//
//  MockCourseRepository.swift
//  VirtualOR
//
//  Mock 剧情数据访问：从主 bundle 的 resource.json 解码，结构与真实 API 一致。
//  后端 API ready 前用它联调；切到真实 API 只需把注入实例换成 LiveCourseRepository。
//

import Foundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "MockCourseRepository")

struct MockCourseRepository: CourseRepository {
    func fetchCourse() async throws -> Course {
        guard let url = Bundle.main.url(forResource: "resource", withExtension: "json") else {
            logger.error("resource.json not found in bundle")
            throw APIError.invalidURL
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(Course.self, from: data)
        } catch {
            logger.error("Failed to decode mock course: \(error.localizedDescription)")
            throw error
        }
    }
}
