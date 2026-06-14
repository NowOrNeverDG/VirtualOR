//
//  CourseRepository.swift
//  VirtualOR
//
//  剧情数据访问接口。Live（真实 API）与 Mock（本地 resource.json）都遵守它，
//  调用方只依赖协议；切换实现 = 换注入的实例，调用点不变。
//

import Foundation

protocol CourseRepository: Sendable {
    /// 拉取一份剧情数据（结构见 CourseModel.Course）。
    func fetchCourse() async throws -> Course
}
