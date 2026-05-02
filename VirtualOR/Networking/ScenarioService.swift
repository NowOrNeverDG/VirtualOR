//
//  ScenarioService.swift
//  VirtualOR
//
//  剧情数据服务。
//
//  - fetchScenario():     真实 API 请求（后端 API 暂定 www.4399.com/placeholder，尚未 ready）
//  - fetchMockScenario(): 死数据 mock，API 接通前用这个
//
//  API ready 后调用方把 fetchMockScenario() 换成 fetchScenario() 即可，签名一致。
//

import Foundation
import os

private let logger = Logger(subsystem: "com.app.VirtualOR", category: "ScenarioService")

enum ScenarioService {

    // MARK: - 真实 API 请求

    /// 走 APIService 拉取剧情数据。后端 API ready 后启用。
    /// TODO: path 暂定 "/placeholder"，等后端确定真实端点后替换；如有必要也要更新 APIConfig.baseURL。
    static func fetchScenario() async throws -> Scenario {
        return try await APIService.shared.request(
            APIEndpoint(path: "/placeholder")
        )
    }

    // MARK: - 死数据 mock

    /// 返回硬编码的剧情数据，结构与真实 API 一致。
    /// 用于 API ready 之前的开发联调。
    static func fetchMockScenario() async throws -> Scenario {
        let data = Data(scenarioJSON.utf8)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Scenario.self, from: data)
        } catch {
            logger.error("Failed to decode mock scenario: \(error.localizedDescription)")
            throw error
        }
    }

    private static let scenarioJSON = """
    {
      "version": "1.0",
      "title": "麻醉操作流程-气道管理模拟",
      "totalDuration": 600,
      "initialState": {
        "id": "initial",
        "duration": 10,
        "monitor": {
          "NIBP": { "systolic": 98, "diastolic": 56 },
          "SPO2": 100,
          "HR": 86,
          "RR": 20,
          "temperature": 36.8
        },
        "description": "初始状态，监护仪稳定，持续10秒后进入状态1"
      },
      "states": [
        {
          "id": "state1",
          "name": "状态1-呼吸困难发作",
          "duration": 600,
          "autoVideo": {
            "content": "呼吸困难视频",
            "playDurationFirst": 10,
            "modeAfter10s": "floatWindow"
          },
          "monitor": {
            "initial": {
              "NIBP": { "systolic": 112, "diastolic": 63 },
              "SPO2": 86,
              "HR": 117,
              "RR": 12,
              "temperature": 36.8
            },
            "degradeTo": {
              "NIBP": { "systolic": 105, "diastolic": 61 },
              "SPO2": 60,
              "HR": 105,
              "RR": 8,
              "temperature": 36.8
            },
            "degradeDuration": 600
          },
          "onNoOperation": {
            "targetState": "state2"
          },
          "operations": [
            {
              "id": "jawThrust",
              "name": "托下颌",
              "effect": {
                "duration": 5,
                "monitorChange": {
                  "NIBP": { "systolic": "+10", "diastolic": "+5" },
                  "HR": "+20",
                  "RR": "+3"
                },
                "afterEffect": "continueDegrade"
              },
              "nextStep": "继续观察，状态向状态2发展"
            },
            {
              "id": "increaseOxygen",
              "name": "提高吸氧浓度（面罩吸氧）",
              "effect": {
                "duration": 5,
                "monitorChange": {
                  "SPO2": "+3",
                  "HR": "-5"
                },
                "afterEffect": "continueDegrade"
              },
              "nextStep": "继续观察，状态向状态2发展"
            },
            {
              "id": "maskBagVentilation",
              "name": "面罩加压给氧（手捏球囊）",
              "effect": {
                "duration": 5,
                "monitorChange": {
                  "SPO2": "-5",
                  "HR": "+10"
                },
                "afterEffect": "continueDegrade"
              },
              "nextStep": "继续观察，状态向状态2发展"
            },
            {
              "id": "propofolIV",
              "name": "静脉注射丙泊酚",
              "effect": {
                "duration": 5,
                "monitorChange": {
                  "NIBP": { "systolic": "-10", "diastolic": "-5" },
                  "SPO2": "-5",
                  "HR": "-10",
                  "RR": "-2"
                },
                "afterEffect": "continueDegrade"
              },
              "nextStep": "继续观察，状态向状态2发展"
            },
            {
              "id": "muscleRelaxant",
              "name": "使用肌松药（罗库溴铵/顺阿曲库铵）",
              "branchOperations": [
                {
                  "id": "noActionAfterRelaxant",
                  "name": "未进行插管/捏球囊（状态3）",
                  "effect": {
                    "duration": 30,
                    "monitorChange": {
                      "NIBP": { "systolic": 105, "diastolic": 61 },
                      "SPO2": 50,
                      "HR": 60,
                      "RR": 0
                    }
                  },
                  "targetState": "state3",
                  "nextStep": "患者呼吸抑制，状态恶化"
                },
                {
                  "id": "onlyBagAfterRelaxant",
                  "name": "仅手捏球囊通气（状态4）",
                  "effect": {
                    "monitorChange": {
                      "NIBP": { "systolic": 98, "diastolic": 56 },
                      "SPO2": 100,
                      "HR": 86,
                      "RR": 20,
                      "temperature": 36.8
                    }
                  },
                  "targetState": "state4",
                  "nextStep": "生命体征恢复正常，持续运行至10分钟结束"
                },
                {
                  "id": "intubationAfterRelaxant",
                  "name": "气管插管（含球囊通气）",
                  "popup": {
                    "type": "success",
                    "message": "患者呼吸困难改善，此次课程结束"
                  },
                  "targetState": "end"
                }
              ]
            },
            {
              "id": "directIntubation",
              "name": "不使用肌松药直接气管插管",
              "popup": {
                "type": "error",
                "message": "无法进行此操作"
              },
              "log": "记录违规操作：无肌松药直接插管"
            },
            {
              "id": "noEffectDrugs",
              "name": "使用沙丁胺醇/甲泼尼龙/地塞米松",
              "effect": {
                "monitorChange": {}
              },
              "nextStep": "生命体征无改变，状态继续向状态2发展"
            },
            {
              "id": "antagonistDrugs",
              "name": "使用氟马西尼/纳洛酮（拮抗药）",
              "effect": {
                "monitorChange": {}
              },
              "nextStep": "生命体征无改变，状态继续向状态2发展"
            }
          ]
        },
        {
          "id": "state2",
          "name": "状态2-未插管最恶化状态",
          "description": "状态1运行10分钟未进行有效处理，进入状态2",
          "monitor": {
            "NIBP": { "systolic": 105, "diastolic": 61 },
            "SPO2": 60,
            "HR": 105,
            "RR": 8,
            "temperature": 36.8
          },
          "duration": 0,
          "targetState": "end"
        },
        {
          "id": "state3",
          "name": "状态3-肌松后无有效通气",
          "monitor": {
            "NIBP": { "systolic": 105, "diastolic": 61 },
            "SPO2": 50,
            "HR": 60,
            "RR": 0,
            "temperature": 36.8
          },
          "description": "使用肌松药后未进行插管或捏球囊，呼吸停止",
          "duration": 0,
          "targetState": "end"
        },
        {
          "id": "state4",
          "name": "状态4-肌松药+仅捏球囊通气",
          "monitor": {
            "NIBP": { "systolic": 98, "diastolic": 56 },
            "SPO2": 100,
            "HR": 86,
            "RR": 20,
            "temperature": 36.8
          },
          "description": "使用肌松药后仅手捏球囊通气，生命体征恢复正常",
          "duration": 600,
          "targetState": "end"
        }
      ],
      "endState": {
        "id": "end",
        "type": "courseEnd"
      }
    }
    """
}
