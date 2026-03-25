//
//  ActionParser.swift
//  AI GM
//
//  Created by tony on 2026/3/24.
//

import Foundation

class ActionParser {

    private var rules: [ActionRule] = []

    init() {
        loadRules()
    }

    private func loadRules() {
        guard let url = Bundle.main.url(forResource: "action_rules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ActionRule].self, from: data) else {
            print("Failed to load rules")
            return
        }

        rules = decoded
    }

    func parse(_ input: String) -> (type: String, check: CheckType?) {
        let text = input.lowercased()

        for rule in rules {
            for keyword in rule.keywords {
                if text.contains(keyword) {
                    return (rule.type, mapCheck(rule.check))
                }
            }
        }

        return ("unknown", nil)
    }

    private func mapCheck(_ check: String?) -> CheckType? {
        switch check {
        case "strength": return .strength
        case "dexterity": return .dexterity
        case "intelligence": return .intelligence
        default: return nil
        }
    }
}
