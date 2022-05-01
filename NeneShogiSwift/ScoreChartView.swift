import SwiftUI

struct ScoreChartView: View {
    var matchStatus: MatchStatus
    
    struct ChartData {
        struct ChartDataItem: Identifiable {
            let id: Int
            let color: Color
            let position: CGPoint
            let size: CGSize
        }
        
        struct ChartVerticalLineItem: Identifiable {
            let id: Int
            let position: CGPoint
            let size: CGSize
            let dashed: Bool
        }
        
        let items: [ChartDataItem]
        let lineItems: [ChartVerticalLineItem]
    }
    
    private func getChartData() -> ChartData {
        // 普通だと100手で右端に到達するので、101手以上なら横幅を2で割る、201手以上なら3で割るというようにして収める
        let units = max(ceil(Double(matchStatus.moveHistory.count) / 100.0), 1.0)
        let scale = 1.0 / units
        let barWidth = CGFloat(10.0 * scale)
        var items: [ChartData.ChartDataItem] = []
        var lines: [ChartData.ChartVerticalLineItem] = []
        for (i, moveItem) in matchStatus.moveHistory.enumerated() {
            if i % 10 == 0 {
                lines.append(ChartData.ChartVerticalLineItem(id: i, position: CGPoint(x: 40.0 + barWidth * CGFloat(i), y: 40.0), size: CGSize(width: 1, height: 80), dashed: i % 100 != 0))
            }
            if let scoreCp = moveItem.scoreCp {
                // scoreCpは手番側から見た値なので先手から見た値に統一
                let scoreCpBlack = moveItem.detailedMove.sideToMove == PColor.BLACK ? scoreCp : -scoreCp
                let height: CGFloat
                // positionで指定するのは中央の位置
                let posX = CGFloat(barWidth * CGFloat(i) + 40.0) + barWidth / 2.0
                let posY: CGFloat
                if scoreCpBlack >= 0 {
                    height = min(CGFloat(Double(scoreCpBlack) / 1000.0 * 40.0), 40.0)
                    posY = 40.0 - height + height / 2.0
                } else {
                    height = min(CGFloat(-Double(scoreCpBlack) / 1000.0 * 40.0), 40.0)
                    posY = 40.0 + height / 2.0
                }
                items.append(ChartData.ChartDataItem(id: i, color: moveItem.detailedMove.sideToMove == PColor.BLACK ? Color.black : Color.white, position: CGPoint(x: posX, y: posY), size: CGSize(width: barWidth, height: height)))
            }
        }
        
        return ChartData(items: items, lineItems: lines)
    }
    
    struct HLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            return path
        }
    }
    
    struct VLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            return path
        }
    }
    
    var body: some View {
        let data = getChartData()
        ZStack(alignment: .topLeading) {
            
            HLine()
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                .frame(width: 1080 - 40, height: 1)
                .position(x: (1080 + 40) / 2, y: 20)
            HLine()
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1))
                .frame(width: 1080 - 40, height: 1)
                .position(x: (1080 + 40) / 2, y: 40)
            HLine()
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                .frame(width: 1080 - 40, height: 1)
                .position(x: (1080 + 40) / 2, y: 60)
            Text("500").font(.footnote).frame(width: 36, height: 20, alignment: .trailing).position(x: 20, y: 20)
            Text("0").font(.footnote).frame(width: 36, height: 20, alignment: .trailing).position(x: 20, y: 40)
            Text("-500").font(.footnote).frame(width: 36, height: 20, alignment: .trailing).position(x: 20, y: 60)
            ForEach(data.items) {
                item in
                Rectangle().fill(item.color).frame(width: item.size.width, height: item.size.height, alignment: .topLeading).position(item.position)
            }
            ForEach(data.lineItems) {
                lineItem in
                lineItem.dashed ?
                    VLine()
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .frame(width: lineItem.size.width, height: lineItem.size.height)
                        .position(lineItem.position)
                :
                    VLine()
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 1))
                        .frame(width: lineItem.size.width, height: lineItem.size.height)
                        .position(lineItem.position)
            }
        }.frame(width: 1080, height: 80).background(Color(red: 0.5, green: 1.0, blue: 1.0))
    }
}

struct ScoreChartView_Previews: PreviewProvider {
    static var sampleMatchStatus: MatchStatus {
        get {
            let position = Position()
            position.setSFEN(sfen: "9/1+P7/2+P+P4l/5+P+R2/2K+S5/LPS6/2N1P1g+p+p/2GG1+s1+rk/5+s1b+p b G2LPb3n8p 1")
            var history: [MoveHistoryItem] = []
            for (i, scoreCp) in [100, -120, 200, -240, -500, 990, -1050, 10, 20, -50, 100, -200, 30000, 10].enumerated() {
                history.append(MoveHistoryItem(detailedMove: DetailedMove(special: .Ordinary, moveFrom: Square(Square.SQ_NB), moveTo: Square.fromFileRank(file: 2, rank: 6), sideToMove: i % 2 == 0 ? PColor.BLACK : PColor.WHITE, moveFromPieceType: Piece.GOLD, moveToPieceType: Piece.GOLD, isPromote: false, isDrop: true), usedTime: 1.0, scoreCp: scoreCp))
            }
            return MatchStatus(gameState: .playing, players: ["player1", "player2"], position: position, moveHistory: history)
        }
    }

    static var previews: some View {
        ScoreChartView(matchStatus: sampleMatchStatus)
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
