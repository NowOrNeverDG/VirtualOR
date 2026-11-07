//
//  DrugMenuView.swift
//  VirtualOR
//
//  药品托盘（径向菜单）。点麻醉车药品抽屉（drawer_002~005）打开。
//  两级：先一圈 6 个类别（镇静药/肌松药/镇痛药/心血管活性药/其他药物/
//  拮抗药，对应开发需求文档附件1·麻醉车第一层），选中类别后展开该类别下的具体
//  药品列表。16 种药没法一圈摆下，所以分两级——一圈 6 个按钮，扇区够大。
//
//  数据直接读 DrugMap.drugs，药品清单只有这一份，不另外维护。
//

import SwiftUI

struct DrugMenuView: View {
    let language: DisplayLanguage
    let onSelect: (DrugMap.Drug) -> Void

    @State private var expandedCategory: DrugCategory?

    private let categoryRadius: CGFloat = 90
    private let categoryButtonSize: CGFloat = 78

    var body: some View {
        Group {
            if let category = expandedCategory {
                drugList(for: category)
            } else {
                categoryRing
            }
        }
        .glassBackgroundEffect()
        .animation(.default, value: expandedCategory)
    }

    /// 第一级：6 个类别排成一圈
    private var categoryRing: some View {
        ZStack {
            ForEach(Array(DrugCategory.allCases.enumerated()), id: \.element) { index, category in
                let angle = Angle(degrees: 360.0 / Double(DrugCategory.allCases.count) * Double(index) - 90)
                Button {
                    expandedCategory = category
                } label: {
                    Text(category.name(language))
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                        .frame(width: categoryButtonSize, height: categoryButtonSize)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .offset(x: cos(angle.radians) * categoryRadius, y: sin(angle.radians) * categoryRadius)
            }
        }
        .frame(width: (categoryRadius + categoryButtonSize) * 2, height: (categoryRadius + categoryButtonSize) * 2)
    }

    /// 第二级：该类别下的具体药品，竖排列表 + 一个返回按钮
    private func drugList(for category: DrugCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    expandedCategory = nil
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)

                Text(category.name(language))
                    .font(.system(size: 16, weight: .semibold))
            }

            ForEach(DrugMap.drugs.filter { $0.category == category }, id: \.nameEN) { drug in
                Button {
                    onSelect(drug)
                } label: {
                    Text(drug.name(language))
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 260)
    }
}
