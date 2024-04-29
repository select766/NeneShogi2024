import SwiftUI

struct MoveHistoryView: View {
    let gridSize = CGFloat(32)

    struct MoveHistoryDisplayItem: Identifiable {
        let id: Int
        let tekazu: Int
        let detailedMove: DetailedMove
        let usedTime: Int?
        let totalUsedTime: Int
        let scoreCp: Int?
        
        private func timeToString(sec: Int) -> String {
            return "\(String(format: "%02d", sec / 60)):\(String(format: "%02d", sec % 60))"
        }
        
        func toPrintString() -> String {
            let scoreFormatter = NumberFormatter()
            scoreFormatter.numberStyle = .none
            scoreFormatter.positivePrefix = "+" // 正の評価値にプラスをつける
            var scoreStr = ""
            if let scoreCp = scoreCp {
                if let formatted = scoreFormatter.string(for: scoreCp) {
                    scoreStr = " / \(formatted)"
                }
            }
            
            return "\(String(format: "%3d", tekazu)) \(detailedMove.toPrintString()) \(usedTime != nil ? String(format: "%3d", usedTime!) : "*") / \(timeToString(sec: totalUsedTime))\(scoreStr)"
        }
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
        GeometryReader {
            geometry in
            VStack {
                Text("指し手 消費時間/合計/評価値").foregroundStyle(.black).font(.system(size: gridSize * 0.5))
                ScrollView(.vertical, showsIndicators: true) {
                    ScrollViewReader {
                        proxy in
                        VStack(alignment: .leading) {
                            ForEach(moveHistory) {moveHistoryItem in
                                Text(moveHistoryItem.toPrintString()).foregroundStyle(.black).font(Font(UIFont.monospacedDigitSystemFont(ofSize: gridSize * 0.5, weight: .medium))).lineLimit(1).minimumScaleFactor(0.1)
                            }
                        }.onChange(of: matchStatus.moveHistory.count - 1, perform: {
                            // withAnimationをつけるとかっこいいが、アニメーションが終わる前に次の手が進むと一番下までスクロールしないままになる
                            value in
                            proxy.scrollTo(value, anchor: .bottom)
                        })
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.background(Color.white.edgesIgnoringSafeArea([]))
        }
    }
}

struct MoveHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        MoveHistoryView(matchStatus: getSampleMatchStatus())
    }
}
