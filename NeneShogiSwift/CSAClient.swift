import Foundation
import Network

class CSAClient {
    let matchManager: MatchManager
    var serverEndpoint: NWEndpoint
    var connection: NWConnection?
    let queue: DispatchQueue
    var recvBuffer: Data = Data()
    var player: PlayerProtocol?
    var myColor: PColor?

    init(matchManager: MatchManager, csaServerIpAddress: String) {
        self.matchManager = matchManager // TODO: 循環参照回避
        queue = DispatchQueue(label: "csaClient")
        self.serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(csaServerIpAddress), port: NWEndpoint.Port(4081))
    }
    
    func start() {
        self.matchManager.displayMessage("connecting to CSA server")
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.matchManager.displayMessage("connected to CSA server")
                self.sendCSA(message: "LOGIN nene test-300-10F") // TODO 設定可能にする
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
                self.matchManager.displayMessage("CSA receive error \(error)")
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
                                self.handleCSACommand(command: commandStr)
                            } else {
                                print("Cannot decode CSA data as utf-8")
                                self.matchManager.displayMessage("Cannot decode CSA data as utf-8")
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
                    self.matchManager.displayMessage("CSA disconnected")
                }
            }
        })
    }
    
    func handleCSACommand(command: String) {
        self.matchManager.displayMessage("CSA recv: '\(command)'")
        if command.starts(with: "Your_Turn") {
            if command == "Your_Turn:+" {
                myColor = PColor.BLACK
            } else if command == "Your_Turn:-" {
                myColor = PColor.WHITE
            } else {
                fatalError("Unknown turn")
            }
        } else if command.starts(with: "END Game_Summary") {
            self.sendCSA(message: "AGREE")
        } else if command.starts(with: "START") {
            if myColor == PColor.BLACK {
                // 初手
                self.sendCSA(message: "+7776FU")
            }
        } else if command.starts(with: "+") {
            // 先手の手
            if myColor == PColor.WHITE {
                self.sendCSA(message: "%TORYO")
            }
        } else if command.starts(with: "-") {
            // 後手の手
            if myColor == PColor.BLACK {
                self.sendCSA(message: "%TORYO")
            }
        }
    }
    
    func _send(messageWithNewline: String) {
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                print("Error in send", error)
            }
        })
        
    }
    
    func sendCSA(message: String) {
        _send(messageWithNewline: message + "\n")
    }
    
    func sendCSA(messages: [String]) {
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
}
