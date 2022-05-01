import SwiftUI


struct PVView: View {
    struct PVLineItem: Identifiable {
        let id: Int
        let isBestRootMove: Bool
        let isSub: Bool
        var nodesRatio: Double
        let message: String
        let percent: String
        var color: Color
    }
    
    var searchProgress: SearchProgress
    
    private func pvsToString(pvs: [SearchTreeRootForVisualize]) -> [PVLineItem] {
        var items: [PVLineItem] = []
        var isBestRootMove = true
        for pv in pvs {
            let rm = pv.rootMoveNode
            // winrateMeanは、指したあとの手番の勝率なので反転させる
            items.append(PVLineItem(id: items.count, isBestRootMove: isBestRootMove, isSub: false, nodesRatio: Double(rm.moveCount), message: "\(rm.moveFromParent.toPrintString())", percent: " \(Int((1.0 - rm.winrateMean) * 100))%±\(Int(rm.winrateStd * 100))", color: Color.black))
            isBestRootMove = false
            for child in pv.childNodes {
                var s = ""
                s += "└\(child.moveFromParent.toPrintString())"
                for cpv in child.pv.prefix(1) { // スペースの都合で表示手数を決める
                    s += "\(cpv.toPrintString())"
                }
                items.append(PVLineItem(id: items.count, isBestRootMove: isBestRootMove, isSub: true, nodesRatio: Double(child.moveCount), message: s, percent: "", color: Color.black))
            }
        }
        
        // ノード数表示バーのスケールと配色を決める
        var maxMoveCount = 0.0
        for item in items {
            maxMoveCount = max(maxMoveCount, item.nodesRatio)
        }
        
        // 最大値を見て、100, 1000, 10000...で割って0~1に収める
        let scale = max(ceil(log10(maxMoveCount + 1.0)), 2.0)
        // 100=青、1000=緑, 10000=オレンジ, 100000=赤
        let hue: Double
        switch Int(scale) {
        case 2:
            hue = 240.0 / 360.0
        case 3:
            hue = 160.0 / 360.0
        case 4:
            hue = 40.0 / 360.0
        default:
            hue = 0.0
        }
        let div = pow(10.0, scale)
        for i in 0..<items.count {
            items[i].nodesRatio /= div
            items[i].color = Color(hue: hue, saturation: items[i].isSub ? 0.125 : 0.25, brightness: 1.0)
        }
        return items
    }

    var body: some View {
        let pad: CGFloat = 2
        let width: CGFloat = 1080 - 768 - 16 // 16は将棋盤との左右スペース
        let contentWidth: CGFloat = width - pad * 2
        VStack(alignment: .center) {
            Text("ノード数: \(searchProgress.totalNodes), NPS: \(searchProgress.nps)").font(Font(UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)))
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pvsToString(pvs: searchProgress.pvs)) {
                    item in
                    let height: CGFloat = item.isBestRootMove ? 30 : 20
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(item.color).frame(width: CGFloat(item.nodesRatio) * contentWidth, height: height)
                        HStack(alignment: .bottom) {
                            Text(item.message).font(Font(UIFont.monospacedDigitSystemFont(ofSize: height, weight: .medium))).lineLimit(1).frame(alignment: .leading)
                            Text(item.percent).font(Font(UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium))).lineLimit(1).frame(alignment: .leading)
                        }.frame(width: contentWidth, height: height, alignment: .leading)
                    }.frame(width: contentWidth, height: height)
                }
            }

            Spacer()
        }.padding(pad).background(Color.white).border(Color.gray, width: pad).frame(width: width, height: 320)
    }
}

//struct PVView_Previews: PreviewProvider {
//    static var previews: some View {
//        PVView()
//    }
//}
