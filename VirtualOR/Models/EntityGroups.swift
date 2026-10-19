//
//  EntityGroups.swift
//  VirtualOR
//
//  Created by Ge Ding on 2026/2/1.
//
//  派生的实体分组与映射：实体分组（CollidableEntities）+ 抽屉→药品映射（DrugMap），
//  都构建在 EntityName.swift 的实体名枚举之上。
//
//  ⚠️ 身份与显示是分开的：器械组的 `id`、药品的 `operationId` 是**身份标识**，
//  参与 intubationKit / coHoldableSets / 手持判定等逻辑；`name(_:)` 只管显示，
//  切换语言不影响任何判定。
//

import Foundation

/// 物品名的显示语言。只影响器械名和药名这类「物品名」；
/// 引导语、提示语、生命体征标签等成句的文案固定中文。
/// 没有 UI 开关，切语言改 AppModel.displayLanguage 的默认值即可。
enum DisplayLanguage {
    case chinese
    case english
}

enum CollidableEntities {
    static var suctionExpanded: [String] = [Suction.pipeRollUpTop, Suction.pipeRollUpBottom, Suction.pipeConnection].map { $0.rawValue }
    static var suctionCollapsed: [String] = [Suction.bentPipe].map { $0.rawValue }
    static var drawer: [String] = [Drawer.drawer1,Drawer.drawer2,Drawer.drawer3, Drawer.drawer4, Drawer.drawer5].map { $0.rawValue }
    static var anesAdjustButton: [String] = [AnesMonitor.autoButton, AnesMonitor.manualButton].map{ $0.rawValue}
    static var mainScreen: String = AnesMonitor.mainScreen.rawValue
    static var submainScreen: String = AnesMonitor.submainScreen.rawValue
    static var anesMasked: [String] = [AnesMonitor.masked].map { $0.rawValue }
    static var anesUnmasked: [String] = [AnesMonitor.unmaskedPipe, AnesMonitor.unmaskedPart1, AnesMonitor.unmaskedPart2, AnesMonitor.unmaskedPart3, AnesMonitor.unmaskedPart4].map { $0.rawValue }

    /// 对点击透明的实体：可拾取器械全都摆在 drawer_001 这一格里，而
    /// generateCollisionShapes 给抽屉生成的凸包会把开口封上、把里面的器械整个罩住，
    /// 射线永远先打到抽屉。drawer_001 自己也没配药（DrugMap 只有 002~005），
    /// 不需要接收点击，索性把它的碰撞体摘掉让射线穿过去。
    static var tapTransparent: [String] = [Drawer.drawer1.rawValue]

    /// 器械分组。`id`（英文名）兼作身份标识 —— intubationKit / coHoldableSets /
    /// 手持判定全部用它；`name(_:)` / `description(_:)` 只用于显示。
    struct InstrumentGroup {
        let id: String
        let nameZH: String
        /// 教学模式点击气泡里的说明文案（占位版，待医生审校后直接替换字符串）
        let descriptionZH: String
        let descriptionEN: String
        let entityNames: [String]

        func name(_ language: DisplayLanguage) -> String {
            language == .chinese ? nameZH : id
        }

        func description(_ language: DisplayLanguage) -> String {
            language == .chinese ? descriptionZH : descriptionEN
        }
    }

