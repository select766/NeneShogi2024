import Foundation
import Network

class USIClient {
    let matchManager: MatchManager
    let usiConfig: USIConfig
    var serverEndpoint: NWEndpoint
    var connection: NWConnection?
    let queue: DispatchQueue
    var recvBuffer: Data = Data()
    var goRunning = false
    var lastPositionArg: String? = nil
    var position: Position // 手番把握のためにAIとは別に必要
    var moveHistory: [MoveHistoryItem] = []
    
    init(matchManager: MatchManager, usiConfig: USIConfig) {
        self.matchManager = matchManager // TODO: 循環参照回避
        self.usiConfig = usiConfig
        queue = DispatchQueue(label: "usiClient")
        self.serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(self.usiConfig.usiServerIpAddress), port: NWEndpoint.Port(rawValue: self.usiConfig.usiServerPort)!)
        position = Position()
    }
    
    func start() {
        self.matchManager.displayMessage("connecting to USI server")
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.matchManager.displayMessage("connected to USI server")
                self.startYane()
                self.startRecv()
            case .waiting(let nwError):
                // ネットワーク構成が変化するまで待つ=事実上の接続失敗
                // TODO: 接続失敗時のアクション
                self.matchManager.displayMessage("Failed to connect to USI server: \(nwError)")
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }
    
    private func startYane() {
        // やねうら王とのプロセス内通信準備
        startYaneuraou(recvCallback: {
            usiSendLine in
            self.queue.async {
                self.sendUSI(message: usiSendLine)
            }
        })
    }
    
    func startRecv() {
        connection?.receive(minimumIncompleteLength: 0, maximumLength: 65535, completion: {(data,context,flag,error) in
            if let error = error {
                self.matchManager.displayMessage("USI receive error \(error)")
                print("receive error", error)
            } else {
                if let data = data {
                    self.recvBuffer.append(data)
                    while true {
                        if let lfPos = self.recvBuffer.firstIndex(of: 0x0a) {
                            var lineEndPos = lfPos
                            // CRをカット
                            if lineEndPos > 0 && self.recvBuffer[lineEndPos - 1] == 0x0d {
                                lineEndPos -= 1
                            }
                            if let commandStr = String(data: self.recvBuffer[..<lineEndPos], encoding: .utf8) {
                                self.matchManager.pushCommunicationHistory(communicationItem: CommunicationItem(direction: .recv, message: commandStr))
                                self.handleUSICommand(command: commandStr)
                            } else {
                                print("Cannot decode USI data as utf-8")
                                self.matchManager.displayMessage("Cannot decode USI data as utf-8")
                            }
                            // Data()で囲わないと、次のfirstIndexで返る値が接続開始時からの全文字列に対するindexになる？バグか仕様か不明
                            self.recvBuffer = Data(self.recvBuffer[(lfPos+1)...])
                        } else {
                            break
                        }
                    }
                    self.startRecv()
                } else {
                    // コネクション切断で発生
                    self.matchManager.displayMessage("USI disconnected")
                }
            }
        })
    }

    func handleUSICommand(command: String) {
        // やねうら王に送る
        sendToYaneuraou(messageWithoutNewLine: command)
        handleUSICommandForDisplay(command: command)
    }
    
    func handleUSICommandForDisplay(command: String) {
        // 画面表示用にUSI受信コマンドをパースする
        self.matchManager.displayMessage("USI recv: '\(command)'")
        let splits = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if splits.count < 1 {
            return
        }
        let commandType = splits[0]
        let commandArg = splits.count == 2 ? String(splits[1]) : nil
        switch commandType {
        case "usi":
            break
        case "isready":
            break
        case "setoption":
            break
        case "usinewgame":
            moveHistory = []
            break
        case "position":
            if let commandArg = commandArg {
                position.setUSIPosition(positionArg: commandArg)
                // ponderが終わってから、positionを設定するためgoの内部で設定
                lastPositionArg = commandArg
                
                // 盤面表示の更新
                // 自分が指した手は直接は表示できない(相手が指した後のpositionコマンドを待つ必要がある)
                let positionForDetailedMove = Position()
                positionForDetailedMove.setSFEN(sfen: position.originSFEN)
                var mh: [MoveHistoryItem] = []
                for move in position.moveStack {
                    let dm = positionForDetailedMove.makeDetailedMove(move: move)
                    // 消費時間は含まれていない
                    mh.append(MoveHistoryItem(detailedMove: dm, usedTime: nil, scoreCp: nil))
                    positionForDetailedMove.doMove(move: move)
                }
                moveHistory = mh
                
                let players: [String?] = position.sideToMove == PColor.BLACK ? ["my", "opponent"] : ["opponent", "my"]
                
                matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: .playing, players: players, position: positionForDetailedMove.copy(), moveHistory: moveHistory))
            }
            break
        case "go":
//            let thinkingTime: ThinkingTime
//            if let commandArg = commandArg {
//                thinkingTime = parseThinkingTime(commandArg: commandArg)
//            } else {
//                // 便宜上秒読み10秒にしておく
//                thinkingTime = ThinkingTime(ponder: false, remaining: 0.0, byoyomi: 10.0, fisher: 0.0)
//            }
            break
        case "stop":
            break
        case "gameover":
            break
        case "quit":
            // 接続を切断することで接続先のncコマンドが終了する
            connection?.cancel()
            connection = nil
            // TODO: AI側終了
        default:
            print("Unknown command \(command)")
        }
    }
    
    
    func parseThinkingTime(commandArg: String) -> ThinkingTime {
        //　positionで指定された手番側の持ち時間を取得する
        let sideToMove = position.sideToMove
        let parts = commandArg.split(separator: " ", omittingEmptySubsequences: false)
        var idx = 0
        var remainingTime = 0.0
        var byoyomi = 0.0
        var fisher = 0.0
        while idx < parts.count {
            let key = parts[idx]
            idx += 1
            switch key {
            case "btime":
                if sideToMove == PColor.BLACK {
                    remainingTime = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            case "wtime":
                if sideToMove == PColor.WHITE {
                    remainingTime = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            case "byoyomi":
                byoyomi = (Double(parts[idx]) ?? 0.0) / 1000.0
                idx += 1
            case "binc":
                if sideToMove == PColor.BLACK {
                    fisher = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            case "winc":
                if sideToMove == PColor.WHITE {
                    fisher = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            default:
                print("Warning: unsupported go argument \(key)")
            }
        }
        return ThinkingTime(ponder: false, remaining: remainingTime, byoyomi: byoyomi, fisher: fisher)
    }
    
    func _send(messageWithNewline: String) {
        // サーバへのUSIメッセージ送信
        for line in messageWithNewline.components(separatedBy: "\n") {
            if line.count > 0 {
                matchManager.pushCommunicationHistory(communicationItem: CommunicationItem(direction: .send, message: line))
            }
        }
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                print("Error in send", error)
            }
        })
        
    }
    
    func sendUSI(message: String) {
        _send(messageWithNewline: message + "\n")
    }
    
    func sendUSI(messages: [String]) {
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
}
