//
//  ORSceneViewModel+DescriptionBubble.swift
//  VirtualOR
//
//  教学模式的点击说明气泡（L2 的替代方案）：不再给可交互物常驻挂名牌，改成点击后
//  在该实体正上方弹一个小气泡说明「这是什么」，几秒后自动消失。考核模式不弹。
//
//  气泡本身是 ImmersiveView 里的一个 SwiftUI Attachment（id: "descriptionBubble"），
//  这里只负责算「弹什么字」「摆哪」，实际的挂载 / 定位在 ImmersiveView 的 update 闭包。
//
//  文案数据源见 CollidableEntities.interactionDescription（改文案只动那边）。
//

import Foundation
import RealityKit

extension ORSceneViewModel {
    /// 一次气泡展示：文案 + 挂载位置（相对 rootEntity 的本地坐标，和其余碰撞体计算同一空间）。
    struct DescriptionBubble: Equatable {
        let text: String
        let localPosition: SIMD3<Float>
    }

    private static let bubbleDuration: Duration = .seconds(4)
    /// 气泡相对物体顶部的固定间隙；大物体（如病人）再按包围盒高度加一点，避免扎进模型里。
    private static let bubbleMargin: Float = 0.06

    /// 在 entityName 正上方弹一个说明气泡，若已有气泡在显示则直接替换（重置计时）。
    func showDescriptionBubble(for entityName: String) {
        guard let rootEntity, let target = rootEntity.findEntity(named: entityName) else { return }

        let text = CollidableEntities.interactionDescription(for: entityName, language: displayLanguage)
        let bounds = target.visualBounds(relativeTo: rootEntity)
        let margin = max(Self.bubbleMargin, bounds.extents.y * 0.08)
        let position = SIMD3<Float>(bounds.center.x, bounds.max.y + margin, bounds.center.z)

        descriptionBubble = DescriptionBubble(text: text, localPosition: position)

        bubbleHideTask?.cancel()
        bubbleHideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.bubbleDuration)
            guard !Task.isCancelled else { return }
            self?.descriptionBubble = nil
        }
    }
}
