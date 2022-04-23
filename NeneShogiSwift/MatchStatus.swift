struct CommunicationItem {
    enum Direction {
        case send
        case recv
    }
    let direction: Direction
    let message: String
}

// 対局の状態（接続状態、盤面や指し手履歴）
class MatchStatus {
    let position: Position
    let moveHistory: [(detailedMove: DetailedMove, usedTime: Double?)]
    let communicationHistory: [CommunicationItem]
    init(position: Position, moveHistory: [(detailedMove: DetailedMove, usedTime: Double?)], communicationHistory: [CommunicationItem]) {
        self.position = position
        self.moveHistory = moveHistory
        self.communicationHistory = communicationHistory
    }
}
