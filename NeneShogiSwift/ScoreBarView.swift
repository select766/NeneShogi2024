import SwiftUI

struct ScoreBarView: View {
    var matchStatus: MatchStatus
    
    private func gameStateToString(gameState: MatchStatus.GameState) -> String {
        switch gameState {
        case .connecting:
            return "接続中"
        case .initializing:
            return "対局待ち"
        case .playing:
            return "対局中"
        case .end(let gameResult):
            // TODO: "#WIN"などコマンド文字列をちゃんと解釈する
            return "終了(\(gameResult))"
        }
    }
    
    private func getBlackWinratePercent() -> Int {
        var lastScore = 0
        
        for mh in matchStatus.moveHistory.reversed() {
            if case .Ordinary = mh.detailedMove.special {
                if let s = mh.scoreCp {
                    lastScore = s
                    if mh.detailedMove.sideToMove == PColor.WHITE {
                        lastScore = -lastScore
                    }
                    break
                }
            }
        }
        
        let sigmoid = (tanh(Double(lastScore) / 1200.0) + 1.0) / 2.0
        let percent = Int(sigmoid * 100.0)
        return percent
    }

    var body: some View {
        let blackWinratePercent = getBlackWinratePercent()
        HStack {
            Text("▲\(matchStatus.players[0] ?? "?")").frame(maxWidth: 160)
            if case .playing = matchStatus.gameState {
                Text("\(blackWinratePercent) %").font(.title).frame(width: 80)
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.white).frame(width: 600, height: 24)
                    Rectangle().fill(Color.black).frame(width: CGFloat(600 * blackWinratePercent / 100), height: 24)
                }
                Text("\(100 - blackWinratePercent) %").font(.title).frame(width: 80)
            } else {
                Text(gameStateToString(gameState: matchStatus.gameState))
            }
            Text("△\(matchStatus.players[1] ?? "?")").frame(maxWidth: 160)
        }.frame(width: 1080, height: 32).background(Color.yellow)
    }
}

struct ScoreBarView_Previews: PreviewProvider {
    static var sampleMatchStatus: MatchStatus {
        get {
            let position = Position()
            position.setSFEN(sfen: "9/1+P7/2+P+P4l/5+P+R2/2K+S5/LPS6/2N1P1g+p+p/2GG1+s1+rk/5+s1b+p b G2LPb3n8p 1")
            return MatchStatus(gameState: .playing, players: ["player1", "player2"], position: position, moveHistory: [MoveHistoryItem(detailedMove: DetailedMove(special: .Ordinary, moveFrom: Square(Square.SQ_NB), moveTo: Square.fromFileRank(file: 2, rank: 6), sideToMove: PColor.WHITE, moveFromPieceType: Piece.GOLD, moveToPieceType: Piece.GOLD, isPromote: false, isDrop: true), usedTime: 1.0, scoreCp: -300)])
        }
    }

    static var previews: some View {
        ScoreBarView(matchStatus: sampleMatchStatus)
    }
}
