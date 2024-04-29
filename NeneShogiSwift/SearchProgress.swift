import Foundation

// 可視化及びサーバに読み筋を送るための探索進捗情報
class SearchProgress {
    let position: Position
    let pv: [DetailedMove]
    let score: Int?
    let nps: Int?
    
    init(position: Position, pv: [DetailedMove], score: Int?, nps: Int?) {
        self.position = position
        self.pv = pv
        self.score = score
        self.nps = nps
    }
}
