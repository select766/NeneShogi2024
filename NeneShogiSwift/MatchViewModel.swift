//
//  CSAViewModel.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/04/13.
//

import Foundation

struct MoveHistoryItem {
    let positionBeforeMove: Position
    let positionAfterMove: Position? // 「投了」など盤面が動かないものではnil
    let detailedMove: DetailedMove
    let usedTime: Double?
    let scoreCp: Int?
}

struct RemainingTime {
    let remainingTimeAt: Date // 手番開始時刻
    let remainingTime: Double // 手番開始時の残り時間
    let decreasing: Bool // 手番の時true
    
    var currentRemainingTime: Double {
        if decreasing {
            return remainingTime - Date.now.timeIntervalSince(remainingTimeAt)
        } else {
            return remainingTime
        }
    }
    
    init(remainingTimeAt: Date? = nil, remainingTime: Double, decreasing: Bool) {
        self.remainingTimeAt = remainingTimeAt ?? Date.now
        self.remainingTime = remainingTime
        self.decreasing = decreasing
    }
    
    func stopDecreasing() -> RemainingTime {
        return RemainingTime(remainingTimeAt: remainingTimeAt, remainingTime: remainingTime, decreasing: false)
    }
}

enum CSAGameState: CustomStringConvertible {
    case initializingUSI
    case initializingCSA
    case waitingNewGame
    case initializingNewGame
    case waitingGameStart
    case playing
    case ended
    
    var description: String {
        switch self {
        case .initializingUSI:
            return "エンジン初期化中"
        case .initializingCSA:
            return "サーバ接続中"
        case .waitingNewGame:
            return "対局相手決定待ち"
        case .initializingNewGame:
            return "対局初期化中"
        case .waitingGameStart:
            return "対局開始待ち"
        case .playing:
            return "対局中"
        case .ended:
            return "終局"
        }
    }
}

class CSAStatusCallback {
    weak var view: MatchViewModel?
    
    init(view: MatchViewModel) {
        self.view = view
    }

    func appendCommnicationHistory(_ message: String) {
        DispatchQueue.main.async {
            self.view?.communicationHistory.append(message)
        }
    }
    
    func updateMatchStatus(players: [String?], moveHistory: [MoveHistoryItem], remainingTimes: [RemainingTime?], csaGameState: CSAGameState, lastGameResult: String?) {
        DispatchQueue.main.async {
            if let view = self.view {
                let ls = view.matchStatus
                view.matchStatus = MatchStatus(engineMode: ls.engineMode, players: players, moveHistory: moveHistory, remainingTimes: remainingTimes, csaGameState: csaGameState, lastGameResult: lastGameResult)
            }
        }
    }
}

class USIStatusCallback {
    weak var view: MatchViewModel?
    
    init(view: MatchViewModel) {
        self.view = view
    }
    
    func appendCommnicationHistory(_ message: String) {
        DispatchQueue.main.async {
            self.view?.communicationHistory.append(message)
        }
    }

    func updateMatchStatus(players: [String?], moveHistory: [MoveHistoryItem]) {
        DispatchQueue.main.async {
            if let view = self.view {
                let ls = view.matchStatus
                view.matchStatus = MatchStatus(engineMode: ls.engineMode, players: players, moveHistory: moveHistory, remainingTimes: ls.remainingTimes, csaGameState: ls.csaGameState, lastGameResult: ls.lastGameResult)
            }
        }
    }
}

enum EngineMode: String {
    case USI = "USI"
    case CSA = "CSA"
}

class MatchViewModel: ObservableObject {
    @Published var matchStatus: MatchStatus
    @Published var communicationHistory: [String]

    var csaClient: CSAClient?
    var usiClient: USIClient?
    var engineMode: EngineMode?
    
    init() {
        matchStatus = MatchStatus(engineMode: nil, players: ["", ""], moveHistory: [], remainingTimes: [nil, nil], csaGameState: .initializingUSI, lastGameResult: nil)
        communicationHistory = []
    }
    
    func startCSA(csaConfig: CSAConfig) {
        if engineMode != nil {
            print("warning: start called twice")
            return
        }
        engineMode = .CSA
        csaClient = CSAClient(callback: CSAStatusCallback(view: self), csaConfig: csaConfig)
        csaClient?.start()
    }
    
    func startUSI(usiConfig: USIConfig) {
        if engineMode != nil {
            print("warning: start called twice")
            return
        }
        engineMode = .USI
        usiClient = USIClient(callback: USIStatusCallback(view: self), usiConfig: usiConfig)
        usiClient?.start()
    }
}
