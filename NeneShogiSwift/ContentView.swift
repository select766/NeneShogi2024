import SwiftUI

struct ContentView: View {
    @State var engineStartInfo: EngineStartInfo?

    var body: some View {
        if let engineStartInfo = engineStartInfo {
            MatchView(engineStartInfo: engineStartInfo)
        } else {
            ConfigView(onStart: {
                engineStartInfo in self.engineStartInfo = engineStartInfo
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
