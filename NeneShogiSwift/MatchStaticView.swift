//
//  MatchStaticView.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/03/31.
//

import SwiftUI

struct MatchStaticView: View {
    struct CommunicationHistoryForDisplayItem: Identifiable {
        let id: Int
        let message: String
    }
    let gridSize = CGFloat(32)
    var searchProgress: SearchProgress?
    var matchStatus: MatchStatus
    var communicationHistory: [String]
    @State var debugView = false
    
    var communicationHistoryForDisplay: [CommunicationHistoryForDisplayItem] {
        let bottom = max(communicationHistory.count - 100, 0)
        var items = [CommunicationHistoryForDisplayItem]()
        for i in bottom..<communicationHistory.count {
            items.append(CommunicationHistoryForDisplayItem(id: i, message: communicationHistory[i]))
        }
        return items
    }
    
    var body: some View {
        ZStack {
            Color(red: 254.0/255, green: 249.0/255, blue: 200.0/255).ignoresSafeArea()
            GeometryReader {
                geometry in
                HStack(spacing: 0) {
                    // BoardViewが親ビューに合わせて最大限大きくなるよう自分のサイズを決める。残りをVStackの各ビューが使う。
                    BoardView(maxSize: geometry.size, matchStatus: matchStatus)
                    VStack(spacing: 0) {
                        ScoreBarView(matchStatus: matchStatus)
                        ScoreChartView(matchStatus: matchStatus)
                        if debugView {
                            ScrollView(.vertical, showsIndicators: true) {
                                ScrollViewReader {
                                    proxy in
                                    VStack(alignment: .leading) {
                                        ForEach(communicationHistoryForDisplay) {cItem in
                                            Text(cItem.message).id(cItem.id)
                                        }
                                    }.onChange(of: (self.communicationHistoryForDisplay.last?.id ?? 0), perform: {
                                        value in proxy.scrollTo(value, anchor: .bottom)
                                    })
                                }
                                
                            }.frame(maxWidth: .infinity, maxHeight: gridSize * 9.375)
                        } else {
                            if let searchProgress = searchProgress {
                                PVView(searchProgress: searchProgress)
                            }
                            
                            // 縦方向残り領域全部を使いたいが方法がわからない
                            MoveHistoryView(matchStatus: matchStatus).frame(height: 300)
                        }
                        Spacer()
                        Button(action: {
                            debugView = !debugView
                        }) {
                            Text("Debug")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MatchStaticView(
        matchStatus: getSampleMatchStatus(),
        communicationHistory: []
    )
}