    static let instrumentGroups: [InstrumentGroup] = [
        InstrumentGroup(id: "Stethoscope", nameZH: "听诊器",
            descriptionZH: "听诊器，用于听诊呼吸音", descriptionEN: "Stethoscope — for listening to breath sounds",
            entityNames: [Drawer.stethoscope1, .stethoscope2, .stethoscope3, .stethoscope4, .stethoscope5, .stethoscope6, .stethoscope7].map { $0.rawValue }),
        InstrumentGroup(id: "Laryngoscope", nameZH: "喉镜",
            descriptionZH: "喉镜，插管时用来挑起会厌", descriptionEN: "Laryngoscope — lifts the epiglottis during intubation",
            entityNames: [Drawer.laryngoscope1, .laryngoscope2, .laryngoscope3, .laryngoscope4].map { $0.rawValue }),
        InstrumentGroup(id: "Oropharyngeal Tube", nameZH: "口咽管",
            descriptionZH: "口咽通气道，用于开放气道", descriptionEN: "Oropharyngeal airway — keeps the airway open",
            entityNames: [Drawer.oropTube1, .oropTube2].map { $0.rawValue }),
        InstrumentGroup(id: "Breathing Bag", nameZH: "呼吸球囊",
            descriptionZH: "简易呼吸器，手动捏压给氧", descriptionEN: "Bag-valve mask — manual ventilation",
            entityNames: [Drawer.respBalloon1, .respBalloon2, .respBalloon3, .respBalloon4, .respBalloon5].map { $0.rawValue }),
        InstrumentGroup(id: "Laryngeal Mask", nameZH: "喉罩",
            descriptionZH: "喉罩，声门上通气工具", descriptionEN: "Laryngeal mask — supraglottic airway device",
            entityNames: [Drawer.laryngealMask1, .laryngealMask2, .laryngealMask3, .laryngealMask4].map { $0.rawValue }),
        InstrumentGroup(id: "Laryngeal Duct", nameZH: "气管导管",
            descriptionZH: "气管导管，插入气管建立通气", descriptionEN: "Endotracheal tube — placed in the trachea for ventilation",
            entityNames: [Drawer.laryngealDuct1, .laryngealDuct2, .laryngealDuct3, .laryngealDuct4, .laryngealDuct5].map { $0.rawValue }),
    ]

    /// 器械组 id → 显示名。找不到就原样返回 id。
    static func groupName(id: String, language: DisplayLanguage) -> String {
        instrumentGroups.first { $0.id == id }?.name(language) ?? id
    }

    /// 这几个实体在 usdz 里是 NurbsCurves 而不是 Mesh，RealityKit 不会给它们生成
    /// ModelComponent，也就拿不到碰撞体、点不到（诊断打印里它们不在 tappable 列表）。
    /// 仍然留在各自的 InstrumentGroup 里 —— 拾取时整组显隐要覆盖到它们，只是不参与
    /// 碰撞体生成，免得每次加载都刷一条 visualBounds 为空的 warning。
    /// 3D 那边把曲线转成 mesh 重导之后，从这个集合里删掉即可。
    static let curveOnlyEntities: Set<String> = Set(
        [Drawer.laryngealDuct4, .laryngealDuct5, .stethoscope1, .stethoscope2].map { $0.rawValue }
    )

    /// 所有可拾取的实体名（扁平列表，用于碰撞体生成）。剔除点不到的曲线对象。
    static var pickableInstruments: [String] =
        instrumentGroups.flatMap { $0.entityNames }.filter { !curveOnlyEntities.contains($0) }

    /// 插管需要同时手持的两件器械（InstrumentGroup.id）：喉镜 + 气管导管。
    static let intubationKit: Set<String> = ["Laryngoscope", "Laryngeal Duct"]

    /// 可以同时手持的器械组合。拿新东西时，只有「手上已有的 + 新拿的」整体落在
    /// 其中某一个组合里才叠加持有；否则先把手上的全部放回场景，再拿新的。
    /// 以后要支持新的组合，往这个数组里再加一组即可，拾取逻辑不用改。
    static let coHoldableSets: [Set<String>] = [
        intubationKit,   // 插管：喉镜 + 气管导管
    ]

