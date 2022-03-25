import Foundation
import Network

// AI種類選択
var playerClass = "MCTS"

class USIClient {
    let matchManager: MatchManager
    var serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(8090))
    var connection: NWConnection?
    let queue: DispatchQueue
    var recvBuffer: Data = Data()
    var player: PlayerProtocol?
    init(matchManager: MatchManager) {
        self.matchManager = matchManager // TODO: 循環参照回避
        queue = DispatchQueue(label: "usiClient")
    }
    
    func start() {
        self.matchManager.displayMessage("connecting to USI server")
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.matchManager.displayMessage("connected to USI server")
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
        self.matchManager.displayMessage("USI recv: '\(command)'")
        let splits = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if splits.count < 1 {
            return
        }
        let commandType = splits[0]
        let commandArg = splits.count == 2 ? String(splits[1]) : nil
        switch commandType {
        case "usi":
            switch playerClass {
            case "Random":
                self.player = RandomPlayer()
            case "Policy":
                self.player = PolicyPlayer()
            case "MCTS":
                self.player = MCTSPlayer()
            default:
                fatalError("Unknown player selection")
            }
            sendUSI(messages: ["id name NeneShogiSwift", "id author select766", "usiok"])
        case "isready":
            self.player?.isReady()
            sendUSI(message: "readyok")
        case "setoption":
            break
        case "usinewgame":
            self.player?.usiNewGame()
            break
        case "position":
            if let commandArg = commandArg {
                self.player?.position(positionArg: commandArg)
            }
            break
        case "go":
            guard let player = self.player else {
                fatalError()
            }
            let bestMove = player.go(info: {(message: String) in sendUSI(message: message)})
            sendUSI(message: "bestmove \(bestMove)")
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
    
    func _send(messageWithNewline: String) {
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
