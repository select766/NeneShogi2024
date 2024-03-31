//
//  MatchStaticView.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/03/31.
//

import SwiftUI

struct MatchStaticView: View {
    let gridSize = CGFloat(32)
    var latestMessage: String = "Press Start"
    var searchProgress: SearchProgress?
    var matchStatus: MatchStatus
    var communicationHistory: [CommunicationItem]
    var commuicationHistoryDisplay: [CommunicationHistoryDisplayItem]
    @State var debugView = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScoreBarView(matchStatus: matchStatus)
            ScoreChartView(matchStatus: matchStatus)
            HStack {
                BoardView(matchStatus: matchStatus)
                VStack(alignment: .center) {
                    if debugView {
                        ScrollView(.vertical, showsIndicators: true) {
                            ScrollViewReader {
                                proxy in
                                VStack(alignment: .leading) {
                                    ForEach(commuicationHistoryDisplay) {cItem in
                                        Text(cItem.displayString).id(cItem.id)
                                    }
                                }.onChange(of: (self.commuicationHistoryDisplay.last?.id ?? 0), perform: {
                                    value in proxy.scrollTo(value, anchor: .bottom)
                                })
                            }
                            
                        }.frame(maxWidth: .infinity, maxHeight: gridSize * 9.375)
                    } else {
                        if let searchProgress = searchProgress {
                            PVView(searchProgress: searchProgress)
                        }
                        
                        MoveHistoryView(matchStatus: matchStatus)
                    }
                    Text(latestMessage)
                    Spacer()
                    Button(action: {
                        debugView = !debugView
                    }) {
                        Text("Debug")
                    }
                }
            }
        }.background(Color(red: 0.8, green: 0.8, blue: 0.8))
    }
}

#Preview {
    MatchStaticView(
        latestMessage: "Hello", matchStatus: MatchStatus(gameState: .playing, players: ["player1", "player2"], position: Position(), moveHistory: []), communicationHistory: [], commuicationHistoryDisplay: [])
}
