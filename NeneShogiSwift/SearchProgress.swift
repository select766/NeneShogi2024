import Foundation

// 可視化及びサーバに読み筋を送るための探索進捗情報
class SearchProgress {
    let message: String
    let rootPosition: Position
    let pv: [DetailedMove]
    let scoreCp: Int
    // TODO: 残り時間
    // TODO: 探索ノード数
    // TODO: NPS
    // TODO: 木構造
    // TODO: 指し手の履歴(指し手と所要時間)
    
    init(message: String, rootPosition: Position, pv: [DetailedMove], scoreCp: Int) {
        self.message = message
        self.rootPosition = rootPosition
        self.pv = pv
        self.scoreCp = scoreCp
    }
}
