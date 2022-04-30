import SwiftUI

struct MoveHistoryView: View {
    struct MoveHistoryDisplayItem: Identifiable {
        let id: Int
        let tekazu: Int
        let detailedMove: DetailedMove
        let usedTime: Int?
        let totalUsedTime: Int
        let scoreCp: Int?
    }
    
    var matchStatus: MatchStatus
    
    private func toMoveHistory() -> [MoveHistoryDisplayItem] {
        var mh: [MoveHistoryDisplayItem] = []
        var totalUsedTimes = [0.0, 0.0]
        for i in 0..<matchStatus.moveHistory.count {
            let mi = matchStatus.moveHistory[i]
            totalUsedTimes[mi.detailedMove.sideToMove.color] += mi.usedTime ?? 0.0
            mh.append(MoveHistoryDisplayItem(
                id: i,
                tekazu: i+1,
                detailedMove: mi.detailedMove, usedTime: mi.usedTime != nil ? Int(mi.usedTime!) : nil,
                totalUsedTime: Int(totalUsedTimes[mi.detailedMove.sideToMove.color]),
                scoreCp: mi.scoreCp
            ))
        }
        return mh
    }
    var body: some View {
        let moveHistory = toMoveHistory()
        VStack {
            Text("指し手 消費時間/合計")
            ScrollView(.vertical, showsIndicators: true) {
                ScrollViewReader {
                    proxy in
                    VStack(alignment: .leading) {
                        ForEach(moveHistory) {moveHistoryItem in
                            Text("\(moveHistoryItem.tekazu): \(moveHistoryItem.detailedMove.toPrintString()) - \(moveHistoryItem.usedTime != nil ? String(moveHistoryItem.usedTime!) : "*") / \(moveHistoryItem.totalUsedTime) \(moveHistoryItem.scoreCp != nil ? String(moveHistoryItem.scoreCp!) : "")").id(moveHistoryItem.id)
                        }
                    }.onChange(of: matchStatus.moveHistory.count - 1, perform: {
                        // withAnimationをつけるとかっこいいが、アニメーションが終わる前に次の手が進むと一番下までスクロールしないままになる
                        value in
                        proxy.scrollTo(value, anchor: .bottom)
                    })
                }
                
            }.frame(maxWidth: .infinity, maxHeight: 120.0)
        }
    }
}

struct MoveHistoryView_Previews: PreviewProvider {
    static var sampleMatchStatus: MatchStatus {
        get {
            let position = Position()
            position.setSFEN(sfen: "9/1+P7/2+P+P4l/5+P+R2/2K+S5/LPS6/2N1P1g+p+p/2GG1+s1+rk/5+s1b+p b G2LPb3n8p 1")
            return MatchStatus(gameState: .playing, players: ["player1", "player2"], position: position, moveHistory: [MoveHistoryItem(detailedMove: DetailedMove(special: .Ordinary, moveFrom: Square(Square.SQ_NB), moveTo: Square.fromFileRank(file: 2, rank: 6), sideToMove: PColor.WHITE, moveFromPieceType: Piece.GOLD, moveToPieceType: Piece.GOLD, isPromote: false, isDrop: true), usedTime: 1.0, scoreCp: -300)])
        }
    }
    
    static var previews: some View {
        MoveHistoryView(matchStatus: sampleMatchStatus)
    }
}
