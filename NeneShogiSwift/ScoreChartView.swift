import SwiftUI

struct ScoreChartView: View {
    var matchStatus: MatchStatus
    var body: some View {
        ZStack {
            Text("X")
        }.background(Color.blue).frame(width: 1080, height: 60)
    }
}

//struct ScoreChartView_Previews: PreviewProvider {
//    static var previews: some View {
//        ScoreChartView()
//    }
//}
