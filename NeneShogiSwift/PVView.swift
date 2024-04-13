import SwiftUI


struct PVView: View {
    let gridSize = CGFloat(32)
    
    var searchProgress: SearchProgress?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("評価値: \(searchProgress?.score?.description ?? "-")")
                Text("NPS: \(searchProgress?.nps?.description ?? "-")")
            }
            if let searchProgress = searchProgress {
                Text(searchProgress.pv.map({dMove in dMove.toPrintString()}).joined(separator: " "))
            } else {
                Text("読み筋")
            }
        }
    }
}

//struct PVView_Previews: PreviewProvider {
//    static var previews: some View {
//        PVView()
//    }
//}
