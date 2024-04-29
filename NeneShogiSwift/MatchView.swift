//
//  MatchView.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/03/31.
//

import SwiftUI

struct MatchView: View {
    @ObservedObject var match: MatchViewModel
    @State var now = Date.now
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let engineStartInfo: EngineStartInfo
    
    init(engineStartInfo: EngineStartInfo) {
        match = MatchViewModel()
        self.engineStartInfo = engineStartInfo
    }

    var body: some View {
        Group {
            MatchStaticView(searchProgress: match.searchProgress, matchStatus: match.matchStatus, communicationHistory: match.communicationHistory, now: now)
        }.onReceive(timer, perform: {_ in
            self.now = Date.now
        }).onAppear {
            // スリープさせない
            UIApplication.shared.isIdleTimerDisabled = true
            start()
        }.onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    func start() {
        switch engineStartInfo {
        case .USI(let usiConfig):
            match.startUSI(usiConfig: usiConfig)
        case .CSA(let csaConfig):
            match.startCSA(csaConfig: csaConfig)
        }
    }
}
