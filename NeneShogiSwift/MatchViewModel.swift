//
//  CSAViewModel.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/04/13.
//

import Foundation
import os

private let logger = Logger(subsystem: "jp.outlook.select766.NeneShogiSwift", category: "MatchViewModel")


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

    // 将棋所では、指し終わった時に指した側の残り時間表示にフィッシャーの加算がなされるので、見た目はこのソフトの方が持ち時間がフィッシャー分短くなる。

    func currentRemainingTime(now: Date) -> Double {
        if decreasing {
            return remainingTime - now.timeIntervalSince(remainingTimeAt)
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


struct USISearchProgress {
    // infoコマンドのパース結果
    let depth: Int?, selDepth: Int?, time: Double?, nodes: Int?, pvUSI: [String]?, multiPV: Int?, score: Int?, currMoveUSI: String?, hashFull: Int?, nps: Int?, string: String?
    
    static func parseGoInfo(commandArg: String) -> USISearchProgress {
        // commandArg: "info depth 1..." or "depth 1..." both ok
        var score: Int? = nil
        var pvUSI: [String]? = nil
        var tokens: [String] = commandArg.split(separator: " ").map{s in String(s)}
        var depth: Int? = nil
        var selDepth: Int? = nil
        var time: Double? = nil
        var nodes: Int? = nil
        var multiPV: Int? = nil
        var currMoveUSI: String? = nil
        var hashFull: Int? = nil
        var nps: Int? = nil
        var string: String? = nil
        while tokens.count > 0 {
            let subcmd = tokens.removeFirst()
            switch subcmd {
            case "info":
                break
            case "depth":
                if tokens.isEmpty {
                    break
                }
                depth = Int(tokens.removeFirst())
            case "seldepth":
                if tokens.isEmpty {
                    break
                }
                selDepth = Int(tokens.removeFirst())
            case "time":
                if tokens.isEmpty {
                    break
                }
                if let timeInt = Int(tokens.removeFirst()) {
                    time = Double(timeInt) / 1000.0
                }
            case "nodes":
                if tokens.isEmpty {
                    break
                }
                nodes = Int(tokens.removeFirst())
            case "pv":
                pvUSI = tokens
                tokens = []
            case "multipv":
                if tokens.isEmpty {
                    break
                }
                // パースはするものの、multipvを想定した表示機能は未実装
                multiPV = Int(tokens.removeFirst())
            case "score":
                let cpOrMate = tokens.removeFirst()
                let value = tokens.removeFirst()
                if tokens.count > 0 {
                    // lowerbound or upperbound
                    if tokens.first == "lowerbound" {
                        tokens.removeFirst()
                    } else if tokens.first == "upperbound" {
                        tokens.removeFirst()
                    }
                }
                if cpOrMate == "cp" {
                    score = Int(value)
                } else if cpOrMate == "mate" {
                    let mateBase = 32000
                    if let parsedValue = Int(value) {
                        if parsedValue > 0 {
                            // 手番側が parsedValue 手で勝つ
                            score = mateBase - parsedValue
                        } else {
                            // 相手側が -parsedValue 手で勝つ
                            score = -mateBase - parsedValue
                        }
                    } else {
                        if value == "+" {
                            score = mateBase
                        } else if value == "-" {
                            score = -mateBase
                        }
                    }
                }
            case "currmove":
                if tokens.isEmpty {
                    break
                }
                currMoveUSI = tokens.removeFirst()
            case "hashfull":
                if tokens.isEmpty {
                    break
                }
                hashFull = Int(tokens.removeFirst())
            case "nps":
                if tokens.isEmpty {
                    break
                }
                nps = Int(tokens.removeFirst())
            case "string":
                string = tokens.joined(separator: " ")
                tokens = []
            default:
                // unknown
                logger.warning("unknown usi info token \(subcmd, privacy: .public)")
                tokens = []
            }
        }
        
        return USISearchProgress(depth: depth, selDepth: selDepth, time: time, nodes: nodes, pvUSI: pvUSI, multiPV: multiPV, score: score, currMoveUSI: currMoveUSI, hashFull: hashFull, nps: nps, string: string)
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
    
    func updateSearchProgress(searchProgress: SearchProgress) {
        DispatchQueue.main.async {
            if let view = self.view {
                view.searchProgress = searchProgress
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
    @Published var searchProgress: SearchProgress?

    var csaClient: CSAClient?
    var usiClient: USIClient?
    var engineMode: EngineMode?
    
    init() {
        matchStatus = MatchStatus(engineMode: nil, players: ["", ""], moveHistory: [], remainingTimes: [nil, nil], csaGameState: .initializingUSI, lastGameResult: nil)
        communicationHistory = []
    }
    
    func startCSA(csaConfig: CSAConfig) {
        if engineMode != nil {
            logger.error("startCSA called twice")
            return
        }
        engineMode = .CSA
        csaClient = CSAClient(callback: CSAStatusCallback(view: self), csaConfig: csaConfig)
        csaClient?.start()
    }
    
    func startUSI(usiConfig: USIConfig) {
        if engineMode != nil {
            logger.error("startUSI called twice")
            return
        }
        engineMode = .USI
        usiClient = USIClient(callback: USIStatusCallback(view: self), usiConfig: usiConfig)
        usiClient?.start()
    }
}
