// 対局の状態（接続状態、盤面や指し手履歴）
class MatchStatus {
    let position: Position
    let moveHistory: [(detailedMove: DetailedMove, usedTime: Double?)]
    init(position: Position, moveHistory: [(detailedMove: DetailedMove, usedTime: Double?)]) {
        self.position = position
        self.moveHistory = moveHistory
    }
}
