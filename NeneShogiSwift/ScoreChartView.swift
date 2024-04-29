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
    
    private func getChartData(gridSize: CGFloat) -> ChartData {
        // 普通だと100手で右端に到達するので、101手以上なら横幅を2で割る、201手以上なら3で割るというようにして収める
        let units = max(ceil(Double(matchStatus.moveHistory.count) / 100.0), 1.0)
        let scale = CGFloat(1.0 / units)
        let barWidth = CGFloat(gridSize * 0.15625 * scale)
        var items: [ChartData.ChartDataItem] = []
        var lines: [ChartData.ChartVerticalLineItem] = []
        for (i, moveItem) in matchStatus.moveHistory.enumerated() {
            if i % 10 == 0 {
                lines.append(ChartData.ChartVerticalLineItem(id: i, position: CGPoint(x: gridSize * 0.625 + barWidth * CGFloat(i), y: gridSize * 0.625), size: CGSize(width: 1, height: gridSize * 1.25), dashed: i % 100 != 0))
            }
            if let scoreCp = moveItem.scoreCp {
                // scoreCpは手番側から見た値なので先手から見た値に統一
                let scoreCpBlack = moveItem.detailedMove.sideToMove == PColor.BLACK ? scoreCp : -scoreCp
                let height: CGFloat
                // positionで指定するのは中央の位置
                let posX = CGFloat(barWidth * CGFloat(i) + gridSize * 0.625) + barWidth / 2.0
                let posY: CGFloat
                if scoreCpBlack >= 0 {
                    height = min(CGFloat(Double(scoreCpBlack) / 1000.0 * gridSize * 0.625), gridSize * 0.625)
                    posY = gridSize * 0.625 - height + height / 2.0
                } else {
                    height = min(CGFloat(-Double(scoreCpBlack) / 1000.0 * gridSize * 0.625), gridSize * 0.625)
                    posY = gridSize * 0.625 + height / 2.0
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
        GeometryReader {
            geometry in
            let gridSize = geometry.size.width / 16.875
            let data = getChartData(gridSize: gridSize)
            ZStack(alignment: .topLeading) {
                
                HLine()
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .frame(width: gridSize * (16.875 - 0.625), height: 1)
                    .position(x: gridSize * (16.875 + 0.625) / 2, y: gridSize * 0.3125)
                HLine()
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 1))
                    .frame(width: gridSize * (16.875 - 0.625), height: 1)
                    .position(x: gridSize * (16.875 + 0.625) / 2, y: gridSize * 0.625)
                HLine()
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .frame(width: gridSize * (16.875 - 0.625), height: 1)
                    .position(x: gridSize * (16.875 + 0.625) / 2, y: gridSize * 0.9375)
                Text("500").font(.system(size: gridSize * 0.125)).frame(width: gridSize * 0.5625, height: gridSize * 0.3125, alignment: .trailing).position(x: gridSize * 0.3125, y: gridSize * 0.3125)
                Text("0").font(.system(size: gridSize * 0.125)).frame(width: gridSize * 0.5625, height: gridSize * 0.3125, alignment: .trailing).position(x: gridSize * 0.3125, y: gridSize * 0.625)
                Text("-500").font(.system(size: gridSize * 0.125)).frame(width: gridSize * 0.5625, height: gridSize * 0.3125, alignment: .trailing).position(x: gridSize * 0.3125, y: gridSize * 0.9375)
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
            }.frame(width: gridSize * 16.875, height: gridSize * 1.25).background(Color(red: 0.5, green: 1.0, blue: 1.0).edgesIgnoringSafeArea([]))
        }.frame(maxWidth: .infinity)
    }
}

struct ScoreChartView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreChartView(matchStatus: getSampleMatchStatus())
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
