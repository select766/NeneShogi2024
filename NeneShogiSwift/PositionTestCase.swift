import Foundation

struct PositionTestCaseItem: Decodable {
    let sfen: String
    let legalMoves: Set<String>
    let positionCommand: String
    let inCheck: Bool
}

func loadPositionTestCases() -> [PositionTestCaseItem] {
    guard let url = Bundle.main.url(forResource: "PositionTestCase", withExtension: "txt") else {
        fatalError()
    }
    guard let data = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError()
    }
    let lines = data.components(separatedBy: .newlines)
    let decoder = JSONDecoder()
    var items: [PositionTestCaseItem] = []
    for line in lines {
        if line.count == 0 {
            // 最終行など
            continue
        }
        guard let lineData = line.data(using: .utf8) else {
            fatalError()
        }
        guard let item = try? decoder.decode(PositionTestCaseItem.self, from: lineData) else {
            fatalError()
        }
        items.append(item)
    }
    return items
}
