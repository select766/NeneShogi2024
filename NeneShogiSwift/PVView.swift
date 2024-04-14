import SwiftUI


struct PVView: View {
    let gridSize = CGFloat(32)
    
    var searchProgress: SearchProgress?
    
    var pvString: String {
        if let searchProgress = searchProgress {
            // reservesSpace: true テキストが短くても2行分のスペースを確保する
            return searchProgress.pv.map({dMove in dMove.toPrintString()}).joined(separator: "")
        } else {
            return "読み筋"
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("評価値: \(searchProgress?.score?.description ?? "-")").foregroundStyle(.black)
                Text("NPS: \(searchProgress?.nps?.description ?? "-")").foregroundStyle(.black)
                Spacer()
            }
            // reservesSpace: true テキストが短くても2行分のスペースを確保する
            Text(pvString).lineLimit(2, reservesSpace: true).font(Font(UIFont.monospacedDigitSystemFont(ofSize: gridSize * 0.5, weight: .medium))).foregroundStyle(.black).frame(alignment: .leading)
        }.frame(maxWidth: .infinity).padding(.all, 1).background(Color.white.edgesIgnoringSafeArea([])).border(Color.black, width: 1)
    }
}

//struct PVView_Previews: PreviewProvider {
//    static var previews: some View {
//        PVView()
//    }
//}
