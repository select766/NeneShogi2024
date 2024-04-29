import SwiftUI

struct ScoreBarView: View {
    var matchStatus: MatchStatus
    
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
        GeometryReader {
            geomerty in
            // 横幅いっぱいを使うためのサイズ
            let gridSizeW = geomerty.size.width / CGFloat(16.875)
            let gridSizeH = CGFloat(40.0)
            HStack {
                Text("▲\(matchStatus.players[0] ?? "?")").foregroundStyle(.black).font(.system(size: gridSizeW * 0.4)).frame(maxWidth: gridSizeW * 2.5)
                if case .playing = matchStatus.csaGameState {
                    Text("\(blackWinratePercent) %").foregroundStyle(.black).font(.system(size: gridSizeW * 0.5)).frame(width: gridSizeW * 1.25)
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(Color.white).frame(width: gridSizeW * 9.375, height: gridSizeH * 0.375)
                        Rectangle().fill(Color.black).frame(width: CGFloat(gridSizeW * CGFloat(CGFloat(9.375) * CGFloat(blackWinratePercent) / CGFloat(100))), height: gridSizeH * 0.375)
                    }
                    Text("\(100 - blackWinratePercent) %").foregroundStyle(.black).font(.system(size: gridSizeW * 0.5)).frame(width: gridSizeW * 1.25)
                } else {
                    Text(matchStatus.csaGameState.description)
                }
                Text("△\(matchStatus.players[1] ?? "?")").font(.system(size: gridSizeW * 0.4)).frame(maxWidth: gridSizeW * 2.5)
            }.frame(width: gridSizeW * 16.875, height: gridSizeH * 0.5).background(Color.yellow.edgesIgnoringSafeArea([]))
            // .edgesIgnoringSafeArea([]) がないと、セーフエリア外に黄色背景が伸びる
        }.frame(maxWidth: .infinity)
    }
}

struct ScoreBarView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreBarView(matchStatus: getSampleMatchStatus())
    }
}
