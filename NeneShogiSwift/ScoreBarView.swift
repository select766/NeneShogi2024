import SwiftUI

struct ScoreBarView: View {
    let gridSize = CGFloat(32)
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
            Text("▲\(matchStatus.players[0] ?? "?")").font(.system(size: gridSize * 0.4)).frame(maxWidth: gridSize * 2.5)
            if case .playing = matchStatus.gameState {
                Text("\(blackWinratePercent) %").font(.system(size: gridSize * 0.5)).frame(width: gridSize * 1.25)
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.white).frame(width: gridSize * 9.375, height: gridSize * 0.375)
                    Rectangle().fill(Color.black).frame(width: CGFloat(gridSize * CGFloat(CGFloat(9.375) * CGFloat(blackWinratePercent) / CGFloat(100))), height: gridSize * 0.375)
                }
                Text("\(100 - blackWinratePercent) %").font(.system(size: gridSize * 0.5)).frame(width: gridSize * 1.25)
            } else {
                Text(gameStateToString(gameState: matchStatus.gameState))
            }
            Text("△\(matchStatus.players[1] ?? "?")").font(.system(size: gridSize * 0.4)).frame(maxWidth: gridSize * 2.5)
        }.frame(width: gridSize * 16.875, height: gridSize * 0.5).background(Color.yellow)
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
