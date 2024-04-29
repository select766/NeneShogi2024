//
//  MatchView.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/03/31.
//

import SwiftUI

struct MatchView: View {
    var serverType: String
    var usiConfig: USIConfig?
    var csaConfig: CSAConfig?
    @State var latestMessage: String = "Press Start"
    @State var searchProgress: SearchProgress? = nil
    @State var matchStatus: MatchStatus? = nil
    @State var matchManager: MatchManager?
    @State var communicationHistory: [CommunicationItem] = []
    @State var commuicationHistoryDisplay: [CommunicationHistoryDisplayItem] = []

    var body: some View {
        Group {
            if let matchStatus = matchStatus {
                MatchStaticView(latestMessage: latestMessage, searchProgress: searchProgress, matchStatus: matchStatus, communicationHistory: communicationHistory, commuicationHistoryDisplay: commuicationHistoryDisplay)
            } else {
                Text("Waiting for match to start")
            }
        }.onAppear {
            start()
        }
    }

    func start() {
        if matchManager != nil {
            return
        }
        let shogiUIInterface = ShogiUIInterface(displayMessage: {message in DispatchQueue.main.async {
            self.latestMessage = message
        }
        }, pushCommunicaionHistory: { communicationItem in
            DispatchQueue.main.async {
                self.communicationHistory.append(communicationItem)
                
                var cis: [CommunicationHistoryDisplayItem] = []
                for i in max(0, self.communicationHistory.count - 1000)..<self.communicationHistory.count {
                    let ci = self.communicationHistory[i]
                    let prefix: String
                    switch ci.direction {
                    case .recv:
                        prefix = "< "
                    case .send:
                        prefix = "> "
                    }
                    cis.append(CommunicationHistoryDisplayItem(id: i, displayString: prefix + ci.message))
                }
                commuicationHistoryDisplay = cis
            }
        }, updateMatchStatus: {matchStatus in DispatchQueue.main.async {
            self.matchStatus = matchStatus
        }}, updateSearchProgress: {searchProgress in DispatchQueue.main.async {
            self.searchProgress = searchProgress
        }})
        matchManager = MatchManager(shogiUIInterface: shogiUIInterface)
        if serverType == "USI" {
            matchManager?.startUSI(usiConfig: usiConfig!)
        } else if serverType == "CSA" {
            matchManager?.startCSA(csaConfig: csaConfig!)
        }
    }
}
