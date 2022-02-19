//
//  ContentView.swift
//  NeneShogiSwift
//
//  Created by Masatoshi Hidaka on 2022/02/13.
//

import SwiftUI

struct ContentView: View {
    @State var latestMessage: String = "Press Start"
    @State var matchManager: MatchManager?
    
    func start() {
        if matchManager != nil {
            return
        }
        let shogiUIInterface = ShogiUIInterface(displayMessage: {message in DispatchQueue.main.async {
            self.latestMessage = message
        }
            
        })
        matchManager = MatchManager(shogiUIInterface: shogiUIInterface)
        matchManager?.start()
    }
    
    var body: some View {
        VStack {
            Text(latestMessage)
                .padding()
            Button(action: start) {
                Text("Start")
            }.padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
