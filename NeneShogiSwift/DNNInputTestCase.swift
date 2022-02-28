import Foundation

struct DNNInputTestCaseItem: Decodable {
    let x: [Int]
    let moveLabel: Int
    let sfen: String
    let moveUSI: String
}

func loadDNNInputTestCases() -> [DNNInputTestCaseItem] {
    guard let url = Bundle.main.url(forResource: "DNNInputTestCase", withExtension: "txt") else {
        fatalError()
    }
    guard let data = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError()
    }
    let lines = data.components(separatedBy: .newlines)
    let decoder = JSONDecoder()
    var items: [DNNInputTestCaseItem] = []
    for line in lines {
        if line.count == 0 {
            // 最終行など
            continue
        }
        guard let lineData = line.data(using: .utf8) else {
            fatalError()
        }
        guard let item = try? decoder.decode(DNNInputTestCaseItem.self, from: lineData) else {
            fatalError()
        }
        items.append(item)
    }
    return items
}
