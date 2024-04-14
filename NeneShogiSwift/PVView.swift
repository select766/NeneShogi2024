import SwiftUI


struct PVView: View {
    let gridSize = CGFloat(32)
    
    var searchProgress: SearchProgress?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("評価値: \(searchProgress?.score?.description ?? "-")").foregroundStyle(.black)
                Text("NPS: \(searchProgress?.nps?.description ?? "-")").foregroundStyle(.black)
                Spacer()
            }
            HStack {
                if let searchProgress = searchProgress {
                    Text(searchProgress.pv.map({dMove in dMove.toPrintString()}).joined(separator: " ")).foregroundStyle(.black)
                } else {
                    Text("読み筋").foregroundStyle(.black)
                }
                Spacer()
            }
        }.frame(maxWidth: .infinity).padding(.all, 1).background(Color.white.edgesIgnoringSafeArea([])).border(Color.black, width: 1)
    }
}

//struct PVView_Previews: PreviewProvider {
//    static var previews: some View {
//        PVView()
//    }
//}