    /// 教学模式点击气泡的说明文案：被点实体名 → 一句话描述「这是什么」。
    /// 占位版，待医生审校后直接替换字符串；drawer / 器械走各自的 description(_:)，
    /// 不另写一份，改名字或改药效只用改 instrumentGroups / DrugMap.drugs 一处。
    /// 查不到就退回实体名本身，不会出现空气泡。
    static func interactionDescription(for entityName: String, language: DisplayLanguage) -> String {
        if let drug = DrugMap.drug(inDrawer: entityName) {
            return drug.description(language)
        }
        if let group = entityToGroup[entityName] {
            return group.description(language)
        }

        let zh = language == .chinese
        switch entityName {
        case OperationEntityName.humanModel.rawValue:
            return zh ? "病人，可以托下颌、给药或插管" : "Patient — jaw thrust, give drugs, or intubate here"
        case OperationEntityName.patientClothes.rawValue:
            return zh ? "手持药物时点击可以给药" : "Tap with a drug in hand to administer it"
        case AnesMonitor.autoButton.rawValue:
            return zh ? "麻醉机旋钮，调节吸氧浓度" : "Anesthesia machine knob — adjusts O2 concentration"
        case AnesMonitor.masked.rawValue:
            return zh ? "吸氧面罩，已经戴在患者脸上" : "Oxygen mask, already fitted on the patient"
        case AnesMonitor.rubberBall.rawValue:
            return zh ? "手控皮球，接在面罩上，点击捏压给氧" : "Bag connected to the mask — tap to squeeze and ventilate"
        case Suction.bentPipe.rawValue:
            return zh ? "吸引器管路，点击展开" : "Suction tubing — tap to unfold"
        case Suction.pipeRollUpTop.rawValue, Suction.pipeRollUpBottom.rawValue, Suction.pipeConnection.rawValue:
            return zh ? "吸引器管路，点击收起" : "Suction tubing — tap to fold back"
        default:
            if anesUnmasked.contains(entityName) {
                return zh ? "面罩部件，收纳在麻醉机上" : "Mask parts, stored on the machine"
            }
            return entityName
        }
    }

    /// 实体名 → 所属器械组（点击任一部件即可找到整组）
    static var entityToGroup: [String: InstrumentGroup] = {
        var map: [String: InstrumentGroup] = [:]
        for group in instrumentGroups {
            for name in group.entityNames {
                map[name] = group
            }
        }
        return map
    }()
}

/// 抽屉 → 药品的映射。点对应抽屉即"拿起"该药品（HUD holdingItem 切换）；
/// 手持药品点人体衣服（steve_clothes_002）即"服用"，触发对应 operation。
/// 没有 3D 药品模型，所以拿药只更新 hold 文字 + 还原原本手持的器械（如果有）。
enum DrugMap {
    /// `operationId` 兼作身份标识；`name(_:)` / `description(_:)` 只用于显示。
    struct Drug {
        let drawer: String
        let nameEN: String
        let nameZH: String
        let operationId: String
        /// 教学模式点击气泡里的说明文案（占位版，待医生审校后直接替换字符串）
        let descriptionZH: String
        let descriptionEN: String

        func name(_ language: DisplayLanguage) -> String {
            language == .chinese ? nameZH : nameEN
        }

        func description(_ language: DisplayLanguage) -> String {
            language == .chinese ? descriptionZH : descriptionEN
        }
    }

    static let drugs: [Drug] = [
        Drug(drawer: Drawer.drawer2.rawValue, nameEN: "Propofol", nameZH: "丙泊酚", operationId: "propofolIV",
             descriptionZH: "静脉麻醉药，用于诱导麻醉", descriptionEN: "IV anesthetic — used for induction"),
        Drug(drawer: Drawer.drawer3.rawValue, nameEN: "Salbutamol", nameZH: "沙丁胺醇", operationId: "noEffectDrugs",
             descriptionZH: "支气管扩张剂，此情境下无效", descriptionEN: "Bronchodilator — no effect in this scenario"),
        Drug(drawer: Drawer.drawer4.rawValue, nameEN: "Flumazenil/Naloxone", nameZH: "氟马西尼/纳洛酮", operationId: "antagonistDrugs",
             descriptionZH: "拮抗药，此情境下无效", descriptionEN: "Reversal agent — no effect in this scenario"),
        Drug(drawer: Drawer.drawer5.rawValue, nameEN: "Muscle Relaxant", nameZH: "肌松药", operationId: "muscleRelaxant",
             descriptionZH: "肌肉松弛药，为插管做准备", descriptionEN: "Muscle relaxant — prepares for intubation"),
    ]

    /// 该抽屉里放的药；drawer_001 没配药，返回 nil。
    static func drug(inDrawer entityName: String) -> Drug? {
        drugs.first { $0.drawer == entityName }
    }
}
