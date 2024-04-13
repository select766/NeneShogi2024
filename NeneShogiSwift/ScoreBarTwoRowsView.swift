import SwiftUI

struct ScoreBarTwoRowsView: View {
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
            let gridSizeH = CGFloat(20.0)
            VStack(spacing: 0) {
                HStack {
                    Text("▲\(matchStatus.players[0] ?? "?")").foregroundStyle(.black).font(.system(size: gridSizeW * 0.8)).frame(width: gridSizeW * 8.0, height: gridSizeH, alignment: .leading)
                    Text("△\(matchStatus.players[1] ?? "?")").font(.system(size: gridSizeW * 0.8)).frame(width: gridSizeW * 8.0, height: gridSizeH, alignment: .trailing)
                }
                if case .playing = matchStatus.csaGameState {
                    HStack {
                        Text("\(blackWinratePercent) %").foregroundStyle(.black).font(.system(size: gridSizeW * 1.0)).frame(width: gridSizeW * 3.75)
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(Color.white).frame(width: gridSizeW * 9.375, height: gridSizeH * 0.9)
                            Rectangle().fill(Color.black).frame(width: CGFloat(gridSizeW * CGFloat(CGFloat(9.375) * CGFloat(blackWinratePercent) / CGFloat(100))), height: gridSizeH * 0.9)
                        }
                        Text("\(100 - blackWinratePercent) %").foregroundStyle(.black).font(.system(size: gridSizeW * 1.0)).frame(width: gridSizeW * 3.75)
                    }.frame(height: gridSizeH)
                } else {
                    Text(matchStatus.csaGameState.description).frame(height: gridSizeH)
                }
            }.frame(width: gridSizeW * 16.875, height: gridSizeH * 2.0).background(Color.yellow.edgesIgnoringSafeArea([]))
            // .edgesIgnoringSafeArea([]) がないと、セーフエリア外に黄色背景が伸びる
        }.frame(maxWidth: .infinity)
    }
}

struct ScoreBarTwoRoesView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreBarTwoRowsView(matchStatus: getSampleMatchStatus())
    }
}