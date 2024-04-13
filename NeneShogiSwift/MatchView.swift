//
//  MatchView.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/03/31.
//

import SwiftUI

struct MatchView: View {
    @ObservedObject var match: MatchViewModel
    let engineStartInfo: EngineStartInfo
    
    init(engineStartInfo: EngineStartInfo) {
        match = MatchViewModel()
        self.engineStartInfo = engineStartInfo
    }

    var body: some View {
        Group {
            MatchStaticView(matchStatus: match.matchStatus, communicationHistory: match.communicationHistory)
        }.onAppear {
            start()
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
