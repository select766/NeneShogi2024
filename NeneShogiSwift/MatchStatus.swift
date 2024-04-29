// 対局の状態（接続状態、盤面や指し手履歴）
class MatchStatus {
    var engineMode: EngineMode?
    var players: [String?]
    var moveHistory: [MoveHistoryItem]
    var remainingTimes: [RemainingTime?]
    var csaGameState: CSAGameState
    var lastGameResult: String?

    init(engineMode: EngineMode? = nil, players: [String?], moveHistory: [MoveHistoryItem], remainingTimes: [RemainingTime?], csaGameState: CSAGameState, lastGameResult: String? = nil) {
        self.engineMode = engineMode
        self.players = players
        self.moveHistory = moveHistory
        self.remainingTimes = remainingTimes
        self.csaGameState = csaGameState
        self.lastGameResult = lastGameResult
    }
}

func getSampleMatchStatus() -> MatchStatus {
    // TODO: 局面の進行、評価値付与
    let position = Position()
    position.setSFEN(sfen: "9/1+P7/2+P+P4l/5+P+R2/2K+S5/LPS6/2N1P1g+p+p/2GG1+s1+rk/5+s1b+p b G2LPb3n8p 1")
    return MatchStatus(engineMode: .CSA, players: ["player1", "player2"], moveHistory: [MoveHistoryItem(positionBeforeMove: position, positionAfterMove: position, detailedMove: DetailedMove(special: .Ordinary, moveFrom: Square(Square.SQ_NB), moveTo: Square.fromFileRank(file: 2, rank: 6), sideToMove: PColor.WHITE, moveFromPieceType: Piece.GOLD, moveToPieceType: Piece.GOLD, isPromote: false, isDrop: true), usedTime: 1.0, scoreCp: -300)], remainingTimes: [nil, nil], csaGameState: .playing)
}
