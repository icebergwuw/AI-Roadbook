import Foundation

enum MockData {
    static let egyptJSON = """
    {
      "destination": "Egypt",
      "dateRange": { "start": "2026-03-26", "end": "2026-04-05" },
      "itinerary": [
        {
          "day": 1,
          "date": "2026-03-26",
          "title": "Cairo → Aswan",
          "events": [
            {
              "time": "04:50",
              "title": "抵达开罗机场",
              "description": "落地后换钱/买SIM卡",
              "location": { "name": "开罗国际机场", "lat": 30.1219, "lng": 31.4056 },
              "type": "transport"
            },
            {
              "time": "09:00",
              "title": "大埃及博物馆 (GEM)",
              "description": "9am-6pm，提前买票",
              "location": { "name": "大埃及博物馆", "lat": 29.9888, "lng": 31.1341 },
              "type": "attraction"
            },
            {
              "time": "19:45",
              "title": "过夜火车 → 阿斯旺",
              "description": "从开罗拉美西斯火车站出发",
              "location": { "name": "开罗火车站", "lat": 30.0598, "lng": 31.2469 },
              "type": "transport"
            }
          ]
        },
        {
          "day": 2,
          "date": "2026-03-27",
          "title": "Aswan · 阿斯旺",
          "events": [
            {
              "time": "07:30",
              "title": "抵达阿斯旺",
              "description": "入住酒店，休息",
              "location": { "name": "阿斯旺火车站", "lat": 24.0889, "lng": 32.8998 },
              "type": "transport"
            },
            {
              "time": "10:00",
              "title": "菲莱神庙",
              "description": "伊希斯女神的圣地，乘船前往",
              "location": { "name": "菲莱神庙", "lat": 24.0235, "lng": 32.8839 },
              "type": "attraction"
            },
            {
              "time": "14:00",
              "title": "阿斯旺高坝",
              "description": "纳赛尔湖全景",
              "location": { "name": "阿斯旺高坝", "lat": 23.9706, "lng": 32.8788 },
              "type": "attraction"
            },
            {
              "time": "19:00",
              "title": "晚餐·尼罗河边",
              "description": "推荐 El Masry Restaurant",
              "location": { "name": "阿斯旺市区", "lat": 24.0875, "lng": 32.8990 },
              "type": "food"
            }
          ]
        }
      ],
      "checklist": [
        { "id": "1", "title": "定包车两天", "completed": true, "dayIndex": 1 },
        { "id": "2", "title": "Airbnb声光秀门票", "completed": false, "dayIndex": null },
        { "id": "3", "title": "各景点门票提前购买", "completed": false, "dayIndex": null },
        { "id": "4", "title": "换好埃及镑", "completed": true, "dayIndex": null }
      ],
      "culture": {
        "type": "mythology_tree",
        "title": "古埃及众神谱系",
        "nodes": [
          {
            "id": "ra",
            "name": "拉 Ra",
            "subtitle": "太阳神·众神之首",
            "description": "古埃及最重要的神，每天清晨以年轻的凯布利形象升起，正午以鹰头人身的拉照耀大地，黄昏化为老年的阿图姆落下。与阿蒙合并后成为阿蒙-拉，统治整个埃及神系。",
            "emoji": "☀️",
            "parentId": null
          },
          {
            "id": "shu",
            "name": "舒",
            "subtitle": "空气之神",
            "description": "拉之子，负责支撑天空，将天地分离。他站在大地之间，双臂高举支撑着天空女神努特。",
            "emoji": "💨",
            "parentId": "ra"
          },
          {
            "id": "tefnut",
            "name": "泰芙努特",
            "subtitle": "雨露女神",
            "description": "拉之女，舒的姐妹兼妻子，代表湿气和雨水。狮头人身形象。",
            "emoji": "💧",
            "parentId": "ra"
          },
          {
            "id": "osiris",
            "name": "奥西里斯",
            "subtitle": "冥界之王",
            "description": "舒与泰芙努特之孙，死亡与复活之神，冥界的统治者。被兄弟塞特杀死后由伊西斯复活，成为冥界之王。",
            "emoji": "🌿",
            "parentId": "shu"
          },
          {
            "id": "isis",
            "name": "伊希斯",
            "subtitle": "魔法女神",
            "description": "奥西里斯之妻，魔法与医疗女神。她的魔法力量使丈夫复活，被视为最伟大的女神之一。",
            "emoji": "✨",
            "parentId": "shu"
          },
          {
            "id": "set",
            "name": "塞特",
            "subtitle": "混乱之神",
            "description": "沙漠、风暴、混乱与战争之神。杀死兄弟奥西里斯并将其分尸，与侄子荷鲁斯长期争斗。",
            "emoji": "⚡",
            "parentId": "shu"
          },
          {
            "id": "horus",
            "name": "荷鲁斯",
            "subtitle": "王权之神",
            "description": "奥西里斯与伊希斯之子，鹰头人身，天空与王权之神。法老被视为荷鲁斯的化身。",
            "emoji": "🦅",
            "parentId": "osiris"
          },
          {
            "id": "anubis",
            "name": "阿努比斯",
            "subtitle": "防腐之神",
            "description": "胡狼头人身，亡者守护神，主持木乃伊制作仪式，引导亡魂前往冥界接受审判。",
            "emoji": "🐺",
            "parentId": "osiris"
          }
        ]
      },
      "tips": [
        "提前在网上购买各景点门票，现场票常售罄",
        "埃及使用东阿拉伯数字，和西方数字字形不同，要提前学习",
        "进入神庙需着长裤或长裙，建议带围巾",
        "讨价还价是常态，第一报价可以还到一半",
        "推荐使用 Uber 或包车，不建议随机搭车"
      ],
      "sos": [
        { "title": "中国驻埃及大使馆", "phone": "+20-2-27361219", "subtitle": "领事保护热线", "emoji": "🇨🇳" },
        { "title": "埃及报警", "phone": "122", "subtitle": "Police", "emoji": "🚓" },
        { "title": "埃及急救", "phone": "123", "subtitle": "Ambulance", "emoji": "🚑" },
        { "title": "埃及旅游警察", "phone": "126", "subtitle": "Tourism Police", "emoji": "👮" }
      ]
    }
    """

    static func makeMockTrip() -> Trip {
        let parsed = try! AIResponseParser.parse(json: egyptJSON)
        let t = Trip(
            destination: parsed.destination,
            startDate: parsed.startDate,
            endDate: parsed.endDate
        )
        t.days = parsed.days
        t.checklist = parsed.checklist
        t.culture = parsed.culture
        t.tips = parsed.tips
        t.sosContacts = parsed.sosContacts
        return t
    }
}
