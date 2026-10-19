//
//  CourseIntroView.swift
//  VirtualOR
//
//  进场引导（L3）：进沉浸空间后显示在视野正中，10s 后随视频浮窗化一起消失。
//  全部话术集中在本文件，改文案只动这里。
//  （另一处文案在 ORSceneViewModel 底部的「教学模式提示文案」MARK 区。）
//

import SwiftUI

struct CourseIntroView: View {
    /// 教学模式才列「可操作的位置」；考核模式只留角色交代和操作方式。
    let showsInteractionGuide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("麻醉操作流程 · 气道管理")
                .font(.title3.bold())

            Text("您是本次手术的麻醉医生。患者突发呼吸困难，请根据生命体征变化及时处理。")
                .font(.system(size: 15))
                .fixedSize(horizontal: false, vertical: true)

            if showsInteractionGuide {
                section("可操作的位置", rows: [
                    ("病人", "托下颌 / 给药 / 捏球囊 / 插管"),
                    ("器械柜", "抽屉里取用器械与药品"),
                    ("麻醉机", "调节吸氧浓度"),
                ])
            }

            section("操作方式", rows: [
                ("注视物体", "手指捏合即可点击"),
                ("高亮", "可操作的物体在注视时会亮起"),
            ])
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(width: 460, alignment: .leading)
        .glassBackgroundEffect()
    }

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            ForEach(rows, id: \.0) { name, detail in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 72, alignment: .leading)
                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}
