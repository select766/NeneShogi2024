import SwiftUI

struct ScoreBarTwoRowsView: View {
    var matchStatus: MatchStatus
    var now: Date
    
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
    
    private func timeToString(sec: Int) -> String {
        return "\(String(format: "%02d", sec / 60)):\(String(format: "%02d", sec % 60))"
    }
    
    func getPlayerInfo(index: Int) -> String {
        var s = ""
        if index == 0 {
            s += "▲"
        } else {
            s += "△"
        }
        s += "\(matchStatus.players[index] ?? "?")"
        return s
    }
    
    func getRemainingTimeString(now: Date) -> String {
        if matchStatus.csaGameState == .playing {
            var tss = ["", ""]
            for i in 0..<2 {
                if let rt = matchStatus.remainingTimes[i] {
                    tss[i] = timeToString(sec: Int(rt.currentRemainingTime(now: now)))
                }
            }
            return "\(tss[0]) 残 \(tss[1])"
        } else {
            return ""
        }
        
    }

    var body: some View {
        let blackWinratePercent = getBlackWinratePercent()
        GeometryReader {
            geomerty in
            // 横幅いっぱいを使うためのサイズ
            let gridSizeW = geomerty.size.width / CGFloat(16.875)
            let gridSizeH = CGFloat(20.0)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(getPlayerInfo(index: 0)).foregroundStyle(.black).font(.system(size: gridSizeW * 0.8)).frame(width: gridSizeW * 5.0, height: gridSizeH, alignment: .leading).padding(.horizontal, gridSizeW * 0.2)
                    Text(getRemainingTimeString(now: now)).foregroundStyle(.black).font(Font(UIFont.monospacedDigitSystemFont(ofSize: gridSizeW * 0.8, weight: .medium))).frame(width: gridSizeW * 6.0, height: gridSizeH, alignment: .center)
                    Text(getPlayerInfo(index: 1)).foregroundStyle(.black).font(.system(size: gridSizeW * 0.8)).frame(width: gridSizeW * 5.0, height: gridSizeH, alignment: .trailing).padding(.horizontal, gridSizeW * 0.2)
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
                    Text(matchStatus.csaGameState.description).foregroundStyle(.black).frame(height: gridSizeH)
                }
            }.frame(width: gridSizeW * 16.875, height: gridSizeH * 2.0).background(Color.yellow.edgesIgnoringSafeArea([]))
            // .edgesIgnoringSafeArea([]) がないと、セーフエリア外に黄色背景が伸びる
        }.frame(maxWidth: .infinity)
    }
}

struct ScoreBarTwoRowsView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreBarTwoRowsView(matchStatus: getSampleMatchStatus(), now: Date(timeIntervalSince1970: 0))
    }
}
